import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/workout_types.dart';

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

  static const _accentColor = Color(0xFF4CAF50);

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
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      final hour = isToday ? now.hour : 0;
      final minute = isToday ? now.minute : 0;
      final dateStr =
          '${date.day}/${date.month}/${date.year}  ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      final distance = double.tryParse(_distanceController.text) ?? 0.0;
      final avgSpeed = double.tryParse(_avgSpeedController.text) ?? 0.0;

      // Encode avgSpeed into notes since we don't have a dedicated column yet
      final notesParts = <String>[
        _activityController.text.trim(),
        if (avgSpeed > 0) 'avg_speed:$avgSpeed',
        if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
      ];

      await DBHelper.insertWorkout(
        dateStr,
        _durationSeconds,
        type: WorkoutTypes.cardio,
        distanceKm: distance,
        notes: notesParts.join('\n'),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accentColor, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    final bool isToday = () {
      final now = DateTime.now();
      return _workoutDate.year == now.year &&
          _workoutDate.month == now.month &&
          _workoutDate.day == now.day;
    }();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF111111)),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _pickDate,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isToday
                    ? 'Cardio Workout'
                    : '${_workoutDate.day}/${_workoutDate.month}/${_workoutDate.year}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF111111),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_calendar_outlined,
                  size: 15, color: Color(0xFFAAAAAA)),
            ],
          ),
        ),
        actions: [
          if (_canSave)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _save,
                style: TextButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity
            const Text('Activity', style: _labelStyle),
            const SizedBox(height: 8),
            TextField(
              controller: _activityController,
              onChanged: (_) => setState(() {}),
              style: _inputTextStyle,
              decoration: _fieldDecoration('e.g. Running'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((s) => GestureDetector(
                onTap: () { _activityController.text = s; setState(() {}); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _activityController.text == s
                        ? _accentColor.withValues(alpha: 0.15)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _activityController.text == s
                          ? _accentColor
                          : const Color(0xFFEEEEEE),
                      width: 1.5,
                    ),
                  ),
                  child: Text(s,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _activityController.text == s
                          ? _accentColor
                          : const Color(0xFF666666),
                    ),
                  ),
                ),
              )).toList(),
            ),

            const SizedBox(height: 24),

            // Duration — hours + minutes
            const Text('Duration', style: _labelStyle),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _hoursController,
                  keyboardType: TextInputType.number,
                  style: _inputTextStyle,
                  decoration: _fieldDecoration('Hours'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  style: _inputTextStyle,
                  decoration: _fieldDecoration('Minutes'),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            // Distance + Avg speed
            const Text('Stats', style: _labelStyle),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _distanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: _inputTextStyle,
                  decoration: _fieldDecoration('Distance (km)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _avgSpeedController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: _inputTextStyle,
                  decoration: _fieldDecoration('Avg speed (km/h)'),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            // Notes
            const Text('Notes', style: _labelStyle),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF111111)),
              decoration: _fieldDecoration('How did it go? (optional)').copyWith(
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  static const _labelStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 13,
    color: Color(0xFF666666),
    letterSpacing: 0.3,
  );

  static const _inputTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Color(0xFF111111),
  );
}
