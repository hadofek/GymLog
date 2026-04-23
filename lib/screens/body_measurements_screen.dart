import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/app_colors.dart';

class BodyMeasurementsScreen extends StatefulWidget {
  const BodyMeasurementsScreen({super.key});
  @override
  State<BodyMeasurementsScreen> createState() => _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState extends State<BodyMeasurementsScreen> {
  List<Map<String, dynamic>> _measurements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await DBHelper.getMeasurements();
    if (mounted) {
      setState(() {
        _measurements = m;
        _loading = false;
      });
    }
  }

  String _formatDate(String raw) {
    try {
      final parts = raw.trim().split(RegExp(r'\s+')).first.split('/');
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

  Future<void> _showAddDialog() async {
    final weightCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final card = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border(ctx),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Log Measurements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All fields are optional',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary(ctx)),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _buildField(
                  ctx: ctx,
                  ctrl: weightCtrl,
                  label: 'Weight (kg)',
                  hint: 'e.g. 75.5',
                  decimal: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  ctx: ctx,
                  ctrl: heightCtrl,
                  label: 'Height (cm)',
                  hint: 'e.g. 178',
                  decimal: true,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _buildField(
              ctx: ctx,
              ctrl: notesCtrl,
              label: 'Notes (optional)',
              hint: 'e.g. morning weight',
              decimal: false,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBtnBg(ctx),
                foregroundColor: AppColors.primaryBtnFg(ctx),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                textStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final weight = double.tryParse(weightCtrl.text.trim());
      final height = double.tryParse(heightCtrl.text.trim());
      final notes = notesCtrl.text.trim();
      if (weight == null && height == null) return;
      final now = DateTime.now();
      final date =
          '${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await DBHelper.insertMeasurement(
        date: date,
        weightKg: weight,
        heightCm: height,
        notes: notes,
      );
      await _load();
    }
  }

  Widget _buildField({
    required BuildContext ctx,
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required bool decimal,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary(ctx)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary(ctx)),
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.hintText(ctx)),
        filled: true,
        fillColor: AppColors.inputFill(ctx),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border(ctx), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textPrimary(ctx), width: 2),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete entry?',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(ctx))),
        content: Text('Remove this measurement?',
            style: TextStyle(color: AppColors.textSecondary(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.deleteMeasurement(id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final card = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final border = AppColors.border(context);

    // Build chart data from oldest → newest with weight values
    final withWeight = _measurements
        .where((m) => m['weight_kg'] != null)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Body Measurements',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Track your body stats over time',
              style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      floatingActionButton: Builder(
        builder: (ctx) => FloatingActionButton(
          onPressed: _showAddDialog,
          backgroundColor: AppColors.primaryBtnBg(ctx),
          foregroundColor: AppColors.primaryBtnFg(ctx),
          child: const Icon(Icons.add),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _measurements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.monitor_weight_outlined,
                            size: 32, color: AppColors.goldDark),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No measurements yet',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap + to log your first measurement',
                        style: TextStyle(fontSize: 14, color: textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    // Weight chart
                    if (withWeight.length >= 2) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weight Progress',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${withWeight.length} entries',
                              style: TextStyle(
                                  fontSize: 12, color: textSecondary),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 120,
                              child: _WeightChart(
                                values: withWeight
                                    .map((m) =>
                                        (m['weight_kg'] as num).toDouble())
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // List
                    Container(
                      decoration: BoxDecoration(
                        color: card,
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
                        children: List.generate(_measurements.length, (i) {
                          final m = _measurements[i];
                          final weight = m['weight_kg'] as double?;
                          final height = m['height_cm'] as double?;
                          final notes = m['notes'] as String? ?? '';
                          final isLast = i == _measurements.length - 1;
                          return Column(
                            children: [
                              InkWell(
                                onLongPress: () =>
                                    _confirmDelete(m['id'] as int),
                                borderRadius: BorderRadius.vertical(
                                  top: i == 0
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                                  bottom: isLast
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.gold
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                            Icons.monitor_weight_outlined,
                                            size: 20,
                                            color: AppColors.goldDark),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatDate(
                                                  m['date'] as String),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: textPrimary,
                                              ),
                                            ),
                                            if (notes.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(notes,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: textSecondary)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (weight != null)
                                            Text(
                                              '${weight % 1 == 0 ? weight.toInt() : weight.toStringAsFixed(1)} kg',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: textPrimary,
                                              ),
                                            ),
                                          if (height != null)
                                            Text(
                                              '${height % 1 == 0 ? height.toInt() : height.toStringAsFixed(1)} cm',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!isLast)
                                Divider(
                                    height: 1,
                                    color: border,
                                    indent: 16,
                                    endIndent: 16),
                            ],
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Long-press an entry to delete it',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: textSecondary),
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
          values: values, cardColor: AppColors.cardBg(context)),
      size: Size.infinite,
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  final Color cardColor;
  static const _lineColor = Color(0xFFFFD700);

  const _ChartPainter({required this.values, required this.cardColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(max);
    final minV = values.reduce(min);
    final range = maxV == minV ? 1.0 : maxV - minV;
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
            _lineColor.withValues(alpha: 0.25),
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
      canvas.drawCircle(p, 4, Paint()..color = cardColor);
      canvas.drawCircle(p, 3, Paint()..color = _lineColor);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.values != values;
}
