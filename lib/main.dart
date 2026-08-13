import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const BrainScannerApp());
}

class BrainScannerApp extends StatelessWidget {
  const BrainScannerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'X-Ray AI Analyzer',
      theme: ThemeData(primarySwatch: Colors.blueGrey, useMaterial3: true),
      home: const BrainScannerHome(),
    );
  }
}

class BrainScannerHome extends StatefulWidget {
  const BrainScannerHome({Key? key}) : super(key: key);

  @override
  State<BrainScannerHome> createState() => _BrainScannerHomeState();
}

class _BrainScannerHomeState extends State<BrainScannerHome> {
  Interpreter? _interpreter;
  List<String>? _labels;
  File? _selectedImage;
  String _resultText = "في انتظار اختيار الصورة...";
  bool _isProcessing = false;

  // أبعاد الصورة التي يتوقعها النموذج
  static const int inputSize = 224;

  @override
  void initState() {
    super.initState();
    _loadModelAndLabels();
  }

  // 1. تحميل النموذج والملصقات
  Future<void> _loadModelAndLabels() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/ai_model/brain_model/brain_model.tflite',
      );

      final String labelsData = await rootBundle.loadString(
        'assets/ai_model/brain_model/brain_labels.json',
      );

      final List<dynamic> jsonList = json.decode(labelsData);
      _labels = jsonList.map((e) => e.toString()).toList();

      setState(() {
        _resultText = "النموذج جاهز للاختبار.";
        print(_resultText);
      });
    } catch (e) {
      setState(() {
        _resultText = "خطأ في تحميل النموذج: $e";
        print(_resultText);
      });
    }
  }

  // 2. اختيار الصورة من جهاز الكمبيوتر
  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedImage = File(result.files.single.path!);
        _resultText = "جاري التحليل...";
        _isProcessing = true;
      });

      // หน่วง وقت بسيط للسماح للواجهة بالتحديث قبل بدء التحليل الثقيل
      await Future.delayed(const Duration(milliseconds: 100));
      _analyzeImage(_selectedImage!);
    }
  }

  // 3. معالجة الصورة وتحليلها
  Future<void> _analyzeImage(File imageFile) async {
    if (_interpreter == null || _labels == null) {
      setState(() {
        _resultText = "النموذج غير محمل بعد.";
        _isProcessing = false;
      });
      return;
    }

    try {
      // قراءة الصورة كبايتات
      final imageBytes = await imageFile.readAsBytes();
      // فك تشفير الصورة
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) throw Exception("لا يمكن قراءة الصورة.");

      // تغيير حجم الصورة لتطابق مدخلات النموذج
      img.Image resizedImage = img.copyResize(
        originalImage,
        width: inputSize,
        height: inputSize,
      );

      // تحويل الصورة إلى مصفوفة (Tensor)
      var input = List.generate(
        1,
        (i) => List.generate(
          inputSize,
          (y) => List.generate(inputSize, (x) {
            final pixel = resizedImage.getPixel(x, y);

            // إرسال القيم الخام تماماً كما هي بناءً على طبيعة تدريب نموذجك
            return [pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()];
          }),
        ),
      );

      // مصفوفة المخرجات
      final output = List.generate(1, (_) => List.filled(_labels!.length, 0.0));

      // تشغيل النموذج
      _interpreter!.run(input, output);

      // استخراج النتيجة الخام
      List<double> rawOutput = (output[0] as List).cast<double>();

      List<double> probabilities = rawOutput;

      final results = List.generate(
        probabilities.length,
        (i) => MapEntry(i, probabilities[i]),
      );

      results.sort((a, b) => b.value.compareTo(a.value));

      final top3 = results.take(3).toList();

      StringBuffer buffer = StringBuffer();

      buffer.writeln("أفضل 3 احتمالات:\n");

      for (int i = 0; i < top3.length; i++) {
        buffer.writeln(
          "${i + 1}. ${_labels![top3[i].key]} "
          "(${(top3[i].value * 100).toStringAsFixed(2)}%)",
        );
      }

      setState(() {
        _resultText = buffer.toString();
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _resultText = "حدث خطأ أثناء التحليل: $e";
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محلل أشعة الدماغ (AI)'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // عرض الصورة
              Container(
                height: 300,
                width: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : const Center(child: Text('لم يتم تحديد صورة')),
              ),
              const SizedBox(height: 30),

              // زر اختيار الصورة
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickImage,
                icon: const Icon(Icons.image_search),
                label: const Text('اختر صورة أشعة من الجهاز'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // عرض النتيجة
              _isProcessing
                  ? const CircularProgressIndicator()
                  : Text(
                      _resultText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
