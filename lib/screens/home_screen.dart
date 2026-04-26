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
import 'package:gymlog/utils/app_colors.dart';

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

  Map<int, Color> get _workedOutDays {
    final result = <int, Color>{};
    for (final w in _workouts) {
      final date = _parseDate(w['date'] as String);
      if (date != null &&
          date.month == _currentMonth.month &&
          date.year == _currentMonth.year) {
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
    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = AppColors.border(context);
    final accent = AppColors.accent(context);

    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32, height: 3,
                decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Start a workout',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: textPrimary),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a type to begin',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              ...WorkoutTypes.all.map((t) => _SheetTile(
                    icon: WorkoutTypes.icon(t),
                    iconColor: WorkoutTypes.color(t),
                    title: WorkoutTypes.label(t),
                    textColor: textPrimary,
                    onTap: () => Navigator.pop(ctx, t),
                  )),
              Divider(height: 16, color: borderColor),
              _SheetTile(
                icon: Icons.bookmark_outline_rounded,
                iconColor: accent,
                title: 'From Template',
                subtitle: 'Start with a saved routine',
                textColor: textPrimary,
                subtitleColor: textSecondary,
                onTap: () => Navigator.pop(ctx, '__templates__'),
              ),
              const SizedBox(height: 4),
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

  int get _currentStreak {
    if (_workouts.isEmpty) return 0;
    final today = DateTime.now();
    int streak = 0;
    DateTime check = DateTime(today.year, today.month, today.day);
    final workedDates = _workouts
        .map((w) => _parseDate(w['date'] as String))
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    while (workedDates.contains(check)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
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
    final streak = _currentStreak;

    final bg = AppColors.background(context);
    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);
    final accent = AppColors.accent(context);
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Text(
                    'GymLog',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _HeaderIcon(
                      icon: Icons.bar_chart_rounded,
                      color: textSecondary,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const StatsScreen()))),
                  _HeaderIcon(
                      icon: Icons.bookmark_outline_rounded,
                      color: textSecondary,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const TemplatesScreen()))),
                  _HeaderIcon(
                      icon: Icons.fitness_center_outlined,
                      color: textSecondary,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()))),
                  _HeaderIcon(
                      icon: Icons.settings_outlined,
                      color: textSecondary,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const ProfileSetupScreen(isEditing: true)));
                      _load();
                    },
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: isDark
                          ? const Color(0xFF242432)
                          : const Color(0xFFE0E0E0),
                      backgroundImage: _userImage != null
                          ? FileImage(File(_userImage!))
                          : null,
                      child: _userImage == null
                          ? Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                  fontSize: 14))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // ── Greeting ──
            if (_userName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hey, $_userName',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ── Scrollable body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Bento stats row ──
                    if (monthWorkouts.isNotEmpty || streak > 0)
                      Row(
                        children: [
                          Expanded(
                            child: _BentoCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${monthWorkouts.length}',
                                    style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -2,
                                      height: 1,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'workouts\nthis month',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                        height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              children: [
                                if (totalMonthSeconds > 0)
                                  _BentoCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DBHelper.formatDuration(totalMonthSeconds),
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1,
                                            height: 1,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'total time',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (totalMonthSeconds > 0 && streak > 0)
                                  const SizedBox(height: 10),
                                if (streak > 0)
                                  _BentoCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '$streak',
                                              style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -1,
                                                height: 1,
                                                color: accent,
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 3, bottom: 1),
                                              child: Text(
                                                streak == 1 ? 'day' : 'days',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: textSecondary),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'current streak',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    if (monthWorkouts.isNotEmpty || streak > 0)
                      const SizedBox(height: 10),

                    // ── Calendar card ──
                    _BentoCard(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        children: [
                          // Month nav
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: _prevMonth,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.chevron_left,
                                      color: textSecondary, size: 20),
                                ),
                              ),
                              Text(
                                _monthLabel,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              GestureDetector(
                                onTap: isCurrentMonth ? null : _nextMonth,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.chevron_right,
                                      color: isCurrentMonth
                                          ? textTertiary
                                          : textSecondary,
                                      size: 20),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Day-of-week headers
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                                .map((d) => SizedBox(
                                      width: 34,
                                      child: Center(
                                        child: Text(
                                          d,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: textTertiary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),

                          const SizedBox(height: 8),

                          // Calendar grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 0,
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
                                            await _showDaySheet(
                                                tappedDate, day, monthWorkouts,
                                                cardBg, borderColor, textPrimary,
                                                textSecondary, accent);
                                            _load();
                                          }
                                        : () => _startWorkout(tappedDate),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.all(1),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hasWorkout
                                        ? workoutColor.withValues(alpha: 0.85)
                                        : isToday
                                            ? accent
                                            : Colors.transparent,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Text(
                                        '$day',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: hasWorkout || isToday
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          color: hasWorkout || isToday
                                              ? Colors.white
                                              : isFuture
                                                  ? textTertiary
                                                  : textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // ── View list link ──
                    if (monthWorkouts.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MonthWorkoutsScreen(
                                      workouts: monthWorkouts,
                                      monthLabel: _monthLabel)));
                          _load();
                        },
                        child: _BentoCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Text(
                                'View all workouts this month',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.arrow_forward_rounded,
                                  color: textSecondary, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + 4),
        child: FloatingActionButton.extended(
          onPressed: () => _startWorkout(DateTime.now()),
          backgroundColor: AppColors.primaryBtnBg(context),
          foregroundColor: Colors.white,
          elevation: isDark ? 0 : 4,
          icon: const Icon(Icons.add, size: 22),
          label: const Text(
            'New Workout',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Future<void> _showDaySheet(
    DateTime date,
    int day,
    List<Map<String, dynamic>> monthWorkouts,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: cardBg,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32, height: 3,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$day ${_monthLabel.split(' ').first}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: textPrimary),
                ),
              ),
              const SizedBox(height: 16),
              _SheetTile(
                icon: Icons.list_alt_outlined,
                iconColor: accent,
                title: 'View workouts',
                textColor: textPrimary,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MonthWorkoutsScreen(
                              workouts: monthWorkouts,
                              monthLabel: _monthLabel,
                              initialDay: day)));
                  if (mounted) _load();
                },
              ),
              _SheetTile(
                icon: Icons.add_rounded,
                iconColor: accent,
                title: 'Add another workout',
                textColor: textPrimary,
                onTap: () async {
                  Navigator.pop(context);
                  await _startWorkout(date);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable bento card ──
class _BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _BentoCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? const Color(0xFF242432)
              : const Color(0xFFEEEEEE),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

// ── Header icon button ──
class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeaderIcon(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

// ── Bottom sheet list tile ──
class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color textColor;
  final Color? subtitleColor;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.textColor,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: textColor)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(
                  fontSize: 12, color: subtitleColor ?? textColor))
          : null,
      onTap: onTap,
    );
  }
}
