import 'package:flutter/material.dart';
import 'dart:math';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/exercise_data.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/widgets/gymlog_wordmark.dart';
import 'package:gymlog/utils/weight_format.dart';

class ExerciseHistoryScreen extends StatefulWidget {
  final String exerciseName;
  const ExerciseHistoryScreen({super.key, required this.exerciseName});

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _isBodyweight = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DBHelper.getExerciseHistory(widget.exerciseName),
      DBHelper.isExerciseBodyweight(widget.exerciseName),
    ]);
    await WeightFormat.load();
    if (mounted) {
      setState(() {
        _history = results[0] as List<Map<String, dynamic>>;
        final flagged = results[1] as bool;
        // Also treat as bodyweight if the exercise only exists in the
        // bodyweight library (handles exercises logged before the flag was set).
        final bwNames = ExerciseData.bodyweight.values
            .expand((e) => e)
            .map((e) => e.toLowerCase())
            .toSet();
        _isBodyweight = flagged ||
            bwNames.contains(widget.exerciseName.toLowerCase());
        _loading = false;
      });
    }
  }

  static Set<int> _computePrIndices(
    List<double> chartValues,
    List<Map<String, dynamic>> fullHistory,
    bool isBodyweight, {
    required int chartStartIdx,
  }) {
    double runningMax = double.negativeInfinity;
    for (int i = 0; i < chartStartIdx; i++) {
      final v = isBodyweight
          ? (fullHistory[i]['total_reps'] as num).toDouble()
          : (fullHistory[i]['max_weight'] as num).toDouble();
      if (v > runningMax) runningMax = v;
    }
    final prIndices = <int>{};
    for (int i = 0; i < chartValues.length; i++) {
      if (chartValues[i] > runningMax) {
        prIndices.add(i);
        runningMax = chartValues[i];
      }
    }
    return prIndices;
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

  String _weightLabel(double w) => WeightFormat.format(w);

  String _rmLabel(double rm) => WeightFormat.formatRm(rm);

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

    final best1RM = _history.isEmpty
        ? 0.0
        : _history
            .map((e) => (e['best_1rm'] as num?)?.toDouble() ?? 0.0)
            .reduce(max);

    final maxReps = _history.isEmpty
        ? 0
        : _history
            .map((e) => (e['total_reps'] as num).toInt())
            .reduce((a, b) => a > b ? a : b);

    final chartHistory = _history.length > 20
        ? _history.sublist(_history.length - 20)
        : _history;
    final chartWeights =
        chartHistory.map((e) => (e['max_weight'] as num).toDouble()).toList();
    final chartReps = chartHistory
        .map((e) => (e['total_reps'] as num).toDouble())
        .toList();

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
            const GymlogWordmark(),
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
                  Icon(Icons.fitness_center_outlined,
                      size: 40, color: textSecondary),
                  const SizedBox(height: 16),
                  Text('No sessions logged yet',
                      style: KiStyles.headlineMd(color: textPrimary)),
                  const SizedBox(height: 6),
                  Text('Log this exercise to see your progress',
                      style: KiStyles.body(color: textSecondary)),
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
                      label: _isBodyweight ? 'Best Session' : 'Best Weight',
                      value: _isBodyweight
                          ? '$maxReps reps'
                          : _weightLabel(maxWeight),
                      smallValue: _isBodyweight,
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

                // ── 1RM card (weighted only) ──
                if (!_isBodyweight && best1RM > 0) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(children: [
                      Icon(Icons.emoji_events_rounded,
                          color: AppColors.accentContainer(context), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated 1-Rep Max',
                              style: KiStyles.label(color: AppColors.textTertiary(context)),
                            ),
                            Text(
                              _rmLabel(best1RM),
                              style: KiStyles.headlineLg(color: AppColors.textPrimary(context)),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  Divider(height: 1, thickness: 0.5, color: AppColors.border(context)),
                ],

                const SizedBox(height: 20),

                // ── Chart ──
                if ((_isBodyweight ? chartReps : chartWeights).length >= 2) ...[
                  const SizedBox(height: 20),
                  Text(
                    _isBodyweight ? 'Total Reps Progress' : 'Max Weight Progress',
                    style: KiStyles.bodySemibold(color: textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${chartHistory.length} most recent sessions',
                    style: KiStyles.labelSm(color: textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: _isBodyweight
                        ? 'Rep count chart over last ${chartHistory.length} sessions'
                        : 'Weight progress chart over last ${chartHistory.length} sessions',
                    child: SizedBox(
                      height: 160,
                      child: _WeightChart(
                        values: _isBodyweight ? chartReps : chartWeights,
                        prIndices: _computePrIndices(
                          _isBodyweight ? chartReps : chartWeights,
                          _history,
                          _isBodyweight,
                          chartStartIdx: _history.length > 20 ? _history.length - 20 : 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Sessions list ──
                Column(
                  children: [
                      Divider(
                          height: 1,
                          thickness: 0.5,
                          color: AppColors.divider(context)),
                      ...List.generate(_history.length, (i) {
                        final session =
                            _history[_history.length - 1 - i];
                        final w =
                            (session['max_weight'] as num).toDouble();
                        final reps = (session['total_reps'] as num).toInt();
                        final sets = session['set_count'] as int;
                        final isLast = i == _history.length - 1;
                        final isPR = _isBodyweight
                            ? reps == maxReps && totalSessions > 1
                            : w == maxWeight && totalSessions > 1;
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
                                        _formatDate(session['date'] as String),
                                        style: KiStyles.bodySemibold(color: textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$sets set${sets != 1 ? 's' : ''}',
                                        style: KiStyles.labelSm(color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPR) ...[
                                      Text('PR',
                                          style: KiStyles.labelSm(
                                              color: AppColors.accentContainer(context))),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      _isBodyweight
                                          ? '$reps reps'
                                          : _weightLabel(w),
                                      style: KiStyles.bodySemibold(color: textPrimary),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KiStyles.label(color: AppColors.textTertiary(context)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: smallValue
              ? KiStyles.bodySemibold(color: AppColors.textPrimary(context))
              : KiStyles.headlineMd(color: AppColors.textPrimary(context)),
        ),
      ],
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<double> values;
  final Set<int> prIndices;
  const _WeightChart({required this.values, this.prIndices = const {}});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(
        values: values,
        dotCenter: AppColors.cardBg(context),
        prIndices: prIndices,
      ),
      size: Size.infinite,
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  final Color dotCenter;
  final Set<int> prIndices;
  static const _lineColor = AppColors.gold;

  const _ChartPainter({
    required this.values,
    required this.dotCenter,
    this.prIndices = const {},
  });

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

    for (int i = 0; i < values.length; i++) {
      final p = pt(i);
      final isPR = prIndices.contains(i);
      // Halo ring for PR points
      if (isPR) {
        canvas.drawCircle(
          p,
          9,
          Paint()
            ..color = _lineColor.withValues(alpha: 0.25)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          p,
          9,
          Paint()
            ..color = _lineColor.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      canvas.drawCircle(p, 5, Paint()..color = dotCenter);
      canvas.drawCircle(p, isPR ? 4.5 : 3.5, Paint()..color = _lineColor);

      // "PR" label above PR points
      if (isPR) {
        const labelStyle = TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColors.gold,
          letterSpacing: 0.5,
        );
        final tp = TextPainter(
          text: const TextSpan(text: 'PR', style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - 20));
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.dotCenter != dotCenter ||
      old.prIndices != prIndices ||
      old.values.length != values.length ||
      !old.values.asMap().entries.every((e) => e.value == values[e.key]);
}
