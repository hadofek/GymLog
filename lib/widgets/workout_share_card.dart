import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';

class WorkoutShareCard extends StatelessWidget {
  final String date;
  final int durationSeconds;
  final int exerciseCount;
  final int totalSets;
  final int totalReps;
  final double totalWeight;

  const WorkoutShareCard({
    super.key,
    required this.date,
    required this.durationSeconds,
    required this.exerciseCount,
    required this.totalSets,
    required this.totalReps,
    required this.totalWeight,
  });

  @override
  Widget build(BuildContext context) {
    final dur = DBHelper.formatDuration(durationSeconds);
    final weightStr = totalWeight == totalWeight.truncateToDouble()
        ? '${totalWeight.toInt()}kg'
        : '${totalWeight.toStringAsFixed(1)}kg';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fitness_center,
                    size: 18, color: Colors.black),
              ),
              const SizedBox(width: 10),
              const Text(
                'GYMLOG',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Workout complete label
          Text(
            'WORKOUT COMPLETE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),

          // Duration — big hero number
          if (dur.isNotEmpty)
            Text(
              dur,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
                height: 1,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            date.split('  ').first,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 28),

          // Divider
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 24),

          // Stats grid
          Row(
            children: [
              _ShareStat(value: '$exerciseCount', label: 'Exercises'),
              _ShareStatDivider(),
              _ShareStat(value: '$totalSets', label: 'Sets'),
              _ShareStatDivider(),
              _ShareStat(value: '$totalReps', label: 'Reps'),
              _ShareStatDivider(),
              _ShareStat(value: weightStr, label: 'Volume'),
            ],
          ),

          const SizedBox(height: 24),

          // Gold accent bar
          Container(
            height: 3,
            width: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStat extends StatelessWidget {
  final String value;
  final String label;
  const _ShareStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}
