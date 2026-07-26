import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shared premium building blocks used across feature screens so the whole app
/// reads as one system. Purely presentational — no state, no logic.

/// A frosted-glass panel: translucent fill, hairline light border, top sheen
/// and a soft drop shadow. With [frosted] a real backdrop blur is applied —
/// reserve that for surfaces content scrolls behind (rail, dialogs, pips);
/// plain translucency is free and looks identical over the ambient backdrop.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppRadii.card,
    this.padding,
    this.frosted = false,
    this.opacity = 1,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool frosted;

  /// Scales the fill strength (1 = default glass).
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deco = cs.glass(radius: radius, opacity: opacity);
    final borderRadius = BorderRadius.circular(radius);

    Widget inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: deco.color,
        borderRadius: borderRadius,
        border: deco.border,
      ),
      foregroundDecoration: BoxDecoration(
        gradient: cs.glassSheen,
        borderRadius: borderRadius,
      ),
      child: child,
    );

    if (frosted) {
      inner = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppGlass.blur, sigmaY: AppGlass.blur),
        child: inner,
      );
    }

    return DecoratedBox(
      // Shadow lives outside the clip so it isn't cut off.
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: deco.boxShadow,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: inner),
    );
  }
}

/// Desktop hover feedback: the child rises 2px with a soft ease — the quiet
/// "this is alive" cue every pointer-driven surface should give.
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, this.dy = -2});

  final Widget child;
  final double dy;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.ease,
        transform:
            Matrix4.translationValues(0, _hovered ? widget.dy : 0, 0),
        child: widget.child,
      ),
    );
  }
}

/// Staggered entrance: fade + rise with the soft quintic landing. Give each
/// successive section a slightly larger [delay] for a cascading page build.
class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final total = delay + AppMotion.entrance;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: AppMotion.easeOutQuint,
      ),
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offset),
          child: child,
        ),
      ),
      child: child,
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

    return HoverLift(
      child: GlassSurface(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor.withValues(alpha: 0.24),
                          accentColor.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(icon, color: accentColor, size: 24),
                  ),
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: cs.heroGradient(c),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: c.withValues(alpha: 0.24)),
      ),
      foregroundDecoration: BoxDecoration(
        gradient: cs.glassSheen,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: child,
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
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: v),
                duration: animate ? const Duration(milliseconds: 700) : Duration.zero,
                curve: AppMotion.easeOutQuint,
                builder: (context, t, _) => FractionallySizedBox(
                  widthFactor: t == 0 ? 0.0001 : t,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [fill.withValues(alpha: 0.8), fill],
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
