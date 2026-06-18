import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/enums.dart';
import '../../core/platform/window_service.dart';
import '../office/office_camera.dart';
import '../office/office_map.dart';
import '../office/office_models.dart';
import '../office/office_painter.dart';
import '../office/office_repository.dart';
import '../office/office_sim.dart';
import '../office/pixel_art.dart';
import 'timer_controller.dart';
import 'timer_engine.dart';

/// Whether the app is collapsed into the compact, always-on-top float widget.
final floatingTimerProvider = StateProvider<bool>((ref) => false);

/// Collapses the window into the pinned mini office.
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

/// The compact always-on-top widget shown while the window is floating: a live
/// mini view of MindNoron Inc. with the focus countdown overlaid. The whole
/// surface is a drag handle (moves the OS window); the buttons pause/resume
/// the session and expand back to the full app.
///
/// Because [OfficeScreen] is unmounted while floating, this widget owns its own
/// simulation, sprite cache and ticker (the same pattern as the office screen).
class FocusPip extends ConsumerStatefulWidget {
  const FocusPip({super.key});

  @override
  ConsumerState<FocusPip> createState() => _FocusPipState();
}

class _FocusPipState extends ConsumerState<FocusPip>
    with SingleTickerProviderStateMixin {
  late final OfficeSim _sim;
  late final SpriteCache _cache;
  late final Ticker _ticker;
  final OfficeCamera _camera = OfficeCamera();
  Duration _lastTick = Duration.zero;
  bool _placed = false;

  @override
  void initState() {
    super.initState();
    _sim = OfficeSim();
    _cache = SpriteCache();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _sim.tick(min(dt, 0.1)); // clamp huge frame gaps (window was hidden)
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sim.dispose();
    _cache.dispose();
    super.dispose();
  }

  void _syncFromProviders() {
    final floor = ref.watch(currentFloorProvider);
    final all = ref.watch(officeStaffProvider).valueOrNull;
    if (all != null) {
      final staff = staffOnFloor(all, floor);
      if (staff.isNotEmpty) {
        _sim.syncStaff(staff);
        if (!_placed) {
          _placed = true;
          _sim.placeInitial();
        }
      }
    }
    final layout = ref.watch(officeLayoutProvider).valueOrNull;
    if (layout != null) _sim.syncLayout(layout);
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(timerControllerProvider);
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final controller = ref.read(timerControllerProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    final isBreak = snap.type != SessionType.work;
    final accent = isBreak ? cs.secondary : cs.primary;
    final active = snap.isActive;
    final remaining = snap.remaining(now);
    final progress = snap.progress(now);

    _syncFromProviders();

    return Scaffold(
      backgroundColor: const Color(0xFF15131A),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => windowManager.startDragging(),
        onDoubleTap: () => exitFloatingTimer(ref),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Live mini office — kept bright (fixed midday light, no deep-work
              // dim) so the campus stays readable at this tiny size.
              LayoutBuilder(
                builder: (context, constraints) {
                  _camera.fit(
                    Size(constraints.maxWidth, constraints.maxHeight),
                    worldWidth.toDouble(),
                    worldHeight.toDouble(),
                  );
                  return CustomPaint(
                    painter: OfficePainter(
                      sim: _sim,
                      cache: _cache,
                      zoom: _camera.zoom,
                      origin: _camera.origin,
                      hourOverride: 13.0,
                    ),
                  );
                },
              ),

              // Accent frame.
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: accent.withValues(alpha: 0.55)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Window controls (top-right). Expand is a labelled chip so it's
              // obvious how to get the full app back (double-click also works).
              Positioned(
                top: 5,
                right: 5,
                child: Row(
                  children: [
                    if (active)
                      _PipButton(
                        icon: snap.isRunning ? Icons.pause : Icons.play_arrow,
                        tooltip: snap.isRunning ? 'Pause' : 'Resume',
                        onTap:
                            snap.isRunning ? controller.pause : controller.resume,
                      ),
                    const SizedBox(width: 4),
                    _ExpandChip(onTap: () => exitFloatingTimer(ref)),
                  ],
                ),
              ),

              // Countdown pill (bottom-left).
              Positioned(
                left: 8,
                bottom: 10,
                child: _CountPill(
                  accent: accent,
                  isBreak: isBreak,
                  label: active ? snap.type.label.toUpperCase() : 'NO SESSION',
                  time: active ? formatTimer(remaining) : '--:--',
                ),
              ),

              // Progress bar pinned to the bottom edge.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: LinearProgressIndicator(
                    value: active ? progress : 0,
                    minHeight: 3,
                    backgroundColor: Colors.black.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The frosted countdown badge laid over the mini office.
class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.accent,
    required this.isBreak,
    required this.label,
    required this.time,
  });

  final Color accent;
  final bool isBreak;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 10, 6),
        decoration: BoxDecoration(
          color: const Color(0xE0141019),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isBreak ? Icons.self_improvement : Icons.bolt,
                    size: 11, color: accent),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.0,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A clearly labelled "expand back to the app" chip.
class _ExpandChip extends StatelessWidget {
  const _ExpandChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Back to app (double-click anywhere)',
      child: Material(
        color: const Color(0xE6141019),
        shape: const StadiumBorder(
          side: BorderSide(color: Color(0x33FFFFFF)),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(8, 5, 10, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_full, size: 13, color: Colors.white),
                SizedBox(width: 5),
                Text('Expand',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
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
      child: Material(
        color: const Color(0xB3141019),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 15, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
