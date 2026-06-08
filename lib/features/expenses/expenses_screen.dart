import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/expense_repository.dart';
import '../../presentation/widgets/common/section_scaffold.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  ExpensePeriod _period = ExpensePeriod.day;
  DateTime _anchor = DateTime.now();

  ExpensePeriodQuery get _query => (period: _period, anchor: _anchor);

  DateTime _shiftedAnchor(int direction) {
    return switch (_period) {
      ExpensePeriod.day => _anchor.add(Duration(days: direction)),
      ExpensePeriod.month => DateTime(
          _anchor.year,
          _anchor.month + direction,
          math.min(_anchor.day, 28),
        ),
      ExpensePeriod.year => DateTime(
          _anchor.year + direction,
          _anchor.month,
          math.min(_anchor.day, 28),
        ),
    };
  }

  bool get _canMoveForward {
    final next = expenseRangeFor(_period, _shiftedAnchor(1)).start;
    final now = expenseRangeFor(_period, DateTime.now()).start;
    return !next.isAfter(now);
  }

  void _move(int direction) {
    setState(() => _anchor = _shiftedAnchor(direction));
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _formatRangeLabel(_period, _anchor);

    return SectionScaffold(
      title: 'Expenses',
      subtitle: rangeLabel,
      actions: [
        SegmentedButton<ExpensePeriod>(
          segments: [
            for (final period in ExpensePeriod.values)
              ButtonSegment(
                value: period,
                label: Text(period.segmentLabel),
                icon: Icon(_periodIcon(period)),
              ),
          ],
          selected: {_period},
          onSelectionChanged: (value) {
            setState(() => _period = value.first);
          },
        ),
        IconButton(
          tooltip: 'Previous ${_period.label.toLowerCase()}',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _move(-1),
        ),
        IconButton(
          tooltip: 'Next ${_period.label.toLowerCase()}',
          icon: const Icon(Icons.chevron_right),
          onPressed: _canMoveForward ? () => _move(1) : null,
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _anchor = DateTime.now()),
          icon: const Icon(Icons.today_outlined),
          label: const Text('Today'),
        ),
      ],
      child: ListView(
        children: [
          const _ExpenseEntryForm(),
          const SizedBox(height: 20),
          _ExpenseSummarySection(query: _query),
          const SizedBox(height: 16),
          _ExpenseTrendCard(query: _query),
          const SizedBox(height: 16),
          _ExpenseEntriesList(query: _query),
        ],
      ),
    );
  }
}

class _ExpenseEntryForm extends ConsumerStatefulWidget {
  const _ExpenseEntryForm();

  @override
  ConsumerState<_ExpenseEntryForm> createState() => _ExpenseEntryFormState();
}

class _ExpenseEntryFormState extends ConsumerState<_ExpenseEntryForm> {
  static const _categories = [
    'General',
    'Food',
    'Transport',
    'Bills',
    'Home',
    'Health',
    'Learning',
    'Work',
    'Fun',
  ];

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _spentAt = DateTime.now();
  String _category = _categories.first;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _spentAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _spentAt.hour,
        _spentAt.minute,
      );
    });
  }

  Future<void> _add() async {
    final title = _titleController.text.trim();
    final amount = parseExpenseAmountVnd(_amountController.text);
    final note = _noteController.text.trim();
    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a name and an amount above 0')),
      );
      return;
    }

    await ref.read(expenseRepositoryProvider).create(
          title: title,
          amountVnd: amount,
          spentAt: _spentAt,
          category: _category,
          note: note.isEmpty ? null : note,
        );
    if (!mounted) return;
    _titleController.clear();
    _amountController.clear();
    _noteController.clear();
    setState(() => _spentAt = DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 900;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('New expense', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            if (compact)
              Column(
                children: [
                  _TitleField(controller: _titleController),
                  const SizedBox(height: 10),
                  _AmountField(controller: _amountController),
                  const SizedBox(height: 10),
                  _CategoryField(
                    value: _category,
                    categories: _categories,
                    onChanged: (value) => setState(() => _category = value),
                  ),
                  const SizedBox(height: 10),
                  _DateField(spentAt: _spentAt, onTap: _pickDate),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _TitleField(controller: _titleController),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _AmountField(controller: _amountController),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _CategoryField(
                      value: _category,
                      categories: _categories,
                      onChanged: (value) => setState(() => _category = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _DateField(spentAt: _spentAt, onTap: _pickDate)),
                ],
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Optional note',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'What did you spend on?',
        prefixIcon: Icon(Icons.sell_outlined),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        hintText: 'Amount VND',
        prefixIcon: Icon(Icons.payments_outlined),
      ),
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.value,
    required this.categories,
    required this.onChanged,
  });

  final String value;
  final List<String> categories;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: [
        for (final category in categories)
          DropdownMenuItem(value: category, child: Text(category)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.spentAt, required this.onTap});

  final DateTime spentAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.event_outlined),
      label: Text(_formatDate(spentAt)),
    );
  }
}

class _ExpenseSummarySection extends ConsumerWidget {
  const _ExpenseSummarySection({required this.query});

  final ExpensePeriodQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseSummaryProvider(query));

    return async.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text('Could not load expenses: $error'),
      data: (summary) {
        final topCategory = summary.topCategory;
        final change = summary.changePercent;
        final changeLabel = change == null
            ? 'No previous data'
            : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'This ${summary.period.label.toLowerCase()}',
                  value: formatVnd(summary.totalVnd),
                  highlight: summary.totalVnd > 0,
                ),
                _StatCard(
                  icon: Icons.history_outlined,
                  label: 'Previous ${summary.period.label.toLowerCase()}',
                  value: formatVnd(summary.previousTotalVnd),
                ),
                _StatCard(
                  icon: summary.differenceVnd > 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  label: 'Change',
                  value: changeLabel,
                  highlight: summary.differenceVnd < 0,
                ),
                _StatCard(
                  icon: Icons.receipt_outlined,
                  label: 'Entries',
                  value: '${summary.entryCount}',
                ),
                if (topCategory != null)
                  _StatCard(
                    icon: Icons.pie_chart_outline,
                    label: topCategory.category,
                    value: formatVnd(topCategory.totalVnd),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _BalanceAdvice(summary: summary),
          ],
        );
      },
    );
  }
}

class _BalanceAdvice extends StatelessWidget {
  const _BalanceAdvice({required this.summary});

  final ExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final advice = _adviceLines(summary);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.balance_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text('Balance notes', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            for (final line in advice)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 17, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _adviceLines(ExpenseSummary summary) {
    if (summary.totalVnd == 0) {
      return const [
        'No spending logged in this period yet.',
        'Start with small daily notes so the comparison becomes useful.',
      ];
    }

    final lines = <String>[];
    final top = summary.topCategory;
    final change = summary.changePercent;
    if (change != null) {
      if (change >= 25) {
        lines.add(
          'Spending is up ${change.toStringAsFixed(1)}% from the previous '
          '${summary.period.label.toLowerCase()}. Review the largest category.',
        );
      } else if (change <= -10) {
        lines.add(
          'Spending is down ${change.abs().toStringAsFixed(1)}% from the '
          'previous ${summary.period.label.toLowerCase()}.',
        );
      } else {
        lines.add('Spending is close to the previous period.');
      }
    } else {
      lines.add('Keep logging this period to build a useful baseline.');
    }

    if (top != null && summary.totalVnd > 0) {
      final share = top.totalVnd / summary.totalVnd;
      if (share >= 0.5) {
        lines.add(
          '${top.category} is ${(share * 100).round()}% of this period. '
          'That is the first place to check for balance.',
        );
      } else {
        lines.add(
          'Top category: ${top.category} at ${formatVnd(top.totalVnd)}.',
        );
      }
    }

    if (summary.period != ExpensePeriod.day) {
      final projected = _projectedPeriodTotal(summary);
      if (projected > summary.totalVnd) {
        lines.add(
          'Current pace points to about ${formatVnd(projected)} by period end.',
        );
      }
    }

    return lines;
  }

  int _projectedPeriodTotal(ExpenseSummary summary) {
    final now = DateTime.now();
    final range = summary.currentRange;
    final periodDays = range.end.difference(range.start).inDays;
    if (periodDays <= 0) return summary.totalVnd;
    final effectiveNow = now.isBefore(range.start)
        ? range.start
        : now.isAfter(range.end)
            ? range.end.subtract(const Duration(days: 1))
            : now;
    final elapsedDays =
        math.max(1, effectiveNow.difference(range.start).inDays + 1);
    return (summary.totalVnd / elapsedDays * periodDays).round();
  }
}

class _ExpenseTrendCard extends ConsumerWidget {
  const _ExpenseTrendCard({required this.query});

  final ExpensePeriodQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseTrendProvider(query));
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${query.period.segmentLabel} comparison',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Chart error: $error')),
                data: (points) => _ExpenseBarChart(points: points),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseBarChart extends StatelessWidget {
  const _ExpenseBarChart({required this.points});

  final List<ExpenseTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxValue =
        points.fold<int>(0, (max, point) => math.max(max, point.totalVnd));

    if (maxValue == 0) {
      return Center(
        child: Text(
          'No expenses to compare yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }

    final maxY = (maxValue * 1.2).ceilToDouble();
    final labelEvery = points.length > 8 ? 2 : 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: cs.outlineVariant, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              formatVnd(rod.toY.round()),
              theme.textTheme.bodySmall!.copyWith(color: cs.onInverseSurface),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, _) {
                if (value != 0 && value != maxY) return const SizedBox.shrink();
                return Text(shortVnd(value.round()),
                    style: theme.textTheme.labelSmall);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                if (index % labelEvery != 0 && index != points.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    points[index].label,
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].totalVnd.toDouble(),
                  color: cs.primary,
                  width: points.length > 10 ? 10 : 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExpenseEntriesList extends ConsumerWidget {
  const _ExpenseEntriesList({required this.query});

  final ExpensePeriodQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseEntriesProvider(query));
    final theme = Theme.of(context);

    return async.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text('Could not load entries: $error'),
      data: (entries) {
        if (entries.isEmpty) {
          return const SizedBox(
            height: 160,
            child: ComingSoon(label: 'No expenses in this period'),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Entries', style: theme.textTheme.titleMedium),
                ),
                for (var i = 0; i < entries.length; i++) ...[
                  _ExpenseTile(entry: entries[i]),
                  if (i < entries.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.entry});

  final ExpenseEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.secondaryContainer,
        child: Icon(_categoryIcon(entry.category),
            color: cs.onSecondaryContainer, size: 20),
      ),
      title: Text(entry.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${entry.category} - ${_formatDate(entry.spentAt)}'
        '${entry.note == null ? '' : ' - ${entry.note}'}',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatVnd(entry.amountVnd),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                ref.read(expenseRepositoryProvider).softDelete(entry.id),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 18, color: highlight ? cs.tertiary : cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _periodIcon(ExpensePeriod period) {
  return switch (period) {
    ExpensePeriod.day => Icons.today_outlined,
    ExpensePeriod.month => Icons.calendar_view_month_outlined,
    ExpensePeriod.year => Icons.calendar_month_outlined,
  };
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'Food' => Icons.restaurant_outlined,
    'Transport' => Icons.directions_car_filled_outlined,
    'Bills' => Icons.receipt_long_outlined,
    'Home' => Icons.home_outlined,
    'Health' => Icons.health_and_safety_outlined,
    'Learning' => Icons.school_outlined,
    'Work' => Icons.work_outline,
    'Fun' => Icons.celebration_outlined,
    _ => Icons.payments_outlined,
  };
}

String _formatDate(DateTime date) {
  return DateFormat('M/d/yyyy').format(date);
}

String _formatRangeLabel(ExpensePeriod period, DateTime anchor) {
  return switch (period) {
    ExpensePeriod.day => DateFormat('EEEE, M/d/yyyy').format(anchor),
    ExpensePeriod.month => DateFormat('MMMM yyyy').format(anchor),
    ExpensePeriod.year => DateFormat('yyyy').format(anchor),
  };
}

String formatVnd(int amount) {
  return '${NumberFormat.decimalPattern('vi_VN').format(amount)} VND';
}

String shortVnd(int amount) {
  if (amount >= 1000000000) {
    return '${(amount / 1000000000).toStringAsFixed(1)}B';
  }
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).round()}K';
  }
  return '$amount';
}
