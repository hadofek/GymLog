import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/add_exercise_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _workoutDate = widget.initialDate ?? DateTime.now();
    DBHelper.getExercises().then((e) => setState(() => _allExercises = e));
    _workoutStopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (widget.initialExercises != null) {
      _exercises.addAll(widget.initialExercises!);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _workoutStopwatch.stop();
    super.dispose();
  }

  String get _elapsedDisplay {
    final e = _workoutStopwatch.elapsed;
    final h = e.inHours;
    final m = e.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = e.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Color _accentColor(BuildContext ctx) => WorkoutTypes.color(widget.type, ctx);

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
    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);
    final isBodyweight = widget.type == WorkoutTypes.bodyweight;

    final wCtrl = TextEditingController();
    final rCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Set — ${_exercises[exIndex]['name']}',
          style: KiStyles.headlineMd(color: textPrimary),
        ),
        content: Row(children: [
          if (!isBodyweight) ...[
            Expanded(
              child: TextField(
                controller: wCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: KiStyles.body(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  hintText: '0 = BW',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: rCtrl,
              autofocus: isBodyweight,
              keyboardType: TextInputType.number,
              style: KiStyles.body(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Reps',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: KiStyles.label(color: textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: accentContainer.withValues(alpha: 0.12),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Add Set',
                style: KiStyles.label(color: accentContainer)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final w = isBodyweight
          ? 0.0
          : (double.tryParse(wCtrl.text.isEmpty ? '0' : wCtrl.text) ?? 0.0);
      final r = int.tryParse(rCtrl.text) ?? 0;
      if (r > 0) {
        final exName = _exercises[exIndex]['name'] as String;
        final prevSets = await DBHelper.getLastSets(exName);
        final prevMax = prevSets.isEmpty
            ? 0.0
            : prevSets
                .map((s) => (s['weight'] as num).toDouble())
                .reduce((a, b) => a > b ? a : b);
        final isPR = !isBodyweight && prevSets.isNotEmpty && w > prevMax;
        if (mounted) {
          setState(() {
            (_exercises[exIndex]['sets'] as List)
                .add({'weight': w, 'reps': r, if (isPR) 'isPR': true});
          });
        }
      }
    }
  }

  Future<String?> _showProgressPhotoDialog() async {
    if (!mounted) return null;
    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);

    return await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                child: Text('Add a progress photo?',
                    style: KiStyles.headlineMd(color: textPrimary)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Document your progress with a photo',
                    style: KiStyles.label(color: textTertiary)),
              ),
              const SizedBox(height: 20),
              ListTile(
                onTap: () => Navigator.pop(ctx, 'camera'),
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentContainer(ctx)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt_outlined,
                      color: AppColors.accentContainer(ctx), size: 22),
                ),
                title: Text('Take Photo',
                    style: KiStyles.bodySemibold(color: textPrimary)),
                subtitle: Text('Open camera',
                    style: KiStyles.labelSm(color: textTertiary)),
              ),
              ListTile(
                onTap: () => Navigator.pop(ctx, 'gallery'),
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentContainer(ctx)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library_outlined,
                      color: AppColors.accentContainer(ctx), size: 22),
                ),
                title: Text('Choose from Gallery',
                    style: KiStyles.bodySemibold(color: textPrimary)),
                subtitle: Text('Pick an existing photo',
                    style: KiStyles.labelSm(color: textTertiary)),
              ),
              ListTile(
                onTap: () => Navigator.pop(ctx, null),
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.close, color: textTertiary, size: 22),
                ),
                title: Text('Skip',
                    style: KiStyles.bodySemibold(color: textTertiary)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _pickAndCopyPhoto(String source) async {
    final picker = ImagePicker();
    final XFile? picked = source == 'camera'
        ? await picker.pickImage(source: ImageSource.camera, imageQuality: 85)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;

    // Copy to app documents dir for permanence
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/progress_photos');
    if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
    final fileName =
        'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = '${photosDir.path}/$fileName';
    await File(picked.path).copy(dest);
    return dest;
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
        await DBHelper.insertExercise(ex['name'] as String);
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

      // Progress photo
      if (!mounted) return;
      final source = await _showProgressPhotoDialog();
      if (source != null && mounted) {
        final path = await _pickAndCopyPhoto(source);
        if (path != null) {
          await DBHelper.updateWorkoutPhoto(workoutId, path);
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save workout: $e')));
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

    return Scaffold(
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
                    onPressed: () => Navigator.pop(context),
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
                          color: Color(0xFF4AE176),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text('LIVE', style: KiStyles.labelSm(color: textTertiary)),
                    ],
                  ),
                  if (_exercises.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _saveWorkout,
                      child: Text('Save', style: KiStyles.bodySemibold(color: accentContainer)),
                    ),
                  ],
                ],
              ),
            ),

            // ── Timer + date flat strip ──
            Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                                Row(children: [
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
                                  if (isLinked)
                                    Text('SS', style: KiStyles.labelSm(color: _accentColor(context))),
                                ]),
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
                                        onTap: () => setState(() {
                                          (ex['sets'] as List)
                                              .removeAt(e.key);
                                        }),
                                        child: Icon(Icons.close,
                                            size: 14,
                                            color: textTertiary),
                                      ),
                                    ]),
                                  );
                                }),
                                // + Add Set inline button
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () =>
                                      _addSetInline(exIndex),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_circle_outline,
                                          size: 15,
                                          color: _accentColor(context)),
                                      const SizedBox(width: 6),
                                      Text(
                                        sets.isEmpty
                                            ? 'ADD FIRST SET'
                                            : 'ADD SET',
                                        style: KiStyles.label(
                                            color: _accentColor(context)),
                                      ),
                                    ],
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
                                  color: const Color(0xFF000000))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentContainer,
                            foregroundColor: const Color(0xFF000000),
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
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (isLinked)
              Container(width: 1, height: 16, color: accentColor.withValues(alpha: 0.4))
            else
              const SizedBox(width: 1),
            const SizedBox(width: 14),
            Text(
              isLinked ? 'SUPERSET — tap to unlink' : 'Link as superset',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isLinked ? accentColor : const Color(0xFF444444),
              ),
            ),
          ],
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
