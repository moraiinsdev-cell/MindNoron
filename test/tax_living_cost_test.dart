import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/data/repositories/expense_repository.dart';
import 'package:mind_noron/features/tax/tax_living_cost.dart';

ExpenseSlice _e(int amount, DateTime at, String category) =>
    ExpenseSlice(amountVnd: amount, spentAt: at, category: category);

void main() {
  // Standing on 13/7: the complete months are April, May and June. July is in
  // progress and must not drag the average down.
  final today = DateTime(2026, 7, 13);

  test('averages the last three complete months', () {
    final est = estimateLivingCost(
      entries: [
        _e(18000000, DateTime(2026, 4, 10), 'Home'),
        _e(18000000, DateTime(2026, 5, 10), 'Home'),
        _e(18000000, DateTime(2026, 6, 10), 'Home'),
      ],
      today: today,
    );

    expect(est.essentialMonthly, 18000000);
    expect(est.monthsCovered, 3);
    expect(est.hasData, isTrue);
  });

  test('the month in progress is excluded — it would halve the estimate', () {
    final est = estimateLivingCost(
      entries: [
        _e(18000000, DateTime(2026, 4, 10), 'Home'),
        _e(18000000, DateTime(2026, 5, 10), 'Home'),
        _e(18000000, DateTime(2026, 6, 10), 'Home'),
        _e(2000000, DateTime(2026, 7, 2), 'Food'), // 13 days in, not a month
      ],
      today: today,
    );

    expect(est.essentialMonthly, 18000000,
        reason: 'July spending must not enter the average');
    expect(est.entryCount, 3);
  });

  test('anything older than the window is out of scope', () {
    final est = estimateLivingCost(
      entries: [
        _e(90000000, DateTime(2026, 1, 5), 'Home'), // way before the window
        _e(15000000, DateTime(2026, 6, 10), 'Home'),
      ],
      today: today,
    );
    expect(est.essentialMonthly, 5000000, reason: '15tr over 3 months');
  });

  test('discretionary spend is counted separately, not as survival cost', () {
    final est = estimateLivingCost(
      entries: [
        _e(30000000, DateTime(2026, 5, 3), 'Food'),
        _e(30000000, DateTime(2026, 5, 4), 'Bills'),
        _e(60000000, DateTime(2026, 5, 5), 'Fun'), // not needed to survive
        _e(30000000, DateTime(2026, 6, 6), 'Work'), // a business cost
        _e(30000000, DateTime(2026, 6, 7), 'Learning'),
      ],
      today: today,
    );

    expect(est.essentialMonthly, 20000000, reason: '60tr essential / 3 months');
    expect(est.totalMonthly, 60000000, reason: 'everything / 3 months');
    expect(est.totalMonthly > est.essentialMonthly, isTrue);
  });

  test('an empty log yields no estimate rather than a confident zero', () {
    final est = estimateLivingCost(entries: const [], today: today);
    expect(est.hasData, isFalse);
    expect(est.essentialMonthly, 0);
  });

  test('a thin log admits it is thin', () {
    final est = estimateLivingCost(
      entries: [_e(15000000, DateTime(2026, 6, 10), 'Home')],
      today: today,
    );
    expect(est.hasData, isTrue);
    expect(est.isThin, isTrue, reason: 'one entry is an anecdote');
  });
}
