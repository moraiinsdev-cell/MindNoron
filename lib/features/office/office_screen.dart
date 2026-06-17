import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import 'office_camera.dart';
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
    with SingleTickerProviderStateMixin {
  late final OfficeSim _sim;
  late final SpriteCache _cache;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  bool _placed = false;

  // Camera owns the screen<->world transform (auto-fit + player zoom/pan).
  final OfficeCamera _camera = OfficeCamera();

  String? _draggingId;
  bool _panning = false;
  bool _hoveringEmployee = false;

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

  Offset _toWorld(Offset local) => _camera.toWorld(local);

  void _syncFromProviders() {
    final staff = ref.watch(officeStaffProvider).valueOrNull;
    if (staff != null && staff.isNotEmpty) {
      _sim.syncStaff(staff);
      if (!_placed) {
        _placed = true;
        _sim.placeInitial();
      }
    }
    final tasks = ref.watch(openTasksProvider).valueOrNull ?? const <Task>[];
    _sim.openTasks = [for (final t in tasks) (t.id, t.title)];

    ref.read(officeSfxProvider).enabled =
        ref.watch(officeSfxEnabledProvider).valueOrNull ?? true;
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
            child: _OfficePanel(sim: _sim, cache: _cache),
          ),
        ],
      ),
    );
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
                          : _hoveringEmployee
                              ? SystemMouseCursors.grab
                              : MouseCursor.defer,
                  onHover: (event) {
                    final hit = _sim.hitTest(_toWorld(event.localPosition));
                    if ((hit != null) != _hoveringEmployee) {
                      setState(() => _hoveringEmployee = hit != null);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) {
                      final world = _toWorld(d.localPosition);
                      final hit = _sim.hitTest(world);
                      if (hit == null && _sim.hitTestCat(world)) {
                        _sim.petCat();
                        return;
                      }
                      _sim.select(hit?.spec.id);
                    },
                    onPanStart: (d) {
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
  const _OfficePanel({required this.sim, required this.cache});

  final OfficeSim sim;
  final SpriteCache cache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedBuilder(
      animation: sim,
      builder: (context, _) {
        final selected = sim.selected;
        return selected == null
            ? _CompanyOverview(sim: sim, cache: cache)
            : _EmployeeProfile(sim: sim, cache: cache, employee: selected);
      },
    );
  }
}

class _CompanyOverview extends ConsumerWidget {
  const _CompanyOverview({required this.sim, required this.cache});

  final OfficeSim sim;
  final SpriteCache cache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (working, breaks, chats) = sim.headcount();
    final now = TimeOfDay.now();
    final staffCount = sim.employees.length;

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
                    'Shipping focus since day one',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            Text(
              now.format(context),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
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
                      .hire(Random());
                  ref.read(officeSfxProvider).play(OfficeSfxCue.hire);
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
      ],
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
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => sim.commandCoffee(spec.id),
                icon: const Text('☕'),
                label: const Text('Coffee'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => sim.commandWork(spec.id),
                icon: const Text('💼'),
                label: const Text('To work'),
              ),
            ),
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
