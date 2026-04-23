import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/workout_detail_screen.dart';
import 'package:gymlog/utils/workout_types.dart';

class MonthWorkoutsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> workouts;
  final String monthLabel;
  final int? initialDay;
  const MonthWorkoutsScreen(
      {super.key,
      required this.workouts,
      required this.monthLabel,
      this.initialDay});
  @override
  State<MonthWorkoutsScreen> createState() => _MonthWorkoutsScreenState();
}

class _MonthWorkoutsScreenState extends State<MonthWorkoutsScreen> {
  late List<Map<String, dynamic>> _workouts;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _workouts = List.from(widget.workouts);
    if (widget.initialDay != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToInitialDay());
    }
  }

  void _scrollToInitialDay() {
    final day = widget.initialDay!;
    final idx = _workouts.indexWhere((w) {
      final dayStr = (w['date'] as String).trim().split('/').first;
      return int.tryParse(dayStr) == day;
    });
    if (idx > 0 && _scrollController.hasClients) {
      // 16px top padding + each card is ~88px (taller cards now)
      final offset = (16.0 + idx * 88.0)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Parse just the day number from the stored date string "d/m/yyyy  HH:mm"
  String _formatDisplayDate(String raw) {
    try {
      final datePart = raw.trim().split(RegExp(r'\s+')).first;
      final parts = datePart.split('/');
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      const monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final time = raw.trim().split(RegExp(r'\s+')).length > 1
          ? raw.trim().split(RegExp(r'\s+'))[1]
          : '';
      if (time.isNotEmpty && time != '00:00') {
        return '${monthNames[month - 1]} $day  ·  $time';
      }
      return '${monthNames[month - 1]} $day';
    } catch (_) {
      return raw;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.monthLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF111111),
                letterSpacing: -0.4,
              ),
            ),
            Text(
              '${_workouts.length} workout${_workouts.length != 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: _workouts.isEmpty
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
                    'No workouts this month',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: _workouts.length,
              itemBuilder: (ctx, i) {
                final w = _workouts[i];
                final dur = DBHelper.formatDuration(
                    w['duration_seconds'] as int? ?? 0);
                final displayDate = _formatDisplayDate(w['date'] as String);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final type = w['type'] as String? ?? WorkoutTypes.weighted;
                        final deleted = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => WorkoutDetailScreen(
                                    workoutId: w['id'],
                                    date: w['date'],
                                    durationSeconds:
                                        w['duration_seconds'] as int? ?? 0,
                                    type: type)));
                        if (deleted == true) {
                          setState(() => _workouts.removeAt(i));
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            // Type-colored icon
                            Builder(builder: (_) {
                              final type = w['type'] as String? ?? WorkoutTypes.weighted;
                              return Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: WorkoutTypes.color(type),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(WorkoutTypes.icon(type),
                                    size: 20, color: Colors.white),
                              );
                            }),
                            const SizedBox(width: 14),
                            // Date + duration
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayDate,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                  if (dur.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.timer_outlined,
                                            size: 12,
                                            color: Color(0xFFAAAAAA)),
                                        const SizedBox(width: 4),
                                        Text(
                                          dur,
                                          style: const TextStyle(
                                            color: Color(0xFFAAAAAA),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Color(0xFFCCCCCC), size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
