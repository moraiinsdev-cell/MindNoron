import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'office_catalog.dart';
import 'office_economy.dart';
import 'office_lighting.dart';
import 'office_map.dart';
import 'office_particles.dart';
import 'office_sim.dart';
import 'office_sprites.dart';
import 'pixel_art.dart';

const _waterBase = Color(0xFF5FA8D4);
const _waterDeep = Color(0xFF4E96C4);
const _coping = Color(0xFFD8DCE0);

/// Paints the whole campus: a cached static layer (floors, walls, water,
/// flat decor) plus a per-frame y-sorted layer of furniture and employees,
/// then screen-space room labels, speech bubbles and a time-of-day tint.
class OfficePainter extends CustomPainter {
  OfficePainter({
    required this.sim,
    required this.cache,
    required this.zoom,
    required this.origin,
    this.hourOverride,
    this.buildMode = false,
    this.placingItem,
    this.ghostTile,
  }) : super(repaint: sim);

  final OfficeSim sim;
  final SpriteCache cache;
  final double zoom;
  final Offset origin;

  /// Forces a specific hour-of-day for lighting (tests/previews). When null
  /// the real wall clock is used.
  final double? hourOverride;

  /// Build-mode overlay state.
  final bool buildMode;
  final CatalogItem? placingItem;
  final Point<int>? ghostTile;

  static ui.Picture? _staticLayer;

  /// Drop the cached static layer (hot reload / map changes).
  static void invalidateStaticLayer() {
    _staticLayer?.dispose();
    _staticLayer = null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _staticLayer ??= _buildStaticLayer();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(origin.dx, origin.dy,
        worldWidth * zoom, worldHeight * zoom));
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(zoom);

    final sky = hourOverride != null ? SkyLight.at(hourOverride!) : SkyLight.now();

    canvas.drawPicture(_staticLayer!);
    _paintWaterShimmer(canvas);
    _paintDynamic(canvas);
    _paintButterflies(canvas);
    _paintParticles(canvas);
    if (buildMode) _paintBuildOverlay(canvas);
    _paintLighting(canvas, sky);
    canvas.restore();

    _paintTint(canvas, sky);
    _paintWeather(canvas);
    _paintOverlays(canvas);
  }

  /// Rain over the outdoor garden (screen space, clipped to the grass). Indoor
  /// areas only get a faint mood-dim, since you can't see the sky from a desk.
  void _paintWeather(Canvas canvas) {
    if (sim.weather != OfficeWeather.rain) return;

    // Outdoor region begins at the indoor/outdoor divider (tile 38).
    final out = Rect.fromLTRB(
      origin.dx + 38 * 16 * zoom,
      origin.dy,
      origin.dx + worldWidth * zoom,
      origin.dy + worldHeight * zoom,
    );
    canvas.save();
    canvas.clipRect(out);
    // Cool dim over the wet garden.
    canvas.drawRect(out, Paint()..color = const Color(0x22243450));

    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final streak = Paint()
      ..color = const Color(0x66AFC4DA)
      ..strokeWidth = 1.0;
    final rng = Random(7);
    for (var i = 0; i < 90; i++) {
      final bx = out.left + rng.nextDouble() * out.width;
      final speed = 320 + rng.nextDouble() * 160;
      final phase = (t * speed + i * 53) % (out.height + 40);
      final y = out.top - 20 + phase;
      final len = 8.0 + rng.nextDouble() * 6;
      canvas.drawLine(
          Offset(bx, y), Offset(bx - 3, y + len), streak);
    }
    canvas.restore();
  }

  // -------------------------------------------------------------------------
  // Static layer: floors, walls, water, flat decor, wall decor
  // -------------------------------------------------------------------------

  ui.Picture _buildStaticLayer() {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final p = Paint()..isAntiAlias = false;

    // Floors: checkered base with per-room colors (incl. outdoor grass).
    for (var ty = 2; ty < mapRows - 1; ty++) {
      for (var tx = 1; tx < mapCols - 1; tx++) {
        var base = floorBase;
        var alt = floorAlt;
        for (final room in rooms) {
          if (tx >= room.tiles.left &&
              tx < room.tiles.right &&
              ty >= room.tiles.top &&
              ty < room.tiles.bottom) {
            base = room.base;
            alt = room.alt;
            break;
          }
        }
        p.color = (tx + ty).isEven ? base : alt;
        c.drawRect(Rect.fromLTWH(tx * 16.0, ty * 16.0, 16, 16), p);
      }
    }

    // Garden details: scattered wildflowers + a stone path to the pool.
    for (var ty = 3; ty < mapRows - 2; ty++) {
      for (var tx = 40; tx < mapCols - 1; tx++) {
        if (isPoolTile(Point(tx, ty))) continue;
        final h = (tx * 73856093) ^ (ty * 19349663);
        if (h % 11 == 0) {
          // A tuft of grass.
          p.color = const Color(0xFF6E9C5C);
          c.drawRect(Rect.fromLTWH(tx * 16.0 + (h % 9), ty * 16.0 + (h % 7),
              2, 2), p);
        } else if (h % 17 == 3) {
          // A tiny flower.
          p.color = const [
            Color(0xFFF2E8C8),
            Color(0xFFE8C84A),
            Color(0xFFE89CB8),
            Color(0xFFB8A0E0),
          ][h % 4];
          final fx = tx * 16.0 + 3 + (h % 8), fy = ty * 16.0 + 3 + (h % 6);
          c.drawRect(Rect.fromLTWH(fx, fy, 2, 2), p);
          p.color = const Color(0xFF6E9C5C);
          c.drawRect(Rect.fromLTWH(fx, fy + 2, 1, 2), p);
        }
      }
    }
    p.color = const Color(0xFFC8C2B2);
    for (final (px, py) in [(39, 8), (40, 8), (41, 9), (39, 26), (40, 27),
        (41, 26), (42, 27), (43, 26)]) {
      c.drawRect(
          Rect.fromLTWH(px * 16.0 + 3, py * 16.0 + 4, 10, 8), p);
    }

    // Pool: coping + water.
    final poolPx = Rect.fromLTRB(poolTiles.left * 16, poolTiles.top * 16,
        poolTiles.right * 16, poolTiles.bottom * 16);
    p.color = _coping;
    c.drawRect(poolPx.inflate(3), p);
    p.color = const Color(0xFFA8ACB0);
    c.drawRect(
        Rect.fromLTWH(poolPx.left - 3, poolPx.bottom + 1,
            poolPx.width + 6, 2),
        p);
    p.color = _waterBase;
    c.drawRect(poolPx, p);
    p.color = _waterDeep;
    c.drawRect(poolPx.deflate(12), p);

    // Flat decor: mats, cushions, stools, gold, the pool ladder.
    for (final (sprite, tx, ty) in flatDecor) {
      c.save();
      c.translate(tx * 16.0 + (16 - sprite.width) / 2,
          ty * 16.0 + (16 - sprite.height) / 2);
      sprite.paint(c);
      c.restore();
    }

    // Top wall: a 2-tile band with face + dark crown + baseboard.
    p.color = wallFace;
    c.drawRect(const Rect.fromLTWH(0, 0, worldWidth + 0.0, 32), p);
    p.color = wallTop;
    c.drawRect(const Rect.fromLTWH(0, 0, worldWidth + 0.0, 4), p);
    p.color = wallBase;
    c.drawRect(const Rect.fromLTWH(0, 29, worldWidth + 0.0, 3), p);

    // Side + bottom walls.
    p.color = wallTop;
    c.drawRect(const Rect.fromLTWH(0, 0, 8, worldHeight + 0.0), p);
    c.drawRect(
        const Rect.fromLTWH(worldWidth - 8.0, 0, 8, worldHeight + 0.0), p);
    c.drawRect(
        const Rect.fromLTWH(0, worldHeight - 12.0, worldWidth + 0.0, 12), p);

    // Interior partitions: dark wall blocks with a lighter south face.
    for (final w in interiorWallTiles) {
      final x = w.x * 16.0, y = w.y * 16.0;
      p.color = wallTop;
      c.drawRect(Rect.fromLTWH(x, y, 16, 16), p);
      p.color = const Color(0xFF564E60);
      c.drawRect(Rect.fromLTWH(x, y + 10, 16, 6), p);
    }

    // Entrance: a gap with a door mat at the bottom wall (cols 27-28).
    p.color = const Color(0xFF8A8278);
    c.drawRect(const Rect.fromLTWH(27 * 16.0, worldHeight - 12.0, 32, 12), p);
    p.color = const Color(0xFFA89C84);
    c.drawRect(const Rect.fromLTWH(27 * 16.0 + 2, 33 * 16.0 + 2, 28, 12), p);

    // Wall decor (windows, whiteboard, posters, clock, calendar).
    for (final (sprite, offset) in wallDecor) {
      c.save();
      c.translate(offset.dx, offset.dy);
      sprite.paint(c);
      c.restore();
    }

    return recorder.endRecording();
  }

  /// Animated ripples drifting across the pool.
  void _paintWaterShimmer(Canvas canvas) {
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final p = Paint()
      ..isAntiAlias = false
      ..color = const Color(0x55E8F4FA);
    final poolPx = Rect.fromLTRB(poolTiles.left * 16, poolTiles.top * 16,
        poolTiles.right * 16, poolTiles.bottom * 16);
    for (var i = 0; i < 12; i++) {
      final phase = (t * 7 + i * 31) % poolPx.width;
      final y = poolPx.top + 8 + (i * 37) % (poolPx.height - 16);
      final x = poolPx.left + 4 + phase;
      final w = 8.0 + (i % 3) * 4;
      if (x + w < poolPx.right - 2) {
        canvas.drawRect(Rect.fromLTWH(x, y.toDouble(), w, 1.6), p);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Dynamic layer: furniture + employees, y-sorted
  // -------------------------------------------------------------------------

  void _paintDynamic(Canvas canvas) {
    final items = <(double, void Function())>[];

    for (final o in officeObjects) {
      items.add((o.sortY, () => _paintObject(canvas, o)));
    }

    // Player-placed furniture (build mode), y-sorted with everything else.
    for (final p in sim.placedItems) {
      final item = catalogItem(p.itemId);
      if (item == null) continue;
      final sortY = (p.ty + item.th) * 16.0;
      items.add((sortY, () => _paintPlaced(canvas, p, item)));
    }

    for (final e in sim.employees) {
      final sortY =
          e.activity == Activity.dragged ? double.infinity : e.pos.dy;
      items.add((sortY, () => _paintEmployee(canvas, e)));
    }

    items.add((sim.cat.pos.dy, () => _paintCat(canvas)));

    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in items) {
      draw();
    }
  }

  void _paintCat(Canvas canvas) {
    final c = sim.cat;
    final (sprite, key, flip) = switch (c.state) {
      CatState.wandering => (c.animPhase * 7).floor() % 2 == 0
          ? (catWalkASprite, 'cat-walkA', !c.facingRight)
          : (catWalkBSprite, 'cat-walkB', !c.facingRight),
      CatState.sitting => (catSitSprite, 'cat-sit', false),
      CatState.sleeping => (catSleepSprite, 'cat-sleep', false),
    };
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(c.pos.dx, c.pos.dy + 1), width: 10, height: 3),
      Paint()
        ..color = const Color.fromRGBO(30, 28, 40, 0.25)
        ..isAntiAlias = false,
    );
    final img = cache.imageFor(key, () => sprite, flipX: flip);
    drawSprite(
        canvas,
        img,
        Offset(c.pos.dx - sprite.width / 2,
            c.pos.dy - sprite.height.toDouble()));
  }

  void _paintButterflies(Canvas canvas) {
    final p = Paint()..isAntiAlias = false;
    for (final b in sim.butterflies) {
      final flap = sin(b.phase * 14) > 0;
      p.color = b.color;
      if (flap) {
        canvas.drawRect(Rect.fromLTWH(b.pos.dx - 2, b.pos.dy - 1, 2, 2), p);
        canvas.drawRect(Rect.fromLTWH(b.pos.dx + 1, b.pos.dy - 1, 2, 2), p);
      } else {
        canvas.drawRect(Rect.fromLTWH(b.pos.dx - 1, b.pos.dy - 2, 1, 3), p);
        canvas.drawRect(Rect.fromLTWH(b.pos.dx + 1, b.pos.dy - 2, 1, 3), p);
      }
    }
  }

  // Warm fixtures that glow once it gets dark (lamps, café counter, screens).
  static const _lampPoints = [
    Offset(2 * 16.0 + 8, 16 * 16.0 + 4), // focus room lamp
    Offset(19 * 16.0 + 8, 16 * 16.0 + 4), // library lamp
    Offset(16 * 16.0, 24 * 16.0 + 6), // café counter
    Offset(34 * 16.0 + 8, 12 * 16.0), // finance lamp
  ];

  void _paintParticles(Canvas canvas) {
    final p = Paint()..isAntiAlias = false;
    for (final pt in sim.particles.particles) {
      final fade = (pt.life / pt.maxLife).clamp(0.0, 1.0);
      switch (pt.kind) {
        case ParticleKind.steam:
          // Soft, expanding, fading upward wisp (additive).
          final r = pt.size + pt.t * 2.5;
          p
            ..blendMode = BlendMode.plus
            ..color = pt.color.withValues(alpha: 0.30 * (1 - pt.t));
          canvas.drawCircle(pt.pos, r, p);
          p.blendMode = BlendMode.srcOver;
        case ParticleKind.dust:
          p.color = pt.color
              .withValues(alpha: 0.5 * sin(fade * pi).clamp(0.0, 1.0));
          canvas.drawRect(
              Rect.fromLTWH(pt.pos.dx, pt.pos.dy, pt.size, pt.size), p);
        case ParticleKind.petal:
          p.color = pt.color.withValues(alpha: fade.clamp(0.0, 1.0));
          canvas.drawRect(
              Rect.fromLTWH(pt.pos.dx, pt.pos.dy, pt.size, pt.size), p);
        case ParticleKind.confetti:
          p.color = pt.color.withValues(alpha: fade.clamp(0.0, 1.0));
          // A spinning sliver — width/height swap by phase for flutter.
          final flip = sin((pt.t + pt.seed) * 12) > 0;
          canvas.drawRect(
            Rect.fromLTWH(pt.pos.dx, pt.pos.dy, flip ? pt.size : pt.size * 0.5,
                flip ? pt.size * 0.5 : pt.size),
            p,
          );
        case ParticleKind.splash:
          p.color = pt.color.withValues(alpha: fade.clamp(0.0, 1.0));
          canvas.drawRect(
              Rect.fromLTWH(pt.pos.dx, pt.pos.dy, pt.size, pt.size), p);
      }
    }
  }

  /// Additive pools of light, scaled by how dark the hour is. Lamps glow
  /// warm; occupied monitors cast a cool wash so the office reads as "alive"
  /// at night. Drawn in world space with [BlendMode.plus].
  void _paintLighting(Canvas canvas, SkyLight sky) {
    if (sky.darkness <= 0.02) return;
    final d = sky.darkness;

    for (final g in _lampPoints) {
      _glow(canvas, g, 38, const Color(0xFFFFD080), 0.30 * d);
    }

    // Cool monitor glow at desks where someone is actually working.
    for (final e in sim.employees) {
      if (e.activity != Activity.working) continue;
      _glow(canvas, Offset(e.pos.dx, e.pos.dy - 6), 18,
          const Color(0xFF8CC8FF), 0.22 * d);
    }
  }

  void _glow(
      Canvas canvas, Offset center, double radius, Color color, double alpha) {
    if (alpha <= 0) return;
    final a = alpha.clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(center, radius, [
          color.withValues(alpha: a),
          color.withValues(alpha: 0),
        ], const [0.0, 1.0]),
    );
  }

  /// Build-mode floor grid + a green/red placement ghost.
  void _paintBuildOverlay(Canvas canvas) {
    final line = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 0.5;
    for (var x = 1; x < mapCols; x++) {
      canvas.drawLine(Offset(x * 16.0, 32), Offset(x * 16.0, worldHeight - 12),
          line);
    }
    for (var y = 2; y < mapRows; y++) {
      canvas.drawLine(Offset(8, y * 16.0), Offset(worldWidth - 8, y * 16.0),
          line);
    }

    final g = ghostTile;
    final item = placingItem;
    if (g != null && item != null) {
      final ok = sim.canPlaceAt(item, g.x, g.y);
      final rect = Rect.fromLTWH(
          g.x * 16.0, g.y * 16.0, item.tw * 16.0, item.th * 16.0);
      canvas.drawRect(
        rect,
        Paint()
          ..color = ok ? const Color(0x5552E07A) : const Color(0x55E05252),
      );
      // Sprite preview, semi-transparent.
      final img = cache.imageFor('cat-${item.id}', () => item.sprite);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(
          g.x * 16.0 + (item.tw * 16 - item.sprite.width) / 2,
          (g.y + item.th) * 16.0 - item.sprite.height,
          item.sprite.width.toDouble(),
          item.sprite.height.toDouble(),
        ),
        Paint()
          ..isAntiAlias = false
          ..filterQuality = FilterQuality.none
          ..color = const Color(0xCCFFFFFF),
      );
    }
  }

  void _paintPlaced(Canvas canvas, PlacedItem placed, CatalogItem item) {
    final origin = Offset(
      placed.tx * 16.0 + (item.tw * 16 - item.sprite.width) / 2,
      (placed.ty + item.th) * 16.0 - item.sprite.height,
    );
    final img =
        cache.imageFor('cat-${item.id}', () => item.sprite);
    drawSprite(canvas, img, origin);
  }

  void _paintObject(Canvas canvas, OfficeObject o) {
    final img = cache.imageFor(
        'obj-${identityHashCode(o.sprite)}', () => o.sprite);
    drawSprite(canvas, img, o.drawOrigin);

    if (o.isDesk) _paintScreenFlicker(canvas, o);
  }

  /// Animated monitor glow — only while someone is sitting at the desk.
  void _paintScreenFlicker(Canvas canvas, OfficeObject desk) {
    final occupied = sim.employees.any((e) =>
        e.activity == Activity.working &&
        e.deskIndex >= 0 &&
        e.deskIndex < officeDesks.length &&
        officeDesks[e.deskIndex].tx == desk.tx &&
        officeDesks[e.deskIndex].ty == desk.ty);
    final o = desk.drawOrigin;
    final screen = Rect.fromLTWH(o.dx + 5, o.dy + 1, 10, 4);
    final p = Paint()..isAntiAlias = false;
    if (!occupied) {
      p.color = const Color(0xFF38404C); // screen off
      canvas.drawRect(screen, p);
      return;
    }
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final phase = ((t * 2.4) + desk.tx * 1.7 + desk.ty).floor() % 3;
    p.color = const [
      Color(0x338CD0FF),
      Color(0x22FFFFFF),
      Color(0x2260A8E0),
    ][phase];
    canvas.drawRect(screen, p);
  }

  void _paintEmployee(Canvas canvas, EmployeeRuntime e) {
    final look = e.spec.look;
    final palette = paletteForLook(
      skin: look.skin,
      hairColor: look.hairColor,
      shirt: look.shirt,
      pants: look.pants,
    );
    final (frame, flip) = sim.frameFor(e);

    final dragged = e.activity == Activity.dragged;
    final swimming = e.activity == Activity.swim;
    final lift = dragged ? 7.0 + sin(e.animPhase * 5) * 1.5 : 0.0;
    final typingBob = e.activity == Activity.working &&
            (e.animPhase * 2.4).floor().isEven
        ? 1.0
        : 0.0;
    // Gentle breathing while standing idle so no one looks frozen.
    final breathing = (e.activity == Activity.idle ||
            e.activity == Activity.wandering ||
            e.activity == Activity.chatting)
        ? (sin(e.animPhase * 1.8) * 0.5 - 0.5)
        : 0.0;

    // Selection marker (pulsing ring under the employee).
    if (sim.selectedId == e.spec.id) {
      final pulse = 0.55 + 0.35 * sin(e.animPhase * 4);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(e.pos.dx, e.pos.dy + 1), width: 16, height: 7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Color.fromRGBO(255, 214, 90, pulse),
      );
    }

    final rows = characterRows(frame, look.hairStyle);
    final key =
        'c-${look.hairStyle}-${look.skin}-${look.hairColor}-${look.shirt}-'
        '${look.pants}-${frame.name}';
    final img = cache.imageFor(
        key, () => PixelSprite(rows, palette),
        flipX: flip);
    final h = rows.length.toDouble();

    if (swimming) {
      // Only head + shoulders above the water, with a ripple ring.
      final bob = sin(e.animPhase * 3) * 1.2;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(e.pos.dx, e.pos.dy - 2), width: 16, height: 7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0x88E8F4FA),
      );
      const visibleRows = 9.0;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), visibleRows),
        Rect.fromLTWH(
            e.pos.dx - 6, e.pos.dy - visibleRows - 1 + bob, 12, visibleRows),
        Paint()
          ..isAntiAlias = false
          ..filterQuality = FilterQuality.none,
      );
      return;
    }

    // Shadow on the floor under their feet.
    if (!e.isSeated) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(e.pos.dx, e.pos.dy + 1), width: 11, height: 4),
        Paint()
          ..color = Color.fromRGBO(30, 28, 40, dragged ? 0.18 : 0.28)
          ..isAntiAlias = false,
      );
    }

    // Chair under desk workers (drawn just before the person).
    if (e.activity == Activity.working) {
      final chairImg = cache.imageFor('chair', () => chairSprite);
      drawSprite(
          canvas,
          chairImg,
          Offset(e.pos.dx - chairSprite.width / 2,
              e.pos.dy - chairSprite.height + 3));
    }

    drawSprite(
      canvas,
      img,
      Offset(e.pos.dx - 6, e.pos.dy - h - lift + typingBob + breathing),
    );
  }

  // -------------------------------------------------------------------------
  // Screen-space layers: tint, room labels, speech bubbles, name tags
  // -------------------------------------------------------------------------

  void _paintTint(Canvas canvas, SkyLight sky) {
    final rect = Rect.fromLTWH(
        origin.dx, origin.dy, worldWidth * zoom, worldHeight * zoom);

    // Smooth time-of-day colour wash.
    if (sky.tint.a > 0) {
      canvas.drawRect(rect, Paint()..color = sky.tint);
    }

    // Subtle vignette for depth — always on, a touch heavier at night.
    final vignette = 0.16 + 0.22 * sky.darkness;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          rect.longestSide * 0.62,
          [
            const Color(0x00000000),
            Color.fromRGBO(8, 6, 18, vignette),
          ],
          const [0.62, 1.0],
        ),
    );
  }

  Offset _toScreen(Offset world) => origin + world * zoom;

  void _paintOverlays(Canvas canvas) {
    // Room labels.
    for (final room in rooms) {
      if (room.label.isEmpty) continue;
      final anchor = _toScreen(Offset(
          room.tiles.left * 16 + 4, room.tiles.top * 16 + 3));
      final tp = TextPainter(
        text: TextSpan(
          text: room.label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF2A2433).withValues(alpha: 0.38),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, anchor);
    }

    // Floating labels (object pokes, +coins, banners).
    for (final f in sim.floatingTexts) {
      final progress = 1 - (f.ttl / f.maxTtl);
      final fade = (f.ttl / 0.5).clamp(0.0, 1.0);
      final at = _toScreen(
          Offset(f.pos.dx, f.pos.dy - 8 - progress * f.rise));
      _paintFloating(canvas, at, f.text, f.color ?? const Color(0xFFFFFDF6),
          fade);
    }

    final cat = sim.cat;
    if (cat.bubble != null && cat.bubbleTtl > 0) {
      _paintBubble(
          canvas, _toScreen(Offset(cat.pos.dx, cat.pos.dy - 12)), cat.bubble!,
          fade: (cat.bubbleTtl / 0.3).clamp(0.0, 1.0));
    }

    for (final e in sim.employees) {
      final headWorld = Offset(e.pos.dx, e.pos.dy - 19);
      if (e.bubble != null && e.bubbleTtl > 0) {
        _paintBubble(canvas, _toScreen(headWorld), e.bubble!,
            fade: (e.bubbleTtl / 0.3).clamp(0.0, 1.0));
      }
      if (sim.selectedId == e.spec.id ||
          e.activity == Activity.dragged) {
        _paintNameTag(
            canvas, _toScreen(Offset(e.pos.dx, e.pos.dy + 3)), e.spec.name);
      }
    }
  }

  void _paintBubble(Canvas canvas, Offset anchor, String text,
      {double fade = 1}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          color: const Color(0xFF2A2433).withValues(alpha: fade),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 160);

    final w = tp.width + 12;
    final h = tp.height + 8;
    final rect = Rect.fromCenter(
        center: anchor.translate(0, -h / 2 - 5), width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    final fill = Paint()
      ..color = const Color(0xFFFFFDF6).withValues(alpha: 0.96 * fade);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF2A2433).withValues(alpha: 0.85 * fade);

    // Tail.
    final tail = Path()
      ..moveTo(anchor.dx - 4, rect.bottom - 1)
      ..lineTo(anchor.dx, rect.bottom + 5)
      ..lineTo(anchor.dx + 4, rect.bottom - 1)
      ..close();

    canvas.drawRRect(rrect, fill);
    canvas.drawPath(tail, fill);
    canvas.drawRRect(rrect, border);
    canvas.drawPath(tail, border);
    // Re-fill the seam where the tail meets the bubble.
    canvas.drawRect(
        Rect.fromLTWH(anchor.dx - 3.4, rect.bottom - 1.6, 6.8, 1.8), fill);

    tp.paint(canvas, rect.topLeft.translate(6, 4));
  }

  void _paintFloating(
      Canvas canvas, Offset center, String text, Color color, double fade) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color.withValues(alpha: fade),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final origin = center.translate(-tp.width / 2, -tp.height / 2);
    // Drop shadow for legibility over any floor.
    final shadow = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1A1622).withValues(alpha: 0.5 * fade),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    shadow.paint(canvas, origin.translate(0.8, 0.8));
    tp.paint(canvas, origin);
  }

  void _paintNameTag(Canvas canvas, Offset anchor, String name) {
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFFFFFDF6),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final rect = Rect.fromCenter(
      center: anchor.translate(0, 8),
      width: tp.width + 10,
      height: tp.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = const Color(0xCC2A2433),
    );
    tp.paint(canvas, rect.topLeft.translate(5, 2));
  }

  @override
  bool shouldRepaint(OfficePainter oldDelegate) =>
      oldDelegate.zoom != zoom ||
      oldDelegate.origin != origin ||
      oldDelegate.sim != sim ||
      oldDelegate.buildMode != buildMode ||
      oldDelegate.placingItem != placingItem ||
      oldDelegate.ghostTile != ghostTile;
}
