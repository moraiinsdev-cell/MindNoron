import 'tax_models.dart';

/// Pure, deterministic Vietnamese personal-tax math for the offline Tax hub.
///
/// Everything here is a plain function over integers (đồng) — no I/O, no state —
/// so it is trivially testable and can never call out to a network. The numbers
/// encode the rules in force from the **2026 tax period** (Nghị quyết về giảm
/// trừ gia cảnh + Luật Thuế GTGT/TNCN sửa đổi), plus the 1/7/2025 changes that
/// matter for someone billing foreign clients.
///
/// ⚠️ This is a planning aid, not tax advice. Brackets and thresholds change;
/// bump [TaxRules.year] and the constants below when the law moves, and always
/// confirm a real filing with a licensed advisor (đại lý thuế).
abstract final class TaxRules {
  const TaxRules._();

  /// Tax period these figures encode.
  static const int year = 2026;

  /// Giảm trừ bản thân — personal deduction, đồng/tháng (from 2026).
  static const int personalDeductionMonthly = 15500000;

  /// Giảm trừ mỗi người phụ thuộc — đồng/tháng (from 2026).
  static const int dependentDeductionMonthly = 6200000;

  /// Hộ/cá nhân kinh doanh: annual revenue at or below this is exempt from both
  /// VAT and PIT (ngưỡng doanh thu không phải nộp thuế, from 2026).
  static const int businessTaxFreeThreshold = 500000000;

  /// Above this revenue an individual business must use the declaration/credit
  /// method rather than the flat %-of-revenue direct method (tham khảo).
  static const int directMethodCeiling = 3000000000;

  /// Biểu thuế lũy tiến từng phần — 7 brackets on *monthly* taxable income
  /// (thu nhập tính thuế = thu nhập - các khoản giảm trừ). Upper bounds in đồng.
  static const List<ProgressiveBracket> progressiveBrackets = [
    ProgressiveBracket(upTo: 5000000, rate: 0.05),
    ProgressiveBracket(upTo: 10000000, rate: 0.10),
    ProgressiveBracket(upTo: 18000000, rate: 0.15),
    ProgressiveBracket(upTo: 32000000, rate: 0.20),
    ProgressiveBracket(upTo: 52000000, rate: 0.25),
    ProgressiveBracket(upTo: 80000000, rate: 0.30),
    ProgressiveBracket(upTo: null, rate: 0.35), // > 80tr
  ];

  /// Tiền chậm nộp — 0,03%/ngày trên số thuế nộp muộn.
  static const double lateDailyRate = 0.0003;

  /// Phạt khai sai dẫn đến thiếu thuế — 20% số thuế thiếu (Luật QLT).
  static const double underreportPenaltyRate = 0.20;

  /// Phạt trốn thuế (hành chính) — 1 đến 3 lần số thuế trốn.
  static const int evasionPenaltyMin = 1;
  static const int evasionPenaltyMax = 3;

  /// Direct-method rates by business line (Thông tư 40/2021, Phụ lục I):
  /// `.vat` = tỷ lệ % thuế GTGT, `.pit` = tỷ lệ % thuế TNCN, on revenue.
  static BizRate rateFor(BusinessLine line) => switch (line) {
        // Dịch vụ xuất khẩu: tiêu dùng ngoài VN → GTGT 0%, TNCN vẫn 2%.
        BusinessLine.exportedServices => const BizRate(vat: 0.0, pit: 0.02),
        BusinessLine.services => const BizRate(vat: 0.05, pit: 0.02),
        BusinessLine.goods => const BizRate(vat: 0.01, pit: 0.005),
        BusinessLine.production => const BizRate(vat: 0.03, pit: 0.015),
        BusinessLine.leasing => const BizRate(vat: 0.05, pit: 0.05),
        BusinessLine.other => const BizRate(vat: 0.02, pit: 0.01),
      };
}

/// Progressive PIT on **employment income** (tiền lương / tiền công) for a full
/// year, given annual gross income and personal circumstances.
///
/// The brackets apply to monthly taxable income, so we work per-month and
/// multiply by 12 (assumes income is spread evenly — a planning simplification).
SalaryTaxResult computeSalaryTax({
  required int annualGross,
  int dependents = 0,
  int monthlyInsurance = 0,
}) {
  final deductionMonthly = TaxRules.personalDeductionMonthly +
      dependents * TaxRules.dependentDeductionMonthly +
      monthlyInsurance;

  final grossMonthly = annualGross ~/ 12;
  final taxableMonthly = grossMonthly - deductionMonthly;

  if (taxableMonthly <= 0) {
    return SalaryTaxResult(
      annualGross: annualGross,
      annualTaxableIncome: 0,
      annualTax: 0,
      marginalRate: 0,
    );
  }

  final taxMonthly = _progressive(taxableMonthly);
  final annualTax = taxMonthly * 12;

  return SalaryTaxResult(
    annualGross: annualGross,
    annualTaxableIncome: taxableMonthly * 12,
    annualTax: annualTax,
    marginalRate: _marginalRate(taxableMonthly),
  );
}

/// Tax for a **household / individual business** (hộ, cá nhân kinh doanh) under
/// the flat direct method: revenue × (VAT% + PIT%), with the annual exemption
/// threshold applied first.
BusinessTaxResult computeBusinessTax({
  required int annualRevenue,
  required BusinessLine line,
}) {
  final rate = TaxRules.rateFor(line);

  if (annualRevenue <= TaxRules.businessTaxFreeThreshold) {
    return BusinessTaxResult(
      annualRevenue: annualRevenue,
      line: line,
      vat: 0,
      pit: 0,
      exempt: true,
    );
  }

  final vat = (annualRevenue * rate.vat).round();
  final pit = (annualRevenue * rate.pit).round();
  return BusinessTaxResult(
    annualRevenue: annualRevenue,
    line: line,
    vat: vat,
    pit: pit,
    exempt: false,
  );
}

/// Projects a full-year revenue picture from income booked so far, and the tax
/// it would attract under the exported-services method (the freelancer's likely
/// optimum). Used by the revenue tracker to warn before the 500tr threshold is
/// crossed rather than after year-end.
RevenueProjection projectRevenue({
  required int toDate,
  required int monthsElapsed,
}) {
  final projectedAnnual =
      monthsElapsed <= 0 ? toDate : (toDate / monthsElapsed * 12).round();
  final biz = computeBusinessTax(
    annualRevenue: projectedAnnual,
    line: BusinessLine.exportedServices,
  );
  return RevenueProjection(
    toDate: toDate,
    projectedAnnual: projectedAnnual,
    overThreshold: projectedAnnual > TaxRules.businessTaxFreeThreshold,
    projectedTax: biz.annualTax,
    thresholdFraction: toDate / TaxRules.businessTaxFreeThreshold,
  );
}

/// Late-payment interest (tiền chậm nộp): 0,03%/ngày × số thuế × số ngày trễ.
int lateFilingPenalty({required int taxOwed, required int daysLate}) {
  if (taxOwed <= 0 || daysLate <= 0) return 0;
  return (taxOwed * TaxRules.lateDailyRate * daysLate).round();
}

/// Estimated total exposure if underreported income is later assessed: the
/// unpaid tax + 20% under-report penalty + accrued late interest. A concrete,
/// sobering number that makes the case for filing honestly.
int underreportExposure({required int taxEvaded, required int daysLate}) {
  final penalty = (taxEvaded * TaxRules.underreportPenaltyRate).round();
  final interest = lateFilingPenalty(taxOwed: taxEvaded, daysLate: daysLate);
  return taxEvaded + penalty + interest;
}

/// Progressive tax on a single month's taxable income (đồng).
int _progressive(int taxable) {
  var remaining = taxable;
  var lower = 0;
  var tax = 0.0;
  for (final b in TaxRules.progressiveBrackets) {
    if (remaining <= 0) break;
    final span = b.upTo == null ? remaining : (b.upTo! - lower);
    final taxedHere = remaining < span ? remaining : span;
    tax += taxedHere * b.rate;
    remaining -= taxedHere;
    lower = b.upTo ?? lower;
  }
  return tax.round();
}

double _marginalRate(int taxableMonthly) {
  for (final b in TaxRules.progressiveBrackets) {
    if (b.upTo == null || taxableMonthly <= b.upTo!) return b.rate;
  }
  return TaxRules.progressiveBrackets.last.rate;
}
