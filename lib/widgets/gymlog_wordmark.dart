import 'package:flutter/material.dart';
import 'package:gymlog/utils/app_colors.dart';

/// Canonical GYMLOG wordmark. Spec: Lexend w900 italic, 20sp, letterSpacing 3,
/// accentContainer color. Never alter size, weight, style, or color.
class GymlogWordmark extends StatelessWidget {
  const GymlogWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'GYMLOG',
      style: TextStyle(
        fontFamily: 'Lexend',
        fontSize: 20,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: 3,
        color: AppColors.accentContainer(context),
      ),
    );
  }
}
