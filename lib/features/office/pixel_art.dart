import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A hand-drawn pixel sprite encoded as rows of palette characters.
///
/// `.` and space are transparent; any other character is looked up in the
/// sprite's palette. All of MindNoron Inc.'s artwork (characters, furniture,
/// floors) is drawn this way — no image assets.
class PixelSprite {
  PixelSprite(this.rows, this.palette)
      : assert(rows.isNotEmpty),
        width = rows.first.length,
        height = rows.length;

  final List<String> rows;
  final Map<String, Color> palette;
  final int width;
  final int height;

  /// Paints the sprite with run-length merged rects (1 unit = 1 pixel).
  /// Callers set up canvas scale/translation themselves.
  void paint(Canvas canvas, {bool flipX = false}) {
    final paintObj = Paint()..isAntiAlias = false;
    for (var y = 0; y < height; y++) {
      final row = rows[y];
      var x = 0;
      while (x < row.length) {
        final ch = row[x];
        if (ch == '.' || ch == ' ') {
          x++;
          continue;
        }
        var run = 1;
        while (x + run < row.length && row[x + run] == ch) {
          run++;
        }
        final color = palette[ch];
        if (color != null) {
          paintObj.color = color;
          final left = flipX ? (width - x - run).toDouble() : x.toDouble();
          canvas.drawRect(
            Rect.fromLTWH(left, y.toDouble(), run.toDouble(), 1),
            paintObj,
          );
        }
        x += run;
      }
    }
  }

  /// Rasterizes to a GPU image (1 px per cell) for cheap repeated drawing.
  ui.Image toImage({bool flipX = false}) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(canvas, flipX: flipX);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  /// Returns a copy with palette entries overridden (used to give every
  /// employee their own hair/skin/shirt colors from one body template).
  PixelSprite withPalette(Map<String, Color> overrides) {
    return PixelSprite(rows, {...palette, ...overrides});
  }
}

/// Cache of rasterized sprite frames keyed by an arbitrary string.
/// Images are kept for the lifetime of the office screen.
class SpriteCache {
  final _images = <String, ui.Image>{};

  ui.Image imageFor(String key, PixelSprite Function() build,
      {bool flipX = false}) {
    return _images.putIfAbsent(
        flipX ? '$key#flip' : key, () => build().toImage(flipX: flipX));
  }

  void dispose() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
  }
}

/// Draws a cached sprite image at [topLeft] (world pixels), scaled by 1.
void drawSprite(Canvas canvas, ui.Image image, Offset topLeft) {
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(topLeft.dx, topLeft.dy, image.width.toDouble(),
        image.height.toDouble()),
    Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none,
  );
}
