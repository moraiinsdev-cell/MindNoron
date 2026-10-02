import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../core/theme/app_theme.dart';

/// Spring-driven motion primitives. Every widget here:
/// * runs on a physical spring ([AppSprings]) — retargeting mid-flight keeps
///   the current velocity, so interrupted motion never jerks;
/// * snaps straight to its end state when motion is reduced
///   ([AppMotion.reduced]).

/// Implicitly animates [value] with a spring and rebuilds with the live value.
///
/// The spring analogue of [TweenAnimationBuilder]: change [value] and the
/// output glides there, carrying whatever velocity it already had. Pass
/// [from] to also animate in on first build.
class SpringBuilder extends StatefulWidget {
  const SpringBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.from,
    this.spring,
    this.child,
  });

  final double value;
  final double? from;
  final SpringDescription? spring;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  State<SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<SpringBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.from ?? widget.value,
  );

  @override
  void initState() {
    super.initState();
    if (widget.from != null && widget.from != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateTo(widget.value);
      });
    }
  }

  @override
  void didUpdateWidget(SpringBuilder old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _animateTo(widget.value);
  }

  void _animateTo(double target) {
    if (AppMotion.reduced(context)) {
      _c.value = target;
      return;
    }
    _c.animateWith(SpringSimulation(
      widget.spring ?? AppSprings.smooth,
      _c.value,
      target,
      _c.velocity,
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => widget.builder(context, _c.value, child),
        child: widget.child,
      );
}

/// The universal "this is touchable" response: a soft spring lift on hover
/// and a squish on press, released with a crisp rebound.
///
/// Listens to raw pointer events, so it never competes with the child's own
/// gestures — wrap an InkWell/button and both work.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.hoverLift = 0,
    this.hoverScale = 1,
    this.enabled = true,
    this.cursor,
  });

  final Widget child;

  /// Optional tap handler (for children that don't handle taps themselves).
  final VoidCallback? onTap;
  final double pressedScale;

  /// Pixels to rise on hover (positive = up).
  final double hoverLift;
  final double hoverScale;
  final bool enabled;
  final MouseCursor? cursor;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool v) {
    if (widget.enabled && v != _hovered) setState(() => _hovered = v);
  }

  void _setPressed(bool v) {
    if (widget.enabled && v != _pressed) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed
        ? widget.pressedScale
        : (_hovered ? widget.hoverScale : 1.0);
    final lift = _hovered && !_pressed ? widget.hoverLift : 0.0;

    Widget child = SpringBuilder(
      value: scale,
      // Press in snappy, release with a little life.
      spring: _pressed ? AppSprings.snappy : AppSprings.bouncy,
      builder: (context, s, child) => SpringBuilder(
        value: lift,
        spring: AppSprings.snappy,
        builder: (context, dy, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.translationValues(0, -dy, 0)
            ..scaleByDouble(s, s, 1, 1),
          child: child,
        ),
        child: child,
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: child,
      );
    }

    return MouseRegion(
      cursor: widget.cursor ??
          (widget.onTap != null && widget.enabled
              ? SystemMouseCursors.click
              : MouseCursor.defer),
      onEnter: (_) => _setHovered(true),
      onExit: (_) {
        _setHovered(false);
        _setPressed(false);
      },
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: child,
      ),
    );
  }
}

/// Desktop hover feedback: the child rises a couple of pixels on a spring —
/// the quiet "this is alive" cue every pointer-driven surface should give.
class HoverLift extends StatelessWidget {
  const HoverLift({super.key, required this.child, this.dy = -2});

  final Widget child;

  /// Vertical offset on hover (negative = up), kept for older call sites.
  final double dy;

  @override
  Widget build(BuildContext context) =>
      Pressable(hoverLift: -dy, pressedScale: 0.985, child: child);
}

/// Staggered entrance: the child blurs, fades and rises into place on a
/// gentle spring — iOS's "materialise" feel. Give each successive section a
/// slightly larger [delay] for a cascading page build.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 16,
    this.scale = 0.985,
    this.blur = 6,
  });

  final Widget child;
  final Duration delay;

  /// Starting vertical offset in pixels.
  final double offset;

  /// Starting scale (1 = none).
  final double scale;

  /// Starting blur sigma (0 = none).
  final double blur;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController.unbounded(vsync: this);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _run();
    } else {
      _timer = Timer(widget.delay, _run);
    }
  }

  void _run() {
    if (!mounted) return;
    _c.animateWith(SpringSimulation(AppSprings.gentle, 0, 1, 0));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        if (t >= 0.999 && !_c.isAnimating) return child!;
        final inv = (1 - t);
        Widget out = Transform(
          alignment: Alignment.topCenter,
          transform: Matrix4.translationValues(0, inv * widget.offset, 0)
            ..scaleByDouble(
              1 - inv * (1 - widget.scale),
              1 - inv * (1 - widget.scale),
              1,
              1,
            ),
          child: child,
        );
        final sigma = (inv * widget.blur).clamp(0.0, widget.blur);
        if (sigma > 0.05) {
          out = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: out,
          );
        }
        return Opacity(opacity: t.clamp(0.0, 1.0), child: out);
      },
    );
  }
}

/// Lays out [children] in a column, each arriving with a staggered
/// [Entrance] — the standard way a page or a card list builds in.
class StaggeredColumn extends StatelessWidget {
  const StaggeredColumn({
    super.key,
    required this.children,
    this.step = const Duration(milliseconds: 55),
    this.initialDelay = Duration.zero,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.maxStaggered = 10,
  });

  final List<Widget> children;
  final Duration step;
  final Duration initialDelay;
  final CrossAxisAlignment crossAxisAlignment;

  /// Items past this index share the last delay so long lists don't trickle.
  final int maxStaggered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          Entrance(
            delay: initialDelay + step * (i < maxStaggered ? i : maxStaggered),
            child: children[i],
          ),
      ],
    );
  }
}
