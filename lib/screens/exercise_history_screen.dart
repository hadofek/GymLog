import 'package:flutter/material.dart';
import 'dart:math';
import 'package:gymlog/db/db_helper.dart';

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
    setState(() {
      _history = h;
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F5F5),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(widget.exerciseName,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF111111))),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final weights =
        _history.map((e) => (e['max_weight'] as num).toDouble()).toList();
    final maxWeight = weights.isEmpty ? 0.0 : weights.reduce(max);
    final totalSessions = _history.length;

    // Chart uses up to the 20 most recent sessions
    final chartHistory = _history.length > 20
        ? _history.sublist(_history.length - 20)
        : _history;
    final chartWeights =
        chartHistory.map((e) => (e['max_weight'] as num).toDouble()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.exerciseName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF111111),
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              'Exercise History',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w400),
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
                      color: const Color(0xFF111111).withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fitness_center_outlined,
                        size: 32, color: Color(0xFF999999)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No sessions logged yet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Log this exercise to see your progress',
                    style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
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

                const SizedBox(height: 20),

                // ── Chart (2+ sessions only) ──
                if (chartWeights.length >= 2) ...[
                  Container(
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Max Weight Progress',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${chartHistory.length} most recent sessions',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF888888)),
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

                // ── Sessions list (newest first) ──
                Container(
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
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            Text(
                              'All Sessions',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF5F5F5)),
                      ...List.generate(_history.length, (i) {
                        // newest first
                        final session = _history[_history.length - 1 - i];
                        final w =
                            (session['max_weight'] as num).toDouble();
                        final sets = session['set_count'] as int;
                        final isLast = i == _history.length - 1;
                        // Only mark PR if it's the first occurrence of maxWeight
                        // and there's more than 1 session
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Color(0xFF111111),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$sets set${sets != 1 ? 's' : ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF888888),
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
                                            ? const Color(0xFF8B7500)
                                            : const Color(0xFF111111),
                                      ),
                                    ),
                                  ],
                                ),
                              ]),
                            ),
                            if (!isLast)
                              const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: Color(0xFFF5F5F5)),
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

// ── Stat card ────────────────────────────────────────────────────────────────

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
        color: Colors.white,
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
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF888888),
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
              color: const Color(0xFF111111),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weight chart ─────────────────────────────────────────────────────────────

class _WeightChart extends StatelessWidget {
  final List<double> values;

  const _WeightChart({required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(values: values),
      size: Size.infinite,
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  static const _lineColor = Color(0xFFFFD700);

  const _ChartPainter({required this.values});

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

    // Gradient fill
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

    // Line
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

    // Dots: find global max index for highlighting
    int maxIdx = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[maxIdx]) maxIdx = i;
    }

    for (int i = 0; i < values.length; i++) {
      final p = pt(i);
      final isMax = i == maxIdx;
      // Outer ring for max
      if (isMax) {
        canvas.drawCircle(
            p,
            8,
            Paint()
              ..color = _lineColor.withValues(alpha: 0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
      // White background
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      // Filled dot
      canvas.drawCircle(p, isMax ? 4.5 : 3.5, Paint()..color = _lineColor);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.values != values;
}
