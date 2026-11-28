import 'package:flutter_test/flutter_test.dart';
import 'package:radiologist_ai/core/app_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await AppPreferences.reset();
  });

  test('all preferences persist and are restored by load()', () async {
    AppPreferences.includeXrayImageInPdf = false;
    AppPreferences.includeGradCamInPdf = true;
    AppPreferences.showModelScores = false;
    AppPreferences.confirmBeforeDelete = false;

    await AppPreferences.save();

    AppPreferences.includeXrayImageInPdf = true;
    AppPreferences.includeGradCamInPdf = false;
    AppPreferences.showModelScores = true;
    AppPreferences.confirmBeforeDelete = true;

    await AppPreferences.load();

    expect(AppPreferences.includeXrayImageInPdf, isFalse);
    expect(AppPreferences.includeGradCamInPdf, isTrue);
    expect(AppPreferences.showModelScores, isFalse);
    expect(AppPreferences.confirmBeforeDelete, isFalse);
  });

  test('reset persists the documented defaults', () async {
    AppPreferences.includeXrayImageInPdf = false;
    AppPreferences.includeGradCamInPdf = true;
    AppPreferences.showModelScores = false;
    AppPreferences.confirmBeforeDelete = false;

    await AppPreferences.reset();

    AppPreferences.includeXrayImageInPdf = false;
    AppPreferences.includeGradCamInPdf = true;
    AppPreferences.showModelScores = false;
    AppPreferences.confirmBeforeDelete = false;

    await AppPreferences.load();

    expect(AppPreferences.includeXrayImageInPdf, isTrue);
    expect(AppPreferences.includeGradCamInPdf, isFalse);
    expect(AppPreferences.showModelScores, isTrue);
    expect(AppPreferences.confirmBeforeDelete, isTrue);
  });
}
