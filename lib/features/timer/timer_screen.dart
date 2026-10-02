import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/enums.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/timer_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/common/activity_rings.dart';
import '../../presentation/widgets/common/app_dialog.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import '../../presentation/widgets/common/ui_kit.dart';
import 'ambient_control.dart';
import 'floating_timer.dart';
import 'noron_backdrop.dart';
import 'thinking_space.dart';
import 'timer_controller.dart';
import 'timer_engine.dart';

/// Ring colours per session kind: a deep indigo→violet for focus, a cool
/// mint→teal for breaks.
(Color, Color) _sessionHues(SessionType type) => type == SessionType.work
    ? (AppleColors.indigo, AppleColors.purple)
    : (AppleColors.teal, AppleColors.mint);

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  String? _linkedTaskId;
  SessionType _mode = SessionType.work;

  /// Per-mode minute overrides chosen on the dial (defaults from settings).
  final Map<SessionType, int> _custom = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(timerControllerProvider);
    final backdropOn = ref.watch(neuronBackdropProvider).valueOrNull ?? true;
    final kind = snapshot.isActive ? snapshot.type : _mode;
    final (hue, _) = _sessionHues(kind);

    final timerArea = Stack(
      children: [
        if (backdropOn)
          Positioned.fill(
            child: NoronBackdrop(
              color: hue,
              intensity: snapshot.isActive ? 0.9 : 0.45,
            ),
          ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              switchInCurve: AppMotion.easeOutQuint,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: snapshot.isActive
                  ? _ActiveTimer(
                      key: const ValueKey('active'), snapshot: snapshot)
                  : KeyedSubtree(
                      key: const ValueKey('setup'), child: _setup(context)),
            ),
          ),
        ),
      ],
    );

    return SectionScaffold(
      icon: Icons.timer_rounded,
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
              SizedBox(height: 520, child: timerArea),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final controller = ref.read(timerControllerProvider.notifier);
    final tasks = ref.watch(openTasksProvider).valueOrNull ?? const <Task>[];
    final defaults = {
      SessionType.work: ref.watch(workMinutesProvider).valueOrNull ??
          AppConstants.defaultWorkMinutes,
      SessionType.shortBreak:
          ref.watch(shortBreakMinutesProvider).valueOrNull ??
              AppConstants.defaultShortBreakMinutes,
      SessionType.longBreak: ref.watch(longBreakMinutesProvider).valueOrNull ??
          AppConstants.defaultLongBreakMinutes,
    };
    final focusToday = ref.watch(focusMinutesTodayProvider).valueOrNull ?? 0;
    final focusEnergy = (focusToday ~/ 60).clamp(0, 5);
    final minutes = (_custom[_mode] ?? defaults[_mode]!).clamp(1, 120);
    final isFocus = _mode == SessionType.work;
    final (c0, _) = _sessionHues(_mode);

    void setMinutes(int m) => setState(() => _custom[_mode] = m.clamp(1, 120));
    final step = isFocus ? 5 : 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeSwitch(
          value: _mode,
          onChanged: (m) => setState(() => _mode = m),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundGlassButton(
              icon: Icons.remove_rounded,
              tooltip: 'Shorter',
              onTap: minutes <= step ? null : () => setMinutes(minutes - step),
            ),
            const SizedBox(width: 24),
            _Dial(
              minutes: minutes,
              type: _mode,
              onScroll: (dir) => setMinutes(minutes + dir * step),
            ),
            const SizedBox(width: 24),
            _RoundGlassButton(
              icon: Icons.add_rounded,
              tooltip: 'Longer',
              onTap: minutes >= 120 ? null : () => setMinutes(minutes + step),
            ),
          ],
        ),
        const SizedBox(height: 26),
        AnimatedSize(
          duration: AppMotion.base,
          curve: AppMotion.ease,
          child: isFocus
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _TaskPicker(
                    tasks: tasks,
                    value: _linkedTaskId,
                    onChanged: (id) => setState(() => _linkedTaskId = id),
                  ),
                )
              : const SizedBox(width: 280),
        ),
        _GlowButton(
          label: isFocus ? 'Start Focus' : 'Start Break',
          icon: Icons.play_arrow_rounded,
          color: c0,
          onTap: () => controller.start(
            duration: Duration(minutes: minutes),
            type: _mode,
            linkedTaskId: isFocus ? _linkedTaskId : null,
          ),
        ),
        if (focusToday > 0) ...[
          const SizedBox(height: 18),
          InfoPill(
            icon: Icons.bolt_rounded,
            color: AppleColors.orange,
            label: 'Today · $focusEnergy/5 energy · $focusToday min focused',
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Scroll on the dial to adjust',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

/// iOS segmented control with a thumb that springs between segments.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.value, required this.onChanged});

  final SessionType value;
  final ValueChanged<SessionType> onChanged;

  static const _modes = [
    (SessionType.work, 'Focus'),
    (SessionType.shortBreak, 'Short break'),
    (SessionType.longBreak, 'Long break'),
  ];
  static const _segment = 118.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final index = _modes.indexWhere((m) => m.$1 == value);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: const Color(0xFF767680).withValues(alpha: dark ? 0.24 : 0.12),
        shape: const StadiumBorder(),
      ),
      child: SizedBox(
        width: _segment * _modes.length,
        height: 34,
        child: Stack(
          children: [
            SpringBuilder(
              value: index * _segment,
              spring: AppSprings.bouncy,
              builder: (context, x, _) => Positioned(
                left: x,
                top: 0,
                bottom: 0,
                width: _segment,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: dark ? const Color(0xFF636366) : Colors.white,
                    shape: const StadiumBorder(),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final (mode, label) in _modes)
                  SizedBox(
                    width: _segment,
                    child: Pressable(
                      onTap: () => onChanged(mode),
                      pressedScale: 0.95,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: AppMotion.fast,
                          style: theme.textTheme.labelLarge!.copyWith(
                            fontWeight: mode == value
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: mode == value
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                          ),
                          child: Text(label),
                        ),
                      ),
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

/// The setup dial: a ring that winds with the chosen minutes (one lap = an
/// hour) around big rolling digits. Scroll the mouse wheel over it to adjust.
class _Dial extends StatelessWidget {
  const _Dial({
    required this.minutes,
    required this.type,
    required this.onScroll,
  });

  final int minutes;
  final SessionType type;

  /// +1 / -1 per wheel notch.
  final ValueChanged<int> onScroll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (c0, c1) = _sessionHues(type);
    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent && e.scrollDelta.dy != 0) {
          onScroll(e.scrollDelta.dy < 0 ? 1 : -1);
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: SizedBox.square(
          dimension: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _Halo(color: c0, size: 280),
              ActivityRings(
                size: 280,
                stroke: 16,
                rings: [
                  RingSpec(progress: minutes / 60, start: c0, end: c1),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RollingText(
                    '$minutes',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 88,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -3,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'minutes',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A soft coloured light pooled behind a ring.
class _Halo extends StatelessWidget {
  const _Halo({required this.color, required this.size, this.strength = 1});

  final Color color;
  final double size;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        width: size * 1.35,
        height: size * 1.35,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: (dark ? 0.30 : 0.22) * strength),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular glass button (dial ±, session controls).
class _RoundGlassButton extends StatelessWidget {
  const _RoundGlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 52,
    this.tint,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final Color? tint;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final c = tint ?? cs.onSurface;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        enabled: enabled,
        pressedScale: 0.9,
        hoverScale: 1.04,
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: enabled ? 1 : 0.35,
          child: SizedBox.square(
            dimension: size,
            child: filled
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(c, Colors.white, 0.18)!,
                          c,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.withValues(alpha: 0.5),
                          blurRadius: 22,
                          spreadRadius: -4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: size * 0.46),
                  )
                : GlassSurface(
                    radius: size / 2,
                    interactive: true,
                    tint: tint,
                    child: Center(
                      child: Icon(icon, color: c, size: size * 0.44),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The big call-to-action capsule with a coloured glow.
class _GlowButton extends StatelessWidget {
  const _GlowButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Pressable(
      onTap: onTap,
      hoverLift: 2,
      child: AnimatedContainer(
        duration: AppMotion.gentle,
        curve: AppMotion.ease,
        height: 54,
        width: 260,
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, 0.2)!, color],
          ),
          shadows: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 28,
              spreadRadius: -6,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Link a task" capsule that opens a menu of open tasks.
class _TaskPicker extends StatelessWidget {
  const _TaskPicker({
    required this.tasks,
    required this.value,
    required this.onChanged,
  });

  final List<Task> tasks;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    Task? linked;
    for (final t in tasks) {
      if (t.id == value) linked = t;
    }
    return PopupMenuButton<String>(
      tooltip: 'Link this session to a task',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 380),
      onSelected: (id) => onChanged(id.isEmpty ? null : id),
      itemBuilder: (context) => [
        const PopupMenuItem(value: '', child: Text('No linked task')),
        if (tasks.isNotEmpty) const PopupMenuDivider(),
        for (final t in tasks)
          PopupMenuItem(
            value: t.id,
            child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: GlassSurface(
          radius: AppRadii.pill,
          level: GlassLevel.thin,
          interactive: true,
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                linked == null ? Icons.link_rounded : Icons.task_alt_rounded,
                size: 18,
                color:
                    linked == null ? cs.onSurfaceVariant : AppleColors.orange,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  linked?.title ?? 'Link a task',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: linked == null ? cs.onSurfaceVariant : cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more_rounded,
                  size: 18, color: cs.onSurfaceVariant),
            ],
          ),
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
  // Slow breathing pulse: deep on breaks (an invitation to slow down), a
  // barely-there glow on focus.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  Future<void> _confirmStop(TimerSnapshot snapshot) async {
    final controller = ref.read(timerControllerProvider.notifier);
    final isBreak = snapshot.type != SessionType.work;
    final reason = await showAppDialog<String>(
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
    final (c0, c1) = _sessionHues(snapshot.type);
    final endsAt = now.add(remaining);

    final ring = SizedBox.square(
      dimension: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _breath,
            builder: (context, _) {
              final b = Curves.easeInOut.transform(_breath.value);
              return _Halo(
                color: c0,
                size: 320,
                strength: isBreak ? 0.6 + 0.6 * b : 0.85 + 0.15 * b,
              );
            },
          ),
          // Springs glide the ring between whole-second ticks.
          ActivityRings(
            size: 320,
            stroke: 18,
            rings: [RingSpec(progress: progress, start: c0, end: c1)],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                snapshot.type.label.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 2.4,
                  color: c1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              RollingText(
                formatTimer(remaining),
                down: true,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 76,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                duration: AppMotion.base,
                opacity: snapshot.isRunning ? 1 : 0.5,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      snapshot.isRunning
                          ? Icons.notifications_none_rounded
                          : Icons.pause_rounded,
                      size: 15,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      snapshot.isRunning
                          ? DateFormat.jm().format(endsAt)
                          : 'Paused',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _breath,
          builder: (context, child) => Transform.scale(
            scale: isBreak
                ? 0.975 + 0.025 * Curves.easeInOut.transform(_breath.value)
                : 1.0,
            child: child,
          ),
          child: ring,
        ),
        const SizedBox(height: 14),
        Text(
          isBreak
              ? 'Breathe — let your mind wander.'
              : 'Stay with the one thing.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ControlColumn(
              label: 'Stop',
              child: _RoundGlassButton(
                icon: Icons.stop_rounded,
                tooltip: 'Stop early',
                tint: AppleColors.red,
                size: 56,
                onTap: () => _confirmStop(snapshot),
              ),
            ),
            const SizedBox(width: 26),
            _ControlColumn(
              label: snapshot.isRunning ? 'Pause' : 'Resume',
              child: _RoundGlassButton(
                icon: snapshot.isRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                tooltip: snapshot.isRunning ? 'Pause' : 'Resume',
                size: 72,
                filled: true,
                tint: c0,
                onTap:
                    snapshot.isRunning ? controller.pause : controller.resume,
              ),
            ),
            // "Float on top" pins a compact always-on-top window — desktop
            // only.
            if (isDesktopPlatform) ...[
              const SizedBox(width: 26),
              _ControlColumn(
                label: 'Float',
                child: _RoundGlassButton(
                  icon: Icons.picture_in_picture_alt_rounded,
                  tooltip: 'Float on top',
                  size: 56,
                  onTap: () => enterFloatingTimer(ref),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        const AmbientControl(),
      ],
    );
  }
}

class _ControlColumn extends StatelessWidget {
  const _ControlColumn({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 72, child: Center(child: child)),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
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

    return GlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: cs.onSurfaceVariant),
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
        decoration: ShapeDecoration(
          color: cs.onSurface.withValues(alpha: 0.05),
          shape: AppShapes.squircle(AppRadii.md),
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
