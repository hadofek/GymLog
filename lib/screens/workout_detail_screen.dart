import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:gal/gal.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/widgets/gymlog_wordmark.dart';
import 'package:gymlog/widgets/workout_share_card.dart';
import 'package:gymlog/utils/exercise_data.dart';
import 'package:gymlog/utils/weight_format.dart';
import 'package:gymlog/screens/exercise_history_screen.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final int workoutId;
  final String date;
  final int durationSeconds;
  final String type;
  const WorkoutDetailScreen(
      {super.key,
      required this.workoutId,
      required this.date,
      this.durationSeconds = 0,
      this.type = WorkoutTypes.weighted});
  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  // exercise name → superset_group (null = no superset)
  Map<String, int?> _exerciseSupersetGroup = {};
  String _notes = '';
  double _distanceKm = 0;
  String _photoPath = '';
  bool _photoExists = false;
  bool _editMode = false;
  bool _isSharing = false;
  final GlobalKey _shareCardKey = GlobalKey();

  bool get _isWeightedType =>
      widget.type == WorkoutTypes.weighted ||
      widget.type == WorkoutTypes.bodyweight;

  @override
  void initState() {
    super.initState();
    WeightFormat.load();
    _load();
  }

  Future<void> _load() async {
    final sets = await DBHelper.getSetsForWorkout(widget.workoutId);
    final workout = await DBHelper.getWorkoutById(widget.workoutId);
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, int?> supersetGroups = {};
    for (final s in sets) {
      final name = s['exercise_name'] as String;
      grouped.putIfAbsent(name, () => []).add(s);
      final sg = s['superset_group'] as int?;
      if (sg != null) supersetGroups[name] = sg;
    }
    setState(() {
      _grouped = grouped;
      _exerciseSupersetGroup = supersetGroups;
      _notes = workout?['notes'] as String? ?? '';
      _distanceKm = (workout?['distance_km'] as num?)?.toDouble() ?? 0;
      _photoPath = workout?['photo_path'] as String? ?? '';
      _photoExists = _photoPath.isNotEmpty && File(_photoPath).existsSync();
      if (grouped.isEmpty) _editMode = false;
    });
  }

  Future<void> _shareWorkout() async {
    if (_isSharing) return;
    _isSharing = true;
    try {
      await _doShareWorkout();
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _doShareWorkout() async {
    final totalSets = _grouped.values.fold(0, (s, v) => s + v.length);
    final totalReps = _grouped.values
        .expand((v) => v)
        .fold(0, (s, e) => s + (e['reps'] as int));
    final totalWeight = _grouped.values
        .expand((v) => v)
        .fold(0.0, (s, e) => s + (e['weight'] as num).toDouble() * (e['reps'] as int));

    final pbs =
        await DBHelper.getPersonalBestsInWorkout(widget.workoutId);
    final muscleBreakdown =
        await DBHelper.getMuscleVolumeForWorkout(widget.workoutId);
    final prevVolumes =
        await DBHelper.getLastNWorkoutVolumes(widget.workoutId, 4);
    final volumeTrend = [...prevVolumes, totalWeight];

    if (!mounted) return; // ignore: use_build_context_synchronously
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _SharePreviewDialog(
        shareCardKey: _shareCardKey,
        date: widget.date,
        durationSeconds: widget.durationSeconds,
        exerciseCount: _grouped.length,
        totalSets: totalSets,
        totalReps: totalReps,
        totalWeight: totalWeight,
        photoPath: _photoExists ? _photoPath : null,
        personalBests: pbs,
        muscleBreakdown: muscleBreakdown,
        volumeTrend: volumeTrend,
      ),
    );
  }

  Future<void> _editSet(Map<String, dynamic> set) async {
    final isBW = (set['weight'] as num).toDouble() == 0;
    final wCtrl = TextEditingController(text: isBW ? '' : '${set['weight']}');
    final rCtrl = TextEditingController(text: '${set['reps']}');
    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);

    final isTimed = ExerciseData.isTimedExercise(set['exercise_name'] as String? ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Set', style: KiStyles.headlineMd(color: textPrimary)),
        content: isTimed
            ? TextField(
                controller: rCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: KiStyles.body(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Seconds',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            : Row(children: [
          Expanded(
            child: TextField(
              controller: wCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: KiStyles.body(color: textPrimary),
              decoration: InputDecoration(
                labelText: WeightFormat.inputLabel,
                hintText: '0 = bodyweight',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: rCtrl,
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save', style: KiStyles.label(color: accentContainer)),
          ),
        ],
      ),
    );
    if (saved == true) {
      final w = double.tryParse(wCtrl.text.isEmpty ? '0' : wCtrl.text);
      final r = int.tryParse(rCtrl.text);
      if (w != null && r != null && w >= 0 && r > 0) {
        await DBHelper.updateSet(set['id'] as int, w, r);
        await _load();
      }
    }
  }

  Future<void> _deleteSet(Map<String, dynamic> setData) async {
    final setId = setData['id'] as int;
    await DBHelper.deleteSet(setId);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Set removed',
          style: KiStyles.body(color: AppColors.textPrimary(context)),
        ),
        backgroundColor: AppColors.cardBg(context),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.accentContainer(context),
          onPressed: () async {
            await DBHelper.insertSet(
              widget.workoutId,
              setData['exercise_name'] as String,
              setData['set_number'] as int,
              (setData['weight'] as num).toDouble(),
              setData['reps'] as int,
              supersetGroup: setData['superset_group'] as int?,
            );
            await _load();
          },
        ),
      ),
    );
  }

  Future<void> _addSetToExercise(String exerciseName) async {
    final wCtrl = TextEditingController();
    final rCtrl = TextEditingController();
    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);
    final isTimed = ExerciseData.isTimedExercise(exerciseName);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Set — $exerciseName',
            style: KiStyles.headlineMd(color: textPrimary)),
        content: isTimed
            ? TextField(
                controller: rCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: KiStyles.body(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Seconds',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            : Row(children: [
          Expanded(
            child: TextField(
              controller: wCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: KiStyles.body(color: textPrimary),
              decoration: InputDecoration(
                labelText: WeightFormat.inputLabel,
                hintText: '0 = bodyweight',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: rCtrl,
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Add', style: KiStyles.label(color: accentContainer)),
          ),
        ],
      ),
    );
    if (saved == true) {
      final w = double.tryParse(wCtrl.text.isEmpty ? '0' : wCtrl.text);
      final r = int.tryParse(rCtrl.text);
      if (w != null && r != null && w >= 0 && r > 0) {
        final nextNum = (_grouped[exerciseName]?.length ?? 0) + 1;
        await DBHelper.insertSet(
            widget.workoutId, exerciseName, nextNum, w, r);
        await _load();
      }
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_grouped.isEmpty) return;
    final ctrl = TextEditingController();
    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Save as Template',
            style: KiStyles.headlineMd(color: textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: KiStyles.body(color: textPrimary),
          decoration: InputDecoration(
            labelText: 'Template name',
            hintText: 'e.g. Push Day A',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: KiStyles.label(color: textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: accentContainer.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save', style: KiStyles.label(color: accentContainer)),
          ),
        ],
      ),
    );
    if (saved == true && ctrl.text.trim().isNotEmpty) {
      final exercises = _grouped.keys.toList();
      await DBHelper.saveTemplate(ctrl.text.trim(), widget.type, exercises);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${ctrl.text.trim()}" saved!'),
            backgroundColor: accentContainer,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildSaveTemplateBar() {
    final accentContainer = AppColors.accentContainer(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ElevatedButton.icon(
          onPressed: _saveAsTemplate,
          icon: const Icon(Icons.bookmark_outline_rounded, size: 18),
          label: Text('Save as Template',
              style: KiStyles.bodySemibold(color: AppColors.primaryBtnFg(context))),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentContainer,
            foregroundColor: AppColors.primaryBtnFg(context),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // Parses notes stored as "Activity\navg_speed:X.X\nUser notes" into components.
  ({String activity, double? avgSpeed, String userNotes}) _parseCardioNotes(String raw) {
    final lines = raw.split('\n').where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return (activity: '', avgSpeed: null, userNotes: '');
    final activity = lines.first;
    double? avgSpeed;
    final noteLines = <String>[];
    for (final line in lines.skip(1)) {
      if (line.startsWith('avg_speed:')) {
        avgSpeed = double.tryParse(line.substring('avg_speed:'.length).trim());
      } else {
        noteLines.add(line);
      }
    }
    return (activity: activity, avgSpeed: avgSpeed, userNotes: noteLines.join('\n'));
  }

  Future<void> _editNonWeightedWorkout() async {
    final parsed = _parseCardioNotes(_notes);
    final isCardio = widget.type == WorkoutTypes.cardio;

    final activityCtrl = TextEditingController(text: parsed.activity);
    final distCtrl = TextEditingController(
        text: _distanceKm > 0 ? _distanceKm.toStringAsFixed(2) : '');
    final speedCtrl = TextEditingController(
        text: parsed.avgSpeed != null ? '${parsed.avgSpeed}' : '');
    final notesCtrl = TextEditingController(text: parsed.userNotes);

    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);

    InputDecoration fieldDec(String label) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textTertiary),
          filled: true,
          fillColor: AppColors.inputFill(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border(context))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentContainer, width: 2)),
        );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 24 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border(ctx),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Edit Session',
                style: KiStyles.headlineMd(color: textPrimary)),
            const SizedBox(height: 20),
            TextField(
              controller: activityCtrl,
              style: KiStyles.body(color: textPrimary),
              decoration: fieldDec('Activity'),
            ),
            if (isCardio) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: distCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: KiStyles.body(color: textPrimary),
                    decoration: fieldDec('Distance (km)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: speedCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: KiStyles.body(color: textPrimary),
                    decoration: fieldDec('Avg speed (km/h)'),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              style: KiStyles.body(color: textPrimary),
              decoration: fieldDec('Notes').copyWith(
                  contentPadding: const EdgeInsets.all(14)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentContainer,
                  foregroundColor: AppColors.primaryBtnFg(context),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Save',
                    style: KiStyles.bodySemibold(
                        color: AppColors.primaryBtnFg(context))),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      final activity = activityCtrl.text.trim();
      final avgSpeed = double.tryParse(speedCtrl.text.trim());
      final userNotes = notesCtrl.text.trim();
      final notesParts = <String>[
        if (activity.isNotEmpty) activity,
        if (avgSpeed != null && avgSpeed > 0) 'avg_speed:$avgSpeed',
        if (userNotes.isNotEmpty) userNotes,
      ];
      final newNotes = notesParts.join('\n');
      final newDistance = isCardio
          ? (double.tryParse(distCtrl.text.trim()) ?? _distanceKm)
          : null;

      await DBHelper.updateWorkoutDetails(
        widget.workoutId,
        notes: newNotes,
        distanceKm: newDistance,
      );
      await _load();
    }
  }

  Widget _buildNonWeightsBody() {
    final typeColor = WorkoutTypes.color(widget.type, context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final hasPhoto = _photoExists;
    final hasContent = _notes.isNotEmpty || _distanceKm > 0 || hasPhoto;

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(WorkoutTypes.icon(widget.type),
                  size: 32, color: typeColor),
            ),
            const SizedBox(height: 16),
            Text('${WorkoutTypes.label(widget.type)} session logged',
                style: KiStyles.headlineMd(color: textPrimary)),
          ],
        ),
      );
    }

    final parsed = _parseCardioNotes(_notes);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (hasPhoto) _buildPhotoCard(),
        if (hasPhoto) const SizedBox(height: 12),
        Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration:
                        BoxDecoration(color: typeColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    parsed.activity.isNotEmpty
                        ? parsed.activity
                        : WorkoutTypes.label(widget.type),
                    style: KiStyles.bodySemibold(color: textPrimary),
                  ),
                ]),
                if (_distanceKm > 0 || parsed.avgSpeed != null) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    if (_distanceKm > 0) ...[
                      Icon(Icons.straighten, size: 16, color: typeColor),
                      const SizedBox(width: 6),
                      Text('${_distanceKm.toStringAsFixed(2)} km',
                          style: KiStyles.bodySemibold(color: textPrimary)),
                    ],
                    if (_distanceKm > 0 && parsed.avgSpeed != null)
                      const SizedBox(width: 16),
                    if (parsed.avgSpeed != null) ...[
                      Icon(Icons.speed_outlined, size: 16, color: typeColor),
                      const SizedBox(width: 6),
                      Text('${parsed.avgSpeed} km/h',
                          style: KiStyles.bodySemibold(color: textPrimary)),
                    ],
                  ]),
                ],
                if (parsed.userNotes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(parsed.userNotes,
                      style: KiStyles.body(color: textSecondary)),
                ],
                if (parsed.activity.isEmpty && _notes.isEmpty) ...[
                  const SizedBox(height: 14),
                  Text('No notes', style: KiStyles.label(color: textTertiary)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        File(_photoPath),
        width: double.infinity,
        height: 260,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoExists;
    final exerciseNames = _grouped.keys.toList();

    final bg = AppColors.background(context);
    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);
    final typeColor = WorkoutTypes.color(widget.type, context);
    final accentContainer = AppColors.accentContainer(context);
    final errorColor = AppColors.error(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        // Title: GYMLOG wordmark + type badge side by side
        title: const GymlogWordmark(),
        // Single overflow menu replaces the crowded action buttons
        actions: [
          if (_editMode)
            IconButton(
              icon: Icon(Icons.check_rounded,
                  color: AppColors.liveActivity(context)),
              onPressed: () => setState(() => _editMode = false),
              tooltip: 'Done editing',
            )
          else
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: textSecondary),
              color: cardBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (value) async {
                if (value == 'edit') {
                  setState(() => _editMode = true);
                } else if (value == 'edit_session') {
                  await _editNonWeightedWorkout();
                } else if (value == 'share') {
                  await _shareWorkout();
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text('Delete workout?',
                          style: KiStyles.headlineMd(color: textPrimary)),
                      content: Text(
                        'This will permanently delete this workout and all its sets.',
                        style: KiStyles.body(color: textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel',
                              style: KiStyles.label(color: textTertiary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.error(context),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Delete',
                              style: KiStyles.label(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await DBHelper.deleteWorkout(widget.workoutId);
                    if (mounted) Navigator.pop(context, true); // ignore: use_build_context_synchronously
                  }
                }
              },
              itemBuilder: (ctx) => [
                if (_grouped.isNotEmpty)
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined,
                          size: 18, color: textSecondary),
                      const SizedBox(width: 12),
                      Text('Edit sets',
                          style: KiStyles.body(color: textPrimary)),
                    ]),
                  ),
                if (!_isWeightedType)
                  PopupMenuItem(
                    value: 'edit_session',
                    child: Row(children: [
                      Icon(Icons.edit_outlined,
                          size: 18, color: textSecondary),
                      const SizedBox(width: 12),
                      Text('Edit session',
                          style: KiStyles.body(color: textPrimary)),
                    ]),
                  ),
                PopupMenuItem(
                  value: 'share',
                  child: Row(children: [
                    Icon(Icons.ios_share_outlined,
                        size: 18, color: textSecondary),
                    const SizedBox(width: 12),
                    Text('Share',
                        style: KiStyles.body(color: textPrimary)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: errorColor),
                    const SizedBox(width: 12),
                    Text('Delete',
                        style: KiStyles.body(color: errorColor)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: !_isWeightedType || _grouped.isEmpty
          ? _buildNonWeightsBody()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: [
                      if (hasPhoto) ...[
                        _buildPhotoCard(),
                        const SizedBox(height: 12),
                      ],
                      ...() {
                        final widgets = <Widget>[];
                        for (int ei = 0; ei < exerciseNames.length; ei++) {
                          final exName = exerciseNames[ei];
                          final sets = _grouped[exName]!;
                          final myGroup = _exerciseSupersetGroup[exName];
                          final prevGroup = ei > 0
                              ? _exerciseSupersetGroup[exerciseNames[ei - 1]]
                              : null;
                          final isInSuperset = myGroup != null;
                          final isContinuingSuperset =
                              isInSuperset && myGroup == prevGroup;

                          if (isContinuingSuperset) {
                            widgets.add(
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 4, left: 16),
                                child: Container(
                                  width: 2,
                                  height: 16,
                                  color: typeColor.withValues(alpha: 0.4),
                                ),
                              ),
                            );
                          }

                          widgets.add(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Divider(height: 1, thickness: 0.5, color: borderColor),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                          color: typeColor,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Semantics(
                                        label: 'View history for $exName',
                                        button: true,
                                        child: GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ExerciseHistoryScreen(
                                                exerciseName: exName,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(exName,
                                                    style: KiStyles.bodySemibold(
                                                        color: textPrimary)),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(Icons.arrow_forward_ios_rounded,
                                                  size: 11,
                                                  color: AppColors.textTertiary(context)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isInSuperset)
                                      Text('SS', style: KiStyles.labelSm(color: typeColor))
                                    else
                                      Text(
                                        '${sets.length} set${sets.length > 1 ? 's' : ''}',
                                        style: KiStyles.labelSm(color: textTertiary),
                                      ),
                                  ]),
                                  const SizedBox(height: 12),
                                  // Column headers
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(children: [
                                      const SizedBox(width: 36),
                                      Expanded(
                                          child: Text('WEIGHT',
                                              style: KiStyles.labelSm(
                                                  color: textTertiary))),
                                      Expanded(
                                          child: Text('REPS',
                                              style: KiStyles.labelSm(
                                                  color: textTertiary))),
                                      if (_editMode) const SizedBox(width: 72),
                                    ]),
                                  ),
                                  ...sets.map((s) {
                                    final isBW =
                                        (s['weight'] as num).toDouble() == 0;
                                    final setRow = Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8),
                                      child: Row(children: [
                                        _SetBadge(
                                            number: s['set_number'] as int),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            isBW
                                                ? 'Bodyweight'
                                                : WeightFormat.format((s['weight'] as num).toDouble()),
                                            style: KiStyles.bodySemibold(
                                                color: textPrimary),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text('${s['reps']}',
                                              style: KiStyles.bodySemibold(
                                                  color: textPrimary)),
                                        ),
                                        if (_editMode) ...[
                                          Semantics(
                                            label: 'Edit set ${s['set_number']}',
                                            button: true,
                                            child: GestureDetector(
                                              onTap: () => _editSet(s),
                                              child: Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Icon(Icons.edit_outlined,
                                                    size: 16, color: textSecondary),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Semantics(
                                            label: 'Delete set ${s['set_number']}',
                                            button: true,
                                            child: GestureDetector(
                                              onTap: () => _deleteSet(s),
                                              child: Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Icon(Icons.close,
                                                    size: 16, color: errorColor),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ]),
                                    );
                                    if (!_editMode) return setRow;
                                    return Dismissible(
                                      key: ValueKey('set-${s['id']}'),
                                      direction: DismissDirection.endToStart,
                                      onDismissed: (_) =>
                                          _deleteSet(s),
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                            right: 12),
                                        decoration: BoxDecoration(
                                          color: errorColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                            Icons.delete_outline,
                                            color: errorColor,
                                            size: 20),
                                      ),
                                      child: setRow,
                                    );
                                  }),
                                  if (_editMode) ...[
                                    const SizedBox(height: 4),
                                    Divider(height: 1, color: borderColor),
                                    const SizedBox(height: 8),
                                    Semantics(
                                      label: 'Add set to $exName',
                                      button: true,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _addSetToExercise(exName),
                                        child: SizedBox(
                                          height: 44,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.add,
                                                  size: 14,
                                                  color: AppColors.accentContainer(context)),
                                              const SizedBox(width: 6),
                                              Text('Add set',
                                                  style: KiStyles.label(
                                                      color: textSecondary)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            ],
                          ));
                        }
                        return widgets;
                      }(),
                    ],
                  ),
                ),
                _buildSaveTemplateBar(),
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
    return SizedBox(
      width: 26,
      child: Text(
        '$number',
        style: KiStyles.labelSm(color: AppColors.textTertiary(context)),
      ),
    );
  }
}

class _SharePreviewDialog extends StatefulWidget {
  final GlobalKey shareCardKey;
  final String date;
  final int durationSeconds;
  final int exerciseCount;
  final int totalSets;
  final int totalReps;
  final double totalWeight;
  final String? photoPath;
  final List<String> personalBests;
  final Map<String, double> muscleBreakdown;
  final List<double> volumeTrend;

  const _SharePreviewDialog({
    required this.shareCardKey,
    required this.date,
    required this.durationSeconds,
    required this.exerciseCount,
    required this.totalSets,
    required this.totalReps,
    required this.totalWeight,
    this.photoPath,
    this.personalBests = const [],
    this.muscleBreakdown = const {},
    this.volumeTrend = const [],
  });

  @override
  State<_SharePreviewDialog> createState() => _SharePreviewDialogState();
}

class _SharePreviewDialogState extends State<_SharePreviewDialog> {
  bool _sharing = false;

  Future<void> _doShare() async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final boundary = widget.shareCardKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');
      final bytes = byteData.buffer.asUint8List();
      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Gallery permission denied')));
        if (mounted) setState(() => _sharing = false);
        return;
      }
      await Gal.putImageBytes(bytes,
          name: 'gymlog_${DateTime.now().millisecondsSinceEpoch}');
      nav.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Saved to gallery!'),
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not save image: $e')));
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: widget.shareCardKey,
              child: WorkoutShareCard(
                date: widget.date,
                durationSeconds: widget.durationSeconds,
                exerciseCount: widget.exerciseCount,
                totalSets: widget.totalSets,
                totalReps: widget.totalReps,
                totalWeight: widget.totalWeight,
                photoPath: widget.photoPath,
                personalBests: widget.personalBests,
                muscleBreakdown: widget.muscleBreakdown,
                volumeTrend: widget.volumeTrend,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary(context),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _sharing ? null : _doShare,
                    icon: _sharing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background(context)))
                        : const Icon(Icons.download_outlined),
                    label: Text(_sharing ? 'Saving...' : 'Save to Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentContainer(context),
                      foregroundColor: AppColors.primaryBtnFg(context),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle:
                          const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
