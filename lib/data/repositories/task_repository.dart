import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/app_date_utils.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

/// Reads/writes for [Tasks]. All deletes are soft (PLAN.md §6).
class TaskRepository {
  TaskRepository(this._db);

  final AppDatabase _db;

  Future<String> create({
    required String title,
    int priority = 3,
    DateTime? dueDate,
    String? context,
    String? description,
    String? parentTaskId,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.tasks).insert(
          TasksCompanion.insert(
            id: id,
            title: title.trim(),
            priority: Value(priority),
            dueDate: Value(dueDate),
            context: Value(context),
            description: Value(description),
            parentTaskId: Value(parentTaskId),
          ),
        );
    return id;
  }

  Future<void> setStatus(String id, TaskStatus status) {
    final isDone = status == TaskStatus.done;
    return (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: Value(status.db),
        completedAt: Value(isDone ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  Future<void> toggleDone(Task task) {
    final next = TaskStatus.fromDb(task.status) == TaskStatus.done
        ? TaskStatus.todo
        : TaskStatus.done;
    return setStatus(task.id, next);
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Add focus minutes accumulated from a Pomodoro session.
  Future<void> addMinutes(String id, int minutes) async {
    final task = await (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (task == null) return;
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        actualMinutes: Value(task.actualMinutes + minutes),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Promote an inbox item into a proper task, marking the item processed.
  Future<String> convertInboxToTask(InboxItem item) async {
    late String id;
    await _db.transaction(() async {
      id = await create(title: item.content);
      await (_db.update(_db.inboxItems)..where((t) => t.id.equals(item.id)))
          .write(
        InboxItemsCompanion(
          isProcessed: const Value(true),
          updatedAt: Value(DateTime.now()),
          isDirty: const Value(true),
        ),
      );
    });
    return id;
  }

  static final _openStatuses = [TaskStatus.done.db, TaskStatus.archived.db];

  /// Top-level open tasks (excludes subtasks), ordered by priority then due.
  Stream<List<Task>> watchOpen() {
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.status.isNotIn(_openStatuses) &
              t.parentTaskId.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.priority),
            (t) => OrderingTerm.asc(t.dueDate),
          ]))
        .watch();
  }

  /// Subtasks of [parentId] (newest last), regardless of done state.
  Stream<List<Task>> watchSubtasks(String parentId) {
    return (_db.select(_db.tasks)
          ..where((t) => t.deletedAt.isNull() & t.parentTaskId.equals(parentId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Tasks completed on/after [since] — backs the weekly recap archive.
  Stream<List<Task>> watchCompletedSince(DateTime since) {
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.completedAt.isBiggerOrEqualValue(since))
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
        .watch();
  }

  /// One-shot fetch of top-level open tasks (for the launch reminder).
  Future<List<Task>> getOpen() {
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.status.isNotIn(_openStatuses) &
              t.parentTaskId.isNull()))
        .get();
  }

  /// Open tasks due today or overdue.
  Stream<List<Task>> watchToday() {
    final end = AppDateUtils.endOfDay(DateTime.now());
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.status.isNotIn(_openStatuses) &
              t.dueDate.isNotNull() &
              t.dueDate.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.priority)]))
        .watch();
  }

  /// Title search across non-deleted tasks.
  Future<List<Task>> search(String query) {
    final like = '%$query%';
    return (_db.select(_db.tasks)
          ..where((t) => t.deletedAt.isNull() & t.title.like(like))
          ..orderBy([(t) => OrderingTerm.asc(t.priority)]))
        .get();
  }

  /// Count of tasks completed today (for the dashboard).
  Stream<int> watchCompletedTodayCount() {
    final start = AppDateUtils.startOfDay(DateTime.now());
    final count = _db.tasks.id.count();
    final query = _db.selectOnly(_db.tasks)
      ..addColumns([count])
      ..where(_db.tasks.completedAt.isBiggerOrEqualValue(start) &
          _db.tasks.deletedAt.isNull());
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(databaseProvider));
});

final openTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskRepositoryProvider).watchOpen();
});

final todayTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskRepositoryProvider).watchToday();
});

final completedTodayCountProvider = StreamProvider<int>((ref) {
  return ref.watch(taskRepositoryProvider).watchCompletedTodayCount();
});

/// Subtasks for a given parent task id.
final subtasksProvider =
    StreamProvider.family<List<Task>, String>((ref, parentId) {
  return ref.watch(taskRepositoryProvider).watchSubtasks(parentId);
});

/// Tasks completed in the last 7 days (weekly recap archive).
final recentlyCompletedProvider = StreamProvider<List<Task>>((ref) {
  final since = DateTime.now().subtract(const Duration(days: 7));
  return ref.watch(taskRepositoryProvider).watchCompletedSince(since);
});
