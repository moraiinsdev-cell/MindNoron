import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/app_date_utils.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

/// One [DailyLogs] row per day — energy check-in + cached stats.
class DailyLogRepository {
  DailyLogRepository(this._db);

  final AppDatabase _db;

  Stream<DailyLog?> watchToday() {
    final day = AppDateUtils.startOfDay(DateTime.now());
    return (_db.select(_db.dailyLogs)..where((t) => t.date.equals(day)))
        .watchSingleOrNull();
  }

  /// Recent days that have an energy reading (oldest first) — backs the trend.
  Stream<List<DailyLog>> watchEnergyHistory(int days) {
    final since = AppDateUtils.startOfDay(DateTime.now())
        .subtract(Duration(days: days - 1));
    return (_db.select(_db.dailyLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(since) & t.energyLevel.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  /// Recent days carrying a journal entry (a written note), newest first.
  Stream<List<DailyLog>> watchJournal(int days) {
    final since = AppDateUtils.startOfDay(DateTime.now())
        .subtract(Duration(days: days - 1));
    return (_db.select(_db.dailyLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(since) &
              t.note.isNotNull() &
              t.note.equals('').not())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Future<void> setEnergy(int level) =>
      _upsertToday((id) => DailyLogsCompanion(
            id: id,
            date: Value(AppDateUtils.startOfDay(DateTime.now())),
            energyLevel: Value(level),
          ));

  Future<void> setMood(String? mood) =>
      _upsertToday((id) => DailyLogsCompanion(
            id: id,
            date: Value(AppDateUtils.startOfDay(DateTime.now())),
            mood: Value(mood),
          ));

  Future<void> setNote(String? note) =>
      _upsertToday((id) => DailyLogsCompanion(
            id: id,
            date: Value(AppDateUtils.startOfDay(DateTime.now())),
            note: Value(note),
          ));

  /// Insert or patch today's row. [build] receives an id Value: absent for an
  /// update (id untouched) or a fresh uuid for an insert.
  Future<void> _upsertToday(
      DailyLogsCompanion Function(Value<String> id) build) async {
    final day = AppDateUtils.startOfDay(DateTime.now());
    final existing = await (_db.select(_db.dailyLogs)
          ..where((t) => t.date.equals(day)))
        .getSingleOrNull();
    if (existing == null) {
      final companion = build(Value(_uuid.v4()));
      await _db.into(_db.dailyLogs).insert(
            DailyLogsCompanion.insert(
              id: companion.id.value,
              date: day,
              energyLevel: companion.energyLevel,
              mood: companion.mood,
              note: companion.note,
            ),
          );
    } else {
      final patch = build(const Value.absent());
      await (_db.update(_db.dailyLogs)..where((t) => t.id.equals(existing.id)))
          .write(
        patch.copyWith(
          id: const Value.absent(),
          date: const Value.absent(),
          updatedAt: Value(DateTime.now()),
          isDirty: const Value(true),
        ),
      );
    }
  }
}

final dailyLogRepositoryProvider = Provider<DailyLogRepository>((ref) {
  return DailyLogRepository(ref.watch(databaseProvider));
});

final todayLogProvider = StreamProvider<DailyLog?>((ref) {
  return ref.watch(dailyLogRepositoryProvider).watchToday();
});

final energyHistoryProvider = StreamProvider<List<DailyLog>>((ref) {
  return ref.watch(dailyLogRepositoryProvider).watchEnergyHistory(14);
});

final journalProvider = StreamProvider<List<DailyLog>>((ref) {
  return ref.watch(dailyLogRepositoryProvider).watchJournal(60);
});
