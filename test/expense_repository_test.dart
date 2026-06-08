import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/data/repositories/expense_repository.dart';

void main() {
  group('parseExpenseAmountVnd', () {
    test('keeps only digits for VND-style input', () {
      expect(parseExpenseAmountVnd('50.000'), 50000);
      expect(parseExpenseAmountVnd('1,250,000 VND'), 1250000);
    });

    test('empty or non-numeric input yields zero', () {
      expect(parseExpenseAmountVnd(''), 0);
      expect(parseExpenseAmountVnd('coffee'), 0);
    });
  });

  group('expense ranges', () {
    test('day range is midnight to next midnight', () {
      final range = expenseRangeFor(ExpensePeriod.day, DateTime(2026, 6, 8, 9));
      expect(range.start, DateTime(2026, 6, 8));
      expect(range.end, DateTime(2026, 6, 9));
    });

    test('month range handles year boundaries', () {
      final range = expenseRangeFor(ExpensePeriod.month, DateTime(2026, 12, 8));
      final previous =
          previousExpenseRangeFor(ExpensePeriod.month, DateTime(2026, 1, 8));
      expect(range.start, DateTime(2026, 12));
      expect(range.end, DateTime(2027, 1));
      expect(previous.start, DateTime(2025, 12));
      expect(previous.end, DateTime(2026, 1));
    });
  });

  group('summarizeExpenses', () {
    test('computes totals, change, and top category', () {
      final summary = summarizeExpenses(
        period: ExpensePeriod.month,
        anchor: DateTime(2026, 6, 8),
        current: [
          ExpenseSlice(
            amountVnd: 100000,
            spentAt: DateTime(2026, 6, 1),
            category: 'Food',
          ),
          ExpenseSlice(
            amountVnd: 50000,
            spentAt: DateTime(2026, 6, 2),
            category: 'Transport',
          ),
          ExpenseSlice(
            amountVnd: 25000,
            spentAt: DateTime(2026, 6, 3),
            category: 'Food',
          ),
        ],
        previous: [
          ExpenseSlice(
            amountVnd: 100000,
            spentAt: DateTime(2026, 5, 1),
            category: 'Food',
          ),
        ],
      );

      expect(summary.totalVnd, 175000);
      expect(summary.previousTotalVnd, 100000);
      expect(summary.entryCount, 3);
      expect(summary.changePercent, closeTo(75, 0.001));
      expect(summary.topCategory?.category, 'Food');
      expect(summary.topCategory?.totalVnd, 125000);
    });
  });

  group('emptyExpenseTrendBuckets', () {
    test('daily trend returns 14 day buckets', () {
      final buckets = emptyExpenseTrendBuckets(
        ExpensePeriod.day,
        DateTime(2026, 6, 8),
      );
      expect(buckets, hasLength(14));
      expect(buckets.first.start, DateTime(2026, 5, 26));
      expect(buckets.last.start, DateTime(2026, 6, 8));
    });
  });
}
