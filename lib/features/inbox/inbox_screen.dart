import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/inbox_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/navigation/app_router.dart';
import '../../presentation/widgets/common/copy_button.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import '../capture/capture_dialog.dart';

/// The Inbox — everything captured lands here (the one fully wired Phase 0
/// screen: it reads live from the local Drift database).
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  Future<void> _makeTask(
    BuildContext context,
    WidgetRef ref,
    InboxItem item,
  ) async {
    await ref.read(taskRepositoryProvider).convertInboxToTask(item);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Converted to task'),
        action: SnackBarAction(
          label: 'Open tasks',
          onPressed: () => appRouter.go(Routes.tasks),
        ),
      ),
    );
  }

  Future<void> _makeNote(
    BuildContext context,
    WidgetRef ref,
    InboxItem item,
  ) async {
    await ref.read(notesRepositoryProvider).convertInboxToNote(item);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Converted to note'),
        action: SnackBarAction(
          label: 'Open notes',
          onPressed: () => appRouter.go(Routes.notes),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final itemsAsync = ref.watch(unprocessedInboxProvider);

    return SectionScaffold(
      title: l10n.navInbox,
      actions: [
        FilledButton.icon(
          onPressed: () => showCaptureDialog(context, source: 'manual'),
          icon: const Icon(Icons.add),
          label: Text(l10n.quickCapture),
        ),
      ],
      child: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load Inbox: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const ComingSoon(
              label: 'Inbox is empty. Use Quick capture (Ctrl+Shift+Space)',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final item = items[i];
              final t = item.createdAt;
              final time =
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
              return ListTile(
                leading: const Icon(Icons.fiber_manual_record, size: 12),
                title: Text(item.content),
                subtitle: Text('$time | ${item.source}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CopyIconButton(text: item.content),
                    IconButton(
                      tooltip: 'Make task',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: () => _makeTask(context, ref, item),
                    ),
                    IconButton(
                      tooltip: 'Make note',
                      icon: const Icon(Icons.sticky_note_2_outlined),
                      onPressed: () => _makeNote(context, ref, item),
                    ),
                    IconButton(
                      tooltip: 'Discard',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref.read(inboxRepositoryProvider).discard(item.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
