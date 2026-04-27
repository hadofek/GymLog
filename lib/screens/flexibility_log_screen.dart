import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';

class FlexibilityLogScreen extends StatefulWidget {
  final DateTime? initialDate;
  const FlexibilityLogScreen({super.key, this.initialDate});
  @override
  State<FlexibilityLogScreen> createState() => _FlexibilityLogScreenState();
}

class _FlexibilityLogScreenState extends State<FlexibilityLogScreen> {
  final _activityController = TextEditingController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _workoutDate;

  static const _suggestions = [
    'Yoga', 'Stretching', 'Mobility', 'Pilates',
    'Foam Rolling', 'Calisthenics', 'Meditation',
  ];

  @override
  void initState() {
    super.initState();
    _workoutDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _activityController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _durationSeconds {
    final h = int.tryParse(_hoursController.text) ?? 0;
    final m = int.tryParse(_minutesController.text) ?? 0;
    return h * 3600 + m * 60;
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
      await DBHelper.insertWorkout(
        dateStr,
        _durationSeconds,
        type: WorkoutTypes.flexibility,
        notes:
            '${_activityController.text.trim()}\n${_notesController.text.trim()}'
                .trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    final accent = AppColors.accentContainer(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.hintText(context)),
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
    final flexColor = WorkoutTypes.color(WorkoutTypes.flexibility);
    final isDark = AppColors.isDark(context);
    final cardBorder = isDark
        ? const Color(0xFF434654).withValues(alpha: 0.6)
        : const Color(0xFFEEEEEE);

    final bool isToday = () {
      final now = DateTime.now();
      return _workoutDate.year == now.year &&
          _workoutDate.month == now.month &&
          _workoutDate.day == now.day;
    }();

    return Scaffold(
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
            Text(
              'GYMLOG',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 2,
                color: accentContainer,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: flexColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: flexColor.withValues(alpha: 0.4), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(WorkoutTypes.icon(WorkoutTypes.flexibility),
                      size: 11, color: flexColor),
                  const SizedBox(width: 4),
                  Text(
                    WorkoutTypes.label(WorkoutTypes.flexibility).toUpperCase(),
                    style: KiStyles.labelSm(color: flexColor),
                  ),
                ],
              ),
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
                  foregroundColor: const Color(0xFF002469),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('SAVE',
                    style: KiStyles.label(color: const Color(0xFF002469))),
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
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16161E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: textTertiary),
                    const SizedBox(width: 10),
                    Text(
                      isToday
                          ? 'Today'
                          : '${_workoutDate.day}/${_workoutDate.month}/${_workoutDate.year}',
                      style: KiStyles.bodySemibold(color: textPrimary),
                    ),
                    const Spacer(),
                    Icon(Icons.edit_outlined, size: 14, color: textTertiary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text('ACTIVITY', style: KiStyles.label(color: textTertiary)),
            const SizedBox(height: 8),
            TextField(
              controller: _activityController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textPrimary),
              decoration: _fieldDecoration('e.g. Yoga'),
            ),

            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions
                  .map((s) => GestureDetector(
                        onTap: () {
                          _activityController.text = s;
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _activityController.text == s
                                ? flexColor.withValues(alpha: 0.15)
                                : AppColors.inputFill(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _activityController.text == s
                                  ? flexColor
                                  : AppColors.border(context),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            s,
                            style: KiStyles.labelSm(
                              color: _activityController.text == s
                                  ? flexColor
                                  : textTertiary,
                            ),
                          ),
                        ),
                      ))
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
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textPrimary),
                  decoration: _fieldDecoration('Hours'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textPrimary),
                  decoration: _fieldDecoration('Minutes'),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            Text('NOTES', style: KiStyles.label(color: textTertiary)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: textPrimary),
              decoration: _fieldDecoration('How did it go? (optional)')
                  .copyWith(
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
