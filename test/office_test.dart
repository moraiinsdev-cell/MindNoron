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
        fridgeSprite,
        kitchenTableSprite,
        stoolSprite,
        armchairSprite,
        filingCabinetSprite,
        serverRackSprite,
        boxSprite,
        treadmillSprite,
        dumbbellRackSprite,
        yogaMatSprite,
        loungerSprite,
        umbrellaSprite,
        cafeTableSprite,
        menuBoardSprite,
        safeSprite,
        moneyPileSprite,
        mailShelfSprite,
        cushionSprite,
        bonsaiSprite,
        lampSprite,
        wallCalendarSprite,
        poolLadderSprite,
        arcadeCabinetSprite,
        jukeboxSprite,
        poolTableSprite,
        tvScreenSprite,
        barCounterSprite,
        catWalkASprite,
        catWalkBSprite,
        catSitSprite,
        catSleepSprite,
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

  group('campus map', () {
    test('all key spots are walkable on every floor', () {
      addTearDown(() => setActiveFloor(0));
      for (var f = 0; f < floorCount; f++) {
        setActiveFloor(f);
        final spots = <String, Point<int>>{
          for (final d in officeDesks) 'desk ${d.index} seat': d.seatTile,
          'coffee': coffeeSpot,
          'vending': vendingSpot,
          'water': waterSpot,
          'snack': snackSpot,
          'swim entry': swimEntry,
          for (var i = 0; i < sofaSeats.length; i++)
            'sofa $i approach': sofaSeats[i].approach,
          for (var i = 0; i < deckSeats.length; i++)
            'deck $i approach': deckSeats[i].approach,
          for (var i = 0; i < cushionSeats.length; i++)
            'cushion $i': cushionSeats[i].approach,
          for (var i = 0; i < readSeats.length; i++)
            'read seat $i approach': readSeats[i].approach,
          for (var i = 0; i < workoutSpots.length; i++)
            'workout $i': workoutSpots[i],
          for (var i = 0; i < cafeSpots.length; i++) 'café $i': cafeSpots[i],
          for (var i = 0; i < readStandSpots.length; i++)
            'read stand $i': readStandSpots[i],
          for (var i = 0; i < chatSpots.length; i++) ...{
            'chat $i A': chatSpots[i].a,
            'chat $i B': chatSpots[i].b,
          },
          for (var i = 0; i < wanderSpots.length; i++)
            'wander $i': wanderSpots[i],
          'door': doorTile,
        };
        for (final entry in spots.entries) {
          expect(isWalkable(entry.value.x, entry.value.y), isTrue,
              reason: 'floor $f: ${entry.key} at ${entry.value} is blocked');
        }
      }
    });

    test('every spot is reachable from the front door on every floor', () {
      addTearDown(() => setActiveFloor(0));
      for (var f = 0; f < floorCount; f++) {
        setActiveFloor(f);
        final targets = [
          for (final d in officeDesks) d.seatTile,
          coffeeSpot,
          vendingSpot,
          waterSpot,
          snackSpot,
          swimEntry,
          for (final s in sofaSeats) s.approach,
          for (final s in deckSeats) s.approach,
          for (final s in cushionSeats) s.approach,
          for (final s in readSeats) s.approach,
          ...workoutSpots,
          ...cafeSpots,
          ...readStandSpots,
          for (final s in chatSpots) ...[s.a, s.b],
          ...wanderSpots,
        ];
        for (final t in targets) {
          expect(findPath(doorTile, t), isNotNull,
              reason: 'floor $f: $t unreachable');
        }
      }
    });

    test('paths only cross walkable tiles', () {
      final path = findPath(doorTile, officeDesks.first.seatTile)!;
      for (final p in path) {
        expect(isWalkable(p.x, p.y), isTrue);
      }
      expect(path.last, officeDesks.first.seatTile);
    });

    test('nearestWalkable escapes furniture and the pool', () {
      final desk = officeDesks.first;
      final out = nearestWalkable(Point(desk.tx, desk.ty));
      expect(isWalkable(out.x, out.y), isTrue);
      final fromPool = nearestWalkable(const Point(46, 10));
      expect(isWalkable(fromPool.x, fromPool.y), isTrue);
    });

    test('pool is not walkable but is a drop target', () {
      expect(isWalkable(46, 10), isFalse);
      expect(isPoolTile(const Point(46, 10)), isTrue);
      expect(isPoolTile(doorTile), isFalse);
    });

    test('rooms cover every named module', () {
      final labels = rooms.map((r) => r.label).toSet();
      for (final expected in [
        'TASKS', 'CALENDAR', 'FINANCE', 'FOCUS', 'LIBRARY', 'INBOX',
        'GYM', 'CAFÉ', 'ANALYTICS', 'LOUNGE', 'POOL',
      ]) {
        expect(labels, contains(expected));
      }
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

    test('default staff have unique ids and each floor fits the office', () {
      final staff = defaultStaff();
      expect(staff.map((e) => e.id).toSet().length, staff.length);
      for (var f = 0; f < floorCount; f++) {
        final onFloor = staffOnFloor(staff, f);
        expect(onFloor, isNotEmpty, reason: 'floor $f has no staff');
        expect(onFloor.length, lessThanOrEqualTo(maxStaff));
        expect(onFloor.length, lessThanOrEqualTo(officeDesks.length));
      }
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
    // One floor's worth of staff (the office screen shows a single floor).
    final floorStaff = staffOnFloor(defaultStaff(), 0);

    OfficeSim boot() {
      final sim = OfficeSim(seed: 42);
      sim.syncStaff(floorStaff);
      sim.placeInitial();
      return sim;
    }

    test('everyone starts working at a desk', () {
      final sim = boot();
      expect(sim.employees.length, floorStaff.length);
      for (final e in sim.employees) {
        expect(e.activity, Activity.working);
        expect(e.deskIndex, greaterThanOrEqualTo(0));
      }
      final desks = sim.employees.map((e) => e.deskIndex).toSet();
      expect(desks.length, sim.employees.length);
    });

    test('exhausted employees head for a break', () {
      final sim = boot();
      final e = sim.employees.first;
      e.energy = 0.01;
      e.coffeeCooldown = 0;
      e.leisureTimer = 9999; // isolate the energy-driven branch
      for (var i = 0; i < 60 && e.activity == Activity.working; i++) {
        sim.tick(0.1);
      }
      expect(e.activity, Activity.walking);
      expect([Goal.coffee, Goal.snack, Goal.sofa], contains(e.goal));
    });

    test('the leisure urge sends employees around the campus', () {
      final sim = boot();
      final found = <Goal>{};
      // Run each employee's leisure roll a few times; across the cast we
      // should see several different campus activities chosen.
      for (var round = 0; round < 6; round++) {
        for (final e in sim.employees) {
          if (e.activity == Activity.working) e.leisureTimer = 0.001;
        }
        for (var i = 0; i < 400; i++) {
          sim.tick(0.1);
          for (final e in sim.employees) {
            if (e.activity == Activity.walking) found.add(e.goal);
          }
        }
      }
      const leisureGoals = {
        Goal.gym, Goal.swim, Goal.sunbathe, Goal.read, Goal.meditate,
        Goal.cafe,
      };
      expect(found.intersection(leisureGoals).length,
          greaterThanOrEqualTo(3),
          reason: 'saw goals: $found');
    });

    test('swimmers paddle inside the pool and climb out', () {
      final sim = boot();
      final e = sim.employees.first;
      sim.beginDrag(e.spec.id);
      sim.dragTo(e.spec.id, const Offset(46 * 16.0, 10 * 16.0));
      sim.drop(e.spec.id);
      expect(e.activity, Activity.swim);
      for (var i = 0; i < 50; i++) {
        sim.tick(0.1);
        if (e.activity != Activity.swim) break;
        expect(swimArea.inflate(2).contains(e.pos), isTrue,
            reason: 'swimmer left the pool at ${e.pos}');
      }
      for (var i = 0; i < 400 && e.activity == Activity.swim; i++) {
        sim.tick(0.1);
      }
      expect(e.activity, isNot(Activity.swim));
    });

    test('lonely employees pair up for a chat', () {
      final sim = boot();
      final a = sim.employees[0];
      final b = sim.employees[1];
      for (final e in sim.employees) {
        e.social = 1;
        e.leisureTimer = 9999;
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

      for (var i = 0; i < 1600; i++) {
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
      sim.dragTo(e.spec.id, const Offset(21 * 16.0, 11 * 16.0));
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
      sim.dragTo(
          e.spec.id, const Offset(31 * 16.0 + 8, 20 * 16.0 + 8));
      sim.drop(e.spec.id);
      expect(e.activity, Activity.sofa);
    });

    test('dropping on a lounger starts sunbathing', () {
      final sim = boot();
      final e = sim.employees.first;
      sim.beginDrag(e.spec.id);
      sim.dragTo(e.spec.id, const Offset(43 * 16.0 + 8, 16 * 16.0 + 8));
      sim.drop(e.spec.id);
      expect(e.activity, Activity.sunbathe);
    });

    test('fired employees disappear from the floor', () {
      final sim = boot();
      final staff = defaultStaff();
      final firedId = staff.first.id;
      sim.selectedId = firedId;
      sim.syncStaff(staff.skip(1).toList());
      expect(sim.employees.length, staff.length - 1);
      expect(sim.byId(firedId), isNull);
      expect(sim.selectedId, isNull);
    });

    test('hired employees appear at the door', () {
      final sim = boot();
      final staff = [...defaultStaff(), rollNewHire(Random(1), defaultStaff())];
      sim.syncStaff(staff);
      expect(sim.employees.length, staff.length);
      final hire = sim.employees.last;
      expect(tileAt(hire.pos), doorTile);
    });

    test('frame selection matches activity', () {
      final sim = boot();
      final e = sim.employees.first;
      expect(sim.frameFor(e).$1, CharFrame.sitBack);
      e.activity = Activity.sofa;
      expect(sim.frameFor(e).$1, CharFrame.sitFront);
      e.activity = Activity.meditate;
      expect(sim.frameFor(e).$1, CharFrame.sitFront);
      e.activity = Activity.gym;
      expect([CharFrame.upWalkA, CharFrame.upWalkB],
          contains(sim.frameFor(e).$1));
      e.activity = Activity.walking;
      e.facing = Facing.left;
      expect(sim.frameFor(e).$2, isTrue); // mirrored
    });

    test('the cat prowls the campus and can be petted', () {
      final sim = boot();
      expect(sim.cat.state, CatState.sitting);
      // Long simulation: the cat must cycle through states without escaping
      // into walls or water.
      var sawWandering = false;
      for (var i = 0; i < 2400; i++) {
        sim.tick(0.05);
        if (sim.cat.state == CatState.wandering) sawWandering = true;
        final t = tileAt(sim.cat.pos);
        expect(isPoolTile(t), isFalse, reason: 'cat fell in the pool');
      }
      expect(sawWandering, isTrue);
      sim.petCat();
      expect(sim.cat.bubble, isNotNull);
    });

    test('butterflies stay over the garden', () {
      final sim = boot();
      for (var i = 0; i < 1200; i++) {
        sim.tick(0.05);
      }
      expect(sim.butterflies.length, 3);
      for (final b in sim.butterflies) {
        expect(b.pos.dx, greaterThan(37 * 16.0),
            reason: 'butterfly drifted indoors');
      }
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
