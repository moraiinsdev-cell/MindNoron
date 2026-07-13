/// The envelope system behind the "Quỹ" tab: models + pure math for splitting
/// every payout the moment it lands, instead of budgeting whatever survives to
/// the end of the month.
///
/// The whole design rests on one idea a freelancer with lumpy income has to
/// internalise: **income is an event, spending is a rate**. Money arrives in
/// bursts (a DevEx cash-out, a studio invoice) but rent, food and the tax bill
/// arrive every single month. So a payout is never "income" — it is raw
/// material to be cut into envelopes in a fixed order, and only what survives
/// that cut is genuinely spendable.
///
/// Fully offline and deterministic, like the rest of the Tax hub.
library;

import 'dart:convert';

/// What an envelope is *for*. The kind decides three things the UI leans on:
/// whether the money is even yours ([isYours]), whether it counts as survival
/// cash ([isLiquid]), and how its target is derived.
enum FundKind {
  /// Money owed to the state, parked early. Never counts as savings.
  tax,

  /// Income smoothing: the lump lands here, and you pay yourself a flat salary
  /// out of it. This is what turns an irregular income into a regular one.
  buffer,

  /// Months of living costs for when work dries up or you get sick.
  emergency,

  /// PC, GPU, licences — the cost of staying able to do the work at all.
  gear,

  /// A named target with a price: a trip, a course, a deposit.
  goal,

  /// Long-term money you deliberately do not touch. The only envelope with no
  /// ceiling — everything else fills up, this one compounds.
  freedom;

  String get label => switch (this) {
        FundKind.tax => 'Quỹ thuế',
        FundKind.buffer => 'Quỹ đệm thu nhập',
        FundKind.emergency => 'Quỹ khẩn cấp',
        FundKind.gear => 'Quỹ thiết bị',
        FundKind.goal => 'Quỹ mục tiêu',
        FundKind.freedom => 'Quỹ tự do tài chính',
      };

  String get icon => switch (this) {
        FundKind.tax => '🏦',
        FundKind.buffer => '🪣',
        FundKind.emergency => '🛟',
        FundKind.gear => '🖥️',
        FundKind.goal => '🎯',
        FundKind.freedom => '🌱',
      };

  /// Why this envelope exists — shown once, on the fund card.
  String get why => switch (this) {
        FundKind.tax =>
          'Tiền thuế chưa bao giờ là tiền của bạn. Trích ngay khi tiền về, '
              'trước cả khi nhìn vào số dư — để đến kỳ khai không phải đi vay.',
        FundKind.buffer =>
          'Thu nhập freelance về theo cục, chi phí thì đều đặn hằng tháng. '
              'Quỹ đệm giữ cục tiền đó và trả cho bạn một mức "lương" cố định '
              'mỗi tháng — tháng đói cũng như tháng no.',
        FundKind.emergency =>
          'Không có studio nào trả lương ốm cho bạn. Quỹ này mua thời gian: '
              'mất khách, hỏng máy, bệnh — bạn vẫn sống được vài tháng mà không '
              'phải nhận đại một job rẻ mạt.',
        FundKind.gear =>
          'Máy sẽ hỏng, GPU sẽ lỗi thời — đó là chi phí chắc chắn, chỉ chưa '
              'biết ngày. Góp dần thì nó là một khoản kế hoạch; không góp thì '
              'nó là một cú sốc.',
        FundKind.goal =>
          'Một mục tiêu có giá và có ngày. Ghi ra để biết mỗi tháng phải để '
              'dành bao nhiêu, thay vì "để dành khi nào dư".',
        FundKind.freedom =>
          'Quỹ duy nhất không có trần. Không tiêu, không rút — đây là phần thu '
              'nhập tương lai mà bạn tự trả cho mình.',
      };

  /// Tax money is held, not owned: it is excluded from every "savings" total.
  bool get isYours => this != FundKind.tax;

  /// Survival cash — what [SavingsHealth.runwayMonths] is computed from.
  /// Gear and goal money is spoken for; freedom money you must not touch.
  bool get isLiquid => this == FundKind.buffer || this == FundKind.emergency;
}

/// One envelope. It carries a *policy* (how much of each payout it takes, and
/// where it stops), never a balance — the balance is always derived from the
/// ledger, so a number on screen can always be traced back to entries.
class SavingsFund {
  const SavingsFund({
    required this.id,
    required this.name,
    required this.kind,
    this.sharePct = 0,
    this.targetVnd = 0,
    this.targetMonths = 0,
    this.note = '',
  });

  final String id;
  final String name;
  final FundKind kind;

  /// Share of each payout *after tax* that flows into this envelope (0..100).
  /// Ignored for [FundKind.tax], which takes the computed reserve rate off the
  /// top instead — the taxman does not negotiate percentages with you.
  final double sharePct;

  /// Fixed ceiling in đồng. 0 = no fixed ceiling (see [targetMonths]).
  final int targetVnd;

  /// Ceiling expressed in months of living costs — the honest way to size a
  /// buffer or an emergency fund, because it re-sizes itself as your life gets
  /// more expensive. Takes precedence over [targetVnd] when both are set.
  final int targetMonths;

  final String note;

  /// Where this envelope stops filling, given monthly living costs.
  /// 0 means bottomless ([FundKind.freedom], or an unsized fund).
  int targetFor(int monthlySpend) {
    if (targetMonths > 0 && monthlySpend > 0) return targetMonths * monthlySpend;
    return targetVnd;
  }

  SavingsFund copyWith({
    String? name,
    FundKind? kind,
    double? sharePct,
    int? targetVnd,
    int? targetMonths,
    String? note,
  }) =>
      SavingsFund(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        sharePct: sharePct ?? this.sharePct,
        targetVnd: targetVnd ?? this.targetVnd,
        targetMonths: targetMonths ?? this.targetMonths,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        if (sharePct > 0) 'share': sharePct,
        if (targetVnd > 0) 'target': targetVnd,
        if (targetMonths > 0) 'months': targetMonths,
        if (note.isNotEmpty) 'note': note,
      };

  static SavingsFund? fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    if (id == null) return null;
    return SavingsFund(
      id: id,
      name: j['name'] as String? ?? 'Quỹ',
      kind: FundKind.values.firstWhere(
        (k) => k.name == j['kind'],
        orElse: () => FundKind.goal,
      ),
      sharePct: (j['share'] as num?)?.toDouble() ?? 0,
      targetVnd: (j['target'] as num?)?.toInt() ?? 0,
      targetMonths: (j['months'] as num?)?.toInt() ?? 0,
      note: j['note'] as String? ?? '',
    );
  }

  static String encodeList(List<SavingsFund> list) =>
      jsonEncode([for (final f in list) f.toJson()]);

  /// Decodes the saved envelopes, falling back to [defaultFunds] the first time
  /// the tab is opened — an empty screen teaches nobody anything.
  static List<SavingsFund> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return defaultFunds();
    try {
      final list = jsonDecode(raw);
      if (list is! List) return defaultFunds();
      final funds = [
        for (final f in list)
          if (f is Map<String, dynamic>)
            if (SavingsFund.fromJson(f) case final fund?) fund,
      ];
      return funds.isEmpty ? defaultFunds() : funds;
    } catch (_) {
      return defaultFunds();
    }
  }
}

/// Why money moved. Kept on every entry so the ledger reads like a story rather
/// than a column of numbers.
enum FundTxnKind {
  /// Automatic slice of an incoming payout.
  split,

  /// Money put in by hand (including the opening balance).
  deposit,

  /// Money taken out — the entry the UI makes you justify.
  withdraw;

  String get label => switch (this) {
        FundTxnKind.split => 'Chia từ tiền về',
        FundTxnKind.deposit => 'Nạp vào',
        FundTxnKind.withdraw => 'Rút ra',
      };
}

/// One movement in one envelope. [amount] is signed: positive in, negative out.
class FundTxn {
  const FundTxn({
    required this.id,
    required this.fundId,
    required this.at,
    required this.amount,
    this.kind = FundTxnKind.deposit,
    this.note = '',
  });

  final String id;
  final String fundId;
  final DateTime at;

  /// Đồng. Negative for a withdrawal.
  final int amount;

  final FundTxnKind kind;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'f': fundId,
        'at': at.toIso8601String(),
        'amt': amount,
        'k': kind.name,
        if (note.isNotEmpty) 'note': note,
      };

  static FundTxn? fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    final fundId = j['f'] as String?;
    final amt = (j['amt'] as num?)?.toInt();
    final at = DateTime.tryParse(j['at'] as String? ?? '');
    if (id == null || fundId == null || amt == null || at == null) return null;
    return FundTxn(
      id: id,
      fundId: fundId,
      at: at,
      amount: amt,
      kind: FundTxnKind.values.firstWhere(
        (k) => k.name == j['k'],
        orElse: () => FundTxnKind.deposit,
      ),
      note: j['note'] as String? ?? '',
    );
  }

  static String encodeList(List<FundTxn> list) =>
      jsonEncode([for (final t in list) t.toJson()]);

  static List<FundTxn> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final t in list)
          if (t is Map<String, dynamic>)
            if (FundTxn.fromJson(t) case final txn?) txn,
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// A starter envelope set for a Roblox freelancer, sized for someone whose
/// income arrives 2–4 times a month and can stop without notice.
///
/// The shares leave ~50% of every payout spendable. That is deliberate: a split
/// so tight that you raid it in week three is worse than no split at all.
List<SavingsFund> defaultFunds() => const [
      SavingsFund(
        id: 'tax',
        name: 'Quỹ thuế',
        kind: FundKind.tax,
        note: 'Tự tính theo doanh thu — không chỉnh tỷ lệ.',
      ),
      SavingsFund(
        id: 'buffer',
        name: 'Quỹ đệm thu nhập',
        kind: FundKind.buffer,
        sharePct: 15,
        targetMonths: 3,
        note: 'Nơi cục tiền đáp xuống, rồi trả bạn lương đều mỗi tháng.',
      ),
      SavingsFund(
        id: 'emergency',
        name: 'Quỹ khẩn cấp',
        kind: FundKind.emergency,
        sharePct: 15,
        targetMonths: 6,
        note: 'Gửi tiết kiệm không kỳ hạn — rút được trong ngày.',
      ),
      SavingsFund(
        id: 'gear',
        name: 'Quỹ thiết bị',
        kind: FundKind.gear,
        sharePct: 10,
        targetVnd: 40000000,
        note: 'PC / GPU / bản quyền phần mềm.',
      ),
      SavingsFund(
        id: 'freedom',
        name: 'Quỹ tự do tài chính',
        kind: FundKind.freedom,
        sharePct: 10,
        note: 'Không trần, không rút.',
      ),
    ];

/// What one envelope got out of a payout, and whether that filled it up.
class FundSlice {
  const FundSlice({
    required this.fund,
    required this.amount,
    required this.filled,
  });

  final SavingsFund fund;
  final int amount;

  /// True when this payout takes the envelope to (or over) its target — the
  /// moment its share starts flowing to the next envelope instead.
  final bool filled;
}

/// The full cut of a single payout, from taxable revenue down to the money you
/// may actually spend without lying to yourself.
class AllocationPlan {
  const AllocationPlan({
    required this.gross,
    required this.fees,
    required this.taxCut,
    required this.reserveRate,
    required this.slices,
    required this.spendable,
  });

  /// Taxable revenue — what the tax office counts.
  final int gross;

  /// PayPal / FX cost: money that never reached you but is still taxed.
  final int fees;

  /// Đồng routed to the tax envelope.
  final int taxCut;

  /// The rate [taxCut] was computed at (0..1), for showing the user *why*.
  final double reserveRate;

  final List<FundSlice> slices;

  /// What is left to live on. This is the only number you are allowed to spend.
  final int spendable;

  /// Cash that actually landed in the bank.
  int get netCash => gross - fees;

  /// Everything routed into envelopes, tax included.
  int get allocated => taxCut + saved;

  /// Money that is genuinely yours and stays yours.
  int get saved =>
      slices.fold(0, (sum, s) => sum + s.amount);

  /// Share of the landed cash that got put away (0..1).
  double get savingsRate => netCash <= 0 ? 0 : saved / netCash;
}

/// Cuts one payout into envelopes, in a strict order, capping each at its
/// target and cascading the overflow onward.
///
/// Order matters and is not negotiable: **tax first** (it is not your money),
/// then the envelopes in the order the user arranged them. Anything a full
/// envelope can no longer absorb falls to the next unfilled one, and only the
/// final residue is spendable — the opposite of the usual "spend, then save the
/// remainder", which reliably saves nothing.
///
/// [reserveRate] comes from `computeReserve` (projected effective tax + buffer)
/// and is applied to [gross], because tax is owed on revenue — including the
/// part that PayPal ate. If fees are so large that the tax cut exceeds the cash
/// that landed, the tax envelope simply takes everything: an honest, unpleasant
/// signal that the payout was not worth its fees.
AllocationPlan allocatePayout({
  required int gross,
  required List<SavingsFund> funds,
  required Map<String, int> balances,
  int fees = 0,
  double reserveRate = 0,
  int monthlySpend = 0,
}) {
  final netCash = (gross - fees).clamp(0, gross);
  final taxCut =
      (gross * reserveRate.clamp(0.0, 1.0)).round().clamp(0, netCash);

  var left = netCash - taxCut;
  final envelopes = [for (final f in funds) if (f.kind != FundKind.tax) f];

  // Pass 1 — everyone takes their share of the same base, never more than the
  // room they have left. Shares are of the after-tax cash, so the percentages
  // the user sees on screen are the percentages of money they can feel.
  final base = left;
  final room = <String, int>{};
  final given = <String, int>{};

  for (final f in envelopes) {
    final target = f.targetFor(monthlySpend);
    final balance = balances[f.id] ?? 0;
    final space = target <= 0 ? left : (target - balance).clamp(0, target);
    room[f.id] = space;

    final want = (base * f.sharePct.clamp(0, 100) / 100).round();
    final give = [want, space, left].reduce((a, b) => a < b ? a : b);
    given[f.id] = give < 0 ? 0 : give;
    left -= given[f.id]!;
    room[f.id] = space - given[f.id]!;
  }

  // Pass 2 — the shares of envelopes that filled up don't leak into spending:
  // they cascade down the list to whoever still has room. Only what nobody can
  // hold is truly spendable.
  final claimed = given.values.fold(0, (a, b) => a + b);
  var overflow = (base * _totalShare(envelopes) / 100).round() - claimed;
  if (overflow > 0) {
    for (final f in envelopes) {
      if (overflow <= 0 || left <= 0) break;
      final space = room[f.id] ?? 0;
      if (space <= 0) continue;
      final top = [overflow, space, left].reduce((a, b) => a < b ? a : b);
      given[f.id] = (given[f.id] ?? 0) + top;
      room[f.id] = space - top;
      overflow -= top;
      left -= top;
    }
  }

  return AllocationPlan(
    gross: gross,
    fees: fees,
    taxCut: taxCut,
    reserveRate: reserveRate,
    slices: [
      for (final f in envelopes)
        if ((given[f.id] ?? 0) > 0)
          FundSlice(
            fund: f,
            amount: given[f.id]!,
            filled: f.targetFor(monthlySpend) > 0 && (room[f.id] ?? 0) <= 0,
          ),
    ],
    spendable: left < 0 ? 0 : left,
  );
}

double _totalShare(List<SavingsFund> funds) =>
    funds.fold(0.0, (sum, f) => sum + f.sharePct.clamp(0, 100));

/// How long you survive on savings alone. The number a freelancer should be
/// able to recite from memory.
enum RunwayLevel {
  /// Under a month of cover: one late invoice from a crisis.
  critical,

  /// Under three months: enough to absorb a bad month, not a bad quarter.
  thin,

  /// Three to six months: you can turn down a bad client.
  ok,

  /// Six months or more: your income is no longer your leash.
  solid;

  String get label => switch (this) {
        RunwayLevel.critical => 'Nguy hiểm',
        RunwayLevel.thin => 'Mỏng',
        RunwayLevel.ok => 'Ổn',
        RunwayLevel.solid => 'Vững',
      };

  String get advice => switch (this) {
        RunwayLevel.critical =>
          'Chưa đủ sống 1 tháng nếu ngừng nhận tiền. Ưu tiên số một lúc này '
              'không phải đầu tư hay đổi máy — mà là dựng quỹ đệm.',
        RunwayLevel.thin =>
          'Chịu được một tháng ế, chưa chịu được một quý ế. Nâng tỷ lệ trích '
              'cho quỹ đệm & khẩn cấp cho tới khi qua mốc 3 tháng.',
        RunwayLevel.ok =>
          'Đủ dài để từ chối một job rẻ hoặc một khách khó chịu. Đẩy tiếp lên '
              '6 tháng, rồi mới nghĩ tới quỹ tự do tài chính.',
        RunwayLevel.solid =>
          'Thu nhập không còn là dây xích. Từ đây, phần trích thêm nên chảy '
              'vào quỹ tự do tài chính thay vì nằm im trong tài khoản.',
      };
}

/// A snapshot of the whole envelope system: what you hold, what is actually
/// yours, how long it buys you, and whether the tax envelope is behind.
class SavingsHealth {
  const SavingsHealth({
    required this.total,
    required this.yours,
    required this.liquid,
    required this.monthlySpend,
    required this.runwayMonths,
    required this.taxHeld,
    required this.taxShouldHold,
  });

  /// Everything in every envelope, tax included.
  final int total;

  /// Everything that is genuinely yours — [total] minus the tax envelope.
  final int yours;

  /// Cash you could actually live on: buffer + emergency.
  final int liquid;

  final int monthlySpend;

  /// [liquid] ÷ [monthlySpend]. Zero when living costs haven't been entered —
  /// which is itself worth saying out loud, so the UI does.
  final double runwayMonths;

  final int taxHeld;

  /// What the tax envelope *should* hold today, from `computeReserve`.
  final int taxShouldHold;

  /// Đồng short of the tax you have already incurred. Positive = you are
  /// spending money that belongs to the tax office.
  int get taxGap => (taxShouldHold - taxHeld).clamp(0, taxShouldHold);

  bool get taxOnTrack => taxGap <= 0;

  RunwayLevel get level => switch (runwayMonths) {
        < 1 => RunwayLevel.critical,
        < 3 => RunwayLevel.thin,
        < 6 => RunwayLevel.ok,
        _ => RunwayLevel.solid,
      };

  /// True when living costs are unknown — every runway number is then a guess.
  bool get needsSpend => monthlySpend <= 0;
}

SavingsHealth computeHealth({
  required List<SavingsFund> funds,
  required Map<String, int> balances,
  required int monthlySpend,
  int taxShouldHold = 0,
}) {
  var total = 0, yours = 0, liquid = 0, taxHeld = 0;
  for (final f in funds) {
    final b = balances[f.id] ?? 0;
    total += b;
    if (f.kind.isYours) yours += b;
    if (f.kind.isLiquid) liquid += b;
    if (f.kind == FundKind.tax) taxHeld += b;
  }
  return SavingsHealth(
    total: total,
    yours: yours,
    liquid: liquid,
    monthlySpend: monthlySpend,
    runwayMonths: monthlySpend <= 0 ? 0 : liquid / monthlySpend,
    taxHeld: taxHeld,
    taxShouldHold: taxShouldHold,
  );
}

/// Turning a spiky income into a wage.
///
/// The trap freelancers fall into is anchoring their lifestyle to a *good*
/// month. The fix is to pay yourself the same amount every month out of the
/// buffer — and to set that amount from what the year actually averages, after
/// tax and after saving, never from the best month.
class SelfSalaryPlan {
  const SelfSalaryPlan({
    required this.avgMonthlyNet,
    required this.worstMonthNet,
    required this.taxCut,
    required this.savingsCut,
    required this.salary,
    required this.monthlySpend,
    required this.bufferBalance,
  });

  /// Trailing average of what actually landed per month (net of fees).
  final int avgMonthlyNet;

  /// The leanest month on record — what the buffer has to survive.
  final int worstMonthNet;

  /// Average đồng/month that belongs to the tax office.
  final int taxCut;

  /// Average đồng/month routed into envelopes.
  final int savingsCut;

  /// What you can pay yourself every month, in good months and bad.
  final int salary;

  final int monthlySpend;
  final int bufferBalance;

  /// Months the buffer alone can keep paying that salary if income stops.
  double get bufferCover => salary <= 0 ? 0 : bufferBalance / salary;

  /// Salary minus living costs — the real monthly surplus, if any.
  int get surplus => salary - monthlySpend;

  bool get sustainable => monthlySpend > 0 && salary >= monthlySpend;

  /// How much the worst month falls short of the salary — i.e. the hole the
  /// buffer is there to plug.
  int get worstMonthGap => (salary - worstMonthNet).clamp(0, salary);
}

/// [monthlyNet] is what landed each month so far this year (net of fees), one
/// entry per month with income; months with nothing are still counted in the
/// average when [monthsElapsed] says they happened — a dry month is data, not
/// an outlier to be excluded.
SelfSalaryPlan planSelfSalary({
  required List<int> monthlyNet,
  required int monthsElapsed,
  required List<SavingsFund> funds,
  required int bufferBalance,
  required int monthlySpend,
  double reserveRate = 0,
}) {
  final months = monthsElapsed <= 0 ? 1 : monthsElapsed;
  final totalNet = monthlyNet.fold(0, (a, b) => a + b);
  final avg = totalNet ~/ months;

  final worst = monthlyNet.length < months
      ? 0 // a month with no income at all is the real worst case
      : monthlyNet.reduce((a, b) => a < b ? a : b);

  final tax = (avg * reserveRate.clamp(0.0, 1.0)).round();
  final afterTax = avg - tax;
  final envelopes = [for (final f in funds) if (f.kind != FundKind.tax) f];
  final savings = (afterTax * _totalShare(envelopes) / 100).round();

  return SelfSalaryPlan(
    avgMonthlyNet: avg,
    worstMonthNet: worst,
    taxCut: tax,
    savingsCut: savings,
    salary: (afterTax - savings).clamp(0, afterTax),
    monthlySpend: monthlySpend,
    bufferBalance: bufferBalance,
  );
}

/// Months until an envelope reaches its target at the current pace.
/// Null when it is already full, bottomless, or nothing is flowing into it —
/// "never" is an answer the UI should say plainly rather than dress up as ∞.
double? monthsToTarget({
  required SavingsFund fund,
  required int balance,
  required int monthlySpend,
  required int monthlyContribution,
}) {
  final target = fund.targetFor(monthlySpend);
  if (target <= 0 || balance >= target) return null;
  if (monthlyContribution <= 0) return null;
  return (target - balance) / monthlyContribution;
}
