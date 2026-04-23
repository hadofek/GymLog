import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/add_exercise_screen.dart';

class LogWorkoutScreen extends StatefulWidget {
  final DateTime? initialDate;
  const LogWorkoutScreen({super.key, this.initialDate});
  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final List<Map<String, dynamic>> _exercises = [];
  List<String> _allExercises = [];
  late DateTime _workoutDate;

  late Stopwatch _workoutStopwatch;

  @override
  void initState() {
    super.initState();
    _workoutDate = widget.initialDate ?? DateTime.now();
    DBHelper.getExercises().then((e) => setState(() => _allExercises = e));
    _workoutStopwatch = Stopwatch()..start();
  }

  @override
  void dispose() {
    _workoutStopwatch.stop();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _workoutDate,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _workoutDate = picked);
    }
  }

  Future<void> _addExercise() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AddExerciseScreen(allExercises: _allExercises)));
    if (result != null) {
      setState(() => _exercises.add(result));
      if (!_allExercises.contains(result['name'])) {
        _allExercises.add(result['name']);
      }
    }
  }

  Future<void> _saveWorkout() async {
    if (_exercises.isEmpty) return;
    try {
      final date = _workoutDate;
      final now = DateTime.now();
      final hour = date.year == now.year &&
              date.month == now.month &&
              date.day == now.day
          ? now.hour
          : 0;
      final minute = date.year == now.year &&
              date.month == now.month &&
              date.day == now.day
          ? now.minute
          : 0;
      final dateStr =
          '${date.day}/${date.month}/${date.year}  ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      final workoutId = await DBHelper.insertWorkout(
          dateStr, _workoutStopwatch.elapsed.inSeconds);
      for (final ex in _exercises) {
        await DBHelper.insertExercise(ex['name']);
        final sets = ex['sets'] as List;
        for (int i = 0; i < sets.length; i++) {
          await DBHelper.insertSet(workoutId, ex['name'], i + 1,
              sets[i]['weight'], sets[i]['reps']);
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
                    ? 'New Workout'
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
                  backgroundColor: const Color(0xFFFFD700),
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
                            color: const Color(0xFF111111).withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.fitness_center_outlined,
                            size: 32,
                            color: Color(0xFF999999),
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
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _exercises.length,
                    itemBuilder: (ctx, i) {
                      final ex = _exercises[i];
                      final sets = ex['sets'] as List;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFD700),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    ex['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Color(0xFF111111),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...sets.asMap().entries.map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(children: [
                                      _SetBadge(number: e.key + 1),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${e.value['weight']}kg',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111111),
                                        ),
                                      ),
                                      const Text(
                                        '  ×  ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFAAAAAA),
                                        ),
                                      ),
                                      Text(
                                        '${e.value['reps']} reps',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111111),
                                        ),
                                      ),
                                    ]),
                                  )),
                            ],
                          ),
                        ),
                      );
                    }),
          ),
          // ── Bottom action ──
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Add Exercise',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
