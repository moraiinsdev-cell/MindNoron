import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/features/office/office_catalog.dart';
import 'package:mind_noron/features/office/office_economy.dart';
import 'package:mind_noron/features/office/office_map.dart';
import 'package:mind_noron/features/office/office_models.dart';
import 'package:mind_noron/features/office/office_sim.dart';

void main() {
  OfficeSim freshSim() {
    final sim = OfficeSim(seed: 7);
    sim.syncStaff(defaultStaff());
    sim.placeInitial();
    return sim;
  }

  group('pokeAt', () {
    test('pool water splashes', () {
      final sim = freshSim();
      final kind = sim.pokeAt(tileCenter(const Point(45, 10)));
      expect(kind, PokeKind.splash);
      expect(sim.particles.particles, isNotEmpty);
      expect(sim.floatingTexts, isNotEmpty);
    });

    test('café counter brews coffee with steam', () {
      final sim = freshSim();
      final kind = sim.pokeAt(tileCenter(const Point(15, 25)));
      expect(kind, PokeKind.coffee);
      expect(sim.particles.particles, isNotEmpty);
    });

    test('a plant reacts as plant', () {
      final sim = freshSim();
      // A plant sits at tile (1, 2).
      final kind = sim.pokeAt(tileCenter(const Point(1, 2)));
      expect(kind, PokeKind.plant);
    });

    test('empty floor returns none', () {
      final sim = freshSim();
      final kind = sim.pokeAt(tileCenter(const Point(5, 5)));
      expect(kind, PokeKind.none);
    });
  });

  test('floating labels expire over time', () {
    final sim = freshSim();
    sim.floating(const Offset(100, 100), 'hi', ttl: 0.5);
    expect(sim.floatingTexts, isNotEmpty);
    for (var i = 0; i < 20; i++) {
      sim.tick(0.05); // 1s total
    }
    expect(sim.floatingTexts, isEmpty);
  });

  test('objectAt finds furniture footprints', () {
    expect(objectAt(const Point(1, 2)), isNotNull); // corridor plant
    expect(objectAt(const Point(5, 5)), isNull); // open floor
  });

  group('god powers', () {
    test('praise lifts social and showers hearts', () {
      final sim = freshSim();
      final e = sim.employees.first;
      e.social = 0.2;
      sim.commandPraise(e.spec.id);
      expect(e.social, greaterThan(0.2));
      expect(sim.floatingTexts.where((f) => f.text == '❤️'), isNotEmpty);
      expect(sim.particles.particles, isNotEmpty);
    });

    test('motivate refills energy', () {
      final sim = freshSim();
      final e = sim.employees.first;
      e.energy = 0.1;
      sim.commandMotivate(e.spec.id);
      expect(e.energy, greaterThan(0.4));
    });

    test('commandPool sends the employee walking toward the pool', () {
      final sim = freshSim();
      final e = sim.employees.first;
      sim.commandPool(e.spec.id);
      expect(e.goal, Goal.swim);
      expect(e.activity, Activity.walking);
    });
  });

  group('build mode placement', () {
    OfficeSim layoutSim() {
      final sim = OfficeSim(seed: 7);
      sim.syncStaff(defaultStaff()); // employees parked at the door
      sim.syncLayout(const []);
      return sim;
    }

    test('canPlaceAt respects walls, door and pool', () {
      final sim = layoutSim();
      final plant = catalogItem('plant')!;
      expect(sim.canPlaceAt(plant, 5, 5), isTrue); // open Tasks floor
      expect(sim.canPlaceAt(plant, 0, 0), isFalse); // outer wall
      expect(sim.canPlaceAt(plant, doorTile.x, doorTile.y), isFalse); // door
      expect(sim.canPlaceAt(plant, 45, 10), isFalse); // pool water
    });

    test('placing a blocking item updates collision + placedAt', () {
      final sim = layoutSim();
      sim.syncLayout(const [PlacedItem(itemId: 'bookshelf', tx: 5, ty: 5)]);
      expect(isWalkable(5, 5), isFalse);
      expect(sim.placedAt(const Point(5, 5))?.itemId, 'bookshelf');
      // Can't stack another item on the same tile.
      expect(sim.canPlaceAt(catalogItem('plant')!, 5, 5), isFalse);
    });

    test('non-blocking decor (cushion) stays walkable', () {
      final sim = layoutSim();
      sim.syncLayout(const [PlacedItem(itemId: 'cushion', tx: 6, ty: 6)]);
      expect(isWalkable(6, 6), isTrue);
      expect(sim.placedAt(const Point(6, 6))?.itemId, 'cushion');
    });

    test('multi-tile footprint blocks all covered tiles', () {
      final sim = layoutSim();
      sim.syncLayout(const [PlacedItem(itemId: 'sofa', tx: 5, ty: 6)]); // 2 wide
      expect(isWalkable(5, 6), isFalse);
      expect(isWalkable(6, 6), isFalse);
    });
  });

  test('random events fire without throwing and leave a trace', () {
    final sim = freshSim();
    var leftMark = false;
    for (var i = 0; i < 60; i++) {
      sim.triggerRandomEvent();
      if (sim.floatingTexts.isNotEmpty ||
          sim.employees.any((e) => e.bubble != null) ||
          sim.cat.bubble != null) {
        leftMark = true;
      }
    }
    expect(leftMark, isTrue);
  });
}
