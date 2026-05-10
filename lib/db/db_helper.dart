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

  /// Merges duplicate exercises that differ only by case.
  /// For each group, the exercise with the most logged sets becomes canonical.
  /// All sets and template_exercises are rewritten to use the canonical name,
  /// and the duplicate exercise rows are deleted.
  static Future<void> _deduplicateExercises(Database d) async {
    final allEx = await d.query('exercises');
    // Group by lowercase name
    final groups = <String, List<String>>{};
    for (final ex in allEx) {
      final name = ex['name'] as String;
      groups.putIfAbsent(name.toLowerCase(), () => []).add(name);
    }
    for (final variants in groups.values) {
      if (variants.length <= 1) continue;
      // Count sets per variant
      final counts = <String, int>{};
      for (final name in variants) {
        final res = await d.rawQuery(
          'SELECT COUNT(*) as c FROM sets WHERE exercise_name = ?', [name]);
        counts[name] = (res.first['c'] as int?) ?? 0;
      }
      // Canonical = most sets; tie-break = alphabetically first
      variants.sort((a, b) {
        final diff = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
        return diff != 0 ? diff : a.compareTo(b);
      });
      final canonical = variants.first;
      for (final other in variants.skip(1)) {
        await d.rawUpdate(
          'UPDATE sets SET exercise_name = ? WHERE LOWER(exercise_name) = LOWER(?)',
          [canonical, other]);
        await d.rawUpdate(
          'UPDATE template_exercises SET exercise_name = ? WHERE LOWER(exercise_name) = LOWER(?)',
          [canonical, other]);
        await d.delete('exercises', where: 'name = ?', whereArgs: [other]);
      }
    }
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
    final d = await openDatabase(path, version: 9, onCreate: (db, v) async {
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
      await db.execute('''
        CREATE TABLE workout_drafts (
          id INTEGER PRIMARY KEY,
          type TEXT NOT NULL,
          exercises_json TEXT NOT NULL,
          elapsed_seconds INTEGER DEFAULT 0,
          date_str TEXT NOT NULL,
          saved_at TEXT NOT NULL
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
      if (oldV < 8) await _deduplicateExercises(db);
      if (oldV < 9) await _ensureV9Tables(db);
    });
    await _ensureV4Columns(d);
    await _ensureV5Columns(d);
    await _createTemplatesTables(d);
    await _ensureV6Columns(d);
    await _ensureV7Columns(d);
    await _ensureV9Tables(d);
    return d;
  }

  static Future<void> _ensureV9Tables(Database d) async {
    try {
      await d.execute('''
        CREATE TABLE IF NOT EXISTS workout_drafts (
          id INTEGER PRIMARY KEY,
          type TEXT NOT NULL,
          exercises_json TEXT NOT NULL,
          elapsed_seconds INTEGER DEFAULT 0,
          date_str TEXT NOT NULL,
          saved_at TEXT NOT NULL
        )
      ''');
    } catch (_) {}
  }

  // ── Exercises ──────────────────────────────────────────────────────────────

  static Future<void> insertExercise(String name,
      {String? muscleGroup}) async {
    final d = await db;
    final trimmed = name.trim();
    // Check for case-insensitive match — avoids duplicates like "pushups" / "Pushups"
    final existing = await d.rawQuery(
      'SELECT name FROM exercises WHERE LOWER(name) = LOWER(?)', [trimmed]);
    if (existing.isNotEmpty) {
      final existingName = existing.first['name'] as String;
      if (muscleGroup != null) {
        await d.rawUpdate(
          'UPDATE exercises SET muscle_group = ? WHERE name = ? AND muscle_group IS NULL',
          [muscleGroup, existingName]);
      }
      return;
    }
    await d.insert('exercises', {'name': trimmed},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    if (muscleGroup != null) {
      await d.rawUpdate(
        'UPDATE exercises SET muscle_group = ? WHERE name = ? AND muscle_group IS NULL',
        [muscleGroup, trimmed],
      );
    }
  }

  static Future<List<String>> getExercises() async {
    final d = await db;
    final res = await d.query('exercises', orderBy: 'name');
    return res.map((e) => e['name'] as String).toList();
  }

  /// Exercise names that have at least one logged set.
  static Future<Set<String>> getExerciseNamesWithSets() async {
    final d = await db;
    final res = await d.rawQuery('SELECT DISTINCT exercise_name FROM sets');
    return res.map((r) => (r['exercise_name'] as String).toLowerCase()).toSet();
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

  /// Insert a full workout and all its sets in a single transaction.
  /// [sets] entries: {exerciseName, setNumber, weight, reps, supersetGroup?}
  static Future<int> saveWorkoutWithSets(
    String date,
    int durationSeconds, {
    required String type,
    double distanceKm = 0,
    String notes = '',
    required List<Map<String, dynamic>> sets,
  }) async {
    final d = await db;
    return await d.transaction<int>((txn) async {
      final workoutId = await txn.insert('workouts', {
        'date': date,
        'duration_seconds': durationSeconds,
        'type': type,
        'distance_km': distanceKm,
        'notes': notes,
      });
      for (final s in sets) {
        await txn.insert('sets', {
          'workout_id': workoutId,
          'exercise_name': s['exerciseName'],
          'set_number': s['setNumber'],
          'weight': s['weight'],
          'reps': s['reps'],
          if (s['supersetGroup'] != null) 'superset_group': s['supersetGroup'],
        });
      }
      return workoutId;
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

  /// All-time personal records per exercise, sorted by session count descending.
  static Future<List<Map<String, dynamic>>> getAllExercisePRs() async {
    final d = await db;
    final res = await d.rawQuery('''
      SELECT
        s.exercise_name,
        MAX(s.weight)                         AS max_weight,
        MAX(s.reps)                           AS max_reps,
        MAX(s.weight * (1 + s.reps / 30.0))  AS best_1rm,
        MAX(w.date)                           AS last_date,
        COUNT(DISTINCT s.workout_id)          AS session_count,
        COALESCE(e.is_bodyweight, 0)          AS is_bodyweight
      FROM sets s
      INNER JOIN workouts w ON s.workout_id = w.id
      LEFT JOIN exercises e ON LOWER(e.name) = LOWER(s.exercise_name)
      GROUP BY LOWER(s.exercise_name)
      HAVING MAX(s.reps) > 0
      ORDER BY session_count DESC, s.exercise_name ASC
    ''');
    return List<Map<String, dynamic>>.from(res);
  }

  /// Sets from the second-most-recent workout containing [exerciseName].
  /// Returns empty list if fewer than 2 sessions exist.
  static Future<List<Map<String, dynamic>>> getPenultimateSessionSets(
      String exerciseName) async {
    final d = await db;
    final ids = await d.rawQuery('''
      SELECT DISTINCT workout_id FROM sets
      WHERE exercise_name = ?
      ORDER BY workout_id DESC
      LIMIT 2
    ''', [exerciseName]);
    if (ids.length < 2) return [];
    final penultimateId = ids[1]['workout_id'] as int;
    final res = await d.rawQuery('''
      SELECT * FROM sets WHERE workout_id = ? AND exercise_name = ?
      ORDER BY set_number
    ''', [penultimateId, exerciseName]);
    return List<Map<String, dynamic>>.from(res);
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

  // ── Workout Draft ──────────────────────────────────────────────────────────

  static Future<void> saveDraft({
    required String type,
    required String exercisesJson,
    required int elapsedSeconds,
    required String dateStr,
  }) async {
    final d = await db;
    await d.insert(
      'workout_drafts',
      {
        'id': 1,
        'type': type,
        'exercises_json': exercisesJson,
        'elapsed_seconds': elapsedSeconds,
        'date_str': dateStr,
        'saved_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> loadDraft() async {
    final d = await db;
    final rows = await d.query('workout_drafts', where: 'id = 1');
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> clearDraft() async {
    final d = await db;
    await d.delete('workout_drafts', where: 'id = 1');
  }

  // ── Measurements ───────────────────────────────────────────────────────────

  static Future<void> insertMeasurement({
    required String date,
    double? weightKg,
    double? heightCm,
    double? bodyFatPct,
    String notes = '',
  }) async {
    final d = await db;
    await d.insert('measurements', {
      'date': date,
      if (weightKg != null) 'weight_kg': weightKg,
      if (heightCm != null) 'height_cm': heightCm,
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
      INNER JOIN exercises e ON LOWER(s.exercise_name) = LOWER(e.name)
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

  // ── Share-card data ────────────────────────────────────────────────────────

  /// Returns volumes (weight × reps) for the [n] workouts before [workoutId],
  /// in chronological order, excluding bodyweight sets (weight = 0).
  static Future<List<double>> getLastNWorkoutVolumes(
      int workoutId, int n) async {
    final d = await db;
    final idRes = await d.rawQuery('''
      SELECT id FROM workouts WHERE id < ?
      ORDER BY id DESC LIMIT ?
    ''', [workoutId, n]);
    if (idRes.isEmpty) return [];
    final ids = idRes.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final volRes = await d.rawQuery('''
      SELECT workout_id, SUM(weight * reps) as volume
      FROM sets
      WHERE workout_id IN ($placeholders)
      GROUP BY workout_id
    ''', ids);
    // Build a map so workouts with no sets resolve to 0.0 rather than being dropped.
    final volMap = <int, double>{};
    for (final r in volRes) {
      volMap[r['workout_id'] as int] =
          (r['volume'] as num?)?.toDouble() ?? 0.0;
    }
    // ids is already DESC (most-recent-first); reverse to get chronological order.
    return ids.reversed.map((id) => volMap[id] ?? 0.0).toList();
  }

  /// Returns muscle-group → total volume (weight × reps) for a single workout.
  static Future<Map<String, double>> getMuscleVolumeForWorkout(
      int workoutId) async {
    final d = await db;
    final res = await d.rawQuery('''
      SELECT e.muscle_group, SUM(s.weight * s.reps) as volume
      FROM sets s
      INNER JOIN exercises e ON LOWER(s.exercise_name) = LOWER(e.name)
      WHERE s.workout_id = ? AND e.muscle_group IS NOT NULL
      GROUP BY e.muscle_group
    ''', [workoutId]);
    final breakdown = <String, double>{};
    for (final row in res) {
      final group = row['muscle_group'] as String;
      breakdown[group] = (row['volume'] as num?)?.toDouble() ?? 0.0;
    }
    return breakdown;
  }

  /// Returns exercise names that achieved a new all-time weight PR in [workoutId].
  static Future<List<String>> getPersonalBestsInWorkout(
      int workoutId) async {
    final d = await db;
    final pbs = <String>[];

    // Weighted: max weight per exercise
    final weightedRes = await d.rawQuery('''
      SELECT exercise_name, MAX(weight) as max_weight
      FROM sets WHERE workout_id = ? AND weight > 0
      GROUP BY exercise_name
    ''', [workoutId]);
    for (final row in weightedRes) {
      final name = row['exercise_name'] as String;
      final currentMax = (row['max_weight'] as num?)?.toDouble() ?? 0.0;
      if (currentMax <= 0) continue;
      final histRes = await d.rawQuery('''
        SELECT MAX(weight) as max_weight FROM sets
        WHERE exercise_name = ? AND workout_id != ? AND weight > 0
      ''', [name, workoutId]);
      final histMax = histRes.isEmpty
          ? 0.0
          : (histRes.first['max_weight'] as num?)?.toDouble() ?? 0.0;
      if (currentMax > histMax) pbs.add(name);
    }

    // Bodyweight: max reps per exercise
    final bwRes = await d.rawQuery('''
      SELECT exercise_name, MAX(reps) as max_reps
      FROM sets WHERE workout_id = ? AND weight = 0
      GROUP BY exercise_name
    ''', [workoutId]);
    for (final row in bwRes) {
      final name = row['exercise_name'] as String;
      final currentMax = (row['max_reps'] as num?)?.toInt() ?? 0;
      if (currentMax <= 0) continue;
      final histRes = await d.rawQuery('''
        SELECT MAX(reps) as max_reps FROM sets
        WHERE exercise_name = ? AND workout_id != ? AND weight = 0
      ''', [name, workoutId]);
      final histMax = histRes.isEmpty
          ? 0
          : (histRes.first['max_reps'] as num?)?.toInt() ?? 0;
      if (currentMax > histMax) pbs.add(name);
    }

    return pbs;
  }

  /// PR detection for cardio and flexibility workouts.
  /// Returns a list of human-readable PR strings, e.g. "Running — 5.2km".
  static Future<List<String>> getNonWeightedPRs(int workoutId) async {
    final d = await db;
    final rows = await d.query('workouts', where: 'id = ?', whereArgs: [workoutId]);
    if (rows.isEmpty) return [];
    final workout = rows.first;
    final type = workout['type'] as String? ?? '';
    final durationSeconds = workout['duration_seconds'] as int? ?? 0;
    final distanceKm = (workout['distance_km'] as num?)?.toDouble() ?? 0.0;
    final notes = workout['notes'] as String? ?? '';
    final activity = notes.split('\n').first.trim();
    if (activity.isEmpty) return [];

    if (type == 'cardio') {
      if (distanceKm > 0) {
        final histRes = await d.rawQuery('''
          SELECT MAX(distance_km) as max_dist FROM workouts
          WHERE type = 'cardio' AND notes LIKE ? AND id != ?
        ''', ['$activity%', workoutId]);
        final histMax = histRes.isEmpty
            ? 0.0
            : (histRes.first['max_dist'] as num?)?.toDouble() ?? 0.0;
        if (distanceKm > histMax) {
          return ['$activity — ${distanceKm.toStringAsFixed(1)}km'];
        }
      } else if (durationSeconds > 0) {
        final histRes = await d.rawQuery('''
          SELECT MAX(duration_seconds) as max_dur FROM workouts
          WHERE type = 'cardio' AND notes LIKE ? AND id != ?
        ''', ['$activity%', workoutId]);
        final histMax = histRes.isEmpty
            ? 0
            : (histRes.first['max_dur'] as num?)?.toInt() ?? 0;
        if (durationSeconds > histMax) {
          return ['$activity — ${formatDuration(durationSeconds)}'];
        }
      }
    } else if (type == 'flexibility') {
      if (durationSeconds > 0) {
        final histRes = await d.rawQuery('''
          SELECT MAX(duration_seconds) as max_dur FROM workouts
          WHERE type = 'flexibility' AND notes LIKE ? AND id != ?
        ''', ['$activity%', workoutId]);
        final histMax = histRes.isEmpty
            ? 0
            : (histRes.first['max_dur'] as num?)?.toInt() ?? 0;
        if (durationSeconds > histMax) {
          return ['$activity — ${formatDuration(durationSeconds)}'];
        }
      }
    }
    return [];
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
      GROUP BY LOWER(exercise_name) ORDER BY cnt DESC LIMIT 3
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
