import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<void> _ensureV4Columns(Database d) async {
    for (final stmt in [
      "ALTER TABLE workouts ADD COLUMN type TEXT DEFAULT 'weighted'",
      'ALTER TABLE workouts ADD COLUMN distance_km REAL DEFAULT 0',
      "ALTER TABLE workouts ADD COLUMN notes TEXT DEFAULT ''",
    ]) {
      try {
        await d.execute(stmt);
      } catch (_) {}
    }
  }

  static Future<void> _ensureV5Columns(Database d) async {
    for (final stmt in [
      'ALTER TABLE sets ADD COLUMN superset_group INTEGER',
      "ALTER TABLE workouts ADD COLUMN photo_path TEXT DEFAULT ''",
    ]) {
      try {
        await d.execute(stmt);
      } catch (_) {}
    }
  }

  static Future<void> _ensureV6Columns(Database d) async {
    try {
      await d.execute('ALTER TABLE exercises ADD COLUMN muscle_group TEXT');
    } catch (_) {}
    try {
      await d.execute('''
        CREATE TABLE IF NOT EXISTS measurements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          weight_kg REAL,
          body_fat_pct REAL,
          notes TEXT DEFAULT ''
        )
      ''');
    } catch (_) {}
    try {
      await d.execute(
          'ALTER TABLE measurements ADD COLUMN body_fat_pct REAL');
    } catch (_) {}
  }

  static Future<void> _ensureV7Columns(Database d) async {
    try {
      await d.execute(
          'ALTER TABLE measurements ADD COLUMN height_cm REAL');
    } catch (_) {}
  }

  static Future<void> _createTemplatesTables(Database d) async {
    try {
      await d.execute('''
        CREATE TABLE IF NOT EXISTS templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT DEFAULT 'weighted'
        )
      ''');
      await d.execute('''
        CREATE TABLE IF NOT EXISTS template_exercises (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          template_id INTEGER NOT NULL,
          exercise_name TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');
    } catch (_) {}
  }

  static Future<Database> _initDB() async {
    final path = p.join(await getDatabasesPath(), 'gymlog.db');
    final d = await openDatabase(path, version: 7, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE exercises (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL,
          is_bodyweight INTEGER DEFAULT 0,
          muscle_group TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE workouts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          duration_seconds INTEGER DEFAULT 0,
          type TEXT DEFAULT 'weighted',
          distance_km REAL DEFAULT 0,
          notes TEXT DEFAULT '',
          photo_path TEXT DEFAULT ''
        )
      ''');
      await db.execute('''
        CREATE TABLE sets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          workout_id INTEGER NOT NULL,
          exercise_name TEXT NOT NULL,
          set_number INTEGER NOT NULL,
          weight REAL NOT NULL,
          reps INTEGER NOT NULL,
          superset_group INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT DEFAULT 'weighted'
        )
      ''');
      await db.execute('''
        CREATE TABLE template_exercises (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          template_id INTEGER NOT NULL,
          exercise_name TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE measurements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          weight_kg REAL,
          height_cm REAL,
          body_fat_pct REAL,
          notes TEXT DEFAULT ''
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
      if (oldV < 4) await _ensureV4Columns(db);
      if (oldV < 5) {
        await _ensureV5Columns(db);
        await _createTemplatesTables(db);
      }
      if (oldV < 6) await _ensureV6Columns(db);
      if (oldV < 7) await _ensureV7Columns(db);
    });
    await _ensureV4Columns(d);
    await _ensureV5Columns(d);
    await _createTemplatesTables(d);
    await _ensureV6Columns(d);
    await _ensureV7Columns(d);
    return d;
  }

  // ── Exercises ──────────────────────────────────────────────────────────────

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
    final existing =
        await d.query('exercises', where: 'name = ?', whereArgs: [name.trim()]);
    if (existing.isEmpty) {
      await d.insert('exercises',
          {'name': name.trim(), 'is_bodyweight': isBodyweight ? 1 : 0});
    } else {
      await d.update('exercises', {'is_bodyweight': isBodyweight ? 1 : 0},
          where: 'name = ?', whereArgs: [name.trim()]);
    }
  }

  static Future<void> setExerciseMuscleGroup(
      String name, String? muscleGroup) async {
    final d = await db;
    await d.update('exercises', {'muscle_group': muscleGroup},
        where: 'name = ?', whereArgs: [name.trim()]);
  }

  static Future<void> deleteExercise(String name) async {
    final d = await db;
    await d.delete('exercises', where: 'name = ?', whereArgs: [name.trim()]);
  }

  // ── Workouts ───────────────────────────────────────────────────────────────

  static Future<int> insertWorkout(
    String date,
    int durationSeconds, {
    String type = 'weighted',
    double distanceKm = 0,
    String notes = '',
  }) async {
    final d = await db;
    return await d.insert('workouts', {
      'date': date,
      'duration_seconds': durationSeconds,
      'type': type,
      'distance_km': distanceKm,
      'notes': notes,
    });
  }

  static Future<Map<String, dynamic>?> getWorkoutById(int id) async {
    final d = await db;
    final rows = await d.query('workouts', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
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

  static Future<List<Map<String, dynamic>>> getWorkouts() async {
    final d = await db;
    final rows = List<Map<String, dynamic>>.from(await d.query('workouts'));
    rows.sort((a, b) {
      final aDate = _parseWorkoutDate(a['date'] as String);
      final bDate = _parseWorkoutDate(b['date'] as String);
      return bDate.compareTo(aDate);
    });
    return rows;
  }

  static DateTime _parseWorkoutDate(String dateStr) {
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

  static Future<void> deleteWorkout(int workoutId) async {
    final d = await db;
    await d.delete('sets', where: 'workout_id = ?', whereArgs: [workoutId]);
    await d.delete('workouts', where: 'id = ?', whereArgs: [workoutId]);
  }

  static Future<void> updateWorkoutPhoto(
      int workoutId, String photoPath) async {
    final d = await db;
    await d.update('workouts', {'photo_path': photoPath},
        where: 'id = ?', whereArgs: [workoutId]);
  }

  static Future<void> updateWorkoutDetails(
    int workoutId, {
    String? notes,
    double? distanceKm,
    int? durationSeconds,
  }) async {
    final d = await db;
    final data = <String, Object?>{};
    if (notes != null) data['notes'] = notes;
    if (distanceKm != null) data['distance_km'] = distanceKm;
    if (durationSeconds != null) data['duration_seconds'] = durationSeconds;
    if (data.isEmpty) return;
    await d.update('workouts', data, where: 'id = ?', whereArgs: [workoutId]);
  }

  // ── Sets ───────────────────────────────────────────────────────────────────

  static Future<void> insertSet(int workoutId, String exerciseName,
      int setNumber, double weight, int reps,
      {int? supersetGroup}) async {
    final d = await db;
    final data = <String, Object?>{
      'workout_id': workoutId,
      'exercise_name': exerciseName,
      'set_number': setNumber,
      'weight': weight,
      'reps': reps,
      if (supersetGroup != null) 'superset_group': supersetGroup,
    };
    await d.insert('sets', data);
  }

  static Future<List<Map<String, dynamic>>> getSetsForWorkout(
      int workoutId) async {
    final d = await db;
    return await d.query('sets',
        where: 'workout_id = ?', whereArgs: [workoutId], orderBy: 'set_number');
  }

  static Future<void> updateSet(int setId, double weight, int reps) async {
    final d = await db;
    await d.update('sets', {'weight': weight, 'reps': reps},
        where: 'id = ?', whereArgs: [setId]);
  }

  static Future<void> deleteSet(int setId) async {
    final d = await db;
    await d.delete('sets', where: 'id = ?', whereArgs: [setId]);
  }

  static Future<double> getMaxWeightForExercise(String name) async {
    final d = await db;
    final res = await d.rawQuery(
      'SELECT MAX(weight) as max_weight FROM sets WHERE exercise_name = ?',
      [name.trim()],
    );
    if (res.isEmpty || res.first['max_weight'] == null) return 0;
    return (res.first['max_weight'] as num).toDouble();
  }

  static Future<List<Map<String, dynamic>>> getExerciseHistory(
      String name) async {
    final d = await db;
    final res = await d.rawQuery('''
      SELECT w.date, w.id as workout_id,
             MAX(s.weight) as max_weight, SUM(s.reps) as total_reps,
             COUNT(s.id) as set_count,
             MAX(s.weight * (1 + s.reps / 30.0)) as best_1rm
      FROM sets s
      INNER JOIN workouts w ON s.workout_id = w.id
      WHERE s.exercise_name = ?
      GROUP BY s.workout_id
      ORDER BY s.workout_id ASC
    ''', [name.trim()]);
    return List<Map<String, dynamic>>.from(res);
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

  // ── Templates ──────────────────────────────────────────────────────────────

  static Future<int> saveTemplate(
      String name, String type, List<String> exercises) async {
    final d = await db;
    final templateId =
        await d.insert('templates', {'name': name.trim(), 'type': type});
    for (int i = 0; i < exercises.length; i++) {
      await d.insert('template_exercises', {
        'template_id': templateId,
        'exercise_name': exercises[i],
        'sort_order': i,
      });
    }
    return templateId;
  }

  static Future<List<Map<String, dynamic>>> getTemplates() async {
    final d = await db;
    return List<Map<String, dynamic>>.from(
        await d.query('templates', orderBy: 'name'));
  }

  static Future<List<String>> getTemplateExercises(int templateId) async {
    final d = await db;
    final rows = await d.query('template_exercises',
        where: 'template_id = ?',
        whereArgs: [templateId],
        orderBy: 'sort_order');
    return rows.map((r) => r['exercise_name'] as String).toList();
  }

  static Future<void> updateTemplateExercises(
      int templateId, String name, List<String> exercises) async {
    final d = await db;
    await d.update('templates', {'name': name.trim()},
        where: 'id = ?', whereArgs: [templateId]);
    await d.delete('template_exercises',
        where: 'template_id = ?', whereArgs: [templateId]);
    for (int i = 0; i < exercises.length; i++) {
      await d.insert('template_exercises', {
        'template_id': templateId,
        'exercise_name': exercises[i],
        'sort_order': i,
      });
    }
  }

  static Future<void> deleteTemplate(int templateId) async {
    final d = await db;
    await d.delete('template_exercises',
        where: 'template_id = ?', whereArgs: [templateId]);
    await d.delete('templates', where: 'id = ?', whereArgs: [templateId]);
  }

  // ── Measurements ───────────────────────────────────────────────────────────

  static Future<void> insertMeasurement({
    required String date,
    double? weightKg,
    double? bodyFatPct,
    String notes = '',
  }) async {
    final d = await db;
    await d.insert('measurements', {
      'date': date,
      if (weightKg != null) 'weight_kg': weightKg,
      if (bodyFatPct != null) 'body_fat_pct': bodyFatPct,
      'notes': notes,
    });
  }

  static Future<List<Map<String, dynamic>>> getMeasurements() async {
    final d = await db;
    return List<Map<String, dynamic>>.from(
        await d.query('measurements', orderBy: 'id DESC'));
  }

  static Future<void> deleteMeasurement(int id) async {
    final d = await db;
    await d.delete('measurements', where: 'id = ?', whereArgs: [id]);
  }

  // ── Muscle group counts ────────────────────────────────────────────────────

  static Future<Map<String, int>> getMuscleGroupCounts(
      {DateTime? since}) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT e.muscle_group, w.date
      FROM sets s
      INNER JOIN workouts w ON s.workout_id = w.id
      INNER JOIN exercises e ON s.exercise_name = e.name
      WHERE e.muscle_group IS NOT NULL
      GROUP BY e.muscle_group, w.id
    ''');
    final counts = <String, int>{};
    for (final row in rows) {
      final group = row['muscle_group'] as String;
      final dateStr = row['date'] as String;
      if (since != null) {
        final date = _parseWorkoutDate(dateStr);
        if (date.isBefore(since)) continue;
      }
      counts[group] = (counts[group] ?? 0) + 1;
    }
    return counts;
  }

  // ── All-time stats ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAllTimeStats() async {
    final d = await db;

    final wRes = await d.rawQuery('SELECT COUNT(*) as c FROM workouts');
    final totalWorkouts = (wRes.first['c'] as int?) ?? 0;

    final tRes =
        await d.rawQuery('SELECT SUM(duration_seconds) as s FROM workouts');
    final totalSeconds = (tRes.first['s'] as int?) ?? 0;

    final topExRes = await d.rawQuery('''
      SELECT exercise_name, COUNT(*) as cnt FROM sets
      GROUP BY exercise_name ORDER BY cnt DESC LIMIT 3
    ''');
    final topExercises =
        topExRes.map((r) => r['exercise_name'] as String).toList();

    final typeRes = await d
        .rawQuery('SELECT type, COUNT(*) as cnt FROM workouts GROUP BY type');
    final typeBreakdown = <String, int>{};
    for (final r in typeRes) {
      typeBreakdown[r['type'] as String? ?? 'weighted'] =
          (r['cnt'] as int?) ?? 0;
    }

    final allDatesRes =
        await d.rawQuery('SELECT DISTINCT date FROM workouts');
    final dates = <DateTime>[];
    for (final row in allDatesRes) {
      final dt = _parseWorkoutDate(row['date'] as String);
      if (dt.year > 1) {
        dates.add(DateTime(dt.year, dt.month, dt.day));
      }
    }
    dates.sort();

    int longestStreak = dates.isEmpty ? 0 : 1;
    int currentStreak = dates.isEmpty ? 0 : 1;
    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        currentStreak++;
        if (currentStreak > longestStreak) longestStreak = currentStreak;
      } else if (diff > 1) {
        currentStreak = 1;
      }
    }

    final distRes = await d.rawQuery(
        "SELECT SUM(distance_km) as total FROM workouts WHERE type = 'cardio' AND distance_km > 0");
    final totalDistanceKm =
        (distRes.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'total_workouts': totalWorkouts,
      'total_seconds': totalSeconds,
      'top_exercises': topExercises,
      'type_breakdown': typeBreakdown,
      'longest_streak': longestStreak,
      'total_distance_km': totalDistanceKm,
    };
  }
}
