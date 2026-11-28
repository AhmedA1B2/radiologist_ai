import 'package:flutter/material.dart';
import 'package:radiologist_ai/body_of_main_view/sidebar.dart';
import 'package:radiologist_ai/core/app_preferences.dart';
import 'package:radiologist_ai/core/theme/app_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _saving = false;

  Future<void> _saveSetting(VoidCallback update) async {
    setState(() {
      update();
      _saving = true;
    });

    await AppPreferences.save();

    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _confirmReset() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'إعادة ضبط الإعدادات',
            style: TextStyle(
              color: AppColors.slateGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'ستعود الخيارات إلى قيمها الافتراضية. هل تريد المتابعة؟',
            style: TextStyle(color: AppColors.slateGrey, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('إعادة الضبط'),
            ),
          ],
        ),
      ),
    );

    if (shouldReset != true) return;

    setState(() => _saving = true);
    await AppPreferences.reset();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إعادة الإعدادات إلى القيم الافتراضية.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: Row(
        children: [
          const Sidebar(),
          Expanded(
            flex: 7,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(34, 30, 34, 34),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1150),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'إعدادات التطبيق',
                                    style: TextStyle(
                                      color: AppColors.slateGrey,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'تحكّم في طريقة عرض نتائج التحليل وتجهيز التقارير.',
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade500,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_saving)
                              const Tooltip(
                                message: 'جارٍ حفظ الإعدادات',
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.cyanAccent,
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                tooltip: 'إعادة ضبط الإعدادات',
                                onPressed: _confirmReset,
                                icon: const Icon(
                                  Icons.restart_alt_rounded,
                                  color: AppColors.cyanAccentDark,
                                  size: 28,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        _buildIntroCard(),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          icon: Icons.picture_as_pdf_outlined,
                          title: 'إعدادات التقارير',
                          subtitle: 'خيارات تؤثر في إنشاء التقارير وحفظها.',
                        ),
                        const SizedBox(height: 12),
                        _buildSettingTile(
                          icon: Icons.image_outlined,
                          title: 'إرفاق صورة الأشعة في ملف PDF',
                          description:
                              'عند التفعيل، تُضاف صورة الأشعة الأصلية المحددة إلى التقرير المُنشأ.',
                          value: AppPreferences.includeXrayImageInPdf,
                          onChanged: (value) => _saveSetting(
                            () => AppPreferences.includeXrayImageInPdf = value,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSettingTile(
                          icon: Icons.center_focus_strong_rounded,
                          title: 'إرفاق خريطة Grad-CAM في ملف PDF',
                          description:
                              'عند التفعيل، ينشئ النظام خريطة تفسير للنموذج المختص ويضيف صورة الإدخال مع الخريطة المركّبة واسم الطبقة إلى التقرير. يتطلب ملف Keras المطابق لكل تخصص، ويعمل حالياً على Windows فقط، وقد يزيد وقت إنشاء التقرير.',
                          value: AppPreferences.includeGradCamInPdf,
                          onChanged: (value) => _saveSetting(
                            () => AppPreferences.includeGradCamInPdf = value,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          icon: Icons.analytics_outlined,
                          title: 'عرض نتائج الذكاء الاصطناعي',
                          subtitle: 'خصّص المعلومات الظاهرة في لوحة التحليل.',
                        ),
                        const SizedBox(height: 12),
                        _buildSettingTile(
                          icon: Icons.percent_rounded,
                          title: 'إظهار درجات النموذج',
                          description:
                              'يعرض أو يخفي الدرجة الرقمية والمؤشر المرئي بجانب نتائج النموذج في لوحة التحليل. لا يغيّر هذا الخيار محتوى ملف PDF.',
                          value: AppPreferences.showModelScores,
                          onChanged: (value) => _saveSetting(
                            () => AppPreferences.showModelScores = value,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          icon: Icons.security_outlined,
                          title: 'إدارة السجلات',
                          subtitle: 'إعدادات تساعد على تجنّب الحذف غير المقصود.',
                        ),
                        const SizedBox(height: 12),
                        _buildSettingTile(
                          icon: Icons.delete_outline_rounded,
                          title: 'التأكيد قبل حذف التقرير',
                          description:
                              'عند التفعيل، تظهر نافذة تأكيد قبل إرسال طلب حذف التقرير من السجلات.',
                          value: AppPreferences.confirmBeforeDelete,
                          onChanged: (value) => _saveSetting(
                            () => AppPreferences.confirmBeforeDelete = value,
                          ),
                          warning: !AppPreferences.confirmBeforeDelete,
                        ),
                        const SizedBox(height: 24),
                        _buildNotice(),
                        const SizedBox(height: 22),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _confirmReset,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('استعادة الإعدادات الافتراضية'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.cyanAccentDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.slateGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cyanAccent.withOpacity(0.35)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Color(0x2638D9EC),
            child: Icon(
              Icons.tune_rounded,
              color: AppColors.cyanAccent,
              size: 30,
            ),
          ),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إعدادات تناسب طريقة عملك',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'تُحفظ الخيارات على هذا الجهاز وتُطبّق في الصفحات المرتبطة بها.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.cyanAccentDark, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.slateGrey,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.blueGrey.shade500, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool warning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: warning
                  ? AppColors.red.withOpacity(0.08)
                  : AppColors.cyanAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: warning ? AppColors.red : AppColors.cyanAccentDark,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.slateGrey,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.blueGrey.shade500,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            activeColor: AppColors.cyanAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNotice() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'تنبيه: درجات النموذج مؤشرات حسابية وليست احتمالات سريرية مؤكدة. يجب مراجعة الصور والنتائج من مختص مؤهل، ولا يُستخدم التطبيق وحده لاتخاذ قرار طبي.',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 13,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
