/// Shared exercise catalog used by AddExerciseScreen and ExerciseLibraryScreen.
class ExerciseData {
  static const Map<String, List<String>> weighted = {
    'Chest': [
      'Bench Press', 'Incline Bench Press', 'Decline Bench Press',
      'Dumbbell Bench Press', 'Incline Dumbbell Press',
      'Dumbbell Fly', 'Cable Fly', 'Push Up', 'Chest Dip', 'Pec Deck',
    ],
    'Back': [
      'Deadlift', 'Pull Up', 'Chin Up', 'Lat Pulldown',
      'Barbell Row', 'Dumbbell Row', 'Cable Row', 'T-Bar Row',
      'Face Pull', 'Straight-Arm Pulldown', 'Hyperextension',
    ],
    'Shoulders': [
      'Overhead Press', 'Dumbbell Shoulder Press', 'Arnold Press',
      'Lateral Raise', 'Front Raise', 'Rear Delt Fly',
      'Upright Row', 'Shrug', 'Cable Lateral Raise',
    ],
    'Biceps': [
      'Barbell Curl', 'Dumbbell Curl', 'Hammer Curl',
      'Preacher Curl', 'Concentration Curl', 'Cable Curl', 'Spider Curl',
    ],
    'Triceps': [
      'Tricep Pushdown', 'Skull Crusher', 'Close-Grip Bench Press',
      'Overhead Tricep Extension', 'Tricep Dip', 'Diamond Push Up',
    ],
    'Legs': [
      'Squat', 'Front Squat', 'Hack Squat', 'Goblet Squat',
      'Leg Press', 'Leg Extension', 'Leg Curl', 'Romanian Deadlift',
      'Lunge', 'Bulgarian Split Squat', 'Calf Raise',
    ],
    'Glutes': [
      'Hip Thrust', 'Glute Bridge', 'Sumo Deadlift',
      'Sumo Squat', 'Cable Kickback', 'Donkey Kick',
    ],
    'Core': [
      'Plank', 'Side Plank', 'Crunch', 'Sit Up', 'Leg Raise',
      'Russian Twist', 'Ab Wheel Rollout', 'Cable Crunch',
      'Hanging Knee Raise', 'Bicycle Crunch',
    ],
  };

  static const Map<String, List<String>> bodyweight = {
    'Chest': [
      'Push Up', 'Wide Push Up', 'Decline Push Up', 'Chest Dip',
      'Pike Push Up', 'Diamond Push Up',
    ],
    'Back': [
      'Pull Up', 'Chin Up', 'Inverted Row', 'Hyperextension', 'Superman',
    ],
    'Shoulders': [
      'Pike Push Up', 'Handstand Push Up', 'Shoulder Tap',
    ],
    'Biceps': [
      'Chin Up', 'Inverted Curl',
    ],
    'Triceps': [
      'Tricep Dip', 'Bench Dip', 'Diamond Push Up', 'Close Grip Push Up',
    ],
    'Legs': [
      'Squat', 'Jump Squat', 'Lunge', 'Bulgarian Split Squat',
      'Pistol Squat', 'Step Up', 'Wall Sit', 'Calf Raise',
    ],
    'Glutes': [
      'Glute Bridge', 'Hip Thrust', 'Donkey Kick', 'Fire Hydrant', 'Sumo Squat',
    ],
    'Core': [
      'Plank', 'Side Plank', 'Crunch', 'Sit Up', 'Leg Raise',
      'Russian Twist', 'Ab Wheel Rollout', 'Hanging Knee Raise',
      'Bicycle Crunch', 'Mountain Climber', 'L-sit',
    ],
  };

  /// All exercises from both libraries merged and deduplicated per category.
  static Map<String, List<String>> get full {
    final result = <String, List<String>>{};
    final allCategories = {...weighted.keys, ...bodyweight.keys};
    for (final cat in allCategories) {
      final seen = <String>{};
      final merged = <String>[];
      for (final name in [...?weighted[cat], ...?bodyweight[cat]]) {
        if (seen.add(name.toLowerCase())) merged.add(name);
      }
      merged.sort();
      result[cat] = merged;
    }
    return result;
  }

  /// Flat list of all unique exercise names across both libraries.
  static List<String> get allNames {
    final seen = <String>{};
    return full.values
        .expand((list) => list)
        .where((name) => seen.add(name.toLowerCase()))
        .toList();
  }

  /// Returns the muscle group category for a known exercise, or null if not found.
  /// Category names match the keys in [full] (e.g. 'Chest', 'Back', 'Legs').
  static String? muscleGroupFor(String exerciseName) {
    final lower = exerciseName.toLowerCase().trim();
    for (final entry in full.entries) {
      if (entry.value.any((e) => e.toLowerCase() == lower)) {
        return entry.key;
      }
    }
    return null;
  }
}
