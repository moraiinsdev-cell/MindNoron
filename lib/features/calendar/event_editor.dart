import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/event_repository.dart';
import 'event_color.dart';

/// Open the add/edit event sheet. Pass [existing] to edit, or [initialStart]
/// (and optionally [allDay]) to prefill a new event at a tapped slot/day.
Future<void> showEventEditor(
  BuildContext context, {
  CalendarEvent? existing,
  DateTime? initialStart,
  bool allDay = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EventEditor(
      existing: existing,
      initialStart: initialStart,
      initialAllDay: allDay,
    ),
  );
}

const _recurrenceOptions = {
  'none': 'Does not repeat',
  'daily': 'Every day',
  'weekly': 'Every week',
  'monthly': 'Every month',
};

const _reminderOptions = <int?, String>{
  null: 'No reminder',
  0: 'At time of event',
  5: '5 minutes before',
  10: '10 minutes before',
  15: '15 minutes before',
  30: '30 minutes before',
  60: '1 hour before',
  1440: '1 day before',
};

class _EventEditor extends ConsumerStatefulWidget {
  const _EventEditor({
    this.existing,
    this.initialStart,
    this.initialAllDay = false,
  });

  final CalendarEvent? existing;
  final DateTime? initialStart;
  final bool initialAllDay;

  @override
  ConsumerState<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<_EventEditor> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;

  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  late EventColor _color;
  late String _recurrence;
  int? _reminder;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _notes = TextEditingController(text: e?.description ?? '');
    _allDay = e?.isAllDay ?? widget.initialAllDay;

    final base = e?.startTime ??
        _roundToNextHalfHour(widget.initialStart ?? DateTime.now());
    _start = base;
    _end = e?.endTime ?? base.add(const Duration(hours: 1));
    _color = EventColor.fromName(e?.colorTag);
    _recurrence = e?.recurrenceRule ?? 'none';
    _reminder = e?.reminderMinutes;
  }

  static DateTime _roundToNextHalfHour(DateTime t) {
    final m = t.minute < 30 ? 30 : 60;
    return DateTime(t.year, t.month, t.day, t.hour).add(Duration(minutes: m));
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      final t = isStart ? _start : _end;
      final merged = DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
      if (isStart) {
        final delta = merged.difference(_start);
        _start = merged;
        if (_end.isBefore(_start)) _end = _start.add(_end.difference(_start.subtract(delta)));
        if (_end.isBefore(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = merged.isBefore(_start) ? _start.add(const Duration(hours: 1)) : merged;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (picked == null) return;
    setState(() {
      final d = isStart ? _start : _end;
      final merged = DateTime(d.year, d.month, d.day, picked.hour, picked.minute);
      if (isStart) {
        final dur = _end.difference(_start);
        _start = merged;
        _end = _start.add(dur.isNegative ? const Duration(hours: 1) : dur);
      } else {
        _end = merged.isBefore(_start) ? _start.add(const Duration(hours: 1)) : merged;
      }
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please add a title')));
      return;
    }
    final repo = ref.read(eventRepositoryProvider);
    DateTime start = _start;
    DateTime end = _end;
    if (_allDay) {
      start = DateTime(_start.year, _start.month, _start.day);
      end = DateTime(_end.year, _end.month, _end.day, 23, 59);
    }
    final rule = _recurrence == 'none' ? null : _recurrence;
    if (widget.existing == null) {
      await repo.create(
        title: title,
        startTime: start,
        endTime: end,
        isAllDay: _allDay,
        location: _empty(_location.text),
        description: _empty(_notes.text),
        colorTag: _color.name,
        recurrenceRule: rule,
        reminderMinutes: _reminder,
      );
    } else {
      await repo.update(
        widget.existing!.id,
        title: title,
        startTime: start,
        endTime: end,
        isAllDay: _allDay,
        location: _empty(_location.text),
        description: _empty(_notes.text),
        colorTag: _color.name,
        recurrenceRule: rule,
        reminderMinutes: _reminder,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  static String? _empty(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _delete() async {
    await ref.read(eventRepositoryProvider).softDelete(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(editing ? 'Edit event' : 'New event',
                        style: theme.textTheme.titleLarge),
                  ),
                  if (editing)
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _delete,
                    ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                shrinkWrap: true,
                children: [
                  TextField(
                    controller: _title,
                    autofocus: !editing,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('All day'),
                    value: _allDay,
                    onChanged: (v) => setState(() => _allDay = v),
                  ),
                  _DateTimeRow(
                    label: 'Starts',
                    dateText: _dateLabel(_start),
                    timeText: _allDay ? null : _timeLabel(_start),
                    onDate: () => _pickDate(isStart: true),
                    onTime: () => _pickTime(isStart: true),
                  ),
                  _DateTimeRow(
                    label: 'Ends',
                    dateText: _dateLabel(_end),
                    timeText: _allDay ? null : _timeLabel(_end),
                    onDate: () => _pickDate(isStart: false),
                    onTime: () => _pickTime(isStart: false),
                  ),
                  const SizedBox(height: 12),
                  Text('Colour', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in EventColor.values)
                        _ColorDot(
                          color: c.color,
                          selected: c == _color,
                          onTap: () => setState(() => _color = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _recurrence,
                    decoration: const InputDecoration(
                      labelText: 'Repeat',
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    items: [
                      for (final e in _recurrenceOptions.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _recurrence = v ?? 'none'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: _reminder,
                    decoration: const InputDecoration(
                      labelText: 'Reminder',
                      prefixIcon: Icon(Icons.notifications_outlined),
                    ),
                    items: [
                      for (final e in _reminderOptions.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _reminder = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _location,
                    decoration: const InputDecoration(
                      hintText: 'Location',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Notes',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _dateLabel(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

  String _timeLabel(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.dateText,
    required this.timeText,
    required this.onDate,
    required this.onTime,
  });

  final String label;
  final String dateText;
  final String? timeText;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: OutlinedButton(onPressed: onDate, child: Text(dateText)),
          ),
          if (timeText != null) ...[
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onTime, child: Text(timeText!)),
          ],
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.5)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
