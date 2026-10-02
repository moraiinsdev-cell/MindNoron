import 'dart:io' show Platform;
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants/app_constants.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/theme/app_theme.dart';
import '../navigation/destinations.dart';
import '../widgets/common/ui_kit.dart';
import 'window_bar.dart';

/// Sidebar collapse override: null = automatic (expanded on wide windows),
/// true = collapsed to icons, false = expanded.
final sidebarCollapsedProvider = StateProvider<bool?>((ref) => null);

/// Window width from which the sidebar expands by default.
const double kSidebarAutoExpandWidth = 1180;

const double _compactWidth = 76;
const double _expandedWidth = 244;
const double _itemHeight = 38;
const double _itemGap = 2;
const double _headerHeight = 30;
const double _hPad = 10;

/// The macOS/iPadOS-style sidebar: grouped destinations with colourful
/// iOS-Settings glyph tiles, a liquid selection pill that stretches between
/// items, and a spring morph between the expanded and icon-only layouts.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.location,
    required this.expanded,
    required this.onNavigate,
    required this.onCapture,
    this.badges = const {},
  });

  final String location;
  final bool expanded;
  final ValueChanged<AppDestination> onNavigate;
  final VoidCallback onCapture;

  /// Route → count shown as a badge.
  final Map<String, int> badges;

  @override
  Widget build(BuildContext context) {
    return SpringBuilder(
      value: expanded ? 1 : 0,
      spring: AppSprings.smooth,
      builder: (context, t, _) => SizedBox(
        width: lerpDouble(_compactWidth, _expandedWidth, t.clamp(0.0, 1.05)),
        child: _SidebarBody(
          t: t.clamp(0.0, 1.0),
          location: location,
          onNavigate: onNavigate,
          onCapture: onCapture,
          badges: badges,
        ),
      ),
    );
  }
}

class _SidebarBody extends StatelessWidget {
  const _SidebarBody({
    required this.t,
    required this.location,
    required this.onNavigate,
    required this.onCapture,
    required this.badges,
  });

  /// 0 = compact, 1 = expanded.
  final double t;
  final String location;
  final ValueChanged<AppDestination> onNavigate;
  final VoidCallback onCapture;
  final Map<String, int> badges;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final current = AppDestinations.forLocation(location);

    // Lay the groups out once so the pill knows where each item sits.
    final rows = <Widget>[];
    double y = 0;
    double? selectedTop;
    for (final group in AppDestinations.groups) {
      if (group.title != null) {
        rows.add(_GroupHeader(title: group.title!, t: t));
        y += _headerHeight;
      }
      for (final d in group.items) {
        if (d == current) selectedTop = y;
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: _itemGap),
          child: _NavItem(
            destination: d,
            selected: d == current,
            t: t,
            badge: badges[d.route] ?? 0,
            onTap: () => onNavigate(d),
          ),
        ));
        y += _itemHeight + _itemGap;
      }
    }
    final settingsSelected = current == AppDestinations.settings;

    return DecoratedBox(
      decoration: BoxDecoration(
        // A tinted, translucent sidebar material over the aurora.
        color: dark
            ? Colors.black.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.42),
        border: Border(
          right: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrandRow(t: t),
          Padding(
            padding: const EdgeInsets.fromLTRB(_hPad, 4, _hPad, 14),
            child: _CaptureButton(t: t, onTap: onCapture),
          ),
          Expanded(
            // Soft fade where the list scrolls under the edges.
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0, 8 / rect.height, 1 - 28 / rect.height, 1],
              ).createShader(rect),
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(_hPad, 4, _hPad, 0),
                  child: Stack(
                    children: [
                      if (selectedTop != null)
                        _LiquidPill(top: selectedTop, height: _itemHeight),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [...rows, const SizedBox(height: 20)],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(_hPad, 8, _hPad, 12),
            child: Stack(
              children: [
                AnimatedOpacity(
                  opacity: settingsSelected ? 1 : 0,
                  duration: AppMotion.base,
                  child: const _PillBody(height: _itemHeight),
                ),
                _NavItem(
                  destination: AppDestinations.settings,
                  selected: settingsSelected,
                  t: t,
                  badge: 0,
                  onTap: () => onNavigate(AppDestinations.settings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Selection pill whose leading edge springs ahead and trailing edge follows
/// on a softer spring — so it stretches toward the new item and settles,
/// like a drop of liquid glass.
class _LiquidPill extends StatefulWidget {
  const _LiquidPill({required this.top, required this.height});

  final double top;
  final double height;

  @override
  State<_LiquidPill> createState() => _LiquidPillState();
}

class _LiquidPillState extends State<_LiquidPill> {
  bool _movingDown = true;

  @override
  void didUpdateWidget(_LiquidPill old) {
    super.didUpdateWidget(old);
    if (old.top != widget.top) _movingDown = widget.top > old.top;
  }

  @override
  Widget build(BuildContext context) {
    final lead = AppSprings.snappy;
    final trail = AppSprings.gentle;
    return SpringBuilder(
      value: widget.top,
      spring: _movingDown ? trail : lead,
      builder: (context, top, _) => SpringBuilder(
        value: widget.top + widget.height,
        spring: _movingDown ? lead : trail,
        builder: (context, bottom, _) {
          final h = (bottom - top).clamp(widget.height * 0.6, 400.0);
          return Positioned(
            top: top,
            left: 0,
            right: 0,
            child: _PillBody(height: h),
          );
        },
      ),
    );
  }
}

class _PillBody extends StatelessWidget {
  const _PillBody({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = AppShapes.squircle(
      12,
      side: BorderSide(
        color: dark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.95),
      ),
    );
    return CustomPaint(
      painter: OutsetShadowPainter(shape: shape, shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.28 : 0.07),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ]),
      child: Container(
        height: height,
        decoration: ShapeDecoration(
          shape: shape,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.08),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.75),
                  ],
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.t});

  final String title;
  final double t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      height: _headerHeight,
      child: Stack(
        children: [
          // Compact: a short hairline separator.
          Center(
            child: Opacity(
              opacity: (1 - t * 2).clamp(0.0, 1.0),
              child: Container(
                width: 22,
                height: 1,
                color: cs.onSurface.withValues(alpha: 0.12),
              ),
            ),
          ),
          // Expanded: the group title.
          Positioned(
            left: 12,
            right: 0,
            bottom: 6,
            child: Opacity(
              opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0),
              child: Text(
                title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.t,
    required this.badge,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final double t;
  final int badge;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final d = widget.destination;
    final t = widget.t;
    final labelOpacity = ((t - 0.35) / 0.65).clamp(0.0, 1.0);

    Widget item = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pressable(
        onTap: widget.onTap,
        pressedScale: 0.96,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: _itemHeight,
          decoration: ShapeDecoration(
            color: _hover && !widget.selected
                ? cs.onSurface.withValues(alpha: 0.05)
                : Colors.transparent,
            shape: AppShapes.squircle(12),
          ),
          child: Row(
            children: [
              const SizedBox(width: 15),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconChip(
                    icon: d.icon,
                    color: d.color,
                    size: 26,
                    solid: true,
                  ),
                  // Compact: a badge dot on the tile.
                  if (widget.badge > 0)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Opacity(
                        opacity: 1 - labelOpacity,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppleColors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.surface, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: labelOpacity,
                  child: Text(
                    d.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          widget.selected ? FontWeight.w600 : FontWeight.w500,
                      color: widget.selected
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ),
              if (widget.badge > 0 && labelOpacity > 0)
                Opacity(
                  opacity: labelOpacity,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      widget.badge > 99 ? '99+' : '${widget.badge}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (t < 0.5) {
      final suffix = widget.badge > 0 ? ' · ${widget.badge}' : '';
      item = Tooltip(
        message: '${d.label}$suffix',
        preferBelow: false,
        verticalOffset: 0,
        margin: const EdgeInsets.only(left: _compactWidth),
        child: item,
      );
    }
    return Semantics(
      selected: widget.selected,
      button: true,
      label: d.label,
      child: item,
    );
  }
}

/// App mark + name at the top of the sidebar; doubles as a drag handle.
class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row = SizedBox(
      height: kWindowBarHeight + 6,
      child: Row(
        children: [
          const SizedBox(width: _hPad + 13),
          const BrandMark(size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Opacity(
              opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0),
              child: Text(
                AppConstants.appName,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'InterDisplay',
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (isDesktopPlatform &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      row = DragToMoveArea(child: row);
    }
    return row;
  }
}

/// MindNoron's mark: a neuron glyph in a luminous blue→indigo squircle.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.3;
    final shape = AppShapes.squircle(
      radius,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
    );
    return CustomPaint(
      painter: OutsetShadowPainter(
        shape: shape,
        shadows: [
          BoxShadow(
            color: AppleColors.blue.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: -3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(
          shape: shape,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppleColors.cyan, AppleColors.blue, AppleColors.indigo],
          ),
        ),
        foregroundDecoration: ShapeDecoration(
          shape: AppShapes.squircle(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.28),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, 0.55],
          ),
        ),
        child: Icon(Icons.hub_rounded, size: size * 0.56, color: Colors.white),
      ),
    );
  }
}

/// The one loud control on the sidebar: a luminous capsule that morphs into
/// a circle when the sidebar collapses.
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.t, required this.onTap});

  final double t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelOpacity = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
    return Tooltip(
      message: 'Quick capture',
      waitDuration: const Duration(milliseconds: 600),
      child: Pressable(
        onTap: onTap,
        hoverLift: 1,
        child: Container(
          height: 38,
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B9BFF), AppleColors.blue, Color(0xFF3D63F0)],
            ),
            shadows: [
              BoxShadow(
                color: AppleColors.blue.withValues(alpha: 0.38),
                blurRadius: 16,
                spreadRadius: -4,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              if (labelOpacity > 0) ...[
                SizedBox(width: 6 * labelOpacity),
                Flexible(
                  child: Opacity(
                    opacity: labelOpacity,
                    child: Text(
                      'Quick capture',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
