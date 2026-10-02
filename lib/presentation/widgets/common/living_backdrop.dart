import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/theme/app_theme.dart';
import 'ui_kit.dart';

/// The four hues of the living aurora. Each area of the app has its own
/// mood; switching areas cross-fades the light behind the glass.
@immutable
class AuroraPalette {
  const AuroraPalette(this.c0, this.c1, this.c2, this.c3);

  final Color c0, c1, c2, c3;

  /// Blue → indigo → purple with a teal accent — the default iOS wash.
  static const standard = AuroraPalette(
      AppleColors.blue, AppleColors.indigo, AppleColors.purple, AppleColors.teal);

  /// Deep and calm for focus work.
  static const focus = AuroraPalette(
      AppleColors.indigo, AppleColors.purple, AppleColors.blue, AppleColors.pink);

  /// Warm sparks for ideas.
  static const spark = AuroraPalette(
      AppleColors.orange, AppleColors.pink, AppleColors.purple, AppleColors.yellow);

  /// Fresh greens for money.
  static const money = AuroraPalette(
      AppleColors.green, AppleColors.teal, AppleColors.blue, AppleColors.mint);

  /// Golden morning light for scripture.
  static const dawn = AuroraPalette(
      AppleColors.orange, AppleColors.indigo, AppleColors.pink, AppleColors.yellow);

  /// Soft, personal tones for reflection.
  static const reflect = AuroraPalette(
      AppleColors.pink, AppleColors.purple, AppleColors.indigo, AppleColors.orange);

  /// Clear blues for planning and time.
  static const plan = AuroraPalette(
      AppleColors.blue, AppleColors.cyan, AppleColors.indigo, AppleColors.mint);

  static AuroraPalette forRoute(String location) {
    bool on(String r) => location.startsWith(r);
    if (on('/timer')) return focus;
    if (on('/catalyst') || on('/office')) return spark;
    if (on('/tax') || on('/expenses')) return money;
    if (on('/bible')) return dawn;
    if (on('/journal') || on('/habits') || on('/notes')) return reflect;
    if (on('/calendar') || on('/tasks') || on('/inbox')) return plan;
    return standard;
  }

  static AuroraPalette lerp(AuroraPalette a, AuroraPalette b, double t) =>
      AuroraPalette(
        Color.lerp(a.c0, b.c0, t)!,
        Color.lerp(a.c1, b.c1, t)!,
        Color.lerp(a.c2, b.c2, t)!,
        Color.lerp(a.c3, b.c3, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is AuroraPalette &&
      other.c0 == c0 &&
      other.c1 == c1 &&
      other.c2 == c2 &&
      other.c3 == c3;

  @override
  int get hashCode => Object.hash(c0, c1, c2, c3);
}

/// A living, GPU-drawn aurora behind [child]: a slow mesh gradient
/// (shaders/aurora.frag) that drifts, cross-fades to each area's [palette],
/// and shifts subtly against the pointer for depth.
///
/// Cheap by design: drawn in its own repaint boundary at ≤30 fps, paused while
/// the window is in the background, frozen when motion is reduced. Falls back
/// to the static [AuroraBackdrop] if the shader can't load.
class LivingBackdrop extends StatefulWidget {
  const LivingBackdrop({
    super.key,
    required this.child,
    this.palette = AuroraPalette.standard,
    this.intensity = 1,
  });

  final Widget child;
  final AuroraPalette palette;
  final double intensity;

  @override
  State<LivingBackdrop> createState() => _LivingBackdropState();
}

class _LivingBackdropState extends State<LivingBackdrop>
    with TickerProviderStateMixin {
  static Future<ui.FragmentProgram?>? _programFuture;
  static final bool _underTest = Platform.environment.containsKey('FLUTTER_TEST');

  /// Seconds on the shader clock. Starts mid-flow so the first frame is
  /// already a composed picture, not every field at its origin.
  final _time = ValueNotifier<double>(_underTest ? 42 : 30);
  final _parallax = ValueNotifier<Offset>(Offset.zero);
  Offset _parallaxTarget = Offset.zero;

  ui.FragmentShader? _shader;
  late final Ticker _ticker = createTicker(_tick);
  Duration _lastPaint = Duration.zero;
  Duration _lastTick = Duration.zero;
  double _clockBase = 0;
  AppLifecycleListener? _lifecycle;
  bool _foreground = true;

  late AuroraPalette _from = widget.palette;
  late AuroraPalette _to = widget.palette;
  late final AnimationController _blend = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _programFuture ??= ui.FragmentProgram.fromAsset('shaders/aurora.frag')
        .then<ui.FragmentProgram?>((p) => p)
        .catchError((Object _) => null);
    _programFuture!.then((program) {
      if (!mounted || program == null) return;
      setState(() => _shader = program.fragmentShader());
      _syncTicker();
    });
    _lifecycle = AppLifecycleListener(onStateChange: (state) {
      _foreground = state == AppLifecycleState.resumed;
      _syncTicker();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(LivingBackdrop old) {
    super.didUpdateWidget(old);
    if (old.palette != widget.palette) {
      _from = AuroraPalette.lerp(_from, _to, _blend.value);
      _to = widget.palette;
      if (AppMotion.reduced(context)) {
        _blend.value = 1;
      } else {
        _blend.forward(from: 0);
      }
    }
  }

  bool get _shouldAnimate =>
      _shader != null &&
      !_underTest &&
      _foreground &&
      mounted &&
      !AppMotion.reduced(context);

  void _syncTicker() {
    if (!mounted) return;
    final run = _shouldAnimate;
    if (run && !_ticker.isActive) {
      _clockBase = _time.value;
      _lastPaint = Duration.zero;
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // Ease the parallax toward the pointer — frame-rate independent
    // exponential smoothing with a ~300 ms time constant.
    final k = 1 - math.exp(-dt.clamp(0.0, 0.1) / 0.3);
    final next = Offset.lerp(_parallax.value, _parallaxTarget, k)!;
    final parallaxMoved = (next - _parallax.value).distanceSquared > 1e-7;
    // The aurora drifts slowly — 30 fps is indistinguishable and halves the
    // raster cost.
    if (elapsed - _lastPaint >= const Duration(milliseconds: 33) ||
        parallaxMoved) {
      _lastPaint = elapsed;
      _time.value = _clockBase + elapsed.inMicroseconds / 1e6;
      if (parallaxMoved) _parallax.value = next;
    }
  }

  void _onHover(PointerEvent e) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    _parallaxTarget = Offset(
      (e.localPosition.dx / size.width) * 2 - 1,
      (e.localPosition.dy / size.height) * 2 - 1,
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _ticker.dispose();
    _blend.dispose();
    _time.dispose();
    _parallax.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shader = _shader;
    final backdrop = shader == null
        ? AuroraBackdrop(intensity: widget.intensity)
        : RepaintBoundary(
            child: CustomPaint(
              painter: _AuroraPainter(
                shader: shader,
                time: _time,
                parallax: _parallax,
                blend: _blend,
                from: () => _from,
                to: () => _to,
                background: theme.colorScheme.surface,
                dark: theme.brightness == Brightness.dark,
                intensity: widget.intensity,
              ),
              child: const SizedBox.expand(),
            ),
          );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: _onHover,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: IgnorePointer(child: backdrop)),
          widget.child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.shader,
    required this.time,
    required this.parallax,
    required this.blend,
    required this.from,
    required this.to,
    required this.background,
    required this.dark,
    required this.intensity,
  }) : super(repaint: Listenable.merge([time, parallax, blend]));

  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final ValueNotifier<Offset> parallax;
  final Animation<double> blend;
  final AuroraPalette Function() from;
  final AuroraPalette Function() to;
  final Color background;
  final bool dark;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeInOut.transform(blend.value.clamp(0.0, 1.0));
    final p = AuroraPalette.lerp(from(), to(), t);
    var i = 0;
    void f(double v) => shader.setFloat(i++, v);
    void rgb(Color v) {
      f(v.r);
      f(v.g);
      f(v.b);
    }

    // Light theme wants pastel light, not neon.
    void c(Color col) => rgb(dark ? col : Color.lerp(col, Colors.white, 0.35)!);

    f(size.width);
    f(size.height);
    f(time.value);
    f(intensity);
    f(parallax.value.dx);
    f(parallax.value.dy);
    rgb(background);
    c(p.c0);
    c(p.c1);
    c(p.c2);
    c(p.c3);
    f(dark ? 1 : 0);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.shader != shader ||
      old.background != background ||
      old.dark != dark ||
      old.intensity != intensity;
}
