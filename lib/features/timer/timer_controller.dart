import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/platform/notification_service.dart';
import '../../data/repositories/timer_repository.dart';
import 'timer_engine.dart';

/// Emits every second purely to repaint the UI. The timer's *truth* is the
/// timestamps in [TimerSnapshot]; this never counts time itself.
final nowTickerProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return Stream<DateTime>.periodic(
      const Duration(seconds: 1), (_) => DateTime.now());
});

final timerControllerProvider =
    NotifierProvider<TimerController, TimerSnapshot>(TimerController.new);

class TimerController extends Notifier<TimerSnapshot> {
  Timer? _completion;

  TimerRepository get _repo => ref.read(timerRepositoryProvider);

  @override
  TimerSnapshot build() {
    ref.onDispose(() => _completion?.cancel());
    Future.microtask(_restore);
    return const TimerSnapshot.idle();
  }

  Future<void> _restore() async {
    final restored = await _repo.restore();
    if (restored == null || !restored.isActive) return;
    final now = DateTime.now();
    if (restored.isRunning && restored.isComplete(now)) {
      // Session finished while the app was closed — finalize it now.
      await _finalize(restored, completedAt: now, completed: true);
      return;
    }
    state = restored;
    if (restored.isRunning) _scheduleCompletion();
  }

  Future<void> start({
    required Duration duration,
    SessionType type = SessionType.work,
    String? linkedTaskId,
  }) async {
    final snapshot = TimerSnapshot(
      isRunning: true,
      type: type,
      plannedDuration: duration,
      startedAt: DateTime.now(),
      pausedElapsed: Duration.zero,
      linkedTaskId: linkedTaskId,
    );
    state = snapshot;
    await _repo.persist(snapshot);
    _scheduleCompletion();
  }

  Future<void> pause() async {
    final s = state;
    if (!s.isRunning) return;
    _completion?.cancel();
    final next = s.copyWith(
      isRunning: false,
      pausedElapsed: s.elapsed(DateTime.now()),
      clearStartedAt: true,
    );
    state = next;
    await _repo.persist(next);
  }

  Future<void> resume() async {
    final s = state;
    if (s.isRunning || !s.isActive) return;
    final next = s.copyWith(isRunning: true, startedAt: DateTime.now());
    state = next;
    await _repo.persist(next);
    _scheduleCompletion();
  }

  /// Stop early; logs the elapsed time as an incomplete session.
  Future<void> stop() async {
    final s = state;
    if (!s.isActive) return;
    _completion?.cancel();
    await _finalize(s, completedAt: DateTime.now(), completed: false);
  }

  Future<void> _finalize(
    TimerSnapshot s, {
    required DateTime completedAt,
    required bool completed,
  }) async {
    final elapsed = completed ? s.plannedDuration : s.elapsed(completedAt);
    final start = (s.startedAt ?? completedAt).subtract(s.pausedElapsed);
    await _repo.logSession(
      type: s.type,
      start: start,
      end: completedAt,
      plannedMinutes: s.plannedDuration.inMinutes,
      actualMinutes: elapsed.inMinutes,
      linkedTaskId: s.linkedTaskId,
      completed: completed,
    );
    await _repo.clear();
    state = const TimerSnapshot.idle();
    if (completed) {
      await NotificationService.show(
        title: '${s.type.label} complete',
        body: s.type == SessionType.work
            ? 'Nice work. Take a clean break.'
            : 'Break complete. Time to focus again.',
      );
    }
  }

  void _scheduleCompletion() {
    _completion?.cancel();
    final remaining = state.remaining(DateTime.now());
    _completion = Timer(
      remaining,
      () => _finalize(state, completedAt: DateTime.now(), completed: true),
    );
  }
}
