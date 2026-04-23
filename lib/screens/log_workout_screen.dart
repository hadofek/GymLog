import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/add_exercise_screen.dart';
import 'package:gymlog/utils/workout_types.dart';

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
  int _nextSupersetGroup = 1;

  @override
  void initState() {
    super.initState();
    _workoutDate = widget.initialDate ?? DateTime.now();
    DBHelper.getExercises().then((e) => setState(() => _allExercises = e));
    _workoutStopwatch = Stopwatch()..start();
    if (widget.initialExercises != null) {
      _exercises.addAll(widget.initialExercises!);
    }
  }

  @override
  void dispose() {
    _workoutStopwatch.stop();
    super.dispose();
  }

  Color get _accentColor => WorkoutTypes.color(widget.type);

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

  Future<String?> _showProgressPhotoDialog() async {
    if (!mounted) return null;
    return await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add a progress photo?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Document your progress with a photo',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 20),
              ListTile(
                onTap: () async {
                  Navigator.pop(ctx, 'camera');
                },
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: Color(0xFF111111), size: 22),
                ),
                title: const Text('Take Photo',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Open camera',
                    style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
              ),
              ListTile(
                onTap: () => Navigator.pop(ctx, 'gallery'),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: Color(0xFF111111), size: 22),
                ),
                title: const Text('Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Pick an existing photo',
                    style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
              ),
              ListTile(
                onTap: () => Navigator.pop(ctx, null),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111).withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.close,
                      color: Color(0xFF888888), size: 22),
                ),
                title: const Text('Skip',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF888888))),
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
      return d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF111111)),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _pickDate,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isToday
                    ? '${WorkoutTypes.label(widget.type)} Workout'
                    : '${_workoutDate.day}/${_workoutDate.month}/${_workoutDate.year}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF111111),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_calendar_outlined,
                  size: 15, color: Color(0xFFAAAAAA)),
            ],
          ),
        ),
        actions: [
          if (_exercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _saveWorkout,
                style: TextButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: const Color(0xFF111111),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _exercises.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _accentColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            WorkoutTypes.icon(widget.type),
                            size: 32,
                            color: _accentColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No exercises yet',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap Add Exercise to get started',
                          style:
                              TextStyle(fontSize: 14, color: Color(0xFF999999)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    // Each pair (card + optional superset connector)
                    itemCount: _exercises.length * 2 - 1,
                    itemBuilder: (ctx, index) {
                      // Even index = exercise card; odd index = connector between [index/2] and [index/2 + 1]
                      if (index.isOdd) {
                        final i = index ~/ 2; // index of left exercise
                        final groupA =
                            _exercises[i]['supersetGroup'] as int?;
                        final groupB =
                            _exercises[i + 1]['supersetGroup'] as int?;
                        final isLinked =
                            groupA != null && groupA == groupB;
                        return _SupersetConnector(
                          isLinked: isLinked,
                          accentColor: _accentColor,
                          onTap: () => _toggleSuperset(i, i + 1),
                        );
                      }
                      final exIndex = index ~/ 2;
                      final ex = _exercises[exIndex];
                      final sets = ex['sets'] as List;
                      final supersetGroup =
                          ex['supersetGroup'] as int?;
                      final isLinked = supersetGroup != null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isLinked
                              ? Border.all(
                                  color:
                                      _accentColor.withValues(alpha: 0.4),
                                  width: 1.5)
                              : null,
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
                                    color: _accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ex['name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Color(0xFF111111),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (isLinked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _accentColor
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.link_rounded,
                                            size: 11, color: _accentColor),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Superset',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: _accentColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ]),
                              const SizedBox(height: 10),
                              ...sets.asMap().entries.map((e) {
                                final isBW =
                                    (e.value['weight'] as num).toDouble() == 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(children: [
                                    _SetBadge(
                                        number: e.key + 1,
                                        color: _accentColor),
                                    const SizedBox(width: 10),
                                    Text(
                                      isBW
                                          ? 'BW'
                                          : '${e.value['weight']}kg',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111111),
                                      ),
                                    ),
                                    const Text('  ×  ',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFFAAAAAA))),
                                    Text(
                                      '${e.value['reps']} reps',
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
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD700),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        child: const Text('PR',
                                            style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF111111))),
                                      ),
                                    ],
                                  ]),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Add Exercise',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 24),
          if (isLinked)
            Container(
              width: 2,
              height: 24,
              color: accentColor.withValues(alpha: 0.5),
            )
          else
            const SizedBox(width: 2),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isLinked
                    ? accentColor.withValues(alpha: 0.12)
                    : const Color(0xFF111111).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: isLinked
                    ? Border.all(
                        color: accentColor.withValues(alpha: 0.3), width: 1)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLinked ? Icons.link_rounded : Icons.link_outlined,
                    size: 14,
                    color: isLinked ? accentColor : const Color(0xFF999999),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isLinked ? 'Superset — tap to unlink' : 'Link as Superset',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          isLinked ? accentColor : const Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
