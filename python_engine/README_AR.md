# دمج Grad-CAM لنموذج Chest في Radiologist AI

## ما الذي يفعله هذا المكوّن؟
يضيف زرًا اختيارياً بعد اكتمال تشخيص Chest في Flutter. عند الضغط عليه يأخذ نفس Tensor الذي أرسله Flutter إلى TFLite (RGB، أبعاد 224×224، قيم 0..255)، ويكتبه مؤقتاً كقيم float32 little-endian، ثم يشغّل محرك Python محلياً على Windows. يحسب المحرك Grad-CAM باستخدام ملف Keras الأصلي، ويتحقق أن أعلى فئة في Keras تطابق الفئة التي اختارها TFLite، ثم يعيد خريطة حرارية شفافة وصورة الإدخال المطابقة لما شاهده النموذج.

لا يُستبدل نموذج TFLite ولا تتغير عملية التشخيص الحالية.

## الإعداد للمطور على Windows
1. ثبّت Python 3.12 (64-bit) كخيار مفضل، أو Python 3.10 أو 3.11 أو 3.13.
2. افتح مجلد المشروع python_engine.
3. شغّل setup_windows.bat. التثبيت الأول لمكتبات TensorFlow وPillow يحتاج إنترنت.
4. تأكد من وجود Microsoft Visual C++ Redistributable إذا ظهرت أخطاء DLL عند استيراد TensorFlow.\n5. انسخ chest_model.keras إلى python_engine/models/chest_model.keras.
6. شغّل تطبيق Flutter على Windows.

في وضع التطوير يستخدم Flutter تلقائياً:
python_engine/.venv/Scripts/python.exe

إذا لم تكن البيئة الافتراضية موجودة، يحاول استخدام الأمر python من PATH.

## المخرجات
تُحفظ الملفات في مجلد مؤقت على Windows: model_input.png وheatmap.png وresult.json. يعرض التطبيق صورة الإدخال التي استخدمها النموذج مع طبقة Grad-CAM، ويمكن التحكم في شفافية الخريطة.

## حدود مهمة
- هذه النسخة مخصصة للاختبار على Windows Desktop.
- Python/TensorFlow يجب أن يكونا مثبتين محلياً في هذه المرحلة. لم يتم تضمين Python في ملف تثبيت التطبيق.
- ملف Keras الكبير لا يُضاف إلى Git. يجب وضعه يدوياً في المسار المذكور.
- إذا اختلف أعلى تصنيف Keras عن التصنيف الذي أعاده TFLite، يوقف المحرك عرض الخريطة لتجنب تفسير قرار مختلف.
- Grad-CAM تفسير بصري تقريبي، وليس تحديداً دقيقاً لحدود المرض أو تشخيصاً طبياً مستقلاً.

## خطوات تشغيل الاختبار داخل المشروع الفعلي

من نافذة PowerShell، افتح مجلد المشروع الذي يحتوي على pubspec.yaml ثم نفّذ:

```powershell
git switch feature/chest-gradcam-windows
flutter pub get
```

ضع نموذج Keras في المسار التالي بالضبط:

```
python_engine/models/chest_model.keras
```

ثم شغّل:

```powershell
cd python_engine
.\setup_windows.bat
cd ..
flutter run -d windows
```

بعد فتح البرنامج:
1. اختر صورة أشعة صدر مدعومة.
2. انتظر انتهاء التشخيص وظهور نتائج Chest.
3. اضغط زر "عرض خريطة Grad-CAM".
4. انتظر إعادة تشغيل TFLite من Python ومقارنة نتيجته بنتيجة Keras، ثم حساب الخريطة. قد يستغرق ذلك وقتاً أطول من التصنيف العادي.
5. استخدم شريط الشفافية وقارن الخريطة مع صورة الإدخال.

إذا لم يتعرف التطبيق على Python، افتح PowerShell من مجلد المشروع واضبط المتغير قبل التشغيل:

```powershell
$env:RADIOLOGIST_AI_PYTHON = "C:\Users\YOUR_USER\AppData\Local\Programs\Python\Python312\python.exe"
flutter run -d windows
```

استبدل المسار بمسار Python الفعلي على جهازك.

**تنبيه توافق:** هذه الإضافة تستخدم Python/TensorFlow محلياً أثناء التطوير. ليست بعد حزمة مستقلة للمستخدم النهائي؛ عند تجهيز نسخة Release يجب تضمين Python والاعتماديات وملف Keras ضمن حزمة Windows. تثبيت TensorFlow على Windows يستخدم المعالجة المركزية CPU، ولا تعتمد هذه النسخة على CUDA.
