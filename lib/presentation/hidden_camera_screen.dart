import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/tts_service.dart';
import '../services/yolo_service.dart';

class HiddenCameraScreen extends StatefulWidget {
  final CameraDescription camera;
  const HiddenCameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _HiddenCameraScreenState createState() => _HiddenCameraScreenState();
}

class _HiddenCameraScreenState extends State<HiddenCameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  final TtsService _ttsService = TtsService();
  final YoloService _yoloService = YoloService();

  Timer? _timer;
  File? _currentImageDisplay;
  bool _isModelLoaded = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _yoloService.initializeModel();

    if (mounted) {
      setState(() { _isModelLoaded = true; });
    }

    _controller = CameraController(widget.camera, ResolutionPreset.medium, enableAudio: false);
    _initializeControllerFuture = _controller.initialize().then((_) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) => _processCycle());
    });
  }

  Future<void> _processCycle() async {
    if (_isProcessing || !_isModelLoaded) return;

    try {
      setState(() { _isProcessing = true; });
      await _initializeControllerFuture;

      if (_currentImageDisplay != null && await _currentImageDisplay!.exists()) {
        await _currentImageDisplay!.delete();
      }

      final XFile photo = await _controller.takePicture();
      final File newImage = File(photo.path);

      setState(() {
        _currentImageDisplay = newImage;
      });

      final detections = await _yoloService.runInference(newImage);

      if (detections.isNotEmpty) {
        String resultText = detections.map((d) {
          String nomeObjetoOriginal = d['objeto'];
          String nomeObjeto = cocoTranslations[nomeObjetoOriginal] ?? nomeObjetoOriginal;
          return "$nomeObjeto na posição ${d['posicao']}";
        }).join(". ");

        await _ttsService.speak(resultText);
      }

    } catch (e) {
      print("Erro no ciclo de execução: $e");
    } finally {
      if (mounted) {
        setState(() { _isProcessing = false; });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _ttsService.stop();
    _yoloService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PAEG + YOLO11 Local")),
      body: Stack(
        children: [
          SizedBox(width: 1, height: 1, child: CameraPreview(_controller)),
          Center(
            child: !_isModelLoaded
                ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 15),
                Text("Carregando modelo YOLO11nano..."),
              ],
            )
                : _currentImageDisplay == null
                ? const Text("Aguardando primeira captura...")
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.file(_currentImageDisplay!, height: 300),
                const SizedBox(height: 20),
                const Text("Análise local ativa (YOLO11)"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}