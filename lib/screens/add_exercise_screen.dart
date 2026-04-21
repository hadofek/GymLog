import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/widgets/wheel_column.dart';

class AddExerciseScreen extends StatefulWidget {
  final List<String> allExercises;
  const AddExerciseScreen({super.key, required this.allExercises});
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
    });
  }

  Future<void> _selectExercise(String name) async {
    _nameController.text = name;
    final last = await DBHelper.getLastSets(name);
    setState(() {
      _suggestions = [];
      _lastSets = last;
    });
  }

  void _saveSet() {
    final w = double.tryParse(_weightController.text);
    final r = int.tryParse(_repsController.text);
    if (w == null || r == null || w < 0 || r <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid weight and reps')),
      );
      return;
    }
    if (w == 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bodyweight exercise?'),
          content: const Text(
              'You entered 0 kg. Is this a bodyweight exercise?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid weight amount')),
                );
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _sets.add({'weight': w, 'reps': r});
                  _weightController.clear();
                  _repsController.clear();
                });
                _showRestPicker();
              },
              child: const Text('Yes, bodyweight'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() {
      _sets.add({'weight': w, 'reps': r});
      _weightController.clear();
      _repsController.clear();
    });
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, 16 + MediaQuery.of(ctx).viewPadding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text('Rest Time',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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
                          color: Colors.black38)),
                ),
                WheelColumn(
                  initialValue: pickedSeconds,
                  count: 60,
                  label: 'sec',
                  onChanged: (v) => pickedSeconds = v,
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Start Rest Timer'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Skip rest',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
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
      if (!mounted) { t.cancel(); return; }
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
            content: Text(
                'Please enter an exercise name and at least one set')),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Add Exercise'),
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_restTimerVisible)
            Container(
              color: _restTimerRunning ? Colors.black : Colors.grey[800],
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _restTimerRunning
                              ? 'Resting — ${_restSeconds}s remaining'
                              : 'Rest done! Ready for next set 💪',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: restProgress.toDouble(),
                            backgroundColor: Colors.white24,
                            valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelRest,
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70)),
                  )
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exercise name',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    onChanged: _onNameChanged,
                    decoration: InputDecoration(
                      hintText: 'e.g. Bench Press',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: _suggestions
                            .map((s) => ListTile(
                          dense: true,
                          title: Text(s),
                          onTap: () => _selectExercise(s),
                        ))
                            .toList(),
                      ),
                    ),
                  if (_lastSets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Last time:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                          const SizedBox(height: 4),
                          ..._lastSets.map((s) => Text(
                              'Set ${s['set_number']}: ${s['weight']}kg × ${s['reps']} reps',
                              style: const TextStyle(color: Colors.blue))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_sets.isNotEmpty) ...[
                    const Text('Sets logged',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._sets.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle),
                          child: Center(
                              child: Text('${e.key + 1}',
                                  style:
                                  const TextStyle(fontSize: 13))),
                        ),
                        const SizedBox(width: 10),
                        Text(
                            '${e.value['weight']}kg × ${e.value['reps']} reps',
                            style: const TextStyle(fontSize: 15)),
                        const Spacer(),
                        IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => _sets.removeAt(e.key))),
                      ]),
                    )),
                    const SizedBox(height: 12),
                  ],
                  Text(
                      _sets.isEmpty ? 'First set' : 'Set ${_sets.length + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Weight (kg)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Reps',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saveSet,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Set'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44)),
                  ),
                ],
              ),
            ),
          ),
          if (_sets.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
              child: ElevatedButton(
                onPressed: _done,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48)),
                child: Text(
                    'Done — ${_sets.length} set${_sets.length > 1 ? 's' : ''} logged'),
              ),
            ),
        ],
      ),
    );
  }
}
