import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/features/office/office_economy.dart';

void main() {
  group('OfficeEconomy', () {
    test('earn adds to balance and lifetime, records credited task', () {
      const start = OfficeEconomy();
      final after = start.earn(15, taskId: 'task-1');
      expect(after.coins, 15);
      expect(after.totalEarned, 15);
      expect(after.hasCredited('task-1'), isTrue);
      expect(after.hasCredited('task-2'), isFalse);
    });

    test('trySpend only succeeds when affordable', () {
      final wallet = const OfficeEconomy().earn(20);
      expect(wallet.trySpend(25), isNull);
      final spent = wallet.trySpend(12);
      expect(spent, isNotNull);
      expect(spent!.coins, 8);
      // totalEarned is untouched by spending.
      expect(spent.totalEarned, 20);
    });

    test('unlock records ownership', () {
      final owned = const OfficeEconomy().unlock('fishtank');
      expect(owned.owns('fishtank'), isTrue);
      expect(owned.owns('jukebox'), isFalse);
    });

    test('JSON round-trip preserves all fields', () {
      final original = const OfficeEconomy(focusSessions: 3)
          .earn(40, taskId: 'a')
          .earn(10, taskId: 'b')
          .unlock('rug');
      final restored = OfficeEconomy.decode(original.encode());
      expect(restored.coins, original.coins);
      expect(restored.totalEarned, original.totalEarned);
      expect(restored.unlockedItemIds, original.unlockedItemIds);
      expect(restored.creditedTaskIds, original.creditedTaskIds);
      expect(restored.focusSessions, original.focusSessions);
    });

    test('decode tolerates garbage and empty input', () {
      expect(OfficeEconomy.decode(null).coins, 0);
      expect(OfficeEconomy.decode('').coins, 0);
      expect(OfficeEconomy.decode('not json{').coins, 0);
    });

    test('credited ledger is capped to recent ids', () {
      var economy = const OfficeEconomy();
      for (var i = 0; i < 600; i++) {
        economy = economy.earn(1, taskId: 'task-$i');
      }
      final restored = OfficeEconomy.decode(economy.encode());
      expect(restored.creditedTaskIds.length, 500);
      // The most recent id survives the cap; an early one is dropped.
      expect(restored.hasCredited('task-599'), isTrue);
      expect(restored.hasCredited('task-0'), isFalse);
    });
  });

  group('PlacedItem', () {
    test('list JSON round-trip', () {
      const items = [
        PlacedItem(itemId: 'sofa', tx: 4, ty: 5),
        PlacedItem(itemId: 'lamp', tx: 10, ty: 2, rot: 2),
      ];
      final restored = PlacedItem.decodeList(PlacedItem.encodeList(items));
      expect(restored.length, 2);
      expect(restored[0].itemId, 'sofa');
      expect(restored[1].rot, 2);
      expect(restored[1].tx, 10);
    });

    test('decodeList drops malformed entries', () {
      expect(PlacedItem.decodeList(null), isEmpty);
      expect(PlacedItem.decodeList('[{"tx":1}]'), isEmpty); // no itemId
    });
  });
}
