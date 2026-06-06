import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/core/utils/app_date_utils.dart';

void main() {
  group('AppDateUtils', () {
    test('startOfDay strips the time component', () {
      final d = DateTime(2026, 6, 6, 13, 45, 30);
      expect(AppDateUtils.startOfDay(d), DateTime(2026, 6, 6));
    });

    test('endOfDay is the last millisecond of the day', () {
      final d = DateTime(2026, 6, 6, 0, 0);
      expect(AppDateUtils.endOfDay(d), DateTime(2026, 6, 6, 23, 59, 59, 999));
    });

    test('isSameDay ignores time', () {
      expect(
        AppDateUtils.isSameDay(
            DateTime(2026, 6, 6, 1), DateTime(2026, 6, 6, 23)),
        isTrue,
      );
      expect(
        AppDateUtils.isSameDay(DateTime(2026, 6, 6), DateTime(2026, 6, 7)),
        isFalse,
      );
    });

    test('upcomingRange returns an ordered [start, end] window', () {
      final (start, end) = AppDateUtils.upcomingRange(7);
      expect(end.isAfter(start), isTrue);
    });
  });
}
