import '../../l10n/app_localizations.dart';

/// Returns a time-of-day greeting using the active localization.
String greetingFor(AppLocalizations l10n, [DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour >= 5 && hour < 12) return l10n.greetingMorning;
  if (hour >= 12 && hour < 18) return l10n.greetingAfternoon;
  if (hour >= 18 && hour < 23) return l10n.greetingEvening;
  return l10n.greetingNight;
}
