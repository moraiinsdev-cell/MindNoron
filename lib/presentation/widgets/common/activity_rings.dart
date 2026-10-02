import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'motion.dart';

/// One ring: [progress] (1 = goal met; may exceed 1) drawn as a gradient
/// from [start] to [end].
@immutable
class RingSpec {
  const RingSpec({
    required this.progress,
    required this.start,
    required this.end,
  });

  final double progress;
  final Color start;
  final Color end;

  /// Apple-Watch-style hues.
  static const focusStart = Color(0xFFFA114F);
  static const focusEnd = Color(0xFFFF5E8E);
  static const tasksStart = Color(0xFF7ED321);
  static const tasksEnd = Color(0xFFB8FF4A);
  static const habitsStart = Color(0xFF00C8E6);
  static const habitsEnd = Color(0xFF6FF7FF);
}

/// Concentric progress rings that wind up on a spring, like the Activity
/// rings on Apple Watch. Overflow past 100% keeps winding, with a shadow
/// under the leading cap so the overlap reads as depth.
class ActivityRings extends StatelessWidget {
  const ActivityRings({
    super.key,
    required this.rings,
    this.size = 160,
    this.stroke = 18,
    this.gap = 4,
  });

  final List<RingSpec> rings;
  final double size;
  final double stroke;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < rings.length; i++)
            SpringBuilder(
              value: rings[i].progress,
              from: 0,
              spring: AppSprings.gentle,
              builder: (context, p, _) => CustomPaint(
                painter: _RingPainter(
                  ring: rings[i],
                  progress: p,
                  index: i,
                  stroke: stroke,
                  gap: gap,
                  dark: dark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.ring,
    required this.progress,
    required this.index,
    required this.stroke,
    required this.gap,
    required this.dark,
  });

  final RingSpec ring;
  final double progress;
  final int index;
  final double stroke;
  final double gap;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke / 2 - index * (stroke + gap);
    if (r <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    const top = -math.pi / 2;

    // Track.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = ring.start.withValues(alpha: dark ? 0.20 : 0.16),
    );

    final p = progress.clamp(0.0, 4.0);
    if (p <= 0.002) return;

    Paint arcPaint(double sweep) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.max(sweep, 0.001),
        colors: [ring.start, ring.end],
        transform: const GradientRotation(top),
      ).createShader(rect);

    const full = 2 * math.pi;
    if (p <= 1) {
      canvas.drawArc(rect, top, full * p, false, arcPaint(full * p));
    } else {
      // Completed lap, then the overflow lap on top.
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = ring.end,
      );
      final over = full * (p - p.floorToDouble());
      canvas.drawArc(rect, top, over, false, arcPaint(over));
    }

    // Leading cap with a soft shadow, so the ring's head sits *over* its tail.
    final angle = top + full * p;
    final head = c + Offset(math.cos(angle), math.sin(angle)) * r;
    if (p > 0.92) {
      final tangent = Offset(-math.sin(angle), math.cos(angle));
      canvas.drawCircle(
        head + tangent * (stroke * 0.12),
        stroke / 2,
        Paint()
          ..color = Colors.black.withValues(alpha: dark ? 0.55 : 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.18),
      );
    }
    canvas.drawCircle(head, stroke / 2, Paint()..color = ring.end);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.ring != ring ||
      old.dark != dark ||
      old.stroke != stroke;
}

/// A single compact ring with a centred label — for tiles and lists.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.color = AppleColors.blue,
    this.size = 44,
    this.stroke = 5,
    this.child,
  });

  final double progress;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    final end =
        hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ActivityRings(
            size: size,
            stroke: stroke,
            rings: [RingSpec(progress: progress, start: color, end: end)],
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
