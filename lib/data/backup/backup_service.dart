import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../database/app_database.dart';

/// Local backup / export / restore. MindNoron is a "single source of truth",
/// so data safety is non-negotiable (PLAN.md §6).
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const _encoder = JsonEncoder.withIndent('  ');

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, AppConstants.appName, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<Map<String, dynamic>>> _dump<T extends Table, D>(
      TableInfo<T, D> table) async {
    final rows = await _db.select(table).get();
    return rows
        .map((e) => (e as dynamic).toJson() as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> _export() async {
    return {
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': {
        'inboxItems': await _dump(_db.inboxItems),
        'tasks': await _dump(_db.tasks),
        'pomodoroSessions': await _dump(_db.pomodoroSessions),
        'dailyLogs': await _dump(_db.dailyLogs),
        'notes': await _dump(_db.notes),
        'habits': await _dump(_db.habits),
        'habitCompletions': await _dump(_db.habitCompletions),
        'calendarEvents': await _dump(_db.calendarEvents),
        'thoughts': await _dump(_db.thoughts),
        'settings': await _dump(_db.settings),
      },
    };
  }

  /// Write a timestamped JSON snapshot, keeping only the newest N.
  Future<File> backupNow() async {
    final dir = await _backupDir();
    String two(int n) => n.toString().padLeft(2, '0');
    final ts = DateTime.now();
    final name =
        'mindnoron-${ts.year}${two(ts.month)}${two(ts.day)}-${two(ts.hour)}${two(ts.minute)}${two(ts.second)}.json';
    final file = File(p.join(dir.path, name));
    await file.writeAsString(_encoder.convert(await _export()));
    await _prune(dir, AppConstants.defaultBackupRetention);
    return file;
  }

  /// Export to a user-chosen path (Settings → Export).
  Future<void> exportTo(String path) async {
    await File(path).writeAsString(_encoder.convert(await _export()));
  }

  Future<void> _prune(Directory dir, int keep) async {
    final files = (await dir.list().toList())
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('mindnoron-'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final f in files.skip(keep)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  /// Wipe all data (Settings → Clear all data).
  Future<void> clearAll() async {
    await _db.transaction(_deleteAll);
  }

  /// Delete every persistent row. Must run inside a transaction.
  Future<void> _deleteAll() async {
    await _db.delete(_db.inboxItems).go();
    await _db.delete(_db.tasks).go();
    await _db.delete(_db.pomodoroSessions).go();
    await _db.delete(_db.dailyLogs).go();
    await _db.delete(_db.notes).go();
    await _db.delete(_db.habits).go();
    await _db.delete(_db.habitCompletions).go();
    await _db.delete(_db.calendarEvents).go();
    await _db.delete(_db.thoughts).go();
    await _db.delete(_db.settings).go();
    await _db.delete(_db.timerStates).go();
  }

  /// Restore from a backup file, replacing all current data.
  Future<void> importFrom(String path) async {
    final data =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    final tables = data['tables'] as Map<String, dynamic>;
    List<Map<String, dynamic>> rows(String key) =>
        ((tables[key] as List?) ?? const []).cast<Map<String, dynamic>>();

    await _db.transaction(() async {
      await _deleteAll();

      for (final m in rows('inboxItems')) {
        await _db.into(_db.inboxItems).insert(InboxItem.fromJson(m));
      }
      for (final m in rows('tasks')) {
        await _db.into(_db.tasks).insert(Task.fromJson(m));
      }
      for (final m in rows('pomodoroSessions')) {
        await _db
            .into(_db.pomodoroSessions)
            .insert(PomodoroSession.fromJson(m));
      }
      for (final m in rows('dailyLogs')) {
        await _db.into(_db.dailyLogs).insert(DailyLog.fromJson(m));
      }
      for (final m in rows('notes')) {
        await _db.into(_db.notes).insert(Note.fromJson(m));
      }
      for (final m in rows('habits')) {
        await _db.into(_db.habits).insert(Habit.fromJson(m));
      }
      for (final m in rows('habitCompletions')) {
        await _db.into(_db.habitCompletions).insert(HabitCompletion.fromJson(m));
      }
      for (final m in rows('calendarEvents')) {
        await _db.into(_db.calendarEvents).insert(CalendarEvent.fromJson(m));
      }
      for (final m in rows('thoughts')) {
        await _db.into(_db.thoughts).insert(Thought.fromJson(m));
      }
      for (final m in rows('settings')) {
        await _db.into(_db.settings).insert(Setting.fromJson(m));
      }
    });
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});
