import '../../data/database/app_database.dart';

/// How urgent an open task is, from how long it has been neglected (or how far
/// past its due date). 0 = fine … 3 = urgent.
///
/// The Tasks UI uses this to colour, sort and nudge long-sitting items so they
/// don't get forgotten.
int taskUrgency(Task task, DateTime now) =>
    urgencyForDates(task.dueDate, task.createdAt, now);

/// Core of [taskUrgency] over raw dates — pure, so it is unit-tested directly.
int urgencyForDates(DateTime? due, DateTime createdAt, DateTime now) {
  if (due != null) {
    final overdueDays = now.difference(due).inDays;
    if (overdueDays >= 3) return 3;
    if (overdueDays >= 1) return 2;
    if (now.isAfter(due)) return 1;
    return 0;
  }
  final ageDays = _calendarDaysBetween(createdAt, now);
  if (ageDays >= 7) return 3;
  if (ageDays >= 4) return 2;
  if (ageDays >= 2) return 1;
  return 0;
}

/// Short chip label: due info if dated, else how long the task has sat.
String taskAgeLabel(Task task, DateTime now) =>
    ageLabelForDates(task.dueDate, task.createdAt, now);

String ageLabelForDates(DateTime? due, DateTime createdAt, DateTime now) {
  if (due != null) {
    final overdueDays = now.difference(due).inDays;
    if (overdueDays >= 1) return '${overdueDays}d overdue';
    if (now.isAfter(due)) return 'Due today';
    final inDays = due.difference(now).inDays;
    return inDays <= 0 ? 'Due today' : 'Due in ${inDays}d';
  }
  final ageDays = _calendarDaysBetween(createdAt, now);
  if (ageDays <= 0) return 'Today';
  if (ageDays == 1) return 'Yesterday';
  return '${ageDays}d ago';
}

/// Whole calendar days from [from] to [to], ignoring clock time — so a task
/// created late yesterday reads as 1 day old this morning, not 0. (The previous
/// `Duration.inDays` counted fixed 24h chunks, which made everything created in
/// the last day show "Today".) Rounding the hour delta keeps it right across DST.
int _calendarDaysBetween(DateTime from, DateTime to) {
  final f = DateTime(from.year, from.month, from.day);
  final t = DateTime(to.year, to.month, to.day);
  return (t.difference(f).inHours / 24).round();
}
