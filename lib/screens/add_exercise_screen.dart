import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/exercise_data.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/utils/weight_format.dart';

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

  // ── Log sets phase ──
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final List<Map<String, dynamic>> _sets = [];
  List<Map<String, dynamic>> _lastSets = [];
  bool? _isBodyweight;
  bool _isWeightedExercise = false;
  double _exercisePR = 0;

  // ── Rest timer ──
  final Stopwatch _restStopwatch = Stopwatch();
  Timer? _restTicker;
  bool _restActive = false;

  Map<String, List<String>> get _currentLibrary =>
      widget.workoutType == WorkoutTypes.bodyweight
          ? ExerciseData.bodyweight
          : ExerciseData.weighted;

  List<String> get _allLibraryNames =>
      _currentLibrary.values.expand((e) => e).toList();

  List<String> get _customExercises => widget.allExercises
      .where((e) => !_allLibraryNames
          .any((l) => l.toLowerCase() == e.toLowerCase()))
      .toList();

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
      _isBodyweight = isBw ? true : null;
      _exercisePR = pr;
      _isWeightedExercise = false;
      _sets.clear();
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
      _startRest();
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
        _startRest();
        return;
      }
      final name = _selectedExercise ?? '';
      if (name.isNotEmpty) {
        final isBw = await DBHelper.isExerciseBodyweight(name);
        if (isBw) {
          setState(() {
            _isBodyweight = true;
            _sets.add({'weight': w, 'reps': r});
            _weightController.clear();
            _repsController.clear();
          });
          _startRest();
          return;
        }
      }
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBg(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Bodyweight exercise?',
              style: KiStyles.headlineMd(color: AppColors.textPrimary(ctx))),
          content: Text('You entered 0 kg. Is this a bodyweight exercise?',
              style: KiStyles.body(color: AppColors.textSecondary(ctx))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('No', style: KiStyles.label(color: AppColors.textSecondary(ctx))),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final exerciseName = _selectedExercise ?? '';
                setState(() {
                  _isBodyweight = true;
                  _sets.add({'weight': w, 'reps': r});
                  _weightController.clear();
                  _repsController.clear();
                });
                _startRest();
                if (exerciseName.isNotEmpty) {
                  await DBHelper.setExerciseBodyweight(exerciseName, true);
                }
              },
              child: Text('Yes, bodyweight',
                  style: KiStyles.label(color: AppColors.accentContainer(ctx))),
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
    _startRest();
    if (isPR && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 20),
            SizedBox(width: 8),
            Text('New Personal Record!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
          backgroundColor: AppColors.cardBg(context),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
  }

  void _done() {
    if (_selectedExercise == null || _sets.isEmpty) return;
    Navigator.pop(context, {'name': _selectedExercise!, 'sets': _sets});
  }

  void _startRest() {
    _restStopwatch..reset()..start();
    _restTicker?.cancel();
    _restTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (mounted) setState(() => _restActive = true);
  }

  void _dismissRest() {
    _restTicker?.cancel();
    _restStopwatch.stop();
    if (mounted) setState(() => _restActive = false);
  }

  String get _restDisplay {
    final e = _restStopwatch.elapsed;
    final m = e.inMinutes.remainder(60).toString();
    final s = e.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _restTicker?.cancel();
    _restStopwatch.stop();
    _searchController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textSecondary),
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
        ),
        title: Text(
          _selectedExercise ?? 'Add Exercise',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        actions: [
          if (_selectedExercise != null && _sets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: _done,
                child: Text('Done', style: KiStyles.bodySemibold(color: textPrimary)),
              ),
            ),
        ],
      ),
      body: _selectedExercise == null
          ? _buildBrowse(context)
          : _buildLogSets(context),
    );
  }

  // ── Phase 1: Browse ────────────────────────────────────────────────────────

  List<String> get _searchResults {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return [];
    final all = [..._allLibraryNames, ..._customExercises];
    final seen = <String>{};
    return all
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
                    child: Icon(Icons.close_rounded, size: 16, color: textTertiary),
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
                        if (custom.isNotEmpty) ...[
                          _categoryHeader('MY EXERCISES', context),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOutCubic,
                            child: _expandedCategory == 'MY EXERCISES'
                                ? Column(children: custom.map((n) => _exerciseRow(n, context)).toList())
                                : const SizedBox.shrink(),
                          ),
                        ],
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
                                e.value['bodyweight'] == true
                                    ? 'BW  ×  ${e.value['reps']} reps'
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
                                child: Icon(Icons.close,
                                    size: 16, color: textTertiary),
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

                // ── Bodyweight toggle ──
                if (widget.workoutType == WorkoutTypes.bodyweight) ...[
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

                // ── Weight + reps inputs ──
                Row(children: [
                  if (widget.workoutType != WorkoutTypes.bodyweight ||
                      _isWeightedExercise) ...[
                    Expanded(
                      child: _flatField(
                        controller: _weightController,
                        label: WeightFormat.inputLabel,
                        keyboard: const TextInputType.numberWithOptions(
                            decimal: true),
                        textPrimary: textPrimary,
                        textTertiary: textTertiary,
                        borderColor: borderColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: _flatField(
                      controller: _repsController,
                      label: 'Reps',
                      keyboard: TextInputType.number,
                      textPrimary: textPrimary,
                      textTertiary: textTertiary,
                      borderColor: borderColor,
                    ),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Log set button ──
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _saveSet,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Log Set',
                        style: KiStyles.bodySemibold(color: textPrimary)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Rest timer ──
        if (_restActive) ...[
          Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
          Container(
            color: AppColors.liveGreen.withValues(alpha: 0.05),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.liveGreen, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('REST', style: KiStyles.labelSm(color: AppColors.liveGreen)),
                const SizedBox(width: 12),
                Text(
                  _restDisplay,
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.liveGreen,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _dismissRest,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textTertiary(context)),
                  ),
                ),
              ],
            ),
          ),
        ],

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

  Widget _flatField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboard,
    required Color textPrimary,
    required Color textTertiary,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KiStyles.labelSm(color: textTertiary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: KiStyles.headlineMd(color: textPrimary),
          decoration: InputDecoration(
            border: UnderlineInputBorder(
                borderSide: BorderSide(color: borderColor, width: 1)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: borderColor, width: 1)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: textPrimary, width: 1.5)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ],
    );
  }
}

// ── Spring-press widget (iOS-like) ────────────────────────────────────────────
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
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut, reverseCurve: Curves.elasticOut),
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
