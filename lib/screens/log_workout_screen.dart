import 'package:flutter/material.dart';
import 'dart:async';
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
  late Timer _workoutTimer;
  String _workoutTime = '00:00';

  @override
  void initState() {
    super.initState();
    _workoutDate = widget.initialDate ?? DateTime.now();
    DBHelper.getExercises().then((e) => setState(() => _allExercises = e));
    _workoutStopwatch = Stopwatch()..start();
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final elapsed = _workoutStopwatch.elapsed;
      final h = elapsed.inHours;
      final m = elapsed.inMinutes % 60;
      final s = elapsed.inSeconds % 60;
      setState(() {
        _workoutTime = h > 0
            ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
            : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      });
    });
  }

  @override
  void dispose() {
    _workoutTimer.cancel();
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
      final hour = date.year == now.year && date.month == now.month && date.day == now.day
          ? now.hour
          : 0;
      final minute = date.year == now.year && date.month == now.month && date.day == now.day
          ? now.minute
          : 0;
      final dateStr =
          '${date.day}/${date.month}/${date.year}  ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      final workoutId = await DBHelper.insertWorkout(dateStr, _workoutStopwatch.elapsed.inSeconds);
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: _pickDate,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                () {
                  final now = DateTime.now();
                  final d = _workoutDate;
                  if (d.year == now.year && d.month == now.month && d.day == now.day) {
                    return 'New Workout';
                  }
                  return '${d.day}/${d.month}/${d.year}';
                }(),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit_calendar_outlined, size: 16, color: Colors.grey),
            ],
          ),
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(_workoutTime,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
            ),
          ),
          if (_exercises.isNotEmpty)
            TextButton(
                onPressed: _saveWorkout,
                child: const Text('Save',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _exercises.isEmpty
                ? const Center(
                child: Text('Add your first exercise below',
                    style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _exercises.length,
                itemBuilder: (ctx, i) {
                  final ex = _exercises[i];
                  final sets = ex['sets'] as List;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 8),
                          ...sets.asMap().entries.map((e) => Padding(
                            padding:
                            const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    shape: BoxShape.circle),
                                child: Center(
                                    child: Text('${e.key + 1}',
                                        style: const TextStyle(
                                            fontSize: 12))),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                  '${e.value['weight']}kg × ${e.value['reps']} reps'),
                            ]),
                          )),
                        ],
                      ),
                    ),
                  );
                }),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Add Exercise'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
