import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:radiologist_ai/ai_processing/diagnostic_result.dart';
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

  final TextEditingController numController = TextEditingController();

  File? _selectedImage;
  ProcessStep _currentStep = ProcessStep.idle;
  String _statusMessage = "بانتظار الصورة...";

  DiagnosticResult? _routerResult;
  List<DiagnosticResult>? _finalResults;

  bool showCustomDialogue = false;

  /// يسجل الخطأ في stdout وFlutter Debug Console وسجل dart:developer.
  void _logDiagnosticError(String stage, Object error, StackTrace stackTrace) {
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
  ////////////////////////////////////////////////////////////
  ////////////////$$$$$$$$$$$$$$$PDF$$$$$$$$$$$$$$$$//////////
  ////////////////////////////////////////////////////////////

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
            // عنوان التقرير
            pw.Text(
              'Diagnostic Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 5),

            pw.Text(
              'Artificial Intelligence X-Ray Analysis',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
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
                child: pw.Image(xrayImage, fit: pw.BoxFit.contain),
              ),

              pw.SizedBox(height: 20),
            ],

            // نوع الأشعة
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
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
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
            if (_finalResults!.isNotEmpty)
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

      // ==============================
      // اختيار مكان حفظ الملف
      // ==============================

      String? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save Diagnostic Report',
        fileName: 'diagnostic_report.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath == null) {
        return null;
      }

      // =========================================
      // إصلاح مشكلة حذف امتداد PDF
      // =========================================

      if (!outputPath.toLowerCase().endsWith('.pdf')) {
        outputPath = '$outputPath.pdf';
      }

      final file = File(outputPath);

      final pdfBytes = await pdf.save();

      await file.writeAsBytes(pdfBytes, flush: true);

      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ التقرير بنجاح:\n$outputPath')),
      );

      return outputPath;
    } catch (e) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء إنشاء التقرير: $e')),
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
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  ////////////////$$$$$$$$$$$$$$$PDF$$$$$$$$$$$$$$$$//////////
  ////////////////////////////////////////////////////////////
  Future<void> _initializeSystem() async {
    try {
      print('[AI INIT] بدء تهيئة نموذج التوجيه...');
      debugPrint('[AI INIT] بدء تهيئة نموذج التوجيه...');
      developer.log('بدء تهيئة نموذج التوجيه', name: 'RadiologistAI.MainDashboard');

      await _aiService.initRouter();

      if (!mounted) return;
      setState(() {
        _currentStep = ProcessStep.idle;
        _statusMessage = "النظام جاهز (الموجه محمل)";
      });

      print('[AI INIT] تم تحميل نموذج التوجيه بنجاح.');
      debugPrint('[AI INIT] تم تحميل نموذج التوجيه بنجاح.');
    } catch (e, stackTrace) {
      _logDiagnosticError('AI INIT ERROR', e, stackTrace);

      if (!mounted) return;
      setState(() {
        _currentStep = ProcessStep.error;
        _statusMessage =
            'فشل تهيئة نظام الذكاء الاصطناعي.\nالخطأ: $e\n\nStackTrace:\n$stackTrace';
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
      } catch (e, stackTrace) {
        // هذا السجل يحدد الخطأ إن حدث أثناء المعالجة أو تشغيل أحد النماذج.
        _logDiagnosticError('AI ANALYSIS ERROR', e, stackTrace);

        if (!mounted) return;
        setState(() {
          _currentStep = ProcessStep.error;
          _statusMessage =
              'حدث خطأ أثناء تحليل الصورة.\nالخطأ: $e\n\nStackTrace:\n$stackTrace';
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
      body: Stack(
        children: [
          Row(
            children: [
              // القائمة الجانبية (Sidebar)
              Sidebar(),
              /////////////////////

              // المنطقة المركزية (Central Panel)
              Expanded(
                flex: 7,
                child: Container(
                  color: AppColors.navyDark,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /////////////////////
                      Header(),
                      /////////////////////
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
          showCustomDialogue == true
              ? CustomDialogue(
                  numController: numController,
                  iconOk: Icons.check_circle,
                  onPressediconOk: () async {
                    // التأكد من وجود صورة
                    if (_selectedImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select an X-ray image first'),
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
                      showCustomDialogue = false;
                      // 1. إنشاء وحفظ PDF
                      final String? pdfPath = await _saveDiagnosticAsPdf();

                      if (pdfPath == null) {
                        return;
                      }

                      // 2. إرسال PDF + صورة الأشعة إلى السيرفر
                      final success = await SendDiagnosis().addDiagnosi(
                        context,
                        numController.text.trim(),
                        DateTime.now().toString(),
                        pdfPath,
                        _selectedImage!.path,
                      );

                      // 3. إذا نجح الحفظ في قاعدة البيانات
                      if (success) {
                        setState(() {
                          showCustomDialogue = false;
                          numController.text = "";
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم حفظ التقرير والبيانات بنجاح'),
                          ),
                        );
                      }
                    } catch (e) {
                      print("Save diagnosis error: $e");

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('حدث خطأ أثناء حفظ التشخيص: $e'),
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
                )
              : const SizedBox(),
        ],
      ),
    );
  }

  // --- مكونات واجهة المستخدم (Widgets) ---

  Widget _buildFeet() {
    final List<String> sectionstext = [
      'brian',
      'chest',
      'teeth',
      'knee',
      'liver',
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
                  color: _routerResult != null
                      ? _routerResult!.label == sectionstext[index]
                            ? AppColors.cyanAccent
                            : Colors.white
                      : Colors.white, // خلفية خفيفة لكل عنصر (اختياري)
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min, // لجعل العنصر يأخذ مساحة محتواه فقط
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
                      style: const TextStyle(color: Colors.black),
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
          if (_finalResults != null) ...[
            const Divider(color: Colors.white24, height: 32),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    showCustomDialogue = true;
                    print("showCustomDialogue => true ");
                  });
                },
                child: Text(
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
