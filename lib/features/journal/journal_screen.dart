import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import 'journal_prompts.dart';

/// Daily reflection journal (PLAN.md §10 Phase 3). Backed by [DailyLog]: one
/// entry per day with an optional mood and a free-text note.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final past = ref.watch(journalProvider).valueOrNull ?? const <DailyLog>[];
    // Today's entry is shown in the editor; keep it out of the history list.
    final history = past
        .where((e) => !_isSameDay(e.date, now))
        .toList(growable: false);

    return SectionScaffold(
      title: 'Journal',
      subtitle: '${now.month}/${now.day}/${now.year}',
      child: ListView(
        children: [
          const _TodayEntry(),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('Past entries',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final entry in history) _PastEntryCard(entry: entry),
          ],
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

const _moods = <(String, String)>[
  ('😄', 'Great'),
  ('🙂', 'Good'),
  ('😐', 'Okay'),
  ('😕', 'Low'),
  ('😣', 'Rough'),
];

class _TodayEntry extends ConsumerStatefulWidget {
  const _TodayEntry();

  @override
  ConsumerState<_TodayEntry> createState() => _TodayEntryState();
}

class _TodayEntryState extends ConsumerState<_TodayEntry> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _initialized = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref
          .read(dailyLogRepositoryProvider)
          .setNote(value.trim().isEmpty ? null : value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final today = ref.watch(todayLogProvider).valueOrNull;

    // Seed the field once from storage (don't fight the user's typing after).
    if (!_initialized && today != null) {
      _controller.text = today.note ?? '';
      _initialized = true;
    }
    final mood = today?.mood;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text('Today', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: cs.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      promptForDate(DateTime.now()),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Mood', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (emoji, label) in _moods)
                  ChoiceChip(
                    label: Text('$emoji $label'),
                    selected: mood == label,
                    onSelected: (sel) => ref
                        .read(dailyLogRepositoryProvider)
                        .setMood(sel ? label : null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Write freely...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            Text('Saved automatically',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _PastEntryCard extends StatelessWidget {
  const _PastEntryCard({required this.entry});

  final DailyLog entry;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  String _emojiFor(String? mood) {
    for (final (emoji, label) in _moods) {
      if (label == mood) return emoji;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = entry.date;
    final emoji = _emojiFor(entry.mood);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${_weekdays[d.weekday - 1]}, ${d.month}/${d.day}/${d.year}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                if (emoji.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(emoji),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(entry.note ?? '', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
