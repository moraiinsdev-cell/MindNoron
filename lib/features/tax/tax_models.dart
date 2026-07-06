import 'dart:convert';

/// Business line for the direct %-of-revenue method (Thông tư 40/2021, Phụ lục I).
/// [exportedServices] is the case that matters most for cross-border freelancing:
/// services consumed outside Vietnam bear 0% VAT while still paying 2% PIT.
enum BusinessLine {
  exportedServices,
  services,
  goods,
  production,
  leasing,
  other;

  String get label => switch (this) {
        BusinessLine.exportedServices => 'Dịch vụ xuất khẩu (khách nước ngoài)',
        BusinessLine.services => 'Dịch vụ trong nước',
        BusinessLine.goods => 'Phân phối, cung cấp hàng hóa',
        BusinessLine.production =>
          'Sản xuất, vận tải, dịch vụ gắn với hàng hóa',
        BusinessLine.leasing => 'Cho thuê tài sản',
        BusinessLine.other => 'Kinh doanh khác',
      };
}

/// A VAT%/PIT% pair for the direct method.
class BizRate {
  const BizRate({required this.vat, required this.pit});
  final double vat;
  final double pit;
  double get total => vat + pit;
}

/// One band of the progressive PIT schedule. [upTo] is the monthly upper bound
/// in đồng, or null for the open-ended top bracket.
class ProgressiveBracket {
  const ProgressiveBracket({required this.upTo, required this.rate});
  final int? upTo;
  final double rate;
}

/// Result of taxing foreign income as **employment income** (progressive).
class SalaryTaxResult {
  const SalaryTaxResult({
    required this.annualGross,
    required this.annualTaxableIncome,
    required this.annualTax,
    required this.marginalRate,
  });

  final int annualGross;
  final int annualTaxableIncome;
  final int annualTax;

  /// Highest bracket rate reached — the tax on the next đồng earned.
  final double marginalRate;

  int get annualNet => annualGross - annualTax;

  /// Effective average rate on gross income (0..1).
  double get effectiveRate => annualGross == 0 ? 0 : annualTax / annualGross;
}

/// Result of taxing the same income as an **individual business** (flat method).
class BusinessTaxResult {
  const BusinessTaxResult({
    required this.annualRevenue,
    required this.line,
    required this.vat,
    required this.pit,
    required this.exempt,
  });

  final int annualRevenue;
  final BusinessLine line;
  final int vat;
  final int pit;

  /// True when revenue is at/under the tax-free threshold.
  final bool exempt;

  int get annualTax => vat + pit;
  int get annualNet => annualRevenue - annualTax;
  double get effectiveRate =>
      annualRevenue == 0 ? 0 : annualTax / annualRevenue;
}

/// Year-end outlook computed from revenue booked so far.
class RevenueProjection {
  const RevenueProjection({
    required this.toDate,
    required this.projectedAnnual,
    required this.overThreshold,
    required this.projectedTax,
    required this.thresholdFraction,
  });

  final int toDate;
  final int projectedAnnual;
  final bool overThreshold;

  /// Tax under the exported-services method on the projected annual revenue.
  final int projectedTax;

  /// Revenue-to-date as a fraction of the 500tr exemption threshold (0..).
  final double thresholdFraction;
}

/// One month's booked revenue for the offline revenue tracker.
class RevenueEntry {
  const RevenueEntry({
    required this.id,
    required this.year,
    required this.month,
    required this.amount,
    this.note = '',
  });

  final String id;
  final int year;
  final int month; // 1..12
  final int amount; // đồng
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'y': year,
        'm': month,
        'amt': amount,
        if (note.isNotEmpty) 'note': note,
      };

  static RevenueEntry? fromJson(Map<String, dynamic> j) {
    final amt = (j['amt'] as num?)?.toInt();
    final y = (j['y'] as num?)?.toInt();
    final m = (j['m'] as num?)?.toInt();
    if (amt == null || y == null || m == null) return null;
    return RevenueEntry(
      id: j['id'] as String? ?? '$y-$m-$amt',
      year: y,
      month: m,
      amount: amt,
      note: j['note'] as String? ?? '',
    );
  }

  static String encodeList(List<RevenueEntry> list) =>
      jsonEncode([for (final e in list) e.toJson()]);

  static List<RevenueEntry> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map<String, dynamic>)
            if (RevenueEntry.fromJson(e) case final entry?) entry,
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// The handful of inputs the calculator remembers between sessions, so a
/// freelancer doesn't retype their numbers. Persisted as JSON in settings.
class TaxProfile {
  const TaxProfile({
    this.annualIncome = 0,
    this.dependents = 0,
    this.monthlyInsurance = 0,
    this.line = BusinessLine.exportedServices,
  });

  /// Annual foreign income, in đồng.
  final int annualIncome;
  final int dependents;

  /// Monthly mandatory insurance deductible from salary-method taxable income.
  final int monthlyInsurance;
  final BusinessLine line;

  TaxProfile copyWith({
    int? annualIncome,
    int? dependents,
    int? monthlyInsurance,
    BusinessLine? line,
  }) =>
      TaxProfile(
        annualIncome: annualIncome ?? this.annualIncome,
        dependents: dependents ?? this.dependents,
        monthlyInsurance: monthlyInsurance ?? this.monthlyInsurance,
        line: line ?? this.line,
      );

  Map<String, dynamic> toJson() => {
        'income': annualIncome,
        'deps': dependents,
        'ins': monthlyInsurance,
        'line': line.name,
      };

  static TaxProfile fromJson(Map<String, dynamic> j) => TaxProfile(
        annualIncome: (j['income'] as num?)?.toInt() ?? 0,
        dependents: (j['deps'] as num?)?.toInt() ?? 0,
        monthlyInsurance: (j['ins'] as num?)?.toInt() ?? 0,
        line: BusinessLine.values.firstWhere(
          (l) => l.name == j['line'],
          orElse: () => BusinessLine.exportedServices,
        ),
      );

  String encode() => jsonEncode(toJson());

  static TaxProfile decode(String? raw) {
    if (raw == null || raw.isEmpty) return const TaxProfile();
    try {
      final j = jsonDecode(raw);
      if (j is Map<String, dynamic>) return fromJson(j);
    } catch (_) {}
    return const TaxProfile();
  }
}
