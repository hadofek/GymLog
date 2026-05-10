import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/widgets/gymlog_wordmark.dart';
import 'package:gymlog/utils/weight_format.dart';

class BodyMeasurementsScreen extends StatefulWidget {
  const BodyMeasurementsScreen({super.key});
  @override
  State<BodyMeasurementsScreen> createState() => _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState extends State<BodyMeasurementsScreen> {
  List<Map<String, dynamic>> _measurements = [];
  bool _loading = true;
  double? _profileHeight;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DBHelper.getMeasurements(),
      SharedPreferences.getInstance(),
    ]);
    final m = results[0] as List<Map<String, dynamic>>;
    final prefs = results[1] as SharedPreferences;
    await WeightFormat.load();
    if (mounted) {
      setState(() {
        _measurements = m;
        _profileHeight = prefs.getDouble('user_height_cm');
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
    final bodyFatCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final bodyFatFocus = FocusNode();
    final notesFocus = FocusNode();
    final card = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);
    final borderColor = AppColors.border(context);
    final inputFill = AppColors.inputFill(context);

    InputDecoration fieldDec(String label, String hint) => InputDecoration(
          labelText: label,
          labelStyle: KiStyles.labelSm(color: textTertiary),
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.hintText(context)),
          filled: true,
          fillColor: inputFill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accentContainer, width: 1.5),
          ),
        );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 24 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Log Measurements', style: KiStyles.headlineMd(color: textPrimary)),
            const SizedBox(height: 4),
            Text('All fields are optional', style: KiStyles.labelSm(color: textSecondary)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(ctx).requestFocus(bodyFatFocus),
                  style: KiStyles.body(color: textPrimary),
                  decoration: fieldDec(WeightFormat.inputLabel, 'e.g. 75.5'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: bodyFatCtrl,
                  focusNode: bodyFatFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(ctx).requestFocus(notesFocus),
                  style: KiStyles.body(color: textPrimary),
                  decoration: fieldDec('Body fat (%)', 'e.g. 18.5'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              focusNode: notesFocus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(ctx).unfocus(),
              style: KiStyles.body(color: textPrimary),
              decoration: fieldDec('Notes (optional)', 'e.g. morning weight'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBtnBg(ctx),
                  foregroundColor: AppColors.primaryBtnFg(ctx),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Save',
                    style: KiStyles.bodySemibold(
                        color: AppColors.primaryBtnFg(ctx))),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final weight = double.tryParse(weightCtrl.text.trim());
      final bodyFat = double.tryParse(bodyFatCtrl.text.trim());
      final notes = notesCtrl.text.trim();
      if (weight == null && bodyFat == null) return;
      final now = DateTime.now();
      final date =
          '${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await DBHelper.insertMeasurement(
        date: date,
        weightKg: weight,
        bodyFatPct: bodyFat,
        notes: notes,
      );
      await _load();
    }
  }

  Future<void> _deleteMeasurement(Map<String, dynamic> m) async {
    final id = m['id'] as int;
    await DBHelper.deleteMeasurement(id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Measurement deleted',
            style: KiStyles.body(color: AppColors.textPrimary(context))),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardBg(context),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.accentContainer(context),
          onPressed: () async {
            await DBHelper.insertMeasurement(
              date: m['date'] as String,
              weightKg: m['weight_kg'] as double?,
              bodyFatPct: m['body_fat_pct'] as double?,
              notes: m['notes'] as String? ?? '',
            );
            await _load();
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);
    final borderColor = AppColors.border(context);
    final errorColor = AppColors.error(context);

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
        title: Row(
          children: [
            const GymlogWordmark(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'MEASUREMENTS',
                style: KiStyles.label(color: textTertiary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: accentContainer,
        foregroundColor: AppColors.primaryBtnFg(context),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add, size: 20),
        label: Text('Log', style: KiStyles.bodySemibold(color: AppColors.primaryBtnFg(context))),
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
                          color: accentContainer.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.monitor_weight_outlined,
                            size: 32, color: accentContainer),
                      ),
                      const SizedBox(height: 16),
                      Text('No measurements yet',
                          style: KiStyles.headlineMd(color: textPrimary)),
                      const SizedBox(height: 6),
                      Text('Tap Log to record your first entry',
                          style: KiStyles.body(color: textSecondary)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    // ── Weight chart ──
                    if (withWeight.length >= 2) ...[
                      Text('Weight Progress',
                          style: KiStyles.bodySemibold(color: textPrimary)),
                      const SizedBox(height: 2),
                      Text('${withWeight.length} entries',
                          style: KiStyles.labelSm(color: textSecondary)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: _WeightChart(
                          values: withWeight
                              .map((m) => (m['weight_kg'] as num).toDouble())
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Divider(height: 1, thickness: 0.5, color: borderColor),
                    ],

                    // ── Height context line ──
                    if (_profileHeight != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Text('HEIGHT', style: KiStyles.label(color: textTertiary)),
                            const Spacer(),
                            Text(
                              '${_profileHeight!.toInt()} cm  ·  set in Profile',
                              style: KiStyles.labelSm(color: textTertiary),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 0.5, color: borderColor),
                    ],

                    // ── Measurements list ──
                    ...List.generate(_measurements.length, (i) {
                      final m = _measurements[i];
                      final weight = m['weight_kg'] as double?;
                      final bodyFat = m['body_fat_pct'] as double?;
                      final notes = m['notes'] as String? ?? '';

                      return Dismissible(
                        key: ValueKey('meas-${m['id']}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteMeasurement(m),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: errorColor.withValues(alpha: 0.12),
                          child: Icon(Icons.delete_outline, color: errorColor, size: 20),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatDate(m['date'] as String),
                                          style: KiStyles.bodySemibold(color: textPrimary),
                                        ),
                                        if (notes.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(notes,
                                              style: KiStyles.labelSm(color: textSecondary)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (weight != null)
                                        Text(
                                          WeightFormat.format(weight),
                                          style: KiStyles.bodySemibold(color: textPrimary),
                                        ),
                                      if (bodyFat != null)
                                        Text(
                                          '${bodyFat % 1 == 0 ? bodyFat.toInt() : bodyFat.toStringAsFixed(1)}% fat',
                                          style: KiStyles.labelSm(color: textSecondary),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                                height: 1,
                                thickness: 0.5,
                                color: borderColor),
                          ],
                        ),
                      );
                    }),
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
          values: values, cardColor: AppColors.background(context)),
      size: Size.infinite,
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  final Color cardColor;
  static const _lineColor = AppColors.gold;

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
  bool shouldRepaint(_ChartPainter old) =>
      old.values.length != values.length ||
      !old.values.asMap().entries.every((e) => e.value == values[e.key]);
}
