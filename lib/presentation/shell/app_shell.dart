import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/inbox_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../features/calendar/event_reminder.dart';
import '../../features/capture/capture_dialog.dart';
import '../../features/command_palette/command_palette.dart';
import '../../l10n/app_localizations.dart';
import '../navigation/app_router.dart';

/// Persistent desktop shell: a left navigation rail + the active screen.
/// Ctrl+K opens the command palette from anywhere in the app.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _routes = [
    Routes.dashboard,
    Routes.office,
    Routes.catalyst,
    Routes.tax,
    Routes.bible,
    Routes.tasks,
    Routes.calendar,
    Routes.timer,
    Routes.inbox,
    Routes.notes,
    Routes.journal,
    Routes.habits,
    Routes.expenses,
    Routes.activity,
    Routes.settings,
  ];

  int _selectedIndex(String location) {
    final i = _routes.indexWhere((r) => location.startsWith(r));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).matchedLocation;
    // Keep the event-reminder poller alive for the life of the app shell.
    ref.watch(eventReminderProvider);
    final openTaskCount = ref.watch(openTasksProvider).maybeWhen(
          data: (tasks) => tasks.length,
          orElse: () => 0,
        );
    final inboxUnreadCount = ref.watch(unprocessedInboxProvider).maybeWhen(
          data: (items) => items.length,
          orElse: () => 0,
        );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            showCommandPalette(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              // Let the rail scroll when the window is too short for all the
              // destinations (otherwise the last items overflow vertically).
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                selectedIndex: _selectedIndex(location),
                onDestinationSelected: (i) => context.go(_routes[i]),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Column(
                    children: [
                      const _RailBrand(),
                      const SizedBox(height: 16),
                      FloatingActionButton(
                        heroTag: 'capture',
                        tooltip: l10n.quickCapture,
                        elevation: 0,
                        onPressed: () =>
                            showCaptureDialog(context, source: 'manual'),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard),
                    label: Text(l10n.navDashboard),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.apartment_outlined),
                    selectedIcon: const Icon(Icons.apartment),
                    label: Text(l10n.navOffice),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.bolt_outlined),
                    selectedIcon: Icon(Icons.bolt),
                    label: Text('Catalyst'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: Text('Thuế'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: Text('Kinh Thánh'),
                  ),
                  NavigationRailDestination(
                    icon: _BadgedRailIcon(
                      icon: Icons.check_circle_outline,
                      count: openTaskCount,
                      tooltip: '$openTaskCount open tasks',
                    ),
                    selectedIcon: _BadgedRailIcon(
                      icon: Icons.check_circle,
                      count: openTaskCount,
                      tooltip: '$openTaskCount open tasks',
                    ),
                    label: Text(l10n.navTasks),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.calendar_month_outlined),
                    selectedIcon: const Icon(Icons.calendar_month),
                    label: Text(l10n.navCalendar),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.timer_outlined),
                    selectedIcon: const Icon(Icons.timer),
                    label: Text(l10n.navTimer),
                  ),
                  NavigationRailDestination(
                    icon: _BadgedRailIcon(
                      icon: Icons.inbox_outlined,
                      count: inboxUnreadCount,
                      tooltip: '$inboxUnreadCount unread inbox items',
                    ),
                    selectedIcon: _BadgedRailIcon(
                      icon: Icons.inbox,
                      count: inboxUnreadCount,
                      tooltip: '$inboxUnreadCount unread inbox items',
                    ),
                    label: Text(l10n.navInbox),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.sticky_note_2_outlined),
                    selectedIcon: const Icon(Icons.sticky_note_2),
                    label: Text(l10n.navNotes),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.auto_stories_outlined),
                    selectedIcon: const Icon(Icons.auto_stories),
                    label: Text(l10n.navJournal),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.local_fire_department_outlined),
                    selectedIcon: const Icon(Icons.local_fire_department),
                    label: Text(l10n.navHabits),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: const Icon(Icons.account_balance_wallet),
                    label: Text(l10n.navExpenses),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.insights_outlined),
                    selectedIcon: const Icon(Icons.insights),
                    label: Text(l10n.navActivity),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings),
                    label: Text(l10n.navSettings),
                  ),
                ],
                      ),
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brand mark pinned to the top of the navigation rail — a gradient neuron
/// glyph that doubles as a subtle identity anchor for the whole shell.
class _RailBrand extends StatelessWidget {
  const _RailBrand();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: AppConstants.appName,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.seed, AppTheme.accentBlue],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.seed.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(Icons.hub_rounded, size: 22, color: cs.surface),
      ),
    );
  }
}

class _BadgedRailIcon extends StatelessWidget {
  const _BadgedRailIcon({
    required this.icon,
    required this.count,
    required this.tooltip,
  });

  final IconData icon;
  final int count;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeLabel = count > 99 ? '99+' : '$count';

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 36,
        height: 32,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon),
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                scale: count > 0 ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      badgeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onError,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
