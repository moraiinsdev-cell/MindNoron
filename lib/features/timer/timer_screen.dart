import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import 'focus_suggestion.dart';
import 'timer_controller.dart';
import 'timer_engine.dart';

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  String? _linkedTaskId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(timerControllerProvider);

    return SectionScaffold(
      title: l10n.navTimer,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
                child: child,
              ),
            );
          },
          child: snapshot.isActive
              ? _ActiveTimer(key: const ValueKey('active'), snapshot: snapshot)
              : KeyedSubtree(
                  key: const ValueKey('setup'), child: _setup(context)),
        ),
      ),
    );
  }

  Widget _setup(BuildContext context) {
    final controller = ref.read(timerControllerProvider.notifier);
    final tasks = ref.watch(openTasksProvider).valueOrNull ?? const <Task>[];
    final work = ref.watch(workMinutesProvider).valueOrNull ??
        AppConstants.defaultWorkMinutes;
    final shortB = ref.watch(shortBreakMinutesProvider).valueOrNull ??
        AppConstants.defaultShortBreakMinutes;
    final longB = ref.watch(longBreakMinutesProvider).valueOrNull ??
        AppConstants.defaultLongBreakMinutes;
    final energy = ref.watch(todayLogProvider).valueOrNull?.energyLevel ?? 0;
    final suggested = suggestFocusMinutes(energy, work);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _linkedTaskId,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Link to task (optional)'),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('-- No linked task --')),
              for (final t in tasks)
                DropdownMenuItem(
                  value: t.id,
                  child: Text(t.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _linkedTaskId = v),
          ),
          const SizedBox(height: 24),
          if (energy > 0 && suggested != work) ...[
            OutlinedButton.icon(
              onPressed: () => controller.start(
                duration: Duration(minutes: suggested),
                linkedTaskId: _linkedTaskId,
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text('${focusSuggestionHint(energy)} · $suggested min'),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: () => controller.start(
              duration: Duration(minutes: work),
              linkedTaskId: _linkedTaskId,
            ),
            icon: const Icon(Icons.play_arrow),
            label: Text('Start $work min focus'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => controller.start(
                  duration: Duration(minutes: shortB),
                  type: SessionType.shortBreak,
                ),
                child: Text('Short break $shortB min'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => controller.start(
                  duration: Duration(minutes: longB),
                  type: SessionType.longBreak,
                ),
                child: Text('Long break $longB min'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveTimer extends ConsumerWidget {
  const _ActiveTimer({super.key, required this.snapshot});

  final TimerSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(timerControllerProvider.notifier);
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final remaining = snapshot.remaining(now);
    final progress = snapshot.progress(now);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(snapshot.type.label.toUpperCase(),
            style: theme.textTheme.labelLarge
                ?.copyWith(letterSpacing: 2, color: theme.colorScheme.primary)),
        const SizedBox(height: 24),
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              Text(formatTimer(remaining),
                  style: theme.textTheme.displayMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (snapshot.isRunning)
              FilledButton.tonalIcon(
                onPressed: controller.pause,
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: controller.resume,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
              ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: controller.stop,
              icon: const Icon(Icons.stop),
              label: const Text('End'),
            ),
          ],
        ),
      ],
    );
  }
}
