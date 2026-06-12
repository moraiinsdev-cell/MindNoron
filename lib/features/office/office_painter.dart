import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'office_map.dart';
import 'office_sim.dart';
import 'office_sprites.dart';
import 'pixel_art.dart';

/// Paints the whole office: a cached static layer (floor, walls, wall decor)
/// plus a per-frame y-sorted layer of furniture and employees, then
/// screen-space speech bubbles and a time-of-day tint.
class OfficePainter extends CustomPainter {
  OfficePainter({
    required this.sim,
    required this.cache,
    required this.zoom,
    required this.origin,
  }) : super(repaint: sim);

  final OfficeSim sim;
  final SpriteCache cache;
  final double zoom;
  final Offset origin;

  static ui.Picture? _staticLayer;

  @override
  void paint(Canvas canvas, Size size) {
    _staticLayer ??= _buildStaticLayer();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(origin.dx, origin.dy,
        worldWidth * zoom, worldHeight * zoom));
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(zoom);

    canvas.drawPicture(_staticLayer!);
    _paintDynamic(canvas);
    canvas.restore();

    _paintTint(canvas);
    _paintOverlays(canvas);
  }

  // -------------------------------------------------------------------------
  // Static layer: floor, walls, wall decor
  // -------------------------------------------------------------------------

  ui.Picture _buildStaticLayer() {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final p = Paint()..isAntiAlias = false;

    // Floor: checkered base with zone carpets.
    for (var ty = 2; ty < mapRows - 1; ty++) {
      for (var tx = 1; tx < mapCols - 1; tx++) {
        var base = floorBase;
        var alt = floorAlt;
        for (final zone in floorZones) {
          if (tx >= zone.tiles.left &&
              tx < zone.tiles.right &&
              ty >= zone.tiles.top &&
              ty < zone.tiles.bottom) {
            base = zone.base;
            alt = zone.alt;
            break;
          }
        }
        p.color = (tx + ty).isEven ? base : alt;
        c.drawRect(
          Rect.fromLTWH(tx * 16.0, ty * 16.0, 16, 16),
          p,
        );
      }
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

    // Entrance: a gap with a door mat at the bottom wall (cols 14-15).
    p.color = const Color(0xFF8A8278);
    c.drawRect(const Rect.fromLTWH(14 * 16.0, worldHeight - 12.0, 32, 12), p);
    p.color = const Color(0xFFA89C84);
    c.drawRect(const Rect.fromLTWH(14 * 16.0 + 2, 18 * 16.0 + 2, 28, 10), p);

    // Wall decor (windows, whiteboard, poster, clock).
    for (final (sprite, offset) in wallDecor) {
      c.save();
      c.translate(offset.dx, offset.dy);
      sprite.paint(c);
      c.restore();
    }

    return recorder.endRecording();
  }

  // -------------------------------------------------------------------------
  // Dynamic layer: furniture + employees, y-sorted
  // -------------------------------------------------------------------------

  void _paintDynamic(Canvas canvas) {
    final items = <(double, void Function())>[];

    for (final o in officeObjects) {
      items.add((o.sortY, () => _paintObject(canvas, o)));
    }

    for (final e in sim.employees) {
      final sortY =
          e.activity == Activity.dragged ? double.infinity : e.pos.dy;
      items.add((sortY, () => _paintEmployee(canvas, e)));
    }

    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in items) {
      draw();
    }
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
    final lift = dragged ? 7.0 + sin(e.animPhase * 5) * 1.5 : 0.0;
    final typingBob = e.activity == Activity.working &&
            (e.animPhase * 2.4).floor().isEven
        ? 1.0
        : 0.0;

    // Shadow on the floor under their feet.
    final shadow = Paint()
      ..color = Color.fromRGBO(30, 28, 40, dragged ? 0.18 : 0.28)
      ..isAntiAlias = false;
    if (!e.isSeated) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(e.pos.dx, e.pos.dy + 1), width: 11, height: 4),
        shadow,
      );
    }

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

    // Chair under desk workers (drawn just before the person).
    if (e.activity == Activity.working) {
      final chairImg = cache.imageFor('chair', () => chairSprite);
      drawSprite(
          canvas,
          chairImg,
          Offset(e.pos.dx - chairSprite.width / 2,
              e.pos.dy - chairSprite.height + 3));
    }

    final rows = characterRows(frame, look.hairStyle);
    final key =
        'c-${look.hairStyle}-${look.skin}-${look.hairColor}-${look.shirt}-'
        '${look.pants}-${frame.name}';
    final img = cache.imageFor(
        key, () => PixelSprite(rows, palette),
        flipX: flip);

    final h = rows.length.toDouble();
    drawSprite(
      canvas,
      img,
      Offset(e.pos.dx - 6, e.pos.dy - h - lift + typingBob),
    );
  }

  // -------------------------------------------------------------------------
  // Screen-space layers: tint, speech bubbles, name tags
  // -------------------------------------------------------------------------

  void _paintTint(Canvas canvas) {
    final tint = _tintForHour(DateTime.now().hour);
    if (tint == null) return;
    canvas.drawRect(
      Rect.fromLTWH(origin.dx, origin.dy, worldWidth * zoom,
          worldHeight * zoom),
      Paint()..color = tint,
    );
  }

  static Color? _tintForHour(int h) {
    if (h >= 22 || h < 6) return const Color(0x3D1E3050); // deep night
    if (h >= 19) return const Color(0x2A283C5C); // evening
    if (h >= 17) return const Color(0x1ED08438); // golden hour
    if (h < 8) return const Color(0x14E8B860); // early morning
    return null;
  }

  Offset _toScreen(Offset world) => origin + world * zoom;

  void _paintOverlays(Canvas canvas) {
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
      oldDelegate.sim != sim;
}
