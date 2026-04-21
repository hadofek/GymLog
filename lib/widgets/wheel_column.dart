import 'package:flutter/material.dart';

class WheelColumn extends StatefulWidget {
  final int initialValue;
  final int count;
  final String label;
  final ValueChanged<int> onChanged;

  const WheelColumn({
    super.key,
    required this.initialValue,
    required this.count,
    required this.label,
    required this.onChanged,
  });

  @override
  State<WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<WheelColumn> {
  late final FixedExtentScrollController _controller;
  late int _selected;

  static const double _itemExtent = 44;
  static const int _visibleItems = 5;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _controller = FixedExtentScrollController(initialItem: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const wheelHeight = _itemExtent * _visibleItems;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: wheelHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Selection zone highlight
              Container(
                height: _itemExtent,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Top fade
              Positioned(
                top: 0, left: 0, right: 0,
                height: wheelHeight / 2 - _itemExtent / 2,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom fade
              Positioned(
                bottom: 0, left: 0, right: 0,
                height: wheelHeight / 2 - _itemExtent / 2,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.white, Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
              // Wheel
              ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: _itemExtent,
                perspective: 0.002,
                diameterRatio: 1.6,
                squeeze: 1.0,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  setState(() => _selected = i);
                  widget.onChanged(i);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: widget.count,
                  builder: (ctx, i) {
                    final isSelected = i == _selected;
                    return Center(
                      child: Text(
                        i.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: isSelected ? 28 : 19,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.black
                              : Colors.black.withValues(alpha: 0.22),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(widget.label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
