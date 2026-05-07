import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/log_workout_screen.dart';
import 'package:gymlog/screens/template_edit_screen.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';

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
      builder: (ctx) => Center(
        child: CircularProgressIndicator(
            color: AppColors.accentContainer(ctx)),
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

  Future<void> _createTemplate() async {
    // Pick workout type first, then open the editor in create mode.
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final textPrimary = AppColors.textPrimary(ctx);
        final border = AppColors.border(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Workout type', style: KiStyles.headlineMd(color: textPrimary)),
                const SizedBox(height: 4),
                Text('Choose the type for this template', style: KiStyles.body(color: AppColors.textTertiary(ctx))),
                const SizedBox(height: 16),
                ...WorkoutTypes.all.where((t) => t == WorkoutTypes.weighted || t == WorkoutTypes.bodyweight).map((type) {
                  final typeColor = WorkoutTypes.color(type, ctx);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(WorkoutTypes.icon(type), color: typeColor, size: 20),
                    ),
                    title: Text(WorkoutTypes.label(type),
                        style: KiStyles.bodySemibold(color: textPrimary)),
                    onTap: () => Navigator.pop(ctx, type),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
    if (type == null || !mounted) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditScreen(
          templateId: -1,
          templateName: '',
          templateType: type,
          exercises: const [],
          createMode: true,
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
                  AppColors.destructive(ctx).withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete',
                style: TextStyle(
                    color: AppColors.destructive(ctx),
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
              leading: Builder(builder: (ctx2) {
                final ac = AppColors.accentContainer(ctx2);
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ac.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.play_arrow_rounded,
                      color: ac, size: 22),
                );
              }),
              title: Text('Start Workout',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _startWorkout(tmpl);
              },
            ),
            ListTile(
              leading: Builder(builder: (ctx2) {
                final ac = AppColors.accentContainer(ctx2);
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ac.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_outlined, color: ac, size: 20),
                );
              }),
              title: Text('Edit Template',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _editTemplate(tmpl);
              },
            ),
            Builder(builder: (ctx2) {
              final destructive = AppColors.destructive(ctx2);
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: destructive.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delete_outline,
                      color: destructive, size: 20),
                ),
                title: Text('Delete',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: destructive)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(tmpl);
                },
              );
            }),
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
    final accentContainer = AppColors.accentContainer(context);
    final isDark = AppColors.isDark(context);
    final cardBorder = isDark
        ? const Color(0xFF1C2235).withValues(alpha: 0.6)
        : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Expanded(
              child: Text(
                'GYMLOG',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 3,
                  color: accentContainer,
                ),
              ),
            ),
            Text('TEMPLATES',
                style: KiStyles.label(
                    color: AppColors.textTertiary(context))),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _createTemplate,
              style: TextButton.styleFrom(
                backgroundColor: accentContainer.withValues(alpha: 0.12),
                foregroundColor: accentContainer,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('New', style: KiStyles.label(color: accentContainer)),
            ),
          ),
        ],
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
                          color: accentContainer.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bookmark_outline_rounded,
                            size: 32, color: accentContainer),
                      ),
                      const SizedBox(height: 16),
                      Text('No templates yet',
                          style: KiStyles.headlineMd(color: textPrimary)),
                      const SizedBox(height: 6),
                      Text(
                        'Create a template to start workouts faster,\nor save any past workout as a template.',
                        textAlign: TextAlign.center,
                        style: KiStyles.label(color: textSecondary),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: _createTemplate,
                        style: TextButton.styleFrom(
                          backgroundColor: accentContainer.withValues(alpha: 0.12),
                          foregroundColor: accentContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('Create template', style: KiStyles.label(color: accentContainer)),
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
                    final typeColor = WorkoutTypes.color(type, context);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder, width: 1),
                      ),
                      child: Row(
                        children: [
                          // Main tappable area — starts workout
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _startWorkout(tmpl),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
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
                                        color: accentContainer.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.play_arrow_rounded,
                                          color: accentContainer, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // ⋯ options button
                          GestureDetector(
                            onTap: () => _showTemplateOptions(tmpl),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 16, 14, 16),
                              child: Icon(Icons.more_vert_rounded,
                                  size: 18, color: AppColors.textTertiary(context)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
