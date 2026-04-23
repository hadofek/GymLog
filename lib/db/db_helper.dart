import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = p.join(await getDatabasesPath(), 'gymlog.db');
    return openDatabase(path, version: 3, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE exercises (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          is_bodyweight INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE workouts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          duration_seconds INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE sets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          workout_id INTEGER NOT NULL,
          exercise_name TEXT NOT NULL,
          set_number INTEGER NOT NULL,
          weight REAL NOT NULL,
          reps INTEGER NOT NULL
        )
      ''');
    }, onUpgrade: (db, oldV, newV) async {
      if (oldV < 2) {
        try {
          await db.execute(
              'ALTER TABLE workouts ADD COLUMN duration_seconds INTEGER DEFAULT 0');
        } catch (_) {}
      }
      if (oldV < 3) {
        try {
          await db.execute(
              'ALTER TABLE exercises ADD COLUMN is_bodyweight INTEGER DEFAULT 0');
        } catch (_) {}
      }
    });
  }

  static Future<void> insertExercise(String name) async {
    final d = await db;
    await d.insert('exercises', {'name': name.trim()},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<List<String>> getExercises() async {
    final d = await db;
    final res = await d.query('exercises', orderBy: 'name');
    return res.map((e) => e['name'] as String).toList();
  }

  static Future<List<Map<String, dynamic>>> getExercisesWithType() async {
    final d = await db;
    return await d.query('exercises', orderBy: 'name');
  }

  static Future<bool> isExerciseBodyweight(String name) async {
    final d = await db;
    final res = await d.query('exercises',
        columns: ['is_bodyweight'],
        where: 'name = ?',
        whereArgs: [name.trim()]);
    if (res.isEmpty) return false;
    return (res.first['is_bodyweight'] as int? ?? 0) == 1;
  }

  static Future<void> setExerciseBodyweight(
      String name, bool isBodyweight) async {
    final d = await db;
    await d.insert(
      'exercises',
      {'name': name.trim(), 'is_bodyweight': isBodyweight ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> insertWorkout(String date, int durationSeconds) async {
    final d = await db;
    return await d.insert('workouts', {'date': date, 'duration_seconds': durationSeconds});
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}min';
    if (m > 0) return '${m}min';
    return '${s}s';
  }

  static Future<void> insertSet(int workoutId, String exerciseName,
      int setNumber, double weight, int reps) async {
    final d = await db;
    await d.insert('sets', {
      'workout_id': workoutId,
      'exercise_name': exerciseName,
      'set_number': setNumber,
      'weight': weight,
      'reps': reps,
    });
  }

  static Future<List<Map<String, dynamic>>> getWorkouts() async {
    final d = await db;
    final rows = await d.query('workouts');
    rows.sort((a, b) {
      final aDate = _parseWorkoutDate(a['date'] as String);
      final bDate = _parseWorkoutDate(b['date'] as String);
      return bDate.compareTo(aDate); // newest first
    });
    return rows;
  }

  static DateTime _parseWorkoutDate(String dateStr) {
    // format: "d/m/yyyy  hh:mm"
    try {
      final parts = dateStr.trim().split(RegExp(r'\s+'));
      final dateParts = parts[0].split('/');
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);
      int hour = 0, minute = 0;
      if (parts.length > 1) {
        final timeParts = parts[1].split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      }
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return DateTime(0);
    }
  }

  static Future<List<Map<String, dynamic>>> getSetsForWorkout(
      int workoutId) async {
    final d = await db;
    return await d.query('sets',
        where: 'workout_id = ?', whereArgs: [workoutId], orderBy: 'set_number');
  }

  static Future<void> deleteWorkout(int workoutId) async {
    final d = await db;
    await d.delete('sets', where: 'workout_id = ?', whereArgs: [workoutId]);
    await d.delete('workouts', where: 'id = ?', whereArgs: [workoutId]);
  }

  static Future<List<Map<String, dynamic>>> getLastSets(
      String exerciseName) async {
    final d = await db;
    final result = await d.rawQuery('''
      SELECT s.* FROM sets s
      INNER JOIN (
        SELECT MAX(workout_id) as max_id
        FROM sets
        WHERE exercise_name = ?
      ) latest ON s.workout_id = latest.max_id
      WHERE s.exercise_name = ?
      ORDER BY s.set_number
    ''', [exerciseName, exerciseName]);
    return result;
  }
}
