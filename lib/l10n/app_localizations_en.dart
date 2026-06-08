// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MindNoron';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navTimer => 'Focus';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navNotes => 'Notes';

  @override
  String get navJournal => 'Journal';

  @override
  String get navHabits => 'Habits';

  @override
  String get navExpenses => 'Expenses';

  @override
  String get navActivity => 'Activity';

  @override
  String get navSettings => 'Settings';

  @override
  String get quickCapture => 'Quick capture';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingNight => 'Working late';

  @override
  String get focusToday => 'Focus today';

  @override
  String get tasksDoneToday => 'Tasks done today';

  @override
  String get topPriorities => 'Today\'s top priorities';

  @override
  String get emptyComingSoon => 'Coming soon';

  @override
  String minutesShort(int count) {
    return '$count min';
  }
}
