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

  Future<void> setEnergy(int level) async {
    final day = AppDateUtils.startOfDay(DateTime.now());
    final existing = await (_db.select(_db.dailyLogs)
          ..where((t) => t.date.equals(day)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.dailyLogs).insert(
            DailyLogsCompanion.insert(
              id: _uuid.v4(),
              date: day,
              energyLevel: Value(level),
            ),
          );
    } else {
      await (_db.update(_db.dailyLogs)..where((t) => t.id.equals(existing.id)))
          .write(
        DailyLogsCompanion(
          energyLevel: Value(level),
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
