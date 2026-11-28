
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:radiologist_ai/ai_processing/diagnostic_result.dart';
import 'package:radiologist_ai/ai_processing/explainability_service.dart';
import 'package:radiologist_ai/widgets/medical_heatmap_view.dart';
import 'package:radiologist_ai/ai_processing/image_pre_processor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:radiologist_ai/api/send_diagnosis.dart';
import 'package:radiologist_ai/body_of_main_view/header.dart';
import 'package:radiologist_ai/body_of_main_view/models/process_step.dart';
import 'package:radiologist_ai/body_of_main_view/sidebar.dart';
import 'package:radiologist_ai/core/theme/app_colors.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:radiologist_ai/customs/custom_dialogue/custom_dialogue.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final AIPipelineService _aiService = AIPipelineService();
  final ExplainabilityService _explainabilityService = ExplainabilityService();

  final TextEditingController numController = TextEditingController();

  File? _selectedImage;

  ProcessStep _currentStep = ProcessStep.idle;

  String _statusMessage = "بانتظار الصورة...";

  DiagnosticResult? _routerResult;

  List<DiagnosticResult>? _finalResults;

  List<List<List<List<double>>>>? _lastInputTensor;
  bool _isGeneratingChestGradCam = false;
  String? _chestGradCamError;

  bool showCustomDialogue = false;

  // التحقق من كون الصورة غير مدعومة
  bool get _isUnsupportedImage {
    return _routerResult?.label.trim().toLowerCase() == 'other';
  }

  /// تسجيل الأخطاء
  void _logDiagnosticError(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    final message = '[$stage] $error';

    print(message);
    debugPrint(message);
    debugPrintStack(stackTrace: stackTrace);

    developer.log(
      message,
      name: 'RadiologistAI.MainDashboard',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  // ============================================================
  // PDF REPORT
  // ============================================================

  Future<String?> _saveDiagnosticAsPdf() async {
    if (_finalResults == null || _finalResults!.isEmpty) {
      return null;
    }

    try {
      final pdf = pw.Document();

      // قراءة صورة الأشعة
      pw.MemoryImage? xrayImage;

      if (_selectedImage != null && await _selectedImage!.exists()) {
        final imageBytes = await _selectedImage!.readAsBytes();
        xrayImage = pw.MemoryImage(imageBytes);
      }

      final now = DateTime.now();

      final date =
          '${now.day.toString().padLeft(2, '0')}/'
          '${now.month.toString().padLeft(2, '0')}/'
          '${now.year}';

      final time =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(35),

          header: (context) {
            return pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'X-RAY AI',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.cyan800,
                      ),
                    ),
                    pw.Text(
                      'MEDICAL DIAGNOSTIC REPORT',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.grey500),
                pw.SizedBox(height: 15),
              ],
            );
          },

          footer: (context) {
            return pw.Column(
              children: [
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'AI-Assisted Diagnostic Report',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },

          build: (context) => [
            pw.Text(
              'Diagnostic Report',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 5),

            pw.Text(
              'Artificial Intelligence X-Ray Analysis',
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey700,
              ),
            ),

            pw.SizedBox(height: 20),

            // معلومات التقرير
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'REPORT INFORMATION',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.cyan800,
                    ),
                  ),

                  pw.SizedBox(height: 12),

                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'Date: $date',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          'Time: $time',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // صورة الأشعة
            if (xrayImage != null) ...[
              pw.Text(
                'X-RAY IMAGE',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.cyan800,
                ),
              ),

              pw.SizedBox(height: 10),

              pw.Container(
                height: 280,
                width: double.infinity,
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Image(
                  xrayImage,
                  fit: pw.BoxFit.contain,
                ),
              ),

              pw.SizedBox(height: 20),
            ],

            // تصنيف الصورة
            if (_routerResult != null) ...[
              pw.Text(
                'IMAGE CLASSIFICATION',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.cyan800,
                ),
              ),

              pw.SizedBox(height: 10),

              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      _routerResult!.label,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.Text(
                      '${(_routerResult!.confidence * 100).toStringAsFixed(1)}%',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.cyan800,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 25),
            ],

            // النتائج
            pw.Text(
              'DIAGNOSTIC RESULTS',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.cyan800,
              ),
            ),

            pw.SizedBox(height: 12),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(5),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  children: [
                    _pdfCell('#', bold: true),
                    _pdfCell('Possible Diagnosis', bold: true),
                    _pdfCell('Confidence', bold: true),
                  ],
                ),

                ..._finalResults!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final result = entry.value;

                  return pw.TableRow(
                    children: [
                      _pdfCell('${index + 1}'),
                      _pdfCell(result.label),
                      _pdfCell(
                        '${(result.confidence * 100).toStringAsFixed(1)}%',
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 25),

            // النتيجة الأعلى
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.cyan800),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PRIMARY AI FINDING',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.cyan800,
                    ),
                  ),

                  pw.SizedBox(height: 8),

                  pw.Text(
                    _finalResults!.first.label,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 5),

                  pw.Text(
                    'AI confidence: '
                    '${(_finalResults!.first.confidence * 100).toStringAsFixed(1)}%',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // التنبيه الطبي
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'IMPORTANT MEDICAL NOTICE',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 8),

                  pw.Text(
                    'This report is generated using an artificial '
                    'intelligence system and is intended for '
                    'decision-support and research purposes. '
                    'The results should not be considered a final '
                    'medical diagnosis. A qualified healthcare '
                    'professional should review the X-ray and '
                    'interpret the findings before making any '
                    'clinical decision.',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      // اختيار مكان حفظ الملف
      String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save Diagnostic Report',
        fileName: 'diagnostic_report.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath == null) {
        return null;
      }

      // التأكد من امتداد PDF
      if (!outputPath.toLowerCase().endsWith('.pdf')) {
        outputPath = '$outputPath.pdf';
      }

      final file = File(outputPath);

      final pdfBytes = await pdf.save();

      await file.writeAsBytes(pdfBytes, flush: true);

      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ التقرير بنجاح:\n$outputPath'),
        ),
      );

      return outputPath;
    } catch (e) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إنشاء التقرير: $e'),
        ),
      );

      return null;
    }
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // ============================================================
  // INITIALIZE AI SYSTEM
  // ============================================================

  Future<void> _initializeSystem() async {
    try {
      print('[AI INIT] بدء تهيئة نموذج التوجيه...');

      developer.log(
        'بدء تهيئة نموذج التوجيه',
        name: 'RadiologistAI.MainDashboard',
      );

      await _aiService.initRouter();

      if (!mounted) return;

      setState(() {
        _currentStep = ProcessStep.idle;
        _statusMessage = "النظام جاهز (الموجه محمل)";
      });

      print('[AI INIT] تم تحميل نموذج التوجيه بنجاح.');
    } catch (e, stackTrace) {
      _logDiagnosticError('AI INIT ERROR', e, stackTrace);

      if (!mounted) return;

      setState(() {
        _currentStep = ProcessStep.error;
        _statusMessage =
            'فشل تهيئة نظام الذكاء الاصطناعي.\n'
            'الخطأ: $e\n\nStackTrace:\n$stackTrace';
      });
    }
  }

  // ============================================================
  // PICK AND PROCESS IMAGE
  // ============================================================

  Future<void> _pickAndProcessImage() async {
    // منع اختيار صورة أثناء المعالجة
    if (_currentStep == ProcessStep.routing ||
        _currentStep == ProcessStep.diagnosing ||
        _currentStep == ProcessStep.loadingSpecialist) {
      return;
    }

    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final selectedFile = File(result.files.single.path!);

      if (!mounted) return;

      setState(() {
        _selectedImage = selectedFile;
        _currentStep = ProcessStep.routing;
        _routerResult = null;
        _finalResults = null;
        _lastInputTensor = null;
        _chestGradCamError = null;
        _isGeneratingChestGradCam = false;
        _statusMessage = "1. جاري معالجة الصورة والتوجيه...";
      });

      // 1. معالجة الصورة
      final inputTensor = await ImagePreProcessor.processImageAsTensor(
        selectedFile.path,
      );
      _lastInputTensor = inputTensor;

      if (!mounted) return;

      // 2. تشغيل نموذج التوجيه
      final routerResult = _aiService.runRouter(inputTensor);

      // 3. التحقق من نوع الصورة
      if (routerResult.label.trim().toLowerCase() == 'other') {
        setState(() {
          _routerResult = routerResult;

          _finalResults = null;

          // ليست حالة خطأ برمجية
          _currentStep = ProcessStep.complete;

          _statusMessage =
              "الصورة غير مدعومة.\n"
              "يرجى اختيار صورة أشعة طبية من الأنواع المدعومة.";
        });

        // إيقاف المعالجة وعدم تحميل أي نموذج مختص
        return;
      }

      // 4. تحديث حالة التوجيه
      setState(() {
        _routerResult = routerResult;

        _currentStep = ProcessStep.loadingSpecialist;

        _statusMessage =
            "2. تم تحديد الأشعة: ${routerResult.label}. "
            "جاري تحميل النموذج المختص...";
      });

      // 5. تحميل النموذج المختص
      await _aiService.loadSpecialist(routerResult.label);

      if (!mounted) return;

      setState(() {
        _currentStep = ProcessStep.diagnosing;

        _statusMessage =
            "3. جاري فحص وتشخيص ${routerResult.label}...";
      });

      // 6. تشغيل نموذج التشخيص
      final finalResults = _aiService.runSpecialist(inputTensor);

      if (!mounted) return;

      // 7. عرض النتائج
      setState(() {
        _finalResults = finalResults;

        _currentStep = ProcessStep.complete;

        _statusMessage = "اكتمل التشخيص بنجاح.";
      });
    } catch (e, stackTrace) {
      _logDiagnosticError('AI ANALYSIS ERROR', e, stackTrace);

      if (!mounted) return;

      setState(() {
        _currentStep = ProcessStep.error;

        _statusMessage =
            'حدث خطأ أثناء تحليل الصورة.\n'
            'الخطأ: $e\n\nStackTrace:\n$stackTrace';
      });
    }
  }


  // ============================================================
  // CHEST GRAD-CAM (OPTIONAL EXPLANATION)
  // ============================================================

  Future<void> _generateChestGradCam() async {
    if (_isGeneratingChestGradCam ||
        _lastInputTensor == null ||
        _finalResults == null ||
        _finalResults!.isEmpty ||
        _routerResult?.label.trim().toLowerCase() != 'chest') {
      return;
    }

    final classIndex = _finalResults!.first.classIndex;
    if (classIndex < 0) {
      setState(() {
        _chestGradCamError =
            'تعذر معرفة رقم الفئة الأصلي. أعد تشغيل التطبيق بعد تحديث ملفات Grad-CAM.';
      });
      return;
    }

    setState(() {
      _isGeneratingChestGradCam = true;
      _chestGradCamError = null;
    });

    try {
      final result = await _explainabilityService.generateChestGradCam(
        inputTensor: _lastInputTensor!,
        classIndex: classIndex,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MedicalHeatmapView(result: result),
        ),
      );
    } catch (error, stackTrace) {
      _logDiagnosticError('CHEST GRAD-CAM ERROR', error, stackTrace);

      if (!mounted) return;
      setState(() {
        _chestGradCamError = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إنشاء خريطة Grad-CAM: $error'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingChestGradCam = false;
        });
      }
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    numController.dispose();
    _aiService.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              Sidebar(),

              Expanded(
                flex: 7,
                child: Container(
                  color: AppColors.navyDark,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Header(),

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
                            Expanded(
                              flex: 1,
                              child: _buildResultsPanel(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // نافذة إدخال الرقم الوطني
          if (showCustomDialogue)
            CustomDialogue(
              numController: numController,
              iconOk: Icons.check_circle,

              onPressediconOk: () async {
                // التأكد من وجود صورة
                if (_selectedImage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please select an X-ray image first',
                      ),
                    ),
                  );

                  return;
                }

                // التأكد من وجود نتائج تشخيص
                if (_finalResults == null ||
                    _finalResults!.isEmpty ||
                    _isUnsupportedImage) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'لا توجد نتائج تشخيص صالحة لحفظها.',
                      ),
                    ),
                  );

                  return;
                }

                // التأكد من وجود رقم المريض
                if (numController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter patient ID'),
                    ),
                  );

                  return;
                }

                try {
                  setState(() {
                    showCustomDialogue = false;
                  });

                  // 1. إنشاء وحفظ PDF
                  final String? pdfPath =
                      await _saveDiagnosticAsPdf();

                  if (pdfPath == null) {
                    return;
                  }

                  if (!mounted) return;

                  // 2. إرسال PDF وصورة الأشعة إلى السيرفر
                  final success = await SendDiagnosis().addDiagnosi(
                    // ignore: use_build_context_synchronously
                    context,
                    numController.text.trim(),
                    DateTime.now().toString(),
                    pdfPath,
                    _selectedImage!.path,
                  );

                  // 3. عند نجاح الحفظ
                  if (success && mounted) {
                    setState(() {
                      showCustomDialogue = false;
                      numController.clear();
                    });

                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'تم حفظ التقرير والبيانات بنجاح',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  // ignore: avoid_print
                  print("Save diagnosis error: $e");

                  if (!mounted) return;

                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'حدث خطأ أثناء حفظ التشخيص: $e',
                      ),
                    ),
                  );
                }
              },

              iconNo: Icons.cancel_sharp,

              onPressediconNo: () {
                setState(() {
                  showCustomDialogue = false;
                });
              },

              text: "ادخل الرقم الوطني",
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SUPPORTED BODY SECTIONS
  // ============================================================

  Widget _buildFeet() {
    final List<String> sectionstext = [
      'brian',
      'chest',
      'teeth',
      'knee',
      'liver',
      'other',
      'hand',
      'elbow',
      'finger',
      'forearm',
      'humerus',
      'shoulder',
      'wrist',
    ];

    final List<String> sectionsimg = [
      'assets/imgs/brain.png',
      'assets/imgs/chest.png',
      'assets/imgs/tooth.png',
      'assets/imgs/knee.png',
      'assets/imgs/liver.png',
      'assets/imgs/other.png',
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
            spacing: 12,
            runSpacing: 12,
            children: List.generate(sectionstext.length, (index) {
              final bool isSelected =
                  _routerResult != null &&
                  _routerResult!.label.toLowerCase() ==
                      sectionstext[index].toLowerCase();

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.cyanAccent
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Text(
                      "${index + 1}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
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
                      style: const TextStyle(
                        color: Colors.black,
                      ),
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

  // ============================================================
  // IMAGE PICKER
  // ============================================================

  Widget _buildDragDropZone() {
    final bool isProcessing =
        _currentStep == ProcessStep.routing ||
        _currentStep == ProcessStep.diagnosing ||
        _currentStep == ProcessStep.loadingSpecialist;

    return GestureDetector(
      onTap: isProcessing ? null : _pickAndProcessImage,

      child: Container(
        height: 350,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.slateGrey,
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
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }

  // ============================================================
  // PROGRESS TRACKER
  // ============================================================

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
            style: TextStyle(
              color: _isUnsupportedImage
                  ? Colors.orangeAccent
                  : AppColors.cyanAccent,
            ),
          ),

          const SizedBox(height: 16),

          LinearProgressIndicator(
            value: _getProgressBarValue(),
            backgroundColor: AppColors.navyDark,
            color: _isUnsupportedImage
                ? Colors.orangeAccent
                : AppColors.cyanAccent,
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

  // ============================================================
  // RESULTS PANEL
  // ============================================================

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
              Icon(
                Icons.analytics_outlined,
                color: AppColors.cyanAccent,
              ),

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

          const Divider(
            color: Colors.white24,
            height: 32,
          ),

          // الحالة الابتدائية
          if (_currentStep == ProcessStep.idle)
            const Expanded(
              child: Center(
                child: Text(
                  "لا توجد نتائج حالياً.",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

          // حالة الخطأ الحقيقي فقط
          if (_currentStep == ProcessStep.error)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: SelectableText(
                    "فشل التحليل. التفاصيل:\n\n$_statusMessage",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),

          // حالة الصورة غير المدعومة
          if (_currentStep == ProcessStep.complete &&
              _isUnsupportedImage)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.orangeAccent,
                      size: 75,
                    ),

                    SizedBox(height: 20),

                    Text(
                      "صورة غير مدعومة",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 12),

                    Text(
                      "يرجى اختيار صورة أشعة من الأنواع "
                      "الطبية المدعومة.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // نوع الأشعة المكتشف
          if (_routerResult != null &&
              !_isUnsupportedImage)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "نوع الأشعة المكتشف:",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 4),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cyanAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.cyanAccent,
                    ),
                  ),

                  child: Text(
                    "${_routerResult!.label} "
                    "(ثقة: ${(_routerResult!.confidence * 100).toStringAsFixed(1)}%)",
                    style: const TextStyle(
                      color: AppColors.cyanAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),

          // النتائج التشخيصية
          if (_finalResults != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "أفضل 3 احتمالات تشخيصية:",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: ListView.builder(
                      itemCount: _finalResults!.length,
                      itemBuilder: (context, index) {
                        final result = _finalResults![index];

                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: 16,
                          ),

                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                ],
              ),
            )

          // مؤشر التحميل
          else if (_currentStep != ProcessStep.idle &&
              _currentStep != ProcessStep.error &&
              !_isUnsupportedImage &&
              _currentStep != ProcessStep.complete)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.cyanAccent,
                ),
              ),
            ),


          // Grad-CAM button is displayed only for completed Chest diagnostics.
          if (_routerResult?.label.trim().toLowerCase() == 'chest' &&
              _finalResults != null &&
              _finalResults!.isNotEmpty &&
              _currentStep == ProcessStep.complete) ...[
            const Divider(color: Colors.white24, height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingChestGradCam ||
                        _lastInputTensor == null
                    ? null
                    : _generateChestGradCam,
                icon: _isGeneratingChestGradCam
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.local_fire_department_outlined),
                label: Text(
                  _isGeneratingChestGradCam
                      ? 'جاري إنشاء الخريطة الحرارية...'
                      : 'عرض خريطة Grad-CAM',
                ),
              ),
            ),
            if (_chestGradCamError != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                _chestGradCamError!,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                ),
              ),
            ],
          ],

          // زر الطباعة: يظهر فقط عند وجود نتائج فعلية
          if (_finalResults != null &&
              _finalResults!.isNotEmpty &&
              _currentStep == ProcessStep.complete &&
              !_isUnsupportedImage) ...[
            const Divider(
              color: Colors.white24,
              height: 32,
            ),

            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    showCustomDialogue = true;
                  });
                },

                child: const Text(
                  "Print",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
