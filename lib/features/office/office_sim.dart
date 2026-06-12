import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'office_map.dart';
import 'office_models.dart';
import 'office_sprites.dart';

enum Facing { down, up, left, right }

/// What an employee is currently doing.
enum Activity {
  working, // seated at their desk, typing
  walking, // en route to wherever [goal] points
  coffee, // standing at the coffee machine
  water, // at the water cooler
  snack, // at the vending machine
  sofa, // lounging on the sofa
  chatting, // paired up with a colleague
  wandering, // stretching their legs
  idle, // floater with nothing to do (no free desk)
  dragged, // held by the hand of God
  stunned, // just dropped — seeing stars
}

/// Where a walk ends and what starts there.
enum Goal { desk, coffee, water, snack, sofa, chat, wander, none }

const _walkSpeed = 42.0; // px/s

/// Hard cap on roster size (desks + a few floaters).
const maxStaff = 12;

const _workPhrases = [
  'hmm…',
  'aha!',
  'compiling…',
  'LGTM ✓',
  'one more line…',
  'found the bug 🐛',
  'shipping it 🚀',
  'in the zone',
  'rubber duck time',
];

const _chatPhrases = [
  'lunch later?',
  'the build is green!',
  'new framework dropped',
  'weekend plans?',
  'this coffee slaps',
  'standup in 5',
  'pixel art is art',
  'have you tried rebooting?',
  'big launch soon 👀',
  'the plant grew!',
  'merge conflict drama',
  'who broke CI? 😅',
];

const _wanderBubbles = ['🌱', '🚶', '✨', 'brb', 'thinking…'];

/// Live (non-persisted) state of one employee in the office.
class EmployeeRuntime {
  EmployeeRuntime(this.spec, Random rng)
      : energy = 0.55 + rng.nextDouble() * 0.45,
        social = 0.4 + rng.nextDouble() * 0.6,
        animPhase = rng.nextDouble() * 10;

  EmployeeSpec spec;

  Offset pos = Offset.zero; // feet center, world px
  Facing facing = Facing.down;
  Activity activity = Activity.idle;
  Goal goal = Goal.none;

  List<Point<int>> path = const [];
  int pathIndex = 0;

  double energy; // 0..1, drains while working
  double social; // 0..1, drains over time; chats refill it
  double activityTimer = 0; // counts down inside timed activities
  double chatCooldown = 0;
  double coffeeCooldown = 0;
  double bubbleTimer = 0; // until the next ambient bubble

  int deskIndex = -1; // claimed desk, or -1 (floater)
  int sofaSeat = -1;
  int chatSpotIndex = -1;
  bool chatIsA = false;
  String? chatPartnerId;

  String? bubble;
  double bubbleTtl = 0;

  double animPhase; // drives walk/typing animation frames
  bool get isSeated =>
      activity == Activity.working || activity == Activity.sofa;

  double get mood => (energy * 0.55 + social * 0.45).clamp(0.0, 1.0);

  String get moodEmoji => mood >= 0.7
      ? '😊'
      : mood >= 0.45
          ? '🙂'
          : mood >= 0.25
              ? '😪'
              : '🥱';

  void say(String text, [double ttl = 2.6]) {
    bubble = text;
    bubbleTtl = ttl;
  }
}

/// The MindNoron Inc. simulation. Ticked every frame by the office screen;
/// notifies listeners so the canvas repaints.
class OfficeSim extends ChangeNotifier {
  OfficeSim({int? seed}) : _rng = Random(seed);

  final Random _rng;
  final employees = <EmployeeRuntime>[];
  final _usedChatSpots = <int>{};

  String? selectedId;
  List<(String, String)> openTasks = const []; // (taskId, title)

  EmployeeRuntime? byId(String? id) {
    if (id == null) return null;
    for (final e in employees) {
      if (e.spec.id == id) return e;
    }
    return null;
  }

  EmployeeRuntime? get selected => byId(selectedId);

  /// Selects (or deselects, with null) an employee and repaints.
  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Staff roster sync (persisted specs -> runtime employees)
  // -------------------------------------------------------------------------

  /// Reconciles the live roster with the persisted one. Existing employees
  /// keep their position/state; new ones walk in through the door.
  void syncStaff(List<EmployeeSpec> specs) {
    final byIdMap = {for (final e in employees) e.spec.id: e};
    final seen = <String>{};
    var changed = false;
    for (final spec in specs) {
      seen.add(spec.id);
      final existing = byIdMap[spec.id];
      if (existing != null) {
        existing.spec = spec;
        continue;
      }
      final hire = EmployeeRuntime(spec, _rng)
        ..pos = tileCenter(const Point(14, 18))
        ..facing = Facing.up;
      employees.add(hire);
      _adoptDefaultGoal(hire);
      changed = true;
    }
    for (final e in [...employees]) {
      if (!seen.contains(e.spec.id)) {
        _releaseClaims(e);
        employees.remove(e);
        if (selectedId == e.spec.id) selectedId = null;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Seeds initial positions: everyone starts at (or near) their desk so the
  /// office is alive from the first frame.
  void placeInitial() {
    for (final e in employees) {
      _claimDesk(e);
      if (e.deskIndex >= 0) {
        final desk = officeDesks[e.deskIndex];
        e.pos = desk.seatPos;
        e.activity = Activity.working;
        e.facing = Facing.up;
      } else {
        e.pos = tileCenter(
            wanderSpots[_rng.nextInt(wanderSpots.length)]);
        e.activity = Activity.idle;
      }
    }
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Tick
  // -------------------------------------------------------------------------

  void tick(double dt) {
    if (dt <= 0) return;
    for (final e in employees) {
      e.animPhase += dt;
      e.chatCooldown = max(0, e.chatCooldown - dt);
      e.coffeeCooldown = max(0, e.coffeeCooldown - dt);
      if (e.bubbleTtl > 0) {
        e.bubbleTtl -= dt;
        if (e.bubbleTtl <= 0) e.bubble = null;
      }
      switch (e.activity) {
        case Activity.working:
          _tickWorking(e, dt);
        case Activity.walking:
          _tickWalking(e, dt);
        case Activity.coffee:
        case Activity.water:
        case Activity.snack:
          _tickRefreshment(e, dt);
        case Activity.sofa:
          _tickSofa(e, dt);
        case Activity.chatting:
          _tickChat(e, dt);
        case Activity.wandering:
          _tickWander(e, dt);
        case Activity.idle:
          _tickIdle(e, dt);
        case Activity.dragged:
          break; // position is driven by the pointer
        case Activity.stunned:
          e.activityTimer -= dt;
          if (e.activityTimer <= 0) _adoptDefaultGoal(e);
      }
    }
    _matchmakeChats();
    notifyListeners();
  }

  void _tickWorking(EmployeeRuntime e, double dt) {
    final p = e.spec.personality;
    e.energy =
        (e.energy - 0.011 * p.energyDrain * dt).clamp(0.0, 1.0);
    e.social = (e.social - 0.009 * p.chattiness * dt).clamp(0.0, 1.0);
    e.bubbleTimer -= dt;
    if (e.bubbleTimer <= 0) {
      e.bubbleTimer = 9 + _rng.nextDouble() * 14;
      if (_rng.nextDouble() < 0.6) {
        final task = taskTitleFor(e);
        e.say(task != null && _rng.nextDouble() < 0.5
            ? _ellipsize(task, 16)
            : _workPhrases[_rng.nextInt(_workPhrases.length)]);
      }
    }
    if (e.energy < 0.22 + _rng.nextDouble() * 0.06 &&
        e.coffeeCooldown <= 0) {
      final wantsCoffee = _rng.nextDouble() < 0.6 * p.coffeeLove;
      if (wantsCoffee) {
        _sendTo(e, coffeeSpot, Goal.coffee);
      } else if (_rng.nextDouble() < 0.5) {
        _sendTo(e, vendingSpot, Goal.snack);
      } else {
        _trySofa(e);
      }
      return;
    }
    // The occasional stroll keeps the floor moving.
    if (_rng.nextDouble() < 0.0015 * dt * 60) {
      _sendTo(e, wanderSpots[_rng.nextInt(wanderSpots.length)], Goal.wander);
    }
  }

  void _tickWalking(EmployeeRuntime e, double dt) {
    if (e.pathIndex >= e.path.length) {
      _arrive(e);
      return;
    }
    final target = tileCenter(e.path[e.pathIndex]);
    final delta = target - e.pos;
    final dist = delta.distance;
    final step = _walkSpeed * e.spec.personality.paceFactor * dt;
    if (dist <= step) {
      e.pos = target;
      e.pathIndex++;
      if (e.pathIndex >= e.path.length) _arrive(e);
      return;
    }
    e.pos += delta / dist * step;
    e.facing = delta.dx.abs() > delta.dy.abs()
        ? (delta.dx > 0 ? Facing.right : Facing.left)
        : (delta.dy > 0 ? Facing.down : Facing.up);
  }

  void _tickRefreshment(EmployeeRuntime e, double dt) {
    e.energy = (e.energy + 0.09 * dt).clamp(0.0, 1.0);
    e.activityTimer -= dt;
    if (e.activityTimer <= 0) {
      e.coffeeCooldown = 30 + _rng.nextDouble() * 20;
      if (e.energy < 0.55 && _rng.nextDouble() < 0.4) {
        _trySofa(e);
      } else if (_rng.nextDouble() < 0.25) {
        _sendTo(
            e, wanderSpots[_rng.nextInt(wanderSpots.length)], Goal.wander);
      } else {
        _adoptDefaultGoal(e);
      }
    }
  }

  void _tickSofa(EmployeeRuntime e, double dt) {
    e.energy = (e.energy + 0.05 * dt).clamp(0.0, 1.0);
    e.activityTimer -= dt;
    if (e.activityTimer <= 0 || e.energy >= 0.98) {
      _releaseSofa(e);
      _adoptDefaultGoal(e);
    }
  }

  void _tickChat(EmployeeRuntime e, double dt) {
    final partner = byId(e.chatPartnerId);
    if (partner == null || partner.activity == Activity.dragged) {
      _endChat(e, alsoPartner: false);
      return;
    }
    e.social = (e.social + 0.06 * dt).clamp(0.0, 1.0);
    e.activityTimer -= dt;
    e.bubbleTimer -= dt;
    if (e.bubbleTimer <= 0) {
      e.bubbleTimer = 3.5 + _rng.nextDouble() * 2.5;
      e.say(_chatPhrases[_rng.nextInt(_chatPhrases.length)], 2.4);
    }
    if (e.activityTimer <= 0) _endChat(e);
  }

  void _tickWander(EmployeeRuntime e, double dt) {
    e.activityTimer -= dt;
    e.social = (e.social - 0.004 * dt).clamp(0.0, 1.0);
    if (e.activityTimer <= 0) _adoptDefaultGoal(e);
  }

  void _tickIdle(EmployeeRuntime e, double dt) {
    e.social =
        (e.social - 0.006 * e.spec.personality.chattiness * dt)
            .clamp(0.0, 1.0);
    e.energy = (e.energy + 0.01 * dt).clamp(0.0, 1.0);
    e.activityTimer -= dt;
    if (e.activityTimer <= 0) {
      e.activityTimer = 4 + _rng.nextDouble() * 6;
      // Floaters drift between wander spots and try to claim a desk.
      _claimDesk(e);
      if (e.deskIndex >= 0) {
        _sendToDesk(e);
      } else if (_rng.nextDouble() < 0.5) {
        _sendTo(
            e, wanderSpots[_rng.nextInt(wanderSpots.length)], Goal.wander);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Goals & arrivals
  // -------------------------------------------------------------------------

  void _sendTo(EmployeeRuntime e, Point<int> tile, Goal goal) {
    final start = tileAt(e.pos);
    final path = findPath(start, nearestWalkable(tile));
    if (path == null) {
      _adoptDefaultGoal(e);
      return;
    }
    if (e.activity == Activity.sofa) _releaseSofa(e);
    e.path = path;
    e.pathIndex = 0;
    e.goal = goal;
    e.activity = Activity.walking;
  }

  void _sendToDesk(EmployeeRuntime e) {
    if (e.deskIndex < 0) {
      _claimDesk(e);
      if (e.deskIndex < 0) {
        e.activity = Activity.idle;
        e.activityTimer = 3;
        return;
      }
    }
    _sendTo(e, officeDesks[e.deskIndex].seatTile, Goal.desk);
  }

  void _trySofa(EmployeeRuntime e) {
    final taken = employees.map((x) => x.sofaSeat).toSet();
    final free = [0, 1].where((i) => !taken.contains(i)).toList();
    if (free.isEmpty) {
      _adoptDefaultGoal(e);
      return;
    }
    e.sofaSeat = free[_rng.nextInt(free.length)];
    _sendTo(e, sofaApproach[e.sofaSeat], Goal.sofa);
  }

  void _arrive(EmployeeRuntime e) {
    switch (e.goal) {
      case Goal.desk:
        if (e.deskIndex >= 0) {
          e.pos = officeDesks[e.deskIndex].seatPos;
          e.facing = Facing.up;
          e.activity = Activity.working;
          e.bubbleTimer = 2 + _rng.nextDouble() * 6;
        } else {
          e.activity = Activity.idle;
          e.activityTimer = 2;
        }
      case Goal.coffee:
        e.activity = Activity.coffee;
        e.facing = Facing.up;
        e.activityTimer = 5 + _rng.nextDouble() * 4;
        e.say('☕', 2.8);
      case Goal.water:
        e.activity = Activity.water;
        e.facing = Facing.up;
        e.activityTimer = 4 + _rng.nextDouble() * 3;
        e.say('💧', 2.4);
      case Goal.snack:
        e.activity = Activity.snack;
        e.facing = Facing.up;
        e.activityTimer = 4 + _rng.nextDouble() * 3;
        e.say('🍫', 2.4);
      case Goal.sofa:
        if (e.sofaSeat >= 0) {
          e.pos = sofaSeatPos[e.sofaSeat];
          e.facing = Facing.down;
          e.activity = Activity.sofa;
          e.activityTimer = 8 + _rng.nextDouble() * 8;
          e.say('😌', 2.4);
        } else {
          _adoptDefaultGoal(e);
        }
      case Goal.chat:
        e.activity = Activity.chatting;
        e.activityTimer = 10 + _rng.nextDouble() * 8;
        e.bubbleTimer = e.chatIsA ? 0.4 : 2.2; // take turns talking
        final spot = chatSpots[e.chatSpotIndex];
        e.facing = spot.faceAxisX
            ? (e.chatIsA ? Facing.right : Facing.left)
            : (e.chatIsA ? Facing.down : Facing.up);
      case Goal.wander:
        e.activity = Activity.wandering;
        e.activityTimer = 2 + _rng.nextDouble() * 3;
        if (_rng.nextDouble() < 0.4) {
          e.say(_wanderBubbles[_rng.nextInt(_wanderBubbles.length)], 2);
        }
      case Goal.none:
        _adoptDefaultGoal(e);
    }
    e.goal = Goal.none;
  }

  /// Sends an employee back to whatever their default is (desk or floating).
  void _adoptDefaultGoal(EmployeeRuntime e) {
    _claimDesk(e);
    if (e.deskIndex >= 0) {
      _sendToDesk(e);
    } else {
      e.activity = Activity.idle;
      e.activityTimer = 1 + _rng.nextDouble() * 3;
    }
  }

  void _claimDesk(EmployeeRuntime e) {
    if (e.deskIndex >= 0) return;
    final taken = employees.map((x) => x.deskIndex).toSet();
    for (final desk in officeDesks) {
      if (!taken.contains(desk.index)) {
        e.deskIndex = desk.index;
        return;
      }
    }
  }

  void _releaseClaims(EmployeeRuntime e) {
    e.deskIndex = -1;
    _releaseSofa(e);
    if (e.activity == Activity.chatting) _endChat(e);
  }

  void _releaseSofa(EmployeeRuntime e) => e.sofaSeat = -1;

  // -------------------------------------------------------------------------
  // Chat matchmaking
  // -------------------------------------------------------------------------

  void _matchmakeChats() {
    final candidates = employees.where((e) {
      if (e.chatCooldown > 0 || e.social > 0.35) return false;
      return e.activity == Activity.working ||
          e.activity == Activity.wandering ||
          e.activity == Activity.idle;
    }).toList();
    while (candidates.length >= 2) {
      final spotIndex = _freeChatSpot();
      if (spotIndex == null) return;
      final a = candidates.removeAt(_rng.nextInt(candidates.length));
      final b = candidates.removeAt(_rng.nextInt(candidates.length));
      _usedChatSpots.add(spotIndex);
      final spot = chatSpots[spotIndex];
      for (final (emp, isA) in [(a, true), (b, false)]) {
        emp.chatSpotIndex = spotIndex;
        emp.chatIsA = isA;
        emp.chatPartnerId = (isA ? b : a).spec.id;
        _sendTo(emp, isA ? spot.a : spot.b, Goal.chat);
        emp.goal = Goal.chat; // _sendTo may have rerouted; force the goal
      }
    }
  }

  int? _freeChatSpot() {
    final free = [
      for (var i = 0; i < chatSpots.length; i++)
        if (!_usedChatSpots.contains(i)) i
    ];
    return free.isEmpty ? null : free[_rng.nextInt(free.length)];
  }

  void _endChat(EmployeeRuntime e, {bool alsoPartner = true}) {
    final partner = byId(e.chatPartnerId);
    _usedChatSpots.remove(e.chatSpotIndex);
    e.chatSpotIndex = -1;
    e.chatPartnerId = null;
    e.chatCooldown = 25 + _rng.nextDouble() * 20;
    e.social = max(e.social, 0.7);
    if (e.activity == Activity.chatting || e.goal == Goal.chat) {
      _adoptDefaultGoal(e);
    }
    if (alsoPartner && partner != null) {
      _endChat(partner, alsoPartner: false);
    }
  }

  // -------------------------------------------------------------------------
  // God mode: drag & drop, commands
  // -------------------------------------------------------------------------

  /// Returns the employee whose sprite contains [world] (topmost first).
  EmployeeRuntime? hitTest(Offset world) {
    EmployeeRuntime? best;
    for (final e in employees) {
      final r = Rect.fromCenter(
          center: e.pos.translate(0, -9), width: 14, height: 22);
      if (r.contains(world) && (best == null || e.pos.dy > best.pos.dy)) {
        best = e;
      }
    }
    return best;
  }

  void beginDrag(String id) {
    final e = byId(id);
    if (e == null) return;
    if (e.activity == Activity.chatting || e.goal == Goal.chat) {
      _endChat(e);
    }
    _releaseSofa(e);
    e.path = const [];
    e.activity = Activity.dragged;
    e.goal = Goal.none;
    e.facing = Facing.down;
    e.say('😱', 1.6);
    selectedId = id;
    notifyListeners();
  }

  void dragTo(String id, Offset world) {
    final e = byId(id);
    if (e == null || e.activity != Activity.dragged) return;
    e.pos = Offset(
      world.dx.clamp(8.0, worldWidth - 8.0),
      world.dy.clamp(24.0, worldHeight - 4.0),
    );
    notifyListeners();
  }

  void drop(String id) {
    final e = byId(id);
    if (e == null || e.activity != Activity.dragged) return;
    final tile = tileAt(e.pos);

    // Dropping someone onto furniture has intent: desk = work there,
    // coffee machine = break time, sofa = nap...
    final desk = _deskAtTile(tile);
    if (desk != null) {
      _evictDesk(e, desk.index);
      e.deskIndex = desk.index;
      e.pos = desk.seatPos;
      e.facing = Facing.up;
      e.activity = Activity.working;
      e.say('💼', 2);
      notifyListeners();
      return;
    }
    if (tile.y == 15 || tile.y == 16) {
      if (tile.x >= 2 && tile.x <= 3) {
        e.pos = tileCenter(coffeeSpot);
        _startRefreshment(e, Activity.coffee, '☕');
        return;
      }
      if (tile.x == 5) {
        e.pos = tileCenter(const Point(5, 16));
        _startRefreshment(e, Activity.water, '💧');
        return;
      }
      if (tile.x == 7) {
        e.pos = tileCenter(vendingSpot);
        _startRefreshment(e, Activity.snack, '🍫');
        return;
      }
      if (tile.x >= 20 && tile.x <= 21) {
        final taken = employees.map((x) => x.sofaSeat).toSet();
        final seat = !taken.contains(tile.x - 20)
            ? tile.x - 20
            : (!taken.contains(1 - (tile.x - 20)) ? 1 - (tile.x - 20) : -1);
        if (seat >= 0) {
          e.sofaSeat = seat;
          e.pos = sofaSeatPos[seat];
          e.facing = Facing.down;
          e.activity = Activity.sofa;
          e.activityTimer = 8 + _rng.nextDouble() * 8;
          e.say('😌', 2.4);
          notifyListeners();
          return;
        }
      }
    }

    final landing = nearestWalkable(tile);
    e.pos = tileCenter(landing);
    e.activity = Activity.stunned;
    e.activityTimer = 1.1 + _rng.nextDouble() * 0.5;
    e.facing = Facing.down;
    e.say('@_@', 1.4);
    notifyListeners();
  }

  void _startRefreshment(EmployeeRuntime e, Activity a, String emote) {
    e.activity = a;
    e.facing = Facing.up;
    e.activityTimer = 5 + _rng.nextDouble() * 3;
    e.say(emote, 2.4);
    notifyListeners();
  }

  DeskSpot? _deskAtTile(Point<int> tile) {
    for (final d in officeDesks) {
      final inDesk =
          tile.y == d.ty && tile.x >= d.tx && tile.x <= d.tx + 1;
      final inSeat =
          tile.y == d.ty + 1 && tile.x >= d.tx && tile.x <= d.tx + 1;
      if (inDesk || inSeat) return d;
    }
    return null;
  }

  /// If someone else owns [deskIndex], they grumble and become a floater.
  void _evictDesk(EmployeeRuntime newcomer, int deskIndex) {
    for (final other in employees) {
      if (other != newcomer && other.deskIndex == deskIndex) {
        other.deskIndex = -1;
        if (other.activity == Activity.working) {
          other.activity = Activity.idle;
          other.activityTimer = 1;
          other.say('😤', 2.2);
        }
      }
    }
  }

  /// Sends the employee for a coffee right now (panel button).
  void commandCoffee(String id) {
    final e = byId(id);
    if (e == null || e.activity == Activity.dragged) return;
    if (e.activity == Activity.chatting) _endChat(e);
    _sendTo(e, coffeeSpot, Goal.coffee);
    notifyListeners();
  }

  /// Sends the employee back to their desk right now (panel button).
  void commandWork(String id) {
    final e = byId(id);
    if (e == null || e.activity == Activity.dragged) return;
    if (e.activity == Activity.chatting) _endChat(e);
    if (e.activity == Activity.sofa) _releaseSofa(e);
    _sendToDesk(e);
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Task helpers & status strings
  // -------------------------------------------------------------------------

  /// The real task this employee is working on: their pinned task if it is
  /// still open, otherwise an automatic round-robin share of the backlog.
  String? taskTitleFor(EmployeeRuntime e) {
    final pinned = e.spec.taskId;
    if (pinned != null) {
      for (final (id, title) in openTasks) {
        if (id == pinned) return title;
      }
    }
    if (openTasks.isEmpty) return null;
    final i = employees.indexOf(e);
    if (i < 0 || i >= openTasks.length) return null;
    return openTasks[i % openTasks.length].$2;
  }

  String statusLine(EmployeeRuntime e) {
    switch (e.activity) {
      case Activity.working:
        final task = taskTitleFor(e);
        return task != null
            ? 'Working on "${_ellipsize(task, 28)}"'
            : 'Typing away at desk ${e.deskIndex + 1}';
      case Activity.walking:
        return switch (e.goal) {
          Goal.coffee => 'Heading for coffee',
          Goal.water => 'Off to the water cooler',
          Goal.snack => 'Raiding the vending machine',
          Goal.sofa => 'Going for a power nap',
          Goal.chat => 'Going to chat with a colleague',
          Goal.desk => 'Walking back to their desk',
          _ => 'Stretching their legs',
        };
      case Activity.coffee:
        return 'Brewing a fresh cup ☕';
      case Activity.water:
        return 'Hydrating 💧';
      case Activity.snack:
        return 'Snack break 🍫';
      case Activity.sofa:
        return 'Recharging on the sofa';
      case Activity.chatting:
        final partner = byId(e.chatPartnerId);
        return partner != null
            ? 'Chatting with ${partner.spec.name}'
            : 'Chatting';
      case Activity.wandering:
        return 'Wandering the office';
      case Activity.idle:
        return 'Looking for a free desk…';
      case Activity.dragged:
        return 'In the hand of God 😱';
      case Activity.stunned:
        return 'Recovering from the flight @_@';
    }
  }

  /// Counts for the header: (working, onBreak, chatting).
  (int, int, int) headcount() {
    var working = 0, breaks = 0, chats = 0;
    for (final e in employees) {
      switch (e.activity) {
        case Activity.working:
          working++;
        case Activity.coffee:
        case Activity.water:
        case Activity.snack:
        case Activity.sofa:
          breaks++;
        case Activity.chatting:
          chats++;
        default:
          break;
      }
    }
    return (working, breaks, chats);
  }

  // -------------------------------------------------------------------------
  // Rendering helpers
  // -------------------------------------------------------------------------

  /// Picks the sprite frame for the employee's current state.
  /// Returns the frame plus whether to mirror horizontally.
  (CharFrame, bool) frameFor(EmployeeRuntime e) {
    switch (e.activity) {
      case Activity.working:
        return (CharFrame.sitBack, false);
      case Activity.sofa:
        return (CharFrame.sitFront, false);
      case Activity.dragged:
        return (CharFrame.downWalkA, false); // legs dangling
      case Activity.walking:
        final step = (e.animPhase * 6).floor() % 2 == 0;
        return switch (e.facing) {
          Facing.down => (
              step ? CharFrame.downWalkA : CharFrame.downWalkB,
              false
            ),
          Facing.up => (step ? CharFrame.upWalkA : CharFrame.upWalkB, false),
          Facing.right => (
              step ? CharFrame.sideWalkA : CharFrame.sideWalkB,
              false
            ),
          Facing.left => (
              step ? CharFrame.sideWalkA : CharFrame.sideWalkB,
              true
            ),
        };
      default:
        return switch (e.facing) {
          Facing.down => (CharFrame.downIdle, false),
          Facing.up => (CharFrame.upIdle, false),
          Facing.right => (CharFrame.sideIdle, false),
          Facing.left => (CharFrame.sideIdle, true),
        };
    }
  }

  static bool deskOccupied(OfficeSim sim, int deskIndex) => sim.employees.any(
      (e) => e.deskIndex == deskIndex && e.activity == Activity.working);
}

String _ellipsize(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max - 1)}…';
