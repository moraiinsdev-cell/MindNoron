import 'dart:math';

import 'package:flutter/material.dart';

/// A subtle, slowly drifting field of "neurons" (nodes) linked by faint synapse
/// lines — the ambient backdrop of the noron space. Deterministic orbital
/// motion (no per-frame state) keeps it cheap and seamless. Decorative only.
class NoronBackdrop extends StatefulWidget {
  const NoronBackdrop({
    super.key,
    required this.color,
    this.nodes = 24,
    this.intensity = 1.0,
  });

  final Color color;
  final int nodes;

  /// Overall opacity multiplier (0..1).
  final double intensity;

  @override
  State<NoronBackdrop> createState() => _NoronBackdropState();
}

class _NoronBackdropState extends State<NoronBackdrop>
    with SingleTickerProviderStateMixin {
  // Free-running elapsed seconds. The field is driven by a monotonic clock
  // rather than an AnimationController that ramps 0→1 and resets: because the
  // node speeds aren't whole numbers, restarting the phase every cycle made the
  // whole field visibly jump at the loop point. A clock that only ever counts
  // up keeps the orbital sin/cos motion seamless forever.
  final _seconds = ValueNotifier<double>(0);
  late final _ticker = createTicker((elapsed) {
    _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  })..start();

  // Angular speed, preserving the previous ~28s-per-revolution pace.
  static const _omega = 2 * pi / 28;

  late final List<_Node> _nodes = _make();

  List<_Node> _make() {
    final rng = Random(7);
    return List.generate(
      widget.nodes,
      (_) => _Node(
        cx: rng.nextDouble(),
        cy: rng.nextDouble(),
        orbit: 0.03 + rng.nextDouble() * 0.11,
        speed: 0.35 + rng.nextDouble() * 1.1,
        phase: rng.nextDouble() * pi * 2,
        size: 1.4 + rng.nextDouble() * 2.6,
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: RepaintBoundary(
          child: ValueListenableBuilder<double>(
            valueListenable: _seconds,
            builder: (_, seconds, __) => CustomPaint(
              size: Size.infinite,
              painter: _NoronPainter(
                nodes: _nodes,
                t: seconds * _omega,
                color: widget.color,
                intensity: widget.intensity,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Node {
  _Node({
    required this.cx,
    required this.cy,
    required this.orbit,
    required this.speed,
    required this.phase,
    required this.size,
  });

  final double cx, cy, orbit, speed, phase, size;

  Offset at(double t, Size s) => Offset(
        (cx + orbit * cos(t * speed + phase)) * s.width,
        (cy + orbit * sin(t * speed + phase * 1.3)) * s.height,
      );
}

class _NoronPainter extends CustomPainter {
  _NoronPainter({
    required this.nodes,
    required this.t,
    required this.color,
    required this.intensity,
  });

  final List<_Node> nodes;
  final double t;
  final Color color;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [for (final n in nodes) n.at(t, size)];
    final threshold = size.shortestSide * 0.2;

    final linePaint = Paint()..strokeWidth = 1;
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        final d = (pts[i] - pts[j]).distance;
        if (d >= threshold) continue;
        final a = (1 - d / threshold) * 0.22 * intensity;
        linePaint.color = color.withValues(alpha: a);
        canvas.drawLine(pts[i], pts[j], linePaint);
      }
    }

    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final pulse = 0.6 + 0.4 * sin(t * 1.5 + nodes[i].phase);
      // soft glow
      canvas.drawCircle(
        p,
        nodes[i].size * 2.6,
        Paint()..color = color.withValues(alpha: 0.06 * intensity * pulse),
      );
      // core
      canvas.drawCircle(
        p,
        nodes[i].size,
        Paint()..color = color.withValues(alpha: 0.5 * intensity * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(_NoronPainter old) =>
      old.t != t || old.color != color || old.intensity != intensity;
}
