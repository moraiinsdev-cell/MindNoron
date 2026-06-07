import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/activity_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/habits/habits_screen.dart';
import '../../features/inbox/inbox_screen.dart';
import '../../features/journal/journal_screen.dart';
import '../../features/motivation/welcome_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/timer/timer_screen.dart';
import '../shell/app_shell.dart';

/// Root navigator key — lets background callbacks (global hotkey, tray) open
/// dialogs/routes without a widget [BuildContext].
final rootNavigatorKey = GlobalKey<NavigatorState>();

abstract final class Routes {
  static const welcome = '/welcome';
  static const dashboard = '/dashboard';
  static const tasks = '/tasks';
  static const calendar = '/calendar';
  static const timer = '/timer';
  static const inbox = '/inbox';
  static const notes = '/notes';
  static const journal = '/journal';
  static const habits = '/habits';
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

Page<void> _appPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 360),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.018, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
