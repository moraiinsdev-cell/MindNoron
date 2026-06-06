import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/app_date_utils.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

/// The "thinking flow": quick thoughts captured during (or between) sessions.
class ThoughtsRepository {
  ThoughtsRepository(this._db);

  final AppDatabase _db;

  Future<void> capture({
    required String content,
    String sessionType = 'none',
    String? linkedTaskId,
  }) async {
    final text = content.trim();
    if (text.isEmpty) return;
    await _db.into(_db.thoughts).insert(
          ThoughtsCompanion.insert(
            id: _uuid.v4(),
            content: text,
            sessionType: Value(sessionType),
            linkedTaskId: Value(linkedTaskId),
          ),
        );
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.thoughts)..where((t) => t.id.equals(id))).write(
      ThoughtsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Today's thoughts, oldest first (reads like a flowing timeline).
  Stream<List<Thought>> watchToday() {
    final start = AppDateUtils.startOfDay(DateTime.now());
    return (_db.select(_db.thoughts)
          ..where((t) =>
              t.deletedAt.isNull() & t.createdAt.isBiggerOrEqualValue(start))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Most recent thoughts (newest first) for reviewing past sessions.
  Stream<List<Thought>> watchRecent(int limit) {
    return (_db.select(_db.thoughts)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }
}

final thoughtsRepositoryProvider = Provider<ThoughtsRepository>((ref) {
  return ThoughtsRepository(ref.watch(databaseProvider));
});

final todayThoughtsProvider = StreamProvider<List<Thought>>((ref) {
  return ref.watch(thoughtsRepositoryProvider).watchToday();
});

final recentThoughtsProvider = StreamProvider<List<Thought>>((ref) {
  return ref.watch(thoughtsRepositoryProvider).watchRecent(50);
});
