import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/workout_types.dart';

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
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0min';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    if (m > 0) return '${m}min';
    return '<1min';
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All-Time Stats',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Color(0xFF111111),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Your complete training overview',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final stats = _stats!;
    final totalWorkouts = stats['total_workouts'] as int;

    if (totalWorkouts == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  size: 34, color: Color(0xFFFFD700)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No workouts yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Log your first workout to see stats',
              style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
          ],
        ),
      );
    }

    final totalSeconds = stats['total_seconds'] as int;
    final topExercises = stats['top_exercises'] as List<String>;
    final typeBreakdown = stats['type_breakdown'] as Map<String, int>;
    final longestStreak = stats['longest_streak'] as int;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── Main stats grid ──
        Row(children: [
          Expanded(
              child: _BigStatCard(
            icon: Icons.fitness_center_rounded,
            value: '$totalWorkouts',
            label: 'Total Workouts',
            accentColor: const Color(0xFFFFD700),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: _BigStatCard(
            icon: Icons.local_fire_department_rounded,
            value: '$longestStreak',
            label: 'Best Streak',
            suffix: longestStreak == 1 ? 'day' : 'days',
            accentColor: const Color(0xFFFF6B35),
          )),
        ]),
        const SizedBox(height: 12),
        _BigStatCard(
          icon: Icons.timer_outlined,
          value: _formatDuration(totalSeconds),
          label: 'Total Time',
          accentColor: const Color(0xFF2196F3),
        ),

        if (topExercises.isNotEmpty) ...[
          const SizedBox(height: 12),
          // ── Top exercises ──
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Most Logged Exercises',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...topExercises.asMap().entries.map((e) {
                  final medals = ['🥇', '🥈', '🥉'];
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: e.key < topExercises.length - 1 ? 10 : 0),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700)
                              .withValues(alpha: 0.15 - e.key * 0.03),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            medals[e.key],
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ]),
                  );
                }),
              ],
            ),
          ),
        ],

        if (typeBreakdown.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Workout Types',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Column(
              children: WorkoutTypes.all.where((t) {
                final count = typeBreakdown[t] ?? 0;
                return count > 0;
              }).map((type) {
                final count = typeBreakdown[type] ?? 0;
                final pct = totalWorkouts > 0 ? count / totalWorkouts : 0.0;
                final typeColor = WorkoutTypes.color(type);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    children: [
                      Row(children: [
                        Icon(WorkoutTypes.icon(type),
                            size: 16, color: typeColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            WorkoutTypes.label(type),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ),
                        Text(
                          '$count workout${count != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888888)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: typeColor.withValues(alpha: 0.12),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(typeColor),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _BigStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? suffix;
  final Color accentColor;

  const _BigStatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.suffix,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    suffix!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
