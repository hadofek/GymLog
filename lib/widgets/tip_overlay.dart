import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymlog/utils/app_colors.dart';

enum TipDirection { above, below, left, right }

/// Wraps [child] and shows a one-time floating tip callout on first render.
///
/// The tip fires 400 ms after the widget settles (via addPostFrameCallback +
/// Future.delayed). Once dismissed — by tap or "Got it" — the key is stored in
/// SharedPreferences and the tip never fires again.
///
/// Pass [enabled: false] to conditionally suppress the tip without removing
/// the wrapper (useful in list builders where only one item should trigger).
class TipOverlay extends StatefulWidget {
  final Widget child;
  final String tipKey;
  final String tipTitle;
  final String tipBody;
  final TipDirection direction;
  final bool enabled;

  const TipOverlay({
    super.key,
    required this.child,
    required this.tipKey,
    required this.tipTitle,
    required this.tipBody,
    this.direction = TipDirection.below,
    this.enabled = true,
  });

  /// Clears all seen-tip flags so every tip will fire again on next visit.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('tip_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  @override
  State<TipOverlay> createState() => _TipOverlayState();
}

class _TipOverlayState extends State<TipOverlay> {
  final _key = GlobalKey();
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(widget.tipKey) ?? false;
      if (seen || !mounted) return;
      await prefs.setBool(widget.tipKey, true);
      _showTip();
    });
  }

  void _showTip() {
    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final targetRect = offset & size;

    _entry = OverlayEntry(
      builder: (ctx) => _TipCalloutLayer(
        targetRect: targetRect,
        direction: widget.direction,
        title: widget.tipTitle,
        body: widget.tipBody,
        onDismiss: _dismiss,
      ),
    );
    Overlay.of(context).insert(_entry!);
    if (mounted) setState(() {});
  }

  void _dismiss() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

// ─── Overlay layer ─────────────────────────────────────────────────────────────

class _TipCalloutLayer extends StatelessWidget {
  final Rect targetRect;
  final TipDirection direction;
  final String title;
  final String body;
  final VoidCallback onDismiss;

  const _TipCalloutLayer({
    required this.targetRect,
    required this.direction,
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    const cardWidth = 236.0;
    const cardEstHeight = 116.0;
    const pointerH = 8.0;
    const gap = 6.0;
    final screen = MediaQuery.of(context).size;
    final safePad = MediaQuery.of(context).padding;

    double cardLeft, cardTop;

    switch (direction) {
      case TipDirection.below:
        cardTop = targetRect.bottom + gap + pointerH;
        cardLeft = targetRect.center.dx - cardWidth / 2;
      case TipDirection.above:
        cardTop = targetRect.top - cardEstHeight - gap - pointerH;
        cardLeft = targetRect.center.dx - cardWidth / 2;
      case TipDirection.right:
        cardLeft = targetRect.right + gap + pointerH;
        cardTop = targetRect.center.dy - cardEstHeight / 2;
      case TipDirection.left:
        cardLeft = targetRect.left - cardWidth - gap - pointerH;
        cardTop = targetRect.center.dy - cardEstHeight / 2;
    }

    // Clamp to screen bounds
    cardLeft = cardLeft.clamp(12.0, screen.width - cardWidth - 12.0);
    cardTop = cardTop.clamp(
      safePad.top + 8.0,
      screen.height - safePad.bottom - cardEstHeight - 8.0,
    );

    // Pointer tip position (center of the gap between card and target)
    double? ptrLeft, ptrTop;
    bool showPointer = true;

    switch (direction) {
      case TipDirection.below:
        ptrLeft = targetRect.center.dx - pointerH;
        ptrTop = targetRect.bottom + gap - 1;
      case TipDirection.above:
        ptrLeft = targetRect.center.dx - pointerH;
        ptrTop = targetRect.top - gap - pointerH + 1;
      case TipDirection.right:
        ptrLeft = targetRect.right + gap - 1;
        ptrTop = targetRect.center.dy - pointerH;
      case TipDirection.left:
        ptrLeft = targetRect.left - gap - pointerH * 2 + 1;
        ptrTop = targetRect.center.dy - pointerH;
    }

    // Suppress pointer if it would be offscreen
    if (ptrLeft < 0 || ptrLeft > screen.width || ptrTop < 0 || ptrTop > screen.height) {
      showPointer = false;
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Full-screen tap-to-dismiss barrier
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),

          // Triangle pointer
          if (showPointer)
            Positioned(
              left: ptrLeft,
              top: ptrTop,
              child: _TrianglePointer(direction: direction, size: pointerH),
            ),

          // Card (must be last so it's above the barrier)
          Positioned(
            left: cardLeft,
            top: cardTop,
            width: cardWidth,
            child: GestureDetector(
              onTap: () {}, // eat taps so they don't hit the barrier
              child: _TipCard(title: title, body: body, onDismiss: onDismiss),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card ──────────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;

  const _TipCard({
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF1A1F2E);
    const bodyColor = Color(0xFFD8DCE8);
    const amber = AppColors.gold;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: amber,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: bodyColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onDismiss,
              child: const Text(
                'Got it',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: amber,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Triangle pointer ──────────────────────────────────────────────────────────

class _TrianglePointer extends StatelessWidget {
  final TipDirection direction;
  final double size;

  const _TrianglePointer({required this.direction, this.size = 8.0});

  @override
  Widget build(BuildContext context) {
    final isVertical = direction == TipDirection.above ||
        direction == TipDirection.below;
    final w = isVertical ? size * 2 : size;
    final h = isVertical ? size : size * 2;
    return CustomPaint(
      size: Size(w, h),
      painter: _TrianglePainter(direction: direction),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final TipDirection direction;
  const _TrianglePainter({required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1A1F2E);
    final path = Path();
    switch (direction) {
      case TipDirection.below:
        // Pointer tip faces up (card is below)
        path.moveTo(size.width / 2, 0);
        path.lineTo(0, size.height);
        path.lineTo(size.width, size.height);
      case TipDirection.above:
        // Pointer tip faces down (card is above)
        path.moveTo(0, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width / 2, size.height);
      case TipDirection.right:
        // Pointer tip faces left (card is to the right)
        path.moveTo(0, size.height / 2);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height);
      case TipDirection.left:
        // Pointer tip faces right (card is to the left)
        path.moveTo(0, 0);
        path.lineTo(0, size.height);
        path.lineTo(size.width, size.height / 2);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.direction != direction;
}
