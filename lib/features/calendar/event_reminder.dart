import 'dart:async';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/notification_service.dart';
import '../../data/repositories/event_repository.dart';
import 'calendar_utils.dart';

/// Fires desktop reminder toasts for upcoming events while the app is running.
///
/// `local_notifier` can only show toasts immediately (no native scheduling), so
/// we poll every 30s and surface any reminder whose fire-time has just passed.
/// Each occurrence fires at most once per session (tracked by id).
class EventReminderScheduler {
  EventReminderScheduler(this._ref) {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
    _tick();
  }

  final Ref _ref;
  Timer? _timer;
  final Set<String> _fired = {};

  Future<void> _tick() async {
    final now = DateTime.now();
    final range = DateTimeRange(
      start: now.subtract(const Duration(minutes: 1)),
      end: now.add(const Duration(days: 2)),
    );
    final events = await _ref
        .read(eventRepositoryProvider)
        .watchBetween(range.start, range.end)
        .first;
    final items = CalendarUtils.expandEventsOnly(events, range);

    for (final item in items) {
      final mins = item.event?.reminderMinutes;
      if (mins == null) continue;
      if (_fired.contains(item.id)) continue;

      final fireTime = item.start.subtract(Duration(minutes: mins));
      final alreadyStarted =
          !now.isBefore(item.start.add(const Duration(minutes: 1)));
      if (now.isBefore(fireTime) || alreadyStarted) continue;

      _fired.add(item.id);
      await NotificationService.show(
        title: item.title,
        body: _body(item.start, mins),
      );
    }
  }

  static String _body(DateTime start, int mins) {
    final at = CalendarUtils.timeLabel(start);
    if (mins <= 0) return 'Starting now · $at';
    if (mins < 60) return 'In $mins min · $at';
    if (mins < 1440) return 'In ${mins ~/ 60}h · $at';
    return 'Tomorrow · $at';
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Kept alive while the app shell is mounted (see `AppShell`).
final eventReminderProvider = Provider<EventReminderScheduler>((ref) {
  final scheduler = EventReminderScheduler(ref);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
