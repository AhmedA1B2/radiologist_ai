import 'package:flutter/material.dart';
import 'package:radiologist_ai/core/theme/app_colors.dart';
import 'package:radiologist_ai/main.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final List<String> sectionstext = [
    'x-ray',
    'report',
    'settings',
    'information',
    'records',
  ];

  final List<String> sectionsimg = [
    'assets/imgs/xray.png',
    'assets/imgs/report.png',
    'assets/imgs/settings.png',
    'assets/imgs/i.png',
    'assets/imgs/records.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Container(
        color: AppColors.slateGrey,
        child: Column(
          children: [
            const SizedBox(height: 40),
            // الشعار (تأكد من وجود الصورة أو استخدم أيقونة)
            const Icon(Icons.biotech, size: 64, color: AppColors.cyanAccent),
            const SizedBox(height: 16),
            const Text(
              "X-Ray AI\nDiagnostics",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 40),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView.builder(
                itemCount: sectionstext.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        thisIndex = index;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: thisIndex == index
                            ? inkWellColor = AppColors.cyanAccent
                            : inkWellColor = AppColors.slateGrey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        spacing: 10,
                        children: [
                          Text(
                            "${index + 1}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(
                            width: 36,
                            child: Image.asset(
                              sectionsimg[index],
                              fit: BoxFit.contain,
                            ),
                          ),
                          Text(
                            sectionstext[index],
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
