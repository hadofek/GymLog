import 'package:flutter/material.dart';
import 'package:gymlog/utils/app_colors.dart';

class WorkoutTypes {
  static const String weighted = 'weighted';
  static const String cardio = 'cardio';
  static const String bodyweight = 'bodyweight';
  static const String flexibility = 'flexibility';

  static const List<String> all = [weighted, cardio, bodyweight, flexibility];

  static Color color(String type, BuildContext ctx) {
    final isDark = AppColors.isDark(ctx);
    switch (type) {
      case cardio:
        return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      case bodyweight:
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
      case flexibility:
        return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
      default: // weighted
        return isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
    }
  }

  static IconData icon(String type) {
    switch (type) {
      case cardio:
        return Icons.directions_run_rounded;
      case bodyweight:
        return Icons.accessibility_new_rounded;
      case flexibility:
        return Icons.self_improvement_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  static String label(String type) {
    switch (type) {
      case cardio:
        return 'Cardio';
      case bodyweight:
        return 'Bodyweight';
      case flexibility:
        return 'Flexibility';
      default:
        return 'Weighted';
    }
  }
}
