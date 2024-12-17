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

class FruitModelPage extends StatefulWidget {
  const FruitModelPage({super.key});

  @override
  State<FruitModelPage> createState() => _FruitModelPageState();
}

class _FruitModelPageState extends State<FruitModelPage> {
  XFile? _image;
  String? _result;
  final ImagePicker _picker = ImagePicker();
  CameraController? _cameraController;
  bool _isDetecting = false;
  bool _isCameraMode = false;
  String? _cameraResult;
  Interpreter? _interpreter;
  List<String>? _labels;

  List<double> softmax(List<double> inputs) { // Converts raw model outputs to probabilities, Makes predictions sum to 100%
    double max = inputs.reduce(math.max);
    List<double> exp = inputs.map((x) => math.exp(x - max)).toList();
    double sum = exp.reduce((a, b) => a + b);
    return exp.map((x) => x / sum * 100).toList();
  }

  @override
  void initState() { // Initializes everything when app starts (model, camera, labels)
    super.initState();
    _loadModel();
    _initializeCamera();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString('assets/labels10.txt');
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

  Future<void> _loadModel() async { //charge et initialise le modele
    try {
      _interpreter = await Interpreter.fromAsset('assets/fruitscnn10.tflite');
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);

      print('Input Tensor Details:'); //for debugging
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

  Future<List<double>> _imageToInput(String imagePath) async { //convert to format required by model
    final imageData = await File(imagePath).readAsBytes();
    final image = img.decodeImage(imageData);
    if (image == null) throw Exception('Failed to decode image');

    // Match training size exactly (32x32)
    final resizedImage = img.copyResize(image, width: 32, height: 32);

    List<double> input = List<double>.filled(32 * 32 * 3, 0);

    int pixelIndex = 0;
    for (int y = 0; y < 32; y++) {
      for (int x = 0; x < 32; x++) {
        final pixel = resizedImage.getPixel(x, y);
        input[pixelIndex] = pixel.r.toDouble();
        input[pixelIndex + 1024] = pixel.g.toDouble();
        input[pixelIndex + 2048] = pixel.b.toDouble();
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

  Future<void> _predictImage(XFile image) async { //traite image et donne prediction
    try {
      if (_interpreter == null) return;

      final input = await _imageToInput(image.path);

      var reshapedInput = List.generate(
        1,
            (_) => List.generate(
          32,
              (y) => List.generate(
            32,
                (x) => List<double>.generate(
              3,
                  (c) => input[y * 32 + x + (c * 1024)],
            ),
          ),
        ),
      );

      // Change output tensor shape to [1, 10]
      var outputTensor = List.generate(1, (_) => List<double>.filled(10, 0));

      _interpreter!.run(reshapedInput, outputTensor);

      print('Raw output: ${outputTensor.map((row) => row.join(', ')).join('\n')}');

      // Apply softmax to the single output
      List<double> probabilities = softmax(outputTensor[0]);

      int predictedClass = probabilities.indexOf(probabilities.reduce(math.max));

      print('Class names: $_labels');
      print('Probabilities: ${probabilities.join(', ')}');
      print('Predicted class index: $predictedClass');

      setState(() {
        if (_labels != null && predictedClass < _labels!.length) {
          _result = "${_labels![predictedClass]} (${probabilities[predictedClass].toStringAsFixed(1)}%)";
        }
      });

    } catch (e) {
      print("Error: $e");
      setState(() => _result = "Error: $e");
    }
  }

  void _toggleCamera() { // Switches between camera and gallery modes
    setState(() {
      _isCameraMode = !_isCameraMode;
      if (_isCameraMode) {
        _startCameraStream();
      } else {
        _stopCameraStream();
      }
    });
  }

  void _startCameraStream() { //start live camera, frames for real-time prediction
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      int frameSkip = 0;

      _cameraController!.startImageStream((CameraImage image) async {
        frameSkip = (frameSkip + 1) % 10; //frame skipping for performance
        if (frameSkip != 0) return;

        if (!_isDetecting) {
          _isDetecting = true;
          try {
            final inputImage = await _convertYUV420ToRGB(image);
            if (inputImage == null) return;

            final input = List<double>.filled(32 * 32 * 3, 0, growable: false);

            final resizedImage = img.copyResize(
                inputImage,
                width: 32,
                height: 32,
                interpolation: img.Interpolation.nearest
            );

            int pixelIndex = 0;
            for (int y = 0; y < 32; y++) {
              for (int x = 0; x < 32; x++) {
                final pixel = resizedImage.getPixel(x, y);
                input[pixelIndex] = pixel.r.toDouble();
                input[pixelIndex + 1024] = pixel.g.toDouble();
                input[pixelIndex + 2048] = pixel.b.toDouble();
                pixelIndex++;
              }
            }

            final reshapedInput = List.generate(
                1,
                    (_) => List.generate(
                    32,
                        (y) => List.generate(
                        32,
                            (x) => List<double>.generate(
                            3,
                                (c) => input[y * 32 + x + (c * 1024)],
                            growable: false
                        ),
                        growable: false
                    ),
                    growable: false
                ),
                growable: false
            );

            // Change output tensor shape to [1, 10]
            final outputTensor = List.generate(
                1,
                    (_) => List<double>.filled(10, 0),
                growable: false
            );

            _interpreter!.run(reshapedInput, outputTensor);

            print('Raw camera output: ${outputTensor.map((row) => row.join(', ')).join('\n')}');

            // Apply softmax to the single output
            List<double> probabilities = softmax(outputTensor[0]);

            final predictedClass = probabilities.indexOf(probabilities.reduce(math.max));

            print('Class names: $_labels');
            print('Probabilities: ${probabilities.join(', ')}');
            print('Predicted class index: $predictedClass');

            if (mounted) {
              setState(() {
                if (_labels != null && predictedClass < _labels!.length) {
                  _cameraResult = "${_labels![predictedClass]} (${probabilities[predictedClass].toStringAsFixed(1)}%)";
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

  // nettoyer ressources
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fruit Classifier'),
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