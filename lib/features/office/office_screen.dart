import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../timer/timer_controller.dart';
import 'office_camera.dart';
import 'office_catalog.dart';
import 'office_economy.dart';
import 'office_map.dart';
import 'office_models.dart';
import 'office_painter.dart';
import 'office_repository.dart';
import 'office_sfx.dart';
import 'office_sim.dart';
import 'office_sprites.dart';
import 'pixel_art.dart';

/// MindNoron Inc. — a living pixel-art office. Employees work, wander and
/// gossip on their own; the user is the hand of God: click to inspect,
/// drag to relocate, rename, hire and fire.
class OfficeScreen extends ConsumerStatefulWidget {
  const OfficeScreen({super.key});

  @override
  ConsumerState<OfficeScreen> createState() => _OfficeScreenState();
}

class _OfficeScreenState extends ConsumerState<OfficeScreen>
    with TickerProviderStateMixin {
  late final OfficeSim _sim;
  late final SpriteCache _cache;
  late final Ticker _ticker;
  late final AnimationController _floorAnim;
  Duration _lastTick = Duration.zero;
  bool _placed = false;
  int _floor = 0;

  // Camera owns the screen<->world transform (auto-fit + player zoom/pan).
  final OfficeCamera _camera = OfficeCamera();

  String? _draggingId;
  bool _panning = false;
  EmployeeRuntime? _hoverEmp;
  Offset _hoverCursor = Offset.zero;
  bool _coinBusy = false;

  // Build / decorate mode.
  bool _buildMode = false;
  String? _placingId;
  Point<int>? _ghostTile;

  @override
  void initState() {
    super.initState();
    _sim = OfficeSim();
    _cache = SpriteCache();
    _ticker = createTicker(_onTick)..start();
    _floorAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _sim.tick(min(dt, 0.1)); // clamp huge frame gaps (window was hidden)
  }

  @override
  void dispose() {
    _floorAnim.dispose();
    _ticker.dispose();
    _sim.dispose();
    _cache.dispose();
    super.dispose();
  }

  Offset _toWorld(Offset local) => _camera.toWorld(local);

  void _syncFromProviders() {
    // Switching floors shows a different department; re-theme the map, drop
    // the cached static layer and re-seat that floor's people.
    final floor = ref.watch(currentFloorProvider);
    setActiveFloor(floor);
    if (floor != _floor) {
      _floor = floor;
      _placed = false;
      _sim.select(null);
      OfficePainter.invalidateStaticLayer();
      _floorAnim.forward(from: 0);
    }
    final allStaff = ref.watch(officeStaffProvider).valueOrNull;
    if (allStaff != null) {
      final staff = staffOnFloor(allStaff, floor);
      _sim.syncStaff(staff);
      if (!_placed && staff.isNotEmpty) {
        _placed = true;
        _sim.placeInitial();
      }
    }
    final tasks = ref.watch(openTasksProvider).valueOrNull ?? const <Task>[];
    _sim.openTasks = [for (final t in tasks) (t.id, t.title)];

    ref.read(officeSfxProvider).enabled =
        ref.watch(officeSfxEnabledProvider).valueOrNull ?? true;

    // Award coins for tasks completed in the real app (idempotent).
    final completed = ref.watch(recentlyCompletedProvider).valueOrNull;
    if (completed != null) _reconcileCoins(completed);

    // Player-placed furniture layout.
    final layout = ref.watch(officeLayoutProvider).valueOrNull;
    if (layout != null) _sim.syncLayout(layout);

    // Mirror a real focus session as office "deep work" mode.
    final timer = ref.watch(timerControllerProvider);
    final focusing = timer.isActive &&
        timer.isRunning &&
        timer.type == SessionType.work;
    _sim.setFocusMode(focusing);
  }

  /// Coin payout for a completed task: a base, plus a priority bonus
  /// (priority 1 = most important), plus a small bonus for longer estimates.
  static int _taskReward(Task t) {
    final priorityBonus = (5 - t.priority).clamp(0, 4) * 2;
    final est = t.estimatedMinutes ?? 0;
    final estBonus = (est ~/ 30).clamp(0, 6);
    return 6 + priorityBonus + estBonus;
  }

  /// Credits coins for any completed task not yet in the ledger. On first run
  /// it baselines existing completions (no payout) so we never dump coins
  /// retroactively. Guarded so overlapping async writes can't double-pay.
  Future<void> _reconcileCoins(List<Task> completed) async {
    if (_coinBusy || completed.isEmpty) return;
    _coinBusy = true;
    try {
      final repo = ref.read(officeRepositoryProvider);
      var econ = await repo.getEconomy();

      if (!econ.seeded) {
        await repo.saveEconomy(econ.seedWith(completed.map((t) => t.id)));
        return;
      }

      var earned = 0;
      for (final t in completed) {
        if (econ.hasCredited(t.id)) continue;
        final reward = _taskReward(t);
        econ = econ.earn(reward, taskId: t.id);
        earned += reward;
      }
      if (earned > 0) {
        await repo.saveEconomy(econ);
        ref.read(officeSfxProvider).play(OfficeSfxCue.coin);
        _sim.celebrateCoins(earned);
      }
    } finally {
      _coinBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncFromProviders();
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildCanvas(theme)),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 300,
            child: Column(
              children: [
                const _FloorBar(),
                const Divider(height: 1),
                Expanded(
                  child: _OfficePanel(
                    sim: _sim,
                    cache: _cache,
                    buildMode: _buildMode,
                    placingId: _placingId,
                    onToggleBuild: _toggleBuild,
                    onPick: (id) => setState(() => _placingId = id),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleBuild() {
    setState(() {
      _buildMode = !_buildMode;
      _placingId = null;
      _ghostTile = null;
      if (_buildMode) {
        _sim.select(null);
        _hoverEmp = null;
      }
    });
  }

  Widget _buildCanvas(ThemeData theme) {
    return Container(
      color: const Color(0xFF221F26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          _camera.fit(Size(w, h), worldWidth.toDouble(), worldHeight.toDouble());

          return Stack(
            children: [
              Listener(
                onPointerSignal: (signal) {
                  if (signal is PointerScrollEvent) {
                    final factor =
                        signal.scrollDelta.dy < 0 ? 1.12 : 1 / 1.12;
                    setState(() => _camera.zoomAt(signal.localPosition, factor));
                  }
                },
                child: MouseRegion(
                  cursor: _draggingId != null
                      ? SystemMouseCursors.grabbing
                      : _panning
                          ? SystemMouseCursors.move
                          : _hoverEmp != null
                              ? SystemMouseCursors.grab
                              : MouseCursor.defer,
                  onExit: (_) {
                    if (_hoverEmp != null || _ghostTile != null) {
                      setState(() {
                        _hoverEmp = null;
                        _ghostTile = null;
                      });
                    }
                  },
                  onHover: (event) {
                    if (_buildMode) {
                      final tile = tileAt(_toWorld(event.localPosition));
                      if (tile != _ghostTile) {
                        setState(() => _ghostTile = tile);
                      }
                      return;
                    }
                    if (_draggingId != null) return;
                    final hit = _sim.hitTest(_toWorld(event.localPosition));
                    if (hit != _hoverEmp ||
                        (hit != null && event.localPosition != _hoverCursor)) {
                      setState(() {
                        _hoverEmp = hit;
                        _hoverCursor = event.localPosition;
                      });
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) {
                      final world = _toWorld(d.localPosition);
                      if (_buildMode) {
                        _handleBuildTap(tileAt(world));
                        return;
                      }
                      final hit = _sim.hitTest(world);
                      if (hit != null) {
                        _sim.select(hit.spec.id);
                        return;
                      }
                      if (_sim.hitTestCat(world)) {
                        _sim.petCat();
                        _sim.select(null);
                        return;
                      }
                      // Poke whatever object is there; deselect on empty floor.
                      final poke = _sim.pokeAt(world);
                      _playPoke(poke);
                      if (poke == PokeKind.none) _sim.select(null);
                    },
                    onPanStart: (d) {
                      if (_buildMode) return;
                      final hit = _sim.hitTest(_toWorld(d.localPosition));
                      if (hit != null) {
                        _draggingId = hit.spec.id;
                        _sim.beginDrag(hit.spec.id);
                        setState(() {});
                      } else if (_camera.canPan) {
                        setState(() => _panning = true);
                      }
                    },
                    onPanUpdate: (d) {
                      final id = _draggingId;
                      if (id != null) {
                        _sim.dragTo(id, _toWorld(d.localPosition));
                      } else if (_panning) {
                        setState(() => _camera.panBy(d.delta));
                      }
                    },
                    onPanEnd: (_) => _endDrag(),
                    onPanCancel: _endDrag,
                    child: CustomPaint(
                      size: Size(w, h),
                      painter: OfficePainter(
                        sim: _sim,
                        cache: _cache,
                        zoom: _camera.zoom,
                        origin: _camera.origin,
                        buildMode: _buildMode,
                        placingItem:
                            _placingId == null ? null : catalogItem(_placingId!),
                        ghostTile: _buildMode ? _ghostTile : null,
                        focusMode: _sim.focusMode,
                      ),
                    ),
                  ),
                ),
              ),
              if (_camera.canPan)
                Positioned(
                  right: 12,
                  top: 12,
                  child: _CameraResetButton(onTap: () {
                    setState(() => _camera.reset());
                  }),
                ),
              // Quick fade-through-black when changing floors.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _floorAnim,
                    builder: (context, _) {
                      final t = _floorAnim.value;
                      final o = (t <= 0 || t >= 1) ? 0.0 : sin(pi * t);
                      return o == 0
                          ? const SizedBox.shrink()
                          : Container(
                              color: const Color(0xFF0B0A12)
                                  .withValues(alpha: o * 0.9));
                    },
                  ),
                ),
              ),
              if (_hoverEmp != null && _draggingId == null)
                _hoverTooltip(Size(w, h)),
              Positioned(
                left: 12,
                bottom: 10,
                child: IgnorePointer(
                  child: Text(
                    'Click to inspect · drag to play God · scroll to zoom ✋',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleBuildTap(Point<int> tile) async {
    final repo = ref.read(officeRepositoryProvider);
    final sfx = ref.read(officeSfxProvider);

    // Remove an existing placed item if one is here (takes priority).
    final existing = _sim.placedAt(tile);
    if (existing != null && _placingId == null) {
      final next = [..._sim.placedItems]..remove(existing);
      _sim.syncLayout(next);
      await repo.saveLayout(next);
      sfx.play(OfficeSfxCue.poof);
      return;
    }

    final id = _placingId;
    if (id == null) return;
    final item = catalogItem(id);
    if (item == null) return;
    if (!_sim.canPlaceAt(item, tile.x, tile.y)) {
      sfx.play(OfficeSfxCue.click);
      return;
    }
    final placed = PlacedItem(itemId: id, tx: tile.x, ty: tile.y);
    final next = [..._sim.placedItems, placed];
    _sim.syncLayout(next);
    await repo.saveLayout(next);
    sfx.play(OfficeSfxCue.poof);
  }

  void _playPoke(PokeKind kind) {
    final sfx = ref.read(officeSfxProvider);
    switch (kind) {
      case PokeKind.none:
        return;
      case PokeKind.splash:
        sfx.play(OfficeSfxCue.splash);
      case PokeKind.coffee:
        sfx.play(OfficeSfxCue.coffee);
      case PokeKind.drink:
      case PokeKind.snack:
      case PokeKind.plant:
      case PokeKind.books:
      case PokeKind.tech:
      case PokeKind.generic:
        sfx.play(OfficeSfxCue.click);
    }
  }

  Widget _hoverTooltip(Size canvas) {
    const cardW = 196.0, cardH = 92.0;
    var dx = _hoverCursor.dx + 16;
    var dy = _hoverCursor.dy + 16;
    if (dx + cardW > canvas.width) dx = _hoverCursor.dx - cardW - 12;
    if (dy + cardH > canvas.height) dy = canvas.height - cardH - 8;
    if (dx < 4) dx = 4;
    if (dy < 4) dy = 4;
    return Positioned(
      left: dx,
      top: dy,
      child: IgnorePointer(
        child: _HoverCard(sim: _sim, employee: _hoverEmp!, width: cardW),
      ),
    );
  }

  void _endDrag() {
    final id = _draggingId;
    if (id != null) {
      _sim.drop(id);
      setState(() => _draggingId = null);
    } else if (_panning) {
      setState(() => _panning = false);
    }
  }
}

/// Small floating button that returns the camera to the fitted view.
/// A compact floor switcher in the panel header (off the campus, so it never
/// covers the office). Tapping a floor changes which department you're viewing.
class _FloorBar extends ConsumerWidget {
  const _FloorBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentFloorProvider);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.apartment, size: 16, color: Colors.white54),
          ),
          for (var f = 0; f < floorCount; f++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Tooltip(
                  message: floorNames[f],
                  child: InkWell(
                    onTap: () =>
                        ref.read(currentFloorProvider.notifier).state = f,
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: f == current
                            ? cs.primary
                            : Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        f == 0 ? 'G' : '${f + 1}F',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: f == current ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraResetButton extends StatelessWidget {
  const _CameraResetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.zoom_out_map, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Side panel: company overview or the selected employee's profile
// ---------------------------------------------------------------------------

class _OfficePanel extends ConsumerWidget {
  const _OfficePanel({
    required this.sim,
    required this.cache,
    required this.buildMode,
    required this.placingId,
    required this.onToggleBuild,
    required this.onPick,
  });

  final OfficeSim sim;
  final SpriteCache cache;
  final bool buildMode;
  final String? placingId;
  final VoidCallback onToggleBuild;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (buildMode) {
      return _BuildPanel(
        sim: sim,
        placingId: placingId,
        onToggleBuild: onToggleBuild,
        onPick: onPick,
      );
    }
    return AnimatedBuilder(
      animation: sim,
      builder: (context, _) {
        final selected = sim.selected;
        return selected == null
            ? _CompanyOverview(
                sim: sim, cache: cache, onToggleBuild: onToggleBuild)
            : _EmployeeProfile(sim: sim, cache: cache, employee: selected);
      },
    );
  }
}

class _CompanyOverview extends ConsumerWidget {
  const _CompanyOverview(
      {required this.sim, required this.cache, required this.onToggleBuild});

  final OfficeSim sim;
  final SpriteCache cache;
  final VoidCallback onToggleBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (working, breaks, chats) = sim.headcount();
    final now = TimeOfDay.now();
    final staffCount = sim.employees.length;
    final coins = ref.watch(officeEconomyProvider).valueOrNull?.coins ?? 0;
    final floor = ref.watch(currentFloorProvider);
    final floorLabel =
        'Floor ${floor + 1} · ${floorNames[floor.clamp(0, floorNames.length - 1)]}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Text('🏢', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MindNoron Inc.',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    floorLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  now.format(context),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '$coins',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD9A521),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatChip(label: 'Working', value: '$working', emoji: '💼'),
            _StatChip(label: 'On break', value: '$breaks', emoji: '☕'),
            _StatChip(label: 'Chatting', value: '$chats', emoji: '💬'),
          ],
        ),
        const SizedBox(height: 20),
        Text('Staff ($staffCount)',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final e in sim.employees)
          _StaffTile(sim: sim, cache: cache, employee: e),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: staffCount >= maxStaff
              ? null
              : () async {
                  final hire = await ref
                      .read(officeRepositoryProvider)
                      .hire(Random(), floor: ref.read(currentFloorProvider));
                  ref.read(officeSfxProvider).play(OfficeSfxCue.hire);
                  sim.logEvent('👋 ${hire.name} joined as ${hire.role}');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '${hire.name} joined as ${hire.role}! 🎉'),
                      duration: const Duration(seconds: 3),
                    ));
                  }
                },
          icon: const Icon(Icons.person_add_alt),
          label: Text(
              staffCount >= maxStaff ? 'Office is full' : 'Hire someone'),
        ),
        const SizedBox(height: 8),
        Text(
          'New hires walk in through the front door.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
          textAlign: TextAlign.center,
        ),
        if (sim.eventLog.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Activity',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final entry in sim.eventLog.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(entry.text,
                        style: theme.textTheme.bodySmall),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _relativeTime(entry.at),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onToggleBuild,
          icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
          label: const Text('Build / Decorate'),
        ),
      ],
    );
  }

  static String _relativeTime(DateTime at) {
    final s = DateTime.now().difference(at).inSeconds;
    if (s < 45) return 'now';
    if (s < 3600) return '${(s / 60).round()}m';
    return '${(s / 3600).round()}h';
  }
}

/// Build-mode side panel: a shop to buy item types with coins and an
/// inventory of owned types to select for placement.
class _BuildPanel extends ConsumerWidget {
  const _BuildPanel({
    required this.sim,
    required this.placingId,
    required this.onToggleBuild,
    required this.onPick,
  });

  final OfficeSim sim;
  final String? placingId;
  final VoidCallback onToggleBuild;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final economy = ref.watch(officeEconomyProvider).valueOrNull;
    final coins = economy?.coins ?? 0;
    final owned = [for (final c in officeCatalog) if (economy?.owns(c.id) ?? false) c];
    final shop = [for (final c in officeCatalog) if (!(economy?.owns(c.id) ?? false)) c];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Done',
              icon: const Icon(Icons.check, size: 20),
              onPressed: onToggleBuild,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text('Build & Decorate',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const Text('🪙', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text('$coins',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD9A521))),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          placingId == null
              ? 'Pick an item, then click the floor to place. Click a placed item to remove it.'
              : 'Click the floor to place. Tap the item again to stop placing.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 14),
        if (owned.isNotEmpty) ...[
          Text('Your items',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in owned)
                ChoiceChip(
                  avatar: Text(c.emoji),
                  label: Text(c.label),
                  selected: placingId == c.id,
                  onSelected: (sel) => onPick(sel ? c.id : null),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        Text('Shop',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final c in shop)
          _ShopRow(
            item: c,
            affordable: coins >= c.price,
            onBuy: () => _buy(ref, c),
          ),
        if (shop.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('You own everything in the catalog! 🎉',
                style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }

  Future<void> _buy(WidgetRef ref, CatalogItem item) async {
    final repo = ref.read(officeRepositoryProvider);
    final econ = await repo.getEconomy();
    if (econ.owns(item.id)) return;
    final spent = econ.trySpend(item.price);
    if (spent == null) return;
    await repo.saveEconomy(spent.unlock(item.id));
    ref.read(officeSfxProvider).play(OfficeSfxCue.coin);
    sim.logEvent('🛒 Bought a ${item.label.toLowerCase()}');
    onPick(item.id); // auto-select the freshly bought item for placement
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow(
      {required this.item, required this.affordable, required this.onBuy});

  final CatalogItem item;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.label, style: theme.textTheme.bodyMedium),
          ),
          FilledButton.tonal(
            onPressed: affordable ? onBuy : null,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text('🪙 ${item.price}'),
          ),
        ],
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile(
      {required this.sim, required this.cache, required this.employee});

  final OfficeSim sim;
  final SpriteCache cache;
  final EmployeeRuntime employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => sim.select(employee.spec.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            _Portrait(cache: cache, look: employee.spec.look, scale: 2),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${employee.spec.name} ${employee.moodEmoji}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    sim.statusLine(employee),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
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

class _EmployeeProfile extends ConsumerStatefulWidget {
  const _EmployeeProfile(
      {required this.sim, required this.cache, required this.employee});

  final OfficeSim sim;
  final SpriteCache cache;
  final EmployeeRuntime employee;

  @override
  ConsumerState<_EmployeeProfile> createState() => _EmployeeProfileState();
}

class _EmployeeProfileState extends ConsumerState<_EmployeeProfile> {
  bool _editingName = false;
  late final TextEditingController _nameController =
      TextEditingController(text: widget.employee.spec.name);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  EmployeeRuntime get e => widget.employee;
  OfficeSim get sim => widget.sim;

  Future<void> _saveName() async {
    setState(() => _editingName = false);
    await ref
        .read(officeRepositoryProvider)
        .rename(e.spec.id, _nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = e.spec;
    final personality = spec.personality;
    final tasks = ref.watch(openTasksProvider).valueOrNull ?? const <Task>[];
    final pinnedStillOpen = tasks.any((t) => t.id == spec.taskId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back to company',
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: () => sim.select(null),
            ),
            const Spacer(),
            Text(e.moodEmoji, style: const TextStyle(fontSize: 22)),
          ],
        ),
        Center(
            child:
                _Portrait(cache: widget.cache, look: spec.look, scale: 5)),
        const SizedBox(height: 10),
        if (_editingName)
          TextField(
            controller: _nameController,
            autofocus: true,
            textAlign: TextAlign.center,
            maxLength: 20,
            decoration: const InputDecoration(counterText: ''),
            onSubmitted: (_) => _saveName(),
            onTapOutside: (_) => _saveName(),
          )
        else
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              _nameController.text = spec.name;
              setState(() => _editingName = true);
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      spec.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_outlined,
                      size: 14, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
        Center(
          child: Text(
            spec.role,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${personality.label} — ${personality.tagline}',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                _MeterRow(label: 'Energy', value: e.energy, emoji: '⚡'),
                const SizedBox(height: 6),
                _MeterRow(label: 'Social', value: e.social, emoji: '💬'),
                const SizedBox(height: 10),
                Text(
                  sim.statusLine(e),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('Assigned task',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: pinnedStillOpen ? spec.taskId : null,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Auto (shares the backlog)'),
            ),
            for (final t in tasks)
              DropdownMenuItem<String?>(
                value: t.id,
                child: Text(t.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (taskId) =>
              ref.read(officeRepositoryProvider).pinTask(spec.id, taskId),
        ),
        const SizedBox(height: 16),
        Text('God powers',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () {
                  sim.commandPraise(spec.id);
                  ref.read(officeSfxProvider).play(OfficeSfxCue.celebrate);
                },
                icon: const Text('❤️'),
                label: const Text('Praise'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () {
                  sim.commandMotivate(spec.id);
                  ref.read(officeSfxProvider).play(OfficeSfxCue.coin);
                },
                icon: const Text('⚡'),
                label: const Text('Motivate'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SendChip(emoji: '☕', label: 'Coffee', onTap: () {
              sim.commandCoffee(spec.id);
              ref.read(officeSfxProvider).play(OfficeSfxCue.coffee);
            }),
            _SendChip(
                emoji: '💼',
                label: 'Desk',
                onTap: () => sim.commandWork(spec.id)),
            _SendChip(
                emoji: '🏋️',
                label: 'Gym',
                onTap: () => sim.commandGym(spec.id)),
            _SendChip(emoji: '🏊', label: 'Pool', onTap: () {
              sim.commandPool(spec.id);
              ref.read(officeSfxProvider).play(OfficeSfxCue.splash);
            }),
            _SendChip(
                emoji: '🛋️',
                label: 'Lounge',
                onTap: () => sim.commandLounge(spec.id)),
          ],
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error),
          onPressed: () => _confirmFire(context),
          icon: const Icon(Icons.person_remove_outlined, size: 18),
          label: const Text('Let go…'),
        ),
      ],
    );
  }

  Future<void> _confirmFire(BuildContext context) async {
    final spec = e.spec;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Let ${spec.name} go?'),
        content: const Text(
            'They will pack their pixel desk and leave MindNoron Inc.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(officeRepositoryProvider).fire(spec.id);
    }
  }
}

/// Floating info card shown while hovering an employee on the canvas.
class _HoverCard extends StatelessWidget {
  const _HoverCard(
      {required this.sim, required this.employee, required this.width});

  final OfficeSim sim;
  final EmployeeRuntime employee;
  final double width;

  @override
  Widget build(BuildContext context) {
    final spec = employee.spec;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xF21C1A24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  spec.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(employee.moodEmoji, style: const TextStyle(fontSize: 14)),
            ],
          ),
          Text(
            sim.statusLine(employee),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          _MiniBar(label: '⚡', value: employee.energy),
          const SizedBox(height: 3),
          _MiniBar(label: '💬', value: employee.social),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              color: value > 0.5
                  ? const Color(0xFF4D9E68)
                  : value > 0.25
                      ? const Color(0xFFC9A227)
                      : const Color(0xFFD06464),
            ),
          ),
        ),
      ],
    );
  }
}

class _SendChip extends StatelessWidget {
  const _SendChip(
      {required this.emoji, required this.label, required this.onTap});

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Text(emoji, style: const TextStyle(fontSize: 13)),
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MeterRow extends StatelessWidget {
  const _MeterRow(
      {required this.label, required this.value, required this.emoji});

  final String label;
  final double value;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(width: 18, child: Text(emoji)),
        SizedBox(
          width: 48,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest,
              color: value > 0.5
                  ? const Color(0xFF4D9E68)
                  : value > 0.25
                      ? const Color(0xFFC9A227)
                      : theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.value, required this.emoji});

  final String label;
  final String value;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$emoji $value $label', style: theme.textTheme.bodySmall),
    );
  }
}

/// A pixel portrait of an employee (their standing-front sprite, scaled up).
class _Portrait extends StatelessWidget {
  const _Portrait(
      {required this.cache, required this.look, required this.scale});

  final SpriteCache cache;
  final EmployeeLook look;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(12 * scale, 17 * scale),
      painter: _PortraitPainter(cache: cache, look: look),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter({required this.cache, required this.look});

  final SpriteCache cache;
  final EmployeeLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final key = 'c-${look.hairStyle}-${look.skin}-${look.hairColor}-'
        '${look.shirt}-${look.pants}-${CharFrame.downIdle.name}';
    final img = cache.imageFor(
      key,
      () => PixelSprite(
        characterRows(CharFrame.downIdle, look.hairStyle),
        paletteForLook(
          skin: look.skin,
          hairColor: look.hairColor,
          shirt: look.shirt,
          pants: look.pants,
        ),
      ),
    );
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_PortraitPainter oldDelegate) =>
      oldDelegate.look != look;
}
