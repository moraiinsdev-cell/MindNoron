import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_router.dart';

/// One top-level place in the app, as the sidebar, the command palette and
/// the Ctrl+1…9 shortcuts all see it. Each has its own iOS-Settings-style
/// glyph colour so the sidebar reads at a glance.
@immutable
class AppDestination {
  const AppDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.color,
    this.keywords = '',
  });

  final String route;
  final String label;
  final IconData icon;
  final Color color;

  /// Extra search terms for the command palette.
  final String keywords;
}

/// A titled run of destinations in the sidebar. A null [title] renders
/// without a header (the home group).
@immutable
class DestinationGroup {
  const DestinationGroup(this.title, this.items);

  final String? title;
  final List<AppDestination> items;
}

abstract final class AppDestinations {
  static const dashboard = AppDestination(
    route: Routes.dashboard,
    label: 'Dashboard',
    icon: Icons.space_dashboard_rounded,
    color: AppleColors.blue,
    keywords: 'home today overview',
  );
  static const tasks = AppDestination(
    route: Routes.tasks,
    label: 'Tasks',
    icon: Icons.checklist_rounded,
    color: AppleColors.orange,
    keywords: 'todo reminders',
  );
  static const calendar = AppDestination(
    route: Routes.calendar,
    label: 'Calendar',
    icon: Icons.calendar_today_rounded,
    color: AppleColors.red,
    keywords: 'events schedule agenda',
  );
  static const focus = AppDestination(
    route: Routes.timer,
    label: 'Focus',
    icon: Icons.timer_rounded,
    color: AppleColors.indigo,
    keywords: 'timer pomodoro deep work',
  );
  static const inbox = AppDestination(
    route: Routes.inbox,
    label: 'Inbox',
    icon: Icons.inbox_rounded,
    color: AppleColors.cyan,
    keywords: 'captures triage',
  );
  static const office = AppDestination(
    route: Routes.office,
    label: 'Office',
    icon: Icons.apartment_rounded,
    color: AppleColors.teal,
    keywords: 'company team rooms',
  );
  static const catalyst = AppDestination(
    route: Routes.catalyst,
    label: 'Catalyst',
    icon: Icons.bolt_rounded,
    color: AppleColors.pink,
    keywords: 'ideas ai brainstorm',
  );
  static const notes = AppDestination(
    route: Routes.notes,
    label: 'Notes',
    icon: Icons.sticky_note_2_rounded,
    color: Color(0xFFFFB30F),
    keywords: 'docs writing',
  );
  static const journal = AppDestination(
    route: Routes.journal,
    label: 'Journal',
    icon: Icons.auto_stories_rounded,
    color: AppleColors.purple,
    keywords: 'diary reflect log',
  );
  static const habits = AppDestination(
    route: Routes.habits,
    label: 'Habits',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFF6A3D),
    keywords: 'streaks routine',
  );
  static const bible = AppDestination(
    route: Routes.bible,
    label: 'Bible',
    icon: Icons.menu_book_rounded,
    color: AppleColors.brown,
    keywords: 'verse scripture kinh thanh',
  );
  static const expenses = AppDestination(
    route: Routes.expenses,
    label: 'Expenses',
    icon: Icons.account_balance_wallet_rounded,
    color: AppleColors.mintLight,
    keywords: 'money spending budget',
  );
  static const tax = AppDestination(
    route: Routes.tax,
    label: 'Thuế',
    icon: Icons.receipt_long_rounded,
    color: AppleColors.green,
    keywords: 'tax thue income freelancer',
  );
  static const activity = AppDestination(
    route: Routes.activity,
    label: 'Activity',
    icon: Icons.insights_rounded,
    color: AppleColors.blue,
    keywords: 'stats trends heatmap',
  );
  static const settings = AppDestination(
    route: Routes.settings,
    label: 'Settings',
    icon: Icons.settings_rounded,
    color: AppleColors.gray,
    keywords: 'preferences options',
  );

  /// Sidebar layout. [settings] is pinned separately at the bottom.
  static const groups = [
    DestinationGroup(null, [dashboard]),
    DestinationGroup('Work', [tasks, calendar, focus, inbox, office, catalyst]),
    DestinationGroup('Mind', [notes, journal, habits, bible]),
    DestinationGroup('Money', [expenses, tax]),
    DestinationGroup('Insights', [activity]),
  ];

  /// Every destination in sidebar order (settings last).
  static final List<AppDestination> all = [
    for (final g in groups) ...g.items,
    settings,
  ];

  /// The destination owning [location], or [dashboard].
  static AppDestination forLocation(String location) => all.firstWhere(
        (d) => location.startsWith(d.route),
        orElse: () => dashboard,
      );
}
