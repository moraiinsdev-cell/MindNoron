import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/features/timer/focus_suggestion.dart';

void main() {
  group('suggestFocusMinutes', () {
    test('neutral or unknown energy keeps the configured length', () {
      expect(suggestFocusMinutes(0, 25), 25);
      expect(suggestFocusMinutes(3, 25), 25);
    });

    test('low energy shortens the sprint', () {
      expect(suggestFocusMinutes(1, 25), 15); // 25 * 0.6
      expect(suggestFocusMinutes(2, 25), 20); // 25 * 0.8
    });

    test('high energy lengthens it (rounded to 5)', () {
      expect(suggestFocusMinutes(4, 25), 30); // 28.75 -> 30
      expect(suggestFocusMinutes(5, 25), 35); // 32.5 -> 35
    });

    test('clamps to a sane range', () {
      expect(suggestFocusMinutes(1, 5), 5); // floor at 5
      expect(suggestFocusMinutes(5, 90), 90); // ceiling at 90
    });
  });
}
