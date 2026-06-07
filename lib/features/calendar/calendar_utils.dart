import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';
import 'calendar_item.dart';

/// Calendar date helpers + recurrence expansion shared by all views.
class CalendarUtils {
  CalendarUtils._();

  static const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday 00:00 of the week containing [d].
  static DateTime weekStart(DateTime d) {
    final day = dayOnly(d);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String timeLabel(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Expand raw [events] (recurring + one-off) and due-dated [tasks] into the
  /// concrete [CalendarItem]s that fall inside [range].
  static List<CalendarItem> expand(
    List<CalendarEvent> events,
    List<Task> tasks,
    DateTimeRange range,
    ColorScheme cs,
  ) {
    final out = expandEventsOnly(events, range);
    for (final t in tasks) {
      if (t.dueDate != null) out.add(CalendarItem.task(t, cs));
    }
    out.sort(_byStart);
    return out;
  }

  /// Recurrence-expanded events only (no tasks) — used by the reminder
  /// scheduler, which doesn't need a [ColorScheme].
  static List<CalendarItem> expandEventsOnly(
    List<CalendarEvent> events,
    DateTimeRange range,
  ) {
    final out = <CalendarItem>[];
    for (final e in events) {
      out.addAll(_expandEvent(e, range));
    }
    out.sort(_byStart);
    return out;
  }

  static int _byStart(CalendarItem a, CalendarItem b) {
    if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
    return a.start.compareTo(b.start);
  }

  static List<CalendarItem> _expandEvent(CalendarEvent e, DateTimeRange range) {
    final rule = e.recurrenceRule;
    final repeats = e.isRecurring && rule != null && rule != 'none';
    final dur = e.endTime.isAfter(e.startTime)
        ? e.endTime.difference(e.startTime)
        : const Duration(minutes: 30);

    if (!repeats) {
      final overlaps =
          e.startTime.isBefore(range.end) && e.endTime.isAfter(range.start);
      return overlaps ? [CalendarItem.event(e)] : const [];
    }

    final out = <CalendarItem>[];
    var occStart = e.startTime;

    // Fast-forward close to the window so old recurring events don't loop for
    // years before reaching the visible range.
    if (rule == 'daily' && occStart.isBefore(range.start)) {
      final days = range.start.difference(occStart).inDays;
      if (days > 1) occStart = occStart.add(Duration(days: days - 1));
    } else if (rule == 'weekly' && occStart.isBefore(range.start)) {
      final weeks = range.start.difference(occStart).inDays ~/ 7;
      if (weeks > 1) occStart = occStart.add(Duration(days: (weeks - 1) * 7));
    }

    var guard = 0;
    while (occStart.isBefore(range.end) && guard < 1000) {
      final occEnd = occStart.add(dur);
      if (occEnd.isAfter(range.start)) {
        out.add(CalendarItem.occurrence(e, occStart, occEnd));
      }
      occStart = _advance(occStart, rule);
      guard++;
    }
    return out;
  }

  static DateTime _advance(DateTime d, String rule) => switch (rule) {
        'weekly' => d.add(const Duration(days: 7)),
        'monthly' => DateTime(d.year, d.month + 1, d.day, d.hour, d.minute),
        _ => d.add(const Duration(days: 1)), // daily
      };
}
