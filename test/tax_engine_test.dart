import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/features/tax/tax_engine.dart';
import 'package:mind_noron/features/tax/tax_models.dart';

void main() {
  group('computeBusinessTax', () {
    test('revenue at/under 500tr threshold is exempt', () {
      final r = computeBusinessTax(
        annualRevenue: 500000000,
        line: BusinessLine.exportedServices,
      );
      expect(r.exempt, isTrue);
      expect(r.annualTax, 0);
      expect(r.annualNet, 500000000);
    });

    test('exported services above threshold: VAT 0%, PIT 2%', () {
      final r = computeBusinessTax(
        annualRevenue: 1000000000, // 1 tỷ
        line: BusinessLine.exportedServices,
      );
      expect(r.exempt, isFalse);
      expect(r.vat, 0); // 0% VAT for exported services
      expect(r.pit, 20000000); // 2% of 1 tỷ
      expect(r.annualTax, 20000000);
      expect(r.effectiveRate, closeTo(0.02, 1e-9));
    });

    test('domestic services: VAT 5% + PIT 2% = 7%', () {
      final r = computeBusinessTax(
        annualRevenue: 1000000000,
        line: BusinessLine.services,
      );
      expect(r.vat, 50000000);
      expect(r.pit, 20000000);
      expect(r.annualTax, 70000000);
    });

    test('goods distribution: VAT 1% + PIT 0.5%', () {
      final r = computeBusinessTax(
        annualRevenue: 2000000000,
        line: BusinessLine.goods,
      );
      expect(r.vat, 20000000);
      expect(r.pit, 10000000);
    });
  });

  group('computeSalaryTax (progressive, 2026 deductions)', () {
    test('income fully covered by personal deduction is untaxed', () {
      // 15tr/month * 12 = 180tr < 186tr personal deduction
      final r = computeSalaryTax(annualGross: 180000000);
      expect(r.annualTax, 0);
      expect(r.annualTaxableIncome, 0);
    });

    test('single earner just into the first bracket', () {
      // 20tr/month gross - 15.5tr deduction = 4.5tr taxable @ 5%
      final r = computeSalaryTax(annualGross: 240000000);
      expect(r.annualTaxableIncome, 54000000); // 4.5tr * 12
      expect(r.annualTax, (4500000 * 0.05).round() * 12); // 225k/mo * 12
      expect(r.marginalRate, 0.05);
    });

    test('dependents lower the taxable base', () {
      final without = computeSalaryTax(annualGross: 600000000);
      final with2 = computeSalaryTax(annualGross: 600000000, dependents: 2);
      expect(with2.annualTax, lessThan(without.annualTax));
      // each dependent removes 6.2tr/month from the taxable base
      expect(without.annualTaxableIncome - with2.annualTaxableIncome,
          2 * 6200000 * 12);
    });

    test('high earner reaches the 35% top bracket', () {
      // 100tr/month gross - 15.5tr = 84.5tr taxable -> top bracket
      final r = computeSalaryTax(annualGross: 1200000000);
      expect(r.marginalRate, 0.35);
      expect(r.annualTax, greaterThan(0));
      expect(r.effectiveRate, lessThan(0.35)); // average < marginal
    });

    test('progressive monthly tax matches the quick-deduction formula', () {
      // 40tr/month gross - 15.5tr = 24.5tr taxable.
      // Bracketed: 5%*5 + 10%*5 + 15%*8 + 20%*6.5 = 0.25+0.5+1.2+1.3 = 3.25tr/mo
      final r = computeSalaryTax(annualGross: 480000000);
      expect(r.annualTax, 3250000 * 12);
      expect(r.marginalRate, 0.20);
    });
  });

  group('computeCompanyTax', () {
    test('CIT 20% + dividend 5% when profit distributed', () {
      // 1 tỷ revenue, 30% expenses -> 700tr profit
      final r = computeCompanyTax(
        revenue: 1000000000,
        expenseRatioPct: 30,
      );
      expect(r.profit, 700000000);
      expect(r.cit, 140000000); // 20% of 700tr
      expect(r.dividendTax, (560000000 * 0.05).round()); // 5% of after-CIT
      expect(r.annualTax, 140000000 + 28000000);
      expect(r.ownerNet, 700000000 - r.annualTax);
    });

    test('retained profit skips dividend tax', () {
      final r = computeCompanyTax(
        revenue: 1000000000,
        expenseRatioPct: 30,
        distribute: false,
      );
      expect(r.dividendTax, 0);
      expect(r.annualTax, 140000000);
    });

    test('no profit -> no tax', () {
      final r = computeCompanyTax(revenue: 100000000, expenseRatioPct: 100);
      expect(r.profit, 0);
      expect(r.annualTax, 0);
    });
  });

  group('projectRevenue', () {
    test('annualizes mid-year revenue by run-rate', () {
      // 300tr booked over 6 months -> 600tr projected.
      final p = projectRevenue(toDate: 300000000, monthsElapsed: 6);
      expect(p.projectedAnnual, 600000000);
      expect(p.overThreshold, isTrue); // > 500tr
      expect(p.projectedTax, (600000000 * 0.02).round()); // 2% exported
      expect(p.thresholdFraction, closeTo(0.6, 1e-9)); // 300/500
    });

    test('stays under threshold -> no projected tax', () {
      final p = projectRevenue(toDate: 100000000, monthsElapsed: 6);
      expect(p.projectedAnnual, 200000000);
      expect(p.overThreshold, isFalse);
      expect(p.projectedTax, 0);
    });

    test('zero months elapsed does not divide by zero', () {
      final p = projectRevenue(toDate: 50000000, monthsElapsed: 0);
      expect(p.projectedAnnual, 50000000);
    });
  });

  group('penalties', () {
    test('late-filing interest is 0.03%/day', () {
      // 10tr owed, 100 days late -> 0.0003 * 100 * 10tr = 300k
      expect(lateFilingPenalty(taxOwed: 10000000, daysLate: 100), 300000);
    });

    test('no penalty for on-time or zero tax', () {
      expect(lateFilingPenalty(taxOwed: 10000000, daysLate: 0), 0);
      expect(lateFilingPenalty(taxOwed: 0, daysLate: 100), 0);
    });

    test('underreport exposure = tax + 20% + interest', () {
      // 100tr evaded, 200 days: 100tr + 20tr + 0.0003*200*100tr(6tr) = 126tr
      final exposure =
          underreportExposure(taxEvaded: 100000000, daysLate: 200);
      expect(exposure, 100000000 + 20000000 + 6000000);
    });
  });

  group('convertPayout (Robux → USD → đồng)', () {
    test('DevEx converts Robux at the configured rate', () {
      // 100.000 Robux @ $0.0035 = $350; @ 26.000đ = 9.100.000đ gross.
      final p = convertPayout(robux: 100000, feePct: 0);
      expect(p.usdFromRobux, closeTo(350, 1e-9));
      expect(p.usdGross, closeTo(350, 1e-9));
      expect(p.vndGross, 9100000);
      expect(p.vndNet, 9100000); // no fee
    });

    test('fees reduce what lands in the bank but NOT the taxable base', () {
      final p = convertPayout(robux: 100000, feePct: 4.4);
      expect(p.vndGross, 9100000); // taxable revenue is unchanged by fees
      expect(p.vndFee, (9100000 * 0.044).round());
      expect(p.vndNet, 9100000 - p.vndFee);
      expect(p.feeRate, closeTo(0.044, 1e-3));
    });

    test('Robux and direct USD are summed into one gross', () {
      final p = convertPayout(robux: 100000, usd: 650, feePct: 0);
      expect(p.usdGross, closeTo(1000, 1e-9)); // 350 + 650
      expect(p.vndGross, 26000000);
    });

    test('empty payout is zero, not a crash', () {
      final p = convertPayout();
      expect(p.vndGross, 0);
      expect(p.feeRate, 0);
    });
  });

  group('annualRevenueOf', () {
    test('vnd mode uses the annual figure directly', () {
      const p = TaxProfile(mode: IncomeMode.vnd, annualIncome: 600000000);
      expect(annualRevenueOf(p), 600000000);
    });

    test('usdRobux mode annualizes the monthly Robux + USD', () {
      // 50.000 Robux/mo = 600.000 Robux/yr = $2.100; plus $1.000/mo = $12.000.
      // Total $14.100 × 26.000 = 366.600.000đ.
      const p = TaxProfile(
        mode: IncomeMode.usdRobux,
        monthlyRobux: 50000,
        monthlyUsd: 1000,
      );
      expect(annualRevenueOf(p), 366600000);
    });

    test('gross ignores the payout fee — fees are not a tax deduction', () {
      const withFee = TaxProfile(
        mode: IncomeMode.usdRobux,
        monthlyUsd: 1000,
        payoutFeePct: 10,
      );
      const noFee = TaxProfile(
        mode: IncomeMode.usdRobux,
        monthlyUsd: 1000,
        payoutFeePct: 0,
      );
      expect(annualRevenueOf(withFee), annualRevenueOf(noFee));
    });
  });

  group('exemptionCliff', () {
    test('crossing 500tr taxes the whole revenue, creating a dead zone', () {
      final c = exemptionCliff();
      expect(c.threshold, 500000000);
      expect(c.taxAtCrossing, 10000000); // 2% of the ENTIRE 500tr, not the excess
      // Net(R) = 0.98R must beat 500tr ⇒ R > 500tr / 0.98 ≈ 510,2tr.
      expect(c.deadZoneTop, (500000000 / 0.98).round());
      expect(c.contains(505000000), isTrue); // worse off than stopping at 500tr
      expect(c.contains(500000000), isFalse); // exactly at the threshold: exempt
      expect(c.contains(600000000), isFalse); // clear of the zone
    });

    test('earning inside the dead zone really does leave you poorer', () {
      final atThreshold = computeBusinessTax(
        annualRevenue: 500000000,
        line: BusinessLine.exportedServices,
      );
      final justOver = computeBusinessTax(
        annualRevenue: 505000000,
        line: BusinessLine.exportedServices,
      );
      expect(justOver.annualNet, lessThan(atThreshold.annualNet));
    });
  });

  group('planRemainingYear (today → 31/12)', () {
    // 12/7/2026: 193 days gone, 172 left in a 365-day year.
    final today = DateTime(2026, 7, 12);

    test('splits the year by real days, not whole months', () {
      final p = planRemainingYear(revenueToDate: 0, today: today);
      expect(p.daysElapsed, 193);
      expect(p.daysRemaining, 172);
      expect(p.daysElapsed + p.daysRemaining, 365);
      expect(p.yearEnd, DateTime(2026, 12, 31));
    });

    test('projects year-end on the daily run-rate', () {
      // 193tr booked over 193 days = 1tr/day → +172tr by 31/12 = 365tr.
      final p = planRemainingYear(revenueToDate: 193000000, today: today);
      expect(p.dailyRunRate, closeTo(1000000, 1));
      expect(p.projectedYearEnd, 365000000);
      expect(p.overThreshold, isFalse);
      expect(p.projectedTax, 0);
    });

    test('headroom is what can still be billed tax-free', () {
      final p = planRemainingYear(revenueToDate: 300000000, today: today);
      expect(p.headroom, 200000000); // 500tr - 300tr
      expect(p.extraToClearCliff, 0); // threshold not crossed yet
    });

    test('past the threshold, headroom is gone and the cliff distance shows',
        () {
      // 505tr booked: over 500tr but still inside the dead zone (< 510,2tr).
      final p = planRemainingYear(revenueToDate: 505000000, today: today);
      expect(p.headroom, 0);
      expect(p.extraToClearCliff, p.cliff.deadZoneTop - 505000000);
      expect(p.extraToClearCliff, greaterThan(0));
    });

    test('clear of the dead zone, there is nothing left to clear', () {
      final p = planRemainingYear(revenueToDate: 700000000, today: today);
      expect(p.headroom, 0);
      expect(p.extraToClearCliff, 0);
      expect(p.overThreshold, isTrue);
    });

    test('a run-rate landing in the dead zone is flagged', () {
      // 267tr over 193 days → ~505tr by year end: earning more, keeping less.
      final p = planRemainingYear(revenueToDate: 267000000, today: today);
      expect(p.projectedInDeadZone, isTrue);
    });

    test('1 January does not divide by zero', () {
      final p =
          planRemainingYear(revenueToDate: 0, today: DateTime(2026, 1, 1));
      expect(p.daysElapsed, 1);
      expect(p.daysRemaining, 364);
      expect(p.projectedYearEnd, 0);
    });
  });

  group('computeReserve', () {
    test('above the threshold, reserves the effective rate plus a buffer', () {
      final r = computeReserve(
        revenueToDate: 500000000,
        projectedAnnualRevenue: 1000000000,
      );
      expect(r.projectedTax, 20000000); // 2% of 1 tỷ
      // 2% × (1 + 20% buffer) = 2,4%
      expect(r.reserveRate, closeTo(0.024, 1e-9));
      expect(r.shouldHaveBanked, (500000000 * 0.024).round());
      expect(r.perPayoutHint, 240000); // per 10tr received
    });

    test('well under the threshold, nothing to reserve', () {
      final r = computeReserve(
        revenueToDate: 100000000,
        projectedAnnualRevenue: 200000000,
      );
      expect(r.projectedTax, 0);
      expect(r.reserveRate, 0);
      expect(r.shouldHaveBanked, 0);
    });

    test('approaching the threshold ramps the reserve up before the cliff', () {
      // 450tr projected: exempt today, but one more invoice tips the whole year.
      final r = computeReserve(
        revenueToDate: 300000000,
        projectedAnnualRevenue: 450000000,
      );
      expect(r.projectedTax, 0); // still exempt
      expect(r.reserveRate, greaterThan(0)); // but reserve anyway
      expect(r.reserveRate, lessThan(0.024)); // ramping, not yet full rate
    });
  });

  group('optimization comparison', () {
    test('exported-services registration beats salary for high foreign income',
        () {
      const income = 1200000000; // 1.2 tỷ/năm
      final salary = computeSalaryTax(annualGross: income);
      final business = computeBusinessTax(
        annualRevenue: income,
        line: BusinessLine.exportedServices,
      );
      expect(business.annualTax, lessThan(salary.annualTax));
      // business is a flat 2%; salary is much heavier at this level
      expect(business.annualTax, (income * 0.02).round());
    });
  });
}
