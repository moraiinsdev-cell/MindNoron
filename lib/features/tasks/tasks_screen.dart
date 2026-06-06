import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/common/section_scaffold.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _addController = TextEditingController();
  bool _todayOnly = false;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    await ref.read(taskRepositoryProvider).create(title: text);
    _addController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tasksAsync = _todayOnly
        ? ref.watch(todayTasksProvider)
        : ref.watch(openTasksProvider);

    return SectionScaffold(
      title: l10n.navTasks,
      actions: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Open')),
            ButtonSegment(value: true, label: Text('Today')),
          ],
          selected: {_todayOnly},
          onSelectionChanged: (s) => setState(() => _todayOnly = s.first),
        ),
      ],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  onSubmitted: (_) => _add(),
                  decoration: const InputDecoration(
                    hintText: 'Add a task... (Enter to save)',
                    prefixIcon: Icon(Icons.add),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _add, child: const Text('Add')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load tasks: $e')),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return const ComingSoon(label: 'No tasks yet');
                }
                return ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _TaskTile(task: tasks[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final Task task;

  String _subtitle() {
    final parts = <String>[];
    final due = task.dueDate;
    if (due != null) parts.add('Due ${due.month}/${due.day}');
    if (task.actualMinutes > 0) parts.add('${task.actualMinutes} min');
    if (task.context != null) parts.add(task.context!);
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final repo = ref.read(taskRepositoryProvider);
    final done = TaskStatus.fromDb(task.status) == TaskStatus.done;
    final subtitle = _subtitle();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Checkbox(
        value: done,
        onChanged: (_) => repo.toggleDone(task),
      ),
      title: Text(
        task.title,
        style: done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: cs.outline,
              )
            : null,
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Priority.color(task.priority, cs).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              Priority.label(task.priority),
              style: TextStyle(
                color: Priority.color(task.priority, cs),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => repo.softDelete(task.id),
          ),
        ],
      ),
    );
  }
}
