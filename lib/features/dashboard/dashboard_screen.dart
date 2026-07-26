import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/greeting.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/timer_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/navigation/app_router.dart';
import '../../presentation/widgets/common/copy_button.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import '../../presentation/widgets/common/ui_kit.dart';
import '../bible/bible_repository.dart';
import '../bible/bible_verse.dart';
import '../capture/capture_dialog.dart';
import '../motivation/quotes.dart';
import '../tasks/task_urgency.dart';
import '../tax/tax_overview.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final focus = ref.watch(focusMinutesTodayProvider).valueOrNull ?? 0;
    final doneToday = ref.watch(completedTodayCountProvider).valueOrNull ?? 0;
    final userName = ref.watch(userNameProvider).valueOrNull;
    final topTasks = [
      ...(ref.watch(openTasksProvider).valueOrNull ?? const <Task>[])
    ]..sort((a, b) {
        final ua = taskUrgency(a, now);
        final ub = taskUrgency(b, now);
        if (ua != ub) return ub - ua;
        if (a.priority != b.priority) return a.priority - b.priority;
        final ad = a.dueDate, bd = b.dueDate;
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });
    final visibleTopTasks = topTasks.take(5).toList();
    final quote = ref.watch(randomQuoteProvider);

    final cs = Theme.of(context).colorScheme;
    return SectionScaffold(
      icon: Icons.dashboard_rounded,
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
          _QuoteBanner(text: quote.text, author: quote.author),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.timer_outlined,
                  label: l10n.focusToday,
                  value: l10n.minutesShort(focus),
                  onTap: () => context.go(Routes.timer),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatTile(
                  icon: Icons.check_circle_outline,
                  label: l10n.tasksDoneToday,
                  value: '$doneToday',
                  accent: AppTheme.accentBlue,
                  onTap: () => context.go(Routes.tasks),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Runway and the tax gap: the two money facts worth knowing before
          // you decide what to work on today. Hides itself until there is
          // something to say.
          const MoneyStrip(),
          const SizedBox(height: 16),
          const _DailyVerseCard(),
          const SizedBox(height: 24),
          _FocusEnergyCard(focusMinutes: focus),
          const SizedBox(height: 20),
          const _EnergyCheckInCard(),
          const SizedBox(height: 28),
          SectionHeader(
            title: l10n.topPriorities,
            icon: Icons.flag_outlined,
            trailing: topTasks.isEmpty
                ? null
                : TextButton(
                    onPressed: () => context.go(Routes.tasks),
                    child: Text(l10n.navTasks),
                  ),
          ),
          const SizedBox(height: 12),
          if (topTasks.isEmpty)
            const SizedBox(
              height: 160,
              child: ComingSoon(
                icon: Icons.task_alt_outlined,
                label: 'No open tasks — capture something to get going',
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < visibleTopTasks.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    _PriorityTile(task: visibleTopTasks[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A single row in the "top priorities" list: an urgency dot, the title, a
/// copy affordance and a coloured priority pill.
class _PriorityTile extends StatelessWidget {
  const _PriorityTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = Priority.color(task.priority, cs);
    return ListTile(
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
          ],
        ),
      ),
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CopyIconButton(text: task.title),
          const SizedBox(width: 4),
          InfoPill(label: Priority.label(task.priority), color: color),
        ],
      ),
    );
  }
}

/// "Today's verse" — the deterministic daily Bible verse, surfaced on the
/// dashboard so the Word greets the reader every day. Tapping opens the full
/// Bible hub. Respects the reader's English/Vietnamese preference.
class _DailyVerseCard extends ConsumerWidget {
  const _DailyVerseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final verse = verseOfDay();
    final english = ref.watch(bibleEnglishProvider).valueOrNull ?? true;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => context.go(Routes.bible),
        child: Ink(
          decoration: BoxDecoration(
            gradient: cs.heroGradient(kBibleGold),
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: kBibleGold.withValues(alpha: 0.24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded,
                        size: 18, color: kBibleGold),
                    const SizedBox(width: 8),
                    Text(
                      "Today's verse",
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    InfoPill(
                      label: '${verse.topic.emoji} ${verse.topic.label}',
                      color: kBibleGold,
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right,
                        size: 20, color: cs.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  verse.textFor(english: english),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '— ${verse.refFor(english: english)} · ${english ? 'KJV' : 'BTT'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A calm, editorial quote banner with a vertical accent bar.
class _QuoteBanner extends StatelessWidget {
  const _QuoteBanner({required this.text, required this.author});

  final String text;
  final String author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '— $author',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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

/// Manual daily energy/mood check-in (1–5), saved per day to [DailyLog]
/// (PLAN.md §5.4). Distinct from the focus-energy charge above: this is how
/// *you* feel, not how much you focused.
class _EnergyCheckInCard extends ConsumerWidget {
  const _EnergyCheckInCard();

  static const _labels = ['Drained', 'Low', 'Okay', 'Good', 'Energized'];
  static const _emojis = ['😴', '🙁', '😐', '🙂', '⚡'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final current = ref.watch(todayLogProvider).valueOrNull?.energyLevel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How is your energy today?',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              current == null
                  ? 'Tap to check in — saved for today.'
                  : 'You feel: ${_labels[current - 1]}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var level = 1; level <= 5; level++) ...[
                  Expanded(
                    child: _EnergyPick(
                      emoji: _emojis[level - 1],
                      label: _labels[level - 1],
                      selected: current == level,
                      onTap: () =>
                          ref.read(dailyLogRepositoryProvider).setEnergy(level),
                    ),
                  ),
                  if (level < 5) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergyPick extends StatelessWidget {
  const _EnergyPick({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
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
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: cs.surfaceContainerHighest),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: cs.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
