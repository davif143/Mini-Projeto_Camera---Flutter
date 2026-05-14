import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MaterialApp(home: HiddenCameraApp(camera: cameras.first)));
}

class HiddenCameraApp extends StatefulWidget {
  final CameraDescription camera;
  const HiddenCameraApp({Key? key, required this.camera}) : super(key: key);

  @override
  _HiddenCameraAppState createState() => _HiddenCameraAppState();
}

class _HiddenCameraAppState extends State<HiddenCameraApp> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final FlutterTts _tts = FlutterTts();
  Timer? _timer;
  File? _currentImageDisplay;

  @override
  void initState() {
    super.initState();
    _setupTts();
    _controller = CameraController(widget.camera, ResolutionPreset.medium, enableAudio: false);
    _initializeControllerFuture = _controller.initialize().then((_) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) => _processCycle());
    });
  }

  void _setupTts() async {
    await _tts.setLanguage("pt-BR");
    await _tts.setSpeechRate(0.5);
  }

  Future<Map<String, dynamic>> _mockApiCall(File imageFile) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      "detections": [
        {"objeto": "Pessoa", "posicao": "Centro"},
        {"objeto": "Cadeira", "posicao": "Esquerda"}
      ]
    };
  }

  Future<void> _processCycle() async {
    try {
      await _initializeControllerFuture;

      if (_currentImageDisplay != null && await _currentImageDisplay!.exists()) {
        await _currentImageDisplay!.delete();
        print("Cache limpo: Imagem anterior deletada.");
      }

      final XFile photo = await _controller.takePicture();
      final File newImage = File(photo.path);

      setState(() {
        _currentImageDisplay = newImage;
      });

      final response = await _mockApiCall(newImage);

      List detections = response['detections'];
      String resultText = detections.map((d) => "${d['objeto']} na posição ${d['posicao']}").join(". ");

      await _tts.speak(resultText);

    } catch (e) {
      print("Erro no ciclo: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PAEG")),
      body: Stack(
        children: [
          SizedBox(width: 1, height: 1, child: CameraPreview(_controller)),

          Center(
            child: _currentImageDisplay == null
                ? const Text("Aguardando primeira captura...")
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.file(_currentImageDisplay!, height: 300),
                const SizedBox(height: 20),
                const Text("Imagem atual"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}