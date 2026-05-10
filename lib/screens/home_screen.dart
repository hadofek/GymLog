import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/muscle_map_screen.dart';
import 'package:gymlog/screens/profile_setup_screen.dart';
import 'package:gymlog/screens/month_workouts_screen.dart';
import 'package:gymlog/screens/log_workout_screen.dart';
import 'package:gymlog/screens/cardio_log_screen.dart';
import 'package:gymlog/screens/flexibility_log_screen.dart';
import 'package:gymlog/screens/templates_screen.dart';
import 'package:gymlog/screens/workout_detail_screen.dart';
import 'package:gymlog/utils/body_svg_paths.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/utils/transitions.dart';
import 'package:gymlog/widgets/gymlog_wordmark.dart';
import 'package:gymlog/widgets/tip_overlay.dart';

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
  int _weeklyGoal = 3;
  Map<String, int> _muscleCounts = {};
  bool _showWelcomeBanner = false;
  Map<String, dynamic>? _draft;
  bool _loaded = false;

  final _statScrollCtrl = ScrollController();
  final _statCanScrollNotifier = ValueNotifier<bool>(false);

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
    _statScrollCtrl.addListener(_onStatScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onStatScroll());
    _loadFull();
  }

  void _onStatScroll() {
    if (!_statScrollCtrl.hasClients) return;
    _statCanScrollNotifier.value = _statScrollCtrl.position.maxScrollExtent > 0 &&
        _statScrollCtrl.position.pixels <
            _statScrollCtrl.position.maxScrollExtent - 4;
  }

  @override
  void dispose() {
    _statScrollCtrl.removeListener(_onStatScroll);
    _statScrollCtrl.dispose();
    _statCanScrollNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadFull() async {
    final since30 = DateTime.now().subtract(const Duration(days: 30));
    final results = await Future.wait([
      DBHelper.getWorkouts(),
      SharedPreferences.getInstance(),
      DBHelper.getMuscleGroupCounts(since: since30),
    ]);
    final w = results[0] as List<Map<String, dynamic>>;
    final prefs = results[1] as SharedPreferences;
    final rawCounts = results[2] as Map<String, int>;
    final normalized = <String, int>{};
    for (final e in rawCounts.entries) {
      final key = _normalizeGroup(e.key);
      normalized[key] = (normalized[key] ?? 0) + e.value;
    }
    final seenWelcome = prefs.getBool('seen_welcome') ?? false;
    final draft = await DBHelper.loadDraft();
    setState(() {
      _workouts = w;
      _userName = prefs.getString('user_name') ?? '';
      _userImage = prefs.getString('user_image');
      _weeklyGoal = prefs.getInt('weekly_goal') ?? 3;
      _muscleCounts = normalized;
      _showWelcomeBanner = !seenWelcome && w.isEmpty;
      _draft = draft;
      _loaded = true;
    });
  }

  /// Lightweight refresh after workout sessions — skips SharedPreferences
  /// (user name/photo/weekly goal don't change during a workout).
  Future<void> _refreshWorkouts() async {
    final since30 = DateTime.now().subtract(const Duration(days: 30));
    final results = await Future.wait([
      DBHelper.getWorkouts(),
      DBHelper.getMuscleGroupCounts(since: since30),
    ]);
    final w = results[0] as List<Map<String, dynamic>>;
    final rawCounts = results[1] as Map<String, int>;
    final normalized = <String, int>{};
    for (final e in rawCounts.entries) {
      final key = _normalizeGroup(e.key);
      normalized[key] = (normalized[key] ?? 0) + e.value;
    }
    final draft = await DBHelper.loadDraft();
    if (!mounted) return;
    setState(() {
      _workouts = w;
      _muscleCounts = normalized;
      _draft = draft;
    });
  }

  Future<void> _resumeDraft() async {
    final draft = _draft;
    if (draft == null) return;
    final type = draft['type'] as String? ?? 'weighted';
    final elapsedSeconds = draft['elapsed_seconds'] as int? ?? 0;
    List<Map<String, dynamic>> exercises = [];
    try {
      final decoded = jsonDecode(draft['exercises_json'] as String) as List;
      exercises = decoded.map((e) {
        final ex = Map<String, dynamic>.from(e as Map);
        ex['sets'] = (ex['sets'] as List).map((s) => Map<String, dynamic>.from(s as Map)).toList();
        return ex;
      }).toList();
    } catch (_) {}
    if (!mounted) return;
    await Navigator.push(
      context,
      fadeSlideRoute(LogWorkoutScreen(
        type: type,
        initialExercises: exercises,
        draftElapsedSeconds: elapsedSeconds,
      )),
    );
    _refreshWorkouts();
  }

  Future<void> _discardDraft() async {
    await DBHelper.clearDraft();
    if (mounted) setState(() => _draft = null);
  }

  Future<void> _dismissWelcomeBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_welcome', true);
    if (mounted) setState(() => _showWelcomeBanner = false);
  }

  String _normalizeGroup(String name) {
    final s = name.toLowerCase().trim();
    if (s.contains('chest') || s.contains('pec')) return 'chest';
    if (s.contains('back') || s.contains('lat')) return 'back';
    if (s.contains('shoulder') || s.contains('delt')) return 'shoulders';
    if (s.contains('bicep')) return 'biceps';
    if (s.contains('tricep')) return 'triceps';
    if (s.contains('core') || s.contains('abs') || s.contains('abdom')) return 'core';
    if (s.contains('quad') || s == 'legs') return 'quads';
    if (s.contains('hamstring')) return 'hamstrings';
    if (s.contains('glute') || s.contains('butt') || s.contains('hip')) return 'glutes';
    if (s.contains('calf') || s.contains('calves')) return 'calves';
    if (s.contains('trap')) return 'traps';
    if (s.contains('forearm')) return 'forearms';
    return s;
  }

  Future<void> _repeatLastWorkout() async {
    final last = _lastWorkout!;
    final type = last['type'] as String? ?? WorkoutTypes.weighted;
    if (type == WorkoutTypes.cardio) {
      await Navigator.push(context, fadeSlideRoute(CardioLogScreen(initialDate: DateTime.now())));
      _refreshWorkouts();
      return;
    }
    if (type == WorkoutTypes.flexibility) {
      await Navigator.push(context, fadeSlideRoute(FlexibilityLogScreen(initialDate: DateTime.now())));
      _refreshWorkouts();
      return;
    }
    final sets = await DBHelper.getSetsForWorkout(last['id'] as int);
    final seen = <String>{};
    final exerciseOrder = <String>[];
    for (final s in sets) {
      final name = s['exercise_name'] as String;
      if (seen.add(name)) exerciseOrder.add(name);
    }
    final initialExercises = exerciseOrder
        .map((name) => {'name': name, 'sets': <Map<String, dynamic>>[]})
        .toList();
    if (!mounted) return;
    await Navigator.push(
      context,
      fadeSlideRoute(LogWorkoutScreen(
        initialDate: DateTime.now(),
        type: type,
        initialExercises: initialExercises,
      )),
    );
    _refreshWorkouts();
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
      isScrollControlled: true,
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
                    subtitle: _workoutTypeSubtitle(t),
                    textColor: textPrimary,
                    subtitleColor: textSecondary,
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
    _refreshWorkouts();
  }

  String _workoutTypeSubtitle(String type) {
    switch (type) {
      case WorkoutTypes.weighted: return 'Barbell, dumbbell, machines';
      case WorkoutTypes.bodyweight: return 'Push-ups, pull-ups, dips';
      case WorkoutTypes.cardio: return 'Running, cycling, rowing';
      case WorkoutTypes.flexibility: return 'Yoga, stretching, mobility';
      default: return '';
    }
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

  Map<String, dynamic>? get _lastWorkout {
    if (_workouts.isEmpty) return null;
    final sorted = List<Map<String, dynamic>>.from(_workouts);
    sorted.sort((a, b) {
      final da = _parseDate(a['date'] as String);
      final db = _parseDate(b['date'] as String);
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return sorted.first;
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
    return '${d.day}/${d.month}';
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

  int get _workoutsThisWeek {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    return _workouts.where((w) {
      final date = _parseDate(w['date'] as String);
      if (date == null) return false;
      final d = DateTime(date.year, date.month, date.day);
      return !d.isBefore(weekStart);
    }).length;
  }

  Future<void> _showWeeklyGoalPicker() async {
    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);
    final accentContainer = AppColors.accentContainer(context);
    final currentGoal = _weeklyGoal;

    await showModalBottomSheet(
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
                    color: borderColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Weekly goal', style: KiStyles.headlineMd(color: textPrimary)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('How many workouts per week?',
                    style: KiStyles.label(color: textTertiary)),
              ),
              const SizedBox(height: 12),
              ...[2, 3, 4, 5, 6, 7].map((n) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('$n days / week', style: KiStyles.body(color: textPrimary)),
                trailing: currentGoal == n
                    ? Icon(Icons.check_rounded, color: accentContainer, size: 20)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('weekly_goal', n);
                  if (mounted) setState(() => _weeklyGoal = n);
                },
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

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
            if (!_loaded)
              LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: AppColors.accent(context).withValues(alpha: 0.5),
                minHeight: 2,
              ),
            // ── KO Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  // Left: avatar
                  Semantics(
                    label: 'Edit profile',
                    button: true,
                    child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                          context,
                          fadeSlideRoute(
                              const ProfileSetupScreen(isEditing: true)));
                      _refreshWorkouts();
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
                  )),
                  const SizedBox(width: 12),
                  // Center: GYMLOG wordmark
                  const Expanded(child: GymlogWordmark()),
                  // Right: templates
                  Semantics(
                    label: 'Templates',
                    button: true,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                          context, fadeSlideRoute(const TemplatesScreen())),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_outline_rounded,
                                color: textTertiary, size: 20),
                            const SizedBox(height: 2),
                            Text('TEMPLATES',
                                style: KiStyles.labelSm(color: textTertiary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Scrollable body ──
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Compact stat strip ──
                    Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                    Stack(
                      children: [
                    SingleChildScrollView(
                      controller: _statScrollCtrl,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(4, 16, 40, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Semantics(
                            label: 'Weekly goal: $_workoutsThisWeek of $_weeklyGoal workouts. Tap to change goal.',
                            button: true,
                            child: TipOverlay(
                              tipKey: 'tip_home_stats',
                              tipTitle: 'Weekly Goal',
                              tipBody: 'Tap to set how many workouts you want per week. Your progress fills in as you train.',
                              direction: TipDirection.below,
                              child: GestureDetector(
                              onTap: _showWeeklyGoalPicker,
                              child: _MicroStat(
                                value: '$_workoutsThisWeek/$_weeklyGoal',
                                label: 'THIS WEEK',
                                hint: 'tap to set goal',
                                primary: true,
                                valueColor: _workoutsThisWeek >= _weeklyGoal
                                    ? accentContainer
                                    : textPrimary,
                                labelColor: textTertiary,
                              ),
                            ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            width: 1,
                            height: 34,
                            color: AppColors.border(context),
                          ),
                          const SizedBox(width: 20),
                          _MicroStat(
                            value: '${monthWorkouts.length}',
                            label: _monthLabel.split(' ').first.toUpperCase(),
                            valueColor: textPrimary,
                            labelColor: textTertiary,
                          ),
                          if (totalMonthSeconds > 0) ...[
                            const SizedBox(width: 20),
                            Container(
                              width: 1,
                              height: 34,
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
                          if (streak > 0) ...[
                            const SizedBox(width: 20),
                            Container(
                              width: 1,
                              height: 34,
                              color: AppColors.border(context),
                            ),
                            const SizedBox(width: 20),
                            _MicroStat(
                              value: '$streak',
                              label: 'STREAK',
                              valueColor: textPrimary,
                              labelColor: textTertiary,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0, top: 0, bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          width: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [bg.withValues(alpha: 0), bg],
                            ),
                          ),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _statCanScrollNotifier,
                      builder: (_, canScroll, __) => canScroll
                          ? Positioned(
                              right: 6, top: 0, bottom: 0,
                              child: IgnorePointer(
                                child: Center(
                                  child: Icon(Icons.chevron_right_rounded,
                                      size: 14, color: textTertiary),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    ], // Stack children
                    ), // Stack

                    // ── Draft resume banner ──
                    if (_draft != null) ...[
                      Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: AppColors.accent(context).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.accent(context).withValues(alpha: 0.22)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.fitness_center_rounded,
                                  size: 18, color: AppColors.accent(context)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Unfinished workout',
                                        style: KiStyles.bodySemibold(color: textPrimary)),
                                    Text(
                                      () {
                                        final secs = _draft!['elapsed_seconds'] as int? ?? 0;
                                        final m = secs ~/ 60;
                                        final h = m ~/ 60;
                                        final rem = m % 60;
                                        final timeStr = h > 0 ? '${h}h ${rem}min' : m > 0 ? '${m}min' : '<1min';
                                        final type = WorkoutTypes.label(_draft!['type'] as String? ?? 'weighted');
                                        return '$type · $timeStr logged';
                                      }(),
                                      style: KiStyles.labelSm(color: textTertiary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Semantics(
                                label: 'Discard draft',
                                button: true,
                                child: GestureDetector(
                                  onTap: _discardDraft,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(Icons.delete_outline_rounded,
                                        size: 18, color: AppColors.error(context)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Semantics(
                                label: 'Resume draft workout',
                                button: true,
                                child: GestureDetector(
                                  onTap: _resumeDraft,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentContainer(context),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('Resume',
                                        style: KiStyles.label(
                                            color: AppColors.primaryBtnFg(context))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ── Welcome banner (first-run only) ──
                    if (_showWelcomeBanner) ...[
                      Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accentContainer.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: accentContainer.withValues(alpha: 0.18)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Welcome${_userName.isNotEmpty ? ', ${_userName.split(' ').first}' : ''}.',
                                    style: KiStyles.headlineMd(color: textPrimary),
                                  ),
                                  const Spacer(),
                                  Semantics(
                                    label: 'Dismiss welcome banner',
                                    button: true,
                                    child: GestureDetector(
                                      onTap: _dismissWelcomeBanner,
                                      behavior: HitTestBehavior.opaque,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Icon(Icons.close_rounded, size: 14, color: textTertiary),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap any day on the calendar to log your first workout. Your stats, streaks, and muscle map will fill in as you train.',
                                style: KiStyles.body(color: textSecondary),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  for (final item in [
                                    (Icons.calendar_today_rounded, 'Log a workout'),
                                    (Icons.bar_chart_rounded, 'Track progress'),
                                    (Icons.local_fire_department_rounded, 'Build streaks'),
                                  ])
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(item.$1, size: 13, color: accentContainer.withValues(alpha: 0.6)),
                                        const SizedBox(width: 4),
                                        Text(item.$2,
                                            style: KiStyles.label(color: textTertiary)),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ── Last workout line ──
                    if (_lastWorkout != null) ...[
                      Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                      GestureDetector(
                        onTap: () async {
                          final w = _lastWorkout!;
                          await Navigator.push(
                            context,
                            fadeSlideRoute(WorkoutDetailScreen(
                              workoutId: w['id'] as int,
                              date: w['date'] as String,
                              durationSeconds: w['duration_seconds'] as int? ?? 0,
                              type: w['type'] as String? ?? WorkoutTypes.weighted,
                            )),
                          );
                          _refreshWorkouts();
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 14),
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: WorkoutTypes.color(
                                      _lastWorkout!['type'] as String? ??
                                          WorkoutTypes.weighted,
                                      context),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                WorkoutTypes.label(
                                    _lastWorkout!['type'] as String? ??
                                        WorkoutTypes.weighted),
                                style: KiStyles.bodySemibold(color: textPrimary),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _relativeDate(_lastWorkout!['date'] as String),
                                style: KiStyles.labelSm(color: textTertiary),
                              ),
                              if ((_lastWorkout!['duration_seconds'] as int? ?? 0) > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  DBHelper.formatDuration(
                                      _lastWorkout!['duration_seconds'] as int),
                                  style: KiStyles.labelSm(color: textTertiary),
                                ),
                              ],
                              const Spacer(),
                              TipOverlay(
                                tipKey: 'tip_home_last_workout',
                                tipTitle: 'Repeat Workout',
                                tipBody: 'Starts a new session with the same exercises as your last workout, pre-loaded and ready to go.',
                                direction: TipDirection.above,
                                child: Semantics(
                                label: 'Repeat last workout',
                                button: true,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _repeatLastWorkout,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Text(
                                      'REPEAT',
                                      style: KiStyles.labelSm(color: accentContainer),
                                    ),
                                  ),
                                ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  color: textTertiary, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ── Calendar card ──
                    Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                    TipOverlay(
                      tipKey: 'tip_home_calendar',
                      tipTitle: 'Training Calendar',
                      tipBody: 'Tap any empty day to log a workout on that date. Days with a dot are already logged — tap to view or add.',
                      direction: TipDirection.below,
                      child: _KoBentoCard(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
                      child: Column(
                        children: [
                          // Month nav
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Semantics(
                                label: 'Previous month',
                                button: true,
                                child: GestureDetector(
                                  onTap: _prevMonth,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(Icons.chevron_left,
                                        color: textSecondary, size: 20),
                                  ),
                                ),
                              ),
                              Text(_monthLabel,
                                  style: KiStyles.bodySemibold(
                                      color: textPrimary)),
                              Semantics(
                                label: 'Next month',
                                button: true,
                                enabled: !isCurrentMonth,
                                child: GestureDetector(
                                  onTap: isCurrentMonth ? null : _nextMonth,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(Icons.chevron_right,
                                        color: isCurrentMonth
                                            ? textTertiary
                                            : textSecondary,
                                        size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Day-of-week headers — Monday first
                          ExcludeSemantics(
                            child: Row(
                              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                                  .map((d) => Expanded(
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
                              childAspectRatio: 1.05,
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

                              return Semantics(
                                label: isFuture
                                    ? '$day, future date'
                                    : hasWorkout
                                        ? '$day, workout logged'
                                        : isToday
                                            ? '$day, today, tap to log workout'
                                            : '$day, tap to log workout',
                                button: !isFuture,
                                child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: isFuture
                                    ? null
                                    : hasWorkout
                                        ? () async {
                                            await _showDaySheet(
                                                tappedDate, day, monthWorkouts);
                                            _refreshWorkouts();
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
                                          style: (isToday || hasWorkout
                                                  ? KiStyles.label
                                                  : KiStyles.labelSm)(
                                            color: isToday
                                                ? bg
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
                              ),
                            );
                            },
                          ),
                        ],
                      ),
                    ),
                    ), // TipOverlay(tip_home_calendar)

                    // ── Compact muscle map ──
                    Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                    TipOverlay(
                      tipKey: 'tip_home_muscles',
                      tipTitle: 'Muscle Activity Map',
                      tipBody: 'Shows which muscles you trained in the last 30 days. Colours go blue → red as sessions increase. Tap to open the full map.',
                      direction: TipDirection.above,
                      child: Semantics(
                      label: 'Muscle activity map. Tap to view details.',
                      button: true,
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(context, fadeSlideRoute(const MuscleMapScreen()));
                          _refreshWorkouts();
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('MUSCLES', style: KiStyles.label(color: textTertiary)),
                                  const SizedBox(width: 6),
                                  Text('· LAST 30 DAYS', style: KiStyles.labelSm(color: textTertiary)),
                                  const Spacer(),
                                  Icon(Icons.chevron_right, color: textTertiary, size: 16),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 160,
                                width: double.infinity,
                                child: _muscleCounts.isEmpty
                                    ? Center(
                                        child: Text(
                                          'Log a workout to track your muscle activity here.',
                                          style: KiStyles.labelSm(color: textTertiary),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    : SvgPicture.string(
                                        buildBodySvg(
                                          counts: _muscleCounts,
                                          totalCount: _muscleCounts.values.fold(0, (a, b) => a + b),
                                          isDark: AppColors.isDark(context),
                                        ),
                                        fit: BoxFit.contain,
                                      ),
                              ),
                              if (_muscleCounts.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const _ColorDot(color: AppColors.muscleMapBlue),
                                    const SizedBox(width: 4),
                                    const _ColorDot(color: AppColors.muscleMapPurple),
                                    const SizedBox(width: 4),
                                    const _ColorDot(color: AppColors.muscleMapPink),
                                    const SizedBox(width: 4),
                                    const _ColorDot(color: AppColors.muscleMapRed),
                                    const SizedBox(width: 6),
                                    Text('fewer → more sessions per muscle', style: KiStyles.labelSm(color: textTertiary)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    ), // TipOverlay(tip_home_muscles)

                    // ── Empty state ──
                    if (_workouts.isEmpty) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No workouts yet.',
                              style: KiStyles.headlineLg(color: textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap New Workout below, or tap any calendar day to log a workout on that date.',
                              style: KiStyles.body(color: textTertiary),
                            ),
                            const SizedBox(height: 16),
                            // ── Calendar legend ──
                            Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: accentContainer,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('Workout logged', style: KiStyles.labelSm(color: textTertiary)),
                                const SizedBox(width: 16),
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: accentContainer, width: 1.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('Today', style: KiStyles.labelSm(color: textTertiary)),
                              ],
                            ),
                          ],
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
          backgroundColor: AppColors.accentContainer(context),
          foregroundColor: AppColors.primaryBtnFg(context),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.add, size: 22),
          label: Text(
            'New Workout',
            style: KiStyles.bodySemibold(color: AppColors.primaryBtnFg(context)),
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
                  if (mounted) _refreshWorkouts();
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

  const _KoBentoCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
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
  /// Primary stats use headlineLg (larger, heavier) for visual anchoring.
  final bool primary;
  /// Optional hint shown below the label (e.g. "tap to edit").
  final String? hint;

  const _MicroStat({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.labelColor,
    this.primary = false,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: primary
              ? KiStyles.headlineLg(color: valueColor)
              : KiStyles.headlineMd(color: valueColor),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(label, style: KiStyles.labelSm(color: labelColor)),
            if (hint != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 9, color: labelColor),
            ],
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 1),
          Text(hint!, style: KiStyles.labelSm(color: labelColor.withValues(alpha: 0.7))),
        ],
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

class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
