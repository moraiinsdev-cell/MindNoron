import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// MindNoron's local-first SQLite database (Drift).
///
/// Schema versioning lives here: bump [schemaVersion] and add an upgrade step
/// in [migration] whenever the schema changes — user data is never dropped.
@DriftDatabase(
  tables: [
    InboxItems,
    Tasks,
    PomodoroSessions,
    DailyLogs,
    Settings,
    TimerStates,
    Notes,
    Habits,
    HabitCompletions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// In-memory database for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // v2: Notes module (Phase 2).
          if (from < 2) {
            await m.createTable(notes);
          }
          // v3: Habits module (Phase 3).
          if (from < 3) {
            await m.createTable(habits);
            await m.createTable(habitCompletions);
          }
          // v4: subtasks — a task can point to a parent task.
          if (from < 4) {
            await m.addColumn(tasks, tasks.parentTaskId);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _open() {
    // drift_flutter resolves the right native sqlite3 lib + a writable path
    // (the app documents dir) on Windows/macOS/Linux/mobile.
    return driftDatabase(name: 'mindnoron');
  }
}
