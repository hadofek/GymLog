import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
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

// Coordinates as fractions of canvas (w × h).
// Front figure at cx=0.25w, back at cx=0.75w.
const _regions = <_Region>[
  // ── Chest (front) ──
  _Region('chest', 0.178, 0.256, 0.066, 0.057),
  _Region('chest', 0.322, 0.256, 0.066, 0.057),
  // ── Front delts ──
  _Region('shoulders', 0.116, 0.204, 0.046, 0.042),
  _Region('shoulders', 0.384, 0.204, 0.046, 0.042),
  // ── Rear delts (back figure) ──
  _Region('shoulders', 0.616, 0.204, 0.046, 0.042),
  _Region('shoulders', 0.884, 0.204, 0.046, 0.042),
  // ── Biceps (front arms) ──
  _Region('biceps', 0.108, 0.295, 0.032, 0.062),
  _Region('biceps', 0.392, 0.295, 0.032, 0.062),
  // ── Triceps (back arms) ──
  _Region('triceps', 0.608, 0.295, 0.032, 0.062),
  _Region('triceps', 0.892, 0.295, 0.032, 0.062),
  // ── Forearms (front) ──
  _Region('forearms', 0.086, 0.474, 0.026, 0.050),
  _Region('forearms', 0.414, 0.474, 0.026, 0.050),
  // ── Core / Abs (front) ──
  _Region('core', 0.250, 0.388, 0.061, 0.077),
  // ── Traps (back) ──
  _Region('traps', 0.750, 0.210, 0.086, 0.038),
  // ── Lats + lower back ──
  _Region('back', 0.632, 0.330, 0.058, 0.083),
  _Region('back', 0.868, 0.330, 0.058, 0.083),
  _Region('back', 0.750, 0.432, 0.065, 0.036),
  // ── Quads (front) ──
  _Region('quads', 0.202, 0.634, 0.054, 0.088),
  _Region('quads', 0.298, 0.634, 0.054, 0.088),
  // ── Hamstrings (back) ──
  _Region('hamstrings', 0.662, 0.644, 0.052, 0.086),
  _Region('hamstrings', 0.838, 0.644, 0.052, 0.086),
  // ── Glutes (back) ──
  _Region('glutes', 0.688, 0.530, 0.063, 0.050),
  _Region('glutes', 0.812, 0.530, 0.063, 0.050),
  // ── Calves ──
  _Region('calves', 0.188, 0.836, 0.034, 0.050),
  _Region('calves', 0.312, 0.836, 0.034, 0.050),
  _Region('calves', 0.662, 0.836, 0.034, 0.050),
  _Region('calves', 0.838, 0.836, 0.034, 0.050),
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
                  // Body model (no image — fully drawn in code)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 720 / 1280,
                      child: CustomPaint(
                        painter: _BodyModelPainter(
                          counts: _counts,
                          maxCount: maxCount,
                          isDark: isDark,
                        ),
                      ),
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

// ── Body Model Painter ──────────────────────────────────────────────────────────

class _BodyModelPainter extends CustomPainter {
  final Map<String, int> counts;
  final int maxCount;
  final bool isDark;

  const _BodyModelPainter({
    required this.counts,
    required this.maxCount,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = isDark ? const Color(0xFF090C14) : const Color(0xFFEBEEF7),
    );

    // Subtle center divider
    canvas.drawLine(
      Offset(w * 0.5, h * 0.04),
      Offset(w * 0.5, h * 0.93),
      Paint()
        ..color = (isDark ? Colors.white : Colors.black)
            .withValues(alpha: isDark ? 0.055 : 0.07)
        ..strokeWidth = 0.6,
    );

    // Figures
    _drawFigure(canvas, w, h, cx: w * 0.25);
    _drawFigure(canvas, w, h, cx: w * 0.75);

    // Anatomy construction lines
    _constructionLines(canvas, w, h, cx: w * 0.25, isFront: true);
    _constructionLines(canvas, w, h, cx: w * 0.75, isFront: false);

    // Muscle glows
    if (maxCount > 0) {
      for (final region in _regions) {
        final count = counts[region.group] ?? 0;
        if (count == 0) continue;
        _drawMuscleGlow(canvas, w, h, region, count);
      }
    }

    // Labels
    _drawLabel(canvas, 'FRONT', Offset(w * 0.25, h * 0.960));
    _drawLabel(canvas, 'BACK', Offset(w * 0.75, h * 0.960));
  }

  // Diagonal gradient: upper-right lit → lower-left shadow, per figure.
  Paint _fill(double cx, double w, double h) => Paint()
    ..shader = ui.Gradient.linear(
      Offset(cx + w * 0.20, h * 0.04),
      Offset(cx - w * 0.20, h * 0.94),
      isDark
          ? const [Color(0xFF1C2A46), Color(0xFF101820), Color(0xFF080C16)]
          : const [Color(0xFFD5DDEE), Color(0xFFBCC6DC), Color(0xFFA8B2C8)],
      const [0.0, 0.48, 1.0],
    )
    ..style = PaintingStyle.fill;

  Paint get _stroke => Paint()
    ..color = isDark ? const Color(0xFF384E72) : const Color(0xFF7888A8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.85
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  void _drawFigure(Canvas canvas, double w, double h, {required double cx}) {
    final fill = _fill(cx, w, h);
    final stroke = _stroke;

    void dp(Path p) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    }

    void dOval(Rect r) {
      canvas.drawOval(r, fill);
      canvas.drawOval(r, stroke);
    }

    // Head
    dOval(Rect.fromCenter(
        center: Offset(cx, h * 0.077), width: w * 0.076, height: h * 0.102));

    // Torso
    dp(_torso(cx, w, h));

    // Upper arms
    dp(_cap(Offset(cx - w * 0.112, h * 0.200), Offset(cx - w * 0.163, h * 0.388),
        w * 0.030, w * 0.024));
    dp(_cap(Offset(cx + w * 0.112, h * 0.200), Offset(cx + w * 0.163, h * 0.388),
        w * 0.030, w * 0.024));

    // Forearms
    dp(_cap(Offset(cx - w * 0.163, h * 0.400), Offset(cx - w * 0.167, h * 0.548),
        w * 0.023, w * 0.015));
    dp(_cap(Offset(cx + w * 0.163, h * 0.400), Offset(cx + w * 0.167, h * 0.548),
        w * 0.023, w * 0.015));

    // Thighs
    dp(_cap(Offset(cx - w * 0.048, h * 0.557), Offset(cx - w * 0.038, h * 0.735),
        w * 0.048, w * 0.037));
    dp(_cap(Offset(cx + w * 0.048, h * 0.557), Offset(cx + w * 0.038, h * 0.735),
        w * 0.048, w * 0.037));

    // Calves
    dp(_cap(Offset(cx - w * 0.038, h * 0.748), Offset(cx - w * 0.036, h * 0.920),
        w * 0.031, w * 0.017));
    dp(_cap(Offset(cx + w * 0.038, h * 0.748), Offset(cx + w * 0.036, h * 0.920),
        w * 0.031, w * 0.017));
  }

  Path _torso(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.022, h * 0.126);
    // Right: neck → shoulder
    p.cubicTo(cx + w * 0.022, h * 0.162,
        cx + w * 0.075, h * 0.172, cx + w * 0.110, h * 0.192);
    // Right: shoulder → armpit
    p.cubicTo(cx + w * 0.097, h * 0.238,
        cx + w * 0.081, h * 0.268, cx + w * 0.079, h * 0.294);
    // Right: armpit → waist
    p.cubicTo(cx + w * 0.077, h * 0.354,
        cx + w * 0.063, h * 0.420, cx + w * 0.062, h * 0.459);
    // Right: waist → hip flare
    p.cubicTo(cx + w * 0.062, h * 0.493,
        cx + w * 0.093, h * 0.513, cx + w * 0.093, h * 0.527);
    // Right: hip → crotch
    p.cubicTo(cx + w * 0.093, h * 0.547,
        cx + w * 0.027, h * 0.561, cx, h * 0.561);
    // Left: crotch → hip
    p.cubicTo(cx - w * 0.027, h * 0.561,
        cx - w * 0.093, h * 0.547, cx - w * 0.093, h * 0.527);
    // Left: hip → waist
    p.cubicTo(cx - w * 0.093, h * 0.513,
        cx - w * 0.062, h * 0.493, cx - w * 0.062, h * 0.459);
    // Left: waist → armpit
    p.cubicTo(cx - w * 0.063, h * 0.420,
        cx - w * 0.077, h * 0.354, cx - w * 0.079, h * 0.294);
    // Left: armpit → shoulder
    p.cubicTo(cx - w * 0.081, h * 0.268,
        cx - w * 0.097, h * 0.238, cx - w * 0.110, h * 0.192);
    // Left: shoulder → neck
    p.cubicTo(cx - w * 0.075, h * 0.172,
        cx - w * 0.022, h * 0.162, cx - w * 0.022, h * 0.126);
    p.close();
    return p;
  }

  // Tapered stadium (capsule) between two center points.
  Path _cap(Offset a, Offset b, double ra, double rb) {
    final d = b - a;
    final len = d.distance;
    if (len < 1) return Path();
    final nx = d.dx / len;
    final ny = d.dy / len;
    final px = -ny;
    final py = nx;

    final p = Path();
    p.moveTo(a.dx + px * ra, a.dy + py * ra);
    p.lineTo(b.dx + px * rb, b.dy + py * rb);
    p.arcToPoint(Offset(b.dx - px * rb, b.dy - py * rb),
        radius: Radius.circular(rb), clockwise: true);
    p.lineTo(a.dx - px * ra, a.dy - py * ra);
    p.arcToPoint(Offset(a.dx + px * ra, a.dy + py * ra),
        radius: Radius.circular(ra), clockwise: true);
    p.close();
    return p;
  }

  void _constructionLines(
      Canvas canvas, double w, double h,
      {required double cx, required bool isFront}) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: isDark ? 0.10 : 0.08)
      ..strokeWidth = 0.45
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (isFront) {
      // Sternal split between pecs
      canvas.drawLine(
          Offset(cx, h * 0.202), Offset(cx, h * 0.296), paint);
      // Ab center line
      canvas.drawLine(
          Offset(cx, h * 0.310), Offset(cx, h * 0.456), paint);
      // Ab horizontal segments (4 rows, narrowing as they descend)
      for (int i = 0; i < 4; i++) {
        final y = 0.334 + i * 0.038;
        final spread = w * (0.052 - i * 0.004);
        canvas.drawLine(
            Offset(cx - spread, h * y), Offset(cx + spread, h * y), paint);
      }
      // Collarbone hints
      canvas.drawLine(
          Offset(cx - w * 0.013, h * 0.140),
          Offset(cx - w * 0.090, h * 0.188), paint);
      canvas.drawLine(
          Offset(cx + w * 0.013, h * 0.140),
          Offset(cx + w * 0.090, h * 0.188), paint);
      // Quad split hint
      canvas.drawLine(
          Offset(cx, h * 0.560), Offset(cx, h * 0.598), paint);
    } else {
      // Spine
      canvas.drawLine(
          Offset(cx, h * 0.198), Offset(cx, h * 0.456), paint);
      // Scapula outlines (two-segment angle each side)
      canvas.drawLine(
          Offset(cx, h * 0.228), Offset(cx - w * 0.053, h * 0.270), paint);
      canvas.drawLine(
          Offset(cx - w * 0.053, h * 0.270),
          Offset(cx - w * 0.069, h * 0.316), paint);
      canvas.drawLine(
          Offset(cx, h * 0.228), Offset(cx + w * 0.053, h * 0.270), paint);
      canvas.drawLine(
          Offset(cx + w * 0.053, h * 0.270),
          Offset(cx + w * 0.069, h * 0.316), paint);
      // Glute crease
      canvas.drawLine(
          Offset(cx, h * 0.518), Offset(cx, h * 0.558), paint);
      // Hamstring split
      canvas.drawLine(
          Offset(cx, h * 0.572), Offset(cx, h * 0.618), paint);
    }
  }

  void _drawMuscleGlow(
      Canvas canvas, double w, double h, _Region region, int count) {
    final intensity = 0.26 + 0.64 * (count / maxCount).clamp(0.0, 1.0);
    final color = _groupColors[region.group] ?? Colors.white;
    final center = Offset(region.cx * w, region.cy * h);
    final rx = region.rx * w;
    final ry = region.ry * h;
    final outerR = math.max(rx, ry);

    // Layer 1 — wide atmospheric halo
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 5.5, height: ry * 5.5),
      Paint()
        ..shader = ui.Gradient.radial(center, outerR * 2.8, [
          color.withValues(alpha: intensity * 0.11),
          Colors.transparent,
        ], [
          0.0,
          1.0
        ])
        ..blendMode = BlendMode.screen,
    );

    // Layer 2 — mid bloom
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 3.0, height: ry * 3.0),
      Paint()
        ..shader = ui.Gradient.radial(center, outerR * 1.5, [
          color.withValues(alpha: intensity * 0.50),
          color.withValues(alpha: intensity * 0.20),
          Colors.transparent,
        ], [
          0.0,
          0.46,
          1.0
        ])
        ..blendMode = BlendMode.screen,
    );

    // Layer 3 — tight bright core (white-shifted at peak)
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.15, height: ry * 1.15),
      Paint()
        ..shader = ui.Gradient.radial(center, outerR * 0.58, [
          Color.lerp(color, Colors.white, 0.38)!
              .withValues(alpha: intensity * 0.92),
          color.withValues(alpha: intensity * 0.58),
          Colors.transparent,
        ], [
          0.0,
          0.40,
          1.0
        ])
        ..blendMode = BlendMode.screen,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: isDark ? const Color(0xFF38506A) : const Color(0xFF7888A8),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_BodyModelPainter old) =>
      old.counts != counts ||
      old.maxCount != maxCount ||
      old.isDark != isDark;
}
