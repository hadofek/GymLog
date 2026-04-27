import 'package:flutter/material.dart';
import 'dart:math';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';

class ExerciseHistoryScreen extends StatefulWidget {
  final String exerciseName;
  const ExerciseHistoryScreen({super.key, required this.exerciseName});

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await DBHelper.getExerciseHistory(widget.exerciseName);
    if (mounted) {
      setState(() {
        _history = h;
        _loading = false;
      });
    }
  }

  String _formatDate(String raw) {
    try {
      final datePart = raw.trim().split(RegExp(r'\s+')).first;
      final parts = datePart.split('/');
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[month - 1]} $day, $year';
    } catch (_) {
      return raw;
    }
  }

  String _shortDate(String raw) {
    try {
      final datePart = raw.trim().split(RegExp(r'\s+')).first;
      final parts = datePart.split('/');
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[int.parse(parts[1]) - 1]} ${parts[0]}';
    } catch (_) {
      return raw;
    }
  }

  String _weightLabel(double w) =>
      w % 1 == 0 ? '${w.toInt()}kg' : '${w}kg';

  String _rmLabel(double rm) =>
      rm % 1 == 0 ? '${rm.toInt()}kg' : '${rm.toStringAsFixed(1)}kg';

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final weights =
        _history.map((e) => (e['max_weight'] as num).toDouble()).toList();
    final maxWeight = weights.isEmpty ? 0.0 : weights.reduce(max);
    final totalSessions = _history.length;

    // Best estimated 1RM across all sessions
    final best1RM = _history.isEmpty
        ? 0.0
        : _history
            .map((e) => (e['best_1rm'] as num?)?.toDouble() ?? 0.0)
            .reduce(max);

    final chartHistory = _history.length > 20
        ? _history.sublist(_history.length - 20)
        : _history;
    final chartWeights =
        chartHistory.map((e) => (e['max_weight'] as num).toDouble()).toList();

    final accentContainer = AppColors.accentContainer(context);
    final textTertiary = AppColors.textTertiary(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Text(
              'GYMLOG',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 2,
                color: accentContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.exerciseName.toUpperCase(),
                style: KiStyles.label(color: textTertiary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _history.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.border(context)
                          .withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.fitness_center_outlined,
                        size: 32, color: textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sessions logged yet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Log this exercise to see your progress',
                    style: TextStyle(fontSize: 14, color: textSecondary),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Stats row ──
                Row(children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Best Weight',
                      value: _weightLabel(maxWeight),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Sessions',
                      value: '$totalSessions',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Last Session',
                      value: _shortDate(_history.last['date'] as String),
                      smallValue: true,
                    ),
                  ),
                ]),

                // ── 1RM card ──
                if (best1RM > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: AppColors.gold, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Est. 1 Rep Max',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.isDark(context)
                                    ? AppColors.textSecondary(context)
                                    : const Color(0xFFAAAAAA),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              _rmLabel(best1RM),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.gold,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Epley\nformula',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary(context),
                          height: 1.4,
                        ),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Chart ──
                if (chartWeights.length >= 2) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Max Weight Progress',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${chartHistory.length} most recent sessions',
                            style: TextStyle(
                                fontSize: 12, color: textSecondary),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 140,
                            child: _WeightChart(values: chartWeights),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Sessions list ──
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context),
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
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            Text(
                              'All Sessions',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: AppColors.divider(context)),
                      ...List.generate(_history.length, (i) {
                        final session =
                            _history[_history.length - 1 - i];
                        final w =
                            (session['max_weight'] as num).toDouble();
                        final sets = session['set_count'] as int;
                        final isLast = i == _history.length - 1;
                        final isPR =
                            w == maxWeight && totalSessions > 1;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatDate(
                                            session['date'] as String),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$sets set${sets != 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPR) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD700),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'PR',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF111111),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      _weightLabel(w),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: isPR
                                            ? AppColors.gold
                                            : textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ]),
                            ),
                            if (!isLast)
                              Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: AppColors.divider(context)),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool smallValue;

  const _StatCard({
    required this.label,
    required this.value,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: smallValue ? 14 : 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<double> values;
  const _WeightChart({required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(
          values: values, dotCenter: AppColors.cardBg(context)),
      size: Size.infinite,
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  final Color dotCenter;
  static const _lineColor = Color(0xFFFFD700);

  const _ChartPainter({required this.values, required this.dotCenter});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    if (values.length == 1) {
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 5,
          Paint()..color = _lineColor);
      return;
    }

    final maxV = values.reduce(max);
    final minV = values.reduce(min);
    final range = maxV == minV ? 1.0 : (maxV - minV);

    const hPad = 10.0;
    const vPad = 14.0;
    final chartW = size.width - hPad * 2;
    final chartH = size.height - vPad * 2;

    Offset pt(int i) {
      final x = hPad + (i / (values.length - 1)) * chartW;
      final y = vPad + (1 - (values[i] - minV) / range) * chartH;
      return Offset(x, y);
    }

    final fillPath = Path()
      ..moveTo(pt(0).dx, size.height - vPad)
      ..lineTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < values.length; i++) {
      fillPath.lineTo(pt(i).dx, pt(i).dy);
    }
    fillPath
      ..lineTo(pt(values.length - 1).dx, size.height - vPad)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _lineColor.withValues(alpha: 0.28),
            _lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final linePath = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < values.length; i++) {
      linePath.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = _lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    int maxIdx = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[maxIdx]) maxIdx = i;
    }

    for (int i = 0; i < values.length; i++) {
      final p = pt(i);
      final isMax = i == maxIdx;
      if (isMax) {
        canvas.drawCircle(
            p,
            8,
            Paint()
              ..color = _lineColor.withValues(alpha: 0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
      canvas.drawCircle(p, 5, Paint()..color = dotCenter);
      canvas.drawCircle(p, isMax ? 4.5 : 3.5, Paint()..color = _lineColor);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.values != values || old.dotCenter != dotCenter;
}
