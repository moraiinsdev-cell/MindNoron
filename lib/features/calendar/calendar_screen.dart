import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/event_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import 'agenda_view.dart';
import 'calendar_item.dart';
import 'calendar_utils.dart';
import 'event_editor.dart';
import 'month_view.dart';
import 'time_grid_view.dart';

enum _CalView { month, week, day, agenda }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _CalView _view = _CalView.month;
  DateTime _anchor = CalendarUtils.dayOnly(DateTime.now());

  DateTimeRange get _range {
    switch (_view) {
      case _CalView.month:
        final first = DateTime(_anchor.year, _anchor.month, 1);
        final start = CalendarUtils.weekStart(first);
        return DateTimeRange(start: start, end: start.add(const Duration(days: 42)));
      case _CalView.week:
        final start = CalendarUtils.weekStart(_anchor);
        return DateTimeRange(start: start, end: start.add(const Duration(days: 7)));
      case _CalView.day:
        return DateTimeRange(
            start: _anchor, end: _anchor.add(const Duration(days: 1)));
      case _CalView.agenda:
        return DateTimeRange(
            start: _anchor, end: _anchor.add(const Duration(days: 30)));
    }
  }

  void _step(int dir) {
    setState(() {
      switch (_view) {
        case _CalView.month:
          _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
        case _CalView.week:
          _anchor = _anchor.add(Duration(days: 7 * dir));
        case _CalView.day:
          _anchor = _anchor.add(Duration(days: dir));
        case _CalView.agenda:
          _anchor = _anchor.add(Duration(days: 14 * dir));
      }
    });
  }

  void _goToday() =>
      setState(() => _anchor = CalendarUtils.dayOnly(DateTime.now()));

  String get _title {
    switch (_view) {
      case _CalView.month:
        return '${CalendarUtils.months[_anchor.month - 1]} ${_anchor.year}';
      case _CalView.week:
        final start = CalendarUtils.weekStart(_anchor);
        final end = start.add(const Duration(days: 6));
        final sM = CalendarUtils.monthsShort[start.month - 1];
        final eM = CalendarUtils.monthsShort[end.month - 1];
        return start.month == end.month
            ? '$sM ${start.day} – ${end.day}, ${end.year}'
            : '$sM ${start.day} – $eM ${end.day}';
      case _CalView.day:
        return '${CalendarUtils.weekdaysShort[_anchor.weekday - 1]}, '
            '${CalendarUtils.months[_anchor.month - 1]} ${_anchor.day}';
      case _CalView.agenda:
        return 'Schedule';
    }
  }

  void _onItemTap(CalendarItem item) {
    if (item.event != null) {
      showEventEditor(context, existing: item.event);
    }
  }

  void _newEvent() {
    final base = CalendarUtils.sameDay(_anchor, DateTime.now())
        ? DateTime.now()
        : DateTime(_anchor.year, _anchor.month, _anchor.day, 9);
    showEventEditor(context, initialStart: base);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final range = _range;
    final events = ref.watch(eventsBetweenProvider(range)).valueOrNull ?? const [];
    final tasks =
        ref.watch(tasksDueBetweenProvider(range)).valueOrNull ?? const [];
    final items = CalendarUtils.expand(events, tasks, range, cs);

    return SectionScaffold(
      title: 'Calendar',
      actions: [
        SegmentedButton<_CalView>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _CalView.month, label: Text('Month')),
            ButtonSegment(value: _CalView.week, label: Text('Week')),
            ButtonSegment(value: _CalView.day, label: Text('Day')),
            ButtonSegment(value: _CalView.agenda, label: Text('Schedule')),
          ],
          selected: {_view},
          onSelectionChanged: (s) => setState(() => _view = s.first),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _newEvent,
          icon: const Icon(Icons.add),
          label: const Text('New event'),
        ),
      ],
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _step(-1),
              ),
              IconButton(
                tooltip: 'Next',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _step(1),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _goToday, child: const Text('Today')),
              const SizedBox(width: 16),
              Text(_title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildView(items)),
        ],
      ),
    );
  }

  Widget _buildView(List<CalendarItem> items) {
    switch (_view) {
      case _CalView.month:
        return MonthView(
          anchor: _anchor,
          items: items,
          onDayTap: (day) => setState(() {
            _anchor = CalendarUtils.dayOnly(day);
            _view = _CalView.day;
          }),
          onItemTap: _onItemTap,
        );
      case _CalView.week:
        final start = CalendarUtils.weekStart(_anchor);
        return TimeGridView(
          days: List.generate(7, (i) => start.add(Duration(days: i))),
          items: items,
          onSlotTap: (dt) => showEventEditor(context, initialStart: dt),
          onItemTap: _onItemTap,
        );
      case _CalView.day:
        return TimeGridView(
          days: [_anchor],
          items: items,
          onSlotTap: (dt) => showEventEditor(context, initialStart: dt),
          onItemTap: _onItemTap,
        );
      case _CalView.agenda:
        return AgendaView(items: items, onItemTap: _onItemTap);
    }
  }
}
