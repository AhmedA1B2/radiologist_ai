import 'package:flutter/material.dart';
import 'package:radiologist_ai/core/theme/app_colors.dart';
import 'package:radiologist_ai/customs/custom_blur_background/custom_blur_background.dart';

class CustomDialogue extends StatefulWidget {
  const CustomDialogue({
    super.key,
    required this.iconOk,
    this.onPressediconOk,
    required this.iconNo,
    this.onPressediconNo,
    required this.text,
    required this.numController,
  });

  final IconData iconOk;
  final void Function()? onPressediconOk;
  final IconData iconNo;
  final void Function()? onPressediconNo;
  final String text;
  final TextEditingController numController;

  @override
  State<CustomDialogue> createState() => _CustomDialogueState();
}

class _CustomDialogueState extends State<CustomDialogue> {
  double dialogueAnimatedScale = 0.2;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        dialogueAnimatedScale = 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomBlurBackground(
      onTap: widget.onPressediconNo,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 400),
        curve: Curves.bounceOut,
        scale: dialogueAnimatedScale,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.5,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: AppColors.navyDark,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Text(
                          widget.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: AppColors.slateGrey,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: TextField(
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.navyDark),
                          controller: widget.numController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            filled: true,
                            fillColor: AppColors.slateGrey,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                              borderSide: BorderSide(
                                color: AppColors.cyanAccent,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          IconButton(
                            hoverColor: AppColors.cyanAccent,
                            padding: const EdgeInsets.all(0),
                            onPressed: widget.onPressediconOk,
                            icon: Icon(
                              widget.iconOk,
                              color: AppColors.slateGrey,
                              size: 48,
                            ),
                          ),
                          IconButton(
                            hoverColor: AppColors.red,
                            padding: const EdgeInsets.all(0),
                            onPressed: widget.onPressediconNo,
                            icon: Icon(
                              widget.iconNo,
                              color: AppColors.slateGrey,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
