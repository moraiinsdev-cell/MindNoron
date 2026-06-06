import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_date_utils.dart';
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
                return ListView.separated(
                  itemCount: habits.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final h = habits[i];
                    final days = byHabit[h.id] ?? const <DateTime>{};
                    final doneToday = days.contains(today);
                    final streak = computeStreak(days, today);
                    return ListTile(
                      leading:
                          Text(h.emoji, style: const TextStyle(fontSize: 22)),
                      title: Text(h.name),
                      subtitle: streak > 0 ? Text('$streak-day streak') : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: doneToday ? 'Done today' : 'Mark today',
                            icon: Icon(
                              doneToday
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: doneToday
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            onPressed: () => ref
                                .read(habitRepositoryProvider)
                                .toggleToday(h.id),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => ref
                                .read(habitRepositoryProvider)
                                .softDelete(h.id),
                          ),
                        ],
                      ),
                    );
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
