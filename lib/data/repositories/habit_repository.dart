import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/app_date_utils.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

/// Current streak = consecutive completed days ending today (if done today) or
/// yesterday (grace until a full day is missed). Pure → unit-tested.
int computeStreak(Set<DateTime> days, DateTime today) {
  var d = DateTime(today.year, today.month, today.day);
  if (!days.contains(d)) {
    d = d.subtract(const Duration(days: 1));
    if (!days.contains(d)) return 0;
  }
  var streak = 0;
  while (days.contains(d)) {
    streak++;
    d = d.subtract(const Duration(days: 1));
  }
  return streak;
}

class HabitRepository {
  HabitRepository(this._db);

  final AppDatabase _db;

  Future<String> create(String name, {String emoji = '◎'}) async {
    final id = _uuid.v4();
    await _db.into(_db.habits).insert(
          HabitsCompanion.insert(
              id: id, name: name.trim(), emoji: Value(emoji)),
        );
    return id;
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.habits)..where((t) => t.id.equals(id))).write(
      HabitsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  Stream<List<Habit>> watchHabits() {
    return (_db.select(_db.habits)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Completions within the last ~90 days (enough to render streaks).
  Stream<List<HabitCompletion>> watchRecentCompletions() {
    final since = AppDateUtils.startOfDay(DateTime.now())
        .subtract(const Duration(days: 90));
    return (_db.select(_db.habitCompletions)
          ..where((t) => t.date.isBiggerOrEqualValue(since)))
        .watch();
  }

  /// Toggle today's completion for a habit.
  Future<void> toggleToday(String habitId) async {
    final day = AppDateUtils.startOfDay(DateTime.now());
    final existing = await (_db.select(_db.habitCompletions)
          ..where((t) => t.habitId.equals(habitId) & t.date.equals(day)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.delete(_db.habitCompletions)
            ..where((t) => t.id.equals(existing.id)))
          .go();
    } else {
      await _db.into(_db.habitCompletions).insert(
            HabitCompletionsCompanion.insert(
                id: _uuid.v4(), habitId: habitId, date: day),
          );
    }
  }
}

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(databaseProvider));
});

final habitsProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitRepositoryProvider).watchHabits();
});

final habitCompletionsProvider = StreamProvider<List<HabitCompletion>>((ref) {
  return ref.watch(habitRepositoryProvider).watchRecentCompletions();
});
