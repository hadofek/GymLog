import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';

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
  bool? _isBodyweight;
  bool _isWeightedExercise = false;
  double _exercisePR = 0;

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
    if (widget.workoutType == WorkoutTypes.bodyweight && !_isWeightedExercise) {
      final r = int.tryParse(_repsController.text);
      if (r == null || r <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter valid reps')),
          );
        }
        return;
      }
      setState(() {
        _sets.add({'weight': 0.0, 'reps': r, 'bodyweight': true});
        _repsController.clear();
      });
      return;
    }

    final w = double.tryParse(_weightController.text);
    final r = int.tryParse(_repsController.text);
    if (w == null || r == null || w < 0 || r <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid weight and reps')),
        );
      }
      return;
    }
    if (w == 0) {
      if (_isBodyweight == true) {
        setState(() {
          _sets.add({'weight': w, 'reps': r});
          _weightController.clear();
          _repsController.clear();
        });
        return;
      }
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
          return;
        }
      }
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBg(ctx),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Bodyweight exercise?',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(ctx))),
          content: Text('You entered 0 kg. Is this a bodyweight exercise?',
              style: TextStyle(color: AppColors.textSecondary(ctx))),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a valid weight amount')),
                  );
                }
              },
              child: Text('No',
                  style: TextStyle(color: AppColors.textSecondary(ctx))),
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
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF111111).withValues(alpha: 0.06),
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
            Icon(Icons.emoji_events_rounded,
                color: Color(0xFFFFD700), size: 20),
            SizedBox(width: 8),
            Text('New Personal Record!',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
          backgroundColor: const Color(0xFF111111),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
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
    Navigator.pop(context, {'name': name, 'sets': _sets});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final card = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final border = AppColors.border(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          'Add Exercise',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Exercise name field ──
                  Text(
                    'Exercise name',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    onChanged: _onNameChanged,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Bench Press',
                      hintStyle: TextStyle(color: AppColors.hintText(context)),
                      filled: true,
                      fillColor: AppColors.inputFill(context),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: textPrimary, width: 2),
                      ),
                    ),
                  ),

                  // ── Autocomplete suggestions ──
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: border, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children:
                            _suggestions.asMap().entries.map((entry) {
                          final isLast =
                              entry.key == _suggestions.length - 1;
                          return Column(
                            children: [
                              ListTile(
                                dense: true,
                                leading: Icon(
                                    Icons.fitness_center_outlined,
                                    size: 18,
                                    color: textSecondary),
                                title: Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: textPrimary,
                                  ),
                                ),
                                onTap: () =>
                                    _selectExercise(entry.value),
                              ),
                              if (!isLast)
                                Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                    color: AppColors.divider(context)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                  // ── Last time reference ──
                  if (_lastSets.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Builder(builder: (context) {
                      final isDark = AppColors.isDark(context);
                      final refBg = isDark
                          ? AppColors.gold.withValues(alpha: 0.08)
                          : const Color(0xFFFFF8DC);
                      final refText = isDark
                          ? AppColors.gold
                          : const Color(0xFF8B7500);
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: refBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                              width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.history, size: 14, color: refText),
                                const SizedBox(width: 6),
                                Text(
                                  'LAST SESSION',
                                  style: KiStyles.labelSm(color: refText),
                                ),
                                if (_exercisePR > 0) ...[
                                  const Spacer(),
                                  Icon(Icons.emoji_events_rounded,
                                      size: 12, color: refText),
                                  const SizedBox(width: 3),
                                  Text(
                                    'PR: ${_exercisePR % 1 == 0 ? _exercisePR.toInt() : _exercisePR}kg',
                                    style: KiStyles.labelSm(color: refText),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._lastSets.map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    'Set ${s['set_number']}:  ${s['weight']}kg × ${s['reps']} reps',
                                    style: TextStyle(
                                      color: refText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 24),

                  // ── Logged sets list ──
                  if (_sets.isNotEmpty) ...[
                    Row(
                      children: [
                        Text(
                          'Sets logged',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentContainer(context)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_sets.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentContainer(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border, width: 1.5),
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
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                  if (e.value['isPR'] == true) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFD700),
                                        borderRadius:
                                            BorderRadius.circular(6),
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
                                Divider(
                                    height: 1,
                                    indent: 14,
                                    endIndent: 14,
                                    color: AppColors.divider(context)),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (widget.workoutType == WorkoutTypes.bodyweight) ...[
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border, width: 1.5),
                      ),
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        title: Text(
                          'Add weight',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'e.g. weighted vest or dip belt',
                          style: TextStyle(
                              fontSize: 12, color: textSecondary),
                        ),
                        value: _isWeightedExercise,
                        activeThumbColor: const Color(0xFF2196F3),
                        activeTrackColor:
                            const Color(0xFF2196F3).withValues(alpha: 0.4),
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
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Weight (kg)',
                            labelStyle:
                                TextStyle(color: textSecondary),
                            filled: true,
                            fillColor: AppColors.inputFill(context),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: border, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: textPrimary, width: 2),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Reps',
                          labelStyle: TextStyle(color: textSecondary),
                          filled: true,
                          fillColor: AppColors.inputFill(context),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: border, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: textPrimary, width: 2),
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
                        backgroundColor: AppColors.accentContainer(context),
                        foregroundColor: const Color(0xFF002469),
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
                decoration: BoxDecoration(
                  color: AppColors.bottomBarBg(context),
                  border: Border(
                    top: BorderSide(color: border, width: 1),
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _done,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBtnBg(context),
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
