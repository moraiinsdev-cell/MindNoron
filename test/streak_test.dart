import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/data/repositories/habit_repository.dart';

void main() {
  DateTime d(int day) => DateTime(2026, 6, day);

  group('computeLongestStreak', () {
    test('empty is zero', () {
      expect(computeLongestStreak({}), 0);
    });

    test('single day is one', () {
      expect(computeLongestStreak({d(3)}), 1);
    });

    test('finds the longest consecutive run', () {
      // 1,2,3 (run 3) … gap … 6,7 (run 2) … gap … 10 (run 1)
      final days = {d(1), d(2), d(3), d(6), d(7), d(10)};
      expect(computeLongestStreak(days), 3);
    });

    test('all consecutive', () {
      expect(computeLongestStreak({d(1), d(2), d(3), d(4), d(5)}), 5);
    });

    test('duplicate timestamps in same day collapse', () {
      final days = {
        DateTime(2026, 6, 1, 9),
        DateTime(2026, 6, 1, 18),
        DateTime(2026, 6, 2, 8),
      };
      expect(computeLongestStreak(days), 2);
    });
  });
}
