import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/log_workout_screen.dart';
import 'package:gymlog/utils/workout_types.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});
  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final templates = await DBHelper.getTemplates();
    setState(() {
      _templates = templates;
      _loading = false;
    });
  }

  Future<void> _startWorkout(Map<String, dynamic> template) async {
    final templateId = template['id'] as int;
    final type = template['type'] as String? ?? WorkoutTypes.weighted;

    // Capture navigator before async gap so we can always dismiss the dialog
    final nav = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD700)),
      ),
    );

    final exerciseNames = await DBHelper.getTemplateExercises(templateId);
    final List<Map<String, dynamic>> exercises = [];

    for (final name in exerciseNames) {
      final lastSets = await DBHelper.getLastSets(name);
      exercises.add({
        'name': name,
        'sets': lastSets.isEmpty
            ? <Map<String, dynamic>>[] // empty — user logs fresh sets
            : lastSets
                .map((s) => <String, dynamic>{
                      'weight': (s['weight'] as num).toDouble(),
                      'reps': s['reps'] as int,
                    })
                .toList(),
      });
    }

    nav.pop(); // always dismiss loading dialog, even if widget unmounted
    if (!mounted) return;

    await nav.push(
      MaterialPageRoute(
        builder: (_) => LogWorkoutScreen(
          type: type,
          initialExercises: exercises,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> template) async {
    final name = template['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete template?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Remove "$name" from your templates?',
          style: const TextStyle(color: Color(0xFF666666)),
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
    if (confirmed == true) {
      await DBHelper.deleteTemplate(template['id'] as int);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Templates',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Color(0xFF111111),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Tap to start a workout',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
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
                        child: const Icon(Icons.bookmark_outline_rounded,
                            size: 32, color: Color(0xFF999999)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No templates yet',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Save a workout as a template\nfrom the workout detail screen',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF999999)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: _templates.length,
                  itemBuilder: (ctx, i) {
                    final tmpl = _templates[i];
                    final type =
                        tmpl['type'] as String? ?? WorkoutTypes.weighted;
                    final typeColor = WorkoutTypes.color(type);
                    return GestureDetector(
                      onTap: () => _startWorkout(tmpl),
                      onLongPress: () => _confirmDelete(tmpl),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
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
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(WorkoutTypes.icon(type),
                                  color: typeColor, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tmpl['name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Color(0xFF111111),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    WorkoutTypes.label(type),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: typeColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Color(0xFF8B7500), size: 20),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
