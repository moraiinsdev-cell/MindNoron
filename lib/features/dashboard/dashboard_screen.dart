import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/utils/greeting.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/timer_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/common/copy_button.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import '../capture/capture_dialog.dart';
import '../motivation/quotes.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final focus = ref.watch(focusMinutesTodayProvider).valueOrNull ?? 0;
    final doneToday = ref.watch(completedTodayCountProvider).valueOrNull ?? 0;
    final List<Task> topTasks =
        (ref.watch(openTasksProvider).valueOrNull ?? const <Task>[])
            .take(5)
            .toList();
    final quote = ref.watch(randomQuoteProvider);

    return SectionScaffold(
      title: greetingFor(l10n, now),
      subtitle: '${now.month}/${now.day}/${now.year}',
      actions: [
        FilledButton.icon(
          onPressed: () => showCaptureDialog(context, source: 'manual'),
          icon: const Icon(Icons.add),
          label: Text(l10n.quickCapture),
        ),
      ],
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              '"${quote.text}" - ${quote.author}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.timer_outlined,
                  label: l10n.focusToday,
                  value: l10n.minutesShort(focus),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  label: l10n.tasksDoneToday,
                  value: '$doneToday',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _EnergyCheckIn(),
          const SizedBox(height: 28),
          Text(l10n.topPriorities,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (topTasks.isEmpty)
            const SizedBox(height: 140, child: ComingSoon())
          else
            Card(
              child: Column(
                children: [
                  for (final t in topTasks)
                    ListTile(
                      leading: Icon(Icons.circle,
                          size: 12,
                          color: Priority.color(
                              t.priority, Theme.of(context).colorScheme)),
                      title: Text(t.title),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CopyIconButton(text: t.title),
                          Text(Priority.label(t.priority)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EnergyCheckIn extends ConsumerWidget {
  const _EnergyCheckIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final current = ref.watch(todayLogProvider).valueOrNull?.energyLevel ?? 0;
    final history =
        ref.watch(energyHistoryProvider).valueOrNull ?? const <DailyLog>[];
    final spots = <FlSpot>[
      for (var i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), (history[i].energyLevel ?? 0).toDouble()),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text("Today's energy")),
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i',
                    onPressed: () =>
                        ref.read(dailyLogRepositoryProvider).setEnergy(i),
                    icon: Icon(
                      i <= current ? Icons.bolt : Icons.bolt_outlined,
                      color: i <= current ? cs.primary : cs.outline,
                    ),
                  ),
              ],
            ),
            if (spots.length >= 2) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  SizedBox(
                    height: 34,
                    width: 130,
                    child: _EnergySparkline(spots: spots, color: cs.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: _trend(theme, spots)),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _trend(ThemeData theme, List<FlSpot> spots) {
    final last = spots.last.y;
    final priors = spots.sublist(0, spots.length - 1);
    final avg = priors.map((s) => s.y).reduce((a, b) => a + b) / priors.length;
    final (IconData icon, String label, Color color) = last > avg + 0.3
        ? (Icons.trending_up, 'Trending up', const Color(0xFF22C55E))
        : last < avg - 0.3
            ? (Icons.trending_down, 'Easing down', const Color(0xFFF59E0B))
            : (
                Icons.trending_flat,
                'Holding steady',
                theme.colorScheme.onSurfaceVariant
              );
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$label · last ${spots.length} check-ins',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EnergySparkline extends StatelessWidget {
  const _EnergySparkline({required this.spots, required this.color});

  final List<FlSpot> spots;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 1,
        maxY: 5,
        minX: spots.first.x,
        maxX: spots.last.x,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData:
                BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
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
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(icon, color: theme.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: theme.textTheme.headlineSmall),
                Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
