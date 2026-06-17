import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
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
}
