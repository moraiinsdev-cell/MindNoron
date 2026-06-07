import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/app_date_utils.dart';
import '../database/app_database.dart';

/// What the activity heatmap is showing.
enum ActivityMetric {
  focus('Focus', 'min'),
  tasks('Tasks', 'done'),
  habits('Habits', 'habits');

  const ActivityMetric(this.label, this.unit);

  final String label;
  final String unit;
}

/// Per-day totals for a metric over one calendar year. Aggregation is done in
/// Dart (range query → bucket by day) to avoid SQLite date-function quirks.
class ActivityRepository {
  ActivityRepository(this._db);

  final AppDatabase _db;

  ({DateTime start, DateTime end}) _yearRange(int year) =>
      (start: DateTime(year), end: DateTime(year + 1));

  /// Work-session minutes per day.
  Stream<Map<DateTime, int>> watchFocusMinutes(int year) {
    final r = _yearRange(year);
    final q = _db.select(_db.pomodoroSessions)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.type.equals(SessionType.work.db) &
          t.startTime.isBiggerOrEqualValue(r.start) &
          t.startTime.isSmallerThanValue(r.end));
    return q.watch().map((rows) {
      final m = <DateTime, int>{};
      for (final s in rows) {
        final day = AppDateUtils.startOfDay(s.startTime);
        m[day] = (m[day] ?? 0) + s.actualMinutes;
      }
      return m;
    });
  }

  /// Tasks completed per day.
  Stream<Map<DateTime, int>> watchTasksDone(int year) {
    final r = _yearRange(year);
    final q = _db.select(_db.tasks)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.completedAt.isBiggerOrEqualValue(r.start) &
          t.completedAt.isSmallerThanValue(r.end));
    return q.watch().map((rows) {
      final m = <DateTime, int>{};
      for (final t in rows) {
        final c = t.completedAt;
        if (c == null) continue;
        final day = AppDateUtils.startOfDay(c);
        m[day] = (m[day] ?? 0) + 1;
      }
      return m;
    });
  }

  /// Work-session minutes per day over the last [days] days (rolling window),
  /// for the trends charts. Days with no focus are absent from the map.
  Stream<Map<DateTime, int>> watchRecentFocus(int days) {
    final start = AppDateUtils.startOfDay(DateTime.now())
        .subtract(Duration(days: days - 1));
    final q = _db.select(_db.pomodoroSessions)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.type.equals(SessionType.work.db) &
          t.startTime.isBiggerOrEqualValue(start));
    return q.watch().map((rows) {
      final m = <DateTime, int>{};
      for (final s in rows) {
        final day = AppDateUtils.startOfDay(s.startTime);
        m[day] = (m[day] ?? 0) + s.actualMinutes;
      }
      return m;
    });
  }

  /// Habit completions per day.
  Stream<Map<DateTime, int>> watchHabitCounts(int year) {
    final r = _yearRange(year);
    final q = _db.select(_db.habitCompletions)
      ..where((t) =>
          t.date.isBiggerOrEqualValue(r.start) &
          t.date.isSmallerThanValue(r.end));
    return q.watch().map((rows) {
      final m = <DateTime, int>{};
      for (final h in rows) {
        final day = AppDateUtils.startOfDay(h.date);
        m[day] = (m[day] ?? 0) + 1;
      }
      return m;
    });
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(databaseProvider));
});

/// Focus minutes per day over the last 56 days (8 weeks) — backs the trends bar
/// chart.
final recentFocusProvider = StreamProvider<Map<DateTime, int>>((ref) {
  return ref.watch(activityRepositoryProvider).watchRecentFocus(56);
});

typedef ActivityQuery = ({ActivityMetric metric, int year});

/// Day → value map for the selected metric/year, kept live.
final activityDataProvider =
    StreamProvider.family<Map<DateTime, int>, ActivityQuery>((ref, q) {
  final repo = ref.watch(activityRepositoryProvider);
  return switch (q.metric) {
    ActivityMetric.focus => repo.watchFocusMinutes(q.year),
    ActivityMetric.tasks => repo.watchTasksDone(q.year),
    ActivityMetric.habits => repo.watchHabitCounts(q.year),
  };
});
