import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/log_workout_screen.dart';
import 'package:gymlog/screens/template_edit_screen.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';

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
    if (mounted) {
      setState(() {
        _templates = templates;
        _loading = false;
      });
    }
  }

  Future<void> _startWorkout(Map<String, dynamic> template) async {
    final templateId = template['id'] as int;
    final type = template['type'] as String? ?? WorkoutTypes.weighted;

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
      exercises.add({
        'name': name,
        'sets': <Map<String, dynamic>>[],
      });
    }

    nav.pop();
    if (!mounted) return;

    await nav.push(
      MaterialPageRoute(
        builder: (_) => LogWorkoutScreen(
          type: type,
          initialExercises: exercises,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _editTemplate(Map<String, dynamic> template) async {
    final templateId = template['id'] as int;
    final exerciseNames =
        await DBHelper.getTemplateExercises(templateId);
    if (!mounted) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditScreen(
          templateId: templateId,
          templateName: template['name'] as String,
          templateType: template['type'] as String? ?? WorkoutTypes.weighted,
          exercises: exerciseNames,
        ),
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> template) async {
    final name = template['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete template?',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(ctx))),
        content: Text(
          'Remove "$name" from your templates?',
          style: TextStyle(color: AppColors.textSecondary(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary(ctx))),
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

  void _showTemplateOptions(Map<String, dynamic> tmpl) {
    final card = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final border = AppColors.border(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            Text(
              tmpl['name'] as String,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: textPrimary),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFF8B7500), size: 22),
              ),
              title: Text('Start Workout',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _startWorkout(tmpl);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_outlined,
                    color: Color(0xFF1565C0), size: 20),
              ),
              title: Text('Edit Template',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _editTemplate(tmpl);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Color(0xFFE53935), size: 20),
              ),
              title: const Text('Delete',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE53935))),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(tmpl);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final card = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Templates',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Tap to start · Long-press for options',
              style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
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
                          color: AppColors.border(context)
                              .withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bookmark_outline_rounded,
                            size: 32, color: textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No templates yet',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Save a workout as a template\nfrom the workout detail screen',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 14, color: textSecondary),
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
                      onLongPress: () => _showTemplateOptions(tmpl),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: card,
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tmpl['name'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: textPrimary,
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
                              child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Color(0xFF8B7500),
                                  size: 20),
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
