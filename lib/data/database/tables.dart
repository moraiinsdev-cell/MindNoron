import 'package:drift/drift.dart';

/// Shared "sync-ready" columns for every domain entity.
///
/// Every record uses a UUID string PK and carries timestamps + a soft-delete
/// marker + a dirty flag, so the local schema can later be synced to Supabase
/// without a painful migration. See PLAN.md §6.
mixin SyncBase on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

/// Quick-capture items. Everything captured lands here first (the Inbox).
class InboxItems extends Table with SyncBase {
  TextColumn get content => text()();
  TextColumn get type =>
      text().withDefault(const Constant('text'))(); // text|voice|photo
  TextColumn get source => text().withDefault(
      const Constant('manual'))(); // hotkey|tray|clipboard|drag|manual
  TextColumn get voicePath => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  BoolColumn get isProcessed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The core unit of work.
class Tasks extends Table with SyncBase {
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()
      .withDefault(const Constant('todo'))(); // todo|in_progress|done|archived
  IntColumn get priority =>
      integer().withDefault(const Constant(3))(); // 1=highest .. 4=lowest
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get estimatedMinutes => integer().nullable()();
  IntColumn get actualMinutes => integer().withDefault(const Constant(0))();
  TextColumn get tags => text().withDefault(
      const Constant('[]'))(); // JSON array (normalized in Phase 2)
  TextColumn get context => text().nullable()(); // @Home / @Office ...
  TextColumn get projectId => text().nullable()();
  TextColumn get parentTaskId => text().nullable()(); // set => this is a subtask
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceRule => text().nullable()(); // RRULE-style string
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A logged focus (Pomodoro) session, optionally linked to a [Tasks] row.
class PomodoroSessions extends Table with SyncBase {
  TextColumn get linkedTaskId => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get plannedMinutes => integer()();
  IntColumn get actualMinutes => integer().withDefault(const Constant(0))();
  TextColumn get type => text()
      .withDefault(const Constant('work'))(); // work|short_break|long_break
  BoolColumn get wasCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get interruptions => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per day — backs the dashboard energy check-in + cached stats.
class DailyLogs extends Table with SyncBase {
  DateTimeColumn get date => dateTime()(); // normalized to midnight
  IntColumn get energyLevel => integer().nullable()(); // 1..5
  TextColumn get mood => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get focusMinutes => integer().withDefault(const Constant(0))();
  IntColumn get tasksCompleted => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A recurring habit to build (Phase 3).
class Habits extends Table with SyncBase {
  TextColumn get name => text()();
  TextColumn get emoji => text().withDefault(const Constant('◎'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per (habit, day) it was completed. Hard-deleted when un-checked.
class HabitCompletions extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  DateTimeColumn get date => dateTime()(); // normalized to midnight
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Markdown notes — the "second brain". Linked to tasks and other notes.
class Notes extends Table with SyncBase {
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content =>
      text().withDefault(const Constant(''))(); // Markdown
  TextColumn get tags =>
      text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get linkedTaskIds =>
      text().withDefault(const Constant('[]'))(); // JSON array

  @override
  Set<Column> get primaryKey => {id};
}

/// Stream-of-consciousness notes captured during (or outside) a focus/break
/// session — the "thinking flow" of the noron space.
class Thoughts extends Table with SyncBase {
  TextColumn get content => text()();
  TextColumn get sessionType => text()
      .withDefault(const Constant('none'))(); // work|short_break|long_break|none
  TextColumn get linkedTaskId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Simple key/value store for [AppSettings] (timer durations, theme, hotkey...).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

/// Single-row, local-only persistence of the active focus timer so it can be
/// reconstructed from timestamps after an app restart. See PLAN.md §5.3.
class TimerStates extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))(); // always 0
  DateTimeColumn get startTimestamp => dateTime().nullable()();
  DateTimeColumn get plannedEndTimestamp => dateTime().nullable()();
  TextColumn get type => text().withDefault(const Constant('work'))();
  TextColumn get linkedTaskId => text().nullable()();
  BoolColumn get isRunning => boolean().withDefault(const Constant(false))();
  IntColumn get pausedElapsedSeconds =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
