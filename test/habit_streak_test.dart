import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/data/repositories/habit_repository.dart';

void main() {
  DateTime d(int day) => DateTime(2026, 6, day);
  final today = d(6);

  group('computeStreak', () {
    test('no completions -> 0', () {
      expect(computeStreak(<DateTime>{}, today), 0);
    });

    test('done today only -> 1', () {
      expect(computeStreak({d(6)}, today), 1);
    });

    test('consecutive days including today -> 3', () {
      expect(computeStreak({d(4), d(5), d(6)}, today), 3);
    });

    test('grace: done yesterday but not today still counts', () {
      expect(computeStreak({d(4), d(5)}, today), 2);
    });

    test('missed both today and yesterday -> 0', () {
      expect(computeStreak({d(3), d(4)}, today), 0);
    });

    test('a gap breaks the streak', () {
      expect(computeStreak({d(2), d(4), d(5), d(6)}, today), 3);
    });
  });
}
