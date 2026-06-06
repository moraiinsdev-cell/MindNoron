import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums.dart';
import '../../core/utils/greeting.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/timer_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/navigation/app_router.dart';
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
    final userName = ref.watch(userNameProvider).valueOrNull;
    final List<Task> topTasks =
        (ref.watch(openTasksProvider).valueOrNull ?? const <Task>[])
            .take(5)
            .toList();
    final quote = ref.watch(randomQuoteProvider);

    return SectionScaffold(
      title: personalizedGreetingFor(l10n, now: now, userName: userName),
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
          _FocusEnergyCard(focusMinutes: focus),
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

class _FocusEnergyCard extends StatelessWidget {
  const _FocusEnergyCard({required this.focusMinutes});

  static const _unitMinutes = 60;
  static const _dailyGoalMinutes = 5 * _unitMinutes;

  final int focusMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final energy = (focusMinutes ~/ _unitMinutes).clamp(0, 5);
    final minutesToNext =
        energy >= 5 ? 0 : _unitMinutes - (focusMinutes % _unitMinutes);
    final status = energy >= 5
        ? 'Daily focus goal complete'
        : '$minutesToNext min to next energy';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's focus energy",
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '1 energy = 60 focused minutes. 5 energy = a complete focus day.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: () => context.go(Routes.timer),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Focus'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$energy/5',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'energy charged',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  Expanded(
                    child: _EnergySegment(
                      value:
                          ((focusMinutes - (i * _unitMinutes)) / _unitMinutes)
                              .clamp(0.0, 1.0),
                    ),
                  ),
                  if (i < 4) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.bolt, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$focusMinutes / $_dailyGoalMinutes focused minutes - $status',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergySegment extends StatelessWidget {
  const _EnergySegment({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: cs.surfaceContainerHighest),
              ),
            ),
            FractionallySizedBox(
              widthFactor: value,
              child: DecoratedBox(
                decoration: BoxDecoration(color: cs.primary),
              ),
            ),
          ],
        ),
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
