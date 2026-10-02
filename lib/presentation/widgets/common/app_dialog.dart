import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shared modal transition: the app behind blurs and dims while the modal
/// pops in with a whisper of overshoot — iOS alert / Spotlight feel.
/// [origin] is the scale anchor (top-centre for palettes, centre for alerts).
Widget glassModalTransition(
  BuildContext context,
  Animation<double> animation,
  Widget child, {
  Alignment origin = Alignment.center,
  double fromScale = 0.92,
  double blur = 10,
}) {
  final reduced = AppMotion.reduced(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  final fade = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );
  final pop = CurvedAnimation(
    parent: animation,
    curve: AppMotion.spring,
    reverseCurve: Curves.easeInCubic,
  );
  return Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: fade,
            builder: (context, _) {
              final t = fade.value;
              final sigma = reduced ? 0.0 : blur * t;
              final dim = ColoredBox(
                color: Colors.black.withValues(alpha: (dark ? 0.40 : 0.18) * t),
              );
              if (sigma < 0.05) return dim;
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: dim,
              );
            },
          ),
        ),
      ),
      FadeTransition(
        opacity: fade,
        child: reduced
            ? child
            : AnimatedBuilder(
                animation: pop,
                child: child,
                builder: (context, child) {
                  final s = fromScale + (1 - fromScale) * pop.value;
                  return Transform(
                    alignment: origin,
                    transform: Matrix4.translationValues(
                        0, origin.y < 0 ? (1 - pop.value) * -10 : 0, 0)
                      ..scaleByDouble(s, s, 1, 1),
                    child: child,
                  );
                },
              ),
      ),
    ],
  );
}

/// Drop-in replacement for [showDialog] with the app's glass modal motion.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String barrierLabel = 'Dismiss',
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    // The transition paints its own blurred, dimmed barrier.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, _, __) => builder(context),
    transitionBuilder: (context, animation, _, child) =>
        glassModalTransition(context, animation, child),
  );
}
