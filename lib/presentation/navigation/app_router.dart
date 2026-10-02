import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/activity/activity_screen.dart';
import '../../features/bible/bible_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/catalyst/catalyst_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/expenses/expenses_screen.dart';
import '../../features/habits/habits_screen.dart';
import '../../features/inbox/inbox_screen.dart';
import '../../features/journal/journal_screen.dart';
import '../../features/motivation/welcome_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/office/office_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/tax/tax_screen.dart';
import '../../features/timer/timer_screen.dart';
import '../shell/app_shell.dart';
import 'destinations.dart';

/// Root navigator key — lets background callbacks (global hotkey, tray) open
/// dialogs/routes without a widget [BuildContext].
final rootNavigatorKey = GlobalKey<NavigatorState>();

abstract final class Routes {
  static const welcome = '/welcome';
  static const dashboard = '/dashboard';
  static const office = '/office';
  static const catalyst = '/catalyst';
  static const tax = '/tax';
  static const bible = '/bible';
  static const tasks = '/tasks';
  static const calendar = '/calendar';
  static const timer = '/timer';
  static const inbox = '/inbox';
  static const notes = '/notes';
  static const journal = '/journal';
  static const habits = '/habits';
  static const expenses = '/expenses';
  static const activity = '/activity';
  static const settings = '/settings';
}

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: Routes.welcome,
  routes: [
    GoRoute(
      path: Routes.welcome,
      pageBuilder: (c, s) => _welcomePage(s, const WelcomeScreen()),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: Routes.dashboard,
          pageBuilder: (c, s) => _appPage(s, const DashboardScreen()),
        ),
        GoRoute(
          path: Routes.office,
          pageBuilder: (c, s) => _appPage(s, const OfficeScreen()),
        ),
        GoRoute(
          path: Routes.catalyst,
          pageBuilder: (c, s) => _appPage(s, const CatalystScreen()),
        ),
        GoRoute(
          path: Routes.tax,
          pageBuilder: (c, s) => _appPage(s, const TaxScreen()),
        ),
        GoRoute(
          path: Routes.bible,
          pageBuilder: (c, s) => _appPage(s, const BibleScreen()),
        ),
        GoRoute(
          path: Routes.tasks,
          pageBuilder: (c, s) => _appPage(s, const TasksScreen()),
        ),
        GoRoute(
          path: Routes.calendar,
          pageBuilder: (c, s) => _appPage(s, const CalendarScreen()),
        ),
        GoRoute(
          path: Routes.timer,
          pageBuilder: (c, s) => _appPage(s, const TimerScreen()),
        ),
        GoRoute(
          path: Routes.inbox,
          pageBuilder: (c, s) => _appPage(s, const InboxScreen()),
        ),
        GoRoute(
          path: Routes.notes,
          pageBuilder: (c, s) => _appPage(s, const NotesScreen()),
        ),
        GoRoute(
          path: Routes.journal,
          pageBuilder: (c, s) => _appPage(s, const JournalScreen()),
        ),
        GoRoute(
          path: Routes.habits,
          pageBuilder: (c, s) => _appPage(s, const HabitsScreen()),
        ),
        GoRoute(
          path: Routes.expenses,
          pageBuilder: (c, s) => _appPage(s, const ExpensesScreen()),
        ),
        GoRoute(
          path: Routes.activity,
          pageBuilder: (c, s) => _appPage(s, const ActivityScreen()),
        ),
        GoRoute(
          path: Routes.settings,
          pageBuilder: (c, s) => _appPage(s, const SettingsScreen()),
        ),
      ],
    ),
  ],
);

Page<void> _welcomePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Direction of the current navigation along the sidebar order: +1 when
/// moving down the list, -1 when moving up. Read by the transitions while
/// they run, so both the entering and the leaving page agree on it.
final _navDirection = ValueNotifier<double>(1);
String? _lastLocation;

void _trackDirection(String location) {
  if (location == _lastLocation) return;
  final all = AppDestinations.all;
  int indexOf(String? l) =>
      l == null ? -1 : all.indexWhere((d) => l.startsWith(d.route));
  final from = indexOf(_lastLocation);
  final to = indexOf(location);
  if (from >= 0 && to >= 0 && from != to) {
    _navDirection.value = to > from ? 1 : -1;
  }
  _lastLocation = location;
}

Page<void> _appPage(GoRouterState state, Widget child) {
  _trackDirection(state.matchedLocation);
  // Directional "materialise": the new page rises (or descends) into place
  // from the side of the sidebar you moved toward, unblurring as it lands;
  // the old page drifts the other way, blurs and fades — iOS 26-style depth
  // rather than a flat crossfade.
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 480),
    reverseTransitionDuration: AppMotion.base,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (AppMotion.reduced(context)) {
        return FadeTransition(opacity: animation, child: child);
      }
      return AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        child: child,
        builder: (context, child) {
          final dir = _navDirection.value;
          final enter = AppMotion.easeOutQuint.transform(animation.value);
          final exit = Curves.easeInCubic.transform(secondaryAnimation.value);
          // Entering: opacity leads, movement settles long.
          final opacity = (const Interval(0, 0.6, curve: Curves.easeOut)
                      .transform(animation.value) *
                  (1 -
                      const Interval(0, 0.55)
                          .transform(secondaryAnimation.value)))
              .clamp(0.0, 1.0);
          final dy = (1 - enter) * 26 * dir - exit * 14 * dir;
          final scale = (0.985 + 0.015 * enter) * (1 - 0.01 * exit);
          final blur = (1 - enter) * 8 + exit * 6;
          Widget out = Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.translationValues(0, dy, 0)
              ..scaleByDouble(scale, scale, 1, 1),
            child: child,
          );
          if (blur > 0.1) {
            out = ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
                tileMode: TileMode.decal,
              ),
              child: out,
            );
          }
          return Opacity(opacity: opacity, child: out);
        },
      );
    },
  );
}
