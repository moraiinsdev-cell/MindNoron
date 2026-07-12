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

/// Where a payout physically came from. A Roblox 3D freelancer typically mixes
/// three: DevEx cash-outs of Robux, direct USD from studios via PayPal, and the
/// occasional domestic (VND) job. All of them count toward the same 500tr/year
/// revenue threshold — which is exactly why they are logged in one place.
enum PayoutSource {
  devex,
  paypal,
  wire,
  domestic;

  String get label => switch (this) {
        PayoutSource.devex => 'Robux → DevEx',
        PayoutSource.paypal => 'USD qua PayPal',
        PayoutSource.wire => 'Chuyển khoản quốc tế',
        PayoutSource.domestic => 'Khách trong nước (VNĐ)',
      };

  String get icon => switch (this) {
        PayoutSource.devex => '🟩',
        PayoutSource.paypal => '💸',
        PayoutSource.wire => '🏦',
        PayoutSource.domestic => '🇻🇳',
      };

  /// Domestic work is not an exported service — it does not get the VAT 0% rate.
  bool get isForeign => this != PayoutSource.domestic;
}

/// How the calculator's annual revenue figure is entered.
enum IncomeMode {
  /// Straight VND — for someone who already knows their annual number.
  vnd,

  /// USD/month + Robux/month, converted with the profile's DevEx & FX rates.
  usdRobux;

  String get label => switch (this) {
        IncomeMode.vnd => 'Nhập VNĐ',
        IncomeMode.usdRobux => 'USD + Robux',
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

/// Result of routing income through a one-member limited company.
class CompanyTaxResult {
  const CompanyTaxResult({
    required this.revenue,
    required this.profit,
    required this.cit,
    required this.dividendTax,
    required this.distributed,
  });

  final int revenue;
  final int profit;
  final int cit;
  final int dividendTax;
  final bool distributed;

  int get annualTax => cit + dividendTax;

  /// What the owner keeps out of profit after CIT and (optional) dividend tax.
  int get ownerNet => profit - annualTax;

  /// Total tax as a share of revenue — comparable to the other methods.
  double get effectiveRate => revenue == 0 ? 0 : annualTax / revenue;
}

/// One payout traced from Robux all the way to đồng in the bank.
///
/// The two numbers that matter, and that freelancers routinely confuse:
/// [vndGross] is what the taxman counts (revenue), [vndNet] is what you can
/// actually spend. Under the flat 2% method the gap between them — PayPal and
/// FX fees — is *not* deductible, so tax is owed on money you never touched.
class PayoutBreakdown {
  const PayoutBreakdown({
    required this.robux,
    required this.usdFromRobux,
    required this.usdDirect,
    required this.usdGross,
    required this.usdFee,
    required this.vndGross,
    required this.vndFee,
    required this.fxRate,
  });

  final int robux;
  final double usdFromRobux;
  final double usdDirect;
  final double usdGross;
  final double usdFee;

  /// Taxable revenue in đồng.
  final int vndGross;

  /// Payment + conversion cost in đồng.
  final int vndFee;
  final int fxRate;

  double get usdNet => usdGross - usdFee;

  /// What actually lands in the Vietnamese bank account.
  int get vndNet => vndGross - vndFee;

  /// Fees as a share of gross (0..1) — the invisible tax nobody budgets for.
  double get feeRate => vndGross == 0 ? 0 : vndFee / vndGross;
}

/// How much of each payout to park so the tax bill is already funded when it
/// falls due — the difference between a freelancer who controls cash flow and
/// one who panics every April.
class TaxReserve {
  const TaxReserve({
    required this.projectedAnnualRevenue,
    required this.projectedTax,
    required this.reserveRate,
    required this.shouldHaveBanked,
    required this.perPayoutHint,
  });

  final int projectedAnnualRevenue;
  final int projectedTax;

  /// Suggested share of every incoming payout to move into the tax reserve
  /// (effective tax rate + safety buffer), 0..1.
  final double reserveRate;

  /// Given the revenue booked so far, what should already be sitting in the
  /// reserve today.
  final int shouldHaveBanked;

  /// Đồng to set aside per 10 triệu received — an easy mental rule.
  final int perPayoutHint;
}

/// Revenue doesn't just cross one line — it climbs a ladder, and each rung
/// changes what you must *do*, not only what you pay.
///
/// The rate itself is flat (2% of revenue, forever), so scaling up never pushes
/// you into a worse rate the way progressive salary does. What changes at the
/// top rung is the **compliance burden**: a large-scale household business has
/// to keep proper books, and that is usually the moment a company starts to make
/// sense for reasons other than tax.
enum RevenueBand {
  /// ≤ 500tr/năm — no VAT, no PIT.
  exempt,

  /// 500tr → 3 tỷ — flat %-of-revenue (direct) method.
  direct,

  /// Above the large-scale threshold — full bookkeeping, invoices, and a real
  /// decision to make about incorporating.
  largeScale;

  String get label => switch (this) {
        RevenueBand.exempt => 'Miễn thuế',
        RevenueBand.direct => 'Kê khai trực tiếp (% trên doanh thu)',
        RevenueBand.largeScale => 'Quy mô lớn — sổ sách đầy đủ',
      };

  String get range => switch (this) {
        RevenueBand.exempt => '≤ 500 triệu/năm',
        RevenueBand.direct => '500 triệu → 3 tỷ/năm',
        RevenueBand.largeScale => 'trên 3 tỷ/năm',
      };

  String get duty => switch (this) {
        RevenueBand.exempt =>
          'Không phát sinh thuế GTGT & TNCN từ hoạt động kinh doanh. Vẫn nên '
              'đăng ký và ghi sổ — để chứng minh được mình ở dưới ngưỡng.',
        RevenueBand.direct =>
          'Nộp theo tỷ lệ % trên doanh thu (dịch vụ xuất khẩu: GTGT 0% + TNCN '
              '2%). Khai theo quý, dùng hóa đơn điện tử. Không được trừ chi phí '
              '— đổi lại sổ sách rất nhẹ.',
        RevenueBand.largeScale =>
          'Bị coi là hộ kinh doanh quy mô lớn: phải kê khai đầy đủ, chế độ kế '
              'toán và hóa đơn như doanh nghiệp. Đây là lúc so sánh nghiêm túc '
              'với việc lập công ty TNHH — và nên có đại lý thuế.',
      };
}

/// Where a revenue figure sits on the ladder, plus how far it is to the next rung.
class BandPosition {
  const BandPosition({
    required this.band,
    required this.revenue,
    required this.nextRungAt,
    required this.toNextRung,
  });

  final RevenueBand band;
  final int revenue;

  /// Revenue at which the next rung starts, or null if already on the top rung.
  final int? nextRungAt;

  /// Đồng still to bill before reaching [nextRungAt]; 0 on the top rung.
  final int toNextRung;
}

/// The band just above the exemption threshold where earning *more* leaves you
/// with *less*, because crossing 500tr taxes the whole revenue rather than only
/// the excess.
class ExemptionCliff {
  const ExemptionCliff({
    required this.threshold,
    required this.deadZoneTop,
    required this.taxAtCrossing,
  });

  /// 500 triệu — the last fully tax-free đồng.
  final int threshold;

  /// Revenue you must exceed to be better off than stopping at [threshold].
  final int deadZoneTop;

  /// Tax due the moment you go one đồng over — charged on the entire revenue.
  final int taxAtCrossing;

  bool contains(int revenue) => revenue > threshold && revenue < deadZoneTop;
}

/// The picture from *today* to 31/12 — the horizon a freelancer actually plans
/// against, rather than a whole calendar year they are already halfway through.
///
/// It answers three questions in one object: where does the year land if nothing
/// changes ([projectedYearEnd]), how much more can I bill before tax starts
/// ([headroom]), and if I'm about to cross the threshold, how much extra do I
/// need for the crossing to be worth it ([extraToClearCliff]).
class RemainingYearPlan {
  const RemainingYearPlan({
    required this.today,
    required this.yearEnd,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.revenueToDate,
    required this.dailyRunRate,
    required this.projectedYearEnd,
    required this.projectedTax,
    required this.headroom,
    required this.extraToClearCliff,
    required this.cliff,
  });

  final DateTime today;
  final DateTime yearEnd;

  /// Days of the year already gone (1/1 → today, inclusive).
  final int daysElapsed;

  /// Days left to bill in, today → 31/12.
  final int daysRemaining;

  final int revenueToDate;

  /// Đồng per day, averaged over the year so far.
  final double dailyRunRate;

  /// Where the year lands if the current run-rate holds.
  final int projectedYearEnd;

  /// Tax on [projectedYearEnd] under the chosen method.
  final int projectedTax;

  /// How much more can still be billed before the 500tr exemption is lost.
  /// Zero once the threshold is already crossed.
  final int headroom;

  /// Once past the threshold, the extra revenue still needed before crossing
  /// actually pays — i.e. before net income beats simply stopping at 500tr.
  /// Zero when out of the dead zone.
  final int extraToClearCliff;

  final ExemptionCliff cliff;

  bool get overThreshold => projectedYearEnd > cliff.threshold;

  /// True when the *projected* year lands in the band where earning more leaves
  /// you with less — the moment to either push well past it or defer to next year.
  bool get projectedInDeadZone => cliff.contains(projectedYearEnd);

  /// Revenue booked as a share of the 500tr threshold (0..).
  double get thresholdFraction => revenueToDate / cliff.threshold;

  /// How far through the calendar year we are (0..1).
  double get yearProgress =>
      daysElapsed / (daysElapsed + daysRemaining).clamp(1, 400);
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

/// One booked payout for the offline revenue tracker.
///
/// [amount] is always the **gross revenue in đồng** — the taxable base. For a
/// DevEx cash-out that is the USD Roblox pays out *before* PayPal takes its
/// cut, because the flat 2% method taxes revenue, not what lands in your bank.
/// [robux] / [usdCents] keep the original figures so the entry can be traced
/// back to a DevEx statement, and [feeVnd] records what the fees actually cost
/// you (shown as a cash-flow line, never deducted from the taxable base).
class RevenueEntry {
  const RevenueEntry({
    required this.id,
    required this.year,
    required this.month,
    required this.amount,
    this.note = '',
    this.source = PayoutSource.paypal,
    this.robux = 0,
    this.usdCents = 0,
    this.feeVnd = 0,
    this.fxRate = 0,
  });

  final String id;
  final int year;
  final int month; // 1..12
  final int amount; // đồng, gross (taxable base)
  final String note;
  final PayoutSource source;

  /// Robux cashed out (DevEx entries only; 0 otherwise).
  final int robux;

  /// Gross USD received, in cents (0 for domestic VND entries).
  final int usdCents;

  /// Payment/conversion fees in đồng — money lost, but NOT tax-deductible under
  /// the flat direct method.
  final int feeVnd;

  /// VND per USD used at the time of booking, so history stays auditable even
  /// after the profile's rate changes.
  final int fxRate;

  double get usd => usdCents / 100;

  /// What actually reached your bank account.
  int get net => amount - feeVnd;

  Map<String, dynamic> toJson() => {
        'id': id,
        'y': year,
        'm': month,
        'amt': amount,
        if (note.isNotEmpty) 'note': note,
        'src': source.name,
        if (robux > 0) 'rbx': robux,
        if (usdCents > 0) 'usdc': usdCents,
        if (feeVnd > 0) 'fee': feeVnd,
        if (fxRate > 0) 'fx': fxRate,
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
      source: PayoutSource.values.firstWhere(
        (s) => s.name == j['src'],
        orElse: () => PayoutSource.paypal,
      ),
      robux: (j['rbx'] as num?)?.toInt() ?? 0,
      usdCents: (j['usdc'] as num?)?.toInt() ?? 0,
      feeVnd: (j['fee'] as num?)?.toInt() ?? 0,
      fxRate: (j['fx'] as num?)?.toInt() ?? 0,
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

/// Sensible starting points for a Roblox 3D freelancer. All of them are
/// editable — rates move, and the user's PayPal fee depends on their plan.
abstract final class PayoutDefaults {
  const PayoutDefaults._();

  /// Roblox DevEx: USD paid per Robux cashed out. The long-standing published
  /// rate is $0.0035/Robux (100.000 Robux ≈ 350 USD). Roblox can change it —
  /// the profile keeps it editable and the UI tells the user to re-check.
  static const double devExUsdPerRobux = 0.0035;

  /// DevEx minimum cash-out (Robux). Below this the button is simply disabled.
  static const int devExMinRobux = 30000;

  /// VND per 1 USD. A planning default only — for a filing you must use the
  /// buying rate of the commercial bank where the money actually landed.
  static const int usdVndRate = 26000;

  /// Combined receiving + currency-conversion cost on a cross-border payout (%).
  static const double payoutFeePct = 4.4;

  /// Safety margin added on top of the projected tax rate when suggesting how
  /// much of each payout to park in the tax reserve.
  static const int reserveBufferPct = 20;
}

/// The handful of inputs the calculator remembers between sessions, so a
/// freelancer doesn't retype their numbers. Persisted as JSON in settings.
class TaxProfile {
  const TaxProfile({
    this.annualIncome = 0,
    this.dependents = 0,
    this.monthlyInsurance = 0,
    this.expenseRatioPct = 30,
    this.line = BusinessLine.exportedServices,
    this.mode = IncomeMode.usdRobux,
    this.monthlyUsd = 0,
    this.monthlyRobux = 0,
    this.usdVndRate = PayoutDefaults.usdVndRate,
    this.devExUsdPerRobux = PayoutDefaults.devExUsdPerRobux,
    this.payoutFeePct = PayoutDefaults.payoutFeePct,
    this.doneSteps = const {},
  });

  /// Annual foreign income in đồng — used directly when [mode] is [IncomeMode.vnd].
  final int annualIncome;
  final int dependents;

  /// Monthly mandatory insurance deductible from salary-method taxable income.
  final int monthlyInsurance;

  /// Estimated business-expense ratio (%) — used for the company (TNHH) route.
  final int expenseRatioPct;
  final BusinessLine line;

  /// How the annual revenue figure is entered.
  final IncomeMode mode;

  /// Direct USD (PayPal/wire) billed per month — [IncomeMode.usdRobux] only.
  final int monthlyUsd;

  /// Robux cashed out via DevEx per month — [IncomeMode.usdRobux] only.
  final int monthlyRobux;

  final int usdVndRate;
  final double devExUsdPerRobux;
  final double payoutFeePct;

  /// Ids of the roadmap steps already ticked off ([RoadmapStep.id]).
  final Set<String> doneSteps;

  TaxProfile toggleStep(String id) => copyWith(
        doneSteps: doneSteps.contains(id)
            ? {...doneSteps.where((s) => s != id)}
            : {...doneSteps, id},
      );

  TaxProfile copyWith({
    int? annualIncome,
    int? dependents,
    int? monthlyInsurance,
    int? expenseRatioPct,
    BusinessLine? line,
    IncomeMode? mode,
    int? monthlyUsd,
    int? monthlyRobux,
    int? usdVndRate,
    double? devExUsdPerRobux,
    double? payoutFeePct,
    Set<String>? doneSteps,
  }) =>
      TaxProfile(
        annualIncome: annualIncome ?? this.annualIncome,
        dependents: dependents ?? this.dependents,
        monthlyInsurance: monthlyInsurance ?? this.monthlyInsurance,
        expenseRatioPct: expenseRatioPct ?? this.expenseRatioPct,
        line: line ?? this.line,
        mode: mode ?? this.mode,
        monthlyUsd: monthlyUsd ?? this.monthlyUsd,
        monthlyRobux: monthlyRobux ?? this.monthlyRobux,
        usdVndRate: usdVndRate ?? this.usdVndRate,
        devExUsdPerRobux: devExUsdPerRobux ?? this.devExUsdPerRobux,
        payoutFeePct: payoutFeePct ?? this.payoutFeePct,
        doneSteps: doneSteps ?? this.doneSteps,
      );

  Map<String, dynamic> toJson() => {
        'income': annualIncome,
        'deps': dependents,
        'ins': monthlyInsurance,
        'exp': expenseRatioPct,
        'line': line.name,
        'mode': mode.name,
        'usdM': monthlyUsd,
        'rbxM': monthlyRobux,
        'fx': usdVndRate,
        'devex': devExUsdPerRobux,
        'fee': payoutFeePct,
        if (doneSteps.isNotEmpty) 'done': doneSteps.toList(),
      };

  static TaxProfile fromJson(Map<String, dynamic> j) => TaxProfile(
        annualIncome: (j['income'] as num?)?.toInt() ?? 0,
        dependents: (j['deps'] as num?)?.toInt() ?? 0,
        monthlyInsurance: (j['ins'] as num?)?.toInt() ?? 0,
        expenseRatioPct: (j['exp'] as num?)?.toInt() ?? 30,
        line: BusinessLine.values.firstWhere(
          (l) => l.name == j['line'],
          orElse: () => BusinessLine.exportedServices,
        ),
        mode: IncomeMode.values.firstWhere(
          (m) => m.name == j['mode'],
          // Profiles saved before the USD/Robux mode existed held a VND figure.
          orElse: () => j.containsKey('mode') || !j.containsKey('income')
              ? IncomeMode.usdRobux
              : IncomeMode.vnd,
        ),
        monthlyUsd: (j['usdM'] as num?)?.toInt() ?? 0,
        monthlyRobux: (j['rbxM'] as num?)?.toInt() ?? 0,
        usdVndRate:
            (j['fx'] as num?)?.toInt() ?? PayoutDefaults.usdVndRate,
        devExUsdPerRobux: (j['devex'] as num?)?.toDouble() ??
            PayoutDefaults.devExUsdPerRobux,
        payoutFeePct:
            (j['fee'] as num?)?.toDouble() ?? PayoutDefaults.payoutFeePct,
        doneSteps: {
          for (final s in (j['done'] as List?) ?? const []) s.toString(),
        },
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
