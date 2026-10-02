import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/inbox_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../features/calendar/event_reminder.dart';
import '../../features/capture/capture_dialog.dart';
import '../../features/command_palette/command_palette.dart';
import '../navigation/destinations.dart';
import '../widgets/common/living_backdrop.dart';
import 'sidebar.dart';
import 'window_bar.dart';

/// Persistent desktop shell: a frameless window with a living aurora, a
/// grouped glass sidebar and a unified toolbar over the active screen.
///
/// Shortcuts: Ctrl+K command palette · Ctrl+\ toggle sidebar ·
/// Ctrl+1…9 jump to the first nine destinations.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final wide =
        MediaQuery.sizeOf(context).width >= kSidebarAutoExpandWidth;
    final collapsedOverride = ref.watch(sidebarCollapsedProvider);
    final expanded = collapsedOverride == null ? wide : !collapsedOverride;
    void toggleSidebar() =>
        ref.read(sidebarCollapsedProvider.notifier).state = expanded;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            showCommandPalette(context),
        const SingleActivator(LogicalKeyboardKey.backslash, control: true):
            toggleSidebar,
        for (var i = 0; i < _digits.length; i++)
          SingleActivator(_digits[i], control: true): () =>
              context.go(AppDestinations.all[i].route),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          // The living aurora every glass surface floats above; each area
          // of the app tints it with its own mood.
          body: LivingBackdrop(
            palette: AuroraPalette.forRoute(location),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Sidebar(
                  location: location,
                  expanded: expanded,
                  onNavigate: (d) => context.go(d.route),
                  onCapture: () =>
                      showCaptureDialog(context, source: 'manual'),
                  badges: {
                    AppDestinations.tasks.route: openTaskCount,
                    AppDestinations.inbox.route: inboxUnreadCount,
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WindowBar(
                        leading: IconButton(
                          tooltip: expanded
                              ? 'Hide sidebar (Ctrl+\\)'
                              : 'Show sidebar (Ctrl+\\)',
                          iconSize: 20,
                          visualDensity: VisualDensity.compact,
                          onPressed: toggleSidebar,
                          icon: const Icon(Icons.view_sidebar_outlined),
                        ),
                        center: SpotlightPill(
                          onTap: () => showCommandPalette(context),
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
