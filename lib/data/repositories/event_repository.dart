import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

/// Reads/writes for [CalendarEvents]. All deletes are soft (PLAN.md §6).
class EventRepository {
  EventRepository(this._db);

  final AppDatabase _db;

  Future<String> create({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    bool isAllDay = false,
    String? location,
    String colorTag = 'blue',
    String? recurrenceRule,
    int? reminderMinutes,
    String? linkedTaskId,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.calendarEvents).insert(
          CalendarEventsCompanion.insert(
            id: id,
            title: title.trim(),
            startTime: startTime,
            endTime: endTime,
            description: Value(description),
            isAllDay: Value(isAllDay),
            location: Value(location),
            colorTag: Value(colorTag),
            isRecurring: Value(recurrenceRule != null && recurrenceRule != 'none'),
            recurrenceRule: Value(recurrenceRule),
            reminderMinutes: Value(reminderMinutes),
            linkedTaskId: Value(linkedTaskId),
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    bool isAllDay = false,
    String? location,
    String colorTag = 'blue',
    String? recurrenceRule,
    int? reminderMinutes,
  }) {
    return (_db.update(_db.calendarEvents)..where((e) => e.id.equals(id))).write(
      CalendarEventsCompanion(
        title: Value(title.trim()),
        startTime: Value(startTime),
        endTime: Value(endTime),
        description: Value(description),
        isAllDay: Value(isAllDay),
        location: Value(location),
        colorTag: Value(colorTag),
        isRecurring:
            Value(recurrenceRule != null && recurrenceRule != 'none'),
        recurrenceRule: Value(recurrenceRule),
        reminderMinutes: Value(reminderMinutes),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Move an event to a new start/end (used by drag-to-reschedule).
  Future<void> reschedule(String id, DateTime startTime, DateTime endTime) {
    return (_db.update(_db.calendarEvents)..where((e) => e.id.equals(id))).write(
      CalendarEventsCompanion(
        startTime: Value(startTime),
        endTime: Value(endTime),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.calendarEvents)..where((e) => e.id.equals(id))).write(
      CalendarEventsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Events overlapping the inclusive window [start, end].
  Stream<List<CalendarEvent>> watchBetween(DateTime start, DateTime end) {
    return (_db.select(_db.calendarEvents)
          ..where((e) =>
              e.deletedAt.isNull() &
              e.startTime.isSmallerOrEqualValue(end) &
              e.endTime.isBiggerOrEqualValue(start))
          ..orderBy([(e) => OrderingTerm.asc(e.startTime)]))
        .watch();
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(databaseProvider));
});

/// Events overlapping the given range — keyed by [DateTimeRange] so each
/// calendar view only streams the span it shows.
final eventsBetweenProvider =
    StreamProvider.family<List<CalendarEvent>, DateTimeRange>((ref, range) {
  return ref.watch(eventRepositoryProvider).watchBetween(range.start, range.end);
});
