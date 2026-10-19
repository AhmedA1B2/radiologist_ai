import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// نتيجة تصنيف واحدة من نماذج الذكاء الاصطناعي.
class DiagnosticResult {
  final String label;
  final double confidence;

  const DiagnosticResult(this.label, this.confidence);
}

/// يدير نموذج التوجيه والنموذج التخصصي الذي يتم تحميله حسب نوع الأشعة.
class AIPipelineService {
  static const String _routerModelPath =
      'assets/ai_model/choose_ai_model/choose_ai_model.tflite';
  static const String _routerLabelsPath =
      'assets/ai_model/choose_ai_model/choose_ai_labels.json';

  Interpreter? _routerInterpreter;
  List<String>? _routerLabels;

  Interpreter? _specialistInterpreter;
  List<String>? _specialistLabels;

  String? currentSpecialistName;

  /// يدعم الاسمين brain وbrian للتوافق مع اختلاف التهجئة في بعض الملفات.
  final Map<String, String> modelsMap = const {
    'brain': 'brain_model',
    'brian': 'brain_model',
    'chest': 'chest_model',
    'teeth': 'teeth_model',
    'knee': 'knee_model',
    'liver': 'liver_model',
    'hand': 'hand_model',
    'elbow': 'elbow_model',
    'finger': 'finger_model',
    'forearm': 'forearm_model',
    'humerus': 'humerus_model',
    'shoulder': 'shoulder_model',
    'wrist': 'wrist_model',
  };

  void _log(String message) {
    // نستخدم أكثر من قناة كي لا تضيع الرسالة إذا لم تكن Debug Console ظاهرة.
    print('[AIPipelineService] $message');
    debugPrint('[AIPipelineService] $message');
    developer.log(message, name: 'AIPipelineService');
  }

  void _logError(String stage, Object error, StackTrace stackTrace) {
    final message = '[$stage] $error';
    print('[AIPipelineService ERROR] $message');
    debugPrint('[AIPipelineService ERROR] $message');
    debugPrintStack(stackTrace: stackTrace);
    developer.log(
      message,
      name: 'AIPipelineService',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }

  List<String> _parseLabels(String labelsData, String assetPath) {
    final dynamic decoded;
    try {
      decoded = json.decode(labelsData);
    } on FormatException catch (error, stackTrace) {
      _logError('JSON labels parse: $assetPath', error, stackTrace);
      throw FormatException('ملف التسميات ليس JSON صالحًا: $assetPath. $error');
    }

    List<String> labels;
    if (decoded is List) {
      labels = decoded.map((value) => value.toString().trim()).toList();
    } else if (decoded is Map) {
      labels = decoded.values.map((value) => value.toString().trim()).toList();
    } else {
      throw FormatException(
        'صيغة ملف التسميات غير مدعومة في $assetPath. يجب أن تكون List أو Map.',
      );
    }

    if (labels.isEmpty || labels.any((label) => label.isEmpty)) {
      throw FormatException(
        'ملف التسميات فارغ أو يحتوي على تسميات فارغة: $assetPath',
      );
    }

    return labels;
  }

  void _validateOutputLabels(
    Interpreter interpreter,
    List<String> labels,
    String modelName,
  ) {
    final outputTensors = interpreter.getOutputTensors();
    if (outputTensors.isEmpty) {
      throw StateError('النموذج $modelName لا يحتوي على مخرجات.');
    }

    final outputShape = outputTensors.first.shape;
    if (outputShape.isEmpty) {
      throw StateError('تعذر قراءة شكل مخرجات النموذج $modelName.');
    }

    final outputClassCount = outputShape.last;
    _log(
      '$modelName: input shape=${interpreter.getInputTensors().isNotEmpty ? interpreter.getInputTensors().first.shape : 'غير متاح'}, '
      'output shape=$outputShape, labels=${labels.length}',
    );

    if (outputClassCount != labels.length) {
      throw StateError(
        'عدد مخرجات النموذج لا يطابق عدد التسميات في $modelName. '
        'شكل المخرجات: $outputShape، عدد التسميات: ${labels.length}.',
      );
    }
  }

  /// تحميل نموذج التوجيه والتسميات، مع تسجيل مرحلة الفشل بدقة.
  Future<void> initRouter() async {
    _log('بدء تهيئة نموذج التوجيه.');
    _routerInterpreter?.close();
    _routerInterpreter = null;
    _routerLabels = null;

    try {
      _log('تحميل ملف التسميات: $_routerLabelsPath');
      final labelsData = await rootBundle.loadString(_routerLabelsPath);
      final labels = _parseLabels(labelsData, _routerLabelsPath);
      _log('تم تحميل ${labels.length} تسمية للموجه.');

      _log('تحميل نموذج TFLite: $_routerModelPath');
      final interpreter = await Interpreter.fromAsset(_routerModelPath);

      try {
        _validateOutputLabels(interpreter, labels, 'نموذج التوجيه');
      } catch (_) {
        interpreter.close();
        rethrow;
      }

      _routerInterpreter = interpreter;
      _routerLabels = labels;
      _log('تمت تهيئة نموذج التوجيه بنجاح.');
    } catch (error, stackTrace) {
      _routerInterpreter?.close();
      _routerInterpreter = null;
      _routerLabels = null;
      _logError('INIT ROUTER', error, stackTrace);
      rethrow;
    }
  }

  /// تشغيل الموجه لتحديد العضو أو نوع الأشعة.
  DiagnosticResult runRouter(List<List<List<List<double>>>> input) {
    final interpreter = _routerInterpreter;
    final labels = _routerLabels;

    if (interpreter == null || labels == null) {
      throw StateError(
        'نموذج التوجيه غير جاهز. تحقق من نجاح initRouter() أولًا.',
      );
    }

    try {
      final output = <List<double>>[List<double>.filled(labels.length, 0.0)];
      interpreter.run(input, output);

      final probabilities = output.first;
      if (probabilities.length != labels.length) {
        throw StateError(
          'خرج الموجه ${probabilities.length} قيمة، لكن عدد التسميات ${labels.length}.',
        );
      }
      if (probabilities.isEmpty) {
        throw StateError('لم ينتج نموذج التوجيه أي احتمالات.');
      }

      var maxIndex = 0;
      var maxProbability = probabilities.first;
      for (var i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProbability) {
          maxProbability = probabilities[i];
          maxIndex = i;
        }
      }

      final result = DiagnosticResult(labels[maxIndex], maxProbability);
      _log('نتيجة الموجه: ${result.label}، الثقة=${result.confidence}.');
      return result;
    } catch (error, stackTrace) {
      _logError('RUN ROUTER', error, stackTrace);
      rethrow;
    }
  }

  /// تحميل النموذج التخصصي بحسب تسمية الموجه.
  Future<void> loadSpecialist(String routerLabel) async {
    final normalizedLabel = routerLabel.trim().toLowerCase();
    final folderName = modelsMap[normalizedLabel];
    if (folderName == null) {
      throw ArgumentError(
        'لا يوجد نموذج مختص للتسمية "$routerLabel". '
        'التسميات المدعومة: ${modelsMap.keys.join(', ')}',
      );
    }

    // نتخلص من النموذج القديم قبل تحميل النموذج الجديد لتقليل استهلاك الذاكرة.
    _specialistInterpreter?.close();
    _specialistInterpreter = null;
    _specialistLabels = null;
    currentSpecialistName = null;

    final modelPath = 'assets/ai_model/$folderName/$folderName.tflite';
    final labelsPath =
        'assets/ai_model/$folderName/${folderName.replaceAll('_model', '_labels')}.json';

    _log('تحميل النموذج التخصصي للاسم "$routerLabel" من: $modelPath');

    Interpreter? newInterpreter;
    try {
      _log('تحميل تسميات النموذج التخصصي: $labelsPath');
      final labelsData = await rootBundle.loadString(labelsPath);
      final labels = _parseLabels(labelsData, labelsPath);

      _log('تحميل نموذج TFLite التخصصي: $modelPath');
      newInterpreter = await Interpreter.fromAsset(modelPath);
      _validateOutputLabels(newInterpreter, labels, folderName);

      _specialistInterpreter = newInterpreter;
      _specialistLabels = labels;
      currentSpecialistName = folderName;
      newInterpreter = null; // أصبحت ملكية الـ Interpreter للخدمة.

      _log('تم تحميل النموذج التخصصي $folderName بنجاح.');
    } catch (error, stackTrace) {
      newInterpreter?.close();
      _specialistInterpreter?.close();
      _specialistInterpreter = null;
      _specialistLabels = null;
      currentSpecialistName = null;
      _logError('LOAD SPECIALIST ($routerLabel)', error, stackTrace);
      rethrow;
    }
  }

  /// تشغيل النموذج التخصصي وإرجاع أعلى ثلاث نتائج.
  List<DiagnosticResult> runSpecialist(List<List<List<List<double>>>> input) {
    final interpreter = _specialistInterpreter;
    final labels = _specialistLabels;

    if (interpreter == null || labels == null) {
      throw StateError(
        'النموذج التخصصي غير جاهز. استدعِ loadSpecialist() بنجاح أولًا.',
      );
    }

    try {
      final output = <List<double>>[List<double>.filled(labels.length, 0.0)];
      interpreter.run(input, output);
      final probabilities = output.first;

      if (probabilities.length != labels.length) {
        throw StateError(
          'خرج النموذج التخصصي ${probabilities.length} قيمة، '
          'لكن عدد التسميات ${labels.length}.',
        );
      }

      final results = <DiagnosticResult>[];
      for (var i = 0; i < probabilities.length; i++) {
        results.add(DiagnosticResult(labels[i], probabilities[i]));
      }
      results.sort((a, b) => b.confidence.compareTo(a.confidence));

      _log('اكتمل النموذج التخصصي $currentSpecialistName.');
      return results.take(3).toList();
    } catch (error, stackTrace) {
      _logError('RUN SPECIALIST ($currentSpecialistName)', error, stackTrace);
      rethrow;
    }
  }

  void dispose() {
    _log('إغلاق نماذج الذكاء الاصطناعي.');
    try {
      _routerInterpreter?.close();
    } catch (error, stackTrace) {
      _logError('DISPOSE ROUTER', error, stackTrace);
    } finally {
      _routerInterpreter = null;
      _routerLabels = null;
    }

    try {
      _specialistInterpreter?.close();
    } catch (error, stackTrace) {
      _logError('DISPOSE SPECIALIST', error, stackTrace);
    } finally {
      _specialistInterpreter = null;
      _specialistLabels = null;
      currentSpecialistName = null;
    }
  }
}
