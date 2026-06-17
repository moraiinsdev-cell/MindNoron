import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/enums.dart';
import '../../core/platform/window_service.dart';
import 'timer_controller.dart';
import 'timer_engine.dart';

/// Whether the app is collapsed into the compact, always-on-top float widget.
final floatingTimerProvider = StateProvider<bool>((ref) => false);

/// Collapses the window into the pinned countdown.
Future<void> enterFloatingTimer(WidgetRef ref) async {
  if (ref.read(floatingTimerProvider)) return;
  ref.read(floatingTimerProvider.notifier).state = true;
  await WindowService.enterFloating();
}

/// Restores the full window.
Future<void> exitFloatingTimer(WidgetRef ref) async {
  if (!ref.read(floatingTimerProvider)) return;
  ref.read(floatingTimerProvider.notifier).state = false;
  await WindowService.exitFloating();
}

/// The compact always-on-top countdown shown while the window is floating.
/// The whole surface is a drag handle (moves the OS window); buttons pause/
/// resume the session and expand back to the full app.
class FocusPip extends ConsumerWidget {
  const FocusPip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(timerControllerProvider);
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final controller = ref.read(timerControllerProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    final isBreak = snap.type != SessionType.work;
    final accent = isBreak ? cs.secondary : cs.primary;
    final active = snap.isActive;
    final remaining = snap.remaining(now);
    final progress = snap.progress(now);

    return Scaffold(
      backgroundColor: const Color(0xFF15131A),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => windowManager.startDragging(),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: accent.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(isBreak ? Icons.self_improvement : Icons.bolt,
                      size: 13, color: accent),
                  const SizedBox(width: 5),
                  Text(
                    active ? snap.type.label.toUpperCase() : 'NO SESSION',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  _PipButton(
                    icon: Icons.open_in_full,
                    tooltip: 'Back to app',
                    onTap: () => exitFloatingTimer(ref),
                  ),
                ],
              ),
              Text(
                active ? formatTimer(remaining) : '--:--',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: active ? progress : 0,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (active)
                    _PipButton(
                      icon: snap.isRunning ? Icons.pause : Icons.play_arrow,
                      tooltip: snap.isRunning ? 'Pause' : 'Resume',
                      onTap: snap.isRunning
                          ? controller.pause
                          : controller.resume,
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

class _PipButton extends StatelessWidget {
  const _PipButton(
      {required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: Colors.white70),
        ),
      ),
    );
  }
}
