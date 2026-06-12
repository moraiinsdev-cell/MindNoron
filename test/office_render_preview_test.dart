// Renders the office artwork to PNGs under build/office_preview/ so the
// pixel art can be reviewed without launching the app. Doubles as a smoke
// test that every sprite and the full painter pipeline rasterize cleanly.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('full office scene renders', () async {
    final sim = OfficeSim(seed: 7);
    sim.syncStaff(defaultStaff());
    sim.placeInitial();
    // Stage a lively scene: someone walking, a chat pair, a sofa napper.
    sim.employees[1].say('the build is green!');
    final walker = sim.employees[2];
    walker.activity = Activity.walking;
    walker.goal = Goal.coffee;
    walker.pos = tileCenter(const Point(9, 11));
    walker.facing = Facing.left;
    final napper = sim.employees[3];
    napper.activity = Activity.sofa;
    napper.sofaSeat = 0;
    napper.pos = sofaSeatPos[0];
    napper.facing = Facing.down;
    final chatterA = sim.employees[4];
    final chatterB = sim.employees[5];
    chatterA.activity = Activity.chatting;
    chatterA.pos = tileCenter(const Point(4, 16));
    chatterA.facing = Facing.right;
    chatterA.say('☕ lunch later?');
    chatterB.activity = Activity.chatting;
    chatterB.pos = tileCenter(const Point(6, 16));
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
}
