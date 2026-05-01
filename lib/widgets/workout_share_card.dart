import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gymlog/db/db_helper.dart';

// ── Fixed palette (card is always rendered dark for social export) ────────────
const _kBg = Color(0xFF0D0D0D);
const _kAccent = Color(0xFFE07B3E);
const _kGold = Color(0xFFFFD700);

const _kPieColors = [
  Color(0xFFE07B3E), // orange — accent
  Color(0xFF4AE176), // green
  Color(0xFF4AB6E1), // sky-blue
  Color(0xFFE1C44A), // amber
  Color(0xFFCB4AE1), // violet
  Color(0xFFE14A6D), // rose
];

// ── Public card widget ────────────────────────────────────────────────────────

class WorkoutShareCard extends StatelessWidget {
  final String date;
  final int durationSeconds;
  final int exerciseCount;
  final int totalSets;
  final int totalReps;
  final double totalWeight;
  final String? photoPath;
  final List<String> personalBests;
  final Map<String, double> muscleBreakdown;

  /// Last N session volumes in chronological order (current session last).
  final List<double> volumeTrend;

  const WorkoutShareCard({
    super.key,
    required this.date,
    required this.durationSeconds,
    required this.exerciseCount,
    required this.totalSets,
    required this.totalReps,
    required this.totalWeight,
    this.photoPath,
    this.personalBests = const [],
    this.muscleBreakdown = const {},
    this.volumeTrend = const [],
  });

  @override
  Widget build(BuildContext context) {
    final dur = DBHelper.formatDuration(durationSeconds);
    final weightStr = totalWeight >= 1000
        ? '${(totalWeight / 1000).toStringAsFixed(1)}t'
        : totalWeight == totalWeight.truncateToDouble()
            ? '${totalWeight.toInt()} kg'
            : '${totalWeight.toStringAsFixed(1)} kg';
    final hasPhoto = photoPath != null &&
        photoPath!.isNotEmpty &&
        File(photoPath!).existsSync();
    final hasMuscles = muscleBreakdown.isNotEmpty;
    final hasTrend = volumeTrend.length >= 2;
    final hasPBs = personalBests.isNotEmpty;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            if (hasPhoto)
              Image.file(File(photoPath!), fit: BoxFit.cover)
            else
              Container(color: _kBg),

            // Gradient overlay — heavier at bottom to keep text legible over photos
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: hasPhoto
                      ? [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.black.withValues(alpha: 0.70),
                          Colors.black.withValues(alpha: 0.96),
                        ]
                      : [
                          Colors.transparent,
                          Colors.transparent,
                        ],
                  stops: hasPhoto ? const [0.0, 0.42, 1.0] : const [0.0, 1.0],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Branding header ────────────────────────────────────────
                  Row(
                    children: [
                      _Logo(),
                      const Spacer(),
                      if (hasPBs) _PBBadge(count: personalBests.length),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Hero stats ─────────────────────────────────────────────
                  Text(
                    'WORKOUT COMPLETE',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),

                  if (dur.isNotEmpty)
                    Text(
                      dur,
                      style: GoogleFonts.lexend(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                  const SizedBox(height: 10),

                  _VolumePill(label: weightStr),

                  const SizedBox(height: 14),

                  // ── PR list ────────────────────────────────────────────────
                  if (hasPBs) ...[
                    ...personalBests.take(3).map((n) => _PRRow(name: n)),
                    const SizedBox(height: 10),
                  ],

                  const Spacer(),

                  // ── Charts ────────────────────────────────────────────────
                  if (hasMuscles || hasTrend) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasMuscles)
                          Expanded(
                            flex: 5,
                            child: _MuscleChart(breakdown: muscleBreakdown),
                          ),
                        if (hasMuscles && hasTrend) const SizedBox(width: 16),
                        if (hasTrend)
                          Expanded(
                            flex: 7,
                            child: _TrendChart(volumes: volumeTrend),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Stats row ─────────────────────────────────────────────
                  Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _Stat(value: '$exerciseCount', label: 'Exercises'),
                      _StatDivider(),
                      _Stat(value: '$totalSets', label: 'Sets'),
                      _StatDivider(),
                      _Stat(value: '$totalReps', label: 'Reps'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Footer ────────────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        date.split('  ').first,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 3,
                        width: 36,
                        decoration: BoxDecoration(
                          color: _kAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: _kAccent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.fitness_center, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(
          'GYMLOG',
          style: GoogleFonts.lexend(
            color: _kAccent,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _PBBadge extends StatelessWidget {
  final int count;
  const _PBBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _kGold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGold.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, size: 12, color: _kGold),
          const SizedBox(width: 4),
          Text(
            count == 1 ? '1 PR' : '$count PRs',
            style: GoogleFonts.spaceGrotesk(
              color: _kGold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumePill extends StatelessWidget {
  final String label;
  const _VolumePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kAccent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 13, color: _kAccent),
          const SizedBox(width: 4),
          Text(
            '$label total volume',
            style: GoogleFonts.spaceGrotesk(
              color: _kAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PRRow extends StatelessWidget {
  final String name;
  const _PRRow({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, size: 11, color: _kGold),
          const SizedBox(width: 5),
          Text(
            'PR — $name',
            style: GoogleFonts.spaceGrotesk(
              color: _kGold,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleChart extends StatelessWidget {
  final Map<String, double> breakdown;
  const _MuscleChart({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final legend = entries.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MUSCLES',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                painter: _DonutPainter(
                  slices: entries.map((e) => e.value / total).toList(),
                  colors: List.generate(
                      entries.length,
                      (i) => _kPieColors[i % _kPieColors.length]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(legend.length, (idx) {
                  final e = legend[idx];
                  final pct = (e.value / total * 100).round();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _kPieColors[idx % _kPieColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            e.key,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white.withValues(alpha: 0.80),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> slices;
  final List<Color> colors;
  const _DonutPainter({required this.slices, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeW = size.shortestSide * 0.22;
    final radius = (size.shortestSide / 2) - strokeW / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const gap = 0.04; // gap in radians between segments

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    double start = -math.pi / 2;
    for (int i = 0; i < slices.length; i++) {
      final sweep = slices[i] * 2 * math.pi - gap;
      if (sweep <= 0) continue;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, start + gap / 2, sweep, false, paint);
      start += slices[i] * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => false;
}

class _TrendChart extends StatelessWidget {
  final List<double> volumes;
  const _TrendChart({required this.volumes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOLUME TREND',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          width: double.infinity,
          child: CustomPaint(
            painter: _SparklinePainter(volumes: volumes),
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> volumes;
  const _SparklinePainter({required this.volumes});

  @override
  void paint(Canvas canvas, Size size) {
    if (volumes.length < 2) return;

    final minV = volumes.reduce(math.min);
    final maxV = volumes.reduce(math.max);
    final range = (maxV - minV).abs();
    const vPad = 6.0;

    final points = List.generate(volumes.length, (i) {
      final x = size.width * i / (volumes.length - 1);
      final y = range > 0
          ? vPad + (size.height - 2 * vPad) * (1 - (volumes[i] - minV) / range)
          : size.height / 2;
      return Offset(x, y);
    });

    // Fill gradient
    final fill = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fill.lineTo(p.dx, p.dy);
    }
    fill.lineTo(points.last.dx, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kAccent.withValues(alpha: 0.28),
            _kAccent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = _kAccent
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots — last one is larger (current session)
    final bgPaint = Paint()
      ..color = _kBg
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = _kAccent
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      final r = isLast ? 4.5 : 2.8;
      canvas.drawCircle(points[i], r + 1.5, bgPaint);
      canvas.drawCircle(points[i], r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => false;
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.lexend(
              color: _kAccent,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}
