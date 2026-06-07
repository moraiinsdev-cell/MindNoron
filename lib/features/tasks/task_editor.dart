import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';

/// Recurrence options stored as a simple RRULE-style string (PLAN.md §4.2).
const _recurrenceOptions = <String?, String>{
  null: 'Does not repeat',
  'daily': 'Daily',
  'weekly': 'Weekly',
  'monthly': 'Monthly',
};

/// Opens the full task editor for [task]. Exposes every editable field that the
/// inline list cannot: description, priority, due date + time, estimated time,
/// context, tags, and recurrence.
Future<void> showTaskEditor(BuildContext context, Task task) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TaskEditorDialog(task: task),
  );
}

class _TaskEditorDialog extends ConsumerStatefulWidget {
  const _TaskEditorDialog({required this.task});

  final Task task;

  @override
  ConsumerState<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends ConsumerState<_TaskEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _tagInput;

  late int _priority;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  int? _estimatedMinutes;
  String? _context;
  late List<String> _tags;
  String? _recurrence;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t.title);
    _description = TextEditingController(text: t.description ?? '');
    _tagInput = TextEditingController();
    _priority = t.priority;
    _estimatedMinutes = t.estimatedMinutes;
    _context = t.context;
    _tags = TaskRepository.tagsOf(t);
    _recurrence = t.recurrenceRule;
    final due = t.dueDate;
    if (due != null) {
      _dueDate = DateTime(due.year, due.month, due.day);
      if (due.hour != 0 || due.minute != 0) {
        _dueTime = TimeOfDay(hour: due.hour, minute: due.minute);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  /// Combine the chosen date + optional time into a single stored due value.
  DateTime? get _combinedDue {
    final d = _dueDate;
    if (d == null) return null;
    final t = _dueTime;
    return DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  void _addTag() {
    final value = _tagInput.text.trim();
    if (value.isEmpty || _tags.contains(value)) {
      _tagInput.clear();
      return;
    }
    setState(() => _tags = [..._tags, value]);
    _tagInput.clear();
  }

  Future<void> _save() async {
    await ref.read(taskRepositoryProvider).updateDetails(
          id: widget.task.id,
          title: _title.text,
          description:
              _description.text.trim().isEmpty ? null : _description.text.trim(),
          priority: _priority,
          dueDate: _combinedDue,
          estimatedMinutes: _estimatedMinutes,
          context: _context,
          tags: _tags,
          recurrenceRule: _recurrence,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final contexts = ref.watch(contextsProvider).valueOrNull ?? const [];
    final dueLabel = _dueDate == null
        ? 'No due date'
        : '${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}';

    return AlertDialog(
      title: const Text('Edit task'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              const _Label('Priority'),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (var p = 1; p <= 4; p++)
                    ButtonSegment(
                      value: p,
                      label: Text(Priority.label(p)),
                    ),
                ],
                selected: {_priority},
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
              const SizedBox(height: 20),
              const _Label('Due'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(dueLabel, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _dueDate == null ? null : _pickTime,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(
                        _dueTime?.format(context) ?? 'No time',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      tooltip: 'Clear due',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _dueDate = null;
                        _dueTime = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const _Label('Estimated time'),
              const SizedBox(height: 8),
              _MinutesStepper(
                minutes: _estimatedMinutes,
                onChanged: (v) => setState(() => _estimatedMinutes = v),
              ),
              const SizedBox(height: 20),
              const _Label('Context'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('None'),
                    selected: _context == null,
                    onSelected: (_) => setState(() => _context = null),
                  ),
                  for (final c in contexts)
                    ChoiceChip(
                      label: Text(c),
                      selected: _context == c,
                      onSelected: (_) => setState(() => _context = c),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const _Label('Tags'),
              const SizedBox(height: 8),
              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _tags)
                      InputChip(
                        label: Text(tag),
                        onDeleted: () =>
                            setState(() => _tags = [..._tags]..remove(tag)),
                      ),
                  ],
                ),
              if (_tags.isNotEmpty) const SizedBox(height: 8),
              TextField(
                controller: _tagInput,
                onSubmitted: (_) => _addTag(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Add a tag...',
                  prefixIcon: const Icon(Icons.label_outline, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addTag,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _Label('Repeat'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _recurrence,
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (final entry in _recurrenceOptions.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (v) => setState(() => _recurrence = v),
              ),
              if (widget.task.estimatedMinutes != null ||
                  widget.task.actualMinutes > 0) ...[
                const SizedBox(height: 16),
                Text(
                  'Logged so far: ${widget.task.actualMinutes} min',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }
}

/// Stepper for an optional minute estimate (off → 15 → 30 … in 15-min steps).
class _MinutesStepper extends StatelessWidget {
  const _MinutesStepper({required this.minutes, required this.onChanged});

  final int? minutes;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = minutes ?? 0;
    return Row(
      children: [
        IconButton.outlined(
          icon: const Icon(Icons.remove),
          onPressed: value <= 0
              ? null
              : () {
                  final next = value - 15;
                  onChanged(next <= 0 ? null : next);
                },
        ),
        SizedBox(
          width: 90,
          child: Text(
            minutes == null ? 'Not set' : '$minutes min',
            textAlign: TextAlign.center,
          ),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.add),
          onPressed: () => onChanged((value + 15).clamp(15, 600)),
        ),
      ],
    );
  }
}
