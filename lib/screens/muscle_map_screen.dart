import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/app_colors.dart';
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

class _Region {
  final String group;
  final double cx, cy, rx, ry;
  const _Region(this.group, this.cx, this.cy, this.rx, this.ry);
}

// Positions as fractions of image dimensions (720×1280).
// Front view occupies left half (x: 0–0.5), back view right half (x: 0.5–1.0).
const _regions = <_Region>[
  // ── Chest (front) ──
  _Region('chest', 0.175, 0.255, 0.082, 0.062),
  _Region('chest', 0.325, 0.255, 0.082, 0.062),
  // ── Shoulders: front delts + rear delts ──
  _Region('shoulders', 0.088, 0.210, 0.052, 0.048),
  _Region('shoulders', 0.412, 0.210, 0.052, 0.048),
  _Region('shoulders', 0.600, 0.210, 0.052, 0.048),
  _Region('shoulders', 0.900, 0.210, 0.052, 0.048),
  // ── Biceps (front) ──
  _Region('biceps', 0.078, 0.325, 0.040, 0.068),
  _Region('biceps', 0.422, 0.325, 0.040, 0.068),
  // ── Triceps (back) ──
  _Region('triceps', 0.578, 0.325, 0.040, 0.068),
  _Region('triceps', 0.922, 0.325, 0.040, 0.068),
  // ── Forearms ──
  _Region('forearms', 0.068, 0.415, 0.035, 0.055),
  _Region('forearms', 0.432, 0.415, 0.035, 0.055),
  // ── Core / Abs (front) ──
  _Region('core', 0.250, 0.405, 0.072, 0.082),
  // ── Traps (back) ──
  _Region('traps', 0.750, 0.205, 0.095, 0.042),
  // ── Lats + lower back ──
  _Region('back', 0.628, 0.325, 0.065, 0.088),
  _Region('back', 0.872, 0.325, 0.065, 0.088),
  _Region('back', 0.750, 0.430, 0.072, 0.040),
  // ── Quads (front) ──
  _Region('quads', 0.193, 0.632, 0.065, 0.095),
  _Region('quads', 0.307, 0.632, 0.065, 0.095),
  // ── Hamstrings (back) ──
  _Region('hamstrings', 0.662, 0.642, 0.060, 0.092),
  _Region('hamstrings', 0.838, 0.642, 0.060, 0.092),
  // ── Glutes (back) ──
  _Region('glutes', 0.688, 0.528, 0.070, 0.055),
  _Region('glutes', 0.812, 0.528, 0.070, 0.055),
  // ── Calves (front + back) ──
  _Region('calves', 0.188, 0.840, 0.040, 0.055),
  _Region('calves', 0.312, 0.840, 0.040, 0.055),
  _Region('calves', 0.662, 0.840, 0.040, 0.055),
  _Region('calves', 0.838, 0.840, 0.040, 0.055),
];

const _groupColors = <String, Color>{
  'chest': Color(0xFF64B5F6),
  'back': Color(0xFFCE93D8),
  'shoulders': Color(0xFF80DEEA),
  'biceps': Color(0xFFA5D6A7),
  'triceps': Color(0xFFEF9A9A),
  'core': Color(0xFFFFCC80),
  'traps': Color(0xFF90CAF9),
  'quads': Color(0xFF80CBC4),
  'hamstrings': Color(0xFFF48FB1),
  'glutes': Color(0xFFFFAB91),
  'calves': Color(0xFFC5E1A5),
  'forearms': Color(0xFFBCAAA4),
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
  ui.Image? _mapImage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMapImage();
    _loadCounts();
  }

  Future<void> _loadMapImage() async {
    final data = await rootBundle.load('assets/images/musclemap.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _mapImage = frame.image);
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

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
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

            // ── Period chips ──
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

            // ── Body ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Image + overlay
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 720 / 1280,
                      child: _mapImage != null
                          ? CustomPaint(
                              painter: _MuscleMapPainter(
                                image: _mapImage!,
                                counts: _counts,
                                maxCount: maxCount,
                              ),
                            )
                          : Container(color: Colors.black),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Caption
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 12,
                            color: textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(width: 6),
                        Text(
                          'Only exercises with a muscle group assigned appear on the map',
                          style: TextStyle(
                            fontSize: 11,
                            color: textTertiary.withValues(alpha: 0.5),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Breakdown ──
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
                    // Section header with legend
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
                    // Muscle rows
                    ...sortedGroups.map((entry) {
                      final group = entry.key;
                      final count = entry.value;
                      final color =
                          _groupColors[group] ?? const Color(0xFF888888);
                      final displayName = _groupDisplayNames[group] ??
                          (group.isNotEmpty
                              ? group[0].toUpperCase() + group.substring(1)
                              : group);
                      final pct =
                          maxCount > 0 ? count / maxCount : 0.0;

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
                                style: KiStyles.labelSm(
                                    color: textSecondary),
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

// ── CustomPainter ──────────────────────────────────────────────────────────────

class _MuscleMapPainter extends CustomPainter {
  final ui.Image image;
  final Map<String, int> counts;
  final int maxCount;

  const _MuscleMapPainter({
    required this.image,
    required this.counts,
    required this.maxCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw base muscle map
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Offset.zero & size;
    canvas.drawImageRect(
        image, src, dst, Paint()..filterQuality = FilterQuality.medium);

    if (maxCount == 0) return;

    // Draw glowing overlays using screen blend mode
    for (final region in _regions) {
      final count = counts[region.group] ?? 0;
      if (count == 0) continue;

      final intensity =
          (0.22 + 0.68 * (count / maxCount).clamp(0.0, 1.0));
      final color = _groupColors[region.group] ?? Colors.white;

      final center =
          Offset(region.cx * size.width, region.cy * size.height);
      final outerRadius =
          math.max(region.rx * size.width, region.ry * size.height);
      final rect = Rect.fromCenter(
        center: center,
        width: region.rx * 2 * size.width,
        height: region.ry * 2 * size.height,
      );

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          outerRadius,
          [
            color.withValues(alpha: intensity),
            color.withValues(alpha: intensity * 0.35),
            Colors.transparent,
          ],
          [0.0, 0.5, 1.0],
        )
        ..blendMode = BlendMode.screen;

      canvas.drawOval(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_MuscleMapPainter old) =>
      old.counts != counts ||
      old.maxCount != maxCount ||
      old.image != image;
}
