/// The bridge between what you *spend* (the Expenses feature) and what your
/// savings are *measured against* (the Quỹ tab).
///
/// Runway — the headline number of the whole savings system — is savings ÷
/// living costs. Ask a freelancer for that denominator and they will guess, and
/// they will guess low: nobody remembers the electricity bill. But the app has
/// already been logging the answer for months. So it computes the number and
/// offers it, instead of asking.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/expense_repository.dart';

/// Categories that keep you alive and housed, as opposed to categories that
/// make life good or make work possible.
///
/// The distinction is not moral, it is arithmetic: runway asks "how long can I
/// survive if the money stops", and in that month you would not be buying a GPU
/// (Work), taking a course (Learning) or going out (Fun) — but you would still
/// be eating and paying rent. Counting the discretionary spend would inflate
/// the denominator and make your runway look *shorter* than it is, which sounds
/// conservative but is just wrong.
const kEssentialCategories = {
  'General',
  'Food',
  'Transport',
  'Bills',
  'Home',
  'Health',
};

/// What the expense log says a month of living costs.
class LivingCostEstimate {
  const LivingCostEstimate({
    required this.essentialMonthly,
    required this.totalMonthly,
    required this.monthsCovered,
    required this.from,
    required this.to,
    required this.entryCount,
  });

  /// Average đồng/month across [monthsCovered] of essential categories only.
  final int essentialMonthly;

  /// Average đồng/month across everything logged — what you actually live on
  /// today, including the nice-to-haves.
  final int totalMonthly;

  /// Whole months the average is drawn from.
  final int monthsCovered;

  final DateTime from;
  final DateTime to;
  final int entryCount;

  /// One month of data is an anecdote; three is a pattern. Below that the UI
  /// still shows the number, but says out loud that it is thin.
  bool get isThin => monthsCovered < 3 || entryCount < 10;

  bool get hasData => entryCount > 0 && essentialMonthly > 0;
}

/// Averages the last [months] **complete** calendar months before [today].
///
/// The month in progress is deliberately excluded: on the 3rd of the month it
/// holds three days of spending, and averaging it in would quietly halve the
/// estimate — the exact direction of error that makes a runway look safe when
/// it isn't.
LivingCostEstimate estimateLivingCost({
  required List<ExpenseSlice> entries,
  required DateTime today,
  int months = 3,
}) {
  final windowEnd = DateTime(today.year, today.month); // 1st of this month
  final windowStart = DateTime(today.year, today.month - months);

  var essential = 0;
  var total = 0;
  var count = 0;
  for (final e in entries) {
    if (e.spentAt.isBefore(windowStart) || !e.spentAt.isBefore(windowEnd)) {
      continue;
    }
    total += e.amountVnd;
    count++;
    if (kEssentialCategories.contains(e.category)) essential += e.amountVnd;
  }

  return LivingCostEstimate(
    essentialMonthly: months <= 0 ? 0 : essential ~/ months,
    totalMonthly: months <= 0 ? 0 : total ~/ months,
    monthsCovered: months,
    from: windowStart,
    to: windowEnd,
    entryCount: count,
  );
}

/// The window the estimate is drawn from: the last three complete months.
final livingCostProvider = StreamProvider<LivingCostEstimate>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 3);
  final end = DateTime(now.year, now.month);

  return ref
      .watch(expenseRepositoryProvider)
      .watchEntriesBetween(start, end)
      .map((rows) => estimateLivingCost(
            entries: [for (final r in rows) ExpenseSlice.fromEntry(r)],
            today: now,
          ));
});
