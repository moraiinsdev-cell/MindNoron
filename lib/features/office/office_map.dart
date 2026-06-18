import 'dart:collection';
import 'dart:math';

import 'package:flutter/painting.dart';

import 'office_sprites.dart';
import 'pixel_art.dart';

/// Tile size in world pixels. The whole campus is laid out on a tile grid
/// and rendered at a zoom that fills the canvas.
const tileSize = 16;

/// MindNoron Campus: one indoor floor with a themed room per app module
/// (Tasks, Calendar, Finance, Focus, Library, Inbox, Gym, Café, Analytics,
/// Lounge) plus an outdoor garden with a swimming pool.
/// 56x36 tiles = 896x576 world pixels.
const mapCols = 56;
const mapRows = 36;
const worldWidth = mapCols * tileSize; // 896
const worldHeight = mapRows * tileSize; // 576

/// Front door: new hires walk in here; it is also the pathfinding anchor
/// the reachability tests use.
const doorTile = Point<int>(27, 34);

/// Indoor/outdoor divider column (with two door gaps).
const _dividerCol = 38;

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
}

/// A sittable spot: walk to [approach], then snap to [seatPos]. [tile] is
/// what the user has to drop an employee onto.
class Seat {
  const Seat(this.tile, this.approach, this.seatPos);
  final Point<int> tile;
  final Point<int> approach;
  final Offset seatPos;
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
// Rooms (floor colors + painted labels)
// ---------------------------------------------------------------------------

class Room {
  const Room(this.label, this.tiles, this.base, this.alt);
  final String label;
  final Rect tiles; // in tile units
  final Color base;
  final Color alt; // checker accent
}

const floorBase = Color(0xFFD8D3CA);
const floorAlt = Color(0xFFCFC9BD);

const _baseRooms = <Room>[
  Room('TASKS', Rect.fromLTRB(2, 3, 17, 15), Color(0xFF8C9CB4),
      Color(0xFF8294AE)),
  Room('ANALYTICS', Rect.fromLTRB(18, 2, 24, 7), Color(0xFFA8B0B8),
      Color(0xFF9CA6B0)),
  Room('CALENDAR', Rect.fromLTRB(25, 2, 38, 9), Color(0xFF7FA083),
      Color(0xFF74987A)),
  Room('FINANCE', Rect.fromLTRB(29, 10, 38, 18), Color(0xFFDECDA0),
      Color(0xFFD4C290)),
  Room('FOCUS', Rect.fromLTRB(2, 15, 10, 22), Color(0xFFB8AECE),
      Color(0xFFAEA2C6)),
  Room('LIBRARY', Rect.fromLTRB(12, 15, 20, 22), Color(0xFFC2A582),
      Color(0xFFB89B76)),
  Room('INBOX', Rect.fromLTRB(22, 15, 27, 21), Color(0xFFA9B4AE),
      Color(0xFF9EAAA3)),
  Room('LOUNGE', Rect.fromLTRB(29, 19, 38, 26), Color(0xFFC4A488),
      Color(0xFFBA9A7E)),
  Room('GYM', Rect.fromLTRB(2, 22, 13, 35), Color(0xFF707684),
      Color(0xFF666C7A)),
  Room('CAFÉ', Rect.fromLTRB(15, 24, 27, 35), Color(0xFFE2DCCB),
      Color(0xFFD4CDB8)),
  Room('POOL', Rect.fromLTRB(39, 2, 55, 35), Color(0xFF8FBE7A),
      Color(0xFF85B470)),
  // Entertainment wing carved out of the south garden (drawn after POOL so
  // their floors override the grass). Open-plan, like the other modules.
  Room('ARCADE', Rect.fromLTRB(39, 22, 55, 28), Color(0xFF3A3550),
      Color(0xFF332E48)),
  Room('CINEMA', Rect.fromLTRB(39, 28, 48, 35), Color(0xFF4A2F3A),
      Color(0xFF422833)),
  Room('BAR', Rect.fromLTRB(48, 28, 55, 35), Color(0xFF6E5440),
      Color(0xFF644A38)),
];

// ---------------------------------------------------------------------------
// Per-floor theming
// ---------------------------------------------------------------------------
// Floors share the building shell but each gets its own colour wash and room
// names so they read as distinct departments. (Giving each floor a genuinely
// different room *layout* is a larger follow-up.)

/// Which floor the map currently represents. Set by the office screen before
/// painting; defaults to the ground floor so everything else (and the tests)
/// see the original campus.
int activeFloor = 0;

void setActiveFloor(int f) {
  activeFloor = f.clamp(0, _floorRoomLabels.length - 1);
}

/// Accent each floor's rooms are tinted toward (null = ground floor as-is).
const _floorRoomAccent = <Color?>[
  null, // Operations
  Color(0xFF4A6CC0), // Engineering — cool blue
  Color(0xFFC0894A), // Creative Studio — warm amber
  Color(0xFF3FA56E), // Wellness — green
  Color(0xFF8A5BC0), // Sky Lounge — violet
];

/// Per-floor room renames (base label → themed label).
const _floorRoomLabels = <Map<String, String>>[
  <String, String>{}, // Operations: original names
  {
    'TASKS': 'DEV BAYS',
    'ANALYTICS': 'DATA',
    'CALENDAR': 'STAND-UP',
    'FINANCE': 'BUDGET',
    'FOCUS': 'DEEP WORK',
    'LIBRARY': 'DOCS',
    'INBOX': 'TICKETS',
    'LOUNGE': 'BREAKOUT',
    'CAFÉ': 'CANTEEN',
    'ARCADE': 'GAME RM',
    'CINEMA': 'DEMOS',
    'BAR': 'TAPROOM',
  },
  {
    'TASKS': 'STUDIO',
    'ANALYTICS': 'RENDER',
    'CALENDAR': 'PITCH',
    'FINANCE': 'GRANTS',
    'FOCUS': 'QUIET',
    'LIBRARY': 'ARCHIVE',
    'INBOX': 'BRIEFS',
    'CINEMA': 'SCREENING',
  },
  {
    'TASKS': 'STUDIO',
    'ANALYTICS': 'VITALS',
    'CALENDAR': 'CLASSES',
    'FINANCE': 'SPA',
    'FOCUS': 'ZEN',
    'LIBRARY': 'SAUNA',
    'INBOX': 'TOWELS',
    'LOUNGE': 'RELAX',
    'CAFÉ': 'JUICE BAR',
    'ARCADE': 'STEAM RM',
    'CINEMA': 'YOGA',
    'BAR': 'SMOOTHIES',
  },
  {
    'TASKS': 'VIP DESKS',
    'ANALYTICS': 'DJ BOOTH',
    'CALENDAR': 'EVENTS',
    'FINANCE': 'VAULT',
    'FOCUS': 'CIGAR RM',
    'LIBRARY': 'WHISKY',
    'INBOX': 'COAT RM',
    'LOUNGE': 'SKY LOUNGE',
    'CAFÉ': 'KITCHEN',
    'ARCADE': 'CASINO',
    'CINEMA': 'THEATRE',
    'BAR': 'SKYBAR',
  },
];

Color _shiftRoom(Color c, Color accent) => Color.lerp(c, accent, 0.30)!;

/// The rooms for the currently-active floor: same rects, themed colours/labels.
List<Room> get rooms {
  final f = activeFloor.clamp(0, _floorRoomLabels.length - 1);
  final accent = _floorRoomAccent[f];
  if (accent == null) return _baseRooms;
  final labels = _floorRoomLabels[f];
  return [
    for (final r in _baseRooms)
      Room(labels[r.label] ?? r.label, r.tiles, _shiftRoom(r.base, accent),
          _shiftRoom(r.alt, accent)),
  ];
}

/// Swimming pool water (tiles, exclusive right/bottom).
const poolTiles = Rect.fromLTRB(42, 6, 52, 15);

/// Where swimmers paddle around, in world pixels (inset from the coping).
final swimArea = Rect.fromLTRB(
  poolTiles.left * 16 + 8,
  poolTiles.top * 16 + 8,
  poolTiles.right * 16 - 8,
  poolTiles.bottom * 16 - 8,
);

/// Walk here to hop in or out of the pool.
const swimEntry = Point<int>(41, 10);

const wallFace = Color(0xFFEFE9DD);
const wallTop = Color(0xFF3A3340);
const wallBase = Color(0xFFC9C0B2);

// ---------------------------------------------------------------------------
// Interior walls
// ---------------------------------------------------------------------------

/// Blocked + painted as partitions. Horizontal segments read as low walls.
final Set<Point<int>> interiorWallTiles = _buildInteriorWalls();

Set<Point<int>> _buildInteriorWalls() {
  final walls = <Point<int>>{};
  void run(int x0, int y0, int x1, int y1, Set<Point<int>> skip) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final p = Point(x, y);
        if (!skip.contains(p)) walls.add(p);
      }
    }
  }

  // Indoor/outdoor divider, gaps at rows 8-9 and 26-27.
  run(_dividerCol, 2, _dividerCol, 34, {
    const Point(_dividerCol, 8),
    const Point(_dividerCol, 9),
    const Point(_dividerCol, 26),
    const Point(_dividerCol, 27),
  });
  // Finance vault: top, bottom, and a left wall with a door gap.
  run(29, 10, 37, 10, const {});
  run(29, 17, 37, 17, const {});
  run(28, 10, 28, 17, {const Point(28, 13), const Point(28, 14)});
  // Focus room: top wall with door, right wall.
  run(2, 15, 9, 15, {const Point(5, 15), const Point(6, 15)});
  run(10, 15, 10, 21, const {});
  // Gym: top wall with a door near the corridor.
  run(2, 22, 12, 22, {const Point(11, 22), const Point(12, 22)});

  // --- Department partitions (gaps are doorways) --------------------------
  // TASKS: right wall onto the central corridor.
  run(17, 3, 17, 14, {const Point(17, 8), const Point(17, 9)});
  // ANALYTICS | CALENDAR divider.
  run(24, 2, 24, 7, {const Point(24, 4), const Point(24, 5)});
  // LIBRARY: right wall onto the corridor.
  run(20, 15, 20, 21, {const Point(20, 18), const Point(20, 19)});
  // CAFÉ: top wall under the corridor.
  run(15, 23, 26, 23, {const Point(20, 23), const Point(21, 23)});

  // --- Entertainment wing walls ------------------------------------------
  // North wall separating the sun deck from the arcade.
  run(39, 21, 54, 21, {const Point(45, 21), const Point(46, 21)});
  // Wall between the arcade and the cinema/bar below.
  run(39, 28, 54, 28, {
    const Point(43, 28),
    const Point(44, 28),
    const Point(51, 28),
    const Point(52, 28),
  });
  // Cinema | bar divider.
  run(48, 29, 48, 34, {const Point(48, 32), const Point(48, 33)});
  return walls;
}

// ---------------------------------------------------------------------------
// Furniture layout
// ---------------------------------------------------------------------------

// The claimable desks in the TASKS bullpen vary per floor: work floors keep a
// full bullpen, leisure floors thin it right down (those staff lounge instead).
const _floor0Desks = <DeskSpot>[
  DeskSpot(0, 3, 4),
  DeskSpot(1, 7, 4),
  DeskSpot(2, 11, 4),
  DeskSpot(3, 14, 4),
  DeskSpot(4, 3, 8),
  DeskSpot(5, 7, 8),
  DeskSpot(6, 11, 8),
  DeskSpot(7, 3, 12),
  DeskSpot(8, 7, 12),
  DeskSpot(9, 11, 12),
  DeskSpot(10, 14, 8),
  DeskSpot(11, 14, 12),
];

// Creative: a smaller studio bullpen.
const _floor2Desks = <DeskSpot>[
  DeskSpot(0, 3, 4),
  DeskSpot(1, 7, 4),
  DeskSpot(2, 11, 4),
  DeskSpot(3, 14, 4),
  DeskSpot(4, 3, 8),
  DeskSpot(5, 7, 8),
];

// Wellness: just a reception desk or two.
const _floor3Desks = <DeskSpot>[
  DeskSpot(0, 14, 4),
  DeskSpot(1, 14, 8),
];

// Sky Lounge: a few VIP desks.
const _floor4Desks = <DeskSpot>[
  DeskSpot(0, 3, 4),
  DeskSpot(1, 7, 4),
  DeskSpot(2, 11, 4),
];

const _floorDesks = <List<DeskSpot>>[
  _floor0Desks, // Operations
  _floor0Desks, // Engineering — also a full bullpen
  _floor2Desks, // Creative Studio
  _floor3Desks, // Wellness
  _floor4Desks, // Sky Lounge
];

List<DeskSpot> get officeDesks =>
    _floorDesks[activeFloor.clamp(0, _floorDesks.length - 1)];

// Furniture that fills the TASKS bullpen *beyond* the desks, themed per floor.
// (Floor 0 leaves it to the desks.) These sit in the bullpen interior, which is
// free of shared activity spots, so they never trap the simulation.
final _floor1Tasks = <OfficeObject>[
  // Engineering: a server farm threaded between the desk rows.
  OfficeObject(serverRackSprite, tx: 3, ty: 6, tw: 1, th: 1),
  OfficeObject(serverRackSprite, tx: 7, ty: 6, tw: 1, th: 1),
  OfficeObject(serverRackSprite, tx: 11, ty: 6, tw: 1, th: 1),
  OfficeObject(serverRackSprite, tx: 3, ty: 10, tw: 1, th: 1),
  OfficeObject(serverRackSprite, tx: 7, ty: 10, tw: 1, th: 1),
  OfficeObject(serverRackSprite, tx: 11, ty: 10, tw: 1, th: 1),
  OfficeObject(filingCabinetSprite, tx: 16, ty: 6, tw: 1, th: 1),
  OfficeObject(filingCabinetSprite, tx: 16, ty: 10, tw: 1, th: 1),
];
final _floor2Tasks = <OfficeObject>[
  // Creative: drafting nooks + a small library where the back desks were.
  OfficeObject(bookshelfSprite, tx: 3, ty: 12, tw: 1, th: 1),
  OfficeObject(bookshelfSprite, tx: 4, ty: 12, tw: 1, th: 1),
  OfficeObject(loungeTableSprite, tx: 7, ty: 12, tw: 1, th: 1),
  OfficeObject(armchairSprite, tx: 9, ty: 12, tw: 1, th: 1),
  OfficeObject(paperStackSprite, tx: 11, ty: 12, tw: 1, th: 1),
  OfficeObject(bonsaiSprite, tx: 14, ty: 12, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 16, ty: 11, tw: 1, th: 1),
];
final _floor3Tasks = <OfficeObject>[
  // Wellness: a studio of treadmills, weights and greenery.
  OfficeObject(treadmillSprite, tx: 3, ty: 4, tw: 1, th: 2),
  OfficeObject(treadmillSprite, tx: 7, ty: 4, tw: 1, th: 2),
  OfficeObject(treadmillSprite, tx: 11, ty: 4, tw: 1, th: 2),
  OfficeObject(dumbbellRackSprite, tx: 3, ty: 8, tw: 1, th: 1),
  OfficeObject(dumbbellRackSprite, tx: 7, ty: 8, tw: 1, th: 1),
  OfficeObject(dumbbellRackSprite, tx: 11, ty: 8, tw: 1, th: 1),
  OfficeObject(bonsaiSprite, tx: 3, ty: 12, tw: 1, th: 1),
  OfficeObject(bonsaiSprite, tx: 7, ty: 12, tw: 1, th: 1),
  OfficeObject(bonsaiSprite, tx: 11, ty: 12, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 9, ty: 6, tw: 1, th: 1),
];
final _floor4Tasks = <OfficeObject>[
  // Sky Lounge: VIP sofas, a bar and arcades where the bullpen was.
  OfficeObject(sofaSprite, tx: 3, ty: 8, tw: 2, th: 1),
  OfficeObject(sofaSprite, tx: 7, ty: 8, tw: 2, th: 1),
  OfficeObject(armchairSprite, tx: 11, ty: 8, tw: 1, th: 1),
  OfficeObject(barCounterSprite, tx: 3, ty: 12, tw: 2, th: 1),
  OfficeObject(arcadeCabinetSprite, tx: 7, ty: 12, tw: 1, th: 1),
  OfficeObject(jukeboxSprite, tx: 9, ty: 12, tw: 1, th: 1),
  OfficeObject(cafeTableSprite, tx: 12, ty: 12, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 15, ty: 8, tw: 1, th: 1),
];

const _noTasks = <OfficeObject>[];
final _floorTasks = <List<OfficeObject>>[
  _noTasks,
  _floor1Tasks,
  _floor2Tasks,
  _floor3Tasks,
  _floor4Tasks,
];

/// Furniture shared by every floor: the spot-anchored pieces (so the
/// simulation's seats/spots always line up) plus the rooftop garden.
final _sharedObjects = <OfficeObject>[
  // ANALYTICS: server racks + storage.
  OfficeObject(serverRackSprite, tx: 18, ty: 2, tw: 1, th: 1),
  OfficeObject(serverRackSprite, tx: 19, ty: 2, tw: 1, th: 1),
  OfficeObject(serverRackSprite, tx: 20, ty: 2, tw: 1, th: 1),
  OfficeObject(filingCabinetSprite, tx: 22, ty: 2, tw: 1, th: 1),
  OfficeObject(printerSprite, tx: 22, ty: 5, tw: 1, th: 1),

  // CALENDAR: the meeting corner.
  OfficeObject(meetingTableSprite, tx: 29, ty: 4, tw: 3, th: 2),
  OfficeObject(plantSprite, tx: 25, ty: 2, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 36, ty: 2, tw: 1, th: 1),
  OfficeObject(paperStackSprite, tx: 34, ty: 6, tw: 1, th: 1),

  // FINANCE: the vault.
  OfficeObject(safeSprite, tx: 36, ty: 11, tw: 1, th: 1),
  OfficeObject(filingCabinetSprite, tx: 29, ty: 11, tw: 1, th: 1),
  OfficeObject(filingCabinetSprite, tx: 30, ty: 11, tw: 1, th: 1),
  OfficeObject(deskSprite, tx: 32, ty: 14, tw: 2, th: 1, isDesk: true),

  // FOCUS: quiet room.
  OfficeObject(bonsaiSprite, tx: 8, ty: 16, tw: 1, th: 1),
  OfficeObject(lampSprite, tx: 2, ty: 16, tw: 1, th: 1),

  // LIBRARY: a wall of books + a reading nook.
  OfficeObject(bookshelfSprite, tx: 12, ty: 16, tw: 1, th: 1),
  OfficeObject(bookshelfSprite, tx: 13, ty: 16, tw: 1, th: 1),
  OfficeObject(bookshelfSprite, tx: 15, ty: 16, tw: 1, th: 1),
  OfficeObject(bookshelfSprite, tx: 16, ty: 16, tw: 1, th: 1),
  OfficeObject(lampSprite, tx: 19, ty: 16, tw: 1, th: 1),
  OfficeObject(armchairSprite, tx: 13, ty: 19, tw: 1, th: 1),
  OfficeObject(loungeTableSprite, tx: 15, ty: 19, tw: 1, th: 1),

  // INBOX: the mailroom.
  OfficeObject(mailShelfSprite, tx: 22, ty: 16, tw: 1, th: 1),
  OfficeObject(mailShelfSprite, tx: 23, ty: 16, tw: 1, th: 1),
  OfficeObject(boxSprite, tx: 26, ty: 16, tw: 1, th: 1),
  OfficeObject(boxSprite, tx: 26, ty: 17, tw: 1, th: 1),
  OfficeObject(loungeTableSprite, tx: 24, ty: 19, tw: 1, th: 1),

  // LOUNGE: conversation pit.
  OfficeObject(sofaSprite, tx: 31, ty: 20, tw: 2, th: 1),
  OfficeObject(sofaSprite, tx: 35, ty: 20, tw: 2, th: 1),
  OfficeObject(loungeTableSprite, tx: 33, ty: 22, tw: 1, th: 1),
  OfficeObject(armchairSprite, tx: 30, ty: 22, tw: 1, th: 1),
  OfficeObject(armchairSprite, tx: 36, ty: 22, tw: 1, th: 1),
  OfficeObject(bookshelfSprite, tx: 37, ty: 19, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 29, ty: 25, tw: 1, th: 1),

  // GYM: iron paradise.
  OfficeObject(treadmillSprite, tx: 3, ty: 24, tw: 1, th: 2),
  OfficeObject(treadmillSprite, tx: 6, ty: 24, tw: 1, th: 2),
  OfficeObject(dumbbellRackSprite, tx: 10, ty: 24, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 2, ty: 32, tw: 1, th: 1),
  OfficeObject(waterCoolerSprite, tx: 10, ty: 32, tw: 1, th: 1),

  // CAFÉ: counter wall + seating.
  OfficeObject(coffeeCounterSprite, tx: 15, ty: 24, tw: 2, th: 1),
  OfficeObject(fridgeSprite, tx: 18, ty: 24, tw: 1, th: 1),
  OfficeObject(waterCoolerSprite, tx: 20, ty: 24, tw: 1, th: 1),
  OfficeObject(menuBoardSprite, tx: 22, ty: 24, tw: 1, th: 1),
  OfficeObject(vendingSprite, tx: 26, ty: 24, tw: 1, th: 1),
  OfficeObject(cafeTableSprite, tx: 17, ty: 28, tw: 1, th: 1),
  OfficeObject(cafeTableSprite, tx: 22, ty: 28, tw: 1, th: 1),
  OfficeObject(cafeTableSprite, tx: 19, ty: 31, tw: 1, th: 1),
  OfficeObject(kitchenTableSprite, tx: 24, ty: 32, tw: 2, th: 1),
  OfficeObject(plantSprite, tx: 15, ty: 33, tw: 1, th: 1),

  // Entrance hall / reception.
  OfficeObject(deskSprite, tx: 30, ty: 31, tw: 2, th: 1, isDesk: true),
  OfficeObject(plantSprite, tx: 29, ty: 28, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 37, ty: 33, tw: 1, th: 1),
  OfficeObject(boxSprite, tx: 37, ty: 28, tw: 1, th: 1),

  // Corridor greenery & clutter.
  OfficeObject(plantSprite, tx: 1, ty: 2, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 27, ty: 2, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 18, ty: 12, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 21, ty: 22, tw: 1, th: 1),
];

/// The poolside sun deck + north-garden greenery. Shared by every floor (it
/// anchors the deck loungers/swim spots and reads as the building's terrace).
final _deckGarden = <OfficeObject>[
  OfficeObject(loungerSprite, tx: 43, ty: 16, tw: 1, th: 2),
  OfficeObject(loungerSprite, tx: 46, ty: 16, tw: 1, th: 2),
  OfficeObject(loungerSprite, tx: 49, ty: 16, tw: 1, th: 2),
  OfficeObject(umbrellaSprite, tx: 52, ty: 16, tw: 1, th: 2),
  OfficeObject(plantSprite, tx: 40, ty: 2, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 53, ty: 2, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 53, ty: 22, tw: 1, th: 1),
];

// The entertainment wing (ARCADE / CINEMA / BAR rooms, rows 22-34) is themed
// per floor. Pieces avoid the shared garden wander/chat spots.
final _floor0Ent = <OfficeObject>[
  OfficeObject(arcadeCabinetSprite, tx: 40, ty: 23, tw: 1, th: 1),
  OfficeObject(arcadeCabinetSprite, tx: 42, ty: 23, tw: 1, th: 1),
  OfficeObject(arcadeCabinetSprite, tx: 44, ty: 23, tw: 1, th: 1),
  OfficeObject(jukeboxSprite, tx: 46, ty: 23, tw: 1, th: 1),
  OfficeObject(poolTableSprite, tx: 49, ty: 24, tw: 2, th: 1),
  OfficeObject(plantSprite, tx: 53, ty: 23, tw: 1, th: 1),
  OfficeObject(tvScreenSprite, tx: 41, ty: 29, tw: 2, th: 1),
  OfficeObject(sofaSprite, tx: 41, ty: 32, tw: 2, th: 1),
  OfficeObject(sofaSprite, tx: 44, ty: 32, tw: 2, th: 1),
  OfficeObject(barCounterSprite, tx: 49, ty: 29, tw: 2, th: 1),
  OfficeObject(cafeTableSprite, tx: 49, ty: 32, tw: 1, th: 1),
  OfficeObject(cafeTableSprite, tx: 52, ty: 32, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 53, ty: 30, tw: 1, th: 1),
];
// Engineering: a LAN/demo zone — arcades, a pool table and server racks.
final _floor1Ent = <OfficeObject>[
  OfficeObject(arcadeCabinetSprite, tx: 40, ty: 23, tw: 1, th: 1),
  OfficeObject(arcadeCabinetSprite, tx: 42, ty: 23, tw: 1, th: 1),
  OfficeObject(poolTableSprite, tx: 49, ty: 24, tw: 2, th: 1),
  OfficeObject(serverRackSprite, tx: 44, ty: 23, tw: 1, th: 1),
  OfficeObject(serverRackSprite, tx: 46, ty: 23, tw: 1, th: 1),
  OfficeObject(tvScreenSprite, tx: 41, ty: 29, tw: 2, th: 1),
  OfficeObject(sofaSprite, tx: 41, ty: 32, tw: 2, th: 1),
  OfficeObject(serverRackSprite, tx: 45, ty: 32, tw: 1, th: 1),
  OfficeObject(barCounterSprite, tx: 49, ty: 29, tw: 2, th: 1),
  OfficeObject(cafeTableSprite, tx: 52, ty: 32, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 53, ty: 23, tw: 1, th: 1),
];
// Creative: a sculpture garden + screening room + bar.
final _floor2Ent = <OfficeObject>[
  OfficeObject(bonsaiSprite, tx: 40, ty: 23, tw: 1, th: 1),
  OfficeObject(bonsaiSprite, tx: 43, ty: 23, tw: 1, th: 1),
  OfficeObject(paperStackSprite, tx: 46, ty: 23, tw: 1, th: 1),
  OfficeObject(bookshelfSprite, tx: 49, ty: 24, tw: 1, th: 1),
  OfficeObject(bookshelfSprite, tx: 50, ty: 24, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 53, ty: 23, tw: 1, th: 1),
  OfficeObject(tvScreenSprite, tx: 41, ty: 29, tw: 2, th: 1),
  OfficeObject(sofaSprite, tx: 41, ty: 32, tw: 2, th: 1),
  OfficeObject(armchairSprite, tx: 45, ty: 32, tw: 1, th: 1),
  OfficeObject(barCounterSprite, tx: 49, ty: 29, tw: 2, th: 1),
  OfficeObject(cafeTableSprite, tx: 52, ty: 32, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 53, ty: 30, tw: 1, th: 1),
];
// Wellness: a steam-room/yoga/smoothie spa — greenery and loungers.
final _floor3Ent = <OfficeObject>[
  OfficeObject(bonsaiSprite, tx: 40, ty: 23, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 42, ty: 23, tw: 1, th: 1),
  OfficeObject(bonsaiSprite, tx: 44, ty: 23, tw: 1, th: 1),
  OfficeObject(loungerSprite, tx: 49, ty: 23, tw: 1, th: 2),
  OfficeObject(loungerSprite, tx: 51, ty: 23, tw: 1, th: 2),
  OfficeObject(plantSprite, tx: 53, ty: 23, tw: 1, th: 1),
  OfficeObject(bonsaiSprite, tx: 41, ty: 29, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 44, ty: 29, tw: 1, th: 1),
  OfficeObject(loungerSprite, tx: 41, ty: 32, tw: 1, th: 2),
  OfficeObject(barCounterSprite, tx: 49, ty: 29, tw: 2, th: 1),
  OfficeObject(cafeTableSprite, tx: 52, ty: 32, tw: 1, th: 1),
  OfficeObject(plantSprite, tx: 53, ty: 30, tw: 1, th: 1),
];
// Sky Lounge: a casino/theatre/skybar — arcades, screens, bars everywhere.
final _floor4Ent = <OfficeObject>[
  OfficeObject(arcadeCabinetSprite, tx: 40, ty: 23, tw: 1, th: 1),
  OfficeObject(arcadeCabinetSprite, tx: 42, ty: 23, tw: 1, th: 1),
  OfficeObject(arcadeCabinetSprite, tx: 44, ty: 23, tw: 1, th: 1),
  OfficeObject(jukeboxSprite, tx: 46, ty: 23, tw: 1, th: 1),
  OfficeObject(poolTableSprite, tx: 49, ty: 24, tw: 2, th: 1),
  OfficeObject(barCounterSprite, tx: 52, ty: 23, tw: 2, th: 1),
  OfficeObject(tvScreenSprite, tx: 41, ty: 29, tw: 2, th: 1),
  OfficeObject(sofaSprite, tx: 41, ty: 32, tw: 2, th: 1),
  OfficeObject(sofaSprite, tx: 44, ty: 32, tw: 2, th: 1),
  OfficeObject(barCounterSprite, tx: 49, ty: 29, tw: 2, th: 1),
  OfficeObject(cafeTableSprite, tx: 49, ty: 32, tw: 1, th: 1),
  OfficeObject(cafeTableSprite, tx: 52, ty: 32, tw: 1, th: 1),
];
final _floorEnt = <List<OfficeObject>>[
  _floor0Ent,
  _floor1Ent,
  _floor2Ent,
  _floor3Ent,
  _floor4Ent,
];

/// All furniture for floor [f]: its desks, its themed bullpen fill, the shared
/// left-side spot anchors + deck, then the floor's entertainment wing.
List<OfficeObject> _objectsForFloor(int f) => [
      for (final d in _floorDesks[f])
        OfficeObject(deskSprite, tx: d.tx, ty: d.ty, tw: 2, th: 1, isDesk: true),
      ..._floorTasks[f],
      ..._sharedObjects,
      ..._deckGarden,
      ..._floorEnt[f],
    ];

/// Furniture for the currently-active floor.
List<OfficeObject> get officeObjects =>
    _objectsForFloor(activeFloor.clamp(0, _floorDesks.length - 1));

/// Flat props painted with the floor (walk-over-able): mats, cushions,
/// stools, gold, the pool ladder.
final flatDecor = <(PixelSprite, int, int)>[
  (yogaMatSprite, 4, 30),
  (yogaMatSprite, 7, 30),
  (cushionSprite, 3, 18),
  (cushionSprite, 5, 18),
  (cushionSprite, 7, 18),
  (moneyPileSprite, 33, 12),
  (moneyPileSprite, 35, 15),
  (moneyPileSprite, 31, 11),
  (stoolSprite, 16, 28),
  (stoolSprite, 18, 28),
  (stoolSprite, 21, 28),
  (stoolSprite, 23, 28),
  (stoolSprite, 18, 31),
  (stoolSprite, 20, 31),
  (poolLadderSprite, 51, 10),
];

/// Decor mounted on the top wall (drawn with the static layer, no collision).
final wallDecor = <(PixelSprite, Offset)>[
  (windowSprite, const Offset(3 * 16.0, 10)),
  (windowSprite, const Offset(7 * 16.0, 10)),
  (windowSprite, const Offset(11 * 16.0, 10)),
  (windowSprite, const Offset(15 * 16.0, 10)),
  (clockSprite, const Offset(21 * 16.0 + 3, 12)),
  (posterSprite, const Offset(23 * 16.0, 11)),
  (wallCalendarSprite, const Offset(26 * 16.0, 11)),
  (whiteboardSprite, const Offset(29 * 16.0, 9)),
  (windowSprite, const Offset(33 * 16.0, 10)),
  (windowSprite, const Offset(36 * 16.0, 10)),
  (windowSprite, const Offset(44 * 16.0, 10)),
  (windowSprite, const Offset(49 * 16.0, 10)),
];

// ---------------------------------------------------------------------------
// Points of interest
// ---------------------------------------------------------------------------

const coffeeSpot = Point<int>(15, 25); // café counter
const vendingSpot = Point<int>(26, 25);
const waterSpot = Point<int>(20, 25);
const snackSpot = Point<int>(18, 25); // the fridge

/// Lounge seats (sofas + armchairs) for naps.
const sofaSeats = <Seat>[
  Seat(Point(31, 20), Point(31, 21), Offset(31 * 16.0 + 8, 21 * 16.0 + 1)),
  Seat(Point(32, 20), Point(32, 21), Offset(32 * 16.0 + 8, 21 * 16.0 + 1)),
  Seat(Point(35, 20), Point(35, 21), Offset(35 * 16.0 + 8, 21 * 16.0 + 1)),
  Seat(Point(36, 20), Point(36, 21), Offset(36 * 16.0 + 8, 21 * 16.0 + 1)),
  Seat(Point(30, 22), Point(30, 23), Offset(30 * 16.0 + 8, 23 * 16.0 + 1)),
  Seat(Point(36, 22), Point(36, 23), Offset(36 * 16.0 + 8, 23 * 16.0 + 1)),
];

/// Poolside loungers for sunbathing.
const deckSeats = <Seat>[
  Seat(Point(43, 16), Point(43, 18), Offset(43 * 16.0 + 8, 18 * 16.0 + 1)),
  Seat(Point(46, 16), Point(46, 18), Offset(46 * 16.0 + 8, 18 * 16.0 + 1)),
  Seat(Point(49, 16), Point(49, 18), Offset(49 * 16.0 + 8, 18 * 16.0 + 1)),
];

/// Meditation cushions in the Focus room (flat: approach == tile).
const cushionSeats = <Seat>[
  Seat(Point(3, 18), Point(3, 18), Offset(3 * 16.0 + 8, 18 * 16.0 + 13)),
  Seat(Point(5, 18), Point(5, 18), Offset(5 * 16.0 + 8, 18 * 16.0 + 13)),
  Seat(Point(7, 18), Point(7, 18), Offset(7 * 16.0 + 8, 18 * 16.0 + 13)),
];

/// The library reading chair.
const readSeats = <Seat>[
  Seat(Point(13, 19), Point(13, 20), Offset(13 * 16.0 + 9, 20 * 16.0 + 1)),
];

/// Stand-and-browse spots in front of the bookshelves.
const readStandSpots = <Point<int>>[Point(12, 17), Point(15, 17)];

/// Gym spots: on the yoga mats and at the dumbbell rack.
const workoutSpots = <Point<int>>[Point(4, 30), Point(7, 30), Point(10, 25)];

/// Café stools — standing here reads as sitting at the table.
const cafeSpots = <Point<int>>[
  Point(16, 28),
  Point(18, 28),
  Point(21, 28),
  Point(23, 28),
  Point(18, 31),
  Point(20, 31),
];

/// Spots where two employees can stop and chat face-to-face.
const chatSpots = <ChatSpot>[
  ChatSpot(Point(19, 25), Point(21, 25), true), // café water cooler
  ChatSpot(Point(16, 28), Point(18, 28), true), // café table
  ChatSpot(Point(29, 3), Point(29, 6), false), // across the meeting table
  ChatSpot(Point(31, 3), Point(31, 6), false),
  ChatSpot(Point(18, 3), Point(20, 3), true), // server-room gossip
  ChatSpot(Point(33, 21), Point(33, 23), false), // lounge pit
  ChatSpot(Point(44, 18), Point(46, 18), true), // poolside
  ChatSpot(Point(4, 27), Point(6, 27), true), // gym
  ChatSpot(Point(30, 30), Point(32, 30), true), // entrance hall
  ChatSpot(Point(48, 25), Point(50, 25), true), // by the pool table
  ChatSpot(Point(52, 33), Point(54, 33), true), // bar
];

/// Idle stroll destinations all over the campus.
const wanderSpots = <Point<int>>[
  Point(21, 3), // analytics
  Point(22, 6), // by the printer
  Point(1, 3),
  Point(35, 3), // meeting plant
  Point(27, 12), // corridor
  Point(33, 13), // admiring the gold
  Point(11, 16), // corridor by the library
  Point(13, 17), // bookshelves
  Point(24, 18), // mailroom
  Point(3, 26), // gym floor
  Point(19, 29), // café
  Point(30, 33), // reception
  Point(41, 4), // garden north
  Point(53, 8), // pool east edge
  Point(44, 20), // deck
  Point(41, 26), // arcade
  Point(47, 25), // by the pool table
  Point(44, 34), // cinema
  Point(51, 33), // bar
];

// ---------------------------------------------------------------------------
// Drop targets (god mode)
// ---------------------------------------------------------------------------

enum DropKind { coffee, water, snack }

/// What dropping an employee on [tile] should trigger (refreshments).
DropKind? dropTargetAt(Point<int> tile) {
  if (tile.y == 24 || tile.y == 25) {
    if (tile.x >= 15 && tile.x <= 16) return DropKind.coffee;
    if (tile.x == 20) return DropKind.water;
    if (tile.x == 18) return DropKind.snack;
    if (tile.x == 26) return DropKind.snack; // vending machine
  }
  if ((tile.y == 32 || tile.y == 33) && tile.x == 10) {
    return DropKind.water; // gym cooler
  }
  return null;
}

/// The furniture object whose footprint covers [tile], if any (topmost wins).
OfficeObject? objectAt(Point<int> tile) {
  for (final o in officeObjects) {
    if (tile.x >= o.tx &&
        tile.x < o.tx + o.tw &&
        tile.y >= o.ty &&
        tile.y < o.ty + o.th) {
      return o;
    }
  }
  return null;
}

/// Finds the seat covering [tile] in [seats] (seat tile or its approach).
int? seatIndexAt(List<Seat> seats, Point<int> tile) {
  for (var i = 0; i < seats.length; i++) {
    if (seats[i].tile == tile) return i;
  }
  return null;
}

/// True if [tile] is inside the pool water.
bool isPoolTile(Point<int> tile) =>
    tile.x >= poolTiles.left &&
    tile.x < poolTiles.right &&
    tile.y >= poolTiles.top &&
    tile.y < poolTiles.bottom;

// ---------------------------------------------------------------------------
// Collision + pathfinding
// ---------------------------------------------------------------------------

// One walkability grid per floor (their furniture differs).
final List<List<List<bool>>> _floorWalkable = [
  for (var f = 0; f < _floorDesks.length; f++) _buildWalkable(f),
];

List<List<bool>> get _walkable =>
    _floorWalkable[activeFloor.clamp(0, _floorWalkable.length - 1)];

List<List<bool>> _buildWalkable(int floor) {
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
  for (final w in interiorWallTiles) {
    grid[w.y][w.x] = false;
  }
  // Pool water: no walking on water (swimming is handled separately).
  for (var y = poolTiles.top.toInt(); y < poolTiles.bottom; y++) {
    for (var x = poolTiles.left.toInt(); x < poolTiles.right; x++) {
      grid[y][x] = false;
    }
  }
  for (final o in _objectsForFloor(floor)) {
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

/// Tiles blocked by player-placed furniture (build mode). Layered on top of
/// the static [_walkable] grid so pathfinding routes around placed pieces
/// without rebuilding the whole grid.
final Set<Point<int>> placedBlocked = <Point<int>>{};

bool isWalkable(int x, int y) =>
    x >= 0 &&
    x < mapCols &&
    y >= 0 &&
    y < mapRows &&
    _walkable[y][x] &&
    !placedBlocked.contains(Point(x, y));

/// True if [tile] is on the static map (walls/furniture/pool) — independent
/// of player-placed items. Used by build mode to decide where placement and
/// removal are allowed.
bool isStaticWalkable(int x, int y) =>
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
  return doorTile; // never expected
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
