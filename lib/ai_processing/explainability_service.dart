import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ChestGradCamResult {
  final String heatmapPath;
  final String modelInputPath;
  final String label;
  final int classIndex;
  final double confidence;
  final double maxAbsProbabilityDifference;
  final double meanAbsProbabilityDifference;
  final String layerName;
  final List<int> featureMapShape;
  final String warning;

  const ChestGradCamResult({
    required this.heatmapPath,
    required this.modelInputPath,
    required this.label,
    required this.classIndex,
    required this.confidence,
    required this.layerName,
    required this.featureMapShape,
    required this.warning,
    required this.maxAbsProbabilityDifference,
    required this.meanAbsProbabilityDifference,
  });

  factory ChestGradCamResult.fromJson(Map<String, dynamic> json) {
    final index = (json['class_index'] as num?)?.toInt();
    if (json['status'] != 'ok' || index == null) {
      throw const FormatException(
        'The Grad-CAM engine returned an invalid result.',
      );
    }
    return ChestGradCamResult(
      heatmapPath: json['heatmap_image'] as String,
      modelInputPath: json['model_input_image'] as String,
      label: json['class_label'] as String,
      classIndex: index,
      confidence: (json['keras_top_confidence'] as num).toDouble(),
      maxAbsProbabilityDifference:
          (json['max_abs_probability_difference'] as num? ?? 0).toDouble(),
      meanAbsProbabilityDifference:
          (json['mean_abs_probability_difference'] as num? ?? 0).toDouble(),
      layerName: json['layer_name'] as String? ?? 'unknown',
      featureMapShape: (json['feature_map_shape'] as List<dynamic>? ?? const [])
          .map((value) => (value as num).toInt())
          .toList(),
      warning:
          json['warning'] as String? ??
          'Grad-CAM is a visual explanation, not a medical diagnosis.',
    );
  }
}

/// Calls the Grad-CAM Python engine locally. No network/API is used at runtime.
class ExplainabilityService {
  static const String _engineRelativePath = 'python_engine';
  static const String _modelRelativePath =
      'python_engine/models/chest_model.keras';
  static const String _tfliteRelativePath =
      'assets/ai_model/chest_model/chest_model.tflite';
  static const String _labelsRelativePath =
      'assets/ai_model/chest_model/chest_labels.json';

  Future<ChestGradCamResult> generateChestGradCam({
    required List<List<List<List<double>>>> inputTensor,
    required int classIndex,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Chest Grad-CAM integration currently supports Windows desktop only.',
      );
    }
    if (classIndex < 0) {
      throw ArgumentError(
        'The predicted class index is unavailable. Rebuild the project with classIndex support.',
      );
    }
    if (inputTensor.length != 1 ||
        inputTensor.first.length != 224 ||
        inputTensor.first.any((row) => row.length != 224) ||
        inputTensor.first.any((row) => row.any((pixel) => pixel.length != 3))) {
      throw ArgumentError(
        'Grad-CAM requires an input tensor with shape [1,224,224,3].',
      );
    }

    final root = await _findProjectRoot();
    String join(String first, String second) =>
        first + Platform.pathSeparator + second;

    final engineDirectory = join(root, _engineRelativePath);
    final scriptPath = join(engineDirectory, 'gradcam_cli.py');
    final modelPath = _absolute(join(root, _modelRelativePath));
    final tflitePath = _absolute(join(root, _tfliteRelativePath));
    final labelsPath = _absolute(join(root, _labelsRelativePath));

    if (!await File(scriptPath).exists()) {
      throw FileSystemException(
        'Grad-CAM Python engine was not found. Run the app from the project root.',
        scriptPath,
      );
    }
    if (!await File(modelPath).exists()) {
      throw FileSystemException(
        'Chest Keras model was not found. Copy chest_model.keras into python_engine/models.',
        modelPath,
      );
    }
    if (!await File(tflitePath).exists()) {
      throw FileSystemException(
        'Chest TFLite model was not found.',
        tflitePath,
      );
    }
    if (!await File(labelsPath).exists()) {
      throw FileSystemException('Chest labels file was not found.', labelsPath);
    }

    final pythonOverride = Platform.environment['RADIOLOGIST_AI_PYTHON'];
    final bundledVenvPython = join(
      join(engineDirectory, '.venv'),
      'Scripts/python.exe',
    );
    final pythonExecutable =
        pythonOverride ??
        (await File(bundledVenvPython).exists() ? bundledVenvPython : 'python');

    final workDirectory = await Directory.systemTemp.createTemp(
      'radiologist_ai_chest_gradcam_',
    );
    final inputTensorFile = File(join(workDirectory.path, 'input_tensor.bin'));
    final outputDirectory = Directory(join(workDirectory.path, 'output'));
    await outputDirectory.create(recursive: true);

    try {
      await inputTensorFile.writeAsBytes(_encodeTensor(inputTensor));

      final arguments = <String>[
        scriptPath,
        '--model',
        modelPath,
        '--tflite-model',
        tflitePath,
        '--labels',
        labelsPath,
        '--input-tensor',
        inputTensorFile.path,
        '--class-index',
        classIndex.toString(),
        '--output-dir',
        outputDirectory.path,
      ];

      final process = await Process.start(
        pythonExecutable,
        arguments,
        workingDirectory: root,
        runInShell: false,
      );

      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;

      if (exitCode != 0) {
        final details = stderr.trim().isNotEmpty
            ? stderr.trim()
            : stdout.trim();
        throw ProcessException(
          pythonExecutable,
          arguments,
          details.isEmpty
              ? 'Grad-CAM process exited with code $exitCode.'
              : details,
          exitCode,
        );
      }

      final resultFile = File(join(outputDirectory.path, 'result.json'));
      if (!await resultFile.exists()) {
        throw const FormatException(
          'Grad-CAM process finished without creating result.json.',
        );
      }

      final decoded = jsonDecode(await resultFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Grad-CAM result JSON has an unexpected format.',
        );
      }
      final result = ChestGradCamResult.fromJson(decoded);

      if (result.classIndex != classIndex) {
        throw StateError(
          'Grad-CAM returned class ${result.classIndex}, but Flutter requested $classIndex.',
        );
      }
      if (!await File(result.heatmapPath).exists() ||
          !await File(result.modelInputPath).exists()) {
        throw const FileSystemException(
          'The Grad-CAM engine did not create the expected image files.',
        );
      }

      // Keep the temporary output directory alive while the viewer is open.
      return result;
    } catch (_) {
      if (await workDirectory.exists()) {
        await workDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Uint8List _encodeTensor(List<List<List<List<double>>>> tensor) {
    final values = tensor.first.expand((row) => row).expand((pixel) => pixel);
    final bytes = ByteData(224 * 224 * 3 * 4);
    var index = 0;

    for (final value in values) {
      if (!value.isFinite) {
        throw ArgumentError('Input tensor contains a non-finite value.');
      }
      bytes.setFloat32(index * 4, value, Endian.little);
      index++;
    }

    if (index != 224 * 224 * 3) {
      throw StateError('Unexpected tensor value count: $index.');
    }
    return bytes.buffer.asUint8List();
  }

  Future<String> _findProjectRoot() async {
    var candidate = Directory.current.absolute;
    while (true) {
      final separator = Platform.pathSeparator;
      final candidateScript =
          '${candidate.path}${separator}python_engine${separator}gradcam_cli.py';
      final candidateLabels =
          '${candidate.path}${separator}assets${separator}ai_model${separator}chest_model${separator}chest_labels.json';

      if (await File(candidateScript).exists() &&
          await File(candidateLabels).exists()) {
        return candidate.path;
      }

      final parent = candidate.parent;
      if (parent.path == candidate.path) break;
      candidate = parent;
    }

    throw FileSystemException(
      'Could not locate the Radiologist AI project root. '
      'Start the Windows app from the Flutter project folder.',
      Directory.current.path,
    );
  }

  String _absolute(String path) {
    return File(path).absolute.path;
  }
}
