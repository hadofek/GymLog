import 'package:flutter/material.dart';
import 'package:gymlog/utils/app_colors.dart';

class WorkoutTypes {
  static const String weighted = 'weighted';
  static const String cardio = 'cardio';
  static const String bodyweight = 'bodyweight';
  static const String flexibility = 'flexibility';

  static const List<String> all = [weighted, cardio, bodyweight, flexibility];

  static Color color(String type, BuildContext ctx) =>
      AppColors.accentContainer(ctx);

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
