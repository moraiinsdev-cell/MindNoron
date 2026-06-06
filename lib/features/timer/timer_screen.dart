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
import 'ambient_control.dart';
import 'focus_suggestion.dart';
import 'noron_backdrop.dart';
import 'thinking_space.dart';
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
    final cs = Theme.of(context).colorScheme;
    final backdropOn = ref.watch(neuronBackdropProvider).valueOrNull ?? true;
    final isBreak = snapshot.isActive && snapshot.type != SessionType.work;

    final timerArea = Stack(
      children: [
        if (backdropOn)
          Positioned.fill(
            child: NoronBackdrop(
              color: isBreak ? cs.secondary : cs.primary,
              intensity: snapshot.isActive ? 1.0 : 0.55,
            ),
          ),
        Center(
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
      ],
    );

    return SectionScaffold(
      title: l10n.navTimer,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final thinking = ThinkingSpace(
            sessionType: snapshot.isActive ? snapshot.type : null,
            linkedTaskId:
                snapshot.isActive ? snapshot.linkedTaskId : _linkedTaskId,
          );
          if (constraints.maxWidth >= 760) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: timerArea),
                const SizedBox(width: 20),
                SizedBox(width: 360, child: thinking),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(height: 300, child: timerArea),
              const SizedBox(height: 16),
              Expanded(child: thinking),
            ],
          );
        },
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

class _ActiveTimer extends ConsumerStatefulWidget {
  const _ActiveTimer({super.key, required this.snapshot});

  final TimerSnapshot snapshot;

  @override
  ConsumerState<_ActiveTimer> createState() => _ActiveTimerState();
}

class _ActiveTimerState extends ConsumerState<_ActiveTimer>
    with SingleTickerProviderStateMixin {
  // Slow "breathing" pulse used on break sessions to invite a calmer pace.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final snapshot = widget.snapshot;
    final controller = ref.read(timerControllerProvider.notifier);
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final remaining = snapshot.remaining(now);
    final progress = snapshot.progress(now);
    final isBreak = snapshot.type != SessionType.work;
    final accent = isBreak ? cs.secondary : cs.primary;

    final ring = SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              valueColor: AlwaysStoppedAnimation(accent),
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
          Text(formatTimer(remaining),
              style: theme.textTheme.displayMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(snapshot.type.label.toUpperCase(),
            style: theme.textTheme.labelLarge
                ?.copyWith(letterSpacing: 2, color: accent)),
        const SizedBox(height: 24),
        // Breathing pulse on breaks; steady on focus.
        AnimatedBuilder(
          animation: _breath,
          builder: (context, child) => Transform.scale(
            scale: isBreak ? (0.97 + 0.03 * _breath.value) : 1.0,
            child: child,
          ),
          child: ring,
        ),
        const SizedBox(height: 14),
        Text(
          isBreak
              ? 'Breathe — let your mind wander.'
              : 'Stay with the one thing.',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 16),
        const AmbientControl(),
      ],
    );
  }
}
