import 'dart:collection';
import 'dart:math';

import 'package:flutter/painting.dart';

import 'office_sprites.dart';
import 'pixel_art.dart';

/// Tile size in world pixels. The whole office is laid out on a tile grid
/// and rendered at an integer zoom for crisp pixels.
const tileSize = 16;

/// MindNoron Inc. headquarters: one open-plan floor.
/// 30x20 tiles = 480x320 world pixels.
const mapCols = 30;
const mapRows = 20;
const worldWidth = mapCols * tileSize; // 480
const worldHeight = mapRows * tileSize; // 320

/// A piece of furniture: anchor tile (top-left of footprint), footprint in
/// tiles, and the sprite (drawn bottom-aligned to the footprint, centered).
class OfficeObject {
  const OfficeObject(
    this.sprite, {
    required this.tx,
    required this.ty,
    required this.tw,
    required this.th,
    this.blocks = true,
    this.isDesk = false,
  });

  final PixelSprite sprite;
  final int tx, ty;
  final int tw, th;
  final bool blocks;
  final bool isDesk;

  /// World-pixel position of the sprite's top-left corner.
  Offset get drawOrigin => Offset(
        tx * tileSize + (tw * tileSize - sprite.width) / 2,
        (ty + th) * tileSize - sprite.height.toDouble(),
      );

  /// Y-sort key: things lower on screen draw later (in front).
  double get sortY => (ty + th) * tileSize.toDouble();
}

/// A desk an employee can claim. [seatTile] is where they path to; the
/// rendered seat position is centered under the desk.
class DeskSpot {
  const DeskSpot(this.index, this.tx, this.ty);
  final int index;
  final int tx, ty; // desk anchor (2 tiles wide)

  Point<int> get seatTile => Point(tx, ty + 1);

  /// Pixel position for the seated character's feet (desk-centered).
  Offset get seatPos => Offset(
        tx * tileSize + tileSize.toDouble(), // center between the 2 tiles
        (ty + 2) * tileSize - 3.0,
      );

  /// Screen region of this desk's monitor (for the flicker overlay).
  Rect get screenRect {
    final o = OfficeObject(deskSprite, tx: tx, ty: ty, tw: 2, th: 1)
        .drawOrigin;
    return Rect.fromLTWH(o.dx + 5, o.dy + 1, 10, 4);
  }
}

/// A two-person chat spot: where each stands and which way they face.
class ChatSpot {
  const ChatSpot(this.a, this.b, this.faceAxisX);
  final Point<int> a;
  final Point<int> b;

  /// true: A faces right & B faces left; false: A faces down & B faces up.
  final bool faceAxisX;
}

// ---------------------------------------------------------------------------
// Floor zones (painted by the static layer)
// ---------------------------------------------------------------------------

class FloorZone {
  const FloorZone(this.tiles, this.base, this.alt);
  final Rect tiles; // in tile units
  final Color base;
  final Color alt; // checker/dither accent
}

const floorBase = Color(0xFFD8D3CA);
const floorAlt = Color(0xFFCFC9BD);

const floorZones = <FloorZone>[
  // Desk-pod carpet
  FloorZone(Rect.fromLTRB(2, 3, 16, 14), Color(0xFF8C9CB4), Color(0xFF8294AE)),
  // Meeting rug
  FloorZone(Rect.fromLTRB(20, 2, 28, 8), Color(0xFF7FA083), Color(0xFF74987A)),
  // Kitchen tiles
  FloorZone(Rect.fromLTRB(1, 14, 10, 19), Color(0xFFE2DCCB), Color(0xFFD4CDB8)),
  // Lounge carpet
  FloorZone(
      Rect.fromLTRB(18, 13, 29, 19), Color(0xFFC4A488), Color(0xFFBA9A7E)),
];

const wallFace = Color(0xFFEFE9DD);
const wallTop = Color(0xFF3A3340);
const wallBase = Color(0xFFC9C0B2);

// ---------------------------------------------------------------------------
// Furniture layout
// ---------------------------------------------------------------------------

const officeDesks = <DeskSpot>[
  DeskSpot(0, 3, 4),
  DeskSpot(1, 7, 4),
  DeskSpot(2, 11, 4),
  DeskSpot(3, 3, 8),
  DeskSpot(4, 7, 8),
  DeskSpot(5, 11, 8),
  DeskSpot(6, 3, 12),
  DeskSpot(7, 11, 12),
];

final officeObjects = <OfficeObject>[
  // Desks (sprite is 2 tiles wide; chair + worker render under them)
  for (final d in officeDesks)
    OfficeObject(deskSprite, tx: d.tx, ty: d.ty, tw: 2, th: 1, isDesk: true),

  // Meeting corner
  OfficeObject(meetingTableSprite, tx: 22, ty: 4, tw: 3, th: 2),
  OfficeObject(plantSprite, tx: 28, ty: 2, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 20, ty: 2, tw: 1, th: 1),

  // Kitchen (bottom-left)
  OfficeObject(coffeeCounterSprite, tx: 2, ty: 15, tw: 2, th: 1),
  OfficeObject(waterCoolerSprite, tx: 5, ty: 15, tw: 1, th: 1),
  OfficeObject(vendingSprite, tx: 7, ty: 15, tw: 1, th: 1),

  // Lounge (bottom-right)
  OfficeObject(sofaSprite, tx: 20, ty: 15, tw: 2, th: 1),
  OfficeObject(loungeTableSprite, tx: 20, ty: 17, tw: 1, th: 1),
  OfficeObject(bookshelfSprite, tx: 24, ty: 15, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 27, ty: 17, tw: 1, th: 1),

  // Scattered life
  OfficeObject(printerSprite, tx: 16, ty: 8, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 1, ty: 2, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 16, ty: 12, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 12, ty: 18, tw: 1, th: 1),
  OfficeObject(paperStackSprite, tx: 17, ty: 2, tw: 1, th: 1),
];

/// Decor mounted on the top wall (drawn with the static layer, no collision).
/// Pairs of (sprite, top-left world offset).
final wallDecor = <(PixelSprite, Offset)>[
  (windowSprite, const Offset(4 * 16.0, 10)),
  (windowSprite, const Offset(8 * 16.0, 10)),
  (windowSprite, const Offset(12 * 16.0, 10)),
  (clockSprite, const Offset(17 * 16.0 + 3, 12)),
  (posterSprite, const Offset(19 * 16.0, 11)),
  (whiteboardSprite, const Offset(22 * 16.0, 9)),
  (windowSprite, const Offset(26 * 16.0, 10)),
];

// ---------------------------------------------------------------------------
// Points of interest
// ---------------------------------------------------------------------------

const coffeeSpot = Point<int>(2, 16); // stand here, face up
const vendingSpot = Point<int>(7, 16);
const printerSpot = Point<int>(16, 9);

/// Sofa: path to the approach tile, then snap onto the seat pixel position.
/// Seat y sits 1px past the sofa's footprint bottom so seated characters
/// y-sort in front of the sofa sprite instead of hiding behind it.
const sofaApproach = [Point<int>(20, 16), Point<int>(21, 16)];
final sofaSeatPos = [
  const Offset(20 * 16.0 + 8, 16 * 16.0 + 1),
  const Offset(21 * 16.0 + 8, 16 * 16.0 + 1),
];

/// Spots where two employees can stop and chat face-to-face.
const chatSpots = <ChatSpot>[
  ChatSpot(Point(4, 16), Point(6, 16), true), // water cooler
  ChatSpot(Point(22, 3), Point(22, 6), false), // across the meeting table
  ChatSpot(Point(25, 3), Point(25, 6), false),
  ChatSpot(Point(18, 15), Point(18, 17), false), // lounge corner
  ChatSpot(Point(13, 15), Point(15, 15), true), // hallway
];

/// Idle stroll destinations (visit a plant, the printer, a window...).
const wanderSpots = <Point<int>>[
  Point(16, 9),
  Point(1, 3),
  Point(28, 3),
  Point(17, 3),
  Point(5, 14),
  Point(26, 13),
  Point(14, 17),
  Point(22, 6),
  Point(9, 14),
];

// ---------------------------------------------------------------------------
// Collision + pathfinding
// ---------------------------------------------------------------------------

final List<List<bool>> _walkable = _buildWalkable();

List<List<bool>> _buildWalkable() {
  final grid = List.generate(mapRows, (_) => List.filled(mapCols, true));
  // Outer walls: 2-tile-tall top wall band, 1-tile border elsewhere.
  for (var x = 0; x < mapCols; x++) {
    grid[0][x] = false;
    grid[1][x] = false;
    grid[mapRows - 1][x] = false;
  }
  for (var y = 0; y < mapRows; y++) {
    grid[y][0] = false;
    grid[y][mapCols - 1] = false;
  }
  for (final o in officeObjects) {
    if (!o.blocks) continue;
    for (var dy = 0; dy < o.th; dy++) {
      for (var dx = 0; dx < o.tw; dx++) {
        final x = o.tx + dx, y = o.ty + dy;
        if (y >= 0 && y < mapRows && x >= 0 && x < mapCols) {
          grid[y][x] = false;
        }
      }
    }
  }
  return grid;
}

bool isWalkable(int x, int y) =>
    x >= 0 && x < mapCols && y >= 0 && y < mapRows && _walkable[y][x];

/// Nearest walkable tile to [target] (BFS ring search) — used when the user
/// drops an employee onto furniture.
Point<int> nearestWalkable(Point<int> target) {
  if (isWalkable(target.x, target.y)) return target;
  final seen = <Point<int>>{target};
  final queue = Queue<Point<int>>()..add(target);
  while (queue.isNotEmpty) {
    final p = queue.removeFirst();
    for (final n in [
      Point(p.x + 1, p.y),
      Point(p.x - 1, p.y),
      Point(p.x, p.y + 1),
      Point(p.x, p.y - 1),
    ]) {
      if (n.x < 0 || n.x >= mapCols || n.y < 0 || n.y >= mapRows) continue;
      if (!seen.add(n)) continue;
      if (isWalkable(n.x, n.y)) return n;
      queue.add(n);
    }
  }
  return const Point(15, 10); // center fallback — never expected
}

/// Breadth-first path on the tile grid (4-directional). Returns the list of
/// tiles from start (exclusive) to goal (inclusive), or null if unreachable.
List<Point<int>>? findPath(Point<int> start, Point<int> goal) {
  if (!isWalkable(goal.x, goal.y)) return null;
  if (start == goal) return [];
  final cameFrom = <Point<int>, Point<int>>{};
  final visited = <Point<int>>{start};
  final queue = Queue<Point<int>>()..add(start);
  while (queue.isNotEmpty) {
    final p = queue.removeFirst();
    for (final n in [
      Point(p.x, p.y - 1),
      Point(p.x - 1, p.y),
      Point(p.x + 1, p.y),
      Point(p.x, p.y + 1),
    ]) {
      if (!isWalkable(n.x, n.y) || visited.contains(n)) continue;
      visited.add(n);
      cameFrom[n] = p;
      if (n == goal) {
        final path = <Point<int>>[n];
        var cur = n;
        while (cameFrom[cur] != start) {
          cur = cameFrom[cur]!;
          path.add(cur);
        }
        return path.reversed.toList();
      }
      queue.add(n);
    }
  }
  return null;
}

/// World-pixel center of a tile.
Offset tileCenter(Point<int> t) => Offset(
      t.x * tileSize + tileSize / 2,
      t.y * tileSize + tileSize / 2,
    );

/// Tile containing a world-pixel point (clamped to the grid).
Point<int> tileAt(Offset world) => Point(
      (world.dx / tileSize).floor().clamp(0, mapCols - 1),
      (world.dy / tileSize).floor().clamp(0, mapRows - 1),
    );
