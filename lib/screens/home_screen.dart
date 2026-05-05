import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/profile_setup_screen.dart';
import 'package:gymlog/screens/month_workouts_screen.dart';
import 'package:gymlog/screens/log_workout_screen.dart';
import 'package:gymlog/screens/cardio_log_screen.dart';
import 'package:gymlog/screens/flexibility_log_screen.dart';
import 'package:gymlog/screens/templates_screen.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/utils/transitions.dart';

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

  Map<int, double> get _workedOutDays {
    final result = <int, double>{};
    for (final w in _workouts) {
      final date = _parseDate(w['date'] as String);
      if (date != null &&
          date.month == _currentMonth.month &&
          date.year == _currentMonth.year) {
        final secs = w['duration_seconds'] as int? ?? 0;
        result.putIfAbsent(date.day, () => _durationAlpha(secs));
      }
    }
    return result;
  }

  double _durationAlpha(int seconds) {
    if (seconds < 1800) return 0.50;
    if (seconds < 3600) return 0.68;
    if (seconds < 5400) return 0.84;
    return 1.0;
  }

  List<Map<String, dynamic>> get _monthWorkouts {
    return _workouts.where((w) {
      final date = _parseDate(w['date'] as String);
      return date != null &&
          date.month == _currentMonth.month &&
          date.year == _currentMonth.year;
    }).toList();
  }

  List<Map<String, dynamic>> get _recentWorkouts {
    final sorted = List<Map<String, dynamic>>.from(_workouts);
    sorted.sort((a, b) {
      final da = _parseDate(a['date'] as String);
      final db = _parseDate(b['date'] as String);
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return sorted.take(3).toList();
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

  String _relativeDate(String dateStr) {
    final date = _parseDate(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${d.day}/${d.month}/${d.year}';
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
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Start a workout',
                    style: KiStyles.headlineMd(color: textPrimary)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose a type to begin',
                    style: KiStyles.label(color: AppColors.textTertiary(ctx))),
              ),
              const SizedBox(height: 16),
              ...WorkoutTypes.all.map((t) => _SheetTile(
                    icon: WorkoutTypes.icon(t),
                    iconColor: WorkoutTypes.color(t, ctx),
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
      await Navigator.push(context, fadeSlideRoute(const TemplatesScreen()));
    } else if (type == WorkoutTypes.cardio) {
      await Navigator.push(
          context, fadeSlideRoute(CardioLogScreen(initialDate: date)));
    } else if (type == WorkoutTypes.flexibility) {
      await Navigator.push(
          context, fadeSlideRoute(FlexibilityLogScreen(initialDate: date)));
    } else {
      await Navigator.push(
          context,
          fadeSlideRoute(LogWorkoutScreen(initialDate: date, type: type)));
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

  int get _totalWorkouts => _workouts.length;

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    // Monday-first: Monday=0 ... Sunday=6
    final rawWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final firstWeekday = (rawWeekday - 1) % 7; // Mon=0, Sun=6
    final monthWorkouts = _monthWorkouts;
    final totalMonthSeconds = monthWorkouts.fold(
        0, (sum, w) => sum + (w['duration_seconds'] as int? ?? 0));
    final workedDays = _workedOutDays;

    final isCurrentMonth = _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;
    final today = DateTime.now().day;
    final streak = _currentStreak;

    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── KO Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  // Left: avatar
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                          context,
                          fadeSlideRoute(
                              const ProfileSetupScreen(isEditing: true)));
                      _load();
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.surfaceContainerHigh(context),
                      backgroundImage: _userImage != null
                          ? FileImage(File(_userImage!))
                          : null,
                      child: _userImage == null
                          ? Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : '?',
                              style: KiStyles.bodySemibold(color: textPrimary))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Center: GYMLOG wordmark
                  Expanded(
                    child: Text(
                      'GYMLOG',
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 3,
                        color: Color(0xFFE8E8E8),
                      ),
                    ),
                  ),
                  // Right: templates
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context, fadeSlideRoute(const TemplatesScreen())),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.bookmark_outline_rounded,
                          color: textTertiary, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Scrollable body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Compact stat strip ──
                    Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _MicroStat(
                            value: '$_totalWorkouts',
                            label: 'ALL TIME',
                            valueColor: textPrimary,
                            labelColor: textTertiary,
                          ),
                          const SizedBox(width: 20),
                          Container(
                            width: 1,
                            height: 30,
                            color: AppColors.border(context),
                          ),
                          const SizedBox(width: 20),
                          _MicroStat(
                            value: '${monthWorkouts.length}',
                            label: _monthLabel.split(' ').first.toUpperCase(),
                            valueColor: accentContainer,
                            labelColor: textTertiary,
                          ),
                          if (totalMonthSeconds > 0) ...[
                            const SizedBox(width: 20),
                            Container(
                              width: 1,
                              height: 30,
                              color: AppColors.border(context),
                            ),
                            const SizedBox(width: 20),
                            _MicroStat(
                              value: DBHelper.formatDuration(totalMonthSeconds),
                              label: 'LOGGED',
                              valueColor: textPrimary,
                              labelColor: textTertiary,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Streak card ──
                    if (streak > 0)
                      _KoBentoCard(
                        radius: 14,
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('STREAK',
                                    style: KiStyles.label(color: textTertiary)),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$streak',
                                      style: KiStyles.headlineLg(
                                          color: accentContainer),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 5, bottom: 3),
                                      child: Text(
                                        streak == 1 ? 'day' : 'days',
                                        style: KiStyles.label(
                                            color: textTertiary),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            // Streak dash indicators (up to 7)
                            Expanded(
                              child: Row(
                                children: List.generate(7, (i) {
                                  final filled = i < streak.clamp(0, 7);
                                  return Expanded(
                                    child: Container(
                                      height: 3,
                                      margin: EdgeInsets.only(
                                          right: i < 6 ? 4 : 0),
                                      decoration: BoxDecoration(
                                        color: filled
                                            ? const Color(0xFFE8E8E8)
                                            : const Color(0xFF1A1A1A),
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Calendar card ──
                    Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                    _KoBentoCard(
                      radius: 20,
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
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
                              Text(_monthLabel,
                                  style: KiStyles.bodySemibold(
                                      color: textPrimary)),
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

                          // Day-of-week headers — Monday first
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                                .map((d) => SizedBox(
                                      width: 34,
                                      child: Center(
                                        child: Text(
                                          d,
                                          style: KiStyles.labelSm(
                                              color: textTertiary),
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
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 0,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: firstWeekday + daysInMonth,
                            itemBuilder: (ctx, index) {
                              if (index < firstWeekday) return const SizedBox();
                              final day = index - firstWeekday + 1;
                              final isToday = isCurrentMonth && day == today;
                              final workoutAlpha = workedDays[day];
                              final hasWorkout = workoutAlpha != null;
                              final isFuture = isCurrentMonth && day > today;

                              final tappedDate = DateTime(
                                  _currentMonth.year, _currentMonth.month, day);

                              return GestureDetector(
                                onTap: isFuture
                                    ? null
                                    : hasWorkout
                                        ? () async {
                                            await _showDaySheet(
                                                tappedDate, day, monthWorkouts);
                                            _load();
                                          }
                                        : () => _startWorkout(tappedDate),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Day number
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isToday
                                            ? accentContainer
                                            : Colors.transparent,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$day',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isToday || hasWorkout
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                            color: isToday
                                                ? const Color(0xFF000000)
                                                : hasWorkout
                                                    ? textPrimary
                                                    : isFuture
                                                        ? textTertiary
                                                        : textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Dot BELOW the number (KO calendar spec)
                                    const SizedBox(height: 3),
                                    if (hasWorkout)
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: accentContainer.withValues(
                                              alpha: workoutAlpha),
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 5),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // ── Recent Activity ──
                    if (_recentWorkouts.isNotEmpty) ...[
                      Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                      _KoBentoCard(
                        radius: 16,
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RECENT',
                                style: KiStyles.label(color: textTertiary)),
                            const SizedBox(height: 10),
                            ..._recentWorkouts.asMap().entries.map((entry) {
                              final i = entry.key;
                              final w = entry.value;
                              final type = w['type'] as String? ??
                                  WorkoutTypes.weighted;
                              final typeColor = WorkoutTypes.color(type, context);
                              final secs =
                                  w['duration_seconds'] as int? ?? 0;
                              return Column(
                                children: [
                                  if (i > 0)
                                    Divider(
                                      height: 1,
                                      thickness: 0.5,
                                      color: AppColors.divider(context),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          child: Text(
                                            (i + 1)
                                                .toString()
                                                .padLeft(2, '0'),
                                            style: KiStyles.labelSm(
                                                color: textTertiary),
                                          ),
                                        ),
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: typeColor,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            WorkoutTypes.label(type),
                                            style: KiStyles.bodySemibold(
                                                color: textPrimary),
                                          ),
                                        ),
                                        if (secs > 0) ...[
                                          Text(
                                            DBHelper.formatDuration(secs),
                                            style: KiStyles.labelSm(
                                                color: textSecondary),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        Text(
                                          _relativeDate(
                                              w['date'] as String),
                                          style: KiStyles.labelSm(
                                              color: textTertiary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    // ── Empty state ──
                    if (_workouts.isEmpty) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start logging.',
                              style: KiStyles.headlineLg(color: textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap any day in the calendar or use New Workout.',
                              style: KiStyles.body(color: textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── View all link ──
                    if (monthWorkouts.isNotEmpty) ...[
                      Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                              context,
                              fadeSlideRoute(MonthWorkoutsScreen(
                                  workouts: monthWorkouts,
                                  monthLabel: _monthLabel)));
                          _load();
                        },
                        child: _KoBentoCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 16),
                          child: Row(
                            children: [
                              Text('View all workouts this month',
                                  style:
                                      KiStyles.bodySemibold(color: textPrimary)),
                              const Spacer(),
                              Icon(Icons.arrow_forward_rounded,
                                  color: textTertiary, size: 16),
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
          backgroundColor: const Color(0xFF000000),
          foregroundColor: const Color(0xFFE8E8E8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE8E8E8), width: 1),
          ),
          icon: const Icon(Icons.add, size: 22),
          label: Text(
            'New Workout',
            style: KiStyles.bodySemibold(color: const Color(0xFFE8E8E8)),
          ),
        ),
      ),
    );
  }

  Future<void> _showDaySheet(
    DateTime date,
    int day,
    List<Map<String, dynamic>> monthWorkouts,
  ) async {
    final cardBg = AppColors.cardBg(context);
    final borderColor = AppColors.border(context);
    final textPrimary = AppColors.textPrimary(context);
    final accent = AppColors.accent(context);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: cardBg,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
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
                  style: KiStyles.headlineMd(color: textPrimary),
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
                      fadeSlideRoute(MonthWorkoutsScreen(
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

// ── Flat section wrapper (no box, just padding) ────────────────────────────────
class _KoBentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const _KoBentoCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

// ── Inline stat label+value pair ───────────────────────────────────────────────
class _MicroStat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final Color labelColor;

  const _MicroStat({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: KiStyles.headlineMd(color: valueColor)),
        const SizedBox(height: 1),
        Text(label, style: KiStyles.labelSm(color: labelColor)),
      ],
    );
  }
}

// ── Bottom sheet list tile ─────────────────────────────────────────────────────
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
          style: KiStyles.bodySemibold(color: textColor)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: KiStyles.labelSm(color: subtitleColor ?? textColor))
          : null,
      onTap: onTap,
    );
  }
}
