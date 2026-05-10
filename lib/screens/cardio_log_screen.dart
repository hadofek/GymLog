import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/workout_summary_screen.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/widgets/gymlog_wordmark.dart';

class CardioLogScreen extends StatefulWidget {
  final DateTime? initialDate;
  const CardioLogScreen({super.key, this.initialDate});
  @override
  State<CardioLogScreen> createState() => _CardioLogScreenState();
}

class _CardioLogScreenState extends State<CardioLogScreen> {
  final _activityController = TextEditingController();
  final _distanceController = TextEditingController();
  final _avgSpeedController = TextEditingController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _workoutDate;

  static const _suggestions = [
    'Running', 'Cycling', 'Swimming', 'Rowing',
    'Jump Rope', 'Walking', 'Hiking', 'Elliptical',
  ];

  @override
  void initState() {
    super.initState();
    _workoutDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _activityController.dispose();
    _distanceController.dispose();
    _avgSpeedController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _notesController.dispose();
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
    if (picked != null) setState(() => _workoutDate = picked);
  }

  bool get _canSave => _activityController.text.trim().isNotEmpty;

  int get _durationSeconds {
    final h = int.tryParse(_hoursController.text) ?? 0;
    final m = int.tryParse(_minutesController.text) ?? 0;
    return h * 3600 + m * 60;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    try {
      final date = _workoutDate;
      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      final hour = isToday ? now.hour : 0;
      final minute = isToday ? now.minute : 0;
      final dateStr =
          '${date.day}/${date.month}/${date.year}  ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      final distance = double.tryParse(_distanceController.text) ?? 0.0;
      final avgSpeed = double.tryParse(_avgSpeedController.text) ?? 0.0;

      final notesParts = <String>[
        _activityController.text.trim(),
        if (avgSpeed > 0) 'avg_speed:$avgSpeed',
        if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
      ];

      final workoutId = await DBHelper.insertWorkout(
        dateStr,
        _durationSeconds,
        type: WorkoutTypes.cardio,
        distanceKm: distance,
        notes: notesParts.join('\n'),
      );

      final prs = await DBHelper.getNonWeightedPRs(workoutId);

      if (!mounted) return;
      final details = <(String, String)>[
        ('Activity', _activityController.text.trim()),
        if (distance > 0) ('Distance', '${distance.toStringAsFixed(1)}km'),
        if (_durationSeconds > 0)
          ('Duration', DBHelper.formatDuration(_durationSeconds)),
        if (avgSpeed > 0) ('Avg Speed', '${avgSpeed.toStringAsFixed(1)}km/h'),
      ];
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryScreen(
            workoutId: workoutId,
            durationSeconds: _durationSeconds,
            type: WorkoutTypes.cardio,
            exercises: const [],
            prs: prs,
            activityDetails: details,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save. Please try again.')));
      }
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    final accent = AppColors.accentContainer(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: KiStyles.body(color: AppColors.hintText(context)),
      filled: true,
      fillColor: AppColors.inputFill(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border(context), width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);
    final cardioColor = WorkoutTypes.color(WorkoutTypes.cardio, context);

    bool hasData() =>
        _activityController.text.trim().isNotEmpty ||
        _distanceController.text.trim().isNotEmpty ||
        _avgSpeedController.text.trim().isNotEmpty ||
        _hoursController.text.trim().isNotEmpty ||
        _minutesController.text.trim().isNotEmpty ||
        _notesController.text.trim().isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!hasData()) { Navigator.pop(context); return; }
        final discard = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: AppColors.cardBg(context),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Discard session?',
                    style: KiStyles.headlineMd(color: AppColors.textPrimary(ctx))),
                const SizedBox(height: 8),
                Text('Your entered data will be lost.',
                    style: KiStyles.body(color: AppColors.textSecondary(ctx))),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error(ctx),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Discard', style: KiStyles.bodySemibold(color: Colors.white)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Keep editing',
                      style: KiStyles.body(color: AppColors.textSecondary(ctx))),
                ),
              ],
            ),
          ),
        );
        if (discard == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GymlogWordmark(),
            const SizedBox(width: 10),
            Text(
              WorkoutTypes.label(WorkoutTypes.cardio).toUpperCase(),
              style: KiStyles.label(color: AppColors.textTertiary(context)),
            ),
          ],
        ),
        actions: [
          if (_canSave)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _save,
                style: TextButton.styleFrom(
                  backgroundColor: accentContainer,
                  foregroundColor: AppColors.primaryBtnFg(context),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('SAVE',
                    style: KiStyles.label(color: AppColors.primaryBtnFg(context))),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date selector
            Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
            Semantics(
              label: 'Workout date: ${_workoutDate.day}/${_workoutDate.month}/${_workoutDate.year}. Tap to change.',
              button: true,
              child: GestureDetector(
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14, color: textTertiary),
                    const SizedBox(width: 10),
                    Text(
                      '${_workoutDate.day}/${_workoutDate.month}/${_workoutDate.year}',
                      style: KiStyles.bodySemibold(color: textPrimary),
                    ),
                    const Spacer(),
                    Icon(Icons.edit_outlined, size: 14, color: textTertiary),
                  ],
                ),
              ),
            )),
            Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),

            const SizedBox(height: 20),

            Text('ACTIVITY', style: KiStyles.label(color: textTertiary)),
            const SizedBox(height: 8),
            TextField(
              controller: _activityController,
              onChanged: (_) => setState(() {}),
              style: KiStyles.bodySemibold(color: textPrimary),
              decoration: _fieldDecoration('e.g. Running'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions
                  .map((s) => Semantics(
                        label: s,
                        button: true,
                        child: GestureDetector(
                        onTap: () {
                          _activityController.text = s;
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _activityController.text == s
                                ? cardioColor.withValues(alpha: 0.15)
                                : AppColors.inputFill(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _activityController.text == s
                                  ? cardioColor
                                  : AppColors.border(context),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            s,
                            style: KiStyles.labelSm(
                              color: _activityController.text == s
                                  ? cardioColor
                                  : textTertiary,
                            ),
                          ),
                        ),
                      )))
                  .toList(),
            ),

            const SizedBox(height: 24),

            Text('DURATION', style: KiStyles.label(color: textTertiary)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _hoursController,
                  keyboardType: TextInputType.number,
                  style: KiStyles.bodySemibold(color: textPrimary),
                  decoration: _fieldDecoration('Hours'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  style: KiStyles.bodySemibold(color: textPrimary),
                  decoration: _fieldDecoration('Minutes'),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            Text('STATS', style: KiStyles.label(color: textTertiary)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _distanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: KiStyles.bodySemibold(color: textPrimary),
                  decoration: _fieldDecoration('Distance (km)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _avgSpeedController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: KiStyles.bodySemibold(color: textPrimary),
                  decoration: _fieldDecoration('Avg speed (km/h)'),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            Text('NOTES', style: KiStyles.label(color: textTertiary)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: KiStyles.body(color: textPrimary),
              decoration: _fieldDecoration('How did it go? (optional)')
                  .copyWith(
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    ));
  }
}
