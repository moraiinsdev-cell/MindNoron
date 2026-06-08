import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/app_date_utils.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

enum ExpensePeriod {
  day('Day', 'Daily'),
  month('Month', 'Monthly'),
  year('Year', 'Yearly');

  const ExpensePeriod(this.label, this.segmentLabel);

  final String label;
  final String segmentLabel;
}

typedef ExpenseRange = ({DateTime start, DateTime end});
typedef ExpensePeriodQuery = ({ExpensePeriod period, DateTime anchor});

class ExpenseSlice {
  const ExpenseSlice({
    required this.amountVnd,
    required this.spentAt,
    required this.category,
  });

  factory ExpenseSlice.fromEntry(ExpenseEntry entry) {
    return ExpenseSlice(
      amountVnd: entry.amountVnd,
      spentAt: entry.spentAt,
      category: entry.category,
    );
  }

  final int amountVnd;
  final DateTime spentAt;
  final String category;
}

class ExpenseCategoryTotal {
  const ExpenseCategoryTotal({
    required this.category,
    required this.totalVnd,
    required this.count,
  });

  final String category;
  final int totalVnd;
  final int count;
}

class ExpenseSummary {
  const ExpenseSummary({
    required this.period,
    required this.currentRange,
    required this.previousRange,
    required this.totalVnd,
    required this.previousTotalVnd,
    required this.entryCount,
    required this.dailyAverageVnd,
    required this.highestExpenseVnd,
    required this.categoryTotals,
  });

  final ExpensePeriod period;
  final ExpenseRange currentRange;
  final ExpenseRange previousRange;
  final int totalVnd;
  final int previousTotalVnd;
  final int entryCount;
  final int dailyAverageVnd;
  final int highestExpenseVnd;
  final List<ExpenseCategoryTotal> categoryTotals;

  double? get changePercent {
    if (previousTotalVnd == 0) return null;
    return ((totalVnd - previousTotalVnd) / previousTotalVnd) * 100;
  }

  int get differenceVnd => totalVnd - previousTotalVnd;

  ExpenseCategoryTotal? get topCategory =>
      categoryTotals.isEmpty ? null : categoryTotals.first;
}

class ExpenseTrendPoint {
  const ExpenseTrendPoint({
    required this.start,
    required this.label,
    required this.totalVnd,
  });

  final DateTime start;
  final String label;
  final int totalVnd;
}

int parseExpenseAmountVnd(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

ExpenseRange expenseRangeFor(ExpensePeriod period, DateTime anchor) {
  return switch (period) {
    ExpensePeriod.day => (
        start: AppDateUtils.startOfDay(anchor),
        end: AppDateUtils.startOfDay(anchor).add(const Duration(days: 1)),
      ),
    ExpensePeriod.month => (
        start: DateTime(anchor.year, anchor.month),
        end: DateTime(anchor.year, anchor.month + 1),
      ),
    ExpensePeriod.year => (
        start: DateTime(anchor.year),
        end: DateTime(anchor.year + 1),
      ),
  };
}

ExpenseRange previousExpenseRangeFor(ExpensePeriod period, DateTime anchor) {
  final current = expenseRangeFor(period, anchor);
  return switch (period) {
    ExpensePeriod.day => (
        start: current.start.subtract(const Duration(days: 1)),
        end: current.start,
      ),
    ExpensePeriod.month => (
        start: DateTime(current.start.year, current.start.month - 1),
        end: current.start,
      ),
    ExpensePeriod.year => (
        start: DateTime(current.start.year - 1),
        end: current.start,
      ),
  };
}

ExpenseSummary summarizeExpenses({
  required ExpensePeriod period,
  required DateTime anchor,
  required List<ExpenseSlice> current,
  required List<ExpenseSlice> previous,
}) {
  final categoryMap = <String, ({int total, int count})>{};
  var total = 0;
  var highest = 0;
  for (final expense in current) {
    total += expense.amountVnd;
    if (expense.amountVnd > highest) highest = expense.amountVnd;
    final category =
        expense.category.trim().isEmpty ? 'General' : expense.category.trim();
    final existing = categoryMap[category] ?? (total: 0, count: 0);
    categoryMap[category] = (
      total: existing.total + expense.amountVnd,
      count: existing.count + 1,
    );
  }

  final categoryTotals = [
    for (final entry in categoryMap.entries)
      ExpenseCategoryTotal(
        category: entry.key,
        totalVnd: entry.value.total,
        count: entry.value.count,
      ),
  ]..sort((a, b) => b.totalVnd.compareTo(a.totalVnd));

  final previousTotal =
      previous.fold<int>(0, (sum, expense) => sum + expense.amountVnd);
  final currentRange = expenseRangeFor(period, anchor);
  final days = currentRange.end.difference(currentRange.start).inDays;

  return ExpenseSummary(
    period: period,
    currentRange: currentRange,
    previousRange: previousExpenseRangeFor(period, anchor),
    totalVnd: total,
    previousTotalVnd: previousTotal,
    entryCount: current.length,
    dailyAverageVnd: days <= 0 ? total : total ~/ days,
    highestExpenseVnd: highest,
    categoryTotals: categoryTotals,
  );
}

List<ExpenseTrendPoint> emptyExpenseTrendBuckets(
  ExpensePeriod period,
  DateTime anchor,
) {
  return switch (period) {
    ExpensePeriod.day => [
        for (var i = 13; i >= 0; i--)
          () {
            final day = AppDateUtils.startOfDay(
              anchor.subtract(Duration(days: i)),
            );
            return ExpenseTrendPoint(
              start: day,
              label: '${day.month}/${day.day}',
              totalVnd: 0,
            );
          }(),
      ],
    ExpensePeriod.month => [
        for (var i = 11; i >= 0; i--)
          () {
            final month = DateTime(anchor.year, anchor.month - i);
            return ExpenseTrendPoint(
              start: month,
              label: '${month.month}/${month.year % 100}',
              totalVnd: 0,
            );
          }(),
      ],
    ExpensePeriod.year => [
        for (var i = 4; i >= 0; i--)
          () {
            final year = DateTime(anchor.year - i);
            return ExpenseTrendPoint(
              start: year,
              label: '${year.year}',
              totalVnd: 0,
            );
          }(),
      ],
  };
}

DateTime expenseBucketStart(ExpensePeriod period, DateTime date) {
  return switch (period) {
    ExpensePeriod.day => AppDateUtils.startOfDay(date),
    ExpensePeriod.month => DateTime(date.year, date.month),
    ExpensePeriod.year => DateTime(date.year),
  };
}

class ExpenseRepository {
  ExpenseRepository(this._db);

  final AppDatabase _db;

  Future<String> create({
    required String title,
    required int amountVnd,
    required DateTime spentAt,
    String category = 'General',
    String? note,
  }) async {
    final id = _uuid.v4();
    final trimmedCategory = category.trim();
    final trimmedNote = note?.trim();
    await _db.into(_db.expenseEntries).insert(
          ExpenseEntriesCompanion.insert(
            id: id,
            title: title.trim(),
            amountVnd: amountVnd,
            spentAt: spentAt,
            category: Value(
              trimmedCategory.isEmpty ? 'General' : trimmedCategory,
            ),
            note: Value(
              trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
            ),
          ),
        );
    return id;
  }

  Future<void> softDelete(String id) {
    return (_db.update(_db.expenseEntries)..where((t) => t.id.equals(id)))
        .write(
      ExpenseEntriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isDirty: const Value(true),
      ),
    );
  }

  Stream<List<ExpenseEntry>> watchEntriesInPeriod(
    ExpensePeriod period,
    DateTime anchor,
  ) {
    final range = expenseRangeFor(period, anchor);
    return (_db.select(_db.expenseEntries)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.spentAt.isBiggerOrEqualValue(range.start) &
              t.spentAt.isSmallerThanValue(range.end))
          ..orderBy([(t) => OrderingTerm.desc(t.spentAt)]))
        .watch();
  }

  Stream<ExpenseSummary> watchSummary(ExpensePeriod period, DateTime anchor) {
    final current = expenseRangeFor(period, anchor);
    final previous = previousExpenseRangeFor(period, anchor);
    return (_db.select(_db.expenseEntries)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.spentAt.isBiggerOrEqualValue(previous.start) &
              t.spentAt.isSmallerThanValue(current.end)))
        .watch()
        .map((rows) {
      final currentRows = <ExpenseSlice>[];
      final previousRows = <ExpenseSlice>[];
      for (final row in rows) {
        final slice = ExpenseSlice.fromEntry(row);
        if (!row.spentAt.isBefore(current.start)) {
          currentRows.add(slice);
        } else {
          previousRows.add(slice);
        }
      }
      return summarizeExpenses(
        period: period,
        anchor: anchor,
        current: currentRows,
        previous: previousRows,
      );
    });
  }

  Stream<List<ExpenseTrendPoint>> watchTrend(
    ExpensePeriod period,
    DateTime anchor,
  ) {
    final buckets = emptyExpenseTrendBuckets(period, anchor);
    final start = buckets.first.start;
    final end = expenseRangeFor(period, buckets.last.start).end;

    return (_db.select(_db.expenseEntries)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.spentAt.isBiggerOrEqualValue(start) &
              t.spentAt.isSmallerThanValue(end)))
        .watch()
        .map((rows) {
      final totals = {
        for (final bucket in buckets) bucket.start: bucket.totalVnd,
      };
      for (final row in rows) {
        final bucketStart = expenseBucketStart(period, row.spentAt);
        if (totals.containsKey(bucketStart)) {
          totals[bucketStart] = totals[bucketStart]! + row.amountVnd;
        }
      }
      return [
        for (final bucket in buckets)
          ExpenseTrendPoint(
            start: bucket.start,
            label: bucket.label,
            totalVnd: totals[bucket.start] ?? 0,
          ),
      ];
    });
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(databaseProvider));
});

final expenseEntriesProvider =
    StreamProvider.family<List<ExpenseEntry>, ExpensePeriodQuery>((ref, query) {
  return ref
      .watch(expenseRepositoryProvider)
      .watchEntriesInPeriod(query.period, query.anchor);
});

final expenseSummaryProvider =
    StreamProvider.family<ExpenseSummary, ExpensePeriodQuery>((ref, query) {
  return ref
      .watch(expenseRepositoryProvider)
      .watchSummary(query.period, query.anchor);
});

final expenseTrendProvider =
    StreamProvider.family<List<ExpenseTrendPoint>, ExpensePeriodQuery>(
  (ref, query) {
    return ref
        .watch(expenseRepositoryProvider)
        .watchTrend(query.period, query.anchor);
  },
);
