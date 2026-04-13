import 'package:flutter/material.dart';

class EdgeSwipeBack extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const EdgeSwipeBack({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack> {
  static const double _edgeWidth = 28;
  static const double _triggerDistance = 72;

  bool _tracking = false;
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        _tracking = details.globalPosition.dx <= _edgeWidth;
        _dragDistance = 0;
      },
      onHorizontalDragUpdate: (details) {
        if (!_tracking) return;
        _dragDistance += details.delta.dx;
      },
      onHorizontalDragEnd: (_) {
        if (_tracking && _dragDistance >= _triggerDistance) {
          Navigator.of(context).maybePop();
        }
        _tracking = false;
        _dragDistance = 0;
      },
      onHorizontalDragCancel: () {
        _tracking = false;
        _dragDistance = 0;
      },
      child: widget.child,
    );
  }
}
