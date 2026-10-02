import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common/ui_kit.dart';

/// Height of the unified title/toolbar strip.
const double kWindowBarHeight = 44;

bool get _liveWindow =>
    isDesktopPlatform && !Platform.environment.containsKey('FLUTTER_TEST');

/// The frameless window's unified toolbar: drag anywhere empty to move the
/// window (double-click to maximize), with [leading], a centred [center] slot
/// (the Spotlight pill) and the window controls on the right.
class WindowBar extends StatelessWidget {
  const WindowBar({super.key, this.leading, this.center});

  final Widget? leading;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    Widget bar = SizedBox(
      height: kWindowBarHeight,
      child: Row(
        children: [
          const SizedBox(width: 10),
          if (leading != null) leading!,
          Expanded(
            child: center == null ? const SizedBox() : Center(child: center),
          ),
          if (isDesktopPlatform) const WindowControls(),
        ],
      ),
    );
    if (_liveWindow) bar = DragToMoveArea(child: bar);
    return bar;
  }
}

/// Minimal minimize / maximize / close controls, drawn as hairline glyphs
/// (Fluent geometry, Apple restraint). Close glows red on hover.
class WindowControls extends StatefulWidget {
  const WindowControls({super.key});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (_liveWindow) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((v) {
        if (mounted) setState(() => _maximized = v);
      });
    }
  }

  @override
  void dispose() {
    if (_liveWindow) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CaptionButton(
          glyph: _Glyph.minimize,
          tooltip: 'Minimize',
          onTap: () => windowManager.minimize(),
        ),
        _CaptionButton(
          glyph: _maximized ? _Glyph.restore : _Glyph.maximize,
          tooltip: _maximized ? 'Restore' : 'Maximize',
          onTap: () => _maximized
              ? windowManager.unmaximize()
              : windowManager.maximize(),
        ),
        _CaptionButton(
          glyph: _Glyph.close,
          tooltip: 'Close',
          danger: true,
          // Routed through the close-to-tray guard (onWindowClose).
          onTap: () => windowManager.close(),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}

enum _Glyph { minimize, maximize, restore, close }

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.glyph,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  final _Glyph glyph;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = !_hover
        ? Colors.transparent
        : widget.danger
            ? AppleColors.red
            : cs.onSurface.withValues(alpha: 0.09);
    final fg = _hover && widget.danger
        ? Colors.white
        : cs.onSurface.withValues(alpha: _hover ? 0.95 : 0.6);
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 700),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Pressable(
          onTap: widget.onTap,
          pressedScale: 0.9,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.ease,
            width: 40,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: ShapeDecoration(
              color: bg,
              shape: AppShapes.squircle(AppRadii.sm),
            ),
            child: CustomPaint(painter: _GlyphPainter(widget.glyph, fg)),
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const s = 5.0;
    switch (glyph) {
      case _Glyph.minimize:
        canvas.drawLine(c + const Offset(-s, 0), c + const Offset(s, 0), p);
      case _Glyph.maximize:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: s * 2, height: s * 2),
              const Radius.circular(2)),
          p,
        );
      case _Glyph.restore:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: c + const Offset(-1, 1), width: 8, height: 8),
              const Radius.circular(1.6)),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 2.5, c.dy - 3.5)
            ..lineTo(c.dx - 2.5, c.dy - 4.5)
            ..lineTo(c.dx + 4.5, c.dy - 4.5)
            ..lineTo(c.dx + 4.5, c.dy + 2.5)
            ..lineTo(c.dx + 3.5, c.dy + 2.5),
          p,
        );
      case _Glyph.close:
        canvas.drawLine(c + const Offset(-s, -s), c + const Offset(s, s), p);
        canvas.drawLine(c + const Offset(s, -s), c + const Offset(-s, s), p);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

/// The centred "Search or jump to…" capsule that opens the command palette —
/// Spotlight's entry point, always one glance away.
class SpotlightPill extends StatelessWidget {
  const SpotlightPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, minWidth: 220),
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: GlassSurface(
          radius: AppRadii.pill,
          level: GlassLevel.thin,
          interactive: true,
          shadow: false,
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.search_rounded, size: 17, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search or jump to…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ),
                const KeyHint('Ctrl K'),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small keycap label, e.g. "Ctrl K" or "↵".
class KeyHint extends StatelessWidget {
  const KeyHint(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: ShapeDecoration(
        color: cs.onSurface.withValues(alpha: 0.07),
        shape: AppShapes.squircle(
          6,
          side: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
