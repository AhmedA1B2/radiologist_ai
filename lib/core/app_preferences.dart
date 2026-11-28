import 'dart:convert';
import 'dart:io';

/// Centralized application preferences persisted on the current device.
class AppPreferences {
  AppPreferences._();

  static bool includeXrayImageInPdf = true;
  static bool includeGradCamInPdf = false;
  static bool showModelScores = true;
  static bool confirmBeforeDelete = true;

  // Serialize writes so rapid switches cannot overwrite a newer preference
  // with an older asynchronous file operation.
  static Future<void> _saveQueue = Future<void>.value();

  static String _join(String first, String second) =>
      first + Platform.pathSeparator + second;

  static Future<File> _settingsFile() async {
    String? baseDirectory;

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      final userProfile = Platform.environment['USERPROFILE'];

      if (appData != null && appData.trim().isNotEmpty) {
        baseDirectory = appData;
      } else if (userProfile != null && userProfile.trim().isNotEmpty) {
        baseDirectory = userProfile;
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.trim().isNotEmpty) {
        baseDirectory = _join(
          _join(home, 'Library'),
          'Application Support',
        );
      }
    } else {
      final configHome = Platform.environment['XDG_CONFIG_HOME'];
      if (configHome != null && configHome.trim().isNotEmpty) {
        baseDirectory = configHome;
      } else {
        final home = Platform.environment['HOME'];
        if (home != null && home.trim().isNotEmpty) {
          baseDirectory = _join(home, '.config');
        }
      }
    }

    baseDirectory ??= Directory.current.path;

    final directory = Directory(_join(baseDirectory, 'radiologist_ai'));
    await directory.create(recursive: true);
    return File(_join(directory.path, 'settings.json'));
  }

  /// Load saved preferences before the application UI is created.
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
    } on FormatException {
      // A damaged settings file must not prevent the app from starting.
      _restoreDefaultsInMemory();
    } on FileSystemException {
      // Keep the documented defaults when the settings directory is unavailable.
      _restoreDefaultsInMemory();
    }
  }

  /// Persist a snapshot of the current settings.
  ///
  /// Errors are intentionally propagated so the Settings page can notify the
  /// user and restore the previous switch value instead of showing a false save.
  static Future<void> save() {
    final encoded = const JsonEncoder.withIndent('  ').convert({
      'includeXrayImageInPdf': includeXrayImageInPdf,
      'includeGradCamInPdf': includeGradCamInPdf,
      'showModelScores': showModelScores,
      'confirmBeforeDelete': confirmBeforeDelete,
    });

    final operation = _saveQueue.then((_) async {
      final file = await _settingsFile();
      await file.writeAsString(encoded, flush: true);
    });

    // Keep the queue usable after a failed write, while returning the original
    // error to the caller.
    _saveQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return operation;
  }

  static void _restoreDefaultsInMemory() {
    includeXrayImageInPdf = true;
    includeGradCamInPdf = false;
    showModelScores = true;
    confirmBeforeDelete = true;
  }

  static Future<void> reset() async {
    _restoreDefaultsInMemory();
    await save();
  }
}
