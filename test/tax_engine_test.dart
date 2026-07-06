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
