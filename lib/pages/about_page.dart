import 'package:flutter/material.dart';
import 'package:radiologist_ai/body_of_main_view/sidebar.dart';
import 'package:radiologist_ai/core/theme/app_colors.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
                padding: const EdgeInsets.fromLTRB(34, 30, 34, 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1150),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'معلومات التطبيق',
                          style: TextStyle(
                            color: AppColors.slateGrey,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تعرف على النظام، طريقة عمله، وحدود استخدام نتائجه.',
                          style: TextStyle(
                            color: Colors.blueGrey.shade500,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _buildHero(),
                        const SizedBox(height: 26),
                        _buildSectionHeading('نبذة عن النظام', Icons.info_outline),
                        const SizedBox(height: 12),
                        _buildTextCard(
                          'Radiologist AI هو تطبيق بحثي يستخدم نماذج تعلم آلي لتصنيف الصور الطبية المدخلة، ثم يعرض النتائج التي تنتجها النماذج وينشئ تقريرًا بصيغة PDF. صُمم التطبيق لعرض خطوات المعالجة والنتائج بطريقة منظمة، وليس ليحل محل اختصاصي الأشعة أو الطبيب.',
                        ),
                        const SizedBox(height: 26),
                        _buildSectionHeading('الوظائف الرئيسية', Icons.grid_view_rounded),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = constraints.maxWidth >= 850
                                ? (constraints.maxWidth - 36) / 3
                                : constraints.maxWidth >= 540
                                    ? (constraints.maxWidth - 18) / 2
                                    : constraints.maxWidth;
                            return Wrap(
                              spacing: 18,
                              runSpacing: 18,
                              children: [
                                _featureCard(
                                  width: cardWidth,
                                  icon: Icons.image_search_outlined,
                                  title: 'إدخال الصور',
                                  description:
                                      'اختيار صورة من الجهاز بصيغ الصور المدعومة في واجهة التطبيق مثل JPG وPNG.',
                                ),
                                _featureCard(
                                  width: cardWidth,
                                  icon: Icons.hub_outlined,
                                  title: 'توجيه النموذج',
                                  description:
                                      'يحدد نموذج التوجيه التصنيف المرشح، ثم يُحمّل النموذج التخصصي المرتبط به.',
                                ),
                                _featureCard(
                                  width: cardWidth,
                                  icon: Icons.analytics_outlined,
                                  title: 'عرض النتائج',
                                  description:
                                      'عرض التصنيفات الأعلى ترتيبًا ودرجات النماذج عند تفعيلها من الإعدادات.',
                                ),
                                _featureCard(
                                  width: cardWidth,
                                  icon: Icons.picture_as_pdf_outlined,
                                  title: 'إنشاء تقرير PDF',
                                  description:
                                      'تجهيز تقرير يتضمن معلومات التحليل والنتائج، مع إمكانية إرفاق الصورة الأصلية.',
                                ),
                                _featureCard(
                                  width: cardWidth,
                                  icon: Icons.folder_shared_outlined,
                                  title: 'سجلات التقارير',
                                  description:
                                      'استعراض السجلات المتاحة عبر واجهة الخادم، وفتح التقارير أو حذفها بحسب الصلاحيات.',
                                ),
                                _featureCard(
                                  width: cardWidth,
                                  icon: Icons.tune_rounded,
                                  title: 'إعدادات قابلة للتخصيص',
                                  description:
                                      'التحكم في إرفاق الصور وإظهار درجات النموذج والتأكيد قبل حذف السجلات.',
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        _buildSectionHeading('كيف تتم المعالجة؟', Icons.account_tree_outlined),
                        const SizedBox(height: 12),
                        _buildWorkflow(),
                        const SizedBox(height: 28),
                        _buildSectionHeading('التصنيفات المرتبطة بالنماذج', Icons.category_outlined),
                        const SizedBox(height: 12),
                        _buildCategoryCard(),
                        const SizedBox(height: 28),
                        _buildSectionHeading('التقنيات المستخدمة', Icons.memory_outlined),
                        const SizedBox(height: 12),
                        _buildTechnologyCard(),
                        const SizedBox(height: 26),
                        _buildMedicalNotice(),
                        const SizedBox(height: 18),
                        const Center(
                          child: Text(
                            'RADIOLOGIST AI  •  نموذج بحثي وتجريبي',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
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

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.slateGrey, AppColors.cyanAccentDark],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanAccentDark.withOpacity(0.15),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final icon = Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.cyanAccent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cyanAccent.withOpacity(0.6)),
            ),
            child: const Icon(
              Icons.biotech_rounded,
              color: AppColors.cyanAccent,
              size: 42,
            ),
          );
          final content = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RADIOLOGIST AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 9),
              Text(
                'نظام لتصنيف الصور الطبية بمساعدة الذكاء الاصطناعي',
                style: TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              SizedBox(height: 15),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroTag(text: 'نسخة بحثية وتجريبية'),
                  _HeroTag(text: 'Flutter · TensorFlow Lite'),
                ],
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [icon, const SizedBox(height: 20), content],
            );
          }
          return Row(
            children: [
              icon,
              const SizedBox(width: 22),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeading(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.cyanAccentDark, size: 24),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.slateGrey,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextCard(String text) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.blueGrey.shade700,
          fontSize: 15,
          height: 1.9,
        ),
      ),
    );
  }

  Widget _featureCard({
    required double width,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 172),
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cyanAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.cyanAccentDark, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.slateGrey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.blueGrey.shade500,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflow() {
    const steps = [
      (
        '01',
        'اختيار الصورة',
        'تحديد صورة طبية من الملفات المحلية المدعومة.',
        Icons.file_open_outlined,
      ),
      (
        '02',
        'التحضير والتصنيف الأولي',
        'تجهيز أبعاد الصورة وتمريرها إلى نموذج التوجيه.',
        Icons.center_focus_strong_outlined,
      ),
      (
        '03',
        'تشغيل النموذج التخصصي',
        'تحميل النموذج المرتبط بالتصنيف وتشغيل الاستدلال.',
        Icons.memory_rounded,
      ),
      (
        '04',
        'عرض النتائج والتقرير',
        'عرض التسميات الأعلى ترتيبًا وإتاحة تجهيز تقرير PDF.',
        Icons.description_outlined,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cyanAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    steps[i].$1,
                    style: const TextStyle(
                      color: AppColors.cyanAccentDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].$2,
                        style: const TextStyle(
                          color: AppColors.slateGrey,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        steps[i].$3,
                        style: TextStyle(
                          color: Colors.blueGrey.shade500,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(steps[i].$4, color: AppColors.cyanAccentDark, size: 23),
              ],
            ),
            if (i != steps.length - 1)
              const Padding(
                padding: EdgeInsetsDirectional.only(start: 20, top: 13, bottom: 13),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 18,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    const categories = [
      'Brain',
      'Chest',
      'Elbow',
      'Finger',
      'Forearm',
      'Hand',
      'Humerus',
      'Knee',
      'Liver',
      'Shoulder',
      'Teeth',
      'Wrist',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'هذه هي أسماء التصنيفات المرتبطة بخريطة النماذج في الكود. وجود التصنيف لا يعني أن النموذج قد خضع لتحقق سريري أو أن كل فئة تمثل صورة أشعة تقليدية؛ يجب مطابقة نوع الصورة مع بيانات النموذج قبل الاستخدام.',
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: 13,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: categories
                .map(
                  (category) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cyanAccent.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.cyanAccent.withOpacity(0.25),
                      ),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: AppColors.cyanAccentDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnologyCard() {
    const technologies = [
      ('Flutter / Dart', 'بناء واجهة التطبيق وتجربة الاستخدام.'),
      ('TensorFlow Lite', 'تشغيل نماذج التصنيف داخل التطبيق.'),
      ('PDF', 'تجهيز التقارير التشخيصية بصيغة PDF.'),
      ('PHP / MySQL API', 'واجهة خادم لإرسال السجلات واسترجاعها وفق إعداد الخادم.'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: technologies
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.cyanAccentDark,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: const TextStyle(
                              color: AppColors.slateGrey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            style: TextStyle(
                              color: Colors.blueGrey.shade500,
                              height: 1.5,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMedicalNotice() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            color: Color(0xFFC2410C),
            size: 30,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه طبي مهم',
                  style: TextStyle(
                    color: Color(0xFF9A3412),
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'هذا التطبيق نموذج بحثي وتجريبي. مخرجاته ودرجاته لا تمثل تشخيصًا طبيًا نهائيًا، ولم يثبت من المعلومات المتاحة أنه خضع للتحقق السريري أو حصل على اعتماد طبي. يجب أن يراجع مختص مؤهل الصور والنتائج قبل أي قرار سريري، ولا ينبغي استخدام التطبيق منفردًا لاتخاذ قرارات العلاج.',
                  style: TextStyle(
                    color: Color(0xFF9A3412),
                    height: 1.8,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.025),
          blurRadius: 13,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}
