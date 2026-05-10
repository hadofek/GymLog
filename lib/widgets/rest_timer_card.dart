import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';

class RestTimerCard extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onDismiss;
  final ValueNotifier<int>? externalTickNotifier;
  final int? initialTarget;
  final ValueChanged<int?>? onTargetChanged;

  const RestTimerCard({
    super.key,
    required this.accentColor,
    required this.onDismiss,
    this.externalTickNotifier,
    this.initialTarget,
    this.onTargetChanged,
  });

  @override
  State<RestTimerCard> createState() => _RestTimerCardState();
}

class _RestTimerCardState extends State<RestTimerCard> {
  late final ValueNotifier<int> _tickNotifier;
  Timer? _timer;
  int? _target;
  bool _editing = false;
  final _minCtrl = TextEditingController();
  final _secCtrl = TextEditingController();
  final _secFocus = FocusNode();
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _target = widget.initialTarget;
    if (widget.externalTickNotifier != null) {
      _tickNotifier = widget.externalTickNotifier!;
    } else {
      _tickNotifier = ValueNotifier<int>(0);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _tickNotifier.value++;
      });
    }
  }

  @override
  void dispose() {
    if (widget.externalTickNotifier == null) {
      _tickNotifier.dispose();
    }
    _timer?.cancel();
    _minCtrl.dispose();
    _secCtrl.dispose();
    _secFocus.dispose();
    super.dispose();
  }

  void _submitTarget() {
    final minTxt = _minCtrl.text.trim();
    final secTxt = _secCtrl.text.trim();
    final minVal = minTxt.isEmpty ? null : int.tryParse(minTxt);
    final secVal = secTxt.isEmpty ? null : int.tryParse(secTxt);

    if (minVal == null && secVal == null) {
      setState(() => _inputError = 'Enter a time');
      return;
    }
    final totalSec = (minVal ?? 0) * 60 + (secVal ?? 0);
    if (totalSec <= 0) {
      setState(() => _inputError = 'Enter a time');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _editing = false;
      _inputError = null;
      _target = totalSec;
    });
    widget.onTargetChanged?.call(totalSec);
  }

  String _fmt(int ticks) {
    final m = ticks ~/ 60;
    final s = (ticks % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final textTertiary = AppColors.textTertiary(context);
    final errorCol = AppColors.error(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ValueListenableBuilder<int>(
        valueListenable: _tickNotifier,
        builder: (ctx, ticks, _) {
          final target = _target;
          final isOvertime = target != null && ticks >= target;
          final timerColor = isOvertime ? errorCol : widget.accentColor;

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: BoxDecoration(
              color: AppColors.inputFill(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOvertime
                    ? errorCol.withValues(alpha: 0.5)
                    : AppColors.border(context),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: dot + REST label + timer + edit + X ──
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                          color: timerColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    ExcludeSemantics(
                      child: Text('REST',
                          style: KiStyles.labelSm(color: textTertiary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: 'Rest time: ${_fmt(ticks)}',
                        child: Text(
                          _fmt(ticks),
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: timerColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    // Edit / confirm icon
                    Semantics(
                      label: _editing
                          ? 'Confirm target time'
                          : 'Set target time',
                      button: true,
                      child: GestureDetector(
                        onTap: _editing
                            ? _submitTarget
                            : () => setState(() {
                                  _editing = true;
                                  _inputError = null;
                                  _minCtrl.clear();
                                  _secCtrl.clear();
                                }),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          child: Icon(
                            _editing
                                ? Icons.check_rounded
                                : Icons.edit_rounded,
                            size: 16,
                            color: textTertiary,
                          ),
                        ),
                      ),
                    ),
                    // Dismiss icon
                    Semantics(
                      label: 'Dismiss rest timer',
                      button: true,
                      child: GestureDetector(
                        onTap: widget.onDismiss,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: textTertiary),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Edit mode: min:sec input ──
                if (_editing) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      RestTimerTimeField(
                        controller: _minCtrl,
                        hint: 'min',
                        accentColor: widget.accentColor,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_secFocus),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(':',
                            style: KiStyles.headlineMd(
                                color: textTertiary)),
                      ),
                      RestTimerTimeField(
                        controller: _secCtrl,
                        hint: 'sec',
                        focusNode: _secFocus,
                        accentColor: widget.accentColor,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitTarget(),
                      ),
                      if (_inputError != null) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(_inputError!,
                              style:
                                  KiStyles.labelSm(color: errorCol)),
                        ),
                      ],
                    ],
                  ),

                // ── Progress bar (target set, not editing) ──
                ] else if (target != null) ...[
                  const SizedBox(height: 8),
                  LayoutBuilder(builder: (_, constraints) {
                    final progress = (ticks / target).clamp(0.0, 1.0);
                    return Stack(
                      children: [
                        Container(
                          height: 3,
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: widget.accentColor
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: 3,
                          width: constraints.maxWidth * progress,
                          decoration: BoxDecoration(
                            color: timerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'TARGET ${_fmt(target)}',
                        style: KiStyles.labelSm(
                            color: isOvertime ? errorCol : textTertiary),
                      ),
                      if (isOvertime) ...[
                        const SizedBox(width: 6),
                        Text(
                          '+${_fmt(ticks - target)}',
                          style: KiStyles.labelSm(color: errorCol),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// Small time input field helper
class RestTimerTimeField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final Color accentColor;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const RestTimerTimeField({
    super.key,
    required this.controller,
    required this.hint,
    required this.accentColor,
    required this.textInputAction,
    this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textInputAction: textInputAction,
        style: KiStyles.bodySemibold(color: AppColors.textPrimary(context)),
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: KiStyles.body(color: AppColors.hintText(context)),
          labelText: hint,
          labelStyle: KiStyles.labelSm(color: AppColors.textTertiary(context)),
          filled: true,
          fillColor: AppColors.inputFill(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: AppColors.border(context))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: accentColor, width: 2)),
        ),
      ),
    );
  }
}
