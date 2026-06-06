import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/features/tasks/task_urgency.dart';

void main() {
  final now = DateTime(2026, 6, 6, 12);

  group('urgencyForDates', () {
    test('fresh undated task is not urgent', () {
      expect(urgencyForDates(null, now.subtract(const Duration(hours: 3)), now),
          0);
    });

    test('undated task escalates with age', () {
      expect(urgencyForDates(null, now.subtract(const Duration(days: 2)), now),
          1);
      expect(urgencyForDates(null, now.subtract(const Duration(days: 4)), now),
          2);
      expect(urgencyForDates(null, now.subtract(const Duration(days: 9)), now),
          3);
    });

    test('overdue dated task escalates', () {
      // due in the future → fine
      expect(urgencyForDates(now.add(const Duration(days: 1)), now, now), 0);
      // just past due → 1
      expect(
          urgencyForDates(now.subtract(const Duration(hours: 2)), now, now), 1);
      // 1-2 days overdue → 2
      expect(
          urgencyForDates(now.subtract(const Duration(days: 1)), now, now), 2);
      // 3+ days overdue → 3 (most urgent)
      expect(
          urgencyForDates(now.subtract(const Duration(days: 4)), now, now), 3);
    });
  });

  group('ageLabelForDates', () {
    test('undated labels', () {
      expect(ageLabelForDates(null, now, now), 'Today');
      expect(ageLabelForDates(null, now.subtract(const Duration(days: 1)), now),
          'Yesterday');
      expect(ageLabelForDates(null, now.subtract(const Duration(days: 5)), now),
          '5d ago');
    });

    test('dated labels', () {
      expect(
          ageLabelForDates(now.subtract(const Duration(days: 2)), now, now),
          '2d overdue');
      expect(ageLabelForDates(now.add(const Duration(days: 3)), now, now),
          'Due in 3d');
    });
  });
}
