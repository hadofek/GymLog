import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/body_svg_paths.dart';
import 'package:gymlog/utils/ki_styles.dart';

enum _Period { daily, weekly, monthly, yearly, allTime }

extension _PeriodExt on _Period {
  String get label {
    switch (this) {
      case _Period.daily:
        return 'Today';
      case _Period.weekly:
        return 'Week';
      case _Period.monthly:
        return 'Month';
      case _Period.yearly:
        return 'Year';
      case _Period.allTime:
        return 'All Time';
    }
  }
}

const _groupColors = <String, Color>{
  'chest': Color(0xFF5B9BD5),
  'back': Color(0xFF9068C4),
  'shoulders': Color(0xFF38B2C8),
  'biceps': Color(0xFF48A870),
  'triceps': Color(0xFFCC5555),
  'core': Color(0xFFCBA038),
  'traps': Color(0xFF6088C8),
  'quads': Color(0xFF3EA898),
  'hamstrings': Color(0xFFCC5878),
  'glutes': Color(0xFFCC7A48),
  'calves': Color(0xFF6EA838),
  'forearms': Color(0xFF906050),
};

const _groupDisplayNames = <String, String>{
  'chest': 'Chest',
  'back': 'Back',
  'shoulders': 'Shoulders',
  'biceps': 'Biceps',
  'triceps': 'Triceps',
  'core': 'Core',
  'traps': 'Traps',
  'quads': 'Quads',
  'hamstrings': 'Hamstrings',
  'glutes': 'Glutes',
  'calves': 'Calves',
  'forearms': 'Forearms',
};

class MuscleMapScreen extends StatefulWidget {
  const MuscleMapScreen({super.key});

  @override
  State<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends State<MuscleMapScreen> {
  _Period _period = _Period.allTime;
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (mounted) setState(() => _loading = true);
    final since = _periodSince(_period);
    final raw = await DBHelper.getMuscleGroupCounts(since: since);
    final normalized = <String, int>{};
    for (final e in raw.entries) {
      final key = _normalizeGroup(e.key);
      normalized[key] = (normalized[key] ?? 0) + e.value;
    }
    if (mounted) {
      setState(() {
        _counts = normalized;
        _loading = false;
      });
    }
  }

  DateTime? _periodSince(_Period p) {
    final now = DateTime.now();
    switch (p) {
      case _Period.daily:
        return DateTime(now.year, now.month, now.day);
      case _Period.weekly:
        return now.subtract(const Duration(days: 7));
      case _Period.monthly:
        return now.subtract(const Duration(days: 30));
      case _Period.yearly:
        return now.subtract(const Duration(days: 365));
      case _Period.allTime:
        return null;
    }
  }

  String _normalizeGroup(String name) {
    final s = name.toLowerCase().trim();
    if (s.contains('chest') || s.contains('pec')) return 'chest';
    if (s.contains('back') || s.contains('lat')) return 'back';
    if (s.contains('shoulder') || s.contains('delt')) return 'shoulders';
    if (s.contains('bicep')) return 'biceps';
    if (s.contains('tricep')) return 'triceps';
    if (s.contains('core') || s.contains('abs') || s.contains('abdom')) {
      return 'core';
    }
    if (s.contains('quad') || s == 'legs') return 'quads';
    if (s.contains('hamstring')) return 'hamstrings';
    if (s.contains('glute') || s.contains('butt') || s.contains('hip')) {
      return 'glutes';
    }
    if (s.contains('calf') || s.contains('calves')) return 'calves';
    if (s.contains('trap')) return 'traps';
    if (s.contains('forearm')) return 'forearms';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);
    final border = AppColors.border(context);
    final isDark = AppColors.isDark(context);

    final maxCount =
        _counts.values.isEmpty ? 0 : _counts.values.reduce(math.max);
    final sortedGroups = _counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final svgString = buildBodySvg(
      counts: _counts,
      maxCount: maxCount,
      isDark: isDark,
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: textPrimary),
                  ),
                  const SizedBox(width: 16),
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
                  Text('MUSCLE MAP',
                      style: KiStyles.label(color: textTertiary)),
                ],
              ),
            ),
            // Period filter
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _Period.values.map((p) {
                    final on = p == _period;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _period = p);
                        _loadCounts();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: on ? accentContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: on ? accentContainer : border,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: on ? Colors.white : textTertiary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // Body + list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // SVG muscle map
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1460 / 1360,
                      child: SvgPicture.string(
                        svgString,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 12,
                            color: textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Only exercises with a muscle group assigned appear on the map',
                            style: TextStyle(
                              fontSize: 11,
                              color: textTertiary.withValues(alpha: 0.5),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Loading / empty / breakdown
                  if (_loading) ...[
                    const SizedBox(height: 32),
                    Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accentContainer,
                        ),
                      ),
                    ),
                  ] else if (sortedGroups.isEmpty) ...[
                    const SizedBox(height: 32),
                    Text('No muscle data yet.',
                        style: KiStyles.headlineMd(color: textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      'Open an exercise, set its muscle group, then log it — the map will light up.',
                      style: KiStyles.body(color: textTertiary),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('BREAKDOWN',
                            style: KiStyles.label(color: textTertiary)),
                        const Spacer(),
                        Text(
                          '${sortedGroups.fold<int>(0, (s, e) => s + e.value)} sessions total',
                          style: KiStyles.labelSm(color: textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...sortedGroups.map((entry) {
                      final group = entry.key;
                      final count = entry.value;
                      final color =
                          _groupColors[group] ?? const Color(0xFF888888);
                      final displayName = _groupDisplayNames[group] ??
                          (group.isNotEmpty
                              ? group[0].toUpperCase() + group.substring(1)
                              : group);
                      final pct = maxCount > 0 ? count / maxCount : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          children: [
                            Row(children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? color
                                      : color.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: KiStyles.bodySemibold(
                                      color: textPrimary),
                                ),
                              ),
                              Text(
                                '$count ${count == 1 ? "session" : "sessions"}',
                                style:
                                    KiStyles.labelSm(color: textSecondary),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 3,
                              child: Stack(children: [
                                Container(
                                  width: double.infinity,
                                  color: color.withValues(alpha: 0.12),
                                ),
                                FractionallySizedBox(
                                  widthFactor: pct,
                                  child: Container(color: color),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
