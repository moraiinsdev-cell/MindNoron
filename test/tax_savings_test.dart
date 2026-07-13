import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/features/tax/tax_repository.dart';
import 'package:mind_noron/features/tax/tax_savings.dart';

/// The envelope math. The rules that must never break: tax comes off the top,
/// nothing overfills, a full envelope's share cascades instead of leaking into
/// spending, and the whole payout is always accounted for.
void main() {
  const spend = 20000000; // 20tr/tháng

  List<SavingsFund> funds() => const [
        SavingsFund(id: 'tax', name: 'Quỹ thuế', kind: FundKind.tax),
        SavingsFund(
            id: 'buffer',
            name: 'Đệm',
            kind: FundKind.buffer,
            sharePct: 20,
            targetMonths: 3),
        SavingsFund(
            id: 'gear',
            name: 'Thiết bị',
            kind: FundKind.gear,
            sharePct: 10,
            targetVnd: 40000000),
        SavingsFund(
            id: 'freedom', name: 'Tự do', kind: FundKind.freedom, sharePct: 10),
      ];

  group('allocatePayout', () {
    test('tax is taken from gross, before any envelope', () {
      final plan = allocatePayout(
        gross: 100000000,
        funds: funds(),
        balances: const {},
        reserveRate: 0.03,
        monthlySpend: spend,
      );

      expect(plan.taxCut, 3000000);
      // Envelope shares are of the after-tax cash, not of gross.
      final buffer = plan.slices.firstWhere((s) => s.fund.id == 'buffer');
      expect(buffer.amount, (97000000 * 0.20).round());
    });

    test('fees shrink the cash but not the tax owed', () {
      final plan = allocatePayout(
        gross: 100000000,
        funds: funds(),
        balances: const {},
        fees: 4000000,
        reserveRate: 0.03,
        monthlySpend: spend,
      );

      expect(plan.netCash, 96000000);
      expect(plan.taxCut, 3000000, reason: 'tax is on revenue, not on net');
      expect(plan.allocated + plan.spendable, plan.netCash);
    });

    test('every đồng that landed is either allocated or spendable', () {
      for (final gross in [1000000, 7500000, 33333333, 250000000]) {
        final plan = allocatePayout(
          gross: gross,
          funds: funds(),
          balances: const {'buffer': 12000000},
          fees: (gross * 0.044).round(),
          reserveRate: 0.024,
          monthlySpend: spend,
        );
        expect(plan.allocated + plan.spendable, plan.netCash,
            reason: 'payout $gross must balance');
      }
    });

    test('an envelope never fills past its target', () {
      // Gear needs 2tr more; a 100tr payout would otherwise pour ~9,7tr in.
      final plan = allocatePayout(
        gross: 100000000,
        funds: funds(),
        balances: const {'gear': 38000000},
        reserveRate: 0.03,
        monthlySpend: spend,
      );

      final gear = plan.slices.firstWhere((s) => s.fund.id == 'gear');
      expect(gear.amount, 2000000);
      expect(gear.filled, isTrue);
    });

    test("a full envelope's share cascades on, it does not become spendable",
        () {
      final full = allocatePayout(
        gross: 100000000,
        funds: funds(),
        // Buffer (60tr target) and gear (40tr) are both full.
        balances: const {'buffer': 60000000, 'gear': 40000000},
        reserveRate: 0.03,
        monthlySpend: spend,
      );

      // 40% of the after-tax cash was earmarked for envelopes; buffer and gear
      // can take none of it, so all of it must land in the bottomless one.
      final freedom = full.slices.firstWhere((s) => s.fund.id == 'freedom');
      expect(freedom.amount, (97000000 * 0.40).round());
      expect(full.spendable, 97000000 - freedom.amount);
    });

    test('targets in months follow the cost of living', () {
      const f = SavingsFund(
          id: 'e', name: 'KC', kind: FundKind.emergency, targetMonths: 6);
      expect(f.targetFor(20000000), 120000000);
      expect(f.targetFor(35000000), 210000000);
      expect(f.targetFor(0), 0, reason: 'unknown living costs = no target');
    });
  });

  group('computeHealth', () {
    test('runway counts only liquid envelopes, and tax money is never yours',
        () {
      final health = computeHealth(
        funds: funds(),
        balances: const {
          'tax': 10000000,
          'buffer': 60000000,
          'gear': 40000000,
          'freedom': 30000000,
        },
        monthlySpend: spend,
        taxShouldHold: 25000000,
      );

      expect(health.total, 140000000);
      expect(health.yours, 130000000, reason: 'tax envelope excluded');
      expect(health.liquid, 60000000, reason: 'gear & freedom are spoken for');
      expect(health.runwayMonths, 3.0);
      expect(health.level, RunwayLevel.ok);
      expect(health.taxGap, 15000000);
      expect(health.taxOnTrack, isFalse);
    });

    test('no living costs means no runway to report', () {
      final health = computeHealth(
        funds: funds(),
        balances: const {'buffer': 60000000},
        monthlySpend: 0,
      );
      expect(health.needsSpend, isTrue);
      expect(health.runwayMonths, 0);
    });
  });

  group('planSelfSalary', () {
    test('pays out of the average, after tax and after saving', () {
      final plan = planSelfSalary(
        monthlyNet: const [40000000, 40000000, 40000000, 40000000],
        monthsElapsed: 4,
        funds: funds(),
        bufferBalance: 60000000,
        monthlySpend: spend,
        reserveRate: 0.025,
      );

      expect(plan.avgMonthlyNet, 40000000);
      expect(plan.taxCut, 1000000);
      expect(plan.savingsCut, ((40000000 - 1000000) * 0.40).round());
      expect(plan.salary, 39000000 - plan.savingsCut);
      expect(plan.sustainable, isTrue);
      expect(plan.bufferCover, closeTo(60000000 / plan.salary, 0.001));
    });

    test('a dry month drags the average down — it is data, not an outlier', () {
      final plan = planSelfSalary(
        monthlyNet: const [60000000, 0, 60000000], // 3 months, one with nothing
        monthsElapsed: 3,
        funds: funds(),
        bufferBalance: 0,
        monthlySpend: spend,
      );
      expect(plan.avgMonthlyNet, 40000000);
      expect(plan.worstMonthNet, 0);
      expect(plan.worstMonthGap, plan.salary);
    });
  });

  test('balances are derived from the ledger', () {
    final txns = [
      FundTxn(
          id: '1',
          fundId: 'buffer',
          at: DateTime(2026, 7, 1),
          amount: 30000000),
      FundTxn(
          id: '2',
          fundId: 'buffer',
          at: DateTime(2026, 7, 5),
          amount: -5000000,
          kind: FundTxnKind.withdraw),
      FundTxn(
          id: '3', fundId: 'tax', at: DateTime(2026, 7, 5), amount: 2000000),
    ];

    expect(balancesOf(txns), {'buffer': 25000000, 'tax': 2000000});
  });

  test('funds round-trip through JSON, and a fresh install gets defaults', () {
    final decoded = SavingsFund.decodeList(SavingsFund.encodeList(funds()));
    expect(decoded.map((f) => f.id), ['tax', 'buffer', 'gear', 'freedom']);
    expect(decoded[1].targetMonths, 3);
    expect(decoded[2].targetVnd, 40000000);

    expect(SavingsFund.decodeList(null), isNotEmpty);
    expect(SavingsFund.decodeList('{corrupt'), isNotEmpty);
  });
}
