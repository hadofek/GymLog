import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<String?> _showProgressPhotoDialog() async {
    if (!mounted) return null;
    final cardBg = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final borderColor = AppColors.border(context);
    final accentContainer = AppColors.accentContainer(context);

    return showModalBottomSheet<String?>(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Add a progress photo?',
                    style: KiStyles.headlineMd(color: textPrimary)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Document your progress with a photo',
                    style: KiStyles.label(color: textTertiary)),
              ),
              const SizedBox(height: 20),
              ListTile(
                onTap: () => Navigator.pop(ctx, 'camera'),
                leading: Icon(Icons.camera_alt_outlined,
                    color: accentContainer, size: 22),
                title: Text('Take Photo',
                    style: KiStyles.bodySemibold(color: textPrimary)),
              ),
              ListTile(
                onTap: () => Navigator.pop(ctx, 'gallery'),
                leading: Icon(Icons.photo_library_outlined,
                    color: accentContainer, size: 22),
                title: Text('Choose from Gallery',
                    style: KiStyles.bodySemibold(color: textPrimary)),
              ),
              ListTile(
                onTap: () => Navigator.pop(ctx, null),
                leading: Icon(Icons.close, color: textTertiary, size: 22),
                title: Text('Skip',
                    style: KiStyles.bodySemibold(color: textTertiary)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _pickAndCopyPhoto(String source) async {
    final picker = ImagePicker();
    final XFile? picked = source == 'camera'
        ? await picker.pickImage(source: ImageSource.camera, imageQuality: 85)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/progress_photos');
    if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
    final dest =
        '${photosDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(dest);
    return dest;
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

      final workoutId = await DBHelper.insertWorkout(
        dateStr,
        _durationSeconds,
        type: WorkoutTypes.flexibility,
        notes:
            '${_activityController.text.trim()}\n${_notesController.text.trim()}'
                .trim(),
      );

      if (!mounted) return;
      final source = await _showProgressPhotoDialog();
      if (source != null && mounted) {
        final path = await _pickAndCopyPhoto(source);
        if (path != null) {
          await DBHelper.updateWorkoutPhoto(workoutId, path);
        }
      }

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
    final flexColor = WorkoutTypes.color(WorkoutTypes.flexibility, context);

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
            Text(
              WorkoutTypes.label(WorkoutTypes.flexibility).toUpperCase(),
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
                  foregroundColor: const Color(0xFF000000),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('SAVE',
                    style: KiStyles.label(color: const Color(0xFF000000))),
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
            GestureDetector(
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
            ),
            Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),

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
