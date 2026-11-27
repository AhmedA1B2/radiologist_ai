import 'dart:io';

import 'package:flutter/material.dart';
import 'package:radiologist_ai/ai_processing/explainability_service.dart';

class MedicalHeatmapView extends StatefulWidget {
  final ChestGradCamResult result;

  const MedicalHeatmapView({
    super.key,
    required this.result,
  });

  @override
  State<MedicalHeatmapView> createState() => _MedicalHeatmapViewState();
}

class _MedicalHeatmapViewState extends State<MedicalHeatmapView> {
  double _opacity = 0.62;
  bool _showHeatmap = true;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التفسير البصري — Chest Grad-CAM'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Center(
              child: Text(
                result.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            alignment: WrapAlignment.spaceAround,
                            spacing: 20,
                            runSpacing: 12,
                            children: [
                              _InfoValue(
                                title: 'الفئة التي جرى تفسيرها',
                                value: result.label,
                              ),
                              _InfoValue(
                                title: 'ثقة Keras',
                                value: (result.confidence * 100).toStringAsFixed(2) + '%',
                              ),
                              _InfoValue(
                                title: 'الطبقة',
                                value: result.layerName,
                              ),
                              _InfoValue(
                                title: 'أبعاد خريطة الخصائص',
                                value: result.featureMapShape.join(' × '),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'صورة الإدخال والخريطة الحرارية',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const Text('عرض الخريطة'),
                                  Switch(
                                    value: _showHeatmap,
                                    onChanged: (value) {
                                      setState(() => _showHeatmap = value);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: 700,
                                    maxHeight: constraints.maxHeight * 0.72,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: InteractiveViewer(
                                      minScale: 1,
                                      maxScale: 5,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.file(
                                            File(result.modelInputPath),
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, error, __) =>
                                                _ImageError(message: error.toString()),
                                          ),
                                          if (_showHeatmap)
                                            Opacity(
                                              opacity: _opacity,
                                              child: Image.file(
                                                File(result.heatmapPath),
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, error, __) =>
                                                    _ImageError(message: error.toString()),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_showHeatmap) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text('شفافية الخريطة'),
                                    Expanded(
                                      child: Slider(
                                        value: _opacity,
                                        min: 0,
                                        max: 1,
                                        divisions: 20,
                                        label: (_opacity * 100).round().toString() + '%',
                                        onChanged: (value) {
                                          setState(() => _opacity = value);
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: 48,
                                      child: Text(
                                        (_opacity * 100).round().toString() + '%',
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            result.warning,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ملاحظة: تُعرض هنا الصورة بعد تجهيزها بالحجم 224×224 كما استُخدمت في التصنيف، لضمان تطابق مواضع الخريطة. Grad-CAM يوضح مناطق ساهمت في قرار النموذج ولا يحدد حدود الإصابة بدقة.',
                        textAlign: TextAlign.start,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoValue extends StatelessWidget {
  final String title;
  final String value;

  const _InfoValue({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ImageError extends StatelessWidget {
  final String message;

  const _ImageError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'تعذّر عرض الصورة: ' + message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
