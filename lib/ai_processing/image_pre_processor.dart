import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';


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
