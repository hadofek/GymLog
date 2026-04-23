import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:gal/gal.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/widgets/workout_share_card.dart';

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
  final GlobalKey _shareCardKey = GlobalKey();

  bool get _isWeightedType =>
      widget.type == WorkoutTypes.weighted ||
      widget.type == WorkoutTypes.bodyweight;

  @override
  void initState() {
    super.initState();
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
    final totalSets = _grouped.values.fold(0, (s, v) => s + v.length);
    final totalReps = _grouped.values
        .expand((v) => v)
        .fold(0, (s, e) => s + (e['reps'] as int));
    final totalWeight = _grouped.values
        .expand((v) => v)
        .fold(0.0, (s, e) => s + (e['weight'] as double) * (e['reps'] as int));

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
      ),
    );
  }

  Future<void> _editSet(Map<String, dynamic> set) async {
    final isBW = (set['weight'] as num).toDouble() == 0;
    final wCtrl = TextEditingController(text: isBW ? '' : '${set['weight']}');
    final rCtrl = TextEditingController(text: '${set['reps']}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Set',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Row(children: [
          Expanded(
            child: TextField(
              controller: wCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                hintText: '0 = bodyweight',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: rCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Reps',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor:
                  const Color(0xFF111111).withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save',
                style: TextStyle(
                    color: Color(0xFF111111), fontWeight: FontWeight.bold)),
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

  Future<void> _deleteSet(int setId) async {
    await DBHelper.deleteSet(setId);
    await _load();
  }

  Future<void> _addSetToExercise(String exerciseName) async {
    final wCtrl = TextEditingController();
    final rCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Set — $exerciseName',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Row(children: [
          Expanded(
            child: TextField(
              controller: wCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                hintText: '0 = BW',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: rCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Reps',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor:
                  const Color(0xFF111111).withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add',
                style: TextStyle(
                    color: Color(0xFF111111), fontWeight: FontWeight.bold)),
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Save as Template',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
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
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor:
                  const Color(0xFF111111).withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save',
                style: TextStyle(
                    color: Color(0xFF111111), fontWeight: FontWeight.bold)),
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
            content: Text(
                'Template "${ctrl.text.trim()}" saved!'),
            backgroundColor: const Color(0xFF111111),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildSaveTemplateBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: ElevatedButton.icon(
          onPressed: _saveAsTemplate,
          icon: const Icon(Icons.bookmark_outline_rounded, size: 18),
          label: const Text('Save as Template',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildNonWeightsBody() {
    final typeColor = WorkoutTypes.color(widget.type);
    final hasPhoto = _photoExists;
    final hasContent = _notes.isNotEmpty || _distanceKm > 0 || hasPhoto;

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(WorkoutTypes.icon(widget.type),
                  size: 32, color: typeColor),
            ),
            const SizedBox(height: 16),
            Text(
              '${WorkoutTypes.label(widget.type)} session logged',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (hasPhoto) _buildPhotoCard(),
        if (hasPhoto) const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: typeColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    WorkoutTypes.label(widget.type),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF111111),
                    ),
                  ),
                ]),
                if (_distanceKm > 0) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Icon(Icons.straighten, size: 16, color: typeColor),
                    const SizedBox(width: 8),
                    Text(
                      '${_distanceKm.toStringAsFixed(2)} km',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ]),
                ],
                if (_notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    _notes,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF555555),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
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
    final formattedDuration =
        DBHelper.formatDuration(widget.durationSeconds);
    final hasPhoto = _photoExists;
    final exerciseNames = _grouped.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.date,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: Color(0xFF111111),
                letterSpacing: -0.2,
              ),
            ),
            if (formattedDuration.isNotEmpty)
              Text(
                formattedDuration,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: WorkoutTypes.color(widget.type)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(WorkoutTypes.icon(widget.type),
                    size: 13, color: WorkoutTypes.color(widget.type)),
                const SizedBox(width: 4),
                Text(
                  WorkoutTypes.label(widget.type),
                  style: TextStyle(
                    color: WorkoutTypes.color(widget.type),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (_isWeightedType && _grouped.isNotEmpty)
            IconButton(
              icon: Icon(
                _editMode ? Icons.check_rounded : Icons.edit_outlined,
                color: _editMode
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF111111),
              ),
              onPressed: () => setState(() => _editMode = !_editMode),
              tooltip: _editMode ? 'Done editing' : 'Edit workout',
            ),
          if (_grouped.isNotEmpty && !_editMode)
            IconButton(
              icon: const Icon(Icons.ios_share_outlined,
                  color: Color(0xFF111111)),
              onPressed: _shareWorkout,
              tooltip: 'Share workout',
            ),
          IconButton(
            icon:
                const Icon(Icons.delete_outline, color: Color(0xFFE53935)),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text(
                    'Delete workout?',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111)),
                  ),
                  content: const Text(
                    'This will permanently delete this workout and all its sets.',
                    style: TextStyle(color: Color(0xFF666666)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF888888))),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935)
                            .withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Delete',
                          style: TextStyle(
                              color: Color(0xFFE53935),
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await DBHelper.deleteWorkout(widget.workoutId);
                if (mounted) Navigator.pop(context, true); // ignore: use_build_context_synchronously
              }
            },
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
                        for (int ei = 0;
                            ei < exerciseNames.length;
                            ei++) {
                          final exName = exerciseNames[ei];
                          final sets = _grouped[exName]!;
                          final typeColor =
                              WorkoutTypes.color(widget.type);
                          final myGroup =
                              _exerciseSupersetGroup[exName];
                          final prevGroup = ei > 0
                              ? _exerciseSupersetGroup[
                                  exerciseNames[ei - 1]]
                              : null;
                          final isInSuperset = myGroup != null;
                          final isContinuingSuperset =
                              isInSuperset && myGroup == prevGroup;

                          // "SUPERSET" connector above if continuing a chain
                          if (isContinuingSuperset) {
                            widgets.add(
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 4, left: 16),
                                child: Row(children: [
                                  Container(
                                    width: 2,
                                    height: 16,
                                    color: typeColor
                                        .withValues(alpha: 0.4),
                                  ),
                                ]),
                              ),
                            );
                          }

                          widgets.add(Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: isInSuperset
                                  ? Border.all(
                                      color: typeColor
                                          .withValues(alpha: 0.4),
                                      width: 1.5)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: typeColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        exName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: Color(0xFF111111),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    if (isInSuperset)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: typeColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.link_rounded,
                                                size: 11,
                                                color: typeColor),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Superset',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: typeColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F5F5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${sets.length} set${sets.length > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF888888),
                                          ),
                                        ),
                                      ),
                                  ]),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 6),
                                    child: Row(children: [
                                      const SizedBox(width: 36),
                                      const Expanded(
                                          child: Text('WEIGHT',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: Color(0xFFAAAAAA),
                                                  letterSpacing: 0.8))),
                                      Expanded(
                                          child: Text('REPS',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: Color(0xFFAAAAAA),
                                                  letterSpacing: 0.8))),
                                      if (_editMode)
                                        const SizedBox(width: 72),
                                    ]),
                                  ),
                                  ...sets.map((s) {
                                    final isBW =
                                        (s['weight'] as num).toDouble() ==
                                            0;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 8),
                                      child: Row(children: [
                                        _SetBadge(
                                            number:
                                                s['set_number'] as int),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            isBW
                                                ? 'BW'
                                                : '${s['weight']}kg',
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF111111)),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${s['reps']}',
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF111111)),
                                          ),
                                        ),
                                        if (_editMode) ...[
                                          GestureDetector(
                                            onTap: () => _editSet(s),
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF111111)
                                                    .withValues(alpha: 0.06),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 15,
                                                  color: Color(0xFF555555)),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () => _deleteSet(
                                                s['id'] as int),
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE53935)
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.close,
                                                  size: 15,
                                                  color: Color(0xFFE53935)),
                                            ),
                                          ),
                                        ],
                                      ]),
                                    );
                                  }),
                                  if (_editMode) ...[
                                    const SizedBox(height: 4),
                                    const Divider(
                                        height: 1,
                                        color: Color(0xFFF0F0F0)),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () =>
                                          _addSetToExercise(exName),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF111111)
                                                  .withValues(alpha: 0.07),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.add,
                                                size: 14,
                                                color: Color(0xFF555555)),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text('Add set',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF666666),
                                                  fontWeight:
                                                      FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
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

class _SharePreviewDialog extends StatefulWidget {
  final GlobalKey shareCardKey;
  final String date;
  final int durationSeconds;
  final int exerciseCount;
  final int totalSets;
  final int totalReps;
  final double totalWeight;

  const _SharePreviewDialog({
    required this.shareCardKey,
    required this.date,
    required this.durationSeconds,
    required this.exerciseCount,
    required this.totalSets,
    required this.totalReps,
    required this.totalWeight,
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
      final bytes = byteData!.buffer.asUint8List();
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
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
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
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.download_outlined),
                  label: Text(_sharing ? 'Saving...' : 'Save to Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
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
    );
  }
}
