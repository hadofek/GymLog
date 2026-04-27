import 'package:flutter/material.dart';

class WorkoutTypes {
  static const String weighted = 'weighted';
  static const String cardio = 'cardio';
  static const String bodyweight = 'bodyweight';
  static const String flexibility = 'flexibility';

  static const List<String> all = [weighted, cardio, bodyweight, flexibility];

  // Kinetic Obsidian workout-type colors
  static Color color(String type) {
    switch (type) {
      case cardio:
        return const Color(0xFF4AE176);
      case flexibility:
        return const Color(0xFFEC6A06);
      case bodyweight:
        return const Color(0xFF608BFF);
      default: // weighted
        return const Color(0xFF608BFF);
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
