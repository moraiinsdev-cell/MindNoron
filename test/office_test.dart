import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/features/office/office_map.dart';
import 'package:mind_noron/features/office/office_models.dart';
import 'package:mind_noron/features/office/office_sim.dart';
import 'package:mind_noron/features/office/office_sprites.dart';

void main() {
  group('sprite integrity', () {
    test('character frames are uniform 12-wide grids', () {
      for (final frame in CharFrame.values) {
        for (var style = 0; style < hairStyleCount; style++) {
          final rows = characterRows(frame, style);
          for (final row in rows) {
            expect(row.length, 12,
                reason: 'frame $frame style $style row "$row"');
          }
          // Movement frames of the same facing must share a height so the
          // walk cycle doesn't jitter vertically.
          expect(rows.length, greaterThanOrEqualTo(12));
        }
      }
    });

    test('all walk frames per facing have equal heights', () {
      for (var style = 0; style < hairStyleCount; style++) {
        int h(CharFrame f) => characterRows(f, style).length;
        expect(h(CharFrame.downWalkA), h(CharFrame.downIdle));
        expect(h(CharFrame.downWalkB), h(CharFrame.downIdle));
        expect(h(CharFrame.upWalkA), h(CharFrame.upIdle));
        expect(h(CharFrame.upWalkB), h(CharFrame.upIdle));
        expect(h(CharFrame.sideWalkA), h(CharFrame.sideIdle));
        expect(h(CharFrame.sideWalkB), h(CharFrame.sideIdle));
      }
    });

    test('character frames only use palette characters', () {
      final allowed = {...characterBasePalette.keys, '.', ' '};
      for (final frame in CharFrame.values) {
        for (var style = 0; style < hairStyleCount; style++) {
          for (final row in characterRows(frame, style)) {
            for (final ch in row.split('')) {
              expect(allowed.contains(ch), isTrue,
                  reason: 'unknown pixel "$ch" in $frame style $style');
            }
          }
        }
      }
    });

    test('furniture sprites are uniform grids with known palette chars', () {
      final sprites = [
        deskSprite,
        chairSprite,
        plantSprite,
        waterCoolerSprite,
        coffeeCounterSprite,
        sofaSprite,
        bookshelfSprite,
        vendingSprite,
        whiteboardSprite,
        posterSprite,
        windowSprite,
        printerSprite,
        meetingTableSprite,
        loungeTableSprite,
        clockSprite,
        paperStackSprite,
      ];
      final problems = <String>[];
      for (var i = 0; i < sprites.length; i++) {
        final sprite = sprites[i];
        for (var r = 0; r < sprite.rows.length; r++) {
          final row = sprite.rows[r];
          if (row.length != sprite.width) {
            problems.add(
                'sprite #$i row $r: width ${row.length} != ${sprite.width}');
          }
          for (final ch in row.split('')) {
            if (ch == '.' || ch == ' ') continue;
            if (!sprite.palette.containsKey(ch)) {
              problems.add('sprite #$i row $r: pixel "$ch" not in palette');
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('office map', () {
    test('all key spots are walkable', () {
      for (final desk in officeDesks) {
        expect(isWalkable(desk.seatTile.x, desk.seatTile.y), isTrue,
            reason: 'desk ${desk.index} seat blocked');
      }
      expect(isWalkable(coffeeSpot.x, coffeeSpot.y), isTrue);
      expect(isWalkable(vendingSpot.x, vendingSpot.y), isTrue);
      for (final approach in sofaApproach) {
        expect(isWalkable(approach.x, approach.y), isTrue);
      }
      for (final spot in chatSpots) {
        expect(isWalkable(spot.a.x, spot.a.y), isTrue,
            reason: 'chat A ${spot.a} blocked');
        expect(isWalkable(spot.b.x, spot.b.y), isTrue,
            reason: 'chat B ${spot.b} blocked');
      }
      for (final spot in wanderSpots) {
        expect(isWalkable(spot.x, spot.y), isTrue,
            reason: 'wander $spot blocked');
      }
    });

    test('every spot is reachable from the front door', () {
      const door = Point(14, 18);
      expect(isWalkable(door.x, door.y), isTrue);
      final targets = [
        for (final d in officeDesks) d.seatTile,
        coffeeSpot,
        vendingSpot,
        ...sofaApproach,
        for (final s in chatSpots) ...[s.a, s.b],
        ...wanderSpots,
      ];
      for (final t in targets) {
        expect(findPath(door, t), isNotNull, reason: '$t unreachable');
      }
    });

    test('paths only cross walkable tiles', () {
      final path = findPath(const Point(14, 18), officeDesks.first.seatTile)!;
      for (final p in path) {
        expect(isWalkable(p.x, p.y), isTrue);
      }
      expect(path.last, officeDesks.first.seatTile);
    });

    test('nearestWalkable escapes furniture', () {
      final desk = officeDesks.first;
      final out = nearestWalkable(Point(desk.tx, desk.ty));
      expect(isWalkable(out.x, out.y), isTrue);
    });
  });

  group('employee codec', () {
    test('round-trips specs', () {
      final staff = defaultStaff();
      final decoded = EmployeeSpec.decodeList(EmployeeSpec.encodeList(staff));
      expect(decoded.length, staff.length);
      expect(decoded.first.name, staff.first.name);
      expect(decoded.last.personalityId, staff.last.personalityId);
      expect(decoded[1].look.shirt, staff[1].look.shirt);
    });

    test('tolerates garbage', () {
      expect(EmployeeSpec.decodeList(null), isEmpty);
      expect(EmployeeSpec.decodeList(''), isEmpty);
      expect(EmployeeSpec.decodeList('not json'), isEmpty);
      expect(EmployeeSpec.decodeList('{"a":1}'), isEmpty);
    });

    test('default staff have unique ids and fit the office', () {
      final staff = defaultStaff();
      expect(staff.map((e) => e.id).toSet().length, staff.length);
      expect(staff.length, lessThanOrEqualTo(maxStaff));
      expect(staff.length, lessThanOrEqualTo(officeDesks.length));
    });

    test('new hires avoid existing names', () {
      final rng = Random(7);
      final staff = defaultStaff();
      final hire = rollNewHire(rng, staff);
      expect(staff.map((e) => e.name), isNot(contains(hire.name)));
      expect(hire.id, isNotEmpty);
    });
  });

  group('simulation', () {
    OfficeSim boot() {
      final sim = OfficeSim(seed: 42);
      sim.syncStaff(defaultStaff());
      sim.placeInitial();
      return sim;
    }

    test('everyone starts working at a desk', () {
      final sim = boot();
      expect(sim.employees.length, 8);
      for (final e in sim.employees) {
        expect(e.activity, Activity.working);
        expect(e.deskIndex, greaterThanOrEqualTo(0));
      }
      // All desk claims unique.
      final desks = sim.employees.map((e) => e.deskIndex).toSet();
      expect(desks.length, 8);
    });

    test('exhausted employees head for a break', () {
      final sim = boot();
      final e = sim.employees.first;
      e.energy = 0.01;
      e.coffeeCooldown = 0;
      // A few ticks: the FSM should send them walking to a refreshment.
      for (var i = 0; i < 60 && e.activity == Activity.working; i++) {
        sim.tick(0.1);
      }
      expect(e.activity, Activity.walking);
      expect([Goal.coffee, Goal.snack, Goal.sofa], contains(e.goal));
    });

    test('lonely employees pair up for a chat', () {
      final sim = boot();
      final a = sim.employees[0];
      final b = sim.employees[1];
      for (final e in sim.employees) {
        e.social = 1; // nobody else wants to chat
      }
      a.social = 0.1;
      b.social = 0.1;
      a.chatCooldown = 0;
      b.chatCooldown = 0;
      sim.tick(0.016);
      expect(a.chatPartnerId, b.spec.id);
      expect(b.chatPartnerId, a.spec.id);
      expect(a.goal, Goal.chat);
      expect(b.goal, Goal.chat);

      // Let them walk there and talk — both should eventually chat.
      for (var i = 0; i < 1200; i++) {
        sim.tick(0.05);
        if (a.activity == Activity.chatting &&
            b.activity == Activity.chatting) {
          break;
        }
      }
      expect(a.activity, Activity.chatting);
      expect(b.activity, Activity.chatting);
    });

    test('drag & drop onto open floor stuns, then they recover', () {
      final sim = boot();
      final e = sim.employees.first;
      sim.beginDrag(e.spec.id);
      expect(e.activity, Activity.dragged);
      sim.dragTo(e.spec.id, const Offset(15 * 16.0, 17 * 16.0));
      sim.drop(e.spec.id);
      expect(e.activity, Activity.stunned);
      for (var i = 0; i < 40; i++) {
        sim.tick(0.1);
      }
      expect(e.activity, isNot(Activity.stunned));
    });

    test('dropping on a desk claims it and evicts the owner', () {
      final sim = boot();
      final newcomer = sim.employees[1];
      final owner = sim.employees
          .firstWhere((x) => x.deskIndex == 0 && x != newcomer);
      sim.beginDrag(newcomer.spec.id);
      final desk = officeDesks[0];
      sim.dragTo(newcomer.spec.id, desk.seatPos);
      sim.drop(newcomer.spec.id);
      expect(newcomer.deskIndex, 0);
      expect(newcomer.activity, Activity.working);
      expect(owner.deskIndex, -1);
    });

    test('dropping on the sofa starts a nap', () {
      final sim = boot();
      final e = sim.employees.first;
      sim.beginDrag(e.spec.id);
      sim.dragTo(e.spec.id, const Offset(20 * 16.0 + 8, 15 * 16.0 + 8));
      sim.drop(e.spec.id);
      expect(e.activity, Activity.sofa);
    });

    test('fired employees disappear from the floor', () {
      final sim = boot();
      final staff = defaultStaff();
      final firedId = staff.first.id;
      sim.selectedId = firedId;
      sim.syncStaff(staff.skip(1).toList());
      expect(sim.employees.length, 7);
      expect(sim.byId(firedId), isNull);
      expect(sim.selectedId, isNull);
    });

    test('hired employees appear at the door', () {
      final sim = boot();
      final staff = [...defaultStaff(), rollNewHire(Random(1), defaultStaff())];
      sim.syncStaff(staff);
      expect(sim.employees.length, 9);
      final hire = sim.employees.last;
      expect(tileAt(hire.pos), const Point(14, 18));
    });

    test('frame selection matches activity', () {
      final sim = boot();
      final e = sim.employees.first;
      expect(sim.frameFor(e).$1, CharFrame.sitBack);
      e.activity = Activity.sofa;
      expect(sim.frameFor(e).$1, CharFrame.sitFront);
      e.activity = Activity.walking;
      e.facing = Facing.left;
      expect(sim.frameFor(e).$2, isTrue); // mirrored
    });

    test('auto task assignment shares the backlog', () {
      final sim = boot();
      sim.openTasks = [('t1', 'Ship the office'), ('t2', 'Water plants')];
      final titles = [
        for (final e in sim.employees) sim.taskTitleFor(e),
      ];
      expect(titles[0], 'Ship the office');
      expect(titles[1], 'Water plants');
      expect(titles[2], isNull); // only as many auto-shares as tasks
    });
  });
}
