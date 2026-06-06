import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../features/capture/capture_dialog.dart';
import '../../features/command_palette/command_palette.dart';
import '../../l10n/app_localizations.dart';
import '../navigation/app_router.dart';

/// Persistent desktop shell: a left navigation rail + the active screen.
/// Ctrl+K opens the command palette from anywhere in the app.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _routes = [
    Routes.dashboard,
    Routes.tasks,
    Routes.timer,
    Routes.inbox,
    Routes.notes,
    Routes.habits,
    Routes.settings,
  ];

  int _selectedIndex(String location) {
    final i = _routes.indexWhere((r) => location.startsWith(r));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).matchedLocation;

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
              NavigationRail(
                selectedIndex: _selectedIndex(location),
                onDestinationSelected: (i) => context.go(_routes[i]),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: FloatingActionButton(
                    heroTag: 'capture',
                    tooltip: l10n.quickCapture,
                    elevation: 0,
                    onPressed: () =>
                        showCaptureDialog(context, source: 'manual'),
                    child: const Icon(Icons.add),
                  ),
                ),
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard),
                    label: Text(l10n.navDashboard),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.check_circle_outline),
                    selectedIcon: const Icon(Icons.check_circle),
                    label: Text(l10n.navTasks),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.timer_outlined),
                    selectedIcon: const Icon(Icons.timer),
                    label: Text(l10n.navTimer),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.inbox_outlined),
                    selectedIcon: const Icon(Icons.inbox),
                    label: Text(l10n.navInbox),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.sticky_note_2_outlined),
                    selectedIcon: const Icon(Icons.sticky_note_2),
                    label: Text(l10n.navNotes),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.local_fire_department_outlined),
                    selectedIcon: const Icon(Icons.local_fire_department),
                    label: Text(l10n.navHabits),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings),
                    label: Text(l10n.navSettings),
                  ),
                ],
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
