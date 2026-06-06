/// Suggests a focus-session length tuned to today's energy level (1..5),
/// scaling the user's configured [workMinutes] up on high-energy days and down
/// on low-energy ones. Unknown energy (0/null) keeps the configured length.
///
/// Rounded to the nearest 5 and clamped to a sane range. Pure → unit-tested.
int suggestFocusMinutes(int energy, int workMinutes) {
  final factor = switch (energy) {
    1 => 0.6,
    2 => 0.8,
    4 => 1.15,
    5 => 1.3,
    _ => 1.0, // 3 or unknown → as configured
  };
  final raw = (workMinutes * factor).round();
  final rounded = (raw / 5).round() * 5;
  return rounded.clamp(5, 90);
}

/// A short rationale for the suggestion, shown next to it on the timer setup.
String focusSuggestionHint(int energy) => switch (energy) {
      1 => 'Low energy — a short, kind sprint',
      2 => 'A little low — keep it light',
      4 => 'Good energy — go a bit longer',
      5 => 'High energy — ride the momentum',
      _ => 'Balanced focus block',
    };
