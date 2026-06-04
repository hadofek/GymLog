import 'dart:async';
import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/exercise_data.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/utils/weight_format.dart';
import 'package:gymlog/widgets/gymlog_wordmark.dart';
import 'package:gymlog/widgets/rest_timer_card.dart';

class AddExerciseScreen extends StatefulWidget {
  final List<String> allExercises;
  final String workoutType;
  const AddExerciseScreen({
    super.key,
    required this.allExercises,
    this.workoutType = WorkoutTypes.weighted,
  });
  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  // ── Browse phase ──
  String? _selectedExercise;
  String? _expandedCategory;
  String? _selectedFilter;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Cache for performance
  late List<String> _libraryNames;
  late List<String> _customExercises;
  late List<String> _allExercisesCombined;

  @override
  void initState() {
    super.initState();
    _initCaches();
  }

  @override
  void didUpdateWidget(AddExerciseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allExercises != widget.allExercises ||
        oldWidget.workoutType != widget.workoutType) {
      _initCaches();
    }
  }

  void _initCaches() {
    _libraryNames = (widget.workoutType == WorkoutTypes.bodyweight
            ? ExerciseData.bodyweight
            : ExerciseData.weighted)
        .values
        .expand((e) => e)
        .toList();

    final libSet = _libraryNames.map((e) => e.toLowerCase()).toSet();
    _customExercises = widget.allExercises
        .where((e) => !libSet.contains(e.toLowerCase()))
        .toList();

    _allExercisesCombined = [..._libraryNames, ..._customExercises];
  }

  // ── Log sets phase ──
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final List<Map<String, dynamic>> _sets = [];
  List<Map<String, dynamic>> _lastSets = [];
  bool? _isBodyweight;
  bool _isWeightedExercise = false;
  bool _isTimed = false;
  double _exercisePR = 0;
  bool _isShowingAddSheet = false;

  // ── Rest Timer State (Elevated) ──
  Timer? _restTimer;
  int? _restTarget;
  bool _isResting = false;
  final _restTickNotifier = ValueNotifier<int>(0);


  Map<String, List<String>> get _currentLibrary =>
      widget.workoutType == WorkoutTypes.bodyweight
          ? ExerciseData.bodyweight
          : ExerciseData.weighted;

  // ── Fuzzy duplicate detection ──────────────────────────────────────────────

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Standard optimization: ensure 'a' is shorter to save space.
    if (a.length > b.length) {
      final temp = a; a = b; b = temp;
    }

    final n = a.length;
    final m = b.length;
    List<int> prev = List<int>.generate(n + 1, (i) => i);
    List<int> curr = List<int>.filled(n + 1, 0);

    for (int j = 1; j <= m; j++) {
      curr[0] = j;
      for (int i = 1; i <= n; i++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[i] = min(
          min(curr[i - 1] + 1, prev[i] + 1),
          prev[i - 1] + cost,
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    return prev[n];
  }

  /// Returns the existing exercise name that fuzzy-matches [input], or null.
  String? _fuzzyMatch(String input) {
    final na = _norm(input);
    if (na.isEmpty) return null;

    for (final e in _allExercisesCombined) {
      final nb = _norm(e);
      if (na == nb) return e;

      // Quick length filter: if lengths differ by more than the max possible
      // threshold (2), they can't match.
      if ((na.length - nb.length).abs() > 2) continue;

      final maxLen = max(na.length, nb.length);
      final threshold = (maxLen * 0.15).floor().clamp(1, 2);
      if (_levenshtein(na, nb) <= threshold) return e;
    }
    return null;
  }

  Future<void> _addCustomExercise() async {
    if (_isShowingAddSheet) return;
    _isShowingAddSheet = true;

    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AddCustomExerciseSheet(
        fuzzyMatch: _fuzzyMatch,
      ),
    );

    _isShowingAddSheet = false;
    if (name == null || name.trim().isEmpty || !mounted) return;
    await _pickExercise(name.trim());
  }

  Future<void> _pickExercise(String name) async {
    final last = await DBHelper.getLastSets(name);
    bool isBw = await DBHelper.isExerciseBodyweight(name);
    final pr = await DBHelper.getMaxWeightForExercise(name);
    await WeightFormat.load();
    // If this is a bodyweight workout, flag the exercise permanently so the
    // history screen can show reps progress instead of weight progress.
    if (!isBw && widget.workoutType == WorkoutTypes.bodyweight) {
      isBw = true;
      await DBHelper.setExerciseBodyweight(name, true);
    }
    if (!mounted) return;
    setState(() {
      _selectedExercise = name;
      _lastSets = last;
      _isTimed = ExerciseData.isTimedExercise(name);
      _isBodyweight = (!_isTimed && (isBw || ExerciseData.isCoreBodyweightExercise(name))) ? true : null;
      _exercisePR = pr;
      _isWeightedExercise = false;
      _sets.clear();
    });
  }

  static String _fmtSecs(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final rem = s % 60;
    return rem == 0 ? '${m}m' : '${m}m ${rem}s';
  }

  void _saveSet() {
    if (_isTimed) {
      final secs = int.tryParse(_repsController.text);
      if (secs == null || secs <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a duration.')),
        );
        return;
      }
      setState(() {
        _sets.add({'weight': 0.0, 'reps': secs, 'timed': true});
        _repsController.clear();
      });
      _startRestTimer();
      _showTimerSheet(context);
      return;
    }

    final isBwMode = widget.workoutType == WorkoutTypes.bodyweight || _isBodyweight == true;
    if (isBwMode && !_isWeightedExercise) {
      final r = int.tryParse(_repsController.text);
      if (r == null || r <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid reps')),
        );
        return;
      }
      setState(() {
        _sets.add({'weight': 0.0, 'reps': r, 'bodyweight': true});
        _repsController.clear();
      });
      _startRestTimer();
      _showTimerSheet(context);
      return;
    }

    final w = double.tryParse(_weightController.text);
    final r = int.tryParse(_repsController.text);
    if (w == null || r == null || w < 0 || r <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid weight and reps')),
      );
      return;
    }

    if (w == 0) {
      if (_isBodyweight == true) {
        setState(() {
          _sets.add({'weight': w, 'reps': r});
          _weightController.clear();
          _repsController.clear();
        });
        _startRestTimer();
        _showTimerSheet(context);
        return;
      }
      // _pickExercise already queried is_bodyweight; if it were true _isBodyweight
      // would already be set. Show the dialog synchronously — no DB call needed.
      showDialog(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          backgroundColor: AppColors.cardBg(dlgCtx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Bodyweight exercise?',
              style: KiStyles.headlineMd(color: AppColors.textPrimary(dlgCtx))),
          content: Text('You entered 0 kg. Is this a bodyweight exercise?',
              style: KiStyles.body(color: AppColors.textSecondary(dlgCtx))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text('No', style: KiStyles.label(color: AppColors.textSecondary(dlgCtx))),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dlgCtx);
                final exerciseName = _selectedExercise ?? '';
                setState(() {
                  _isBodyweight = true;
                  _sets.add({'weight': w, 'reps': r});
                  _weightController.clear();
                  _repsController.clear();
                });
                // Show timer before the async DB write so context is still valid.
                if (mounted) {
                  _startRestTimer();
                  _showTimerSheet(context);
                }
                if (exerciseName.isNotEmpty) {
                  await DBHelper.setExerciseBodyweight(exerciseName, true);
                }
              },
              child: Text('Yes, bodyweight',
                  style: KiStyles.label(color: AppColors.accentContainer(dlgCtx))),
            ),
          ],
        ),
      );
      return;
    }

    final isPR = w > 0 && _exercisePR > 0 && w > _exercisePR;
    if (w > _exercisePR) _exercisePR = w;
    setState(() {
      _sets.add({'weight': w, 'reps': r, 'isPR': isPR});
      _weightController.clear();
      _repsController.clear();
    });
    if (isPR) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 20),
            const SizedBox(width: 8),
            Text('New Personal Record!',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
          ]),
          backgroundColor: AppColors.cardBg(context),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
    _startRestTimer();
    _showTimerSheet(context);
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    _restTickNotifier.value = 0;
    setState(() => _isResting = true);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _restTickNotifier.value++;
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restTickNotifier.value = 0;
    });
  }

  Future<void> _showTimerSheet(BuildContext context) async {
    final timerGreen = WorkoutTypes.color(WorkoutTypes.cardio, context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 24,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              RestTimerCard(
                accentColor: timerGreen,
                onDismiss: () => Navigator.pop(ctx),
                externalTickNotifier: _restTickNotifier,
                initialTarget: _restTarget,
                onTargetChanged: (newTarget) => setState(() => _restTarget = newTarget),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: timerGreen,
                      foregroundColor: AppColors.primaryBtnFg(ctx),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: Text('Done',
                        style: KiStyles.bodySemibold(
                            color: AppColors.primaryBtnFg(ctx))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _done() {
    if (_selectedExercise == null || _sets.isEmpty) return;
    Navigator.pop(context, {
      'name': _selectedExercise!,
      'sets': _sets,
      'restTarget': _restTarget,
      'restTicks': _isResting ? _restTickNotifier.value : null,
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    _restTimer?.cancel();
    _restTickNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Custom header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary(context)),
                  onPressed: () {
                    if (_selectedExercise != null) {
                      setState(() {
                        _selectedExercise = null;
                        _sets.clear();
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                const Expanded(child: GymlogWordmark()),
                Text(
                  _selectedExercise != null ? 'LOG SETS' : 'ADD EXERCISE',
                  style: KiStyles.label(color: AppColors.textSecondary(context)),
                ),
                if (_selectedExercise != null && _sets.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _done,
                    child: Text('Done', style: KiStyles.bodySemibold(color: AppColors.textPrimary(context))),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),

          // ── Sticky Rest Bar (Fixed outside scroll) ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              axisAlignment: -1.0,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: _isResting
                ? _StickyRestBar(
                    tickNotifier: _restTickNotifier,
                    target: _restTarget,
                    accentColor: WorkoutTypes.color(WorkoutTypes.cardio, context),
                    onStop: _stopRestTimer,
                    onMaximize: () async {
                      await _showTimerSheet(context);
                      if (mounted) setState(() {});
                    },
                  )
                : const SizedBox.shrink(),
          ),

          Expanded(
            child: _selectedExercise == null
                ? _buildBrowse(context)
                : _buildLogSets(context),
          ),
        ],
      ),
    );
  }

  // ── Phase 1: Browse ────────────────────────────────────────────────────────

  List<String> get _searchResults {
    final q = _searchQuery.toLowerCase().trim();
    if (q.isEmpty) return [];
    final seen = <String>{};
    return _allExercisesCombined
        .where((e) => e.toLowerCase().contains(q) && seen.add(e.toLowerCase()))
        .toList();
  }

  Widget _buildBrowse(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);
    final inputFill = AppColors.inputFill(context);
    final hasSearch = _searchQuery.isNotEmpty;
    final results = _searchResults;
    final custom = _customExercises;

    return Column(
      children: [
        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: inputFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 17, color: textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: KiStyles.body(color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search exercises',
                      hintStyle: KiStyles.body(color: textTertiary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  _Pressable(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                        child: Icon(Icons.close_rounded, size: 16, color: textTertiary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: borderColor),

        // ── Category filter chips ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: _currentLibrary.keys.map((cat) {
              final selected = _selectedFilter == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedFilter = selected ? null : cat;
                    _expandedCategory = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accentContainer(context)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.accentContainer(context)
                            : borderColor,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: KiStyles.labelSm(
                          color: selected ? AppColors.primaryBtnFg(context) : textPrimary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: borderColor),

        // ── Exercise list ──
        Expanded(
          child: ListView(
            children: hasSearch
                ? [
                    ...results.map((name) => _exerciseRow(name, context)),
                    if (!results.any((r) =>
                        r.toLowerCase() == _searchQuery.trim().toLowerCase()))
                      _addCustomRow(_searchQuery.trim(), context),
                  ]
                : _selectedFilter != null
                    ? _currentLibrary[_selectedFilter]!
                        .map((n) => _exerciseRow(n, context))
                        .toList()
                    : [
                        _myExercisesHeader(custom, context),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          child: _expandedCategory == 'MY EXERCISES'
                              ? Column(children: [
                                  ...custom.map((n) => _exerciseRow(n, context)),
                                  _addNewExerciseRow(context),
                                ])
                              : const SizedBox.shrink(),
                        ),
                        ..._currentLibrary.entries.map((entry) {
                          final key = entry.key;
                          return Column(
                            children: [
                              _categoryHeader(key, context),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeInOutCubic,
                                child: _expandedCategory == key
                                    ? Column(children: entry.value.map((n) => _exerciseRow(n, context)).toList())
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          );
                        }),
                      ],
          ),
        ),
      ],
    );
  }

  Widget _addCustomRow(String name, BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);
    final accent = AppColors.accentContainer(context);

    final match = _fuzzyMatch(name);

    // Fuzzy match found — redirect to the existing exercise instead of creating a duplicate.
    if (match != null) {
      return _Pressable(
        onTap: () => _pickExercise(match),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 16, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Use  ',
                              style: KiStyles.labelSm(color: textTertiary),
                            ),
                            TextSpan(
                              text: '"$match"',
                              style: KiStyles.bodySemibold(color: textPrimary),
                            ),
                            TextSpan(
                              text: '  (already exists)',
                              style: KiStyles.labelSm(color: textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: borderColor),
          ],
        ),
      );
    }

    // No match — show the normal "Add [name]" row.
    return _Pressable(
      onTap: () => _pickExercise(name),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 16, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Add  ',
                            style: KiStyles.labelSm(color: textTertiary),
                          ),
                          TextSpan(
                            text: '"$name"',
                            style: KiStyles.bodySemibold(color: textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: borderColor),
        ],
      ),
    );
  }

  Widget _myExercisesHeader(List<String> custom, BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);
    final accent = AppColors.accentContainer(context);
    final isExpanded = _expandedCategory == 'MY EXERCISES';

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: _Pressable(
                  onTap: () => setState(
                      () => _expandedCategory = isExpanded ? null : 'MY EXERCISES'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                    child: Row(
                      children: [
                        Text('MY EXERCISES', style: KiStyles.body(color: textPrimary)),
                        if (custom.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('${custom.length}',
                              style: KiStyles.labelSm(color: textTertiary)),
                        ],
                        const Spacer(),
                        AnimatedRotation(
                          turns: isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          child: Icon(Icons.chevron_right_rounded, size: 18, color: textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _addCustomExercise,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Icon(Icons.add_rounded, size: 20, color: accent),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: borderColor),
      ],
    );
  }

  Widget _addNewExerciseRow(BuildContext context) {
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);
    final accent = AppColors.accentContainer(context);

    return _Pressable(
      onTap: _addCustomExercise,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 0, 20, 0),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 16, color: accent),
                  const SizedBox(width: 10),
                  Text('New exercise', style: KiStyles.body(color: textTertiary)),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: borderColor),
        ],
      ),
    );
  }

  Widget _categoryHeader(String label, BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);
    final isExpanded = _expandedCategory == label;

    return _Pressable(
      onTap: () => setState(() => _expandedCategory = isExpanded ? null : label),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Text(label, style: KiStyles.body(color: textPrimary)),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: Icon(Icons.chevron_right_rounded, size: 18, color: textTertiary),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: borderColor),
        ],
      ),
    );
  }

  Widget _exerciseRow(String name, BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);

    return _Pressable(
      onTap: () => _pickExercise(name),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 0, 20, 0),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(child: Text(name, style: KiStyles.body(color: textPrimary))),
                  Icon(Icons.add_rounded, size: 16, color: textTertiary),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: borderColor),
        ],
      ),
    );
  }

  // ── Phase 2: Log sets ──────────────────────────────────────────────────────

  Widget _buildLogSets(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);
    final borderColor = AppColors.border(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Last session reference ──
                if (_lastSets.isNotEmpty) ...[
                  Divider(height: 1, thickness: 0.5, color: borderColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('LAST SESSION',
                              style: KiStyles.labelSm(color: textTertiary)),
                          if (_exercisePR > 0) ...[
                            const Spacer(),
                            Text(
                              'PR  ${WeightFormat.format(_exercisePR)}',
                              style: KiStyles.labelSm(color: textTertiary),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 8),
                        ..._lastSets.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                'Set ${s['set_number']}  ·  ${WeightFormat.format((s['weight'] as num).toDouble())} × ${s['reps']} reps',
                                style: KiStyles.body(color: textSecondary),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],

                // ── Logged sets ──
                if (_sets.isNotEmpty) ...[
                  Divider(height: 1, thickness: 0.5, color: borderColor),
                  ..._sets.asMap().entries.map((e) => Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(children: [
                              Text(
                                '${e.key + 1}',
                                style: KiStyles.labelSm(color: textTertiary),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                e.value['timed'] == true
                                    ? _fmtSecs(e.value['reps'] as int)
                                    : e.value['bodyweight'] == true
                                        ? 'Bodyweight  ×  ${e.value['reps']} reps'
                                        : '${WeightFormat.format((e.value['weight'] as num).toDouble())}  ×  ${e.value['reps']} reps',
                                style: KiStyles.bodySemibold(color: textPrimary),
                              ),
                              if (e.value['isPR'] == true) ...[
                                const SizedBox(width: 8),
                                Text('PR',
                                    style: KiStyles.labelSm(color: textTertiary)),
                              ],
                              const Spacer(),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _sets.removeAt(e.key)),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: Icon(Icons.close,
                                        size: 16, color: textTertiary),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                          Divider(height: 1, thickness: 0.5, color: borderColor),
                        ],
                      )),
                ],

                if (_sets.isEmpty)
                  Divider(height: 1, thickness: 0.5, color: borderColor),

                // ── Set number label ──
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 12),
                  child: Text(
                    _sets.isEmpty ? 'First set' : 'Set ${_sets.length + 1}',
                    style: KiStyles.label(color: textTertiary),
                  ),
                ),

                // ── Bodyweight toggle (hidden for timed exercises) ──
                if (!_isTimed && (widget.workoutType == WorkoutTypes.bodyweight || _isBodyweight == true)) ...[
                  Row(children: [
                    Text('Add weight',
                        style: KiStyles.body(color: textPrimary)),
                    const Spacer(),
                    Switch(
                      value: _isWeightedExercise,
                      activeThumbColor: accentContainer,
                      onChanged: (v) =>
                          setState(() => _isWeightedExercise = v),
                    ),
                  ]),
                  const SizedBox(height: 12),
                ],

                // ── Timed exercise: seconds field + quick-add buttons ──
                if (_isTimed) ...[
                  TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    style: KiStyles.bodySemibold(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Seconds',
                      labelStyle: KiStyles.labelSm(color: AppColors.textTertiary(context)),
                      hintText: '0',
                      hintStyle: TextStyle(color: AppColors.textTertiary(context)),
                      filled: true,
                      fillColor: AppColors.inputFill(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide:
                          BorderSide(color: AppColors.border(context))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide:
                          BorderSide(color: AppColors.accentContainer(context), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [10, 20, 30, 60].map((s) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: s != 60 ? 8.0 : 0.0),
                          child: OutlinedButton(
                            onPressed: () {
                              final cur = int.tryParse(_repsController.text) ?? 0;
                              _repsController.text = '${cur + s}';
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderColor),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('+${s}s',
                                style: KiStyles.labelSm(color: textSecondary)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  // ── Weight + reps inputs ──
                  Row(children: [
                    if ((widget.workoutType != WorkoutTypes.bodyweight && _isBodyweight != true) || _isWeightedExercise) ...[
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: KiStyles.bodySemibold(color: AppColors.textPrimary(context)),
                          decoration: InputDecoration(
                            labelText: WeightFormat.inputLabel,
                            labelStyle: KiStyles.labelSm(color: AppColors.textTertiary(context)),
                            hintText: '0',
                            hintStyle: TextStyle(color: AppColors.textTertiary(context)),
                            filled: true,
                            fillColor: AppColors.inputFill(context),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide:
                                BorderSide(color: AppColors.border(context))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide:
                                BorderSide(color: AppColors.accentContainer(context), width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        style: KiStyles.bodySemibold(color: AppColors.textPrimary(context)),
                        decoration: InputDecoration(
                          labelText: 'Reps',
                          labelStyle: KiStyles.labelSm(color: AppColors.textTertiary(context)),
                          hintText: '0',
                          hintStyle: TextStyle(color: AppColors.textTertiary(context)),
                          filled: true,
                          fillColor: AppColors.inputFill(context),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide:
                              BorderSide(color: AppColors.border(context))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide:
                              BorderSide(color: AppColors.accentContainer(context), width: 1.5)),
                        ),
                      ),
                    ),
                  ]),
                ],

                const SizedBox(height: 20),

                // ── Log set button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentContainer,
                      foregroundColor: AppColors.primaryBtnFg(context),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Log Set',
                        style: KiStyles.bodySemibold(
                            color: AppColors.primaryBtnFg(context))),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Done bar ──
        if (_sets.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _done,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentContainer,
                    foregroundColor: AppColors.primaryBtnFg(context),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  child: Text(
                      'Done — ${_sets.length} set${_sets.length > 1 ? 's' : ''} logged'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Sticky Rest Bar (Minimized view) ──────────────────────────────────────────

class _StickyRestBar extends StatelessWidget {
  final ValueNotifier<int> tickNotifier;
  final int? target;
  final Color accentColor;
  final VoidCallback onStop;
  final VoidCallback onMaximize;

  const _StickyRestBar({
    required this.tickNotifier,
    required this.target,
    required this.accentColor,
    required this.onStop,
    required this.onMaximize,
  });

  String _fmt(int ticks) {
    final m = ticks ~/ 60;
    final s = (ticks % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final textTertiary = AppColors.textTertiary(context);
    final errorCol = AppColors.error(context);

    return ValueListenableBuilder<int>(
      valueListenable: tickNotifier,
      builder: (context, ticks, _) {
        final isOvertime = target != null && ticks >= target!;
        final color = isOvertime ? errorCol : accentColor;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            border: Border(
              bottom: BorderSide(color: AppColors.border(context), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onMaximize,
              child: Stack(
                children: [
                  // Progress background
                  if (target != null && !isOvertime)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        width: MediaQuery.of(context).size.width *
                            (ticks / target!).clamp(0.0, 1.0),
                        height: double.infinity,
                        color: accentColor.withValues(alpha: 0.12),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _PulseDot(color: color),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RESTING · ${_fmt(ticks)}',
                                style: KiStyles.bodySemibold(color: color),
                              ),
                              if (target != null)
                                Text(
                                  isOvertime ? 'OVERTIME' : 'GOAL ${_fmt(target!)}',
                                  style: KiStyles.labelSm(
                                      color: isOvertime ? errorCol : textTertiary),
                                ),
                            ],
                          ),
                        ),
                        // Stop button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onStop,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.error(context).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.error(context)
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.stop_rounded,
                                      size: 14, color: AppColors.error(context)),
                                  const SizedBox(width: 4),
                                  Text('STOP',
                                      style: KiStyles.labelSm(
                                          color: AppColors.error(context))),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.expand_less_rounded,
                            size: 20, color: textTertiary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.4 + (0.6 * _ctrl.value)),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: widget.color.withValues(alpha: 0.3 * _ctrl.value),
                blurRadius: 4,
                spreadRadius: 2),
          ],
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scale = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut, reverseCurve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

class _AddCustomExerciseSheet extends StatefulWidget {
  final String? Function(String) fuzzyMatch;
  const _AddCustomExerciseSheet({required this.fuzzyMatch});

  @override
  State<_AddCustomExerciseSheet> createState() => _AddCustomExerciseSheetState();
}

class _AddCustomExerciseSheetState extends State<_AddCustomExerciseSheet> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    // _nameCtrl is managed by the sheet lifecycle — do not dispose here
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() == true) {
      Navigator.pop(context, _nameCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('New exercise',
                style: KiStyles.headlineMd(color: AppColors.textPrimary(context))),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              style: KiStyles.bodySemibold(color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                hintText: 'Exercise name',
                hintStyle: KiStyles.body(color: AppColors.hintText(context)),
                filled: true,
                fillColor: AppColors.inputFill(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border(context), width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accentContainer(context), width: 2)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error(context), width: 1.5)),
                focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error(context), width: 2)),
              ),
              validator: (v) {
                final trimmed = v?.trim() ?? '';
                if (trimmed.isEmpty) return 'Enter an exercise name';
                final match = widget.fuzzyMatch(trimmed);
                if (match != null) return 'Already exists as "$match"';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentContainer(context),
                  foregroundColor: AppColors.primaryBtnFg(context),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text('Add',
                    style: KiStyles.bodySemibold(
                        color: AppColors.primaryBtnFg(context))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
