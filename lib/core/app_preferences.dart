import 'dart:convert';
import 'dart:io';

/// إعدادات التطبيق المشتركة بين الصفحات.
/// تُحفظ في مجلد إعدادات المستخدم دون الحاجة إلى حزمة خارجية.
class AppPreferences {
  AppPreferences._();

  static bool includeXrayImageInPdf = true;
  static bool includeGradCamInPdf = false;
  static bool showModelScores = true;
  static bool confirmBeforeDelete = true;

  static Future<File> _settingsFile() async {
    String? baseDirectory;

    if (Platform.isWindows) {
      baseDirectory = Platform.environment['APPDATA'] ??
          Platform.environment['USERPROFILE'];
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        baseDirectory = '$home/Library/Application Support';
      }
    } else {
      baseDirectory = Platform.environment['XDG_CONFIG_HOME'];
      if (baseDirectory == null || baseDirectory.isEmpty) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          baseDirectory = '$home/.config';
        }
      }
    }

    // fallback نادر في حال عدم توفر متغيرات مجلد المستخدم.
    baseDirectory ??= Directory.current.path;

    final directory = Directory(
      '$baseDirectory${Platform.pathSeparator}radiologist_ai',
    );
    await directory.create(recursive: true);
    return File(
      '${directory.path}${Platform.pathSeparator}settings.json',
    );
  }

  static Future<void> load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) return;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;

      includeXrayImageInPdf = decoded['includeXrayImageInPdf'] is bool
          ? decoded['includeXrayImageInPdf'] as bool
          : true;
      includeGradCamInPdf = decoded['includeGradCamInPdf'] is bool
          ? decoded['includeGradCamInPdf'] as bool
          : false;
      showModelScores = decoded['showModelScores'] is bool
          ? decoded['showModelScores'] as bool
          : true;
      confirmBeforeDelete = decoded['confirmBeforeDelete'] is bool
          ? decoded['confirmBeforeDelete'] as bool
          : true;
    } catch (_) {
      // عند تعذّر قراءة الملف، يعمل التطبيق بالقيم الافتراضية.
    }
  }

  static Future<void> save() async {
    try {
      final file = await _settingsFile();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'includeXrayImageInPdf': includeXrayImageInPdf,
          'includeGradCamInPdf': includeGradCamInPdf,
          'showModelScores': showModelScores,
          'confirmBeforeDelete': confirmBeforeDelete,
        }),
        flush: true,
      );
    } catch (_) {
      // لا نوقف التطبيق إذا لم تتوفر صلاحية كتابة الإعدادات المحلية.
    }
  }

  static Future<void> reset() async {
    includeXrayImageInPdf = true;
    includeGradCamInPdf = false;
    showModelScores = true;
    confirmBeforeDelete = true;
    await save();
  }
}
