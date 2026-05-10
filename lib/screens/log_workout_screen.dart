import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/add_exercise_screen.dart';
import 'package:gymlog/screens/workout_summary_screen.dart';
import 'package:gymlog/utils/exercise_data.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/utils/weight_format.dart';
import 'package:gymlog/widgets/gymlog_wordmark.dart';
import 'package:gymlog/widgets/tip_overlay.dart';

class LogWorkoutScreen extends StatefulWidget {
  final DateTime? initialDate;
  final String type;
  final List<Map<String, dynamic>>? initialExercises;
  final int draftElapsedSeconds;
  const LogWorkoutScreen({
    super.key,
    this.initialDate,
    this.type = WorkoutTypes.weighted,
    this.initialExercises,
    this.draftElapsedSeconds = 0,
  });
  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final List<Map<String, dynamic>> _exercises = [];
  List<String> _allExercises = [];
  late DateTime _workoutDate;
  late Stopwatch _workoutStopwatch;
  int _elapsedOffset = 0;
  Timer? _ticker;
  int _nextSupersetGroup = 1;

  // ── Workout tick notifier — updates only the timer strip, not the full screen ──
  final _tickNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _workoutDate = widget.initialDate ?? DateTime.now();
    _elapsedOffset = widget.draftElapsedSeconds;
    DBHelper.getExercises().then((e) => setState(() => _allExercises = e));
    _workoutStopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _tickNotifier.value++;
    });
    if (widget.initialExercises != null) {
      _exercises.addAll(widget.initialExercises!);
      _seedLastSets();
    }
    WeightFormat.load();
  }

  Future<void> _seedLastSets() async {
    for (final ex in _exercises) {
      final last = await DBHelper.getLastSets(ex['name'] as String);
      if (mounted && last.isNotEmpty) {
        setState(() => ex['lastSets'] = last);
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _workoutStopwatch.stop();
    _tickNotifier.dispose();
    super.dispose();
  }

  void _confirmDeleteExercise(int exIndex) {
    final exName = _exercises[exIndex]['name'] as String;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final textPrimary = AppColors.textPrimary(ctx);
        final textTertiary = AppColors.textTertiary(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remove Exercise?', style: KiStyles.headlineMd(color: textPrimary)),
                const SizedBox(height: 6),
                Text(exName, style: KiStyles.body(color: textTertiary)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final removed = {
                        ...Map<String, dynamic>.from(_exercises[exIndex]),
                        'sets': List.from(_exercises[exIndex]['sets'] as List),
                      };
                      final idx = exIndex;
                      setState(() => _exercises.removeAt(exIndex));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text('$exName removed'),
                          duration: const Duration(seconds: 4),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              if (mounted) {
                                setState(() {
                                  _exercises.insert(idx.clamp(0, _exercises.length), removed);
                                });
                              }
                            },
                          ),
                        ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error(ctx),
                      foregroundColor: AppColors.primaryBtnFg(ctx),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: Text('Remove', style: KiStyles.bodySemibold(color: AppColors.primaryBtnFg(ctx))),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text('Cancel', style: KiStyles.bodySemibold(color: textTertiary)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _elapsedDisplay {
    final totalSeconds = _workoutStopwatch.elapsed.inSeconds + _elapsedOffset;
    final h = totalSeconds ~/ 3600;
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _serializeExercises() => jsonEncode(_exercises.map((ex) => {
        'name': ex['name'],
        if (ex['supersetGroup'] != null) 'supersetGroup': ex['supersetGroup'],
        'sets': (ex['sets'] as List).map((s) => {
              'weight': (s['weight'] as num).toDouble(),
              'reps': s['reps'],
              if (s['isPR'] == true) 'isPR': true,
            }).toList(),
      }).toList());

  void _removeSet(int exIdx, int setIdx) {
    final removed = Map<String, dynamic>.from(
        (_exercises[exIdx]['sets'] as List)[setIdx] as Map);
    setState(() => (_exercises[exIdx]['sets'] as List).removeAt(setIdx));
    _saveDraft();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Set removed'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (mounted && exIdx < _exercises.length) {
              setState(() {
                final sets = _exercises[exIdx]['sets'] as List;
                sets.insert(setIdx.clamp(0, sets.length), removed);
              });
              _saveDraft();
            }
          },
        ),
      ));
  }

  void _saveDraft() {
    DBHelper.saveDraft(
      type: widget.type,
      exercisesJson: _serializeExercises(),
      elapsedSeconds: _workoutStopwatch.elapsed.inSeconds + _elapsedOffset,
      dateStr:
          '${_workoutDate.day}/${_workoutDate.month}/${_workoutDate.year}',
    );
  }

  Color _accentColor(BuildContext ctx) => WorkoutTypes.color(widget.type, ctx);

  Widget _buildDiscardSheet(BuildContext ctx) {
    final setCount = _exercises.fold<int>(
        0, (sum, ex) => sum + (ex['sets'] as List).length);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have an ongoing workout',
                style: KiStyles.headlineMd(color: AppColors.textPrimary(ctx))),
            const SizedBox(height: 6),
            Text(
              '$setCount set${setCount != 1 ? 's' : ''} logged will be lost.',
              style: KiStyles.body(color: AppColors.textTertiary(ctx)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentContainer(ctx),
                  foregroundColor: AppColors.background(ctx),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text('Resume',
                    style: KiStyles.bodySemibold(
                        color: AppColors.background(ctx))),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Discard',
                    style: KiStyles.bodySemibold(
                        color: AppColors.error(ctx))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _workoutDate,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) setState(() => _workoutDate = picked);
  }

  Future<void> _addExercise() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AddExerciseScreen(
                allExercises: _allExercises, workoutType: widget.type)));
    if (result != null) {
      final last = await DBHelper.getLastSets(result['name'] as String);
      if (mounted) {
        setState(() {
          if (last.isNotEmpty) result['lastSets'] = last;
          _exercises.add(result);
        });
        if (!_allExercises.contains(result['name'])) {
          _allExercises.add(result['name'] as String);
        }
        // Rest timer starts only after a set is logged, not on exercise add
      }
    }
  }

  void _toggleSuperset(int indexA, int indexB) {
    final groupA = _exercises[indexA]['supersetGroup'] as int?;
    final groupB = _exercises[indexB]['supersetGroup'] as int?;
    setState(() {
      if (groupA != null && groupA == groupB) {
        // Already linked — unlink both
        _exercises[indexA].remove('supersetGroup');
        _exercises[indexB].remove('supersetGroup');
      } else {
        // Link them in the same new group
        final newGroup = _nextSupersetGroup++;
        _exercises[indexA]['supersetGroup'] = newGroup;
        _exercises[indexB]['supersetGroup'] = newGroup;
      }
    });
  }

  String _fmtSecs(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _addSetInline(int exIndex, {double? prefillWeight, int? prefillReps}) async {
    final exName = _exercises[exIndex]['name'] as String;
    final isTimed = ExerciseData.isTimedExercise(exName);
    final isExBW = await DBHelper.isExerciseBodyweight(exName);
    final isBodyweight = isTimed || widget.type == WorkoutTypes.bodyweight || isExBW;

    final cachedSets = _exercises[exIndex]['lastSets'] as List?;
    final prevSets = (cachedSets != null && cachedSets.isNotEmpty)
        ? cachedSets
        : await DBHelper.getLastSets(exName);
    String prevHint = '';
    double seedWeight = prefillWeight ?? 0.0;
    int seedReps = prefillReps ?? 0;
    if (prefillWeight == null && prevSets.isNotEmpty) {
      final lastWeight = (prevSets.last['weight'] as num).toDouble();
      final lastReps = prevSets.last['reps'] as int? ?? 0;
      if (isTimed && lastReps > 0) {
        prevHint = 'Last: ${_fmtSecs(lastReps)}';
      } else if (!isBodyweight && lastWeight > 0) {
        seedWeight = lastWeight;
        prevHint = 'Last: ${WeightFormat.format(lastWeight)} × $lastReps reps';
      } else if (isBodyweight && lastReps > 0) {
        prevHint = 'Last session: $lastReps reps';
      }
    }

    if (!mounted) return;

    final wCtrl = TextEditingController(
        text: seedWeight > 0
            ? (seedWeight % 1 == 0
                ? seedWeight.toInt().toString()
                : seedWeight.toStringAsFixed(1))
            : '');
    final rCtrlInitial = seedReps > 0 ? seedReps.toString() : '';
    final rCtrl = TextEditingController(text: rCtrlInitial);

    bool showWeightField = !isBodyweight;
    bool timerPhase = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, sheetSetState) {
          final accent = _accentColor(ctx);
          final textPrimary = AppColors.textPrimary(ctx);
          final textTertiary = AppColors.textTertiary(ctx);
          final timerGreen = WorkoutTypes.color(WorkoutTypes.cardio, ctx);

          if (timerPhase) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
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
                  _RestTimerCard(
                    accentColor: timerGreen,
                    onDismiss: () => Navigator.pop(ctx),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: Text('Done', style: KiStyles.bodySemibold(color: AppColors.primaryBtnFg(ctx))),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          void adjustWeight(double delta) {
            final current = double.tryParse(wCtrl.text) ?? 0.0;
            final next = (current + delta).clamp(0.0, 9999.0);
            wCtrl.text = next % 1 == 0 ? next.toInt().toString() : next.toStringAsFixed(1);
            wCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: wCtrl.text.length));
            sheetSetState(() {});
          }

          InputDecoration fieldDeco(String label) => InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(color: textTertiary),
            labelText: label,
            labelStyle: KiStyles.labelSm(color: textTertiary),
            filled: true,
            fillColor: AppColors.inputFill(ctx),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border(ctx))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accent, width: 1.5)),
          );

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 20),
                Text('Log Set', style: KiStyles.headlineMd(color: textPrimary)),
                Text(exName, style: KiStyles.label(color: textTertiary)),
                const SizedBox(height: 16),
                if (prevHint.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.18)),
                    ),
                    child: Text(prevHint,
                        style: KiStyles.labelSm(color: accent)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (isTimed) ...[
                  // ── Timed exercise: duration in seconds ──
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: rCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        style: KiStyles.bodySemibold(color: textPrimary),
                        decoration: fieldDeco('Seconds'),
                        onChanged: (_) => sheetSetState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final step in [10, 20, 30, 60])
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: OutlinedButton(
                                  onPressed: () {
                                    final current = int.tryParse(rCtrl.text) ?? 0;
                                    final next = (current + step).clamp(0, 9999);
                                    rCtrl.text = next.toString();
                                    rCtrl.selection = TextSelection.fromPosition(
                                        TextPosition(offset: rCtrl.text.length));
                                    sheetSetState(() {});
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 44),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    side: BorderSide(color: AppColors.border(ctx)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: Text(
                                    '+${step}s',
                                    style: KiStyles.label(color: textPrimary),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showWeightField) ...[
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: wCtrl,
                                autofocus: !isBodyweight,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: KiStyles.bodySemibold(color: textPrimary),
                                decoration: fieldDeco(WeightFormat.inputLabel),
                                onChanged: (_) => sheetSetState(() {}),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (final delta in WeightFormat.increments)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: OutlinedButton(
                                          onPressed: () => adjustWeight(delta),
                                          style: OutlinedButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 44),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            side: BorderSide(color: AppColors.border(ctx)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          child: Text(
                                            WeightFormat.incrementLabel(delta),
                                            style: KiStyles.label(color: textPrimary),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: rCtrl,
                          autofocus: isBodyweight,
                          keyboardType: TextInputType.number,
                          style: KiStyles.bodySemibold(color: textPrimary),
                          decoration: fieldDeco('Reps'),
                          onChanged: (_) => sheetSetState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (isBodyweight) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => sheetSetState(() => showWeightField = !showWeightField),
                      child: Text(
                        showWeightField ? '− remove weight' : '+ add weight',
                        style: KiStyles.labelSm(color: textTertiary),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final reps = int.tryParse(rCtrl.text) ?? 0;
                      if (reps <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(isTimed ? 'Enter a duration.' : 'Enter at least 1 rep.')),
                        );
                        return;
                      }
                      final weight = showWeightField
                          ? (double.tryParse(wCtrl.text.isEmpty ? '0' : wCtrl.text) ?? 0.0)
                          : 0.0;
                      FocusScope.of(ctx).unfocus();
                      // Save set immediately into parent state
                      final prevMax = prevSets.isEmpty
                          ? 0.0
                          : prevSets
                              .map((s) => (s['weight'] as num).toDouble())
                              .reduce((a, b) => a > b ? a : b);
                      final isPR = !isBodyweight && prevSets.isNotEmpty && weight > prevMax;
                      setState(() {
                        (_exercises[exIndex]['sets'] as List)
                            .add({'weight': weight, 'reps': reps, if (isPR) 'isPR': true});
                      });
                      _saveDraft();
                      // Switch sheet to timer phase
                      sheetSetState(() => timerPhase = true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: AppColors.primaryBtnFg(ctx),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: Text('Log Set', style: KiStyles.bodySemibold(color: AppColors.primaryBtnFg(ctx))),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

  }

  Future<void> _saveWorkout() async {
    if (_exercises.isEmpty) return;
    try {
      final date = _workoutDate;
      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      final hour = isToday ? now.hour : 0;
      final minute = isToday ? now.minute : 0;
      final dateStr =
          '${date.day}/${date.month}/${date.year}  ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      final totalDuration = _workoutStopwatch.elapsed.inSeconds + _elapsedOffset;
      // Build flat set list for batch insert
      final allSets = <Map<String, dynamic>>[];
      for (final ex in _exercises) {
        final muscleGroup = ExerciseData.muscleGroupFor(ex['name'] as String);
        await DBHelper.insertExercise(ex['name'] as String, muscleGroup: muscleGroup);
        final sets = ex['sets'] as List;
        final supersetGroup = ex['supersetGroup'] as int?;
        int setNum = 1;
        for (final s in sets) {
          final reps = s['reps'] as int;
          if (reps <= 0) continue;
          allSets.add({
            'exerciseName': ex['name'],
            'setNumber': setNum++,
            'weight': (s['weight'] as num).toDouble(),
            'reps': reps,
            if (supersetGroup != null) 'supersetGroup': supersetGroup,
          });
        }
      }
      final workoutId = await DBHelper.saveWorkoutWithSets(
        dateStr,
        totalDuration,
        type: widget.type,
        sets: allSets,
      );

      final prs = await DBHelper.getPersonalBestsInWorkout(workoutId);
      await DBHelper.clearDraft();

      // ignore: use_build_context_synchronously
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryScreen(
            workoutId: workoutId,
            durationSeconds: totalDuration,
            type: widget.type,
            exercises: List<Map<String, dynamic>>.from(_exercises),
            prs: prs,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save workout. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isToday = () {
      final now = DateTime.now();
      final d = _workoutDate;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }();

    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);

    return PopScope(
      canPop: _exercises.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldDiscard = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: AppColors.cardBg(context),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (ctx) => _buildDiscardSheet(ctx),
        );
        if (shouldDiscard == true && mounted) {
          await DBHelper.clearDraft();
          // ignore: use_build_context_synchronously
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── KO Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary),
                    onPressed: () async {
                      if (_exercises.isEmpty) {
                        Navigator.pop(context);
                        return;
                      }
                      final shouldDiscard = await showModalBottomSheet<bool>(
                        context: context,
                        backgroundColor: AppColors.cardBg(context),
                        shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (ctx) => _buildDiscardSheet(ctx),
                      );
                      if (shouldDiscard == true && mounted) {
                        await DBHelper.clearDraft();
                        // ignore: use_build_context_synchronously
                        Navigator.pop(context);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: GymlogWordmark()),
                  // Live indicator (decorative — exclude from semantics)
                  ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.liveActivity(context),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text('LIVE', style: KiStyles.labelSm(color: textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Timer + date + rest strip ──
            Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
            ValueListenableBuilder<int>(
              valueListenable: _tickNotifier,
              builder: (context, _, __) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Workout clock
                  Semantics(
                    label: 'Elapsed time: $_elapsedDisplay',
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(child: Text('TIME', style: KiStyles.labelSm(color: textTertiary))),
                      const SizedBox(height: 4),
                      Text(_elapsedDisplay, style: KiStyles.headlineLg(color: accentContainer)),
                      Text(
                        isToday
                            ? WorkoutTypes.label(widget.type).toUpperCase()
                            : '${_workoutDate.day}/${_workoutDate.month}/${_workoutDate.year}',
                        style: KiStyles.labelSm(color: textTertiary),
                      ),
                    ],
                  ),
                  ), // closes Semantics(elapsed time)
                  const SizedBox(width: 24),
                  Container(width: 1, height: 36, color: AppColors.border(context)),
                  const SizedBox(width: 24),
                  Semantics(
                    label: 'Workout date: ${_workoutDate.day}/${_workoutDate.month}/${_workoutDate.year}. Tap to change.',
                    button: true,
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(child: Text('DATE', style: KiStyles.labelSm(color: textTertiary))),
                          const SizedBox(height: 4),
                          Text(
                            '${_workoutDate.day}/${_workoutDate.month}/${_workoutDate.year}',
                            style: KiStyles.headlineMd(color: textPrimary),
                          ),
                          ExcludeSemantics(child: Text('TAP TO CHANGE', style: KiStyles.labelSm(color: textTertiary))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ), // closes ValueListenableBuilder
            Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),

            // ── Exercise counter ──
            if (_exercises.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_exercises.length} EXERCISE${_exercises.length != 1 ? 'S' : ''}',
                    style: KiStyles.label(color: textTertiary),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // ── Exercise list ──
            Expanded(
              child: RepaintBoundary(child: _exercises.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(WorkoutTypes.icon(widget.type),
                              size: 44,
                              color: _accentColor(context).withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text('No exercises yet',
                              style: KiStyles.headlineMd(
                                  color: textPrimary)),
                          const SizedBox(height: 6),
                          Text('Tap Add Exercise to get started',
                              style: KiStyles.label(
                                  color: textTertiary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: _exercises.length * 2 - 1,
                      itemBuilder: (ctx, index) {
                        if (index.isOdd) {
                          final i = index ~/ 2;
                          final groupA =
                              _exercises[i]['supersetGroup'] as int?;
                          final groupB = _exercises[i + 1]
                              ['supersetGroup'] as int?;
                          final isLinked =
                              groupA != null && groupA == groupB;
                          final connector = _SupersetConnector(
                            isLinked: isLinked,
                            accentColor: _accentColor(context),
                            onTap: () => _toggleSuperset(i, i + 1),
                          );
                          // Show tip only on the first connector
                          if (i == 0) {
                            return TipOverlay(
                              tipKey: 'tip_superset',
                              tipTitle: 'Supersets',
                              tipBody: 'Tap to link two exercises as a superset. They\'ll be logged back-to-back with no rest between.',
                              direction: TipDirection.right,
                              child: connector,
                            );
                          }
                          return connector;
                        }
                        final exIndex = index ~/ 2;
                        final ex = _exercises[exIndex];
                        return _ExerciseCard(
                          key: ValueKey('ex_${ex['name']}_$exIndex'),
                          exercise: ex,
                          exIndex: exIndex,
                          accentColor: _accentColor(context),
                          onAddSet: _addSetInline,
                          onConfirmDelete: _confirmDeleteExercise,
                          onRemoveSet: _removeSet,
                          fmtSecs: _fmtSecs,
                        );
                      }),
              ),
            ),


            // ── Bottom action area ──
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    // Add Exercise button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addExercise,
                        icon: Icon(Icons.add_circle_outline,
                            size: 18, color: accentContainer),
                        label: Text('Add Exercise',
                            style: KiStyles.bodySemibold(
                                color: textPrimary)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border(context)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    if (_exercises.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      // Finish Workout primary button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveWorkout,
                          icon: const Icon(Icons.task_alt_rounded,
                              size: 20),
                          label: Text('Finish Workout',
                              style: KiStyles.bodySemibold(
                                  color: AppColors.primaryBtnFg(context))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentContainer,
                            foregroundColor: AppColors.primaryBtnFg(context),
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14)),
                            elevation: 0,
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
    ),
    );
  }
}

// ── Per-exercise card ─────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final int exIndex;
  final Color accentColor;
  final Future<void> Function(int, {double? prefillWeight, int? prefillReps}) onAddSet;
  final void Function(int) onConfirmDelete;
  final void Function(int, int) onRemoveSet;
  final String Function(int) fmtSecs;

  const _ExerciseCard({
    required super.key,
    required this.exercise,
    required this.exIndex,
    required this.accentColor,
    required this.onAddSet,
    required this.onConfirmDelete,
    required this.onRemoveSet,
    required this.fmtSecs,
  });

  @override
  Widget build(BuildContext context) {
    final sets = exercise['sets'] as List;
    final supersetGroup = exercise['supersetGroup'] as int?;
    final isLinked = supersetGroup != null;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final isTimed = ExerciseData.isTimedExercise(exercise['name'] as String);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(exercise['name'] as String,
                      style: KiStyles.bodySemibold(color: textPrimary)),
                ),
                if (isLinked) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.link_rounded, size: 13, color: accentColor),
                  const SizedBox(width: 3),
                  Text('SUPERSET', style: KiStyles.labelSm(color: accentColor)),
                ],
                const SizedBox(width: 6),
                Semantics(
                  label: 'Remove ${exercise['name']}',
                  button: true,
                  child: GestureDetector(
                    onTap: () => onConfirmDelete(exIndex),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 18, color: textTertiary.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              // ── Ghost rows (last session reference) ──
              Builder(builder: (context) {
                final lastSets = exercise['lastSets'] as List?;
                if (lastSets == null || lastSets.isEmpty || sets.isNotEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LAST SESSION', style: KiStyles.labelSm(color: textTertiary)),
                    const SizedBox(height: 6),
                    ...lastSets.asMap().entries.map((e) {
                      final w = (e.value['weight'] as num).toDouble();
                      final r = e.value['reps'] as int? ?? 0;
                      final isBW = w == 0;
                      final weightLabel = WeightFormat.format(w);
                      final repsLabel = isTimed ? fmtSecs(r) : '$r reps';
                      return Semantics(
                        label: isBW
                            ? 'Last session set ${e.key + 1}: bodyweight × $repsLabel. Tap to prefill'
                            : 'Last session set ${e.key + 1}: $weightLabel × $repsLabel. Tap to prefill',
                        button: true,
                        child: GestureDetector(
                          onTap: () => onAddSet(exIndex, prefillWeight: w, prefillReps: r),
                          child: Opacity(
                            opacity: 0.4,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(children: [
                                _SetBadge(number: e.key + 1, color: accentColor),
                                const SizedBox(width: 10),
                                Text(weightLabel,
                                    style: KiStyles.bodySemibold(color: textPrimary)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('×', style: KiStyles.label(color: textTertiary)),
                                ),
                                Text(repsLabel,
                                    style: KiStyles.bodySemibold(color: textSecondary)),
                                const Spacer(),
                                Text(
                                  isBW ? '+1 rep' : WeightFormat.overloadStep,
                                  style: KiStyles.labelSm(
                                      color: textTertiary.withValues(alpha: 0.6)),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.arrow_forward_ios_rounded,
                                    size: 10, color: textTertiary),
                              ]),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                    const SizedBox(height: 8),
                  ],
                );
              }),

              // ── Logged sets ──
              ...sets.asMap().entries.map((e) {
                final repsLabel = isTimed
                    ? fmtSecs(e.value['reps'] as int)
                    : '${e.value['reps']} reps';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    _SetBadge(number: e.key + 1, color: accentColor),
                    const SizedBox(width: 10),
                    Text(
                      WeightFormat.format((e.value['weight'] as num).toDouble()),
                      style: KiStyles.bodySemibold(color: textPrimary),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('×', style: KiStyles.label(color: textTertiary)),
                    ),
                    Text(repsLabel,
                        style: KiStyles.bodySemibold(color: textSecondary)),
                    if (e.value['isPR'] == true) ...[
                      const SizedBox(width: 8),
                      Text('PR', style: KiStyles.labelSm(color: accentColor)),
                    ],
                    const Spacer(),
                    Semantics(
                      label: 'Remove set ${e.key + 1}',
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onRemoveSet(exIndex, e.key),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.close, size: 14, color: textTertiary),
                        ),
                      ),
                    ),
                  ]),
                );
              }),

              // ── Add Set ──
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onAddSet(exIndex),
                  icon: Icon(Icons.add_circle_outline, size: 15, color: accentColor),
                  label: Text(
                    sets.isEmpty ? 'ADD FIRST SET' : 'ADD SET',
                    style: KiStyles.label(color: accentColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Superset connector between two exercise cards ─────────────────────────────

class _SupersetConnector extends StatelessWidget {
  final bool isLinked;
  final Color accentColor;
  final VoidCallback onTap;

  const _SupersetConnector({
    required this.isLinked,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);
    return Semantics(
      label: isLinked ? 'Superset: tap to unlink' : 'Tap to link as superset',
      button: true,
      child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
        child: Row(
          children: [
            // Vertical connector line
            SizedBox(
              width: 16,
              child: Center(
                child: Container(
                  width: 1,
                  height: 28,
                  color: isLinked
                      ? accentColor.withValues(alpha: 0.5)
                      : borderColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isLinked ? Icons.link_rounded : Icons.add_link_rounded,
              size: 13,
              color: isLinked ? accentColor : textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              isLinked ? 'SUPERSET — tap to unlink' : 'Link as superset',
              style: KiStyles.label(color: isLinked ? accentColor : textTertiary),
            ),
          ],
        ),
      ),
    ));
  }
}

// ── Set badge ─────────────────────────────────────────────────────────────────

class _SetBadge extends StatelessWidget {
  final int number;
  final Color color;
  const _SetBadge({required this.number, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      child: Text(
        '$number',
        style: KiStyles.label(color: color.withValues(alpha: 0.6)),
      ),
    );
  }
}

// ── Per-set rest timer card ────────────────────────────────────────────────────

class _RestTimerCard extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onDismiss;

  const _RestTimerCard({
    required this.accentColor,
    required this.onDismiss,
  });

  @override
  State<_RestTimerCard> createState() => _RestTimerCardState();
}

class _RestTimerCardState extends State<_RestTimerCard> {
  int _ticks = 0;
  Timer? _timer;
  int? _target;
  bool _editing = false;
  final _minCtrl = TextEditingController();
  final _secCtrl = TextEditingController();
  final _secFocus = FocusNode();
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _ticks++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _minCtrl.dispose();
    _secCtrl.dispose();
    _secFocus.dispose();
    super.dispose();
  }

  void _submitTarget() {
    final minTxt = _minCtrl.text.trim();
    final secTxt = _secCtrl.text.trim();
    final minVal = minTxt.isEmpty ? null : int.tryParse(minTxt);
    final secVal = secTxt.isEmpty ? null : int.tryParse(secTxt);

    if (minVal == null && secVal == null) {
      setState(() => _inputError = 'Enter a time');
      return;
    }
    final totalSec = (minVal ?? 0) * 60 + (secVal ?? 0);
    if (totalSec <= 0) {
      setState(() => _inputError = 'Enter a time');
      return;
    }
    setState(() { _editing = false; _inputError = null; _target = totalSec; });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  String _fmt(int ticks) {
    final m = ticks ~/ 60;
    final s = (ticks % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final textTertiary = AppColors.textTertiary(context);
    final borderCol = AppColors.border(context);
    final errorCol = AppColors.error(context);
    final target = _target;
    final isOvertime = target != null && _ticks >= target;
    final timerColor = isOvertime ? errorCol : widget.accentColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOvertime ? errorCol.withValues(alpha: 0.5) : borderCol,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: dot + REST label + timer + edit + X ──
            Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: timerColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                ExcludeSemantics(
                  child: Text('REST', style: KiStyles.labelSm(color: textTertiary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: 'Rest time: ${_fmt(_ticks)}',
                    child: Text(
                      _fmt(_ticks),
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: timerColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                // Edit / confirm icon
                Semantics(
                  label: _editing ? 'Confirm target time' : 'Set target time',
                  button: true,
                  child: GestureDetector(
                    onTap: _editing
                        ? _submitTarget
                        : () => setState(() {
                              _editing = true;
                              _inputError = null;
                              _minCtrl.clear();
                              _secCtrl.clear();
                            }),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Icon(
                        _editing ? Icons.check_rounded : Icons.edit_rounded,
                        size: 16, color: textTertiary,
                      ),
                    ),
                  ),
                ),
                // Dismiss icon
                Semantics(
                  label: 'Dismiss rest timer',
                  button: true,
                  child: GestureDetector(
                    onTap: widget.onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Icon(Icons.close_rounded, size: 16, color: textTertiary),
                    ),
                  ),
                ),
              ],
            ),

            // ── Edit mode: min:sec input ──
            if (_editing) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _TimeField(
                    controller: _minCtrl,
                    hint: 'min',
                    accentColor: widget.accentColor,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => FocusScope.of(context).requestFocus(_secFocus),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':', style: KiStyles.headlineMd(color: textTertiary)),
                  ),
                  _TimeField(
                    controller: _secCtrl,
                    hint: 'sec',
                    focusNode: _secFocus,
                    accentColor: widget.accentColor,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitTarget(),
                  ),
                  if (_inputError != null) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(_inputError!, style: KiStyles.labelSm(color: errorCol)),
                    ),
                  ],
                ],
              ),

            // ── Progress bar (target set, not editing) ──
            ] else if (target != null) ...[
              const SizedBox(height: 8),
              LayoutBuilder(builder: (_, constraints) {
                final progress = (_ticks / target).clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Container(
                      height: 3,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: timerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      height: 3,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        color: timerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'TARGET ${_fmt(target)}',
                    style: KiStyles.labelSm(color: isOvertime ? errorCol : textTertiary),
                  ),
                  if (isOvertime) ...[
                    const SizedBox(width: 6),
                    Text(
                      '+${_fmt(_ticks - target)}',
                      style: KiStyles.labelSm(color: errorCol),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Small time input field helper
class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final Color accentColor;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _TimeField({
    required this.controller,
    required this.hint,
    required this.accentColor,
    required this.textInputAction,
    this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textInputAction: textInputAction,
        style: KiStyles.bodySemibold(color: AppColors.textPrimary(context)),
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: KiStyles.body(color: AppColors.hintText(context)),
          filled: true,
          fillColor: AppColors.inputFill(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: AppColors.border(context))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: accentColor, width: 2)),
        ),
      ),
    );
  }
}
