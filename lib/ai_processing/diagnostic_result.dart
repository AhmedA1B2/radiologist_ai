import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
// ==========================================
// 3. طبقة الذكاء الاصطناعي (Pipeline Service)
// ==========================================
class DiagnosticResult {
  final String label;
  final double confidence;
  DiagnosticResult(this.label, this.confidence);
}

class AIPipelineService {
  Interpreter? _routerInterpreter;
  List<String>? _routerLabels;

  Interpreter? _specialistInterpreter;
  List<String>? _specialistLabels;

  String? currentSpecialistName;

  // خريطة مسارات النماذج التخصصية
  final Map<String, String> modelsMap = {
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

  // تهيئة نموذج الموجه (Router)
  Future<void> initRouter() async {
    _routerInterpreter = await Interpreter.fromAsset(
      'assets/ai_model/choose_ai_model/choose_ai_model.tflite',
    );
    final String labelsData = await rootBundle.loadString(
      'assets/ai_model/choose_ai_model/choose_ai_labels.json',
    );
    _routerLabels = List<String>.from(json.decode(labelsData));
  }

  // تشغيل الموجه لتحديد العضو
  DiagnosticResult runRouter(List<List<List<List<double>>>> input) {
    if (_routerInterpreter == null || _routerLabels == null) {
      throw Exception("الموجه غير جاهز");
    }
    var output = List.generate(
      1,
      (_) => List.filled(_routerLabels!.length, 0.0),
    );
    _routerInterpreter!.run(input, output);

    List<double> probabilities = (output[0] as List).cast<double>();
    int maxIndex = 0;
    double maxProb = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }
    return DiagnosticResult(_routerLabels![maxIndex], maxProb);
  }

  // تحميل النموذج المختص ديناميكياً مع إدارة الذاكرة
  Future<void> loadSpecialist(String routerLabel) async {
    // التخلص من النموذج القديم من الذاكرة إن وجد
    _specialistInterpreter?.close();
    _specialistInterpreter = null;
    _specialistLabels = null;

    // مطابقة اسم الموجه مع المجلد
    String? folderName = modelsMap[routerLabel.toLowerCase()];
    if (folderName == null) {
      throw Exception("لا يوجد نموذج مختص لهذا العضو: $routerLabel");
    }

    currentSpecialistName = folderName;

    _specialistInterpreter = await Interpreter.fromAsset(
      'assets/ai_model/$folderName/$folderName.tflite',
    );
    final String labelsData = await rootBundle.loadString(
      'assets/ai_model/$folderName/${folderName.replaceAll('_model', '_labels')}.json',
    );

    // دعم التعامل مع JSON إذا كان List مباشر أو Map
    var decoded = json.decode(labelsData);
    if (decoded is List) {
      _specialistLabels = List<String>.from(decoded);
    } else if (decoded is Map) {
      _specialistLabels = decoded.values.map((e) => e.toString()).toList();
    }
  }

  // تشغيل المختص واستخراج أفضل 3 نتائج
  List<DiagnosticResult> runSpecialist(List<List<List<List<double>>>> input) {
    if (_specialistInterpreter == null || _specialistLabels == null) {
      throw Exception("النموذج المختص غير جاهز");
    }
    var output = List.generate(
      1,
      (_) => List.filled(_specialistLabels!.length, 0.0),
    );
    _specialistInterpreter!.run(input, output);

    List<double> probabilities = (output[0] as List).cast<double>();
    List<DiagnosticResult> results = [];
    for (int i = 0; i < probabilities.length; i++) {
      results.add(DiagnosticResult(_specialistLabels![i], probabilities[i]));
    }

    // ترتيب تنازلي
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results.take(3).toList();
  }

  void dispose() {
    _routerInterpreter?.close();
    _specialistInterpreter?.close();
  }
}
