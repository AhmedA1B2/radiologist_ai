import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One specialist model's Grad-CAM result.
class GradCamResult {
  final String specialistModelName;
  final String overlayPath;
  final String heatmapPath;
  final String modelInputPath;
  final String label;
  final int classIndex;
  final double confidence;
  final double tfliteScore;
  final double maxAbsProbabilityDifference;
  final double meanAbsProbabilityDifference;
  final String layerName;
  final List<int> featureMapShape;
  final String warning;
  final String outputDirectoryPath;

  const GradCamResult({
    required this.specialistModelName,
    required this.overlayPath,
    required this.heatmapPath,
    required this.modelInputPath,
    required this.label,
    required this.classIndex,
    required this.confidence,
    required this.tfliteScore,
    required this.maxAbsProbabilityDifference,
    required this.meanAbsProbabilityDifference,
    required this.layerName,
    required this.featureMapShape,
    required this.warning,
    required this.outputDirectoryPath,
  });

  factory GradCamResult.fromJson(
    Map<String, dynamic> json, {
    required String outputDirectoryPath,
  }) {
    final index = (json['class_index'] as num?)?.toInt();
    if (json['status'] != 'ok' || index == null) {
      throw const FormatException(
        'The Grad-CAM engine returned an invalid result.',
      );
    }

    return GradCamResult(
      specialistModelName: json['specialist'] as String,
      overlayPath: json['overlay_image'] as String,
      heatmapPath: json['heatmap_image'] as String,
      modelInputPath: json['model_input_image'] as String,
      label: json['class_label'] as String,
      classIndex: index,
      confidence: (json['keras_top_confidence'] as num).toDouble(),
      tfliteScore: (json['tflite_top_score'] as num).toDouble(),
      maxAbsProbabilityDifference:
          (json['max_abs_probability_difference'] as num).toDouble(),
      meanAbsProbabilityDifference:
          (json['mean_abs_probability_difference'] as num).toDouble(),
      layerName: json['layer_name'] as String,
      featureMapShape: (json['feature_map_shape'] as List<dynamic>)
          .map((value) => (value as num).toInt())
          .toList(),
      warning: json['warning'] as String,
      outputDirectoryPath: outputDirectoryPath,
    );
  }
}

/// Runs the local Python Grad-CAM engine for the selected specialist model.
/// The TFLite diagnosis path remains unchanged.
class ExplainabilityService {
  static const String _engineRelativePath = 'python_engine';
  static const Set<String> _supportedModels = {
    'brain_model',
    'chest_model',
    'teeth_model',
    'knee_model',
    'liver_model',
    'hand_model',
    'elbow_model',
    'finger_model',
    'forearm_model',
    'humerus_model',
    'shoulder_model',
    'wrist_model',
  };

  final Set<String> _temporaryDirectories = {};

  Future<GradCamResult> generateSpecialistGradCam({
    required String specialistModelName,
    required List<List<List<List<double>>>> inputTensor,
    required int classIndex,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Grad-CAM currently supports Windows desktop only.',
      );
    }
    if (!_supportedModels.contains(specialistModelName)) {
      throw ArgumentError(
        'Unsupported Grad-CAM specialist: $specialistModelName',
      );
    }
    if (classIndex < 0) {
      throw ArgumentError('The predicted class index is unavailable.');
    }
    _validateInputTensor(inputTensor);

    final root = await _findProjectRoot();
    String join(String first, String second) =>
        first + Platform.pathSeparator + second;

    final engineDirectory = join(root, _engineRelativePath);
    final scriptPath = join(engineDirectory, 'gradcam_cli.py');
    final modelPath = _absolute(
      join(
        join(engineDirectory, 'models'),
        '$specialistModelName.keras',
      ),
    );

    final assetDirectory = join(
      join(root, 'assets'),
      join('ai_model', specialistModelName),
    );
    final tflitePath = _absolute(
      join(assetDirectory, '$specialistModelName.tflite'),
    );
    final labelsFileName =
        '${specialistModelName.replaceAll('_model', '_labels')}.json';
    final labelsPath = _absolute(join(assetDirectory, labelsFileName));

    _requireFile(scriptPath, 'Grad-CAM Python script was not found.');
    _requireFile(
      modelPath,
      'Keras model not found for $specialistModelName. '
          'Expected python_engine/models/$specialistModelName.keras.',
    );
    _requireFile(tflitePath, 'TFLite asset not found for $specialistModelName.');
    _requireFile(labelsPath, 'Labels file not found for $specialistModelName.');

    final pythonOverride = Platform.environment['RADIOLOGIST_AI_PYTHON'];
    final venvPython = join(
      join(engineDirectory, '.venv'),
      join('Scripts', 'python.exe'),
    );
    final pythonExecutable = pythonOverride ??
        (await File(venvPython).exists() ? venvPython : 'python');

    final workDirectory = await Directory.systemTemp.createTemp(
      'radiologist_ai_gradcam_',
    );
    final inputTensorFile = File(join(workDirectory.path, 'input_tensor.bin'));
    final outputDirectory = Directory(join(workDirectory.path, 'output'));
    await outputDirectory.create(recursive: true);

    try {
      await inputTensorFile.writeAsBytes(_encodeTensor(inputTensor));

      final arguments = <String>[
        scriptPath,
        '--specialist',
        specialistModelName,
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

      final result = GradCamResult.fromJson(
        decoded,
        outputDirectoryPath: workDirectory.path,
      );

      if (result.specialistModelName != specialistModelName ||
          result.classIndex != classIndex) {
        throw StateError(
          'Grad-CAM returned a result for a different model or class.',
        );
      }

      for (final path in [
        result.overlayPath,
        result.heatmapPath,
        result.modelInputPath,
      ]) {
        if (!await File(path).exists()) {
          throw FileSystemException(
            'Grad-CAM output image was not created.',
            path,
          );
        }
      }

      _temporaryDirectories.add(workDirectory.path);
      return result;
    } catch (_) {
      if (await workDirectory.exists()) {
        await workDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  void _validateInputTensor(
    List<List<List<List<double>>>> tensor,
  ) {
    if (tensor.length != 1 ||
        tensor.first.length != 224 ||
        tensor.first.any((row) => row.length != 224) ||
        tensor.first.any((row) => row.any((pixel) => pixel.length != 3))) {
      throw ArgumentError(
        'Grad-CAM currently requires the app tensor shape [1,224,224,3].',
      );
    }

    for (final row in tensor.first) {
      for (final pixel in row) {
        for (final value in pixel) {
          if (!value.isFinite) {
            throw ArgumentError('Input tensor contains a non-finite value.');
          }
        }
      }
    }
  }

  Uint8List _encodeTensor(List<List<List<List<double>>>> tensor) {
    final values = tensor.first.expand((row) => row).expand((pixel) => pixel);
    final bytes = ByteData(224 * 224 * 3 * 4);
    var index = 0;

    for (final value in values) {
      bytes.setFloat32(index * 4, value, Endian.little);
      index++;
    }

    if (index != 224 * 224 * 3) {
      throw StateError('Unexpected tensor value count: $index.');
    }
    return bytes.buffer.asUint8List();
  }

  void _requireFile(String path, String message) {
    if (!File(path).existsSync()) {
      throw FileSystemException(message, path);
    }
  }

  Future<String> _findProjectRoot() async {
    var candidate = Directory.current.absolute;

    while (true) {
      final separator = Platform.pathSeparator;
      final candidateScript =
          '${candidate.path}${separator}python_engine${separator}gradcam_cli.py';
      final candidateAssets =
          '${candidate.path}${separator}assets${separator}ai_model';

      if (await File(candidateScript).exists() &&
          await Directory(candidateAssets).exists()) {
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

  String _absolute(String path) => File(path).absolute.path;

  /// Remove generated local files when a new case is selected or the page closes.
  Future<void> clearTemporaryFiles() async {
    final directories = _temporaryDirectories.toList();
    _temporaryDirectories.clear();

    for (final path in directories) {
      try {
        final directory = Directory(path);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      } catch (_) {
        // Temporary files are best-effort cleanup only.
      }
    }
  }
}
