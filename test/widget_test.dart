import 'package:flutter_test/flutter_test.dart';
import 'package:radiologist_ai/main.dart';

void main() {
  testWidgets('medical analysis app displays the login page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MedicalXRayApp());

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
