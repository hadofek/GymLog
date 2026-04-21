import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/workout_detail_screen.dart';

class MonthWorkoutsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> workouts;
  final String monthLabel;
  final int? initialDay;
  const MonthWorkoutsScreen(
      {super.key,
        required this.workouts,
        required this.monthLabel,
        this.initialDay});
  @override
  State<MonthWorkoutsScreen> createState() => _MonthWorkoutsScreenState();
}

class _MonthWorkoutsScreenState extends State<MonthWorkoutsScreen> {
  late List<Map<String, dynamic>> _workouts;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _workouts = List.from(widget.workouts);
    if (widget.initialDay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitialDay());
    }
  }

  void _scrollToInitialDay() {
    final day = widget.initialDay!;
    final idx = _workouts.indexWhere((w) {
      final dayStr = (w['date'] as String).trim().split('/').first;
      return int.tryParse(dayStr) == day;
    });
    if (idx > 0 && _scrollController.hasClients) {
      // 16px top padding + each card is ~ListTile(72px) + 12px margin = 84px
      final offset = (16.0 + idx * 84.0)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.monthLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _workouts.isEmpty
          ? const Center(
          child: Text('No workouts this month.',
              style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _workouts.length,
        itemBuilder: (ctx, i) {
          final w = _workouts[i];
          final dur = DBHelper.formatDuration(w['duration_seconds'] as int? ?? 0);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: Color(0xFFFFD700), shape: BoxShape.circle),
                child: const Icon(Icons.fitness_center,
                    size: 18, color: Colors.black),
              ),
              title: Text(w['date'],
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: dur.isNotEmpty
                  ? Text(dur, style: TextStyle(color: Colors.grey[600], fontSize: 12))
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final deleted = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => WorkoutDetailScreen(
                            workoutId: w['id'],
                            date: w['date'],
                            durationSeconds: w['duration_seconds'] as int? ?? 0)));
                if (deleted == true) {
                  setState(() => _workouts.removeAt(i));
                }
              },
            ),
          );
        },
      ),
    );
  }
}
