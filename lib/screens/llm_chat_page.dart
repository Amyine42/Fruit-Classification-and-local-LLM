import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Message {
  final String content;
  final bool isUser;

  Message(this.content, this.isUser);
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final String baseUrl = 'http://192.168.100.28:5000';
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  double _temperature = 0.7;
  int _maxTokens = 1000;
  List<PlatformFile> _uploadedFiles = [];

  Future<void> _uploadDocuments() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _isLoading = true;
        });

        // Prepare the files for upload
        List<String> documents = [];
        List<Map<String, String>> metadatas = [];

        for (var file in result.files) {
          if (file.path != null) {
            final content = await File(file.path!).readAsString();
            documents.add(content);
            metadatas.add({"source": file.name});
          }
        }

        // Send documents to your Python server
        final response = await http.post(
          Uri.parse('http://192.168.100.28:1234/upload_documents'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'documents': documents,
            'metadatas': metadatas,
          }),
        );

        if (response.statusCode == 200) {
          setState(() {
            _uploadedFiles.addAll(result.files);
          });
          _showSnackBar('Documents uploaded successfully!');
        } else {
          _showSnackBar('Failed to upload documents');
        }
      }
    } catch (e) {
      _showSnackBar('Error uploading documents: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> _getLLMResponse(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': [
            ..._messages.map((msg) => {
              'role': msg.isUser ? 'user' : 'assistant',
              'content': msg.content,
            }),
            {'role': 'user', 'content': prompt}
          ],
          'temperature': _temperature,
          'max_tokens': _maxTokens,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['response'];  // Changed from ['choices'][0]['message']['content']
      } else {
        print('Error response: ${response.body}');
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error: $e');
      return null;
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(Message(text, true));
      _isLoading = true;
      _controller.clear();
    });

    _scrollToBottom();

    final response = await _getLLMResponse(text);

    setState(() {
      _isLoading = false;
      if (response != null) {
        _messages.add(Message(response, false));
      } else {
        _messages.add(Message('Sorry, I encountered an error. Please try again.', false));
      }
    });

    _scrollToBottom();
  }

  void _showDocumentsList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uploaded Documents'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _uploadedFiles.isEmpty
                ? [const Text('No documents uploaded yet')]
                : _uploadedFiles
                .map((file) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(file.name),
            ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with LLM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _uploadDocuments,
            tooltip: 'Upload Documents',
          ),
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: _showDocumentsList,
            tooltip: 'View Uploaded Documents',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Chat Settings'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Temperature: ${_temperature.toStringAsFixed(1)}'),
                      Slider(
                        value: _temperature,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        onChanged: (value) => setState(() => _temperature = value),
                      ),
                      Text('Max Tokens: $_maxTokens'),
                      Slider(
                        value: _maxTokens.toDouble(),
                        min: 100,
                        max: 2000,
                        divisions: 19,
                        onChanged: (value) => setState(() => _maxTokens = value.toInt()),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}