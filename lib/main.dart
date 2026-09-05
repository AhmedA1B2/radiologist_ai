import 'package:flutter/material.dart';
import 'package:radiologist_ai/auth/log_in.dart';
import 'package:radiologist_ai/core/theme/app_colors.dart';
import 'package:radiologist_ai/dashboard/main_dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedicalXRayApp());
}

Color inkWellColor = AppColors.slateGrey;
int thisIndex = 0;

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
      home: const LoginPage(),
      routes: {"main_dashboard": (context) => const MainDashboard()},
    );
  }
}
