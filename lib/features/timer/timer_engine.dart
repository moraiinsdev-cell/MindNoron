import '../../core/enums.dart';

/// An immutable snapshot of the focus timer.
///
/// The engine is **timestamp-based**: the source of truth is [startedAt] +
/// [pausedElapsed], and elapsed/remaining are derived from the wall clock. This
/// is what keeps the timer accurate across app restart / sleep — a ticking Dart
/// `Timer` is only used to repaint the UI, never to count time (PLAN.md §5.3).
class TimerSnapshot {
  const TimerSnapshot({
    required this.isRunning,
    required this.type,
    required this.plannedDuration,
    required this.startedAt,
    required this.pausedElapsed,
    this.linkedTaskId,
  });

  const TimerSnapshot.idle()
      : isRunning = false,
        type = SessionType.work,
        plannedDuration = Duration.zero,
        startedAt = null,
        pausedElapsed = Duration.zero,
        linkedTaskId = null;

  final bool isRunning;
  final SessionType type;
  final Duration plannedDuration;

  /// When the current running segment began. Null while paused/idle.
  final DateTime? startedAt;

  /// Elapsed time accumulated before the current running segment.
  final Duration pausedElapsed;

  final String? linkedTaskId;

  /// True once a session has been started (running or paused) but not stopped.
  bool get isActive =>
      isRunning || pausedElapsed > Duration.zero || startedAt != null;

  Duration elapsed(DateTime now) {
    if (isRunning && startedAt != null) {
      return pausedElapsed + now.difference(startedAt!);
    }
    return pausedElapsed;
  }

  Duration remaining(DateTime now) {
    final r = plannedDuration - elapsed(now);
    return r.isNegative ? Duration.zero : r;
  }

  bool isComplete(DateTime now) =>
      plannedDuration > Duration.zero && elapsed(now) >= plannedDuration;

  /// 0.0 → 1.0 progress through the planned duration.
  double progress(DateTime now) {
    final total = plannedDuration.inMilliseconds;
    if (total <= 0) return 0;
    return (elapsed(now).inMilliseconds / total).clamp(0.0, 1.0);
  }

  TimerSnapshot copyWith({
    bool? isRunning,
    SessionType? type,
    Duration? plannedDuration,
    DateTime? startedAt,
    bool clearStartedAt = false,
    Duration? pausedElapsed,
    String? linkedTaskId,
    bool clearLinkedTaskId = false,
  }) {
    return TimerSnapshot(
      isRunning: isRunning ?? this.isRunning,
      type: type ?? this.type,
      plannedDuration: plannedDuration ?? this.plannedDuration,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      pausedElapsed: pausedElapsed ?? this.pausedElapsed,
      linkedTaskId:
          clearLinkedTaskId ? null : (linkedTaskId ?? this.linkedTaskId),
    );
  }
}

/// Formats a [Duration] as `mm:ss` (or `h:mm:ss` past an hour).
String formatTimer(Duration d) {
  final total = d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
