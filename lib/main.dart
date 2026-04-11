import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

void main() {
  runApp(const GymLogApp());
}

class GymLogApp extends StatelessWidget {
  const GymLogApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymLog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const SplashRouter(),
    );
  }
}

// ─── SPLASH / ROUTER ─────────────────────────────────────────
class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});
  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    if (!mounted) return;
    if (name.isEmpty) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator(color: Colors.black)),
    );
  }
}

// ─── PROFILE SETUP SCREEN ─────────────────────────────────────
class ProfileSetupScreen extends StatefulWidget {
  final bool isEditing;
  const ProfileSetupScreen({super.key, this.isEditing = false});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  String? _imagePath;
  bool _saving = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    if (widget.isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? '';
      _imagePath = prefs.getString('user_image');
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await picker.pickImage(
                    source: ImageSource.camera, imageQuality: 80);
                if (img != null) setState(() => _imagePath = img.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 80);
                if (img != null) setState(() => _imagePath = img.path);
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _imagePath = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    if (_imagePath != null) {
      await prefs.setString('user_image', _imagePath!);
    } else {
      await prefs.remove('user_image');
    }
    if (!mounted) return;
    if (widget.isEditing) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // Logo / brand
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                            color: Colors.black, shape: BoxShape.circle),
                        child: const Icon(Icons.fitness_center,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text('GymLog',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),

                  const SizedBox(height: 48),

                  Text(
                    widget.isEditing ? 'Edit Profile' : 'Welcome! 👋',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isEditing
                        ? 'Update your profile details'
                        : 'Let\'s set up your profile\nbefore we start training',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),

                  const SizedBox(height: 40),

                  // Avatar picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[100],
                            border: Border.all(
                                color: Colors.grey.shade300, width: 2),
                          ),
                          child: ClipOval(
                            child: _imagePath != null
                                ? Image.file(File(_imagePath!),
                                fit: BoxFit.cover)
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_outline,
                                    size: 44, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                              color: Colors.black, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text('Tap to add photo',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),

                  const SizedBox(height: 36),

                  // Name field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your name',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'e.g. Alex',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.black, width: 2)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onSubmitted: (_) => _save(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0),
                      child: _saving
                          ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : Text(
                          widget.isEditing ? 'Save Changes' : 'Get Started',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── DATABASE ───────────────────────────────────────────────
class DBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = p.join(await getDatabasesPath(), 'gymlog.db');
    return openDatabase(path, version: 2, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE exercises (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE NOT NULL
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
    });
  }

  static Future<void> insertExercise(String name) async {
    final d = await db;
    await d.insert('exercises', {'name': name},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<List<String>> getExercises() async {
    final d = await db;
    final res = await d.query('exercises', orderBy: 'name');
    return res.map((e) => e['name'] as String).toList();
  }

  static Future<int> insertWorkout(String date, int durationSeconds) async {
    final d = await db;
    return await d.insert('workouts', {'date': date, 'duration_seconds': durationSeconds});
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
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
    return await d.query('workouts', orderBy: 'id DESC');
  }

  static Future<List<Map<String, dynamic>>> getSetsForWorkout(
      int workoutId) async {
    final d = await db;
    return await d.query('sets',
        where: 'workout_id = ?', whereArgs: [workoutId]);
  }

  static Future<void> deleteWorkout(int workoutId) async {
    final d = await db;
    await d.delete('sets', where: 'workout_id = ?', whereArgs: [workoutId]);
    await d.delete('workouts', where: 'id = ?', whereArgs: [workoutId]);
  }

  static Future<List<Map<String, dynamic>>> getLastSets(
      String exerciseName) async {
    final d = await db;
    final workouts = await d.query('workouts', orderBy: 'id DESC');
    for (final w in workouts) {
      final sets = await d.query('sets',
          where: 'workout_id = ? AND exercise_name = ?',
          whereArgs: [w['id'], exerciseName],
          orderBy: 'set_number');
      if (sets.isNotEmpty) return sets;
    }
    return [];
  }
}

// ─── HOME SCREEN ────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _workouts = [];
  String _userName = '';
  String? _userImage;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Set<int> get _workedOutDays {
    final result = <int>{};
    for (final w in _workouts) {
      final date = _parseDate(w['date'] as String);
      if (date != null &&
          date.month == _currentMonth.month &&
          date.year == _currentMonth.year) {
        result.add(date.day);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get _monthWorkouts {
    return _workouts.where((w) {
      final date = _parseDate(w['date'] as String);
      return date != null &&
          date.month == _currentMonth.month &&
          date.year == _currentMonth.year;
    }).toList();
  }

  int get _totalMonthSeconds => _monthWorkouts.fold(
      0, (sum, w) => sum + (w['duration_seconds'] as int? ?? 0));

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('  ')[0].split('/');
      return DateTime(
          int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await DBHelper.getWorkouts();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workouts = w;
      _userName = prefs.getString('user_name') ?? '';
      _userImage = prefs.getString('user_image');
    });
  }

  void _prevMonth() => setState(() =>
  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
  void _nextMonth() => setState(() =>
  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));

  String get _monthLabel {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
    DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final workedDays = _workedOutDays;
    final isCurrentMonth = _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;
    final today = DateTime.now().day;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('GymLog',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          if (_totalMonthSeconds > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: Color(0xFFFFD700)),
                    const SizedBox(width: 5),
                    Text(
                      DBHelper.formatDuration(_totalMonthSeconds),
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileSetupScreen(isEditing: true)));
              _load();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage:
                _userImage != null ? FileImage(File(_userImage!)) : null,
                child: _userImage == null
                    ? Text(
                    _userName.isNotEmpty
                        ? _userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 15))
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_userName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(children: [
                  Text('Hey, $_userName 💪',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ]),
              ),
            const SizedBox(height: 16),

            // ── Month navigator ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _prevMonth,
                  ),
                  Text(_monthLabel,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.chevron_right,
                        color: isCurrentMonth ? Colors.grey[300] : Colors.black),
                    onPressed: isCurrentMonth ? null : _nextMonth,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Day-of-week headers ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                    .map((d) => SizedBox(
                  width: 36,
                  child: Center(
                    child: Text(d,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500])),
                  ),
                ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 8),

            // ── Calendar grid ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                itemCount: firstWeekday + daysInMonth,
                itemBuilder: (ctx, index) {
                  if (index < firstWeekday) return const SizedBox();
                  final day = index - firstWeekday + 1;
                  final isToday = isCurrentMonth && day == today;
                  final hasWorkout = workedDays.contains(day);
                  final isFuture = isCurrentMonth && day > today;

                  final tappedDate = DateTime(
                      _currentMonth.year, _currentMonth.month, day);

                  return GestureDetector(
                    onTap: isFuture
                        ? null
                        : hasWorkout
                            ? () async {
                                await showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                  ),
                                  builder: (_) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 8),
                                        Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ListTile(
                                          leading: const Icon(Icons.list_alt),
                                          title: const Text('View workouts'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        MonthWorkoutsScreen(
                                                            workouts:
                                                                _monthWorkouts,
                                                            monthLabel:
                                                                _monthLabel,
                                                            initialDay: day)));
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.add),
                                          title:
                                              const Text('Add another workout'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        LogWorkoutScreen(
                                                            initialDate:
                                                                tappedDate)));
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  ),
                                );
                                _load();
                              }
                            : () async {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => LogWorkoutScreen(
                                            initialDate: tappedDate)));
                                _load();
                              },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasWorkout
                            ? const Color(0xFFFFD700)
                            : isToday
                            ? Colors.black
                            : Colors.grey[100],
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: hasWorkout || isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: hasWorkout
                                ? Colors.black
                                : isToday
                                ? Colors.white
                                : isFuture
                                ? Colors.grey[300]
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Stats ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatChip(
                    icon: Icons.local_fire_department,
                    label: '${workedDays.length}',
                    sub: 'workouts this month',
                    color: const Color(0xFFFFD700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── View list button ──
            if (_monthWorkouts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MonthWorkoutsScreen(
                                workouts: _monthWorkouts,
                                monthLabel: _monthLabel)));
                    _load();
                  },
                  icon: const Icon(Icons.list_alt, color: Colors.black),
                  label: Text(
                      'View ${_monthWorkouts.length} workout${_monthWorkouts.length > 1 ? 's' : ''} this month',
                      style: const TextStyle(color: Colors.black)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => LogWorkoutScreen()));
            _load();
          },
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New Workout'),
        ),
      ),
    );
  }
}

// ─── STAT CHIP ───────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  const _StatChip(
      {required this.icon,
        required this.label,
        required this.sub,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(label,
              style:
              const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(sub, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

// ─── MONTH WORKOUTS SCREEN ───────────────────────────────────
class MonthWorkoutsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> workouts;
  final String monthLabel;
  final int? initialDay;
  const MonthWorkoutsScreen(
      {super.key,
        required this.workouts,
        required this.monthLabel,
        this.initialDay});
  @override
  State<MonthWorkoutsScreen> createState() => _MonthWorkoutsScreenState();
}

class _MonthWorkoutsScreenState extends State<MonthWorkoutsScreen> {
  late List<Map<String, dynamic>> _workouts;

  @override
  void initState() {
    super.initState();
    _workouts = List.from(widget.workouts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.monthLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _workouts.isEmpty
          ? const Center(
          child: Text('No workouts this month.',
              style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _workouts.length,
        itemBuilder: (ctx, i) {
          final w = _workouts[i];
          final dur = DBHelper.formatDuration(w['duration_seconds'] as int? ?? 0);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: Color(0xFFFFD700), shape: BoxShape.circle),
                child: const Icon(Icons.fitness_center,
                    size: 18, color: Colors.black),
              ),
              title: Text(w['date'],
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: dur.isNotEmpty
                  ? Text(dur, style: TextStyle(color: Colors.grey[600], fontSize: 12))
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final deleted = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => WorkoutDetailScreen(
                            workoutId: w['id'],
                            date: w['date'],
                            durationSeconds: w['duration_seconds'] as int? ?? 0)));
                if (deleted == true) {
                  setState(() => _workouts.removeAt(i));
                }
              },
            ),
          );
        },
      ),
    );
  }
}

// ─── LOG WORKOUT SCREEN ──────────────────────────────────────
class LogWorkoutScreen extends StatefulWidget {
  final DateTime? initialDate;
  const LogWorkoutScreen({super.key, this.initialDate});
  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final List<Map<String, dynamic>> _exercises = [];
  List<String> _allExercises = [];
  late DateTime _workoutDate;

  late Stopwatch _workoutStopwatch;
  late Timer _workoutTimer;
  String _workoutTime = '00:00';

  @override
  void initState() {
    super.initState();
    _workoutDate = widget.initialDate ?? DateTime.now();
    DBHelper.getExercises().then((e) => setState(() => _allExercises = e));
    _workoutStopwatch = Stopwatch()..start();
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = _workoutStopwatch.elapsed;
      setState(() {
        _workoutTime =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    });
  }

  @override
  void dispose() {
    _workoutTimer.cancel();
    _workoutStopwatch.stop();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _workoutDate,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _workoutDate = picked);
    }
  }

  Future<void> _addExercise() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AddExerciseScreen(allExercises: _allExercises)));
    if (result != null) {
      setState(() => _exercises.add(result));
      if (!_allExercises.contains(result['name'])) {
        _allExercises.add(result['name']);
      }
    }
  }

  Future<void> _saveWorkout() async {
    if (_exercises.isEmpty) return;
    try {
      final date = _workoutDate;
      final now = DateTime.now();
      final hour = date.year == now.year && date.month == now.month && date.day == now.day
          ? now.hour
          : 0;
      final minute = date.year == now.year && date.month == now.month && date.day == now.day
          ? now.minute
          : 0;
      final dateStr =
          '${date.day}/${date.month}/${date.year}  ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      final workoutId = await DBHelper.insertWorkout(dateStr, _workoutStopwatch.elapsed.inSeconds);
      for (final ex in _exercises) {
        await DBHelper.insertExercise(ex['name']);
        final sets = ex['sets'] as List;
        for (int i = 0; i < sets.length; i++) {
          await DBHelper.insertSet(workoutId, ex['name'], i + 1,
              sets[i]['weight'], sets[i]['reps']);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save workout: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: _pickDate,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                () {
                  final now = DateTime.now();
                  final d = _workoutDate;
                  if (d.year == now.year && d.month == now.month && d.day == now.day) {
                    return 'New Workout';
                  }
                  return '${d.day}/${d.month}/${d.year}';
                }(),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit_calendar_outlined, size: 16, color: Colors.grey),
            ],
          ),
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(_workoutTime,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
            ),
          ),
          if (_exercises.isNotEmpty)
            TextButton(
                onPressed: _saveWorkout,
                child: const Text('Save',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _exercises.isEmpty
                ? const Center(
                child: Text('Add your first exercise below',
                    style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _exercises.length,
                itemBuilder: (ctx, i) {
                  final ex = _exercises[i];
                  final sets = ex['sets'] as List;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 8),
                          ...sets.asMap().entries.map((e) => Padding(
                            padding:
                            const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    shape: BoxShape.circle),
                                child: Center(
                                    child: Text('${e.key + 1}',
                                        style: const TextStyle(
                                            fontSize: 12))),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                  '${e.value['weight']}kg × ${e.value['reps']} reps'),
                            ]),
                          )),
                        ],
                      ),
                    ),
                  );
                }),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Add Exercise'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ─── ADD EXERCISE SCREEN ─────────────────────────────────────
class AddExerciseScreen extends StatefulWidget {
  final List<String> allExercises;
  const AddExerciseScreen({super.key, required this.allExercises});
  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  List<Map<String, dynamic>> _sets = [];
  List<String> _suggestions = [];
  List<Map<String, dynamic>> _lastSets = [];

  bool _restTimerVisible = false;
  bool _restTimerRunning = false;
  int _restSeconds = 0;
  int _restTotalSeconds = 0;
  Timer? _restTimer;

  void _onNameChanged(String val) {
    setState(() {
      _suggestions = val.isEmpty
          ? []
          : widget.allExercises
          .where((e) => e.toLowerCase().contains(val.toLowerCase()))
          .toList();
    });
  }

  Future<void> _selectExercise(String name) async {
    _nameController.text = name;
    final last = await DBHelper.getLastSets(name);
    setState(() {
      _suggestions = [];
      _lastSets = last;
    });
  }

  void _saveSet() {
    final w = double.tryParse(_weightController.text);
    final r = int.tryParse(_repsController.text);
    if (w == null || r == null || w < 0 || r <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid weight and reps')),
      );
      return;
    }
    if (w == 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bodyweight exercise?'),
          content: const Text(
              'You entered 0 kg. Is this a bodyweight exercise?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid weight amount')),
                );
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _sets.add({'weight': w, 'reps': r});
                  _weightController.clear();
                  _repsController.clear();
                });
                _showRestPicker();
              },
              child: const Text('Yes, bodyweight'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      _sets.add({'weight': w, 'reps': r});
      _weightController.clear();
      _repsController.clear();
    });
    _showRestPicker();
  }

  Future<void> _showRestPicker() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('rest_timer_seconds') ?? 90;
    int pickedMinutes = saved ~/ 60;
    int pickedSeconds = saved % 60;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, 16 + MediaQuery.of(ctx).viewPadding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text('Rest Time',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _WheelColumn(
                  initialValue: pickedMinutes,
                  count: 60,
                  label: 'min',
                  onChanged: (v) => pickedMinutes = v,
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 22),
                  child: Text(':',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: Colors.black38)),
                ),
                _WheelColumn(
                  initialValue: pickedSeconds,
                  count: 60,
                  label: 'sec',
                  onChanged: (v) => pickedSeconds = v,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final total = pickedMinutes * 60 + pickedSeconds;
                if (total > 0) {
                  final p = await SharedPreferences.getInstance();
                  await p.setInt('rest_timer_seconds', total);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _startRestTimer(total);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Start Rest Timer'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Skip rest',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restSeconds = seconds;
      _restTotalSeconds = seconds;
      _restTimerRunning = true;
      _restTimerVisible = true;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restSeconds <= 0) {
        t.cancel();
        setState(() => _restTimerRunning = false);
      } else {
        setState(() => _restSeconds--);
      }
    });
  }

  void _cancelRest() {
    _restTimer?.cancel();
    setState(() {
      _restTimerVisible = false;
      _restTimerRunning = false;
      _restSeconds = 0;
    });
  }

  void _done() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please enter an exercise name and at least one set')),
      );
      return;
    }
    _restTimer?.cancel();
    Navigator.pop(context, {'name': name, 'sets': _sets});
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _nameController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restProgress =
    _restTotalSeconds > 0 ? _restSeconds / _restTotalSeconds : 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Add Exercise'),
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_restTimerVisible)
            Container(
              color: _restTimerRunning ? Colors.black : Colors.grey[800],
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _restTimerRunning
                              ? 'Resting — ${_restSeconds}s remaining'
                              : 'Rest done! Ready for next set 💪',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: restProgress.toDouble(),
                            backgroundColor: Colors.white24,
                            valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelRest,
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70)),
                  )
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exercise name',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    onChanged: _onNameChanged,
                    decoration: InputDecoration(
                      hintText: 'e.g. Bench Press',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: _suggestions
                            .map((s) => ListTile(
                          dense: true,
                          title: Text(s),
                          onTap: () => _selectExercise(s),
                        ))
                            .toList(),
                      ),
                    ),
                  if (_lastSets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Last time:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                          const SizedBox(height: 4),
                          ..._lastSets.map((s) => Text(
                              'Set ${s['set_number']}: ${s['weight']}kg × ${s['reps']} reps',
                              style: const TextStyle(color: Colors.blue))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_sets.isNotEmpty) ...[
                    const Text('Sets logged',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._sets.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle),
                          child: Center(
                              child: Text('${e.key + 1}',
                                  style:
                                  const TextStyle(fontSize: 13))),
                        ),
                        const SizedBox(width: 10),
                        Text(
                            '${e.value['weight']}kg × ${e.value['reps']} reps',
                            style: const TextStyle(fontSize: 15)),
                        const Spacer(),
                        IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => _sets.removeAt(e.key))),
                      ]),
                    )),
                    const SizedBox(height: 12),
                  ],
                  Text(
                      _sets.isEmpty ? 'First set' : 'Set ${_sets.length + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Weight (kg)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Reps',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saveSet,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Set'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44)),
                  ),
                ],
              ),
            ),
          ),
          if (_sets.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
              child: ElevatedButton(
                onPressed: _done,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48)),
                child: Text(
                    'Done — ${_sets.length} set${_sets.length > 1 ? 's' : ''} logged'),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── WORKOUT DETAIL SCREEN ───────────────────────────────────
class WorkoutDetailScreen extends StatefulWidget {
  final int workoutId;
  final String date;
  final int durationSeconds;
  const WorkoutDetailScreen(
      {super.key, required this.workoutId, required this.date, this.durationSeconds = 0});
  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  final GlobalKey _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sets = await DBHelper.getSetsForWorkout(widget.workoutId);
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in sets) {
      final name = s['exercise_name'] as String;
      grouped.putIfAbsent(name, () => []).add(s);
    }
    setState(() => _grouped = grouped);
  }

  Future<void> _shareWorkout() async {
    final totalSets = _grouped.values.fold(0, (s, v) => s + v.length);
    final totalReps = _grouped.values
        .expand((v) => v)
        .fold(0, (s, e) => s + (e['reps'] as int));
    final totalWeight = _grouped.values
        .expand((v) => v)
        .fold(0.0, (s, e) => s + (e['weight'] as double) * (e['reps'] as int));

    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _SharePreviewDialog(
        shareCardKey: _shareCardKey,
        date: widget.date,
        durationSeconds: widget.durationSeconds,
        exerciseCount: _grouped.length,
        totalSets: totalSets,
        totalReps: totalReps,
        totalWeight: totalWeight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.date),
        elevation: 0,
        actions: [
          if (_grouped.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: _shareWorkout,
              tooltip: 'Share workout',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete workout?'),
                  content: const Text('This will permanently delete this workout and all its sets.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await DBHelper.deleteWorkout(widget.workoutId);
                if (mounted) Navigator.pop(context, true); // ignore: use_build_context_synchronously
              }
            },
          ),
        ],
      ),
      body: _grouped.isEmpty
          ? const Center(child: Text('No exercises logged.'))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: _grouped.entries.map((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...entry.value.map((s) => Padding(
                    padding:
                    const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle),
                        child: Center(
                            child: Text('${s['set_number']}',
                                style: const TextStyle(
                                    fontSize: 12))),
                      ),
                      const SizedBox(width: 8),
                      Text(
                          '${s['weight']}kg × ${s['reps']} reps'),
                    ]),
                  )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── SHARE PREVIEW DIALOG ────────────────────────────────────
class _SharePreviewDialog extends StatefulWidget {
  final GlobalKey shareCardKey;
  final String date;
  final int durationSeconds;
  final int exerciseCount;
  final int totalSets;
  final int totalReps;
  final double totalWeight;

  const _SharePreviewDialog({
    required this.shareCardKey,
    required this.date,
    required this.durationSeconds,
    required this.exerciseCount,
    required this.totalSets,
    required this.totalReps,
    required this.totalWeight,
  });

  @override
  State<_SharePreviewDialog> createState() => _SharePreviewDialogState();
}

class _SharePreviewDialogState extends State<_SharePreviewDialog> {
  bool _sharing = false;

  Future<void> _doShare() async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final boundary = widget.shareCardKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Gallery permission denied')));
        if (mounted) setState(() => _sharing = false);
        return;
      }
      await Gal.putImageBytes(
          bytes, name: 'gymlog_${DateTime.now().millisecondsSinceEpoch}');
      nav.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Saved to gallery!'),
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not save image: $e')));
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: widget.shareCardKey,
            child: _WorkoutShareCard(
              date: widget.date,
              durationSeconds: widget.durationSeconds,
              exerciseCount: widget.exerciseCount,
              totalSets: widget.totalSets,
              totalReps: widget.totalReps,
              totalWeight: widget.totalWeight,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _sharing ? null : _doShare,
                  icon: _sharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.share),
                  label: Text(_sharing ? 'Preparing...' : 'Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── WORKOUT SHARE CARD ──────────────────────────────────────
class _WorkoutShareCard extends StatelessWidget {
  final String date;
  final int durationSeconds;
  final int exerciseCount;
  final int totalSets;
  final int totalReps;
  final double totalWeight;

  const _WorkoutShareCard({
    required this.date,
    required this.durationSeconds,
    required this.exerciseCount,
    required this.totalSets,
    required this.totalReps,
    required this.totalWeight,
  });

  @override
  Widget build(BuildContext context) {
    final dur = DBHelper.formatDuration(durationSeconds);
    final weightStr = totalWeight == totalWeight.truncateToDouble()
        ? '${totalWeight.toInt()}kg'
        : '${totalWeight.toStringAsFixed(1)}kg';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fitness_center,
                    size: 18, color: Colors.black),
              ),
              const SizedBox(width: 10),
              const Text(
                'GYMLOG',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Workout complete label
          Text(
            'WORKOUT COMPLETE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),

          // Duration — big hero number
          if (dur.isNotEmpty)
            Text(
              dur,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
                height: 1,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            date.split('  ').first,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 28),

          // Divider
          Container(height: 1, color: Colors.white.withOpacity(0.08)),
          const SizedBox(height: 24),

          // Stats grid
          Row(
            children: [
              _ShareStat(value: '$exerciseCount', label: 'Exercises'),
              _ShareStatDivider(),
              _ShareStat(value: '$totalSets', label: 'Sets'),
              _ShareStatDivider(),
              _ShareStat(value: '$totalReps', label: 'Reps'),
              _ShareStatDivider(),
              _ShareStat(value: weightStr, label: 'Volume'),
            ],
          ),

          const SizedBox(height: 24),

          // Gold accent bar
          Container(
            height: 3,
            width: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  final String value;
  final String label;
  const _ShareStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withOpacity(0.08),
    );
  }
}

// ─── WHEEL COLUMN (iOS-style drum picker) ────────────────────
class _WheelColumn extends StatefulWidget {
  final int initialValue;
  final int count;
  final String label;
  final ValueChanged<int> onChanged;

  const _WheelColumn({
    required this.initialValue,
    required this.count,
    required this.label,
    required this.onChanged,
  });

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  late final FixedExtentScrollController _controller;
  late int _selected;

  static const double _itemExtent = 44;
  static const int _visibleItems = 5;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _controller = FixedExtentScrollController(initialItem: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const wheelHeight = _itemExtent * _visibleItems;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: wheelHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Selection zone highlight
              Container(
                height: _itemExtent,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Top fade
              Positioned(
                top: 0, left: 0, right: 0,
                height: wheelHeight / 2 - _itemExtent / 2,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Colors.white.withOpacity(0)],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom fade
              Positioned(
                bottom: 0, left: 0, right: 0,
                height: wheelHeight / 2 - _itemExtent / 2,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.white, Colors.white.withOpacity(0)],
                      ),
                    ),
                  ),
                ),
              ),
              // Wheel
              ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: _itemExtent,
                perspective: 0.002,
                diameterRatio: 1.6,
                squeeze: 1.0,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  setState(() => _selected = i);
                  widget.onChanged(i);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: widget.count,
                  builder: (ctx, i) {
                    final isSelected = i == _selected;
                    return Center(
                      child: Text(
                        i.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: isSelected ? 28 : 19,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.black
                              : Colors.black.withOpacity(0.22),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(widget.label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}