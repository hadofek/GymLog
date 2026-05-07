import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/utils/workout_types.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final int workoutId;
  final int durationSeconds;
  final String type;
  final List<Map<String, dynamic>> exercises;
  final List<String> prs;
  /// For cardio/flexibility: ordered key-value pairs to show instead of exercise list.
  /// e.g. [('Activity', 'Running'), ('Distance', '5.2km')]
  final List<(String, String)>? activityDetails;

  const WorkoutSummaryScreen({
    super.key,
    required this.workoutId,
    required this.durationSeconds,
    required this.type,
    required this.exercises,
    required this.prs,
    this.activityDetails,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  bool _savingPhoto = false;

  int get _totalSets => widget.exercises.fold<int>(
        0,
        (sum, ex) => sum +
            (ex['sets'] as List)
                .where((s) => (s['reps'] as int? ?? 0) > 0)
                .length,
      );

  Future<void> _pickPhoto(String source) async {
    setState(() => _savingPhoto = true);
    try {
      final picker = ImagePicker();
      final XFile? picked = source == 'camera'
          ? await picker.pickImage(source: ImageSource.camera, imageQuality: 85)
          : await picker.pickImage(
              source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) {
        if (mounted) setState(() => _savingPhoto = false);
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/progress_photos');
      if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
      final dest =
          '${photosDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(picked.path).copy(dest);
      await DBHelper.updateWorkoutPhoto(widget.workoutId, dest);
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  void _showPhotoSheet() {
    final bg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final accent = AppColors.accentContainer(context);
    final border = AppColors.border(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Add a progress photo',
                    style: KiStyles.headlineMd(color: textPrimary)),
              ),
              const SizedBox(height: 16),
              _PhotoTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take Photo',
                accent: accent,
                textPrimary: textPrimary,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto('camera');
                },
              ),
              _PhotoTile(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                accent: accent,
                textPrimary: textPrimary,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto('gallery');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accent = AppColors.accentContainer(context);
    final border = AppColors.border(context);
    final typeColor = WorkoutTypes.color(widget.type, context);

    final duration = DBHelper.formatDuration(widget.durationSeconds);
    final exerciseCount = widget.exercises.length;
    final setCount = _totalSets;
    final hasPRs = widget.prs.isNotEmpty;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: typeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      WorkoutTypes.label(widget.type).toUpperCase(),
                      style: KiStyles.label(color: textTertiary),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.close_rounded,
                            color: textTertiary, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Duration ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    duration.isNotEmpty ? duration : 'Done',
                    style: KiStyles.monument(color: textPrimary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.activityDetails != null
                        ? (widget.activityDetails!
                            .firstWhere((e) => e.$1 == 'Activity',
                                orElse: () => ('', ''))
                            .$2)
                        : '$exerciseCount exercise${exerciseCount != 1 ? 's' : ''}  ·  $setCount set${setCount != 1 ? 's' : ''}',
                    style: KiStyles.body(color: textSecondary),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Progress photo prompt (above fold) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: GestureDetector(
                  onTap: _savingPhoto ? null : _showPhotoSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.18), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.camera_alt_outlined, size: 16, color: accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add a progress photo to this workout',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: accent,
                            ),
                          ),
                        ),
                        if (_savingPhoto)
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: accent),
                          )
                        else
                          Icon(Icons.chevron_right_rounded,
                              size: 16, color: accent.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Divider(height: 1, thickness: 0.5, color: border),

              // ── Scrollable content ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  children: [

                    // ── PRs ──
                    if (hasPRs) ...[
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events_rounded,
                              color: accent, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            widget.prs.length == 1
                                ? 'New Personal Record'
                                : '${widget.prs.length} New Personal Records',
                            style: KiStyles.bodySemibold(color: accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...widget.prs.map(
                        (name) => Padding(
                          padding: const EdgeInsets.only(left: 28, top: 4),
                          child: Text(name,
                              style: KiStyles.body(color: textPrimary)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Divider(height: 1, thickness: 0.5, color: border),
                    ],

                    // ── Activity details (cardio / flexibility) ──
                    if (widget.activityDetails != null) ...[
                      const SizedBox(height: 20),
                      Text('DETAILS', style: KiStyles.label(color: textTertiary)),
                      const SizedBox(height: 12),
                      ...List.generate(widget.activityDetails!.length, (i) {
                        final entry = widget.activityDetails![i];
                        final isLast = i == widget.activityDetails!.length - 1;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Text(entry.$1,
                                      style: KiStyles.body(color: textSecondary)),
                                  const Spacer(),
                                  Text(entry.$2,
                                      style: KiStyles.bodySemibold(color: textPrimary)),
                                ],
                              ),
                            ),
                            if (!isLast)
                              Divider(height: 1, thickness: 0.5, color: border),
                          ],
                        );
                      }),
                    ],

                    // ── Exercise breakdown (strength / bodyweight) ──
                    if (widget.exercises.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('EXERCISES', style: KiStyles.label(color: textTertiary)),
                      const SizedBox(height: 12),
                      ...List.generate(widget.exercises.length, (i) {
                        final ex = widget.exercises[i];
                        final name = ex['name'] as String;
                        final sets = (ex['sets'] as List)
                            .where((s) => (s['reps'] as int? ?? 0) > 0)
                            .toList();
                        final isPR = widget.prs.contains(name);
                        final isLast = i == widget.exercises.length - 1;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: KiStyles.bodySemibold(
                                          color: isPR ? accent : textPrimary),
                                    ),
                                  ),
                                  if (isPR) ...[
                                    Text('PR', style: KiStyles.labelSm(color: accent)),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(
                                    '${sets.length} set${sets.length != 1 ? 's' : ''}',
                                    style: KiStyles.labelSm(color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              Divider(height: 1, thickness: 0.5, color: border),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Bottom actions ──
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: AppColors.primaryBtnFg(context),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Done',
                      style: KiStyles.bodySemibold(
                          color: AppColors.primaryBtnFg(context)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final Color textPrimary;
  final VoidCallback onTap;

  const _PhotoTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: accent, size: 22),
      ),
      title: Text(label, style: KiStyles.bodySemibold(color: textPrimary)),
      onTap: onTap,
    );
  }
}
