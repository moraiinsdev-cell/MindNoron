import 'package:flutter/widgets.dart';

/// Motion tokens — one fluid, Apple-like timing language for the whole app.
///
/// Two families:
/// * **Durations + curves** ([fast], [base], [ease]…) for implicit widgets
///   that only take a duration (AnimatedContainer, AnimatedOpacity…).
/// * **Springs** ([AppSprings]) for anything that moves. Springs keep their
///   velocity when retargeted mid-flight, which is what makes iOS feel
///   physical instead of scripted. Prefer them via `SpringBuilder`.
///
/// Every motion widget honours [reduced] — the OS "reduce motion" flag or the
/// in-app setting (both surface as `MediaQuery.disableAnimations`).
abstract final class AppMotion {
  /// Hover feedback, small state flips.
  static const Duration fast = Duration(milliseconds: 160);

  /// Default transitions: selection, colour, reveal.
  static const Duration base = Duration(milliseconds: 260);

  /// Route changes, larger movements.
  static const Duration gentle = Duration(milliseconds: 380);

  /// Page/section entrances.
  static const Duration entrance = Duration(milliseconds: 520);

  /// The workhorse ease — fast start, long soft landing.
  static const Curve ease = Curves.easeOutCubic;

  /// Extra-soft landing for entrances (quintic).
  static const Curve easeOutQuint = Cubic(0.22, 1, 0.36, 1);

  /// Apple's default UIKit-style ease-in-out, for symmetric morphs.
  static const Curve easeInOut = Cubic(0.42, 0, 0.58, 1);

  /// A whisper of overshoot for scale-ins — never bouncy, just alive.
  static const Curve spring = Cubic(0.34, 1.3, 0.64, 1);

  /// Whether motion should be minimised for this subtree.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Spring presets mirroring SwiftUI's `.snappy`, `.smooth` and `.bouncy`.
/// `duration` is the perceptual settle time; `bounce` the overshoot (0 = none).
abstract final class AppSprings {
  /// Press feedback, toggles, small selections. Quick and crisp.
  static final SpringDescription snappy =
      SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 320),
    bounce: 0.12,
  );

  /// The default for layout and position changes — no overshoot.
  static final SpringDescription smooth =
      SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 480),
  );

  /// Playful arrivals: badges, confirmations, the selection pill.
  static final SpringDescription bouncy =
      SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 520),
    bounce: 0.28,
  );

  /// Large, calm movements: page content settling, sheets.
  static final SpringDescription gentle =
      SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 720),
    bounce: 0.04,
  );
}
