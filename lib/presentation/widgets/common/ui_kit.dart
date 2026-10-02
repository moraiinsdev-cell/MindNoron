import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'motion.dart';

export 'motion.dart';

/// Shared premium building blocks used across feature screens so the whole app
/// reads as one system. Purely presentational — no state, no logic.

/// How much material a [GlassSurface] has — thin lets more of the backdrop
/// through, thick reads almost like a solid panel.
enum GlassLevel { thin, regular, thick }

/// Liquid Glass: a translucent squircle panel that catches light.
///
/// Layers, back to front: a soft two-part drop shadow; (optionally) a real
/// backdrop blur with a saturation boost — iOS "vibrancy"; a translucent
/// fill; a top sheen; a specular rim lit from the top-left and refracted
/// back at the bottom-right; and, when [interactive], a light that follows
/// the pointer across the surface and brightens the rim near it.
///
/// Reserve [frosted] for surfaces content scrolls behind (sidebar, dialogs,
/// pips) — plain translucency is free and looks identical over the aurora.
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppRadii.card,
    this.padding,
    this.frosted = false,
    this.opacity = 1,
    this.level = GlassLevel.regular,
    this.interactive = false,
    this.tint,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool frosted;

  /// Scales the fill strength (1 = default for [level]).
  final double opacity;
  final GlassLevel level;

  /// Track the pointer with a specular highlight (desktop hover).
  final bool interactive;

  /// Optional colour wash mixed into the glass (accent-tinted panels).
  final Color? tint;
  final bool shadow;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface>
    with SingleTickerProviderStateMixin {
  final _pointer = ValueNotifier<Offset?>(null);
  AnimationController? _hover;

  AnimationController get _hoverCtrl => _hover ??= AnimationController(
        vsync: this,
        duration: AppMotion.gentle,
        reverseDuration: AppMotion.entrance,
      );

  @override
  void dispose() {
    _pointer.dispose();
    _hover?.dispose();
    super.dispose();
  }

  static double _fillAlpha(GlassLevel level, bool dark) => switch (level) {
        GlassLevel.thin => dark ? 0.035 : 0.42,
        GlassLevel.regular => dark ? 0.06 : 0.64,
        GlassLevel.thick => dark ? 0.10 : 0.82,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final shape = AppShapes.squircle(widget.radius);
    final borderRadius = BorderRadius.circular(widget.radius);
    final alpha = _fillAlpha(widget.level, dark) * widget.opacity;
    final base = Colors.white.withValues(alpha: alpha);
    final fill = widget.tint == null
        ? base
        : Color.alphaBlend(
            widget.tint!.withValues(alpha: dark ? 0.10 : 0.08), base);

    final interactive = widget.interactive && !AppMotion.reduced(context);
    final painter = _GlassPainter(
      shape: shape,
      dark: dark,
      pointer: _pointer,
      hover: interactive ? _hoverCtrl : null,
    );

    Widget inner = CustomPaint(
      foregroundPainter: painter,
      child: ColoredBox(
        color: fill,
        child: widget.padding == null
            ? widget.child
            : Padding(padding: widget.padding!, child: widget.child),
      ),
    );

    if (widget.frosted) {
      inner = BackdropFilter(
        filter: ImageFilter.compose(
          outer: ImageFilter.blur(
            sigmaX: AppGlass.blur,
            sigmaY: AppGlass.blur,
            tileMode: TileMode.mirror,
          ),
          inner: const ColorFilter.matrix(_saturate),
        ),
        child: inner,
      );
    }

    Widget out = ClipRSuperellipse(borderRadius: borderRadius, child: inner);

    if (widget.shadow) {
      // Shadow lives outside the clip — and is masked to the outside of the
      // shape, or it would show through the translucent glass.
      out = CustomPaint(
        painter: OutsetShadowPainter(shape: shape, shadows: [
          // A wide ambient lift and a tight contact shadow, as on iOS.
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.32 : 0.08),
            blurRadius: 32,
            spreadRadius: -6,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.24 : 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ]),
        child: out,
      );
    }

    if (interactive) {
      out = MouseRegion(
        onEnter: (e) {
          _pointer.value = e.localPosition;
          _hoverCtrl.forward();
        },
        onHover: (e) => _pointer.value = e.localPosition,
        onExit: (_) => _hoverCtrl.reverse(),
        child: out,
      );
    }
    return out;
  }

  /// Saturation boost (≈ AppGlass.saturation) for the frosted backdrop.
  static const List<double> _saturate = [
    1.4248, -0.3576, -0.0672, 0, 0, //
    -0.1272, 1.3584, -0.2312, 0, 0, //
    -0.1272, -0.3576, 1.4848, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

/// Paints [shadows] for [shape] only *outside* the shape — required under
/// translucent surfaces, where a regular shadow would show through the fill.
class OutsetShadowPainter extends CustomPainter {
  const OutsetShadowPainter({required this.shape, required this.shadows});

  final ShapeBorder shape;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outline = shape.getOuterPath(rect);
    canvas.save();
    canvas.clipPath(Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(120)),
      outline,
    ));
    for (final s in shadows) {
      final r = rect.shift(s.offset).inflate(s.spreadRadius);
      canvas.drawPath(shape.getOuterPath(r), s.toPaint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(OutsetShadowPainter old) =>
      old.shape != shape || old.shadows != shadows;
}

/// Paints the light on the glass: sheen, specular rim and pointer glow.
class _GlassPainter extends CustomPainter {
  _GlassPainter({
    required this.shape,
    required this.dark,
    required this.pointer,
    required this.hover,
  }) : super(repaint: Listenable.merge([pointer, hover]));

  final ShapeBorder shape;
  final bool dark;
  final ValueNotifier<Offset?> pointer;
  final Animation<double>? hover;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Top sheen — light pooling on the upper half of the slab.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.07 : 0.38),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.55],
        ).createShader(rect),
    );

    // 2. Pointer glow — a soft light the cursor carries over the surface.
    final h = hover?.value ?? 0;
    final p = pointer.value;
    if (h > 0.001 && p != null) {
      final r = (size.longestSide * 0.55).clamp(120.0, 320.0);
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: (dark ? 0.085 : 0.32) * h),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: p, radius: r)),
      );
    }

    // 3. Specular rim — lit top-left, refracted back bottom-right.
    final rimPath = shape.getOuterPath(rect.deflate(0.5));
    canvas.drawPath(
      rimPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  Colors.white.withValues(alpha: 0.30),
                  Colors.white.withValues(alpha: 0.07),
                  Colors.white.withValues(alpha: 0.04),
                  Colors.white.withValues(alpha: 0.16),
                ]
              : [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.7),
                  Colors.white.withValues(alpha: 0.55),
                  Colors.white.withValues(alpha: 0.9),
                ],
          stops: const [0, 0.35, 0.7, 1],
        ).createShader(rect),
    );

    // 4. The rim flares where the pointer is closest.
    if (h > 0.001 && p != null) {
      const r = 140.0;
      canvas.drawPath(
        rimPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: (dark ? 0.55 : 0.9) * h),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: p, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.dark != dark || old.shape != shape || old.hover != hover;
}

/// The soft ambient wash the glass surfaces float above: large radial glows
/// in Apple's hues over the canvas, like an iOS wallpaper seen through
/// frosted glass. Static and gradient-only — the cheap fallback for the
/// living shader backdrop.
class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({super.key, this.intensity = 1});

  /// Scales the glow strength (1 = default, already subtle).
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final a = (dark ? 0.22 : 0.20) * intensity;

    Widget glow(Alignment center, Color c, double alpha, double radius) {
      return Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: center,
              radius: radius,
              colors: [
                c.withValues(alpha: alpha),
                c.withValues(alpha: alpha * 0.35),
                c.withValues(alpha: 0),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(color: cs.surface),
        child: Stack(
          children: [
            glow(const Alignment(-1.0, -1.2), AppleColors.blue, a, 1.1),
            glow(const Alignment(1.25, -0.6), AppleColors.indigo, a * 0.8, 1.0),
            glow(const Alignment(0.55, 1.4), AppleColors.purple, a * 0.55, 1.1),
            glow(const Alignment(-1.1, 1.1), AppleColors.teal, a * 0.4, 0.9),
          ],
        ),
      ),
    );
  }
}

/// A compact stat card: tinted icon chip + big value + label.
/// The canonical "focus today / tasks done" tile. Glass, with hover lift.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accentColor = accent ?? cs.primary;

    return Pressable(
      hoverLift: 2,
      child: GlassSurface(
        interactive: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: AppShapes.squircle(AppRadii.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  IconChip(icon: icon, color: accentColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app-icon-style glyph tile: a squircle filled with a luminous gradient
/// of [color], a white glyph, an inner top highlight and a coloured glow —
/// like a Settings row icon on iOS, scaled up.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
    this.solid = false,
  });

  final IconData icon;
  final Color color;
  final double size;

  /// Solid = saturated iOS app-icon fill with a white glyph. Otherwise a
  /// soft tinted glass chip with a coloured glyph.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = size * 0.3;
    final hsl = HSLColor.fromColor(color);
    final lighter =
        hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
    final chip = Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        shape: AppShapes.squircle(
          radius,
          side: BorderSide(
            color: solid
                ? Colors.white.withValues(alpha: 0.18)
                : color.withValues(alpha: dark ? 0.30 : 0.24),
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: solid
              ? [lighter, color]
              : [
                  color.withValues(alpha: dark ? 0.30 : 0.22),
                  color.withValues(alpha: dark ? 0.10 : 0.08),
                ],
        ),
      ),
      foregroundDecoration: ShapeDecoration(
        shape: AppShapes.squircle(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: solid ? 0.22 : 0.10),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.5],
        ),
      ),
      child: Icon(
        icon,
        color: solid ? Colors.white : color,
        // Small tiles need a relatively larger glyph to stay legible.
        size: size * (size < 32 ? 0.6 : 0.5),
      ),
    );
    // Coloured glow, kept outside the shape so the tinted glass stays clean.
    return CustomPaint(
      painter: OutsetShadowPainter(
        shape: AppShapes.squircle(radius),
        shadows: [
          BoxShadow(
            color: color.withValues(alpha: solid ? 0.45 : 0.22),
            blurRadius: solid ? 16 : 14,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: chip,
    );
  }
}

/// A titled section header row: optional glyph, a title, and optional trailing.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.accent,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: accent ?? cs.onSurfaceVariant),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A rounded pill with an optional leading glyph — for statuses/tags/metrics.
class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = color ?? cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: filled ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: c.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: filled ? c : cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A container with a subtle accent gradient + border — for hero/callout cards.
class AccentCard extends StatelessWidget {
  const AccentCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = accent ?? cs.primary;
    return GlassSurface(
      tint: c,
      interactive: true,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: cs.heroGradient(c)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A rounded, animated progress bar — used for gauges, energy, runway, etc.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.value,
    this.height = 10,
    this.color,
    this.background,
    this.animate = true,
  });

  /// 0..1.
  final double value;
  final double height;
  final Color? color;
  final Color? background;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = value.clamp(0.0, 1.0);
    final fill = color ?? cs.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: background ?? cs.surfaceContainerHighest,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: SpringBuilder(
                value: v,
                from: animate ? 0 : v,
                spring: AppSprings.gentle,
                builder: (context, t, _) => FractionallySizedBox(
                  widthFactor: t.clamp(0.0001, 1.0),
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [fill.withValues(alpha: 0.75), fill],
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      boxShadow: [
                        BoxShadow(
                          color: fill.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
