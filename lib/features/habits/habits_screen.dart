import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_date_utils.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/habit_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/common/section_scaffold.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    await ref.read(habitRepositoryProvider).create(text);
    _addController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final habitsAsync = ref.watch(habitsProvider);
    final completions =
        ref.watch(habitCompletionsProvider).valueOrNull ?? const [];
    final today = AppDateUtils.startOfDay(DateTime.now());

    // habitId -> set of completed days.
    final byHabit = <String, Set<DateTime>>{};
    for (final c in completions) {
      byHabit.putIfAbsent(c.habitId, () => <DateTime>{}).add(c.date);
    }

    return SectionScaffold(
      title: l10n.navHabits,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  onSubmitted: (_) => _add(),
                  decoration: const InputDecoration(
                    hintText: 'Add a habit... (Enter to save)',
                    prefixIcon: Icon(Icons.add),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: _add, child: const Text('Add')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: habitsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load habits: $e')),
              data: (habits) {
                if (habits.isEmpty) {
                  return const ComingSoon(label: 'No habits yet');
                }
                return ListView.builder(
                  itemCount: habits.length,
                  itemBuilder: (_, i) {
                    final h = habits[i];
                    final days = byHabit[h.id] ?? const <DateTime>{};
                    return _HabitTile(habit: h, days: days, today: today);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One habit: name, a tappable last-7-days row, and streak/total stats.
class _HabitTile extends ConsumerWidget {
  const _HabitTile({
    required this.habit,
    required this.days,
    required this.today,
  });

  final Habit habit;
  final Set<DateTime> days;
  final DateTime today;

  static const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final repo = ref.read(habitRepositoryProvider);

    final streak = computeStreak(days, today);
    final longest = computeLongestStreak(days);
    final total = days.length;
    final last7 = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(habit.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(habit.name, style: theme.textTheme.titleMedium),
                ),
                if (streak > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department,
                            size: 16, color: Color(0xFFF97316)),
                        const SizedBox(width: 2),
                        Text('$streak', style: theme.textTheme.labelLarge),
                      ],
                    ),
                  ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => repo.softDelete(habit.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final day in last7) ...[
                  Expanded(
                    child: _DayDot(
                      letter: _weekdayLetters[day.weekday - 1],
                      label: '${day.month}/${day.day}',
                      done: days.contains(day),
                      isToday: day == today,
                      onTap: () => repo.toggleDay(habit.id, day),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Best: $longest ${longest == 1 ? 'day' : 'days'}  ·  '
              'Total: $total ${total == 1 ? 'day' : 'days'}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.letter,
    required this.label,
    required this.done,
    required this.isToday,
    required this.onTap,
  });

  final String letter;
  final String label;
  final bool done;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(letter,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? cs.primary : cs.surfaceContainerHighest,
                  border: isToday
                      ? Border.all(color: cs.primary, width: 2)
                      : null,
                ),
                child: done
                    ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
