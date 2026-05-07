import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/add_exercise_screen.dart';
import 'package:gymlog/screens/workout_summary_screen.dart';
import 'package:gymlog/utils/exercise_data.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';

class LogWorkoutScreen extends StatefulWidget {
  final DateTime? initialDate;
  final String type;
  final List<Map<String, dynamic>>? initialExercises;
  const LogWorkoutScreen({
    super.key,
    this.initialDate,
    this.type = WorkoutTypes.weighted,
    this.initialExercises,
  });
  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final List<Map<String, dynamic>> _exercises = [];
  List<String> _allExercises = [];
  late DateTime _workoutDate;
  late Stopwatch _workoutStopwatch;
  Timer? _ticker;
  int _nextSupersetGroup = 1;

  // ── Rest timer ──
  final Stopwatch _restStopwatch = Stopwatch();
  bool _restActive = false;
  int? _restTarget;
  bool _restAlarmFired = false;

  @override
  void initState() {
    super.initState();
    _workoutDate = widget.initialDate ?? DateTime.now();
    DBHelper.getExercises().then((e) => setState(() => _allExercises = e));
    _workoutStopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_restActive && _restTarget != null && !_restAlarmFired &&
          _restStopwatch.elapsed.inSeconds >= _restTarget!) {
        _restAlarmFired = true;
        HapticFeedback.heavyImpact();
      }
      setState(() {});
    });
    if (widget.initialExercises != null) {
      _exercises.addAll(widget.initialExercises!);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _workoutStopwatch.stop();
    _restStopwatch.stop();
    super.dispose();
  }

  void _startRest() {
    _restStopwatch
      ..reset()
      ..start();
    if (mounted) setState(() { _restActive = true; _restAlarmFired = false; });
  }

  void _dismissRest() {
    _restStopwatch.stop();
    if (mounted) setState(() => _restActive = false);
  }

  void _showRestTargetPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final textPrimary = AppColors.textPrimary(ctx);
        final textTertiary = AppColors.textTertiary(ctx);
        final accent = _accentColor(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rest Target', style: KiStyles.headlineMd(color: textPrimary)),
                const SizedBox(height: 4),
                Text('Haptic alert when rest is done.', style: KiStyles.body(color: textTertiary)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in [('60s', 60), ('90s', 90), ('2 min', 120), ('3 min', 180), ('5 min', 300)])
                      _RestPresetChip(
                        label: entry.$1,
                        selected: _restTarget == entry.$2,
                        accent: accent,
                        textPrimary: textPrimary,
                        onTap: () {
                          setState(() { _restTarget = entry.$2; _restAlarmFired = false; });
                          Navigator.pop(ctx);
                        },
                      ),
                    _RestPresetChip(
                      label: 'Off',
                      selected: _restTarget == null,
                      accent: AppColors.error(ctx),
                      textPrimary: textPrimary,
                      onTap: () {
                        setState(() => _restTarget = null);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Remove $exName', style: KiStyles.bodySemibold(color: Colors.white)),
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

  String get _restDisplay {
    final e = _restStopwatch.elapsed;
    final m = e.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = e.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _elapsedDisplay {
    final e = _workoutStopwatch.elapsed;
    final h = e.inHours;
    final m = e.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = e.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
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
                      borderRadius: BorderRadius.circular(12)),
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
      setState(() => _exercises.add(result));
      if (!_allExercises.contains(result['name'])) {
        _allExercises.add(result['name']);
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

  Future<void> _addSetInline(int exIndex) async {
    final isBodyweight = widget.type == WorkoutTypes.bodyweight;
    final exName = _exercises[exIndex]['name'] as String;

    final prevSets = await DBHelper.getLastSets(exName);
    String prevHint = '';
    double seedWeight = 0.0;
    if (prevSets.isNotEmpty) {
      final lastWeight = (prevSets.last['weight'] as num).toDouble();
      final lastReps = prevSets.last['reps'] as int? ?? 0;
      if (!isBodyweight && lastWeight > 0) {
        seedWeight = lastWeight;
        prevHint = 'Last: ${lastWeight % 1 == 0 ? lastWeight.toInt() : lastWeight.toStringAsFixed(1)}kg × $lastReps reps';
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
    final rCtrl = TextEditingController();

    final result = await showModalBottomSheet<({double weight, int reps})>(
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
            labelStyle: TextStyle(color: textTertiary, fontSize: 13),
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
                Text('Add Set', style: KiStyles.headlineMd(color: textPrimary)),
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
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: accent)),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isBodyweight) ...[
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: wCtrl,
                              autofocus: true,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: KiStyles.bodySemibold(color: textPrimary),
                              decoration: fieldDeco('Weight (kg)'),
                              onChanged: (_) => sheetSetState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (final delta in [-5.0, -2.5, 2.5, 5.0])
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: OutlinedButton(
                                        onPressed: () => adjustWeight(delta),
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 32),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          side: BorderSide(color: AppColors.border(ctx)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        child: Text(
                                          delta > 0 ? '+${delta % 1 == 0 ? delta.toInt() : delta}' : '${delta % 1 == 0 ? delta.toInt() : delta}',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final reps = int.tryParse(rCtrl.text) ?? 0;
                      if (reps <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Enter at least 1 rep.')),
                        );
                        return;
                      }
                      final weight = isBodyweight
                          ? 0.0
                          : (double.tryParse(wCtrl.text.isEmpty ? '0' : wCtrl.text) ?? 0.0);
                      FocusScope.of(ctx).unfocus();
                      Navigator.pop(ctx, (weight: weight, reps: reps));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: AppColors.primaryBtnFg(ctx),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Add Set', style: KiStyles.bodySemibold(color: AppColors.primaryBtnFg(ctx))),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result != null && mounted) {
      final prevMax = prevSets.isEmpty
          ? 0.0
          : prevSets
              .map((s) => (s['weight'] as num).toDouble())
              .reduce((a, b) => a > b ? a : b);
      final isPR = !isBodyweight && prevSets.isNotEmpty && result.weight > prevMax;
      setState(() {
        (_exercises[exIndex]['sets'] as List)
            .add({'weight': result.weight, 'reps': result.reps, if (isPR) 'isPR': true});
      });
      _startRest();
    }
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
      final workoutId = await DBHelper.insertWorkout(
        dateStr,
        _workoutStopwatch.elapsed.inSeconds,
        type: widget.type,
      );
      for (final ex in _exercises) {
        final muscleGroup = ExerciseData.muscleGroupFor(ex['name'] as String);
        await DBHelper.insertExercise(ex['name'] as String, muscleGroup: muscleGroup);
        final sets = ex['sets'] as List;
        final supersetGroup = ex['supersetGroup'] as int?;
        int setNum = 1;
        for (int i = 0; i < sets.length; i++) {
          final reps = sets[i]['reps'] as int;
          if (reps <= 0) continue; // skip placeholder sets from empty templates
          await DBHelper.insertSet(
            workoutId,
            ex['name'] as String,
            setNum++,
            (sets[i]['weight'] as num).toDouble(),
            reps,
            supersetGroup: supersetGroup,
          );
        }
      }

      final prs = await DBHelper.getPersonalBestsInWorkout(workoutId);

      // ignore: use_build_context_synchronously
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryScreen(
            workoutId: workoutId,
            durationSeconds: _workoutStopwatch.elapsed.inSeconds,
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
                        // ignore: use_build_context_synchronously
                        Navigator.pop(context);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GYMLOG',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 3,
                        color: accentContainer,
                      ),
                    ),
                  ),
                  // Live indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5, height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.liveGreen,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text('LIVE', style: KiStyles.labelSm(color: textTertiary)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Timer + date + rest strip ──
            Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Workout clock
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TIME', style: KiStyles.labelSm(color: textTertiary)),
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
                  const SizedBox(width: 24),
                  Container(width: 1, height: 36, color: AppColors.border(context)),
                  const SizedBox(width: 24),
                  // Rest timer (replaces DATE when active)
                  if (_restActive)
                    Expanded(
                      child: GestureDetector(
                        onTap: _showRestTargetPicker,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: _restAlarmFired ? AppColors.error(context) : AppColors.liveGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'REST',
                                  style: KiStyles.labelSm(color: _restAlarmFired ? AppColors.error(context) : AppColors.liveGreen),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _dismissRest,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(Icons.close_rounded, size: 13, color: textTertiary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _restDisplay,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _restAlarmFired ? AppColors.error(context) : textPrimary,
                                letterSpacing: 1,
                              ),
                            ),
                            if (_restTarget != null) ...[
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (_restStopwatch.elapsed.inSeconds / _restTarget!).clamp(0.0, 1.0),
                                  minHeight: 3,
                                  backgroundColor: AppColors.border(context),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _restAlarmFired ? AppColors.error(context) : AppColors.liveGreen,
                                  ),
                                ),
                              ),
                            ] else
                              Text('tap to set target', style: KiStyles.labelSm(color: textTertiary)),
                          ],
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _pickDate,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DATE', style: KiStyles.labelSm(color: textTertiary)),
                          const SizedBox(height: 4),
                          Text(
                            '${_workoutDate.day}/${_workoutDate.month}/${_workoutDate.year}',
                            style: KiStyles.headlineMd(color: textPrimary),
                          ),
                          Text('TAP TO CHANGE', style: KiStyles.labelSm(color: textTertiary)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
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
              child: _exercises.isEmpty
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
                          return _SupersetConnector(
                            isLinked: isLinked,
                            accentColor: _accentColor(context),
                            onTap: () => _toggleSuperset(i, i + 1),
                          );
                        }
                        final exIndex = index ~/ 2;
                        final ex = _exercises[exIndex];
                        final sets = ex['sets'] as List;
                        final supersetGroup =
                            ex['supersetGroup'] as int?;
                        final isLinked = supersetGroup != null;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                            Padding(
                            padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onLongPress: () => _confirmDeleteExercise(exIndex),
                                  behavior: HitTestBehavior.opaque,
                                  child: Row(children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                          color: _accentColor(context),
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ex['name'] as String,
                                        style: KiStyles.bodySemibold(
                                            color: textPrimary),
                                      ),
                                    ),
                                    if (isLinked) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.link_rounded, size: 13, color: _accentColor(context)),
                                      const SizedBox(width: 3),
                                      Text('SUPERSET', style: KiStyles.labelSm(color: _accentColor(context))),
                                    ],
                                    Icon(Icons.more_horiz_rounded, size: 16, color: textTertiary.withValues(alpha: 0.4)),
                                  ]),
                                ),
                                const SizedBox(height: 10),
                                ...sets.asMap().entries.map((e) {
                                  final isBW =
                                      (e.value['weight'] as num)
                                              .toDouble() ==
                                          0;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 6),
                                    child: Row(children: [
                                      _SetBadge(
                                          number: e.key + 1,
                                          color: _accentColor(context)),
                                      const SizedBox(width: 10),
                                      Text(
                                        isBW
                                            ? 'BW'
                                            : '${e.value['weight']}kg',
                                        style: KiStyles.bodySemibold(
                                            color: textPrimary),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Text('×',
                                            style: KiStyles.label(
                                                color: textTertiary)),
                                      ),
                                      Text(
                                        '${e.value['reps']} reps',
                                        style: KiStyles.bodySemibold(
                                            color: textSecondary),
                                      ),
                                      if (e.value['isPR'] == true) ...[
                                        const SizedBox(width: 8),
                                        Text('PR', style: KiStyles.labelSm(color: accentContainer)),
                                      ],
                                      // Remove set button
                                      const Spacer(),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          final removed = Map<String, dynamic>.from(
                                              (ex['sets'] as List)[e.key] as Map);
                                          final exIdx = exIndex;
                                          final setIdx = e.key;
                                          setState(() {
                                            (ex['sets'] as List).removeAt(e.key);
                                          });
                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              SnackBar(
                                                content: const Text('Set removed'),
                                                duration: const Duration(seconds: 3),
                                                action: SnackBarAction(
                                                  label: 'Undo',
                                                  onPressed: () {
                                                    if (mounted && exIdx < _exercises.length) {
                                                      setState(() {
                                                        final sets = _exercises[exIdx]['sets'] as List;
                                                        final insertAt = setIdx.clamp(0, sets.length);
                                                        sets.insert(insertAt, removed);
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                            );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(Icons.close,
                                              size: 14,
                                              color: textTertiary),
                                        ),
                                      ),
                                    ]),
                                  );
                                }),
                                // + Add Set inline button
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _addSetInline(exIndex),
                                    icon: Icon(Icons.add_circle_outline,
                                        size: 15, color: _accentColor(context)),
                                    label: Text(
                                      sets.isEmpty ? 'ADD FIRST SET' : 'ADD SET',
                                      style: KiStyles.label(color: _accentColor(context)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(color: _accentColor(context).withValues(alpha: 0.3)),
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
                      }),
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
    return GestureDetector(
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
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isLinked ? accentColor : textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rest preset chip ──────────────────────────────────────────────────────────

class _RestPresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color textPrimary;
  final VoidCallback onTap;
  const _RestPresetChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.15)
              : AppColors.border(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? accent : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? accent : textPrimary,
          ),
        ),
      ),
    );
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
