import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/app_date_utils.dart';
import '../../features/timer/timer_engine.dart';
import '../database/app_database.dart';
import 'task_repository.dart';

const _uuid = Uuid();

/// Persists the live [TimerStates] row and logs completed [PomodoroSessions],
/// rolling focus minutes into the linked task + today's [DailyLogs].
class TimerRepository {
  TimerRepository(this._db, this._tasks);

  final AppDatabase _db;
  final TaskRepository _tasks;

  /// Upsert the single-row timer state so it survives an app restart.
  Future<void> persist(TimerSnapshot s) async {
    await _db.into(_db.timerStates).insertOnConflictUpdate(
          TimerStatesCompanion(
            id: const Value(0),
            startTimestamp: Value(s.startedAt),
            plannedEndTimestamp: Value(
              s.startedAt?.add(s.plannedDuration - s.pausedElapsed),
            ),
            type: Value(s.type.db),
            linkedTaskId: Value(s.linkedTaskId),
            isRunning: Value(s.isRunning),
            pausedElapsedSeconds: Value(s.pausedElapsed.inSeconds),
          ),
        );
  }

  Future<TimerSnapshot?> restore() async {
    final row = await (_db.select(_db.timerStates)
          ..where((t) => t.id.equals(0)))
        .getSingleOrNull();
    if (row == null) return null;
    final paused = Duration(seconds: row.pausedElapsedSeconds);
    final planned =
        row.plannedEndTimestamp != null && row.startTimestamp != null
            ? row.plannedEndTimestamp!.difference(row.startTimestamp!) + paused
            : Duration.zero;
    return TimerSnapshot(
      isRunning: row.isRunning,
      type: SessionType.fromDb(row.type),
      plannedDuration: planned,
      startedAt: row.startTimestamp,
      pausedElapsed: paused,
      linkedTaskId: row.linkedTaskId,
    );
  }

  Future<void> clear() =>
      (_db.delete(_db.timerStates)..where((t) => t.id.equals(0))).go();

  /// Record a finished session and credit its minutes (work sessions only).
  Future<void> logSession({
    required SessionType type,
    required DateTime start,
    required DateTime end,
    required int plannedMinutes,
    required int actualMinutes,
    String? linkedTaskId,
    bool completed = true,
  }) async {
    await _db.into(_db.pomodoroSessions).insert(
          PomodoroSessionsCompanion.insert(
            id: _uuid.v4(),
            startTime: start,
            endTime: Value(end),
            plannedMinutes: plannedMinutes,
            actualMinutes: Value(actualMinutes),
            type: Value(type.db),
            wasCompleted: Value(completed),
            linkedTaskId: Value(linkedTaskId),
          ),
        );
    if (type == SessionType.work && actualMinutes > 0) {
      if (linkedTaskId != null) {
        await _tasks.addMinutes(linkedTaskId, actualMinutes);
      }
      await _addFocusMinutesToday(actualMinutes);
    }
  }

  Future<void> _addFocusMinutesToday(int minutes) async {
    final day = AppDateUtils.startOfDay(DateTime.now());
    final existing = await (_db.select(_db.dailyLogs)
          ..where((t) => t.date.equals(day)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.dailyLogs).insert(
            DailyLogsCompanion.insert(
              id: _uuid.v4(),
              date: day,
              focusMinutes: Value(minutes),
            ),
          );
    } else {
      await (_db.update(_db.dailyLogs)..where((t) => t.id.equals(existing.id)))
          .write(
        DailyLogsCompanion(
          focusMinutes: Value(existing.focusMinutes + minutes),
          updatedAt: Value(DateTime.now()),
          isDirty: const Value(true),
        ),
      );
    }
  }

  /// Sum of work minutes logged today (drives the dashboard "focus today").
  Stream<int> watchFocusMinutesToday() {
    final day = AppDateUtils.startOfDay(DateTime.now());
    final total = _db.pomodoroSessions.actualMinutes.sum();
    final query = _db.selectOnly(_db.pomodoroSessions)
      ..addColumns([total])
      ..where(_db.pomodoroSessions.type.equals(SessionType.work.db) &
          _db.pomodoroSessions.startTime.isBiggerOrEqualValue(day) &
          _db.pomodoroSessions.deletedAt.isNull());
    return query.map((row) => row.read(total) ?? 0).watchSingle();
  }
}

final timerRepositoryProvider = Provider<TimerRepository>((ref) {
  return TimerRepository(
    ref.watch(databaseProvider),
    ref.watch(taskRepositoryProvider),
  );
});

final focusMinutesTodayProvider = StreamProvider<int>((ref) {
  return ref.watch(timerRepositoryProvider).watchFocusMinutesToday();
});
