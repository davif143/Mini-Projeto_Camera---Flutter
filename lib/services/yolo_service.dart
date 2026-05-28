import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../core/constants.dart';

class YoloService {
  Interpreter? _interpreter;
  final int inputSize = 640;
  final double confidenceThreshold = 0.5;

  Future<void> initializeModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/yolo11n_int8.tflite');
      _interpreter?.allocateTensors();
      print("Modelo TFLite carregado com sucesso.");
    } catch (e) {
      print("Erro ao carregar o modelo: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> runInference(File imageFile) async {
    if (_interpreter == null) return [];

    final Uint8List imageBytes = await imageFile.readAsBytes();
    final img.Image? oriImage = img.decodeImage(imageBytes);
    if (oriImage == null) return [];

    final img.Image resizedImage = img.copyResize(oriImage, width: inputSize, height: inputSize);

    var input = List.generate(
      1,
          (_) => List.generate(
        inputSize,
            (y) => List.generate(
          inputSize,
              (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );

    var output = List.generate(1, (_) => List.generate(84, (_) => List.generate(8400, (_) => 0.0)));

    _interpreter!.run(input, output);

    List<Map<String, dynamic>> detections = [];
    List<List<double>> outputData = output[0];

    for (int i = 0; i < 8400; i++) {
      double maxClassScore = 0.0;
      int classId = -1;

      for (int c = 0; c < 80; c++) {
        double score = outputData[4 + c][i];
        if (score > maxClassScore) {
          maxClassScore = score;
          classId = c;
        }
      }

      if (maxClassScore > confidenceThreshold) {
        double xc = outputData[0][i];
        double relativeCenterX = xc / inputSize;

        String posicao = "no Centro";
        if (relativeCenterX < 0.35) posicao = "à Esquerda";
        else if (relativeCenterX > 0.65) posicao = "à Direita";

        detections.add({
          "objeto": cocoClasses[classId],
          "posicao": posicao,
          "confianca": maxClassScore
        });
      }
    }

    Map<String, Map<String, dynamic>> uniqueDetections = {};
    for (var det in detections) {
      String key = "${det['objeto']}_${det['posicao']}";
      if (!uniqueDetections.containsKey(key) || det['confianca'] > uniqueDetections[key]!['confianca']) {
        uniqueDetections[key] = det;
      }
    }

    return uniqueDetections.values.toList();
  }

  void dispose() {
    _interpreter?.close();
  }
}