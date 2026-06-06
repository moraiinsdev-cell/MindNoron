import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/habit_repository.dart'
    show computeStreak, computeLongestStreak;
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import 'activity_heatmap.dart';

/// The activity board: a GitHub-style contribution heatmap you can flip between
/// focus minutes, tasks done, and habits, with streak + total stats.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  ActivityMetric _metric = ActivityMetric.focus;
  int _year = DateTime.now().year;

  IconData _metricIcon(ActivityMetric m) => switch (m) {
        ActivityMetric.focus => Icons.timer_outlined,
        ActivityMetric.tasks => Icons.check_circle_outline,
        ActivityMetric.habits => Icons.local_fire_department_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async =
        ref.watch(activityDataProvider((metric: _metric, year: _year)));
    final thisYear = DateTime.now().year;
    final years = [for (var y = thisYear; y >= thisYear - 3; y--) y];

    return SectionScaffold(
      title: l10n.navActivity,
      actions: [
        DropdownButton<int>(
          value: _year,
          underline: const SizedBox.shrink(),
          items: [
            for (final y in years)
              DropdownMenuItem(value: y, child: Text('$y')),
          ],
          onChanged: (y) {
            if (y != null) setState(() => _year = y);
          },
        ),
      ],
      child: ListView(
        children: [
          SegmentedButton<ActivityMetric>(
            segments: [
              for (final m in ActivityMetric.values)
                ButtonSegment(
                  value: m,
                  label: Text(m.label),
                  icon: Icon(_metricIcon(m)),
                ),
            ],
            selected: {_metric},
            onSelectionChanged: (s) => setState(() => _metric = s.first),
          ),
          const SizedBox(height: 20),
          async.when(
            loading: () => const SizedBox(
                height: 200, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Could not load activity: $e'),
            data: (values) => _Content(metric: _metric, year: _year, values: values),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.metric,
    required this.year,
    required this.values,
  });

  final ActivityMetric metric;
  final int year;
  final Map<DateTime, int> values;

  @override
  Widget build(BuildContext context) {
    final days =
        values.entries.where((e) => e.value > 0).map((e) => e.key).toSet();
    final current = computeStreak(days, DateTime.now());
    final longest = computeLongestStreak(days);
    final total = values.values.fold<int>(0, (a, b) => a + b);
    var bestValue = 0;
    for (final v in values.values) {
      if (v > bestValue) bestValue = v;
    }

    String days1(int n) => '$n ${n == 1 ? 'day' : 'days'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              icon: Icons.local_fire_department,
              label: 'Current streak',
              value: days1(current),
              highlight: current > 0,
            ),
            _StatCard(
              icon: Icons.emoji_events_outlined,
              label: 'Longest streak',
              value: days1(longest),
            ),
            _StatCard(
              icon: Icons.functions,
              label: 'Total ${metric.unit}',
              value: '$total',
            ),
            _StatCard(
              icon: Icons.event_available_outlined,
              label: 'Active days',
              value: '${days.length}',
            ),
            if (bestValue > 0)
              _StatCard(
                icon: Icons.star_outline,
                label: 'Best day',
                value: '$bestValue ${metric.unit}',
              ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ActivityHeatmap(values: values, year: year, unit: metric.unit),
                const SizedBox(height: 14),
                const Align(
                    alignment: Alignment.centerRight, child: HeatmapLegend()),
              ],
            ),
          ),
        ),
      ],
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
      width: 168,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 18,
                      color: highlight ? const Color(0xFFF97316) : cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
