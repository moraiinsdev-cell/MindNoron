import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/platform/sound_service.dart';
import '../../core/providers/app_providers.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/common/celebration_checkbox.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import 'task_editor.dart';
import 'task_urgency.dart';

enum _TaskView { open, today, done }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _addController = TextEditingController();
  _TaskView _view = _TaskView.open;

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

    return SectionScaffold(
      title: l10n.navTasks,
      actions: [
        SegmentedButton<_TaskView>(
          segments: const [
            ButtonSegment(value: _TaskView.open, label: Text('Open')),
            ButtonSegment(value: _TaskView.today, label: Text('Today')),
            ButtonSegment(value: _TaskView.done, label: Text('Done')),
          ],
          selected: {_view},
          onSelectionChanged: (s) => setState(() => _view = s.first),
        ),
      ],
      child: _view == _TaskView.done
          ? const _CompletedArchive()
          : Column(
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
                Expanded(child: _buildOpenList()),
              ],
            ),
    );
  }

  Widget _buildOpenList() {
    final tasksAsync = _view == _TaskView.today
        ? ref.watch(todayTasksProvider)
        : ref.watch(openTasksProvider);
    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load tasks: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const ComingSoon(label: 'No tasks yet');
        }
        final now = DateTime.now();
        // Long-neglected tasks bubble to the top, then priority/due.
        final sorted = [...tasks]..sort((a, b) {
            final ua = taskUrgency(a, now);
            final ub = taskUrgency(b, now);
            if (ua != ub) return ub - ua;
            if (a.priority != b.priority) return a.priority - b.priority;
            final ad = a.dueDate, bd = b.dueDate;
            if (ad != null && bd != null) return ad.compareTo(bd);
            if (ad != null) return -1;
            if (bd != null) return 1;
            return a.createdAt.compareTo(b.createdAt);
          });
        return ListView.separated(
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _TaskTile(task: sorted[i]),
        );
      },
    );
  }
}

Color urgencyColor(int level, ColorScheme cs) => switch (level) {
      3 => const Color(0xFFEF4444), // red
      2 => const Color(0xFFF97316), // orange
      1 => const Color(0xFFF59E0B), // amber
      _ => cs.onSurfaceVariant,
    };

/// A top-level task with its checkable subtasks and an inline add-subtask
/// affordance. Completing a task or subtask celebrates and plays a soft cue.
class _TaskTile extends ConsumerStatefulWidget {
  const _TaskTile({required this.task});

  final Task task;

  @override
  ConsumerState<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<_TaskTile> {
  final _subController = TextEditingController();
  final _titleController = TextEditingController();
  bool _adding = false;
  bool _editing = false;

  @override
  void dispose() {
    _subController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _addSubtask() async {
    final text = _subController.text.trim();
    if (text.isEmpty) return;
    await ref
        .read(taskRepositoryProvider)
        .create(title: text, parentTaskId: widget.task.id);
    _subController.clear();
  }

  void _startEdit() {
    _titleController.text = widget.task.title;
    setState(() => _editing = true);
  }

  Future<void> _saveEdit() async {
    await ref
        .read(taskRepositoryProvider)
        .updateTitle(widget.task.id, _titleController.text);
    if (mounted) setState(() => _editing = false);
  }

  void _complete(Task task, bool nowDone) {
    ref.read(taskRepositoryProvider).toggleDone(task);
    if (nowDone) _celebrateSound();
  }

  void _setStatus(Task task, TaskStatus status) {
    final wasDone = TaskStatus.fromDb(task.status) == TaskStatus.done;
    ref.read(taskRepositoryProvider).setStatus(task.id, status);
    if (status == TaskStatus.done && !wasDone) _celebrateSound();
  }

  Future<void> _setDue() async {
    final task = widget.task;
    final picked = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await ref.read(taskRepositoryProvider).setDueDate(
          task.id,
          DateTime(picked.year, picked.month, picked.day),
        );
  }

  Future<void> _celebrateSound() async {
    final settings = ref.read(settingsRepositoryProvider);
    if (!await settings.getSoundEnabled()) return;
    final volume = await settings.getSoundVolume();
    await ref
        .read(soundServiceProvider)
        .playCue(SoundCue.taskComplete, volume: volume);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final task = widget.task;
    final repo = ref.read(taskRepositoryProvider);
    final done = TaskStatus.fromDb(task.status) == TaskStatus.done;
    final now = DateTime.now();
    final urgency = done ? 0 : taskUrgency(task, now);
    final ageColor = urgencyColor(urgency, cs);

    final subs = ref.watch(subtasksProvider(task.id)).valueOrNull ??
        const <Task>[];
    final doneSubs = subs
        .where((s) => TaskStatus.fromDb(s.status) == TaskStatus.done)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: CelebrationCheckbox(
            value: done,
            color: cs.primary,
            onChanged: (v) => _complete(task, v),
          ),
          title: _editing
              ? TextField(
                  controller: _titleController,
                  autofocus: true,
                  onSubmitted: (_) => _saveEdit(),
                  onTapOutside: (_) => _saveEdit(),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Rename task... (Enter to save)',
                  ),
                )
              : InkWell(
                  onTap: _startEdit,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      task.title,
                      style: done
                          ? TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: cs.outline,
                            )
                          : null,
                    ),
                  ),
                ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      urgency >= 2
                          ? Icons.warning_amber_rounded
                          : Icons.schedule,
                      size: 13,
                      color: ageColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      taskAgeLabel(task, now),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ageColor,
                        fontWeight:
                            urgency >= 2 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                if (subs.isNotEmpty)
                  Text(
                    '$doneSubs/${subs.length} subtasks',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                if (task.actualMinutes > 0 || task.estimatedMinutes != null)
                  Text(
                    task.estimatedMinutes != null
                        ? '${task.actualMinutes}/${task.estimatedMinutes} min'
                        : '${task.actualMinutes} min',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                if (task.context != null)
                  Text(task.context!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                if (task.isRecurring)
                  Icon(Icons.repeat, size: 13, color: cs.onSurfaceVariant),
                for (final tag in TaskRepository.tagsOf(task))
                  Text('#$tag',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.primary)),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusChip(
                status: TaskStatus.fromDb(task.status),
                onChanged: (s) => _setStatus(task, s),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showTaskEditor(context, task),
                child: _PriorityChip(priority: task.priority),
              ),
              IconButton(
                tooltip: 'Add subtask',
                icon: const Icon(Icons.playlist_add),
                onPressed: () => setState(() => _adding = !_adding),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      showTaskEditor(context, task);
                    case 'rename':
                      _startEdit();
                    case 'due':
                      _setDue();
                    case 'clearDue':
                      repo.setDueDate(task.id, null);
                    case 'delete':
                      repo.softDelete(task.id);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.tune),
                      title: Text('Edit details...'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Rename'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'due',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.event_outlined),
                      title: Text('Set due date'),
                    ),
                  ),
                  if (task.dueDate != null)
                    const PopupMenuItem(
                      value: 'clearDue',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.event_busy_outlined),
                        title: Text('Clear due date'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (subs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 44, right: 4),
            child: Column(
              children: [
                for (final sub in subs)
                  _SubtaskRow(
                    sub: sub,
                    onToggle: (v) => _complete(sub, v),
                    onDelete: () => repo.softDelete(sub.id),
                  ),
              ],
            ),
          ),
        if (_adding)
          Padding(
            padding: const EdgeInsets.only(left: 44, right: 4, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.subdirectory_arrow_right, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _subController,
                    autofocus: true,
                    onSubmitted: (_) => _addSubtask(),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Add a subtask... (Enter to save)',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Done adding',
                  icon: const Icon(Icons.check),
                  onPressed: () => setState(() => _adding = false),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.sub,
    required this.onToggle,
    required this.onDelete,
  });

  final Task sub;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = TaskStatus.fromDb(sub.status) == TaskStatus.done;
    return Row(
      children: [
        CelebrationCheckbox(
          value: done,
          size: 20,
          color: cs.secondary,
          onChanged: onToggle,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            sub.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? cs.outline : null,
                ),
          ),
        ),
        IconButton(
          tooltip: 'Delete subtask',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close, size: 16),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// Weekly recap: tasks completed in the last 7 days, grouped by day. Each can
/// be unchecked to send it back to the to-do list (e.g. if checked by mistake).
class _CompletedArchive extends ConsumerWidget {
  const _CompletedArchive();

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _dayLabel(DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${_weekdays[day.weekday - 1]} ${day.month}/${day.day}';
  }

  String _time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(recentlyCompletedProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load archive: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const ComingSoon(
              label: 'Nothing completed in the last 7 days yet');
        }
        final now = DateTime.now();
        final groups = <DateTime, List<Task>>{};
        for (final t in tasks) {
          final c = t.completedAt;
          if (c == null) continue;
          (groups[DateTime(c.year, c.month, c.day)] ??= []).add(t);
        }
        final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
        final repo = ref.read(taskRepositoryProvider);

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Text('${tasks.length} completed in the last 7 days',
                  style: theme.textTheme.titleMedium),
            ),
            Text(
              'Uncheck anything finished by mistake to send it back to your to-do list.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            for (final day in days) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 2),
                child: Text(_dayLabel(day, now),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: cs.primary)),
              ),
              for (final t in groups[day]!)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CelebrationCheckbox(
                    value: true,
                    color: cs.primary,
                    onChanged: (_) => repo.toggleDone(t),
                  ),
                  title: Text(
                    t.title,
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: cs.outline,
                    ),
                  ),
                  trailing: Text(_time(t.completedAt!),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// A tappable status pill (Pending · In progress · Finished) backed by a popup.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.onChanged});

  final TaskStatus status;
  final ValueChanged<TaskStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = status.color(cs);
    return PopupMenuButton<TaskStatus>(
      tooltip: 'Set status',
      initialValue: status,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final s in TaskStatus.selectable)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(s.icon, size: 18, color: s.color(cs)),
                const SizedBox(width: 10),
                Text(s.label),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              status.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Priority.color(priority, cs).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        Priority.label(priority),
        style: TextStyle(
          color: Priority.color(priority, cs),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
