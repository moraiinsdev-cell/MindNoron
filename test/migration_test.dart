// Regression: a database where ALTER TABLE succeeded but the process died
// before drift bumped user_version used to crash on every launch with
// "duplicate column name: stop_reason" — a permanent white-screen boot loop.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/data/database/app_database.dart';

void main() {
  test('migration heals a v7 database that already has stop_reason', () async {
    // Simulate the stuck state: table already has the v8 column, but
    // user_version still says 7 so the v8 migration step re-runs.
    final db = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
          CREATE TABLE pomodoro_sessions (
            id TEXT NOT NULL PRIMARY KEY,
            linked_task_id TEXT,
            start_time INTEGER NOT NULL,
            end_time INTEGER,
            planned_minutes INTEGER NOT NULL,
            actual_minutes INTEGER NOT NULL DEFAULT 0,
            type TEXT NOT NULL DEFAULT 'work',
            was_completed INTEGER NOT NULL DEFAULT 0,
            interruptions INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            deleted_at INTEGER,
            is_dirty INTEGER NOT NULL DEFAULT 0,
            stop_reason TEXT
          );
        ''');
        raw.execute('PRAGMA user_version = 7;');
      },
    ));
    addTearDown(db.close);

    // Opening triggers the 7 -> 8 migration; it must not throw and must
    // finish bumping the schema version so it never re-runs.
    final version = await db
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((row) => row.read<int>('user_version'));
    expect(version, db.schemaVersion);

    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM pomodoro_sessions')
        .getSingle()
        .then((row) => row.read<int>('c'));
    expect(count, 0);
  });

  test('fresh database still gets the stop_reason column', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final info = await db
        .customSelect("PRAGMA table_info('pomodoro_sessions')")
        .get();
    final columns = info.map((r) => r.read<String>('name')).toSet();
    expect(columns, contains('stop_reason'));
  });
}
