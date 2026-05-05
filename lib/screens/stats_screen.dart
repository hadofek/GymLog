import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/muscle_map_screen.dart';
import 'package:gymlog/utils/workout_types.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';

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

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0min';
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
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);

    final totalWorkouts =
        _stats != null ? _stats!['total_workouts'] as int : 0;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
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
                  if (!_loading && totalWorkouts > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$totalWorkouts',
                          style: KiStyles.headlineMd(color: textPrimary),
                        ),
                        Text('sessions',
                            style: KiStyles.labelSm(color: textTertiary)),
                      ],
                    )
                  else
                    Text('ALL-TIME',
                        style: KiStyles.label(color: textTertiary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading ? _buildSkeleton(context) : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    const skeletonColor = Color(0xFF111111);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        _SkeletonBox(height: 72, radius: 14, color: skeletonColor),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _SkeletonBox(height: 72, radius: 14, color: skeletonColor)),
          const SizedBox(width: 10),
          Expanded(
              child: _SkeletonBox(height: 72, radius: 14, color: skeletonColor)),
        ]),
        const SizedBox(height: 10),
        _SkeletonBox(height: 120, radius: 14, color: skeletonColor),
        const SizedBox(height: 10),
        _SkeletonBox(height: 140, radius: 14, color: skeletonColor),
      ],
    );
  }

  Widget _buildBody() {
    final stats = _stats!;
    final totalWorkouts = stats['total_workouts'] as int;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);
    final isDark = AppColors.isDark(context);

    if (totalWorkouts == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No data yet.',
                style: KiStyles.headlineLg(color: textPrimary)),
            const SizedBox(height: 6),
            Text('Log your first workout and stats will appear here.',
                style: KiStyles.body(color: textTertiary)),
          ],
        ),
      );
    }

    final totalSeconds = stats['total_seconds'] as int;
    final topExercises = stats['top_exercises'] as List<String>;
    final typeBreakdown = stats['type_breakdown'] as Map<String, int>;
    final longestStreak = stats['longest_streak'] as int;
    final totalDistanceKm = stats['total_distance_km'] as double? ?? 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [

        // ── Stats row: streak + total time ──
        Row(children: [
          Expanded(
            child: _KoBentoCard(
              isDark: isDark,
              radius: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BEST STREAK',
                      style: KiStyles.label(color: textTertiary)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$longestStreak',
                          style: KiStyles.headlineLg(color: textPrimary)),
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 4, bottom: 3),
                        child: Text(
                          longestStreak == 1 ? 'day' : 'days',
                          style: KiStyles.label(color: textTertiary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _KoBentoCard(
              isDark: isDark,
              radius: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL TIME',
                      style: KiStyles.label(color: textTertiary)),
                  const SizedBox(height: 8),
                  Text(_formatDuration(totalSeconds),
                      style: KiStyles.headlineLg(color: textPrimary)),
                ],
              ),
            ),
          ),
        ]),

        // ── Distance card (cardio users only) ──
        if (totalDistanceKm > 0) ...[
          const SizedBox(height: 10),
          _KoBentoCard(
            isDark: isDark,
            radius: 14,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL DISTANCE',
                          style: KiStyles.label(color: textTertiary)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            totalDistanceKm >= 1000
                                ? '${(totalDistanceKm / 1000).toStringAsFixed(1)}k'
                                : totalDistanceKm % 1 == 0
                                    ? '${totalDistanceKm.toInt()}'
                                    : totalDistanceKm.toStringAsFixed(1),
                            style: KiStyles.headlineLg(color: textPrimary),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 3),
                            child: Text('km',
                                style: KiStyles.label(color: textTertiary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.straighten_rounded,
                    color: textTertiary.withValues(alpha: 0.4), size: 32),
              ],
            ),
          ),
        ],

        // ── Top exercises podium ──
        if (topExercises.isNotEmpty) ...[
          const SizedBox(height: 10),
          _KoBentoCard(
            isDark: isDark,
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOP EXERCISES',
                    style: KiStyles.label(color: textTertiary)),
                const SizedBox(height: 16),

                // Podium row (center=1st, left=2nd, right=3rd)
                if (topExercises.length >= 2)
                  _PodiumRow(
                    exercises: topExercises,
                    accentContainer: accentContainer,
                    textPrimary: textPrimary,
                    textTertiary: textTertiary,
                    isDark: isDark,
                  )
                else
                  Row(
                    children: topExercises.asMap().entries.map((e) {
                      final colors = [
                        accentContainer,
                        textSecondary,
                        textTertiary,
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Text('${e.key + 1}.',
                              style: KiStyles.label(
                                  color: colors[e.key.clamp(0, 2)])),
                          const SizedBox(width: 8),
                          Text(e.value,
                              style:
                                  KiStyles.bodySemibold(color: textPrimary)),
                        ]),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],

        // ── Workout type distribution ──
        if (typeBreakdown.isNotEmpty) ...[
          const SizedBox(height: 10),
          _KoBentoCard(
            isDark: isDark,
            radius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TRAINING SPLIT',
                    style: KiStyles.label(color: textTertiary)),
                const SizedBox(height: 16),
                ...WorkoutTypes.all.where((t) => (typeBreakdown[t] ?? 0) > 0).map((type) {
                  final count = typeBreakdown[type] ?? 0;
                  final pct =
                      totalWorkouts > 0 ? count / totalWorkouts : 0.0;
                  final typeColor = WorkoutTypes.color(type, context);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      children: [
                        Row(children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: typeColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              WorkoutTypes.label(type),
                              style: KiStyles.bodySemibold(
                                  color: textPrimary),
                            ),
                          ),
                          Text(
                            '${(pct * 100).round()}%',
                            style: KiStyles.label(color: textSecondary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$count',
                            style: KiStyles.label(color: textTertiary),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        // Flat-end progress bar (KO spec)
                        SizedBox(
                          height: 4,
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.12),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: pct,
                                child: Container(color: typeColor),
                              ),
                            ],
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

        // ── Muscle map entry ──
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MuscleMapScreen())),
          child: _KoBentoCard(
            isDark: isDark,
            radius: 14,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MUSCLE MAP',
                          style: KiStyles.label(color: textTertiary)),
                      const SizedBox(height: 8),
                      Text('See which muscles\nyou\'ve been hitting',
                          style: KiStyles.bodySemibold(color: textPrimary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: textTertiary, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Podium widget ──────────────────────────────────────────────────────────────
class _PodiumRow extends StatelessWidget {
  final List<String> exercises;
  final Color accentContainer;
  final Color textPrimary;
  final Color textTertiary;
  final bool isDark;

  const _PodiumRow({
    required this.exercises,
    required this.accentContainer,
    required this.textPrimary,
    required this.textTertiary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Order: 2nd (left), 1st (center-raised), 3rd (right)
    final order = [1, 0, exercises.length > 2 ? 2 : -1];
    final heights = [56.0, 72.0, 44.0];
    final colors = [
      AppColors.textSecondary(context),
      accentContainer,
      AppColors.textTertiary(context),
    ];
    final labels = ['2ND', '1ST', '3RD'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (col) {
        final idx = order[col];
        if (idx < 0 || idx >= exercises.length) {
          return const Expanded(child: SizedBox());
        }
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: col < 2 ? 8 : 0),
            child: Column(
              children: [
                Text(
                  exercises[idx],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KiStyles.labelSm(color: textPrimary),
                ),
                const SizedBox(height: 6),
                Container(
                  height: heights[col],
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colors[col], width: 1),
                    ),
                  ),
                  child: Center(
                    child: Text(labels[col],
                        style: KiStyles.label(color: colors[col])),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Flat section card (no box) ────────────────────────────────────────────────
class _KoBentoCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final double radius;

  const _KoBentoCard({
    required this.child,
    required this.isDark,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }
}

// ── Skeleton placeholder box ───────────────────────────────────────────────────
class _SkeletonBox extends StatelessWidget {
  final double height;
  final double radius;
  final Color color;

  const _SkeletonBox({
    required this.height,
    required this.color,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
