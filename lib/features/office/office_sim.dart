import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'office_catalog.dart';
import 'office_economy.dart';
import 'office_map.dart';
import 'office_models.dart';
import 'office_particles.dart';
import 'office_sprites.dart';

enum Facing { down, up, left, right }

/// What an employee is currently doing.
enum Activity {
  working, // seated at their desk, typing
  walking, // en route to wherever [goal] points
  coffee, // at the café espresso machine
  water, // at a water cooler
  snack, // raiding the fridge / vending machine
  sofa, // napping in the lounge pit
  gym, // working out (mats / dumbbell rack)
  swim, // paddling around the pool
  sunbathe, // lying on a poolside lounger
  read, // in the library
  meditate, // on a cushion in the Focus room
  cafe, // sitting at a café table
  chatting, // paired up with a colleague
  wandering, // stretching their legs
  idle, // floater with nothing to do (no free desk)
  dragged, // held by the hand of God
  stunned, // just dropped — seeing stars
}

/// Where a walk ends and what starts there.
enum Goal {
  desk,
  coffee,
  water,
  snack,
  sofa,
  gym,
  swim,
  sunbathe,
  read,
  meditate,
  cafe,
  chat,
  wander,
  none,
}

/// Which seat list a seated employee occupies.
enum SeatKind { none, sofa, deck, cushion, readChair }

const _walkSpeed = 42.0; // px/s
const _swimSpeed = 13.0; // px/s

/// Hard cap on roster size (desks + a few floaters).
const maxStaff = 14;

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
  'to the moon 📈',
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
  'stock is up 📈',
  'pool later?',
];

const _wanderBubbles = ['🌱', '🚶', '✨', 'brb', 'thinking…'];

/// Live (non-persisted) state of one employee in the office.
class EmployeeRuntime {
  EmployeeRuntime(this.spec, Random rng)
      : energy = 0.55 + rng.nextDouble() * 0.45,
        social = 0.4 + rng.nextDouble() * 0.6,
        leisureTimer = 40 + rng.nextDouble() * 140,
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
  double leisureTimer; // until the next gym/pool/library urge
  double chatCooldown = 0;
  double coffeeCooldown = 0;
  double bubbleTimer = 0; // until the next ambient bubble

  int deskIndex = -1; // claimed desk, or -1 (floater)
  SeatKind seatKind = SeatKind.none;
  int seatIndex = -1;
  Point<int>? spotTarget; // gym/café/read-stand spot being used
  Offset? swimTarget;

  int chatSpotIndex = -1;
  bool chatIsA = false;
  String? chatPartnerId;

  String? bubble;
  double bubbleTtl = 0;

  double animPhase; // drives walk/typing animation frames

  bool get isSeated =>
      activity == Activity.working ||
      activity == Activity.sofa ||
      activity == Activity.sunbathe ||
      activity == Activity.meditate ||
      activity == Activity.cafe ||
      (activity == Activity.read && seatKind == SeatKind.readChair);

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

enum CatState { wandering, sitting, sleeping }

/// Outdoor weather over the campus. Cosmetic — drives rain streaks over the
/// garden and a slight mood shift; never affects the simulation.
enum OfficeWeather { clear, rain }

/// The result of poking an object on the floor, so the screen can play a
/// matching sound effect.
enum PokeKind { none, splash, coffee, drink, snack, plant, books, tech, generic }

/// A short-lived label that floats up and fades over the world (object pokes,
/// "+coins", event banners).
class FloatingText {
  FloatingText(this.pos, this.text, this.ttl, {this.color, this.rise = 14})
      : maxTtl = ttl;
  final Offset pos;
  final String text;
  double ttl;
  final double maxTtl;
  final Color? color;
  final double rise;
}

/// Pixel, the office cat. Fully autonomous; click her for a meow.
class OfficeCat {
  Offset pos = Offset.zero;
  CatState state = CatState.sitting;
  List<Point<int>> path = const [];
  int pathIndex = 0;
  double timer = 3;
  bool facingRight = true;
  double animPhase = 0;
  String? bubble;
  double bubbleTtl = 0;

  void say(String text, [double ttl = 2]) {
    bubble = text;
    bubbleTtl = ttl;
  }
}

/// A garden butterfly — pure ambience over the outdoor grass.
class Butterfly {
  Butterfly(this.pos, this.target, this.phase, this.color);
  Offset pos;
  Offset target;
  double phase;
  final Color color;
}

const _catSpeed = 26.0;

/// Where Pixel likes to hang out (besides random wander spots).
const _catNapSpots = <Point<int>>[
  Point(33, 24), // lounge rug
  Point(17, 20), // library
  Point(44, 24), // sunny grass
  Point(24, 29), // café floor
  Point(5, 20), // focus room (zen cat)
];

/// The MindNoron campus simulation. Ticked every frame by the office screen;
/// notifies listeners so the canvas repaints.
class OfficeSim extends ChangeNotifier {
  OfficeSim({int? seed}) : _rng = Random(seed) {
    for (var i = 0; i < 3; i++) {
      butterflies.add(Butterfly(
        _randomGardenPoint(),
        _randomGardenPoint(),
        _rng.nextDouble() * 10,
        const [
          Color(0xFFF2E8C8),
          Color(0xFFE8C84A),
          Color(0xFFE89CB8),
        ][i % 3],
      ));
    }
  }

  final Random _rng;
  final employees = <EmployeeRuntime>[];
  final cat = OfficeCat();
  final butterflies = <Butterfly>[];
  late final particles = ParticleField(_rng);
  final floatingTexts = <FloatingText>[];
  final _usedChatSpots = <int>{};

  /// Player-placed furniture (build mode). Kept in sync with the persisted
  /// layout; drives both rendering and the dynamic collision overlay.
  List<PlacedItem> placedItems = const [];

  /// Reconciles placed furniture from the persisted layout and rebuilds the
  /// walkability overlay so the AI routes around new pieces.
  void syncLayout(List<PlacedItem> items) {
    placedItems = items;
    placedBlocked.clear();
    for (final p in items) {
      final item = catalogItem(p.itemId);
      if (item == null || !item.blocks) continue;
      final (w, h) = _footprint(item, p.rot);
      for (var dy = 0; dy < h; dy++) {
        for (var dx = 0; dx < w; dx++) {
          placedBlocked.add(Point(p.tx + dx, p.ty + dy));
        }
      }
    }
    notifyListeners();
  }

  /// Footprint after rotation (90°/270° swap width and height).
  static (int, int) _footprint(CatalogItem item, int rot) =>
      rot.isOdd ? (item.th, item.tw) : (item.tw, item.th);

  /// Whether [item] can be placed with its anchor at ([tx],[ty]): every
  /// footprint tile must be open static floor, free of other placed pieces
  /// and not under an employee, and clear of the front door.
  bool canPlaceAt(CatalogItem item, int tx, int ty, {int rot = 0}) {
    final (w, h) = _footprint(item, rot);
    for (var dy = 0; dy < h; dy++) {
      for (var dx = 0; dx < w; dx++) {
        final x = tx + dx, y = ty + dy;
        if (!isStaticWalkable(x, y)) return false;
        if (placedBlocked.contains(Point(x, y))) return false;
        if (x == doorTile.x && y == doorTile.y) return false;
        if (employees.any((e) => tileAt(e.pos) == Point(x, y))) return false;
      }
    }
    return true;
  }

  /// The placed item whose footprint covers [tile], if any (topmost wins).
  PlacedItem? placedAt(Point<int> tile) {
    for (final p in placedItems.reversed) {
      final item = catalogItem(p.itemId);
      if (item == null) continue;
      final (w, h) = _footprint(item, p.rot);
      if (tile.x >= p.tx &&
          tile.x < p.tx + w &&
          tile.y >= p.ty &&
          tile.y < p.ty + h) {
        return p;
      }
    }
    return null;
  }

  /// Current outdoor weather (cosmetic). Recomputed on a slow timer.
  OfficeWeather weather = OfficeWeather.clear;
  double _weatherTimer = 90;

  /// Forces a weather state (settings/tests).
  void setWeather(OfficeWeather w) {
    weather = w;
    notifyListeners();
  }

  /// Set false to silence ambient office events (settings/tests).
  bool eventsEnabled = true;
  double _eventTimer = 35;

  void _tickEvents(double dt) {
    if (!eventsEnabled || employees.isEmpty) return;
    _eventTimer -= dt;
    if (_eventTimer > 0) return;
    _eventTimer = 55 + _rng.nextDouble() * 75;
    triggerRandomEvent();
  }

  /// Fires one of the little ambient office moments. Cosmetic only — bubbles,
  /// floating labels and particles; never touches the activity state machine.
  void triggerRandomEvent() {
    if (employees.isEmpty) return;
    switch (_rng.nextInt(5)) {
      case 0: // rubber-duck debugging
        _randomEmployee().say('rubber duck time 🦆', 3);
      case 1: // a delivery arrives at the front door
        floating(tileCenter(doorTile).translate(0, -10), '📦', ttl: 2.2);
        _nudge(tileCenter(doorTile), 'delivery! 📦', range: 260);
      case 2: // Pixel knocks something over
        floating(cat.pos.translate(0, -10), '🐱💥', ttl: 1.8);
        cat.say('meo!', 2);
        particles.emitSteam(cat.pos); // a little puff of "dust"
      case 3: // someone proposes a coffee run
        final host = _randomEmployee();
        host.say('coffee run? ☕', 2.4);
        _nudge(host.pos, '🙋', range: 120);
      case 4: // spontaneous brainstorm
        _randomEmployee().say('💡', 2.2);
    }
    notifyListeners();
  }

  EmployeeRuntime _randomEmployee() =>
      employees[_rng.nextInt(employees.length)];

  /// A coin reward landed (a real task was completed): confetti + a "+N 🪙"
  /// float over a celebrating employee.
  void celebrateCoins(int amount) {
    final e = employees.isEmpty ? null : _randomEmployee();
    final at = e?.pos ?? tileCenter(doorTile);
    particles.confetti(Offset(at.dx, at.dy - 18), count: 16);
    floating(Offset(at.dx, at.dy - 24), '+$amount 🪙',
        ttl: 2.0, color: const Color(0xFFFFD24A));
    e?.say('🎉', 2);
    notifyListeners();
  }

  void _tickWeather(double dt) {
    _weatherTimer -= dt;
    if (_weatherTimer > 0) return;
    // Mostly clear, with the occasional shower that lingers a while.
    final wasRain = weather == OfficeWeather.rain;
    weather =
        _rng.nextDouble() < (wasRain ? 0.55 : 0.18) ? OfficeWeather.rain : OfficeWeather.clear;
    _weatherTimer = wasRain
        ? 60 + _rng.nextDouble() * 90
        : 120 + _rng.nextDouble() * 240;
  }

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
        ..pos = tileCenter(doorTile)
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
    cat.pos = tileCenter(_catNapSpots.first);
    cat.state = CatState.sitting;
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
        case Activity.cafe:
          _tickRefreshment(e, dt);
          // A wisp of steam from the fresh cup.
          if (_rng.nextDouble() < dt * 3.5) {
            particles.emitSteam(Offset(e.pos.dx, e.pos.dy - 12));
          }
        case Activity.water:
        case Activity.snack:
          _tickRefreshment(e, dt);
        case Activity.sofa:
        case Activity.sunbathe:
        case Activity.meditate:
        case Activity.read:
          _tickRest(e, dt);
        case Activity.gym:
          _tickGym(e, dt);
        case Activity.swim:
          _tickSwim(e, dt);
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
    _tickCat(dt);
    _tickButterflies(dt);
    _tickWeather(dt);
    _tickEvents(dt);
    particles.tick(dt);
    if (floatingTexts.isNotEmpty) {
      for (final f in floatingTexts) {
        f.ttl -= dt;
      }
      floatingTexts.removeWhere((f) => f.ttl <= 0);
    }
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Pixel the cat & garden butterflies
  // -------------------------------------------------------------------------

  void _tickCat(double dt) {
    final c = cat;
    c.animPhase += dt;
    if (c.bubbleTtl > 0) {
      c.bubbleTtl -= dt;
      if (c.bubbleTtl <= 0) c.bubble = null;
    }
    switch (c.state) {
      case CatState.wandering:
        if (c.pathIndex >= c.path.length) {
          // Arrived: nap, sit, or keep prowling.
          final roll = _rng.nextDouble();
          if (roll < 0.35) {
            c.state = CatState.sleeping;
            c.timer = 14 + _rng.nextDouble() * 14;
            c.say('💤', 2.2);
          } else if (roll < 0.75) {
            c.state = CatState.sitting;
            c.timer = 5 + _rng.nextDouble() * 7;
          } else {
            _catProwl();
          }
          return;
        }
        final target = tileCenter(c.path[c.pathIndex]);
        final delta = target - c.pos;
        final dist = delta.distance;
        final step = _catSpeed * dt;
        if (dist <= step) {
          c.pos = target;
          c.pathIndex++;
        } else {
          c.pos += delta / dist * step;
          if (delta.dx.abs() > 0.5) c.facingRight = delta.dx > 0;
        }
      case CatState.sitting:
      case CatState.sleeping:
        c.timer -= dt;
        if (c.timer <= 0) _catProwl();
    }
  }

  void _catProwl() {
    final c = cat;
    final useNapSpot = _rng.nextDouble() < 0.5;
    final target = useNapSpot
        ? _catNapSpots[_rng.nextInt(_catNapSpots.length)]
        : wanderSpots[_rng.nextInt(wanderSpots.length)];
    final path = findPath(tileAt(c.pos), nearestWalkable(target));
    if (path == null) {
      c.state = CatState.sitting;
      c.timer = 4;
      return;
    }
    c.path = path;
    c.pathIndex = 0;
    c.state = CatState.wandering;
  }

  /// True if [world] hits the cat (the screen pets her: meow!).
  bool hitTestCat(Offset world) {
    final r = Rect.fromCenter(
        center: cat.pos.translate(0, -4), width: 16, height: 12);
    return r.contains(world);
  }

  void petCat() {
    cat.say(_rng.nextDouble() < 0.5 ? 'meo!' : '❤️', 2);
    if (cat.state == CatState.sleeping) {
      cat.state = CatState.sitting;
      cat.timer = 4;
    }
    notifyListeners();
  }

  /// Adds a floating label over the world.
  void floating(Offset pos, String text, {Color? color, double ttl = 1.4}) {
    floatingTexts.add(FloatingText(pos, text, ttl, color: color));
  }

  static const _pokeLines = ['hmm?', '✨', 'ooh', '👀', 'shiny', '*tap*'];

  /// The screen pokes whatever is on [world] (not an employee or the cat).
  /// Produces a little reaction and returns its kind so the UI can play a
  /// matching sound. Returns [PokeKind.none] for empty floor.
  PokeKind pokeAt(Offset world) {
    final tile = tileAt(world);

    if (isPoolTile(tile)) {
      particles.splash(world);
      floating(world.translate(0, -6), '💦');
      notifyListeners();
      return PokeKind.splash;
    }

    // Café counter — fresh brew.
    if ((tile.y == 24 || tile.y == 25) && tile.x >= 15 && tile.x <= 16) {
      final at = tileCenter(coffeeSpot).translate(0, -8);
      for (var i = 0; i < 4; i++) {
        particles.emitSteam(at);
      }
      floating(at, '☕');
      _nudge(at, '☕?');
      notifyListeners();
      return PokeKind.coffee;
    }
    if ((tile.y == 24 || tile.y == 25) && tile.x == 20) {
      floating(tileCenter(waterSpot).translate(0, -8), '💧');
      notifyListeners();
      return PokeKind.drink;
    }
    if ((tile.y == 24 || tile.y == 25) && (tile.x == 18 || tile.x == 26)) {
      floating(tileCenter(tile).translate(0, -8), '🍫');
      notifyListeners();
      return PokeKind.snack;
    }

    final o = objectAt(tile);
    if (o != null) {
      final at = Offset(o.tx * 16 + o.tw * 8, o.ty * 16.0);
      final s = o.sprite;
      final (text, kind) = (s == plantSprite || s == bonsaiSprite)
          ? ('🌱', PokeKind.plant)
          : (s == bookshelfSprite || s == mailShelfSprite)
              ? ('📚', PokeKind.books)
              : (s == serverRackSprite ||
                      s == printerSprite ||
                      s == vendingSprite ||
                      s == safeSprite)
                  ? ('🔧', PokeKind.tech)
                  : (_pokeLines[_rng.nextInt(_pokeLines.length)],
                      PokeKind.generic);
      floating(at, text);
      notifyListeners();
      return kind;
    }
    return PokeKind.none;
  }

  /// The nearest non-dragged employee within range glances over and reacts.
  void _nudge(Offset at, String text, {double range = 150}) {
    EmployeeRuntime? best;
    var bestD = double.infinity;
    for (final e in employees) {
      if (e.activity == Activity.dragged) continue;
      final d = (e.pos - at).distance;
      if (d < bestD) {
        bestD = d;
        best = e;
      }
    }
    if (best != null && bestD <= range) best.say(text, 1.6);
  }

  void _tickButterflies(double dt) {
    for (final b in butterflies) {
      b.phase += dt;
      final delta = b.target - b.pos;
      if (delta.distance < 4) {
        b.target = _randomGardenPoint();
        continue;
      }
      final dir = delta / delta.distance;
      b.pos += dir * 22 * dt +
          Offset(sin(b.phase * 5) * 0.4, cos(b.phase * 7) * 0.5);
    }
  }

  /// A point over the outdoor grass, avoiding the pool water.
  Offset _randomGardenPoint() {
    for (var i = 0; i < 20; i++) {
      final p = Offset(
        (39 * 16) + _rng.nextDouble() * (15 * 16),
        (3 * 16) + _rng.nextDouble() * (30 * 16),
      );
      if (!isPoolTile(tileAt(p))) return p;
    }
    return const Offset(45 * 16.0, 25 * 16.0);
  }

  void _tickWorking(EmployeeRuntime e, double dt) {
    final p = e.spec.personality;
    e.energy =
        (e.energy - 0.011 * p.energyDrain * dt).clamp(0.0, 1.0);
    e.social = (e.social - 0.009 * p.chattiness * dt).clamp(0.0, 1.0);
    e.bubbleTimer -= dt;
    e.leisureTimer -= dt;
    if (e.bubbleTimer <= 0) {
      e.bubbleTimer = 9 + _rng.nextDouble() * 14;
      if (_rng.nextDouble() < 0.6) {
        final task = taskTitleFor(e);
        e.say(task != null && _rng.nextDouble() < 0.5
            ? _ellipsize(task, 16)
            : _workPhrases[_rng.nextInt(_workPhrases.length)]);
      }
    }
    if (e.leisureTimer <= 0) {
      e.leisureTimer = 130 + _rng.nextDouble() * 160;
      _goLeisure(e);
      return;
    }
    if (e.energy < 0.22 + _rng.nextDouble() * 0.06 &&
        e.coffeeCooldown <= 0) {
      final wantsCoffee = _rng.nextDouble() < 0.6 * p.coffeeLove;
      if (wantsCoffee) {
        _sendTo(e, coffeeSpot, Goal.coffee);
      } else if (_rng.nextDouble() < 0.5) {
        _sendTo(e, _rng.nextBool() ? vendingSpot : snackSpot, Goal.snack);
      } else {
        _trySeat(e, sofaSeats, SeatKind.sofa, Goal.sofa);
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
      _freeSpot(e);
      if (e.energy < 0.55 && _rng.nextDouble() < 0.35) {
        _trySeat(e, sofaSeats, SeatKind.sofa, Goal.sofa);
      } else if (_rng.nextDouble() < 0.25) {
        _sendTo(
            e, wanderSpots[_rng.nextInt(wanderSpots.length)], Goal.wander);
      } else {
        _adoptDefaultGoal(e);
      }
    }
  }

  void _tickRest(EmployeeRuntime e, double dt) {
    e.energy = (e.energy + 0.05 * dt).clamp(0.0, 1.0);
    e.activityTimer -= dt;
    if (e.activityTimer <= 0 || e.energy >= 0.98) {
      _releaseSeat(e);
      _freeSpot(e);
      _adoptDefaultGoal(e);
    }
  }

  void _tickGym(EmployeeRuntime e, double dt) {
    // Endorphins: a workout is a net energy gain in pixel-land.
    e.energy = (e.energy + 0.03 * dt).clamp(0.0, 1.0);
    e.activityTimer -= dt;
    e.bubbleTimer -= dt;
    if (e.bubbleTimer <= 0) {
      e.bubbleTimer = 5 + _rng.nextDouble() * 5;
      if (_rng.nextDouble() < 0.5) e.say('💪', 1.8);
    }
    if (e.activityTimer <= 0) {
      _freeSpot(e);
      _adoptDefaultGoal(e);
    }
  }

  void _tickSwim(EmployeeRuntime e, double dt) {
    e.energy = (e.energy + 0.04 * dt).clamp(0.0, 1.0);
    e.activityTimer -= dt;
    e.bubbleTimer -= dt;
    if (e.bubbleTimer <= 0) {
      e.bubbleTimer = 6 + _rng.nextDouble() * 6;
      if (_rng.nextDouble() < 0.5) e.say('💦', 1.6);
    }
    final target = e.swimTarget ?? _randomSwimPoint();
    final delta = target - e.pos;
    if (delta.distance < 3) {
      e.swimTarget = _randomSwimPoint();
    } else {
      e.pos += delta / delta.distance * _swimSpeed * dt;
      e.facing = delta.dx.abs() > delta.dy.abs()
          ? (delta.dx > 0 ? Facing.right : Facing.left)
          : (delta.dy > 0 ? Facing.down : Facing.up);
    }
    if (e.activityTimer <= 0) {
      e.swimTarget = null;
      e.pos = tileCenter(swimEntry);
      e.say('😎', 2);
      _adoptDefaultGoal(e);
    }
  }

  Offset _randomSwimPoint() => Offset(
        swimArea.left + _rng.nextDouble() * swimArea.width,
        swimArea.top + _rng.nextDouble() * swimArea.height,
      );

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
    e.leisureTimer -= dt;
    if (e.leisureTimer <= 0) {
      e.leisureTimer = 100 + _rng.nextDouble() * 140;
      _goLeisure(e);
      return;
    }
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
  // Leisure: every personality has favorite campus spots
  // -------------------------------------------------------------------------

  List<Goal> _leisureFor(Personality p) => switch (p.id) {
        'speedrunner' => const [Goal.gym, Goal.gym, Goal.swim],
        'coffeeAddict' => const [Goal.cafe, Goal.gym],
        'zenMaster' => const [Goal.meditate, Goal.meditate, Goal.read],
        'perfectionist' => const [Goal.meditate, Goal.gym, Goal.read],
        'daydreamer' => const [Goal.swim, Goal.sunbathe, Goal.read],
        'visionary' => const [Goal.swim, Goal.sunbathe, Goal.gym],
        'nightOwl' => const [Goal.read, Goal.read, Goal.cafe],
        'memeLord' => const [Goal.cafe, Goal.gym, Goal.swim],
        'socialButterfly' => const [Goal.cafe, Goal.sunbathe],
        'plantParent' => const [Goal.sunbathe, Goal.meditate],
        _ => const [Goal.cafe],
      };

  void _goLeisure(EmployeeRuntime e) {
    final options = _leisureFor(e.spec.personality);
    final pick = options[_rng.nextInt(options.length)];
    switch (pick) {
      case Goal.gym:
        final spot = _freeSpotFrom(workoutSpots);
        if (spot != null) {
          e.spotTarget = spot;
          _sendTo(e, spot, Goal.gym);
          return;
        }
      case Goal.swim:
        _sendTo(e, swimEntry, Goal.swim);
        return;
      case Goal.sunbathe:
        if (_trySeat(e, deckSeats, SeatKind.deck, Goal.sunbathe)) return;
      case Goal.meditate:
        if (_trySeat(e, cushionSeats, SeatKind.cushion, Goal.meditate)) {
          return;
        }
      case Goal.read:
        if (_rng.nextBool() &&
            _trySeat(e, readSeats, SeatKind.readChair, Goal.read)) {
          return;
        }
        final spot = _freeSpotFrom(readStandSpots);
        if (spot != null) {
          e.spotTarget = spot;
          _sendTo(e, spot, Goal.read);
          return;
        }
      case Goal.cafe:
        final spot = _freeSpotFrom(cafeSpots);
        if (spot != null) {
          e.spotTarget = spot;
          _sendTo(e, spot, Goal.cafe);
          return;
        }
      default:
        break;
    }
    // Favorite spot taken — stroll instead.
    _sendTo(e, wanderSpots[_rng.nextInt(wanderSpots.length)], Goal.wander);
  }

  Point<int>? _freeSpotFrom(List<Point<int>> spots) {
    final taken = employees.map((x) => x.spotTarget).whereType<Point<int>>();
    final free = spots.where((s) => !taken.contains(s)).toList();
    return free.isEmpty ? null : free[_rng.nextInt(free.length)];
  }

  void _freeSpot(EmployeeRuntime e) => e.spotTarget = null;

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
    _releaseSeat(e);
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

  /// Reserves a free seat in [seats] and walks there. Returns false if all
  /// seats are taken.
  bool _trySeat(
      EmployeeRuntime e, List<Seat> seats, SeatKind kind, Goal goal) {
    final taken = employees
        .where((x) => x.seatKind == kind)
        .map((x) => x.seatIndex)
        .toSet();
    final free = [
      for (var i = 0; i < seats.length; i++)
        if (!taken.contains(i)) i
    ];
    if (free.isEmpty) return false;
    final index = free[_rng.nextInt(free.length)];
    _sendTo(e, seats[index].approach, goal);
    // _sendTo releases seats, so claim after.
    e.seatKind = kind;
    e.seatIndex = index;
    return true;
  }

  Seat? _seatOf(EmployeeRuntime e) => switch (e.seatKind) {
        SeatKind.sofa => sofaSeats[e.seatIndex],
        SeatKind.deck => deckSeats[e.seatIndex],
        SeatKind.cushion => cushionSeats[e.seatIndex],
        SeatKind.readChair => readSeats[e.seatIndex],
        SeatKind.none => null,
      };

  void _releaseSeat(EmployeeRuntime e) {
    e.seatKind = SeatKind.none;
    e.seatIndex = -1;
  }

  void _sitDown(EmployeeRuntime e, Activity activity, double duration,
      String emote) {
    final seat = _seatOf(e);
    if (seat == null) {
      _adoptDefaultGoal(e);
      return;
    }
    e.pos = seat.seatPos;
    e.facing = Facing.down;
    e.activity = activity;
    e.activityTimer = duration;
    e.say(emote, 2.4);
  }

  void _arrive(EmployeeRuntime e) {
    final goal = e.goal;
    e.goal = Goal.none;
    switch (goal) {
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
        _sitDown(e, Activity.sofa, 8 + _rng.nextDouble() * 8, '😌');
      case Goal.sunbathe:
        _sitDown(e, Activity.sunbathe, 10 + _rng.nextDouble() * 8, '😎');
      case Goal.meditate:
        _sitDown(e, Activity.meditate, 10 + _rng.nextDouble() * 6, '🧘');
      case Goal.gym:
        e.activity = Activity.gym;
        e.facing = Facing.up;
        e.activityTimer = 9 + _rng.nextDouble() * 6;
        e.say('💪', 2);
      case Goal.swim:
        e.activity = Activity.swim;
        e.activityTimer = 12 + _rng.nextDouble() * 8;
        e.swimTarget = _randomSwimPoint();
        e.say('🏊', 2);
      case Goal.read:
        if (e.seatKind == SeatKind.readChair) {
          _sitDown(e, Activity.read, 9 + _rng.nextDouble() * 7, '📖');
        } else {
          e.activity = Activity.read;
          e.facing = Facing.up;
          e.activityTimer = 7 + _rng.nextDouble() * 6;
          e.say('📖', 2.4);
        }
      case Goal.cafe:
        e.activity = Activity.cafe;
        e.facing = _faceNearestCafeTable(e);
        e.activityTimer = 8 + _rng.nextDouble() * 6;
        e.say(_rng.nextBool() ? '☕' : '🍰', 2.4);
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
  }

  Facing _faceNearestCafeTable(EmployeeRuntime e) {
    const tables = [Point(17, 28), Point(22, 28), Point(19, 31)];
    final here = tileAt(e.pos);
    Point<int>? best;
    var bestD = 999;
    for (final t in tables) {
      final d = (t.x - here.x).abs() + (t.y - here.y).abs();
      if (d < bestD) {
        bestD = d;
        best = t;
      }
    }
    if (best == null) return Facing.down;
    final dx = best.x - here.x, dy = best.y - here.y;
    return dx.abs() > dy.abs()
        ? (dx > 0 ? Facing.right : Facing.left)
        : (dy > 0 ? Facing.down : Facing.up);
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
    _releaseSeat(e);
    _freeSpot(e);
    if (e.activity == Activity.chatting) _endChat(e);
  }

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
    _releaseSeat(e);
    _freeSpot(e);
    e.swimTarget = null;
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
    // espresso machine = break, sofa = nap, pool = an involuntary swim...
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

    if (isPoolTile(tile)) {
      e.pos = Offset(
        e.pos.dx.clamp(swimArea.left, swimArea.right),
        e.pos.dy.clamp(swimArea.top, swimArea.bottom),
      );
      e.activity = Activity.swim;
      e.activityTimer = 10 + _rng.nextDouble() * 6;
      e.swimTarget = _randomSwimPoint();
      e.say('💦!!', 2.4);
      notifyListeners();
      return;
    }

    final dropKind = dropTargetAt(tile);
    if (dropKind != null) {
      final (spot, activity, emote) = switch (dropKind) {
        DropKind.coffee => (coffeeSpot, Activity.coffee, '☕'),
        DropKind.water => (waterSpot, Activity.water, '💧'),
        DropKind.snack => (snackSpot, Activity.snack, '🍫'),
      };
      e.pos = tileCenter(spot);
      e.activity = activity;
      e.facing = Facing.up;
      e.activityTimer = 5 + _rng.nextDouble() * 3;
      e.say(emote, 2.4);
      notifyListeners();
      return;
    }

    for (final (seats, kind, activity, emote) in [
      (sofaSeats, SeatKind.sofa, Activity.sofa, '😌'),
      (deckSeats, SeatKind.deck, Activity.sunbathe, '😎'),
      (cushionSeats, SeatKind.cushion, Activity.meditate, '🧘'),
      (readSeats, SeatKind.readChair, Activity.read, '📖'),
    ]) {
      final index = seatIndexAt(seats, tile);
      if (index == null) continue;
      final taken = employees
          .any((x) => x != e && x.seatKind == kind && x.seatIndex == index);
      if (taken) break;
      e.seatKind = kind;
      e.seatIndex = index;
      e.pos = seats[index].seatPos;
      e.facing = Facing.down;
      e.activity = activity;
      e.activityTimer = 8 + _rng.nextDouble() * 8;
      e.say(emote, 2.4);
      notifyListeners();
      return;
    }

    final landing = nearestWalkable(tile);
    e.pos = tileCenter(landing);
    e.activity = Activity.stunned;
    e.activityTimer = 1.1 + _rng.nextDouble() * 0.5;
    e.facing = Facing.down;
    e.say('@_@', 1.4);
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
    _freeSpot(e);
    _sendTo(e, coffeeSpot, Goal.coffee);
    notifyListeners();
  }

  /// Sends the employee back to their desk right now (panel button).
  void commandWork(String id) {
    final e = byId(id);
    if (e == null || e.activity == Activity.dragged) return;
    if (e.activity == Activity.chatting) _endChat(e);
    _freeSpot(e);
    _sendToDesk(e);
    notifyListeners();
  }

  /// Sends the employee to the gym (panel button).
  void commandGym(String id) {
    final e = byId(id);
    if (e == null || e.activity == Activity.dragged) return;
    if (e.activity == Activity.chatting) _endChat(e);
    _freeSpot(e);
    final spot = _freeSpotFrom(workoutSpots) ?? workoutSpots.first;
    e.spotTarget = spot;
    _sendTo(e, spot, Goal.gym);
    notifyListeners();
  }

  /// Sends the employee for a swim (panel button).
  void commandPool(String id) {
    final e = byId(id);
    if (e == null || e.activity == Activity.dragged) return;
    if (e.activity == Activity.chatting) _endChat(e);
    _freeSpot(e);
    _sendTo(e, swimEntry, Goal.swim);
    notifyListeners();
  }

  /// Sends the employee to lounge on a sofa (panel button).
  void commandLounge(String id) {
    final e = byId(id);
    if (e == null || e.activity == Activity.dragged) return;
    if (e.activity == Activity.chatting) _endChat(e);
    _freeSpot(e);
    if (!_trySeat(e, sofaSeats, SeatKind.sofa, Goal.sofa)) {
      _sendTo(e, wanderSpots[_rng.nextInt(wanderSpots.length)], Goal.wander);
    }
    notifyListeners();
  }

  static const _praiseLines = ['❤️', '🥹', 'thank you!', '🙏', 'aw shucks'];
  static const _motivateLines = ['💪', '🔥', "let's go!", '⚡', 'on it!'];

  /// A morale boost: lifts social/energy, showers hearts and confetti.
  void commandPraise(String id) {
    final e = byId(id);
    if (e == null) return;
    e.social = (e.social + 0.3).clamp(0.0, 1.0);
    e.energy = (e.energy + 0.12).clamp(0.0, 1.0);
    e.say(_praiseLines[_rng.nextInt(_praiseLines.length)], 2.2);
    for (var i = 0; i < 3; i++) {
      floating(Offset(e.pos.dx + (i - 1) * 7, e.pos.dy - 16), '❤️',
          ttl: 1.5, color: const Color(0xFFE85C6A));
    }
    particles.confetti(Offset(e.pos.dx, e.pos.dy - 18), count: 12);
    notifyListeners();
  }

  /// An energy jolt: refills the battery and fires them up.
  void commandMotivate(String id) {
    final e = byId(id);
    if (e == null) return;
    e.energy = (e.energy + 0.35).clamp(0.0, 1.0);
    e.say(_motivateLines[_rng.nextInt(_motivateLines.length)], 2.0);
    floating(Offset(e.pos.dx, e.pos.dy - 16), '⚡',
        ttl: 1.3, color: const Color(0xFFFFD24A));
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
          Goal.coffee => 'Heading to the café',
          Goal.water => 'Off to the water cooler',
          Goal.snack => 'Raiding the snack corner',
          Goal.sofa => 'Going for a power nap',
          Goal.gym => 'Off to the gym',
          Goal.swim => 'Headed for the pool',
          Goal.sunbathe => 'Claiming a deck chair',
          Goal.read => 'Off to the library',
          Goal.meditate => 'Seeking inner peace',
          Goal.cafe => 'Grabbing a table at the café',
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
        return 'Recharging in the lounge';
      case Activity.gym:
        return 'Crushing a workout 💪';
      case Activity.swim:
        return 'Doing laps in the pool 🏊';
      case Activity.sunbathe:
        return 'Sunbathing by the pool 😎';
      case Activity.read:
        return 'Lost in a book 📖';
      case Activity.meditate:
        return 'Meditating in the Focus room 🧘';
      case Activity.cafe:
        return 'Espresso break at the café';
      case Activity.chatting:
        final partner = byId(e.chatPartnerId);
        return partner != null
            ? 'Chatting with ${partner.spec.name}'
            : 'Chatting';
      case Activity.wandering:
        return 'Wandering the campus';
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
        case Activity.gym:
        case Activity.swim:
        case Activity.sunbathe:
        case Activity.read:
        case Activity.meditate:
        case Activity.cafe:
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
      case Activity.sunbathe:
      case Activity.meditate:
      case Activity.cafe:
        return (CharFrame.sitFront, false);
      case Activity.read:
        return e.seatKind == SeatKind.readChair
            ? (CharFrame.sitFront, false)
            : (CharFrame.upIdle, false);
      case Activity.gym:
        // Jogging in place on the mats.
        final step = (e.animPhase * 6).floor() % 2 == 0;
        return (step ? CharFrame.upWalkA : CharFrame.upWalkB, false);
      case Activity.dragged:
        return (CharFrame.downWalkA, false); // legs dangling
      case Activity.swim:
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
}

String _ellipsize(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max - 1)}…';
