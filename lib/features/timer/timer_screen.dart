import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/timer_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import 'ambient_control.dart';
import 'floating_timer.dart';
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
  int? _customFocusMinutes;

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
                ? _ActiveTimer(
                    key: const ValueKey('active'), snapshot: snapshot)
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
                SizedBox(
                  width: 360,
                  child: _TimerSidePanel(thinking: thinking),
                ),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(height: 300, child: timerArea),
              const SizedBox(height: 16),
              Expanded(child: thinking),
              const SizedBox(height: 16),
              const SizedBox(height: 180, child: _EarlyStopsCard()),
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
    final focusToday = ref.watch(focusMinutesTodayProvider).valueOrNull ?? 0;
    final focusEnergy = (focusToday ~/ 60).clamp(0, 5);
    final focusMinutes = (_customFocusMinutes ?? work).clamp(5, 120);

    void setFocusMinutes(int minutes) {
      setState(() => _customFocusMinutes = minutes.clamp(5, 120));
    }

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
          if (focusToday > 0) ...[
            InputChip(
              avatar: const Icon(Icons.bolt, size: 18),
              label: Text(
                'Today: $focusEnergy/5 energy - $focusToday focused min',
              ),
            ),
            const SizedBox(height: 12),
          ],
          _FocusDurationControl(
            minutes: focusMinutes,
            onChanged: setFocusMinutes,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => controller.start(
              duration: Duration(minutes: focusMinutes),
              linkedTaskId: _linkedTaskId,
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start focus'),
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

class _FocusDurationControl extends StatelessWidget {
  const _FocusDurationControl({
    required this.minutes,
    required this.onChanged,
  });

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: cs.surface.withValues(alpha: 0.72),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Focus duration', style: theme.textTheme.labelLarge),
                  Text(
                    '$minutes min',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.outlined(
              tooltip: 'Shorter',
              onPressed: minutes <= 5 ? null : () => onChanged(minutes - 5),
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Longer',
              onPressed: minutes >= 120 ? null : () => onChanged(minutes + 5),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
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

  Future<void> _confirmStop(TimerSnapshot snapshot) async {
    final controller = ref.read(timerControllerProvider.notifier);
    final isBreak = snapshot.type != SessionType.work;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _StopReasonDialog(isBreak: isBreak),
    );

    if (reason != null && reason.trim().isNotEmpty) {
      await controller.stop(reason: reason);
    }
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
              ? 'Breathe - let your mind wander.'
              : 'Stay with the one thing.',
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
              onPressed: () => _confirmStop(snapshot),
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => enterFloatingTimer(ref),
          icon: const Icon(Icons.picture_in_picture_alt, size: 18),
          label: const Text('Float on top'),
        ),
        const SizedBox(height: 8),
        const AmbientControl(),
      ],
    );
  }
}

class _TimerSidePanel extends StatelessWidget {
  const _TimerSidePanel({required this.thinking});

  final Widget thinking;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: thinking),
        const SizedBox(height: 16),
        const SizedBox(height: 210, child: _EarlyStopsCard()),
      ],
    );
  }
}

class _StopReasonDialog extends StatefulWidget {
  const _StopReasonDialog({required this.isBreak});

  final bool isBreak;

  @override
  State<_StopReasonDialog> createState() => _StopReasonDialogState();
}

class _StopReasonDialogState extends State<_StopReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) return;
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    final isBreak = widget.isBreak;
    final reason = _controller.text.trim();
    return AlertDialog(
      icon: Icon(isBreak ? Icons.self_improvement : Icons.lock_outline),
      title: Text(isBreak ? 'Stop break early?' : 'Stop focus early?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isBreak
                ? 'Write why you are cutting this break short. The reason will be saved so you can review the pattern later.'
                : 'Write why you are ending this focus block early. The reason will be saved so you can understand what pulled you away.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'Reason for stopping early...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isBreak ? 'Keep resting' : 'Keep focusing'),
        ),
        FilledButton.tonal(
          onPressed: reason.isEmpty ? null : _submit,
          child: Text(isBreak ? 'Save and stop break' : 'Save and stop focus'),
        ),
      ],
    );
  }
}

class _EarlyStopsCard extends ConsumerWidget {
  const _EarlyStopsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final stops = ref.watch(recentEarlyStopsProvider);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('Recent early stops', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: stops.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Could not load stops: $error'),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No early stops recorded yet.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _EarlyStopTile(session: items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EarlyStopTile extends StatelessWidget {
  const _EarlyStopTile({required this.session});

  final PomodoroSession session;

  String _time(DateTime date) {
    final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final m = date.minute.toString().padLeft(2, '0');
    return '${date.month}/${date.day} $h:$m ${date.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final type = SessionType.fromDb(session.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    type.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color:
                          type == SessionType.work ? cs.primary : cs.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _time(session.startTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                session.stopReason ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${session.actualMinutes}/${session.plannedMinutes} min',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
