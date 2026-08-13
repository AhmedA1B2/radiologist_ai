import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedicalXRayApp());
}

// ==========================================
// 1. إعدادات الثيم والألوان (Dark Medical Tech)
// ==========================================
class AppColors {
  static const Color navyDark = Color(0xFF0F172A);
  static const Color slateGrey = Color(0xFF1E293B);
  static const Color cyanAccent = Color(0xFF06B6D4);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
}

class MedicalXRayApp extends StatelessWidget {
  const MedicalXRayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'X-Ray AI Medical Diagnostics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.navyDark,
        primaryColor: AppColors.cyanAccent,
        useMaterial3: true,
        fontFamily: 'Segoe UI', // خط مناسب للويندوز
      ),
      home: const MainDashboard(),
    );
  }
}

// ==========================================
// 2. طبقة معالجة الصور (Image PreProcessor) - Isolate
// ==========================================
class ImagePreProcessor {
  static const int inputSize = 224;

  // استخدام Compute لمنع تجميد الواجهة أثناء معالجة المصفوفات
  static Future<List<List<List<List<double>>>>> processImageAsTensor(
    String imagePath,
  ) async {
    return compute(_processInternal, imagePath);
  }

  static List<List<List<List<double>>>> _processInternal(String path) {
    final bytes = File(path).readAsBytesSync();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) throw Exception("تعذرت قراءة الصورة");

    img.Image resizedImage = img.copyResize(
      originalImage,
      width: inputSize,
      height: inputSize,
    );

    // الموديل يحتوي داخلياً على preprocess_input
    // لذلك نمرر قيم 0-255 مباشرة
    return List.generate(
      1,
      (i) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final pixel = resizedImage.getPixel(x, y);

          return [pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()];
        }),
      ),
    );
  }
}

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

// ==========================================
// 4. واجهة المستخدم (Windows Desktop UI)
// ==========================================
enum ProcessStep {
  idle,
  routing,
  loadingSpecialist,
  diagnosing,
  complete,
  error,
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final AIPipelineService _aiService = AIPipelineService();

  File? _selectedImage;
  ProcessStep _currentStep = ProcessStep.idle;
  String _statusMessage = "بانتظار الصورة...";

  DiagnosticResult? _routerResult;
  List<DiagnosticResult>? _finalResults;

  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  Future<void> _initializeSystem() async {
    try {
      await _aiService.initRouter();
      setState(() {
        _statusMessage = "النظام جاهز (الموجه محمل)";
      });
    } catch (e) {
      setState(() {
        _currentStep = ProcessStep.error;
        _statusMessage = "خطأ في تهيئة النظام: $e";
      });
    }
  }

  Future<void> _pickAndProcessImage() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'dcm',
      ], // إضافة dcm لو كنت تدعمه لاحقاً
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedImage = File(result.files.single.path!);
        _currentStep = ProcessStep.routing;
        _routerResult = null;
        _finalResults = null;
        _statusMessage = "1. جاري معالجة الصورة والتوجيه...";
      });

      try {
        // 1. معالجة الصورة في Isolate
        final inputTensor = await ImagePreProcessor.processImageAsTensor(
          _selectedImage!.path,
        );

        // 2. تشغيل الموجه
        _routerResult = _aiService.runRouter(inputTensor);

        setState(() {
          _currentStep = ProcessStep.loadingSpecialist;
          _statusMessage =
              "2. تم تحديد الأشعة: ${_routerResult!.label}. جاري تحميل المختص...";
        });

        // 3. تحميل النموذج المختص ديناميكياً
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // محاكاة وقت التحميل للواجهة
        await _aiService.loadSpecialist(_routerResult!.label);

        setState(() {
          _currentStep = ProcessStep.diagnosing;
          _statusMessage = "3. جاري فحص وتشخيص ${_routerResult!.label}...";
        });

        // 4. تشخيص النموذج المختص
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // لضمان سلاسة الواجهة
        _finalResults = _aiService.runSpecialist(inputTensor);

        setState(() {
          _currentStep = ProcessStep.complete;
          _statusMessage = "اكتمل التشخيص.";
        });
      } catch (e) {
        setState(() {
          _currentStep = ProcessStep.error;
          _statusMessage = "حدث خطأ: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // القائمة الجانبية (Sidebar)
          _buildSidebar(),

          // المنطقة المركزية (Central Panel)
          Expanded(
            flex: 7,
            child: Container(
              color: AppColors.navyDark,
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),

                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // منطقة الصورة والتتبع
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              _buildDragDropZone(),
                              const SizedBox(height: 24),
                              _buildProgressTracker(),
                              const SizedBox(height: 24),
                              _buildFeet(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        // منطقة النتائج
                        Expanded(flex: 1, child: _buildResultsPanel()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- مكونات واجهة المستخدم (Widgets) ---

  Widget _buildFeet() {
    final List<String> sectionstext = [
      'الدماغ',
      'الصدر',
      'الأسنان',
      'الركبة',
      'الكبد',
      'اليد',
      'الكوع',
      'الأصبع',
      'الساعد',
      'العضد',
      'الكتف',
      'المعصم',
    ];

    final List<String> sectionsimg = [
      'assets/imgs/brain.png',
      'assets/imgs/chest.png',
      'assets/imgs/tooth.png',
      'assets/imgs/knee.png',
      'assets/imgs/liver.png',
      'assets/imgs/hand.png',
      'assets/imgs/elbow.png',
      'assets/imgs/finger.png',
      'assets/imgs/forearm.png',
      'assets/imgs/humerus.png',
      'assets/imgs/shoulder.png',
      'assets/imgs/wrist.png',
    ];

    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.slateGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 12.0, // المسافة الأفقيّة بين العناصر
            runSpacing: 12.0, // المسافة الرأسية بين السطور
            children: List.generate(sectionstext.length, (index) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                    0.1,
                  ), // خلفية خفيفة لكل عنصر (اختياري)
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min, // لجعل العنصر يأخذ مساحة محتواه فقط
                  spacing: 8,
                  children: [
                    Text(
                      "${index + 1}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: Image.asset(
                        sectionsimg[index],
                        fit: BoxFit.contain,
                      ),
                    ),
                    Text(
                      sectionstext[index],
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final List<String> sectionstext = [
      'x-ray',
      'report',
      'settings',
      'i',
      'records',
    ];

    final List<String> sectionsimg = [
      'assets/imgs/xray.png',
      'assets/imgs/report.png',
      'assets/imgs/settings.png',
      'assets/imgs/i.png',
      'assets/imgs/records.png',
    ];

    return Expanded(
      flex: 2,
      child: Container(
        color: AppColors.slateGrey,
        child: Column(
          children: [
            const SizedBox(height: 40),
            // الشعار (تأكد من وجود الصورة أو استخدم أيقونة)
            const Icon(Icons.biotech, size: 64, color: AppColors.cyanAccent),
            const SizedBox(height: 16),
            const Text(
              "X-Ray AI\nDiagnostics",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 40),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView.builder(
                itemCount: sectionstext.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: EdgeInsets.all(8),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: index == 0 ? AppColors.cyanAccent : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      spacing: 10,
                      children: [
                        Text(
                          "${index + 1}",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(
                          width: 36,
                          child: Image.asset(
                            sectionsimg[index],
                            fit: BoxFit.contain,
                          ),
                        ),
                        Text(
                          sectionstext[index],
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "لوحة التشخيص الطبي الرئيسية",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          "قم بإدراج صورة الأشعة وسيتكفل الذكاء الاصطناعي بالتوجيه والتشخيص.",
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDragDropZone() {
    return GestureDetector(
      onTap:
          _currentStep == ProcessStep.routing ||
              _currentStep == ProcessStep.diagnosing ||
              _currentStep == ProcessStep.loadingSpecialist
          ? null
          : _pickAndProcessImage,
      child: Container(
        height: 350,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.slateGrey.withOpacity(0.5),
          border: Border.all(
            color: AppColors.cyanAccent.withOpacity(0.5),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: _selectedImage == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 80,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "انقر لاختيار صورة الأشعة",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "يدعم صيغ JPG, PNG",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              ),
      ),
    );
  }

  Widget _buildProgressTracker() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.slateGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "حالة التحليل",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _statusMessage,
            style: const TextStyle(color: AppColors.cyanAccent),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _getProgressBarValue(),
            backgroundColor: AppColors.navyDark,
            color: AppColors.cyanAccent,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  double _getProgressBarValue() {
    switch (_currentStep) {
      case ProcessStep.idle:
        return 0.0;
      case ProcessStep.routing:
        return 0.33;
      case ProcessStep.loadingSpecialist:
        return 0.66;
      case ProcessStep.diagnosing:
        return 0.85;
      case ProcessStep.complete:
        return 1.0;
      case ProcessStep.error:
        return 0.0;
    }
  }

  Widget _buildResultsPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.slateGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppColors.cyanAccent),
              SizedBox(width: 8),
              Text(
                "التقرير التشخيصي (AI)",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 32),

          if (_currentStep == ProcessStep.idle)
            const Expanded(
              child: Center(
                child: Text(
                  "لا توجد نتائج حالياً.",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),

          if (_currentStep == ProcessStep.error)
            const Expanded(
              child: Center(
                child: Text(
                  "فشل التحليل. الرجاء المحاولة مرة أخرى.",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ),

          if (_routerResult != null) ...[
            Text(
              "نوع الأشعة المكتشف:",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cyanAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cyanAccent),
              ),
              child: Text(
                "${_routerResult!.label} (ثقة: ${(_routerResult!.confidence * 100).toStringAsFixed(1)}%)",
                style: const TextStyle(
                  color: AppColors.cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (_finalResults != null) ...[
            const Text(
              "أفضل 3 احتمالات تشخيصية:",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _finalResults!.length,
                itemBuilder: (context, index) {
                  final result = _finalResults![index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              result.label,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "${(result.confidence * 100).toStringAsFixed(1)}%",
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: result.confidence,
                          backgroundColor: AppColors.navyDark,
                          color: index == 0
                              ? AppColors.cyanAccent
                              : Colors.white38,
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else if (_currentStep != ProcessStep.idle &&
              _currentStep != ProcessStep.error) ...[
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.cyanAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
