import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/core/enums.dart';
import 'package:mind_noron/features/timer/timer_engine.dart';

void main() {
  final start = DateTime(2026, 6, 6, 9, 0, 0);

  group('TimerSnapshot (timestamp-based)', () {
    test('idle has no elapsed and is not active', () {
      const s = TimerSnapshot.idle();
      expect(s.isActive, isFalse);
      expect(s.elapsed(start), Duration.zero);
      expect(s.isComplete(start), isFalse);
      expect(s.progress(start), 0);
    });

    test('running elapsed is derived from the wall clock', () {
      final s = TimerSnapshot(
        isRunning: true,
        type: SessionType.work,
        plannedDuration: const Duration(minutes: 25),
        startedAt: start,
        pausedElapsed: Duration.zero,
      );
      final now = start.add(const Duration(minutes: 10));
      expect(s.elapsed(now), const Duration(minutes: 10));
      expect(s.remaining(now), const Duration(minutes: 15));
      expect(s.progress(now), closeTo(10 / 25, 1e-9));
      expect(s.isComplete(now), isFalse);
    });

    test('paused elapsed does not advance with the clock', () {
      const s = TimerSnapshot(
        isRunning: false,
        type: SessionType.work,
        plannedDuration: Duration(minutes: 25),
        startedAt: null,
        pausedElapsed: Duration(minutes: 10),
      );
      final later = start.add(const Duration(minutes: 30));
      expect(s.elapsed(later), const Duration(minutes: 10));
      expect(s.isActive, isTrue);
    });

    test('resumed segment adds onto paused elapsed', () {
      final resumeAt = start.add(const Duration(minutes: 10));
      final s = TimerSnapshot(
        isRunning: true,
        type: SessionType.work,
        plannedDuration: const Duration(minutes: 25),
        startedAt: resumeAt,
        pausedElapsed: const Duration(minutes: 10),
      );
      final now = resumeAt.add(const Duration(minutes: 5));
      expect(s.elapsed(now), const Duration(minutes: 15));
      expect(s.remaining(now), const Duration(minutes: 10));
    });

    test('completes and clamps remaining at zero past the planned duration',
        () {
      final s = TimerSnapshot(
        isRunning: true,
        type: SessionType.work,
        plannedDuration: const Duration(minutes: 25),
        startedAt: start,
        pausedElapsed: Duration.zero,
      );
      final past = start.add(const Duration(minutes: 30));
      expect(s.isComplete(past), isTrue);
      expect(s.remaining(past), Duration.zero);
      expect(s.progress(past), 1.0);
    });
  });

  group('formatTimer', () {
    test('mm:ss under an hour', () {
      expect(formatTimer(const Duration(minutes: 25)), '25:00');
      expect(formatTimer(const Duration(seconds: 5)), '00:05');
      expect(formatTimer(const Duration(minutes: 1, seconds: 9)), '01:09');
    });

    test('h:mm:ss at/over an hour', () {
      expect(formatTimer(const Duration(hours: 1, minutes: 2, seconds: 3)),
          '1:02:03');
    });
  });
}
