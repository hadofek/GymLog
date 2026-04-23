import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/profile_setup_screen.dart';
import 'package:gymlog/screens/month_workouts_screen.dart';
import 'package:gymlog/screens/log_workout_screen.dart';
import 'package:gymlog/screens/cardio_log_screen.dart';
import 'package:gymlog/screens/flexibility_log_screen.dart';
import 'package:gymlog/screens/exercise_library_screen.dart';
import 'package:gymlog/screens/templates_screen.dart';
import 'package:gymlog/screens/stats_screen.dart';
import 'package:gymlog/screens/settings_screen.dart';
import 'package:gymlog/utils/workout_types.dart';

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

  // Returns day → color of the most recent workout that day
  Map<int, Color> get _workedOutDays {
    final result = <int, Color>{};
    for (final w in _workouts) {
      final date = _parseDate(w['date'] as String);
      if (date != null &&
          date.month == _currentMonth.month &&
          date.year == _currentMonth.year) {
        // _workouts is sorted newest-first; putIfAbsent keeps the first (newest)
        result.putIfAbsent(
          date.day,
          () => WorkoutTypes.color(w['type'] as String? ?? WorkoutTypes.weighted),
        );
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

  DateTime? _parseDate(String dateStr) {
    try {
      final datePart = dateStr.trim().split(RegExp(r'\s+')).first;
      final parts = datePart.split('/');
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

  Future<void> _startWorkout(DateTime date) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Workout Type',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: Color(0xFF111111)),
              ),
              const SizedBox(height: 8),
              ...WorkoutTypes.all.map((t) => ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: WorkoutTypes.color(t).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(WorkoutTypes.icon(t),
                      color: WorkoutTypes.color(t), size: 20),
                ),
                title: Text(WorkoutTypes.label(t),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                onTap: () => Navigator.pop(ctx, t),
              )),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bookmark_outline_rounded,
                      color: Color(0xFF8B7500), size: 20),
                ),
                title: const Text('From Template',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: const Text('Start with a saved routine',
                    style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, '__templates__'),
              ),
            ],
          ),
        ),
      ),
    );
    if (type == null || !mounted) return;
    if (type == '__templates__') {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const TemplatesScreen()));
    } else if (type == WorkoutTypes.cardio) {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => CardioLogScreen(initialDate: date)));
    } else if (type == WorkoutTypes.flexibility) {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => FlexibilityLogScreen(initialDate: date)));
    } else {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => LogWorkoutScreen(initialDate: date, type: type)));
    }
    _load();
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
    final monthWorkouts = _monthWorkouts;
    final totalMonthSeconds = monthWorkouts.fold(
        0, (sum, w) => sum + (w['duration_seconds'] as int? ?? 0));
    final workedDays = _workedOutDays;
    final isCurrentMonth = _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;
    final today = DateTime.now().day;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'GymLog',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
            color: Color(0xFF111111),
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: Color(0xFF111111)),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded,
                color: Color(0xFF111111)),
            tooltip: 'All-Time Stats',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded,
                color: Color(0xFF111111)),
            tooltip: 'Templates',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TemplatesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.fitness_center_outlined,
                color: Color(0xFF111111)),
            tooltip: 'Exercise Library',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ExerciseLibraryScreen())),
          ),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ProfileSetupScreen(isEditing: true)));
              _load();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16, left: 4),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE0E0E0),
                backgroundImage:
                    _userImage != null ? FileImage(File(_userImage!)) : null,
                child: _userImage == null
                    ? Text(
                        _userName.isNotEmpty
                            ? _userName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111111),
                            fontSize: 15))
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting ──
            if (_userName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  'Hey, $_userName',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── Calendar card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Month navigator
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left,
                                color: Color(0xFF111111)),
                            onPressed: _prevMonth,
                            splashRadius: 20,
                          ),
                          Text(
                            _monthLabel,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111111),
                              letterSpacing: -0.3,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right,
                                color: isCurrentMonth
                                    ? const Color(0xFFCCCCCC)
                                    : const Color(0xFF111111)),
                            onPressed: isCurrentMonth ? null : _nextMonth,
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    // Day-of-week headers
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                            .map((d) => SizedBox(
                                  width: 36,
                                  child: Center(
                                    child: Text(
                                      d,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFAAAAAA),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),

                    // Calendar grid
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 2,
                          childAspectRatio: 1,
                        ),
                        itemCount: firstWeekday + daysInMonth,
                        itemBuilder: (ctx, index) {
                          if (index < firstWeekday) return const SizedBox();
                          final day = index - firstWeekday + 1;
                          final isToday = isCurrentMonth && day == today;
                          final workoutColor = workedDays[day];
                          final hasWorkout = workoutColor != null;
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
                                                top: Radius.circular(20)),
                                          ),
                                          backgroundColor: Colors.white,
                                          builder: (_) => SafeArea(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(height: 10),
                                                Container(
                                                  width: 36,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDDDDDD),
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                ListTile(
                                                  leading: Container(
                                                    width: 40, height: 40,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF111111).withValues(alpha: 0.08),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: const Icon(Icons.list_alt_outlined,
                                                        color: Color(0xFF111111), size: 20),
                                                  ),
                                                  title: const Text('View workouts',
                                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                                  onTap: () async {
                                                    Navigator.pop(context);
                                                    await Navigator.push(context, MaterialPageRoute(
                                                        builder: (_) => MonthWorkoutsScreen(
                                                            workouts: monthWorkouts,
                                                            monthLabel: _monthLabel,
                                                            initialDay: day)));
                                                    if (mounted) _load();
                                                  },
                                                ),
                                                ListTile(
                                                  leading: Container(
                                                    width: 40, height: 40,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: const Icon(Icons.add,
                                                        color: Color(0xFF8B7500), size: 20),
                                                  ),
                                                  title: const Text('Add another workout',
                                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                                  onTap: () async {
                                                    Navigator.pop(context);
                                                    await _startWorkout(tappedDate);
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                            ),
                                          ),
                                        );
                                        _load();
                                      }
                                    : () => _startWorkout(tappedDate),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasWorkout
                                    ? workoutColor
                                    : isToday
                                        ? const Color(0xFF111111)
                                        : Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: hasWorkout || isToday
                                        ? FontWeight.bold
                                        : FontWeight.w400,
                                    color: hasWorkout
                                        ? const Color(0xFF111111)
                                        : isToday
                                            ? Colors.white
                                            : isFuture
                                                ? const Color(0xFFCCCCCC)
                                                : const Color(0xFF333333),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Stats row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.local_fire_department_rounded,
                      value: '${monthWorkouts.length}',
                      label: 'Workouts',
                      accentColor: const Color(0xFFFFD700),
                    ),
                  ),
                  if (totalMonthSeconds > 0) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.timer_outlined,
                        value: DBHelper.formatDuration(totalMonthSeconds),
                        label: 'Total time',
                        accentColor: const Color(0xFF111111),
                        iconColor: Colors.white,
                        valueFontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── View list button ──
            if (monthWorkouts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MonthWorkoutsScreen(
                                workouts: monthWorkouts,
                                monthLabel: _monthLabel)));
                    _load();
                  },
                  icon: const Icon(Icons.list_alt_outlined,
                      color: Color(0xFF111111), size: 18),
                  label: const Text(
                    'View workouts this month',
                    style: TextStyle(
                        color: Color(0xFF111111),
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
        child: FloatingActionButton.extended(
          onPressed: () => _startWorkout(DateTime.now()),
          backgroundColor: const Color(0xFF111111),
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add, size: 22),
          label: const Text(
            'New Workout',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;
  final Color? iconColor;
  final double valueFontSize;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accentColor,
    this.iconColor,
    this.valueFontSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: iconColor ?? const Color(0xFF111111), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
