import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Three animated bars shown on the surah that is currently playing.
/// Bars freeze in a static shape when playback is paused.
class EqualizerIcon extends StatefulWidget {
  const EqualizerIcon({
    super.key,
    required this.animating,
    required this.color,
    this.size = 22,
  });

  final bool animating;
  final Color color;
  final double size;

  @override
  State<EqualizerIcon> createState() => _EqualizerIconState();
}

class _EqualizerIconState extends State<EqualizerIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();

    if (widget.animating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant EqualizerIcon oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _bar(double phase) {
    final t = _controller.value * 2 * math.pi + phase;
    return 0.35 + 0.65 * ((math.sin(t) + 1) / 2);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final heights = widget.animating
              ? [_bar(0), _bar(2.1), _bar(4.2)]
              : const [0.45, 0.85, 0.6];

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final h in heights)
                Container(
                  width: widget.size * 0.2,
                  height: widget.size * h,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}