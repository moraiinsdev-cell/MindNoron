import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import 'event_color.dart';

/// A unified thing shown on the calendar — either a [CalendarEvent] or a [Task]
/// that carries a due date. Views render [CalendarItem]s without caring which.
class CalendarItem {
  CalendarItem._({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
    required this.color,
    required this.isTask,
    this.event,
    this.task,
  });

  factory CalendarItem.event(CalendarEvent e) => CalendarItem._(
        id: e.id,
        title: e.title,
        start: e.startTime,
        end: e.endTime.isAfter(e.startTime)
            ? e.endTime
            : e.startTime.add(const Duration(minutes: 30)),
        isAllDay: e.isAllDay,
        color: EventColor.fromName(e.colorTag).color,
        isTask: false,
        event: e,
      );

  /// One occurrence of a recurring [CalendarEvent] at an overridden start/end.
  factory CalendarItem.occurrence(
    CalendarEvent e,
    DateTime start,
    DateTime end,
  ) =>
      CalendarItem._(
        id: '${e.id}@${start.millisecondsSinceEpoch}',
        title: e.title,
        start: start,
        end: end,
        isAllDay: e.isAllDay,
        color: EventColor.fromName(e.colorTag).color,
        isTask: false,
        event: e,
      );

  factory CalendarItem.task(Task t, ColorScheme cs) {
    final due = t.dueDate!;
    return CalendarItem._(
      id: 'task:${t.id}',
      title: t.title,
      start: due,
      end: due.add(const Duration(minutes: 30)),
      isAllDay: true, // tasks ride in the all-day row
      color: Priority.color(t.priority, cs),
      isTask: true,
      task: t,
    );
  }

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
  final Color color;
  final bool isTask;
  final CalendarEvent? event;
  final Task? task;

  bool get isDone =>
      task != null && TaskStatus.fromDb(task!.status) == TaskStatus.done;

  Duration get duration => end.difference(start);
}
