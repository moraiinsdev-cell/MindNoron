import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/greeting.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../data/repositories/habit_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/timer_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/navigation/app_router.dart';
import '../../presentation/widgets/common/activity_rings.dart';
import '../../presentation/widgets/common/copy_button.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import '../../presentation/widgets/common/ui_kit.dart';
import '../bible/bible_repository.dart';
import '../bible/bible_verse.dart';
import '../motivation/quotes.dart';
import '../tasks/task_urgency.dart';
import '../tax/tax_overview.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// A fully-closed tasks ring.
  static const _dailyTaskGoal = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final focus = ref.watch(focusMinutesTodayProvider).valueOrNull ?? 0;
    final doneToday = ref.watch(completedTodayCountProvider).valueOrNull ?? 0;
    final userName = ref.watch(userNameProvider).valueOrNull;
    final habits = ref.watch(habitsProvider).valueOrNull ?? const <Habit>[];
    final today = DateTime(now.year, now.month, now.day);
    final habitIds = {for (final h in habits) h.id};
    final habitsDone = (ref.watch(habitCompletionsProvider).valueOrNull ??
            const <HabitCompletion>[])
        .where((c) =>
            habitIds.contains(c.habitId) &&
            DateTime(c.date.year, c.date.month, c.date.day) == today)
        .map((c) => c.habitId)
        .toSet()
        .length;
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

    final priorities = _PrioritiesCard(
      title: l10n.topPriorities,
      tasks: visibleTopTasks,
      hasMore: topTasks.isNotEmpty,
      tasksLabel: l10n.navTasks,
    );

    return SectionScaffold(
      title: personalizedGreetingFor(l10n, now: now, userName: userName),
      subtitle: DateFormat('EEEE, MMMM d').format(now),
      actions: [
        FilledButton.icon(
          onPressed: () => context.go(Routes.timer),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Focus'),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final cols = w >= 1000 ? 3 : (w >= 680 ? 2 : 1);
          const gap = 16.0;
          // In a shared-height row, side tiles stretch and pin their footer.
          final inRow = cols > 1;
          final todayCard = _TodayCard(
            focusMinutes: focus,
            tasksDone: doneToday,
            taskGoal: _dailyTaskGoal,
            habitsDone: habitsDone,
            habitsTotal: habits.length,
            // Rings beside the stats unless the tile is phone-narrow.
            stacked: w < 520,
          );
          final verse = _DailyVerseCard(fill: inRow);
          final checkIn = _EnergyCheckInCard(fill: inRow);

          // Bento: rows of tiles that share a height; spans by flex.
          Widget row(List<(int, Widget)> tiles) => IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(flex: tiles[i].$1, child: tiles[i].$2),
                    ],
                  ],
                ),
              );

          final sections = <Widget>[
            if (cols == 3) ...[
              row([(2, todayCard), (1, verse)]),
              row([(2, priorities), (1, checkIn)]),
            ] else if (cols == 2) ...[
              todayCard,
              row([(1, verse), (1, checkIn)]),
              priorities,
            ] else ...[
              todayCard,
              verse,
              checkIn,
              priorities,
            ],
            // Runway and the tax gap: the two money facts worth knowing
            // before you decide what to work on today. Hides itself until
            // there is something to say.
            const MoneyStrip(),
            _QuoteBanner(text: quote.text, author: quote.author),
          ];

          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: gap),
                // Tiles cascade in — one motion, one page.
                Entrance(
                  delay: Duration(milliseconds: 40 + 60 * i),
                  blur: 4,
                  child: sections[i],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The hero tile: Activity-style rings for focus, tasks and habits, with
/// counting stats beside them.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.focusMinutes,
    required this.tasksDone,
    required this.taskGoal,
    required this.habitsDone,
    required this.habitsTotal,
    required this.stacked,
  });

  static const _unitMinutes = 60;
  static const _dailyGoalMinutes = 5 * _unitMinutes;

  final int focusMinutes;
  final int tasksDone;
  final int taskGoal;
  final int habitsDone;
  final int habitsTotal;
  final bool stacked;

  static String _hm(double minutes) {
    final m = minutes.round();
    final h = m ~/ 60;
    final r = m % 60;
    if (h == 0) return '${r}m';
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final energy = (focusMinutes ~/ _unitMinutes).clamp(0, 5);
    final minutesToNext =
        energy >= 5 ? 0 : _unitMinutes - (focusMinutes % _unitMinutes);
    final status = energy >= 5
        ? 'daily focus goal complete'
        : '$minutesToNext min to next';

    final rings = ActivityRings(
      size: 176,
      stroke: 20,
      rings: [
        RingSpec(
          progress: focusMinutes / _dailyGoalMinutes,
          start: RingSpec.focusStart,
          end: RingSpec.focusEnd,
        ),
        RingSpec(
          progress: tasksDone / taskGoal,
          start: RingSpec.tasksStart,
          end: RingSpec.tasksEnd,
        ),
        RingSpec(
          progress: habitsTotal == 0 ? 0 : habitsDone / habitsTotal,
          start: RingSpec.habitsStart,
          end: RingSpec.habitsEnd,
        ),
      ],
    );

    final stats = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Today', style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          'Close your rings — focus, tasks, habits.',
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        _RingStat(
          label: 'Focus',
          color: RingSpec.focusStart,
          value: focusMinutes.toDouble(),
          format: _hm,
          goal: '/ ${_hm(_dailyGoalMinutes.toDouble())}',
          onTap: () => context.go(Routes.timer),
        ),
        _RingStat(
          label: 'Tasks',
          color: RingSpec.tasksStart,
          value: tasksDone.toDouble(),
          format: (v) => '${v.round()}',
          goal: '/ $taskGoal',
          onTap: () => context.go(Routes.tasks),
        ),
        _RingStat(
          label: 'Habits',
          color: RingSpec.habitsStart,
          value: habitsDone.toDouble(),
          format: (v) => habitsTotal == 0 ? '—' : '${v.round()}',
          goal: habitsTotal == 0 ? 'none yet' : '/ $habitsTotal',
          onTap: () => context.go(Routes.habits),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.bolt_rounded,
                size: 16, color: RingSpec.focusStart),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$energy/5 focus energy · $status',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );

    return GlassSurface(
      interactive: true,
      padding: const EdgeInsets.all(22),
      child: stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [rings, const SizedBox(height: 20), stats],
            )
          : Row(
              children: [
                rings,
                const SizedBox(width: 28),
                Expanded(child: stats),
              ],
            ),
    );
  }
}

class _RingStat extends StatelessWidget {
  const _RingStat({
    required this.label,
    required this.color,
    required this.value,
    required this.format,
    required this.goal,
    required this.onTap,
  });

  final String label;
  final Color color;
  final double value;
  final String Function(double) format;
  final String goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            AnimatedNumber(
              value: value,
              format: format,
              style: theme.textTheme.titleLarge?.copyWith(color: color),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                goal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's top priorities as a glass list tile.
class _PrioritiesCard extends StatelessWidget {
  const _PrioritiesCard({
    required this.title,
    required this.tasks,
    required this.hasMore,
    required this.tasksLabel,
  });

  final String title;
  final List<Task> tasks;
  final bool hasMore;
  final String tasksLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: title,
            icon: Icons.flag_rounded,
            accent: AppleColors.orange,
            trailing: !hasMore
                ? null
                : TextButton(
                    onPressed: () => context.go(Routes.tasks),
                    child: Text('All $tasksLabel'),
                  ),
          ),
          const SizedBox(height: 4),
          if (tasks.isEmpty)
            const SizedBox(
              height: 150,
              child: ComingSoon(
                icon: Icons.task_alt_rounded,
                label: 'No open tasks — capture something to get going',
              ),
            )
          else
            for (var i = 0; i < tasks.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 40,
                  endIndent: 8,
                  color: cs.onSurface.withValues(alpha: 0.07),
                ),
              _PriorityTile(task: tasks[i]),
            ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      minLeadingWidth: 18,
      onTap: () => context.go(Routes.tasks),
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
  const _DailyVerseCard({this.fill = false});

  /// Stretch to the row height, pinning the reference to the bottom.
  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final verse = verseOfDay();
    final english = ref.watch(bibleEnglishProvider).valueOrNull ?? true;

    return Pressable(
      onTap: () => context.go(Routes.bible),
      pressedScale: 0.985,
      child: GlassSurface(
        interactive: true,
        tint: kBibleGold,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: cs.heroGradient(kBibleGold)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconChip(
                      icon: Icons.menu_book_rounded,
                      color: kBibleGold,
                      size: 28,
                      solid: true,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Today's verse",
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: cs.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  verse.textFor(english: english),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: 'InterDisplay',
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                    letterSpacing: -0.2,
                  ),
                ),
                if (fill) const Spacer(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${verse.refFor(english: english)} · ${english ? 'KJV' : 'BTT'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InfoPill(
                      label: '${verse.topic.emoji} ${verse.topic.label}',
                      color: kBibleGold,
                    ),
                  ],
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
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      // IntrinsicHeight bounds the stretched accent bar inside the ListView.
      child: IntrinsicHeight(
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
      ),
    );
  }
}

/// Manual daily energy/mood check-in (1–5), saved per day to [DailyLog]
/// (PLAN.md §5.4). Distinct from the focus-energy charge above: this is how
/// *you* feel, not how much you focused.
class _EnergyCheckInCard extends ConsumerWidget {
  const _EnergyCheckInCard({this.fill = false});

  /// Stretch to the row height, pinning the picker to the bottom.
  final bool fill;

  static const _labels = ['Drained', 'Low', 'Okay', 'Good', 'Energized'];
  static const _emojis = ['😴', '🙁', '😐', '🙂', '⚡'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final current = ref.watch(todayLogProvider).valueOrNull?.energyLevel;

    return GlassSurface(
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
            if (fill) const Spacer(),
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
    return Pressable(
      onTap: onTap,
      pressedScale: 0.92,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.ease,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: ShapeDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.18)
              : cs.onSurface.withValues(alpha: 0.05),
          shape: AppShapes.squircle(
            AppRadii.md,
            side: BorderSide(
              color: selected
                  ? cs.primary.withValues(alpha: 0.55)
                  : cs.onSurface.withValues(alpha: 0.06),
              width: selected ? 1.5 : 1,
            ),
          ),
        ),
        child: Column(
          children: [
            SpringBuilder(
              value: selected ? 1.18 : 1,
              spring: AppSprings.bouncy,
              builder: (context, s, child) =>
                  Transform.scale(scale: s, child: child),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? cs.primary : cs.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
