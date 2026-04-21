import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:gal/gal.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/widgets/workout_share_card.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final int workoutId;
  final String date;
  final int durationSeconds;
  const WorkoutDetailScreen(
      {super.key, required this.workoutId, required this.date, this.durationSeconds = 0});
  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  final GlobalKey _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sets = await DBHelper.getSetsForWorkout(widget.workoutId);
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in sets) {
      final name = s['exercise_name'] as String;
      grouped.putIfAbsent(name, () => []).add(s);
    }
    setState(() => _grouped = grouped);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.date),
        elevation: 0,
        actions: [
          if (_grouped.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: _shareWorkout,
              tooltip: 'Share workout',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete workout?'),
                  content: const Text('This will permanently delete this workout and all its sets.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
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
      body: _grouped.isEmpty
          ? const Center(child: Text('No exercises logged.'))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: _grouped.entries.map((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...entry.value.map((s) => Padding(
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
                            child: Text('${s['set_number']}',
                                style: const TextStyle(
                                    fontSize: 12))),
                      ),
                      const SizedBox(width: 8),
                      Text(
                          '${s['weight']}kg × ${s['reps']} reps'),
                    ]),
                  )),
                ],
              ),
            ),
          );
        }).toList(),
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
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Gallery permission denied')));
        if (mounted) setState(() => _sharing = false);
        return;
      }
      await Gal.putImageBytes(
          bytes, name: 'gymlog_${DateTime.now().millisecondsSinceEpoch}');
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
                      : const Icon(Icons.share),
                  label: Text(_sharing ? 'Preparing...' : 'Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
