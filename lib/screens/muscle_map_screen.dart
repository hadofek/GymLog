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

const _groupColors = <String, Color>{
  'chest':      Color(0xFF5B9BD5),
  'back':       Color(0xFF9068C4),
  'shoulders':  Color(0xFF38B2C8),
  'biceps':     Color(0xFF48A870),
  'triceps':    Color(0xFFCC5555),
  'core':       Color(0xFFCBA038),
  'traps':      Color(0xFF6088C8),
  'quads':      Color(0xFF3EA898),
  'hamstrings': Color(0xFFCC5878),
  'glutes':     Color(0xFFCC7A48),
  'calves':     Color(0xFF6EA838),
  'forearms':   Color(0xFF906050),
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
    if (s.contains('core') || s.contains('abs') || s.contains('abdom')) return 'core';
    if (s.contains('quad') || s == 'legs') return 'quads';
    if (s.contains('hamstring')) return 'hamstrings';
    if (s.contains('glute') || s.contains('butt') || s.contains('hip')) return 'glutes';
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          isDark
                              ? ColorFiltered(
                                  colorFilter: const ColorFilter.matrix([
                                    -1, 0, 0, 0, 255,
                                     0,-1, 0, 0, 255,
                                     0, 0,-1, 0, 255,
                                     0, 0, 0, 1,   0,
                                  ]),
                                  child: Image.asset(
                                    'assets/images/muscle_map.png',
                                    fit: BoxFit.fill,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/muscle_map.png',
                                  fit: BoxFit.fill,
                                ),
                          CustomPaint(
                            painter: _BodyModelPainter(
                              counts: _counts,
                              maxCount: maxCount,
                              isDark: isDark,
                            ),
                          ),
                        ],
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

// ── Body Model Painter ──────────────────────────────────────────────────────

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

    final frontCx = w * 0.25;
    final backCx = w * 0.75;

    _paintMuscleFills(canvas, w, h, frontCx, isFront: true);
    _paintMuscleFills(canvas, w, h, backCx, isFront: false);

    _drawLabel(canvas, 'FRONT', Offset(w * 0.25, h * 0.962));
    _drawLabel(canvas, 'BACK', Offset(w * 0.75, h * 0.962));
  }

  // ── Muscle fills ─────────────────────────────────────────────────────────

  void _paintMuscleFills(
      Canvas canvas, double w, double h, double cx, {required bool isFront}) {
    if (maxCount == 0) return;

    void fill(String group, Path path) {
      final count = counts[group] ?? 0;
      if (count == 0) return;
      final color = _groupColors[group] ?? Colors.grey;
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.52)
          ..style = PaintingStyle.fill,
      );
    }

    if (isFront) {
      // Chest
      fill('chest', _pecRight(cx, w, h));
      fill('chest', _pecLeft(cx, w, h));
      // Front shoulders
      fill('shoulders', _frontDeltRight(cx, w, h));
      fill('shoulders', _frontDeltLeft(cx, w, h));
      // Biceps
      fill('biceps', _bicepRight(cx, w, h));
      fill('biceps', _bicepLeft(cx, w, h));
      // Forearms front
      fill('forearms', _forearmFrontRight(cx, w, h));
      fill('forearms', _forearmFrontLeft(cx, w, h));
      // Core / abs
      fill('core', _coreRegion(cx, w, h));
      // Quads
      fill('quads', _quadRight(cx, w, h));
      fill('quads', _quadLeft(cx, w, h));
      // Calves front (tibialis)
      fill('calves', _tibRight(cx, w, h));
      fill('calves', _tibLeft(cx, w, h));
    } else {
      // Traps
      fill('traps', _traps(cx, w, h));
      // Rear shoulders
      fill('shoulders', _rearDeltRight(cx, w, h));
      fill('shoulders', _rearDeltLeft(cx, w, h));
      // Triceps
      fill('triceps', _tricepRight(cx, w, h));
      fill('triceps', _tricepLeft(cx, w, h));
      // Forearms back
      fill('forearms', _forearmBackRight(cx, w, h));
      fill('forearms', _forearmBackLeft(cx, w, h));
      // Lats + back
      fill('back', _latRight(cx, w, h));
      fill('back', _latLeft(cx, w, h));
      // Glutes
      fill('glutes', _gluteRight(cx, w, h));
      fill('glutes', _gluteLeft(cx, w, h));
      // Hamstrings
      fill('hamstrings', _hamRight(cx, w, h));
      fill('hamstrings', _hamLeft(cx, w, h));
      // Calves back (gastrocnemius)
      fill('calves', _gastroRight(cx, w, h));
      fill('calves', _gastroLeft(cx, w, h));
    }
  }

  // ── Muscle path definitions ───────────────────────────────────────────────

  // Right pec (fan shape from sternum to armpit)
  Path _pecRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.014, h * 0.200);
    p.cubicTo(cx + w * 0.052, h * 0.193, cx + w * 0.085, h * 0.210,
        cx + w * 0.096, h * 0.236);
    p.cubicTo(cx + w * 0.096, h * 0.256, cx + w * 0.083, h * 0.276,
        cx + w * 0.079, h * 0.283);
    p.cubicTo(cx + w * 0.054, h * 0.308, cx + w * 0.025, h * 0.310,
        cx + w * 0.014, h * 0.308);
    p.close();
    return p;
  }

  Path _pecLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.014, h * 0.200);
    p.cubicTo(cx - w * 0.052, h * 0.193, cx - w * 0.085, h * 0.210,
        cx - w * 0.096, h * 0.236);
    p.cubicTo(cx - w * 0.096, h * 0.256, cx - w * 0.083, h * 0.276,
        cx - w * 0.079, h * 0.283);
    p.cubicTo(cx - w * 0.054, h * 0.308, cx - w * 0.025, h * 0.310,
        cx - w * 0.014, h * 0.308);
    p.close();
    return p;
  }

  // Front deltoid (shoulder cap, front view)
  Path _frontDeltRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.084, h * 0.194);
    p.cubicTo(cx + w * 0.097, h * 0.180, cx + w * 0.116, h * 0.177,
        cx + w * 0.128, h * 0.189);
    p.cubicTo(cx + w * 0.136, h * 0.203, cx + w * 0.133, h * 0.232,
        cx + w * 0.118, h * 0.250);
    p.cubicTo(cx + w * 0.104, h * 0.260, cx + w * 0.092, h * 0.254,
        cx + w * 0.084, h * 0.244);
    p.cubicTo(cx + w * 0.083, h * 0.228, cx + w * 0.083, h * 0.208,
        cx + w * 0.084, h * 0.194);
    p.close();
    return p;
  }

  Path _frontDeltLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.084, h * 0.194);
    p.cubicTo(cx - w * 0.097, h * 0.180, cx - w * 0.116, h * 0.177,
        cx - w * 0.128, h * 0.189);
    p.cubicTo(cx - w * 0.136, h * 0.203, cx - w * 0.133, h * 0.232,
        cx - w * 0.118, h * 0.250);
    p.cubicTo(cx - w * 0.104, h * 0.260, cx - w * 0.092, h * 0.254,
        cx - w * 0.084, h * 0.244);
    p.cubicTo(cx - w * 0.083, h * 0.228, cx - w * 0.083, h * 0.208,
        cx - w * 0.084, h * 0.194);
    p.close();
    return p;
  }

  // Bicep (front of upper arm)
  Path _bicepRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.112, h * 0.258);
    p.cubicTo(cx + w * 0.126, h * 0.264, cx + w * 0.138, h * 0.290,
        cx + w * 0.140, h * 0.328);
    p.cubicTo(cx + w * 0.141, h * 0.360, cx + w * 0.137, h * 0.385,
        cx + w * 0.130, h * 0.400);
    p.lineTo(cx + w * 0.096, h * 0.400);
    p.cubicTo(cx + w * 0.088, h * 0.385, cx + w * 0.085, h * 0.358,
        cx + w * 0.087, h * 0.326);
    p.cubicTo(cx + w * 0.090, h * 0.290, cx + w * 0.100, h * 0.264,
        cx + w * 0.112, h * 0.258);
    p.close();
    return p;
  }

  Path _bicepLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.112, h * 0.258);
    p.cubicTo(cx - w * 0.126, h * 0.264, cx - w * 0.138, h * 0.290,
        cx - w * 0.140, h * 0.328);
    p.cubicTo(cx - w * 0.141, h * 0.360, cx - w * 0.137, h * 0.385,
        cx - w * 0.130, h * 0.400);
    p.lineTo(cx - w * 0.096, h * 0.400);
    p.cubicTo(cx - w * 0.088, h * 0.385, cx - w * 0.085, h * 0.358,
        cx - w * 0.087, h * 0.326);
    p.cubicTo(cx - w * 0.090, h * 0.290, cx - w * 0.100, h * 0.264,
        cx - w * 0.112, h * 0.258);
    p.close();
    return p;
  }

  // Forearm (front)
  Path _forearmFrontRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.130, h * 0.408);
    p.cubicTo(cx + w * 0.143, h * 0.432, cx + w * 0.148, h * 0.474,
        cx + w * 0.144, h * 0.512);
    p.cubicTo(cx + w * 0.140, h * 0.536, cx + w * 0.132, h * 0.550,
        cx + w * 0.126, h * 0.554);
    p.lineTo(cx + w * 0.098, h * 0.554);
    p.cubicTo(cx + w * 0.092, h * 0.550, cx + w * 0.086, h * 0.536,
        cx + w * 0.083, h * 0.512);
    p.cubicTo(cx + w * 0.079, h * 0.474, cx + w * 0.084, h * 0.432,
        cx + w * 0.096, h * 0.408);
    p.close();
    return p;
  }

  Path _forearmFrontLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.130, h * 0.408);
    p.cubicTo(cx - w * 0.143, h * 0.432, cx - w * 0.148, h * 0.474,
        cx - w * 0.144, h * 0.512);
    p.cubicTo(cx - w * 0.140, h * 0.536, cx - w * 0.132, h * 0.550,
        cx - w * 0.126, h * 0.554);
    p.lineTo(cx - w * 0.098, h * 0.554);
    p.cubicTo(cx - w * 0.092, h * 0.550, cx - w * 0.086, h * 0.536,
        cx - w * 0.083, h * 0.512);
    p.cubicTo(cx - w * 0.079, h * 0.474, cx - w * 0.084, h * 0.432,
        cx - w * 0.096, h * 0.408);
    p.close();
    return p;
  }

  // Core (rectus abdominis + obliques)
  Path _coreRegion(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.060, h * 0.312);
    p.lineTo(cx + w * 0.060, h * 0.312);
    p.lineTo(cx + w * 0.062, h * 0.456);
    p.cubicTo(cx + w * 0.052, h * 0.490, cx + w * 0.040, h * 0.495,
        cx + w * 0.030, h * 0.494);
    p.lineTo(cx - w * 0.030, h * 0.494);
    p.cubicTo(cx - w * 0.040, h * 0.495, cx - w * 0.052, h * 0.490,
        cx - w * 0.062, h * 0.456);
    p.close();
    return p;
  }

  // Quads (front thigh)
  Path _quadRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.020, h * 0.500);
    p.cubicTo(cx + w * 0.040, h * 0.498, cx + w * 0.075, h * 0.500,
        cx + w * 0.105, h * 0.507);
    p.cubicTo(cx + w * 0.103, h * 0.575, cx + w * 0.096, h * 0.638,
        cx + w * 0.086, h * 0.700);
    p.lineTo(cx + w * 0.022, h * 0.704);
    p.cubicTo(cx + w * 0.016, h * 0.638, cx + w * 0.016, h * 0.573,
        cx + w * 0.020, h * 0.500);
    p.close();
    return p;
  }

  Path _quadLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.020, h * 0.500);
    p.cubicTo(cx - w * 0.040, h * 0.498, cx - w * 0.075, h * 0.500,
        cx - w * 0.105, h * 0.507);
    p.cubicTo(cx - w * 0.103, h * 0.575, cx - w * 0.096, h * 0.638,
        cx - w * 0.086, h * 0.700);
    p.lineTo(cx - w * 0.022, h * 0.704);
    p.cubicTo(cx - w * 0.016, h * 0.638, cx - w * 0.016, h * 0.573,
        cx - w * 0.020, h * 0.500);
    p.close();
    return p;
  }

  // Tibialis anterior (front of calf, narrow strip)
  Path _tibRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.022, h * 0.710);
    p.cubicTo(cx + w * 0.032, h * 0.710, cx + w * 0.044, h * 0.718,
        cx + w * 0.050, h * 0.738);
    p.cubicTo(cx + w * 0.053, h * 0.785, cx + w * 0.050, h * 0.830,
        cx + w * 0.042, h * 0.862);
    p.lineTo(cx + w * 0.025, h * 0.868);
    p.cubicTo(cx + w * 0.020, h * 0.834, cx + w * 0.018, h * 0.788,
        cx + w * 0.018, h * 0.752);
    p.cubicTo(cx + w * 0.018, h * 0.728, cx + w * 0.018, h * 0.712,
        cx + w * 0.022, h * 0.710);
    p.close();
    return p;
  }

  Path _tibLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.022, h * 0.710);
    p.cubicTo(cx - w * 0.032, h * 0.710, cx - w * 0.044, h * 0.718,
        cx - w * 0.050, h * 0.738);
    p.cubicTo(cx - w * 0.053, h * 0.785, cx - w * 0.050, h * 0.830,
        cx - w * 0.042, h * 0.862);
    p.lineTo(cx - w * 0.025, h * 0.868);
    p.cubicTo(cx - w * 0.020, h * 0.834, cx - w * 0.018, h * 0.788,
        cx - w * 0.018, h * 0.752);
    p.cubicTo(cx - w * 0.018, h * 0.728, cx - w * 0.018, h * 0.712,
        cx - w * 0.022, h * 0.710);
    p.close();
    return p;
  }

  // Trapezius (full diamond, back view)
  Path _traps(double cx, double w, double h) {
    final p = Path();
    // Start at top center (base of skull)
    p.moveTo(cx, h * 0.130);
    // Right shoulder
    p.cubicTo(cx + w * 0.038, h * 0.152, cx + w * 0.082, h * 0.175,
        cx + w * 0.108, h * 0.197);
    // Down right side to mid-back point
    p.cubicTo(cx + w * 0.078, h * 0.262, cx + w * 0.038, h * 0.338,
        cx + w * 0.003, h * 0.392);
    // Bottom point of diamond
    p.lineTo(cx - w * 0.003, h * 0.392);
    // Up left side from mid-back
    p.cubicTo(cx - w * 0.038, h * 0.338, cx - w * 0.078, h * 0.262,
        cx - w * 0.108, h * 0.197);
    // Left shoulder to top
    p.cubicTo(cx - w * 0.082, h * 0.175, cx - w * 0.038, h * 0.152,
        cx, h * 0.130);
    p.close();
    return p;
  }

  // Rear deltoid (back view)
  Path _rearDeltRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.086, h * 0.196);
    p.cubicTo(cx + w * 0.098, h * 0.182, cx + w * 0.116, h * 0.179,
        cx + w * 0.128, h * 0.191);
    p.cubicTo(cx + w * 0.138, h * 0.204, cx + w * 0.136, h * 0.234,
        cx + w * 0.120, h * 0.256);
    p.cubicTo(cx + w * 0.106, h * 0.266, cx + w * 0.092, h * 0.260,
        cx + w * 0.084, h * 0.250);
    p.cubicTo(cx + w * 0.083, h * 0.232, cx + w * 0.084, h * 0.212,
        cx + w * 0.086, h * 0.196);
    p.close();
    return p;
  }

  Path _rearDeltLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.086, h * 0.196);
    p.cubicTo(cx - w * 0.098, h * 0.182, cx - w * 0.116, h * 0.179,
        cx - w * 0.128, h * 0.191);
    p.cubicTo(cx - w * 0.138, h * 0.204, cx - w * 0.136, h * 0.234,
        cx - w * 0.120, h * 0.256);
    p.cubicTo(cx - w * 0.106, h * 0.266, cx - w * 0.092, h * 0.260,
        cx - w * 0.084, h * 0.250);
    p.cubicTo(cx - w * 0.083, h * 0.232, cx - w * 0.084, h * 0.212,
        cx - w * 0.086, h * 0.196);
    p.close();
    return p;
  }

  // Triceps (back of upper arm)
  Path _tricepRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.110, h * 0.260);
    p.cubicTo(cx + w * 0.124, h * 0.268, cx + w * 0.136, h * 0.295,
        cx + w * 0.140, h * 0.330);
    p.cubicTo(cx + w * 0.142, h * 0.360, cx + w * 0.138, h * 0.386,
        cx + w * 0.130, h * 0.402);
    p.lineTo(cx + w * 0.095, h * 0.402);
    p.cubicTo(cx + w * 0.086, h * 0.386, cx + w * 0.084, h * 0.358,
        cx + w * 0.086, h * 0.328);
    p.cubicTo(cx + w * 0.089, h * 0.294, cx + w * 0.100, h * 0.266,
        cx + w * 0.110, h * 0.260);
    p.close();
    return p;
  }

  Path _tricepLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.110, h * 0.260);
    p.cubicTo(cx - w * 0.124, h * 0.268, cx - w * 0.136, h * 0.295,
        cx - w * 0.140, h * 0.330);
    p.cubicTo(cx - w * 0.142, h * 0.360, cx - w * 0.138, h * 0.386,
        cx - w * 0.130, h * 0.402);
    p.lineTo(cx - w * 0.095, h * 0.402);
    p.cubicTo(cx - w * 0.086, h * 0.386, cx - w * 0.084, h * 0.358,
        cx - w * 0.086, h * 0.328);
    p.cubicTo(cx - w * 0.089, h * 0.294, cx - w * 0.100, h * 0.266,
        cx - w * 0.110, h * 0.260);
    p.close();
    return p;
  }

  // Forearm (back)
  Path _forearmBackRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.130, h * 0.410);
    p.cubicTo(cx + w * 0.142, h * 0.434, cx + w * 0.147, h * 0.476,
        cx + w * 0.143, h * 0.514);
    p.cubicTo(cx + w * 0.139, h * 0.538, cx + w * 0.131, h * 0.552,
        cx + w * 0.125, h * 0.556);
    p.lineTo(cx + w * 0.097, h * 0.556);
    p.cubicTo(cx + w * 0.091, h * 0.552, cx + w * 0.086, h * 0.538,
        cx + w * 0.082, h * 0.514);
    p.cubicTo(cx + w * 0.079, h * 0.476, cx + w * 0.084, h * 0.434,
        cx + w * 0.095, h * 0.410);
    p.close();
    return p;
  }

  Path _forearmBackLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.130, h * 0.410);
    p.cubicTo(cx - w * 0.142, h * 0.434, cx - w * 0.147, h * 0.476,
        cx - w * 0.143, h * 0.514);
    p.cubicTo(cx - w * 0.139, h * 0.538, cx - w * 0.131, h * 0.552,
        cx - w * 0.125, h * 0.556);
    p.lineTo(cx - w * 0.097, h * 0.556);
    p.cubicTo(cx - w * 0.091, h * 0.552, cx - w * 0.086, h * 0.538,
        cx - w * 0.082, h * 0.514);
    p.cubicTo(cx - w * 0.079, h * 0.476, cx - w * 0.084, h * 0.434,
        cx - w * 0.095, h * 0.410);
    p.close();
    return p;
  }

  // Lats (back, V-shape from armpit down)
  Path _latRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.082, h * 0.262);
    p.cubicTo(cx + w * 0.090, h * 0.298, cx + w * 0.088, h * 0.354,
        cx + w * 0.070, h * 0.408);
    p.cubicTo(cx + w * 0.053, h * 0.450, cx + w * 0.030, h * 0.468,
        cx + w * 0.006, h * 0.470);
    p.lineTo(cx + w * 0.005, h * 0.390);
    p.cubicTo(cx + w * 0.028, h * 0.380, cx + w * 0.052, h * 0.350,
        cx + w * 0.062, h * 0.296);
    p.cubicTo(cx + w * 0.068, h * 0.272, cx + w * 0.075, h * 0.260,
        cx + w * 0.082, h * 0.262);
    p.close();
    return p;
  }

  Path _latLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.082, h * 0.262);
    p.cubicTo(cx - w * 0.090, h * 0.298, cx - w * 0.088, h * 0.354,
        cx - w * 0.070, h * 0.408);
    p.cubicTo(cx - w * 0.053, h * 0.450, cx - w * 0.030, h * 0.468,
        cx - w * 0.006, h * 0.470);
    p.lineTo(cx - w * 0.005, h * 0.390);
    p.cubicTo(cx - w * 0.028, h * 0.380, cx - w * 0.052, h * 0.350,
        cx - w * 0.062, h * 0.296);
    p.cubicTo(cx - w * 0.068, h * 0.272, cx - w * 0.075, h * 0.260,
        cx - w * 0.082, h * 0.262);
    p.close();
    return p;
  }

  // Glutes (back)
  Path _gluteRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.007, h * 0.454);
    p.cubicTo(cx + w * 0.028, h * 0.450, cx + w * 0.057, h * 0.453,
        cx + w * 0.082, h * 0.463);
    p.cubicTo(cx + w * 0.090, h * 0.472, cx + w * 0.092, h * 0.486,
        cx + w * 0.088, h * 0.498);
    p.cubicTo(cx + w * 0.078, h * 0.510, cx + w * 0.055, h * 0.513,
        cx + w * 0.030, h * 0.511);
    p.cubicTo(cx + w * 0.016, h * 0.509, cx + w * 0.007, h * 0.502,
        cx + w * 0.007, h * 0.495);
    p.close();
    return p;
  }

  Path _gluteLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.007, h * 0.454);
    p.cubicTo(cx - w * 0.028, h * 0.450, cx - w * 0.057, h * 0.453,
        cx - w * 0.082, h * 0.463);
    p.cubicTo(cx - w * 0.090, h * 0.472, cx - w * 0.092, h * 0.486,
        cx - w * 0.088, h * 0.498);
    p.cubicTo(cx - w * 0.078, h * 0.510, cx - w * 0.055, h * 0.513,
        cx - w * 0.030, h * 0.511);
    p.cubicTo(cx - w * 0.016, h * 0.509, cx - w * 0.007, h * 0.502,
        cx - w * 0.007, h * 0.495);
    p.close();
    return p;
  }

  // Hamstrings (back thigh)
  Path _hamRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.020, h * 0.507);
    p.cubicTo(cx + w * 0.042, h * 0.503, cx + w * 0.075, h * 0.505,
        cx + w * 0.105, h * 0.510);
    p.cubicTo(cx + w * 0.103, h * 0.577, cx + w * 0.096, h * 0.641,
        cx + w * 0.082, h * 0.702);
    p.lineTo(cx + w * 0.020, h * 0.706);
    p.cubicTo(cx + w * 0.014, h * 0.641, cx + w * 0.014, h * 0.577,
        cx + w * 0.020, h * 0.507);
    p.close();
    return p;
  }

  Path _hamLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.020, h * 0.507);
    p.cubicTo(cx - w * 0.042, h * 0.503, cx - w * 0.075, h * 0.505,
        cx - w * 0.105, h * 0.510);
    p.cubicTo(cx - w * 0.103, h * 0.577, cx - w * 0.096, h * 0.641,
        cx - w * 0.082, h * 0.702);
    p.lineTo(cx - w * 0.020, h * 0.706);
    p.cubicTo(cx - w * 0.014, h * 0.641, cx - w * 0.014, h * 0.577,
        cx - w * 0.020, h * 0.507);
    p.close();
    return p;
  }

  // Gastrocnemius (back of calf)
  Path _gastroRight(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx + w * 0.032, h * 0.714);
    p.cubicTo(cx + w * 0.044, h * 0.720, cx + w * 0.054, h * 0.752,
        cx + w * 0.056, h * 0.790);
    p.cubicTo(cx + w * 0.057, h * 0.816, cx + w * 0.050, h * 0.842,
        cx + w * 0.040, h * 0.858);
    p.cubicTo(cx + w * 0.032, h * 0.868, cx + w * 0.021, h * 0.868,
        cx + w * 0.012, h * 0.858);
    p.cubicTo(cx + w * 0.004, h * 0.844, cx + w * 0.002, h * 0.816,
        cx + w * 0.004, h * 0.790);
    p.cubicTo(cx + w * 0.007, h * 0.752, cx + w * 0.018, h * 0.720,
        cx + w * 0.032, h * 0.714);
    p.close();
    return p;
  }

  Path _gastroLeft(double cx, double w, double h) {
    final p = Path();
    p.moveTo(cx - w * 0.032, h * 0.714);
    p.cubicTo(cx - w * 0.044, h * 0.720, cx - w * 0.054, h * 0.752,
        cx - w * 0.056, h * 0.790);
    p.cubicTo(cx - w * 0.057, h * 0.816, cx - w * 0.050, h * 0.842,
        cx - w * 0.040, h * 0.858);
    p.cubicTo(cx - w * 0.032, h * 0.868, cx - w * 0.021, h * 0.868,
        cx - w * 0.012, h * 0.858);
    p.cubicTo(cx - w * 0.004, h * 0.844, cx - w * 0.002, h * 0.816,
        cx - w * 0.004, h * 0.790);
    p.cubicTo(cx - w * 0.007, h * 0.752, cx - w * 0.018, h * 0.720,
        cx - w * 0.032, h * 0.714);
    p.close();
    return p;
  }

  void _drawLabel(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: isDark ? const Color(0xFF7090B8) : const Color(0xFF8898B8),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_BodyModelPainter old) =>
      old.counts != counts ||
      old.maxCount != maxCount ||
      old.isDark != isDark;
}
