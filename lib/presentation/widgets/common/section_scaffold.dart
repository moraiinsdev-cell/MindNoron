import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

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
    final accentColor = accent ?? cs.primary;

    final titleText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
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

    final titleBlock = icon == null
        ? titleText
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  color: accentColor.withValues(alpha: 0.14),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
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
            EdgeInsets.fromLTRB(horizontalPadding, 22, horizontalPadding, 14),
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
            const SizedBox(height: 14),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (_, t, content) {
                  return Opacity(
                    opacity: t.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 10),
                      child: content,
                    ),
                  );
                },
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Friendly placeholder for screens/features not yet built, or empty states.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, this.label, this.icon});

  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(
            scale: 0.98 + t * 0.02,
            child: child,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerHigh,
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Icon(
                icon ?? Icons.auto_awesome_outlined,
                size: 34,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              label ?? l10n.emptyComingSoon,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
