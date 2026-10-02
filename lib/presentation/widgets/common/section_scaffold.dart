import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../navigation/destinations.dart';
import 'ui_kit.dart';

/// Standard padded page with a header row, used by every top-level screen.
///
/// Optionally shows a tinted leading [icon] chip beside the title and animates
/// its content in on entry for a calm, consistent page feel.
class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.subtitle,
    this.icon,
    this.accent,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget child;

  /// Optional tinted glyph shown left of the title.
  final IconData? icon;

  /// Accent colour for the [icon] chip; defaults to the primary colour.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 720 ? 18.0 : 28.0;
    // Inside the shell the header chip mirrors the sidebar tile of the
    // current destination, so the page and its nav entry read as one object.
    final dest = _destinationOf(context);
    final accentColor = dest?.color ?? accent ?? cs.primary;
    final glyph = dest?.icon ?? icon;

    final titleText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    final titleBlock = glyph == null
        ? titleText
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconChip(icon: glyph, color: accentColor, size: 44, solid: true),
              const SizedBox(width: 14),
              Flexible(child: titleText),
            ],
          );

    final actionBar = actions == null
        ? null
        : Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: actions!,
          );
    final compactHeader = width < 840;

    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 6, horizontalPadding, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compactHeader && actionBar != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: actionBar,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: titleBlock),
                  if (actionBar != null)
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: actionBar,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 22),
            // The page transition already blurs the whole page in; the body
            // follows the large title a beat later for a gentle cascade.
            Expanded(
              child: Entrance(
                delay: const Duration(milliseconds: 70),
                blur: 0,
                offset: 12,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

AppDestination? _destinationOf(BuildContext context) {
  try {
    final location = GoRouterState.of(context).matchedLocation;
    for (final d in AppDestinations.all) {
      if (location.startsWith(d.route)) return d;
    }
  } catch (_) {
    // Not under the router (previews, dialogs) — use the explicit props.
  }
  return null;
}

/// Empty state: the current destination's glyph tile floating in a soft
/// halo of its colour, springing in with a little bounce, over a quiet
/// caption — the iOS "nothing here yet" moment rather than a grey void.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, this.label, this.icon, this.color});

  final String? label;
  final IconData? icon;

  /// Tint; defaults to the current destination's colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final dest = _destinationOf(context);
    final c = color ?? dest?.color ?? cs.primary;
    final dark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpringBuilder(
              value: 1,
              from: 0.6,
              spring: AppSprings.bouncy,
              builder: (context, t, child) => Opacity(
                opacity: ((t - 0.6) / 0.4).clamp(0.0, 1.0),
                child: Transform.scale(scale: t, child: child),
              ),
              child: SizedBox.square(
                dimension: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            c.withValues(alpha: dark ? 0.32 : 0.24),
                            c.withValues(alpha: 0),
                          ],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                    IconChip(
                      icon: icon ?? dest?.icon ?? Icons.auto_awesome_rounded,
                      color: c,
                      size: 60,
                      solid: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                label ?? l10n.emptyComingSoon,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
