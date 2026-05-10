import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/workout_detail_screen.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/utils/transitions.dart';
import 'package:gymlog/widgets/gymlog_wordmark.dart';

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
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);
    final cardBorder = AppColors.border(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const GymlogWordmark(),
            const SizedBox(width: 10),
            Text(
              widget.monthLabel.toUpperCase(),
              style: KiStyles.label(color: textTertiary),
            ),
          ],
        ),
      ),
      body: _workouts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center_outlined,
                      size: 40, color: accentContainer),
                  const SizedBox(height: 16),
                  Text('No workouts this month',
                      style: KiStyles.headlineMd(color: textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                    'No workouts logged this month',
                    style: KiStyles.label(color: textTertiary),
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
                final displayDate =
                    _formatDisplayDate(w['date'] as String);
                final type =
                    w['type'] as String? ?? WorkoutTypes.weighted;
                final typeColor = WorkoutTypes.color(type, context);

                return Column(
                  children: [
                  Divider(height: 1, thickness: 0.5, color: cardBorder),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final deleted = await Navigator.push<bool>(
                            context,
                            fadeSlideRoute(WorkoutDetailScreen(
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
                            Icon(WorkoutTypes.icon(type),
                                size: 22, color: typeColor),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayDate,
                                    style:
                                        KiStyles.bodySemibold(color: textPrimary),
                                  ),
                                  if (dur.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(Icons.timer_outlined,
                                            size: 12, color: textTertiary),
                                        const SizedBox(width: 4),
                                        Text(dur,
                                            style: KiStyles.labelSm(
                                                color: textTertiary)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: textTertiary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ],
                );
              },
            ),
    );
  }
}
