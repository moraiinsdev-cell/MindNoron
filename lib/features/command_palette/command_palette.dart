import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../presentation/navigation/app_router.dart';
import '../capture/capture_dialog.dart';
import '../timer/timer_controller.dart';

/// Linear/Notion-style command palette. Summoned with Ctrl+K.
Future<void> showCommandPalette(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close command palette',
    barrierColor: Colors.black.withValues(alpha: 0.36),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, __, ___) => const CommandPalette(),
    transitionBuilder: (_, animation, __, child) {
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

class _Command {
  const _Command(this.icon, this.label, this.run);
  final IconData icon;
  final String label;
  final VoidCallback run;
}

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _Command _nav(IconData icon, String label, String route) {
    return _Command(icon, label, () {
      Navigator.of(context).pop();
      appRouter.go(route);
    });
  }

  List<_Command> _build() {
    final q = _query.trim().toLowerCase();
    final base = <_Command>[
      _nav(Icons.dashboard_outlined, 'Dashboard', Routes.dashboard),
      _nav(Icons.check_circle_outline, 'Tasks', Routes.tasks),
      _nav(Icons.timer_outlined, 'Focus', Routes.timer),
      _nav(Icons.inbox_outlined, 'Inbox', Routes.inbox),
      _nav(Icons.sticky_note_2_outlined, 'Notes', Routes.notes),
      _nav(Icons.settings_outlined, 'Settings', Routes.settings),
      _Command(Icons.add, 'Quick capture...', () {
        Navigator.of(context).pop();
        final c = rootNavigatorKey.currentContext;
        if (c != null) showCaptureDialog(c);
      }),
      _Command(Icons.play_arrow,
          'Start ${AppConstants.defaultWorkMinutes} min focus', () {
        ref.read(timerControllerProvider.notifier).start(
            duration: const Duration(minutes: AppConstants.defaultWorkMinutes));
        Navigator.of(context).pop();
        appRouter.go(Routes.timer);
      }),
    ];

    final list = q.isEmpty
        ? base
        : base.where((c) => c.label.toLowerCase().contains(q)).toList();

    if (q.isNotEmpty) {
      final tasks = ref.watch(openTasksProvider).valueOrNull ?? const <Task>[];
      for (final t
          in tasks.where((t) => t.title.toLowerCase().contains(q)).take(5)) {
        list.add(_Command(Icons.check_circle_outline, 'Task: ${t.title}', () {
          Navigator.of(context).pop();
          appRouter.go(Routes.tasks);
        }));
      }
      final notes = ref.watch(allNotesProvider).valueOrNull ?? const <Note>[];
      for (final n in notes
          .where((n) =>
              n.title.toLowerCase().contains(q) ||
              n.content.toLowerCase().contains(q))
          .take(5)) {
        final title = n.title.isEmpty ? '(untitled)' : n.title;
        list.add(_Command(Icons.sticky_note_2_outlined, 'Note: $title', () {
          Navigator.of(context).pop();
          appRouter.go(Routes.notes);
        }));
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final commands = _build();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (_) {
                    if (commands.isNotEmpty) commands.first.run();
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Type a command or search...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: commands.length,
                  itemBuilder: (_, i) {
                    final c = commands[i];
                    return ListTile(
                      leading: Icon(c.icon),
                      title: Text(c.label),
                      onTap: c.run,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
