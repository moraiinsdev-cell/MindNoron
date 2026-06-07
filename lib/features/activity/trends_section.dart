import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_date_utils.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/daily_log_repository.dart';

/// Trend charts: weekly focus minutes (last 8 weeks) and the daily energy
/// check-in trend (last 14 days). Complements the contribution heatmap.
class TrendsSection extends ConsumerWidget {
  const TrendsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(recentFocusProvider).valueOrNull ?? const {};
    final energy = ref.watch(energyHistoryProvider).valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartCard(
          title: 'Focus by week',
          subtitle: 'Minutes focused, last 8 weeks',
          child: _WeeklyFocusChart(daily: focus),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Energy trend',
          subtitle: 'Daily check-in (1–5), last 14 days',
          child: _EnergyChart(logs: energy),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            Text(subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            SizedBox(height: 180, child: child),
          ],
        ),
      ),
    );
  }
}

class _WeeklyFocusChart extends StatelessWidget {
  const _WeeklyFocusChart({required this.daily});

  final Map<DateTime, int> daily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Build 8 week buckets (oldest → newest), Monday-aligned.
    final today = AppDateUtils.startOfDay(DateTime.now());
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekStarts = [
      for (var i = 7; i >= 0; i--)
        thisWeekStart.subtract(Duration(days: 7 * i)),
    ];
    final totals = [
      for (final ws in weekStarts)
        () {
          var sum = 0;
          for (var d = 0; d < 7; d++) {
            sum += daily[ws.add(Duration(days: d))] ?? 0;
          }
          return sum;
        }(),
    ];
    final maxTotal = totals.fold<int>(0, (a, b) => a > b ? a : b);

    if (maxTotal == 0) {
      return _empty(context, 'No focus sessions yet');
    }
    final maxY = (maxTotal * 1.2).ceilToDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${rod.toY.round()} min',
              theme.textTheme.bodySmall!
                  .copyWith(color: cs.onInverseSurface),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                if (value != 0 && value != maxY) return const SizedBox.shrink();
                return Text('${value.round()}',
                    style: theme.textTheme.labelSmall);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= weekStarts.length) {
                  return const SizedBox.shrink();
                }
                final ws = weekStarts[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${ws.month}/${ws.day}',
                      style: theme.textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < totals.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: totals[i].toDouble(),
                  color: cs.primary,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EnergyChart extends StatelessWidget {
  const _EnergyChart({required this.logs});

  final List<DailyLog> logs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final points = [
      for (final l in logs)
        if (l.energyLevel != null) (l.date, l.energyLevel!),
    ];

    if (points.length < 2) {
      return _empty(context, 'Check in your energy for a few days');
    }

    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].$2.toDouble()),
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 5,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: cs.outlineVariant, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (value, _) {
                if (value % 1 != 0 || value < 1 || value > 5) {
                  return const SizedBox.shrink();
                }
                return Text('${value.toInt()}',
                    style: theme.textTheme.labelSmall);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (points.length / 4).ceilToDouble(),
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                final d = points[i].$1;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${d.month}/${d.day}',
                      style: theme.textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: cs.tertiary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: cs.tertiary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _empty(BuildContext context, String message) {
  final theme = Theme.of(context);
  return Center(
    child: Text(
      message,
      style: theme.textTheme.bodyMedium
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    ),
  );
}
