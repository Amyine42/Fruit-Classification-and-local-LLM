
// code for 3 class


import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  XFile? _image;
  String? _result;
  final ImagePicker _picker = ImagePicker();
  CameraController? _cameraController;
  bool _isDetecting = false;
  bool _isCameraMode = false;
  String? _cameraResult;
  Interpreter? _interpreter;
  List<String>? _labels;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _initializeCamera();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString('assets/labels.txt');
      setState(() {
        _labels = labelData.split('\n');
      });
      print('Labels loaded: $_labels');
    } catch (e) {
      print('Error loading labels: $e');
    }
  }

  Future<void> _initializeCamera() async {
    if (await Permission.camera.request().isGranted) {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras[0],
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );

        try {
          await _cameraController!.initialize();
          if (mounted) {
            setState(() {});
          }
        } on CameraException catch (e) {
          print('Camera initialization error: ${e.description}');
        }
      }
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/fruitcnn.tflite');
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);

      print('Input Tensor Details:');
      print('Shape: ${inputTensor.shape}');
      print('Type: ${inputTensor.type}');
      print('Name: ${inputTensor.name}');

      print('Output Tensor Details:');
      print('Shape: ${outputTensor.shape}');
      print('Type: ${outputTensor.type}');
      print('Name: ${outputTensor.name}');

      // Try allocating tensors to check if shapes are compatible
      try {
        _interpreter!.allocateTensors();
        print('Tensor allocation successful');
      } catch (e) {
        print('Tensor allocation failed: $e');
      }
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  Future<List<double>> _imageToInput(String imagePath) async {
    final imageData = await File(imagePath).readAsBytes();
    final image = img.decodeImage(imageData);
    if (image == null) throw Exception('Failed to decode image');

    // Resize to 100x100 to match model input
    final resizedImage = img.copyResize(image, width: 100, height: 100);

    List<double> input = List<double>.filled(100 * 100 * 3, 0);

    int pixelIndex = 0;
    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        final pixel = resizedImage.getPixel(x, y);

        // Keep normalization consistent
        input[pixelIndex] = pixel.r / 255.0;
        input[pixelIndex + 10000] = pixel.g / 255.0;
        input[pixelIndex + 20000] = pixel.b / 255.0;
        pixelIndex++;
      }
    }
    return input;
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _image = image;
      _isCameraMode = false;
    });

    await _predictImage(image);
  }

  Future<void> _predictImage(XFile image) async {
    try {
      if (_interpreter == null) return;

      final input = await _imageToInput(image.path);

      // Reshape input for Conv2D [batch, height, width, channels]
      var reshapedInput = List.generate(
        1,
            (_) => List.generate(
          100,
              (y) => List.generate(
            100,
                (x) => List<double>.generate(
              3,
                  (c) => input[y * 100 + x + (c * 10000)],
            ),
          ),
        ),
      );

      var outputTensor = List.generate(1, (_) => List<double>.filled(3, 0));

      _interpreter!.run(reshapedInput, outputTensor);

      var probs = outputTensor[0];
      int predictedClass = probs.indexOf(probs.reduce(math.max));

      setState(() {
        if (_labels != null && predictedClass < _labels!.length) {
          _result = "${_labels![predictedClass]} (${(probs[predictedClass] * 100).toStringAsFixed(1)}%)";
        }
      });

    } catch (e) {
      print("Error: $e");
      setState(() => _result = "Error: $e");
    }
  }

  void _toggleCamera() {
    setState(() {
      _isCameraMode = !_isCameraMode;
      if (_isCameraMode) {
        _startCameraStream();
      } else {
        _stopCameraStream();
      }
    });
  }

  void _startCameraStream() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      // Add frame processing delay
      int frameSkip = 0;

      _cameraController!.startImageStream((CameraImage image) async {
        // Process every 10th frame to reduce load
        frameSkip = (frameSkip + 1) % 10;
        if (frameSkip != 0) return;

        if (!_isDetecting) {
          _isDetecting = true;
          try {
            final inputImage = await _convertYUV420ToRGB(image);
            if (inputImage == null) return;

            // Use fixed size list for better memory management
            final input = List<double>.filled(100 * 100 * 3, 0, growable: false);

            final resizedImage = img.copyResize(
                inputImage,
                width: 100,
                height: 100,
                interpolation: img.Interpolation.nearest // Faster resize
            );

            int pixelIndex = 0;
            for (int y = 0; y < resizedImage.height; y++) {
              for (int x = 0; x < resizedImage.width; x++) {
                final pixel = resizedImage.getPixel(x, y);
                input[pixelIndex] = pixel.r / 255.0;
                input[pixelIndex + 10000] = pixel.g / 255.0;
                input[pixelIndex + 20000] = pixel.b / 255.0;
                pixelIndex++;
              }
            }

            // Use fixed size lists for tensors
            final reshapedInput = List.generate(
                1,
                    (_) => List.generate(
                    100,
                        (y) => List.generate(
                        100,
                            (x) => List<double>.generate(
                            3,
                                (c) => input[y * 100 + x + (c * 10000)],
                            growable: false
                        ),
                        growable: false
                    ),
                    growable: false
                ),
                growable: false
            );

            final outputTensor = List.generate(
                1,
                    (_) => List<double>.filled(3, 0),
                growable: false
            );

            _interpreter!.run(reshapedInput, outputTensor);

            final probs = outputTensor[0];
            final predictedClass = probs.indexOf(probs.reduce(math.max));

            if (mounted) {
              setState(() {
                if (_labels != null && predictedClass < _labels!.length) {
                  _cameraResult = "${_labels![predictedClass]} (${(probs[predictedClass] * 100).toStringAsFixed(1)}%)";
                }
              });
            }
          } catch (e) {
            print('Error processing frame: $e');
          } finally {
            _isDetecting = false;
          }
        }
      });
    }
  }

  // Add this method to properly cleanup resources
  @override
  void dispose() {
    _stopCameraStream();
    _interpreter?.close();
    _cameraController?.dispose();
    super.dispose();
  }

  void _stopCameraStream() {
    _isDetecting = false;
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.stopImageStream();
    }
  }
  Future<img.Image?> _convertYUV420ToRGB(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;

      // Create the image with fixed dimensions
      final rgbImage = img.Image(width: width ~/ 2, height: height ~/ 2); // Reduced size

      final yBuffer = image.planes[0].bytes;
      final uBuffer = image.planes[1].bytes;
      final vBuffer = image.planes[2].bytes;

      final int uvRowStride = image.planes[1].bytesPerRow;
      final int? uvPixelStride = image.planes[1].bytesPerPixel;

      if (uvPixelStride == null) return null;

      // Process every other pixel to reduce computation
      for (int x = 0; x < width; x += 2) {
        for (int y = 0; y < height; y += 2) {
          final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
          final int index = y * width + x;

          final yp = yBuffer[index];
          final up = uBuffer[uvIndex];
          final vp = vBuffer[uvIndex];

          // Convert YUV to RGB
          int r = (yp + (1.370705 * (vp - 128))).toInt().clamp(0, 255);
          int g = (yp - (0.698001 * (vp - 128)) - (0.337633 * (up - 128))).toInt().clamp(0, 255);
          int b = (yp + (1.732446 * (up - 128))).toInt().clamp(0, 255);

          rgbImage.setPixelRgba(x ~/ 2, y ~/ 2, r, g, b, 255);
        }
      }

      return rgbImage;
    } catch (e) {
      print('Error converting YUV to RGB: $e');
      return null;
    }
  }

  // Future<void> _processCameraImage(CameraImage image) async {
  //   try {
  //     XFile file = await _cameraController!.takePicture();
  //     var recognitions = await _predictImage(file);
  //
  //     if (mounted) {
  //       setState(() {
  //         _isDetecting = false;
  //       });
  //     }
  //   } catch (e) {
  //     print('Error processing camera image: $e');
  //     _isDetecting = false;
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: const <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'EL AYOUBI Amine',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 10),
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: AssetImage('assets/images/photo_pro.jpeg'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCameraMode && _cameraController != null && _cameraController!.value.isInitialized)
              Container(
                height: 300,
                child: Stack(
                  children: [
                    CameraPreview(_cameraController!),
                    if (_cameraResult != null)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.black54,
                            child: Text(
                              'Prediction: $_cameraResult',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else if (!_isCameraMode)
              _image != null
                  ? Image.file(
                File(_image!.path),
                height: 200,
              )
                  : const Text('No image selected'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Select Image'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _toggleCamera,
                  child: Text(_isCameraMode ? 'Stop Camera' : 'Start Camera'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!_isCameraMode && _result != null)
              Text(
                'Prediction: $_result',
                style: const TextStyle(fontSize: 18),
              ),
          ],
        ),
      ),
    );
  }


}