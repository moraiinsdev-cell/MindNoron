// Renders the office artwork to PNGs under build/office_preview/ so the
// pixel art can be reviewed without launching the app. Doubles as a smoke
// test that every sprite and the full painter pipeline rasterize cleanly.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/features/office/office_catalog.dart';
import 'package:mind_noron/features/office/office_economy.dart';
import 'package:mind_noron/features/office/office_map.dart';
import 'package:mind_noron/features/office/office_models.dart';
import 'package:mind_noron/features/office/office_painter.dart';
import 'package:mind_noron/features/office/office_sim.dart';
import 'package:mind_noron/features/office/office_sprites.dart';
import 'package:mind_noron/features/office/pixel_art.dart';

Future<void> _savePng(ui.Image image, String name) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('build/office_preview/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

ui.Image _record(int w, int h, void Function(Canvas) draw) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(w, h);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('character sheet renders', () async {
    const scale = 4.0;
    const cellW = 16.0, cellH = 22.0;
    const frames = CharFrame.values;
    final looks = [
      for (var i = 0; i < 6; i++)
        EmployeeLook(
            skin: i % 4,
            hairStyle: i % 3,
            hairColor: i,
            shirt: i,
            pants: i % 3),
    ];
    final img = _record(
      (frames.length * cellW * scale).toInt(),
      (looks.length * cellH * scale).toInt(),
      (canvas) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, frames.length * cellW * scale,
              looks.length * cellH * scale),
          Paint()..color = const Color(0xFF4A4A55),
        );
        canvas.scale(scale);
        for (var row = 0; row < looks.length; row++) {
          final look = looks[row];
          final palette = paletteForLook(
            skin: look.skin,
            hairColor: look.hairColor,
            shirt: look.shirt,
            pants: look.pants,
          );
          for (var col = 0; col < frames.length; col++) {
            canvas.save();
            canvas.translate(col * cellW + 2, row * cellH + 2);
            characterSprite(frames[col],
                    style: look.hairStyle, palette: palette)
                .paint(canvas);
            canvas.restore();
          }
        }
      },
    );
    await _savePng(img, 'characters');
    expect(img.width, greaterThan(0));
  });

  test('furniture sheet renders', () async {
    const scale = 3.0;
    final sprites = <String, PixelSprite>{
      'desk': deskSprite,
      'chair': chairSprite,
      'plant': plantSprite,
      'cooler': waterCoolerSprite,
      'coffee': coffeeCounterSprite,
      'sofa': sofaSprite,
      'shelf': bookshelfSprite,
      'vending': vendingSprite,
      'board': whiteboardSprite,
      'poster': posterSprite,
      'window': windowSprite,
      'printer': printerSprite,
      'meeting': meetingTableSprite,
      'lounge': loungeTableSprite,
      'clock': clockSprite,
      'papers': paperStackSprite,
      'fridge': fridgeSprite,
      'kitchen': kitchenTableSprite,
      'stool': stoolSprite,
      'armchair': armchairSprite,
      'filing': filingCabinetSprite,
      'server': serverRackSprite,
      'box': boxSprite,
      'treadmill': treadmillSprite,
      'dumbbells': dumbbellRackSprite,
      'yogamat': yogaMatSprite,
      'lounger': loungerSprite,
      'umbrella': umbrellaSprite,
      'cafetable': cafeTableSprite,
      'menu': menuBoardSprite,
      'safe': safeSprite,
      'money': moneyPileSprite,
      'mail': mailShelfSprite,
      'cushion': cushionSprite,
      'bonsai': bonsaiSprite,
      'lamp': lampSprite,
      'calendar': wallCalendarSprite,
      'ladder': poolLadderSprite,
    };
    var x = 2.0;
    final positions = <String, double>{};
    for (final entry in sprites.entries) {
      positions[entry.key] = x;
      x += entry.value.width + 4;
    }
    final img = _record((x * scale).toInt(), (40 * scale).toInt(), (canvas) {
      canvas.drawRect(Rect.fromLTWH(0, 0, x * scale, 40 * scale),
          Paint()..color = const Color(0xFFD8D3CA));
      canvas.scale(scale);
      for (final entry in sprites.entries) {
        canvas.save();
        canvas.translate(
            positions[entry.key]!, 36.0 - entry.value.height);
        entry.value.paint(canvas);
        canvas.restore();
      }
    });
    await _savePng(img, 'furniture');
    expect(img.width, greaterThan(0));
  });

  test('full campus scene renders', () async {
    final sim = OfficeSim(seed: 7);
    sim.syncStaff(defaultStaff());
    sim.placeInitial();
    // Stage a lively scene covering the campus: walker, swimmer, sunbather,
    // gym-goer, meditator, and a chatting pair at the café cooler.
    sim.employees[1].say('the build is green!');
    final walker = sim.employees[1];
    walker.activity = Activity.walking;
    walker.goal = Goal.coffee;
    walker.pos = tileCenter(const Point(9, 11));
    walker.facing = Facing.left;
    final swimmer = sim.employees[2];
    swimmer.activity = Activity.swim;
    swimmer.pos = const Offset(46 * 16.0, 10 * 16.0);
    swimmer.swimTarget = const Offset(48 * 16.0, 12 * 16.0);
    final sunbather = sim.employees[3];
    sunbather.activity = Activity.sunbathe;
    sunbather.seatKind = SeatKind.deck;
    sunbather.seatIndex = 0;
    sunbather.pos = deckSeats[0].seatPos;
    sunbather.facing = Facing.down;
    sunbather.say('😎');
    final lifter = sim.employees[4];
    lifter.activity = Activity.gym;
    lifter.pos = tileCenter(const Point(4, 30));
    lifter.facing = Facing.up;
    final monk = sim.employees[5];
    monk.activity = Activity.meditate;
    monk.seatKind = SeatKind.cushion;
    monk.seatIndex = 0;
    monk.pos = cushionSeats[0].seatPos;
    monk.facing = Facing.down;
    final chatterA = sim.employees[6];
    final chatterB = sim.employees[7];
    chatterA.activity = Activity.chatting;
    chatterA.pos = tileCenter(const Point(19, 25));
    chatterA.facing = Facing.right;
    chatterA.say('☕ lunch later?');
    chatterB.activity = Activity.chatting;
    chatterB.pos = tileCenter(const Point(21, 25));
    chatterB.facing = Facing.left;
    sim.selectedId = sim.employees.first.spec.id;

    const zoom = 2.0;
    final cache = SpriteCache();
    final painter = OfficePainter(
      sim: sim,
      cache: cache,
      zoom: zoom,
      origin: Offset.zero,
    );
    final img = _record(
      (worldWidth * zoom).toInt(),
      (worldHeight * zoom).toInt(),
      (canvas) => painter.paint(
          canvas, const Size(worldWidth * zoom, worldHeight * zoom)),
    );
    await _savePng(img, 'office_scene');
    cache.dispose();
    expect(img.width, worldWidth * zoom);
  });

  test('time-of-day lighting renders (morning/day/dusk/night)', () async {
    final sim = OfficeSim(seed: 7);
    sim.syncStaff(defaultStaff());
    sim.placeInitial();
    // A few workers at desks so monitor glow shows up at night.
    for (var i = 0; i < 4; i++) {
      sim.employees[i].activity = Activity.working;
    }
    const zoom = 2.0;
    final cache = SpriteCache();
    for (final (name, hour) in [
      ('morning', 7.2),
      ('day', 13.0),
      ('dusk', 18.6),
      ('night', 23.0),
    ]) {
      final painter = OfficePainter(
        sim: sim,
        cache: cache,
        zoom: zoom,
        origin: Offset.zero,
        hourOverride: hour,
      );
      final img = _record(
        (worldWidth * zoom).toInt(),
        (worldHeight * zoom).toInt(),
        (canvas) => painter.paint(
            canvas, const Size(worldWidth * zoom, worldHeight * zoom)),
      );
      await _savePng(img, 'lighting_$name');
      expect(img.width, worldWidth * zoom);
    }
    cache.dispose();
  });

  test('particles render (steam, dust, petals, confetti, splash)', () async {
    final sim = OfficeSim(seed: 7);
    sim.syncStaff(defaultStaff());
    sim.placeInitial();
    // Two coffee drinkers so steam puffs spawn during the warm-up.
    sim.employees[0].activity = Activity.coffee;
    sim.employees[0].pos = tileCenter(const Point(15, 25));
    sim.employees[1].activity = Activity.cafe;
    sim.employees[1].pos = tileCenter(const Point(24, 28));
    // Warm up ambient emitters (dust + petals).
    for (var i = 0; i < 120; i++) {
      sim.tick(0.05);
    }
    // Stage one-off effects.
    sim.particles.confetti(const Offset(20 * 16.0, 8 * 16.0));
    sim.particles.splash(const Offset(47 * 16.0, 10 * 16.0));
    for (var i = 0; i < 6; i++) {
      sim.particles.emitSteam(const Offset(15 * 16.0, 24 * 16.0));
    }

    const zoom = 2.0;
    final cache = SpriteCache();
    final painter = OfficePainter(
      sim: sim,
      cache: cache,
      zoom: zoom,
      origin: Offset.zero,
      hourOverride: 13.0,
    );
    final img = _record(
      (worldWidth * zoom).toInt(),
      (worldHeight * zoom).toInt(),
      (canvas) => painter.paint(
          canvas, const Size(worldWidth * zoom, worldHeight * zoom)),
    );
    await _savePng(img, 'particles');
    cache.dispose();
    expect(sim.particles.particles, isNotEmpty);
  });

  test('rainy weather renders over the garden', () async {
    final sim = OfficeSim(seed: 7);
    sim.syncStaff(defaultStaff());
    sim.placeInitial();
    sim.setWeather(OfficeWeather.rain);
    const zoom = 2.0;
    final cache = SpriteCache();
    final painter = OfficePainter(
      sim: sim,
      cache: cache,
      zoom: zoom,
      origin: Offset.zero,
      hourOverride: 15.0,
    );
    final img = _record(
      (worldWidth * zoom).toInt(),
      (worldHeight * zoom).toInt(),
      (canvas) => painter.paint(
          canvas, const Size(worldWidth * zoom, worldHeight * zoom)),
    );
    await _savePng(img, 'weather_rain');
    cache.dispose();
    expect(img.width, worldWidth * zoom);
  });

  test('build mode renders grid, placed items and ghost', () async {
    final sim = OfficeSim(seed: 7);
    sim.syncStaff(defaultStaff());
    sim.placeInitial();
    sim.syncLayout(const [
      PlacedItem(itemId: 'sofa', tx: 24, ty: 5),
      PlacedItem(itemId: 'plant', tx: 22, ty: 6),
      PlacedItem(itemId: 'bookshelf', tx: 26, ty: 5),
    ]);
    const zoom = 2.0;
    final cache = SpriteCache();
    final painter = OfficePainter(
      sim: sim,
      cache: cache,
      zoom: zoom,
      origin: Offset.zero,
      hourOverride: 13.0,
      buildMode: true,
      placingItem: catalogItem('bonsai'),
      ghostTile: const Point(20, 6),
    );
    final img = _record(
      (worldWidth * zoom).toInt(),
      (worldHeight * zoom).toInt(),
      (canvas) => painter.paint(
          canvas, const Size(worldWidth * zoom, worldHeight * zoom)),
    );
    await _savePng(img, 'build_mode');
    cache.dispose();
    expect(sim.placedItems.length, 3);
  });

  test('focus mode renders deep-work overlay', () async {
    final sim = OfficeSim(seed: 7);
    sim.syncStaff(defaultStaff());
    sim.placeInitial();
    sim.setFocusMode(true);
    const zoom = 2.0;
    final cache = SpriteCache();
    final painter = OfficePainter(
      sim: sim,
      cache: cache,
      zoom: zoom,
      origin: Offset.zero,
      hourOverride: 14.0,
      focusMode: true,
    );
    final img = _record(
      (worldWidth * zoom).toInt(),
      (worldHeight * zoom).toInt(),
      (canvas) => painter.paint(
          canvas, const Size(worldWidth * zoom, worldHeight * zoom)),
    );
    await _savePng(img, 'focus_mode');
    cache.dispose();
    expect(sim.focusMode, isTrue);
  });
}
