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
      {super.key,
      required this.workoutId,
      required this.date,
      this.durationSeconds = 0});
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
    final formattedDuration =
        DBHelper.formatDuration(widget.durationSeconds);

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
          if (_grouped.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_outlined,
                  color: Color(0xFF111111)),
              onPressed: _shareWorkout,
              tooltip: 'Share workout',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE53935)),
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
                        fontWeight: FontWeight.w700, color: Color(0xFF111111)),
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
                        backgroundColor:
                            const Color(0xFFE53935).withValues(alpha: 0.08),
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
      body: _grouped.isEmpty
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
                    'No exercises logged',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: _grouped.entries.map((entry) {
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
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Color(0xFF111111),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${entry.value.length} set${entry.value.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF888888),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Column header
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              SizedBox(width: 36),
                              Expanded(
                                child: Text(
                                  'WEIGHT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFAAAAAA),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'REPS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFAAAAAA),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...entry.value.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                _SetBadge(number: s['set_number'] as int),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${s['weight']}kg',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${s['reps']}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                ),
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
                      : const Icon(Icons.download_outlined),
                  label: Text(_sharing ? 'Saving...' : 'Save to Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
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
