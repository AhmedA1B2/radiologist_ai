import 'package:flutter/material.dart';

import 'package:radiologist_ai/core/theme/app_colors.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "لوحة التشخيص الطبي الرئيسية",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
        Text(
          "قم بإدراج صورة الأشعة وسيتكفل الذكاء الاصطناعي بالتوجيه والتشخيص.",
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
