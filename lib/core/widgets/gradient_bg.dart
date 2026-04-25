import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable gradient background — matches existing app's dark teal gradient.
class GradientBg extends StatelessWidget {
  const GradientBg({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.mainGradient),
    );
  }
}

/// Wrap any Scaffold body with this for the standard gradient background.
Widget gradientBgWidget() => Container(
  decoration: const BoxDecoration(gradient: AppColors.mainGradient),
);
