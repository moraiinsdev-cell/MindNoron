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
    Thoughts,
    CalendarEvents,
    ExpenseEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// In-memory database for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

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
            await _addColumnIfMissing(m, tasks, tasks.parentTaskId);
          }
          // v5: thoughts — the noron-space thinking flow.
          if (from < 5) {
            await m.createTable(thoughts);
          }
          // v6: calendar events — the scheduling layer.
          if (from < 6) {
            await m.createTable(calendarEvents);
          }
          if (from < 7) {
            await m.createTable(expenseEntries);
          }
          if (from < 8) {
            await _addColumnIfMissing(
                m, pomodoroSessions, pomodoroSessions.stopReason);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// `ALTER TABLE ADD COLUMN`, but tolerant of the column already existing.
  ///
  /// SQLite persists a successful ALTER even if the process dies before
  /// drift bumps `user_version`; on the next launch the same migration step
  /// re-runs and a plain addColumn crashes with "duplicate column name" —
  /// permanently, since the version never gets bumped. Checking first makes
  /// the step idempotent and self-heals databases stuck in that state.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final info = await customSelect(
      "PRAGMA table_info('${table.actualTableName}')",
    ).get();
    final exists =
        info.any((row) => row.read<String>('name') == column.name);
    if (!exists) {
      await m.addColumn(table, column);
    }
  }

  static QueryExecutor _open() {
    // drift_flutter resolves the right native sqlite3 lib + a writable path
    // (the app documents dir) on Windows/macOS/Linux/mobile.
    return driftDatabase(name: 'mindnoron');
  }
}
