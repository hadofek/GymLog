import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/exercise_history_screen.dart';
import 'package:gymlog/screens/personal_records_screen.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/widgets/tip_overlay.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await DBHelper.getAllTimeStats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  String _fmtDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '<1m';
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);
    final border = AppColors.border(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
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
                  Text('STATS', style: KiStyles.label(color: textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? _buildSkeleton(context)
                  : _buildBody(textPrimary, textSecondary, textTertiary,
                      accentContainer, border),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final c = AppColors.cardBg(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        _Bone(height: 48, color: c),
        const SizedBox(height: 1),
        _Bone(height: 120, color: c),
        const SizedBox(height: 1),
        _Bone(height: 140, color: c),
        const SizedBox(height: 1),
        _Bone(height: 100, color: c),
      ],
    );
  }

  Widget _buildBody(
    Color textPrimary,
    Color textSecondary,
    Color textTertiary,
    Color accentContainer,
    Color border,
  ) {
    final stats = _stats!;
    final totalWorkouts = stats['total_workouts'] as int;

    if (totalWorkouts == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nothing yet.', style: KiStyles.headlineLg(color: textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Complete your first workout and your full stats — training split, streaks, top exercises — will unlock here.',
              style: KiStyles.body(color: textTertiary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _StatPreview(label: 'WORKOUTS', icon: Icons.fitness_center_rounded, color: accentContainer),
                const SizedBox(width: 16),
                _StatPreview(label: 'STREAK', icon: Icons.local_fire_department_rounded, color: accentContainer),
                const SizedBox(width: 16),
                _StatPreview(label: 'TIME', icon: Icons.timer_outlined, color: accentContainer),
              ],
            ),
          ],
        ),
      );
    }

    final totalSeconds = stats['total_seconds'] as int;
    final topExercises = stats['top_exercises'] as List<String>;
    final typeBreakdown = stats['type_breakdown'] as Map<String, int>;
    final longestStreak = stats['longest_streak'] as int;
    final totalDistanceKm = stats['total_distance_km'] as double? ?? 0.0;

    final activeTypes = WorkoutTypes.all
        .where((t) => (typeBreakdown[t] ?? 0) > 0)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Stat strip ──
          Divider(height: 1, thickness: 0.5, color: border),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MicroStat(
                    value: '$totalWorkouts',
                    label: 'WORKOUTS',
                    valueColor: textPrimary,
                    labelColor: textTertiary,
                  ),
                  _Divider(color: border),
                  _MicroStat(
                    value: '$longestStreak',
                    label: 'BEST STREAK',
                    valueColor: textPrimary,
                    labelColor: textTertiary,
                  ),
                  _Divider(color: border),
                  _MicroStat(
                    value: _fmtDuration(totalSeconds),
                    label: 'TOTAL TIME',
                    valueColor: textPrimary,
                    labelColor: textTertiary,
                  ),
                  if (totalDistanceKm > 0) ...[
                    _Divider(color: border),
                    _MicroStat(
                      value: totalDistanceKm >= 1000
                          ? '${(totalDistanceKm / 1000).toStringAsFixed(1)}k km'
                          : totalDistanceKm % 1 == 0
                              ? '${totalDistanceKm.toInt()} km'
                              : '${totalDistanceKm.toStringAsFixed(1)} km',
                      label: 'DISTANCE',
                      valueColor: textPrimary,
                      labelColor: textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Training split ──
          if (activeTypes.isNotEmpty) ...[
            Divider(height: 1, thickness: 0.5, color: border),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRAINING SPLIT',
                      style: KiStyles.label(color: textTertiary)),
                  const SizedBox(height: 14),

                  // Stacked color bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: activeTypes.map((type) {
                          final count = typeBreakdown[type]!;
                          return Expanded(
                            flex: count,
                            child: Container(
                              color: WorkoutTypes.color(type, context),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Legend rows
                  ...activeTypes.map((type) {
                    final count = typeBreakdown[type]!;
                    final pct = (count / totalWorkouts * 100).round();
                    final typeColor = WorkoutTypes.color(type, context);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                                color: typeColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(WorkoutTypes.label(type),
                                style: KiStyles.body(color: textPrimary)),
                          ),
                          Text('$pct%',
                              style: KiStyles.bodySemibold(color: textPrimary)),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.right,
                              style: KiStyles.label(color: textTertiary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // ── Top exercises ──
          if (topExercises.isNotEmpty) ...[
            Divider(height: 1, thickness: 0.5, color: border),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TipOverlay(
                    tipKey: 'tip_stats_exercises',
                    tipTitle: 'Top Exercises',
                    tipBody: 'Tap any exercise to see your full progress chart — weights, reps, and personal bests over time.',
                    direction: TipDirection.below,
                    child: Text('TOP EXERCISES',
                        style: KiStyles.label(color: textTertiary)),
                  ),
                  const SizedBox(height: 4),
                  ...topExercises.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final name = entry.value;
                    final isFirst = rank == 1;
                    return Column(
                      children: [
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExerciseHistoryScreen(exerciseName: name),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    rank.toString().padLeft(2, '0'),
                                    style: KiStyles.labelSm(
                                        color: isFirst
                                            ? accentContainer
                                            : textTertiary),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: isFirst
                                        ? KiStyles.bodySemibold(color: textPrimary)
                                        : KiStyles.body(color: textPrimary),
                                  ),
                                ),
                                if (isFirst)
                                  Text('★',
                                      style: TextStyle(
                                          color: accentContainer, fontSize: 11)),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right_rounded,
                                    size: 14, color: textTertiary),
                              ],
                            ),
                          ),
                        ),
                        if (rank < topExercises.length)
                          Divider(
                              height: 1,
                              thickness: 0.5,
                              color: AppColors.divider(context)),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],

          // ── Personal Records ──
          Divider(height: 1, thickness: 0.5, color: border),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PersonalRecordsScreen())),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PERSONAL RECORDS',
                            style: KiStyles.label(color: textTertiary)),
                        const SizedBox(height: 4),
                        Text('All-time bests for every exercise',
                            style: KiStyles.body(color: textPrimary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: textTertiary, size: 20),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: border),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _MicroStat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final Color labelColor;

  const _MicroStat({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: KiStyles.headlineMd(color: valueColor)),
        const SizedBox(height: 1),
        Text(label, style: KiStyles.labelSm(color: labelColor)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(width: 1, height: 30, color: color),
    );
  }
}

class _Bone extends StatelessWidget {
  final double height;
  final Color color;
  const _Bone({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
        width: double.infinity, height: height, color: color);
  }
}

/// Ghost stat tile for the empty state — shows what will unlock.
class _StatPreview extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _StatPreview({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color.withValues(alpha: 0.3)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: 0.3),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
