import 'dart:math';

import 'package:flutter/material.dart';

/// A checkbox that *celebrates* completion: the check pops in with an elastic
/// bounce and a short confetti burst radiates from it.
///
/// Purely visual — the caller owns persistence (and any sound) via [onChanged].
class CelebrationCheckbox extends StatefulWidget {
  const CelebrationCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.color,
    this.size = 24,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? color;
  final double size;

  @override
  State<CelebrationCheckbox> createState() => _CelebrationCheckboxState();
}

class _CelebrationCheckboxState extends State<CelebrationCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
    value: widget.value ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant CelebrationCheckbox old) {
    super.didUpdateWidget(old);
    if (widget.value && !old.value) {
      _pop.forward(from: 0);
    } else if (!widget.value && old.value) {
      _pop.reverse();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _toggle() {
    final next = !widget.value;
    widget.onChanged(next);
    if (next) _burst();
  }

  void _burst() {
    final overlay = Overlay.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null || !box.hasSize) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiBurst(
        center: center,
        seed: color,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.color ?? cs.primary;
    return InkResponse(
      onTap: _toggle,
      radius: widget.size * 0.9,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedBuilder(
          animation: _pop,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _CheckPainter(
              progress: _pop.value,
              pop: Curves.elasticOut.transform(_pop.value.clamp(0.0, 1.0)),
              color: color,
              outline: cs.outline,
              check: cs.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.progress,
    required this.pop,
    required this.color,
    required this.outline,
    required this.check,
  });

  final double progress; // raw 0..1
  final double pop; // eased (may overshoot 1)
  final Color color;
  final Color outline;
  final Color check;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.28),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color.lerp(outline, color, p)!,
    );

    if (p <= 0) return;

    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: p));

    final s = pop.clamp(0.0, 1.25);
    final cx = size.width / 2;
    final cy = size.height / 2;
    Offset at(double fx, double fy) => Offset(
          cx + (size.width * fx - cx) * s,
          cy + (size.height * fy - cy) * s,
        );
    final path = Path()
      ..moveTo(at(0.26, 0.52).dx, at(0.26, 0.52).dy)
      ..lineTo(at(0.44, 0.70).dx, at(0.44, 0.70).dy)
      ..lineTo(at(0.76, 0.31).dx, at(0.76, 0.31).dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = check.withValues(alpha: p),
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.pop != pop || old.color != color;
}

/// A one-shot confetti burst rendered in an [Overlay], removed when done.
class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst({
    required this.center,
    required this.seed,
    required this.onDone,
  });

  final Offset center;
  final Color seed;
  final VoidCallback onDone;

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  late final List<_Particle> _particles = _spawn();

  List<_Particle> _spawn() {
    final rng = Random();
    final palette = <Color>[
      widget.seed,
      Colors.amber,
      Colors.pinkAccent,
      Colors.lightBlueAccent,
      Colors.greenAccent,
    ];
    return List.generate(16, (_) {
      // Mostly upward fan.
      final angle = -pi / 2 + (rng.nextDouble() - 0.5) * pi * 1.25;
      return _Particle(
        angle: angle,
        speed: 46 + rng.nextDouble() * 80,
        color: palette[rng.nextInt(palette.length)],
        size: 4 + rng.nextDouble() * 5,
        spin: (rng.nextDouble() - 0.5) * 10,
        phase: rng.nextDouble() * pi,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _ConfettiPainter(
              center: widget.center,
              particles: _particles,
              t: _c.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.spin,
    required this.phase,
  });

  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double spin;
  final double phase;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.center,
    required this.particles,
    required this.t,
  });

  final Offset center;
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 150.0;
    final opacity = (1 - t * t).clamp(0.0, 1.0);
    for (final p in particles) {
      final dist = p.speed * t;
      final pos = center +
          Offset(cos(p.angle) * dist, sin(p.angle) * dist + gravity * t * t);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.phase + p.spin * t);
      final w = p.size * (1 - 0.25 * t);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.6),
        Paint()..color = p.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
