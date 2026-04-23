import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/widgets/wheel_column.dart';

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
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final List<Map<String, dynamic>> _sets = [];
  List<String> _suggestions = [];
  List<Map<String, dynamic>> _lastSets = [];
  // null = unknown, true = bodyweight, false = weighted
  bool? _isBodyweight;

  // For bodyweight workouts: whether this specific exercise uses added weight
  bool _isWeightedExercise = false;

  // Personal record: max weight ever logged for the current exercise
  double _exercisePR = 0;

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
      _isBodyweight = null;
      _lastSets = [];
      _isWeightedExercise = false;
      _exercisePR = 0;
    });
  }

  Future<void> _selectExercise(String name) async {
    _nameController.text = name;
    final last = await DBHelper.getLastSets(name);
    final isBw = await DBHelper.isExerciseBodyweight(name);
    final pr = await DBHelper.getMaxWeightForExercise(name);
    setState(() {
      _suggestions = [];
      _lastSets = last;
      _isBodyweight = isBw ? true : null;
      _exercisePR = pr;
      _isWeightedExercise = false;
    });
  }

  Future<void> _saveSet() async {
    // Bodyweight workout + no added weight: use weight=0, skip weight field
    if (widget.workoutType == WorkoutTypes.bodyweight && !_isWeightedExercise) {
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
      _showRestPicker();
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
      // If already confirmed bodyweight (this session or from DB), skip dialog
      if (_isBodyweight == true) {
        setState(() {
          _sets.add({'weight': w, 'reps': r});
          _weightController.clear();
          _repsController.clear();
        });
        _showRestPicker();
        return;
      }
      // Check DB in case user typed the name without selecting from suggestions
      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        final isBw = await DBHelper.isExerciseBodyweight(name);
        if (isBw) {
          setState(() {
            _isBodyweight = true;
            _sets.add({'weight': w, 'reps': r});
            _weightController.clear();
            _repsController.clear();
          });
          _showRestPicker();
          return;
        }
      }
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Bodyweight exercise?',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text(
              'You entered 0 kg. Is this a bodyweight exercise?',
              style: TextStyle(color: Color(0xFF666666))),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid weight amount')),
                );
              },
              child: const Text('No',
                  style: TextStyle(color: Color(0xFF888888))),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final exerciseName = _nameController.text.trim();
                setState(() {
                  _isBodyweight = true;
                  _sets.add({'weight': w, 'reps': r});
                  _weightController.clear();
                  _repsController.clear();
                });
                if (exerciseName.isNotEmpty) {
                  await DBHelper.setExerciseBodyweight(exerciseName, true);
                }
                _showRestPicker();
              },
              style: TextButton.styleFrom(
                backgroundColor:
                    const Color(0xFF111111).withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Yes, bodyweight',
                  style: TextStyle(
                      color: Color(0xFF111111), fontWeight: FontWeight.bold)),
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
    if (isPR && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 20),
            SizedBox(width: 8),
            Text('New Personal Record!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
          backgroundColor: const Color(0xFF111111),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Rest Timer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'How long do you want to rest?',
              style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WheelColumn(
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
                          color: Color(0xFFCCCCCC))),
                ),
                WheelColumn(
                  initialValue: pickedSeconds,
                  count: 60,
                  label: 'sec',
                  onChanged: (v) => pickedSeconds = v,
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                textStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              child: const Text('Start Rest Timer'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Skip',
                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
              ),
            ),
          ],
        ),
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
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_restSeconds <= 0) {
        t.cancel();
        setState(() => _restTimerRunning = false);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _restTimerVisible = false);
        });
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
            content:
                Text('Please enter an exercise name and at least one set')),
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Add Exercise',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF111111),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Rest timer banner ──
          if (_restTimerVisible)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: _restTimerRunning
                  ? const Color(0xFF111111)
                  : const Color(0xFF2A7A2A),
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _restTimerRunning
                          ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _restTimerRunning ? '$_restSeconds' : 'GO',
                        style: TextStyle(
                          color: _restTimerRunning
                              ? const Color(0xFFFFD700)
                              : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: _restTimerRunning ? 14 : 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _restTimerRunning
                              ? 'Resting — ${_restSeconds}s left'
                              : 'Rest complete — go!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: restProgress.toDouble(),
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation(
                              _restTimerRunning
                                  ? const Color(0xFFFFD700)
                                  : Colors.white,
                            ),
                            minHeight: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelRest,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Cancel',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Exercise name field ──
                  const Text(
                    'Exercise name',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF666666),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    onChanged: _onNameChanged,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111111)),
                    decoration: InputDecoration(
                      hintText: 'e.g. Bench Press',
                      hintStyle:
                          const TextStyle(color: Color(0xFFCCCCCC)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFEEEEEE), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF111111), width: 2),
                      ),
                    ),
                  ),

                  // ── Autocomplete suggestions ──
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFEEEEEE), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: _suggestions.asMap().entries.map((entry) {
                          final isLast =
                              entry.key == _suggestions.length - 1;
                          return Column(
                            children: [
                              ListTile(
                                dense: true,
                                leading: const Icon(
                                    Icons.fitness_center_outlined,
                                    size: 18,
                                    color: Color(0xFF999999)),
                                title: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF111111),
                                  ),
                                ),
                                onTap: () => _selectExercise(entry.value),
                              ),
                              if (!isLast)
                                const Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                    color: Color(0xFFF0F0F0)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                  // ── Last time reference ──
                  if (_lastSets.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8DC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history,
                                  size: 14, color: Color(0xFF8B7500)),
                              const SizedBox(width: 6),
                              const Text(
                                'Last session',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Color(0xFF8B7500),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              if (_exercisePR > 0) ...[
                                const Spacer(),
                                const Icon(Icons.emoji_events_rounded,
                                    size: 12, color: Color(0xFF8B7500)),
                                const SizedBox(width: 3),
                                Text(
                                  'PR: ${_exercisePR % 1 == 0 ? _exercisePR.toInt() : _exercisePR}kg',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8B7500),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._lastSets.map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  'Set ${s['set_number']}:  ${s['weight']}kg × ${s['reps']} reps',
                                  style: const TextStyle(
                                    color: Color(0xFF6B5800),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Logged sets list ──
                  if (_sets.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text(
                          'Sets logged',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF666666),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_sets.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8B7500),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFEEEEEE), width: 1.5),
                      ),
                      child: Column(
                        children: _sets.asMap().entries.map((e) {
                          final isLast = e.key == _sets.length - 1;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(children: [
                                  _SetBadge(number: e.key + 1),
                                  const SizedBox(width: 10),
                                  Text(
                                    e.value['bodyweight'] == true
                                        ? 'BW  ×  ${e.value['reps']} reps'
                                        : '${e.value['weight']}kg  ×  ${e.value['reps']} reps',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                  if (e.value['isPR'] == true) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFD700),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('PR',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF111111))),
                                    ),
                                  ],
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _sets.removeAt(e.key)),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE53935)
                                            .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 15,
                                        color: Color(0xFFE53935),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                              if (!isLast)
                                const Divider(
                                    height: 1,
                                    indent: 14,
                                    endIndent: 14,
                                    color: Color(0xFFF5F5F5)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── New set input ──
                  Text(
                    _sets.isEmpty ? 'First set' : 'Set ${_sets.length + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF666666),
                      letterSpacing: 0.3,
                    ),
                  ),
                  // "Add weight" switch — only shown for bodyweight workouts
                  if (widget.workoutType == WorkoutTypes.bodyweight) ...[
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFEEEEEE), width: 1.5),
                      ),
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        title: const Text(
                          'Add weight',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111111),
                          ),
                        ),
                        subtitle: const Text(
                          'e.g. weighted vest or dip belt',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF999999)),
                        ),
                        value: _isWeightedExercise,
                        activeThumbColor: const Color(0xFF2196F3),
                        activeTrackColor: const Color(0xFF2196F3).withValues(alpha: 0.4),
                        onChanged: (v) =>
                            setState(() => _isWeightedExercise = v),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    if (widget.workoutType != WorkoutTypes.bodyweight ||
                        _isWeightedExercise) ...[
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111111),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Weight (kg)',
                            labelStyle:
                                const TextStyle(color: Color(0xFF999999)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFFEEEEEE), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF111111), width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111111),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Reps',
                          labelStyle:
                              const TextStyle(color: Color(0xFF999999)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFEEEEEE), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF111111), width: 2),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveSet,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        'Log Set',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: const Color(0xFF111111),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Done button ──
          if (_sets.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                ),
              ),
              child: ElevatedButton(
                onPressed: _done,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: Colors.white,
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
        ],
      ),
    );
  }
}

class _SetBadge extends StatelessWidget {
  final int number;
  const _SetBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8B7500),
          ),
        ),
      ),
    );
  }
}
