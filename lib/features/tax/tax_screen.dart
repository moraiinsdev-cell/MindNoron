import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/event_repository.dart';
import '../../presentation/widgets/common/section_scaffold.dart';
import 'tax_dta.dart';
import 'tax_engine.dart';
import 'tax_knowledge.dart';
import 'tax_models.dart';
import 'tax_repository.dart';
import 'tax_roblox.dart';

/// Offline Tax hub, tuned for a Vietnamese 3D artist selling models to Roblox
/// studios and paid in USD (PayPal) or Robux (DevEx).
///
/// It answers the three questions that decide whether a freelancer keeps their
/// money: *how much is really mine* (Robux → USD → VND, gross vs net of fees),
/// *how should I be registered* (progressive salary vs 2% exported services vs
/// a company), and *when do I owe it* (revenue tracker, tax reserve, deadlines).
/// No network, no LLM — pure local math + curated content.
class TaxScreen extends ConsumerStatefulWidget {
  const TaxScreen({super.key});

  @override
  ConsumerState<TaxScreen> createState() => _TaxScreenState();
}

enum _Tab { calculator, revenue, roblox, risk, dta, regulations, strategies }

class _TaxScreenState extends ConsumerState<TaxScreen> {
  _Tab _tab = _Tab.calculator;

  /// Live copy of the persisted profile — every edit writes through to settings.
  TaxProfile _p = const TaxProfile();
  bool _seeded = false;

  final _incomeCtrl = TextEditingController();
  final _usdCtrl = TextEditingController();
  final _robuxCtrl = TextEditingController();
  final _depsCtrl = TextEditingController();
  final _insCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _fxCtrl = TextEditingController();
  final _devexCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _incomeCtrl,
      _usdCtrl,
      _robuxCtrl,
      _depsCtrl,
      _insCtrl,
      _expCtrl,
      _fxCtrl,
      _devexCtrl,
      _feeCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(TaxProfile p) {
    if (_seeded) return;
    _seeded = true;
    _p = p;
    if (p.annualIncome > 0) {
      _incomeCtrl.text = (p.annualIncome ~/ 1000000).toString();
    }
    if (p.monthlyUsd > 0) _usdCtrl.text = p.monthlyUsd.toString();
    if (p.monthlyRobux > 0) _robuxCtrl.text = p.monthlyRobux.toString();
    if (p.dependents > 0) _depsCtrl.text = p.dependents.toString();
    if (p.monthlyInsurance > 0) {
      _insCtrl.text = (p.monthlyInsurance ~/ 1000000).toString();
    }
    _expCtrl.text = p.expenseRatioPct.toString();
    _fxCtrl.text = p.usdVndRate.toString();
    _devexCtrl.text = p.devExUsdPerRobux.toString();
    _feeCtrl.text = p.payoutFeePct.toString();
  }

  void _update(TaxProfile next) {
    setState(() => _p = next);
    ref.read(taxRepositoryProvider).save(next);
  }

  /// Re-reads every controller into the profile — simpler than wiring nine
  /// individual callbacks, and the inputs are cheap to parse.
  void _sync() {
    _update(_p.copyWith(
      annualIncome: (int.tryParse(_incomeCtrl.text.trim()) ?? 0) * 1000000,
      monthlyUsd: int.tryParse(_usdCtrl.text.trim()) ?? 0,
      monthlyRobux: int.tryParse(_robuxCtrl.text.trim()) ?? 0,
      dependents: int.tryParse(_depsCtrl.text.trim()) ?? 0,
      monthlyInsurance: (int.tryParse(_insCtrl.text.trim()) ?? 0) * 1000000,
      expenseRatioPct: (int.tryParse(_expCtrl.text.trim()) ?? 30).clamp(0, 100),
      usdVndRate: int.tryParse(_fxCtrl.text.trim()) ?? PayoutDefaults.usdVndRate,
      devExUsdPerRobux: double.tryParse(_devexCtrl.text.trim().replaceAll(',', '.')) ??
          PayoutDefaults.devExUsdPerRobux,
      payoutFeePct: double.tryParse(_feeCtrl.text.trim().replaceAll(',', '.')) ??
          PayoutDefaults.payoutFeePct,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Seed inputs once from the persisted profile.
    ref.watch(taxProfileProvider).whenData(_seed);

    return SectionScaffold(
      title: 'Thuế',
      subtitle:
          'Trợ lý thuế cho 3D artist freelance làm cho studio Roblox — Robux '
          '(DevEx) & USD (PayPal) quy về đồng, thuế đúng luật, dòng tiền trong '
          'tầm kiểm soát. Hoàn toàn offline.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_Tab>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _Tab.calculator,
                  icon: Icon(Icons.calculate_outlined),
                  label: Text('Máy tính'),
                ),
                ButtonSegment(
                  value: _Tab.revenue,
                  icon: Icon(Icons.trending_up),
                  label: Text('Doanh thu'),
                ),
                ButtonSegment(
                  value: _Tab.roblox,
                  icon: Icon(Icons.sports_esports_outlined),
                  label: Text('Roblox'),
                ),
                ButtonSegment(
                  value: _Tab.risk,
                  icon: Icon(Icons.shield_outlined),
                  label: Text('Rủi ro'),
                ),
                ButtonSegment(
                  value: _Tab.dta,
                  icon: Icon(Icons.public),
                  label: Text('Quốc tế'),
                ),
                ButtonSegment(
                  value: _Tab.regulations,
                  icon: Icon(Icons.gavel_outlined),
                  label: Text('Quy định'),
                ),
                ButtonSegment(
                  value: _Tab.strategies,
                  icon: Icon(Icons.savings_outlined),
                  label: Text('Tối ưu'),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (_tab) {
              _Tab.calculator => _CalculatorTab(
                  profile: _p,
                  incomeCtrl: _incomeCtrl,
                  usdCtrl: _usdCtrl,
                  robuxCtrl: _robuxCtrl,
                  depsCtrl: _depsCtrl,
                  insCtrl: _insCtrl,
                  expCtrl: _expCtrl,
                  fxCtrl: _fxCtrl,
                  devexCtrl: _devexCtrl,
                  feeCtrl: _feeCtrl,
                  onChanged: _sync,
                  onProfile: _update,
                ),
              _Tab.revenue => const _RevenueTab(),
              _Tab.roblox => const _RobloxTab(),
              _Tab.risk => const _RiskTab(),
              _Tab.dta => const _DtaTab(),
              _Tab.regulations => const _NotesTab(),
              _Tab.strategies => const _StrategiesTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Calculator ────────────────────────────────

class _CalculatorTab extends StatelessWidget {
  const _CalculatorTab({
    required this.profile,
    required this.incomeCtrl,
    required this.usdCtrl,
    required this.robuxCtrl,
    required this.depsCtrl,
    required this.insCtrl,
    required this.expCtrl,
    required this.fxCtrl,
    required this.devexCtrl,
    required this.feeCtrl,
    required this.onChanged,
    required this.onProfile,
  });

  final TaxProfile profile;
  final TextEditingController incomeCtrl;
  final TextEditingController usdCtrl;
  final TextEditingController robuxCtrl;
  final TextEditingController depsCtrl;
  final TextEditingController insCtrl;
  final TextEditingController expCtrl;
  final TextEditingController fxCtrl;
  final TextEditingController devexCtrl;
  final TextEditingController feeCtrl;
  final VoidCallback onChanged;
  final ValueChanged<TaxProfile> onProfile;

  @override
  Widget build(BuildContext context) {
    final line = profile.line;
    final dependents = profile.dependents;
    final expenseRatioPct = profile.expenseRatioPct;
    final annualIncome = annualRevenueOf(profile);

    final salary = computeSalaryTax(
      annualGross: annualIncome,
      dependents: dependents,
      monthlyInsurance: profile.monthlyInsurance,
    );
    final business = computeBusinessTax(
      annualRevenue: annualIncome,
      line: line,
    );
    final company = computeCompanyTax(
      revenue: annualIncome,
      expenseRatioPct: expenseRatioPct,
    );
    final hasIncome = annualIncome > 0;

    // Cheapest of the three methods drives the highlight + banner.
    final taxes = {
      'business': business.annualTax,
      'salary': salary.annualTax,
      'company': company.annualTax,
    };
    final best = taxes.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
    final sorted = taxes.values.toList()..sort();
    final saving = sorted[1] - sorted[0];

    final cliff = exemptionCliff(line: line);

    return ListView(
      children: [
        _InputsCard(
          profile: profile,
          incomeCtrl: incomeCtrl,
          usdCtrl: usdCtrl,
          robuxCtrl: robuxCtrl,
          depsCtrl: depsCtrl,
          insCtrl: insCtrl,
          expCtrl: expCtrl,
          fxCtrl: fxCtrl,
          devexCtrl: devexCtrl,
          feeCtrl: feeCtrl,
          onChanged: onChanged,
          onProfile: onProfile,
        ),
        const SizedBox(height: 14),
        if (!hasIncome)
          const _HintCard()
        else ...[
          if (profile.mode == IncomeMode.usdRobux) ...[
            _PayoutFlowCard(
              breakdown: convertPayout(
                robux: profile.monthlyRobux * 12,
                usd: profile.monthlyUsd * 12.0,
                devExUsdPerRobux: profile.devExUsdPerRobux,
                usdVndRate: profile.usdVndRate,
                feePct: profile.payoutFeePct,
              ),
              taxOnGross: business.annualTax,
            ),
            const SizedBox(height: 12),
          ],
          if (cliff.contains(annualIncome)) ...[
            _CliffWarning(cliff: cliff, revenue: annualIncome),
            const SizedBox(height: 12),
          ],
          _WinnerBanner(best: best, saving: saving),
          const SizedBox(height: 12),
          _ResultCard(
            title: 'Cá nhân kinh doanh',
            subtitle: line.label,
            annualTax: business.annualTax,
            effectiveRate: business.effectiveRate,
            annualNet: business.annualNet,
            highlighted: best == 'business',
            rows: [
              if (business.exempt)
                const _Row('Tình trạng', 'Miễn thuế (≤ 500 triệu/năm)')
              else ...[
                _Row('Thuế GTGT', _vnd(business.vat)),
                _Row('Thuế TNCN', _vnd(business.pit)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _ResultCard(
            title: 'Tiền lương / tiền công',
            subtitle: 'Biểu lũy tiến 5%–35%, giảm trừ gia cảnh',
            annualTax: salary.annualTax,
            effectiveRate: salary.effectiveRate,
            annualNet: salary.annualNet,
            highlighted: best == 'salary',
            rows: [
              _Row('Thu nhập tính thuế/năm', _vnd(salary.annualTaxableIncome)),
              _Row('Thuế suất biên', '${(salary.marginalRate * 100).round()}%'),
              const _Row('Giảm trừ bản thân', '15,5 triệu/tháng'),
              if (dependents > 0)
                _Row('Người phụ thuộc', '$dependents × 6,2 triệu/tháng'),
            ],
          ),
          const SizedBox(height: 12),
          _ResultCard(
            title: 'Công ty TNHH một thành viên',
            subtitle: 'TNDN 20% + thuế cổ tức 5% (giả định chia hết lợi nhuận)',
            annualTax: company.annualTax,
            effectiveRate: company.effectiveRate,
            annualNet: company.ownerNet,
            netLabel: 'Còn lại từ lợi nhuận',
            highlighted: best == 'company',
            rows: [
              _Row('Chi phí ước tính', '$expenseRatioPct% doanh thu'),
              _Row('Lợi nhuận trước thuế', _vnd(company.profit)),
              _Row('Thuế TNDN (20%)', _vnd(company.cit)),
              _Row('Thuế cổ tức (5%)', _vnd(company.dividendTax)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Lưu ý: công ty được trừ chi phí thực tế (lợi thế khi biên lợi '
            'nhuận thấp) nhưng phải làm kế toán, BHXH, và có chi phí tuân thủ '
            'cao hơn — cân nhắc khi thu nhập lớn.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _copyReport(
                context,
                annualIncome: annualIncome,
                business: business,
                salary: salary,
                company: company,
                best: best,
              ),
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: const Text('Sao chép báo cáo'),
            ),
          ),
          const SizedBox(height: 12),
          const _DisclaimerCard(),
        ],
      ],
    );
  }

  Future<void> _copyReport(
    BuildContext context, {
    required int annualIncome,
    required BusinessTaxResult business,
    required SalaryTaxResult salary,
    required CompanyTaxResult company,
    required String best,
  }) async {
    String pct(double r) => '${(r * 100).toStringAsFixed(1)}%';
    const names = {
      'business': 'Cá nhân kinh doanh',
      'salary': 'Tiền lương / tiền công',
      'company': 'Công ty TNHH',
    };

    final src = StringBuffer();
    if (profile.mode == IncomeMode.usdRobux) {
      final flow = convertPayout(
        robux: profile.monthlyRobux * 12,
        usd: profile.monthlyUsd * 12.0,
        devExUsdPerRobux: profile.devExUsdPerRobux,
        usdVndRate: profile.usdVndRate,
        feePct: profile.payoutFeePct,
      );
      src
        ..writeln('Nguồn thu/năm: ${_int(profile.monthlyRobux * 12)} Robux '
            '(DevEx @ ${profile.devExUsdPerRobux}) + '
            '${_int(profile.monthlyUsd * 12)} USD trực tiếp')
        ..writeln('  = ${flow.usdGross.toStringAsFixed(0)} USD gộp × '
            '${_int(profile.usdVndRate)} ₫/USD')
        ..writeln('  Phí nhận tiền (${profile.payoutFeePct}%): '
            '${_vnd(flow.vndFee)} → thực về tay ${_vnd(flow.vndNet)}');
    }

    final report = '''
BÁO CÁO THUẾ — 3D freelance cho studio Roblox
Doanh thu tính thuế/năm: ${_vnd(annualIncome)}
${src}Người phụ thuộc: ${profile.dependents}

1) Cá nhân kinh doanh (${profile.line.label})
   Thuế/năm: ${_vnd(business.annualTax)} (${pct(business.effectiveRate)})
2) Tiền lương / tiền công (lũy tiến)
   Thuế/năm: ${_vnd(salary.annualTax)} (${pct(salary.effectiveRate)})
3) Công ty TNHH (chi phí ${profile.expenseRatioPct}%)
   Thuế/năm: ${_vnd(company.annualTax)} (${pct(company.effectiveRate)})

➜ Phương án tối ưu: ${names[best]}

$taxDisclaimer''';
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã sao chép báo cáo thuế')));
  }
}

class _InputsCard extends StatelessWidget {
  const _InputsCard({
    required this.profile,
    required this.incomeCtrl,
    required this.usdCtrl,
    required this.robuxCtrl,
    required this.depsCtrl,
    required this.insCtrl,
    required this.expCtrl,
    required this.fxCtrl,
    required this.devexCtrl,
    required this.feeCtrl,
    required this.onChanged,
    required this.onProfile,
  });

  final TaxProfile profile;
  final TextEditingController incomeCtrl;
  final TextEditingController usdCtrl;
  final TextEditingController robuxCtrl;
  final TextEditingController depsCtrl;
  final TextEditingController insCtrl;
  final TextEditingController expCtrl;
  final TextEditingController fxCtrl;
  final TextEditingController devexCtrl;
  final TextEditingController feeCtrl;
  final VoidCallback onChanged;
  final ValueChanged<TaxProfile> onProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usdMode = profile.mode == IncomeMode.usdRobux;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<IncomeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: IncomeMode.usdRobux,
                  icon: Icon(Icons.currency_exchange, size: 16),
                  label: Text('USD + Robux'),
                ),
                ButtonSegment(
                  value: IncomeMode.vnd,
                  icon: Icon(Icons.payments_outlined, size: 16),
                  label: Text('Nhập VNĐ'),
                ),
              ],
              selected: {profile.mode},
              onSelectionChanged: (s) =>
                  onProfile(profile.copyWith(mode: s.first)),
            ),
            const SizedBox(height: 14),
            if (usdMode) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: robuxCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        labelText: 'Robux DevEx / tháng',
                        suffixText: 'R\$',
                        border: OutlineInputBorder(),
                        helperText: 'Tối thiểu 30.000 R\$ mỗi lần rút',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: usdCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        labelText: 'USD trực tiếp / tháng',
                        suffixText: '\$',
                        border: OutlineInputBorder(),
                        helperText: 'Commission studio trả qua PayPal',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fxCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        labelText: 'Tỷ giá USD',
                        suffixText: '₫',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: devexCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        labelText: 'Rate DevEx',
                        suffixText: '\$/R\$',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: feeCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        labelText: 'Phí nhận tiền',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tỷ giá & rate DevEx do bạn tự cập nhật — Roblox có thể đổi rate, '
                'và khi quyết toán phải dùng tỷ giá mua vào của ngân hàng nơi '
                'tiền về.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ] else
              TextField(
                controller: incomeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  labelText: 'Doanh thu / năm',
                  suffixText: 'triệu ₫',
                  border: OutlineInputBorder(),
                  helperText: 'Ví dụ: 600 = 600 triệu đồng/năm',
                ),
              ),
            const SizedBox(height: 14),
            DropdownButtonFormField<BusinessLine>(
              initialValue: profile.line,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ngành nghề (khi khai cá nhân kinh doanh)',
                border: OutlineInputBorder(),
                helperText: 'Làm 3D cho studio nước ngoài → dịch vụ xuất khẩu',
              ),
              items: [
                for (final l in BusinessLine.values)
                  DropdownMenuItem(value: l, child: Text(l.label)),
              ],
              onChanged: (l) =>
                  l == null ? null : onProfile(profile.copyWith(line: l)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: depsCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Người phụ thuộc',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: insCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'BHXH/tháng',
                      suffixText: 'triệu ₫',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: expCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Chi phí (công ty)',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Robux → USD → đồng, with the two numbers side by side that a freelancer must
/// never confuse: the revenue the taxman sees, and the money that reaches the
/// bank. The gap is the fees — and under the 2% method you are taxed on the
/// bigger of the two.
class _PayoutFlowCard extends StatelessWidget {
  const _PayoutFlowCard({required this.breakdown, required this.taxOnGross});

  final PayoutBreakdown breakdown;
  final int taxOnGross;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = breakdown;
    final takeHome = b.vndNet - taxOnGross;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💱', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text('Đường đi của tiền (cả năm)',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            if (b.robux > 0)
              _Row('${_int(b.robux)} Robux → DevEx',
                  '\$${b.usdFromRobux.toStringAsFixed(0)}'),
            if (b.usdDirect > 0)
              _Row('PayPal / chuyển khoản trực tiếp',
                  '\$${b.usdDirect.toStringAsFixed(0)}'),
            _Row('USD gộp (doanh thu tính thuế)',
                '\$${b.usdGross.toStringAsFixed(0)}'),
            _Row('Quy đổi @ ${_int(b.fxRate)} ₫/USD', _vnd(b.vndGross)),
            const Divider(height: 22),
            _Row('− Phí nhận tiền & quy đổi', '−${_vnd(b.vndFee)}'),
            _Row('− Thuế (theo phương án đang chọn)', '−${_vnd(taxOnGross)}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Còn lại thật sự của bạn',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        )),
                  ),
                  Text(_vnd(takeHome),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Phí chiếm ${(b.feeRate * 100).toStringAsFixed(1)}% doanh thu và '
              'KHÔNG được trừ khi khai theo phương pháp 2% — bạn vẫn nộp thuế '
              'trên phần tiền chưa từng chạm tay. Hãy cộng nó vào giá báo cho '
              'studio.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 500tr trap: one đồng over the threshold taxes the *whole* year's revenue,
/// so there is a band where earning more leaves you poorer.
class _CliffWarning extends StatelessWidget {
  const _CliffWarning({required this.cliff, required this.revenue});

  final ExemptionCliff cliff;
  final int revenue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final netNow = revenue - (revenue * 0.02).round();
    final lost = cliff.threshold - netNow;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.dangerous_outlined,
              color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn đang ở "vùng chết" của ngưỡng 500 triệu',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vượt 500 triệu thì thuế đánh trên TOÀN BỘ doanh thu, không '
                  'chỉ phần vượt. Với ${_vnd(revenue)} bạn còn ${_vnd(netNow)} — '
                  'ít hơn ${_vnd(lost)} so với việc dừng đúng ở 500 triệu. Chỉ '
                  'thực sự có lời khi doanh thu vượt ${_vnd(cliff.deadZoneTop)}: '
                  'hoặc nhận thêm việc cho vượt hẳn, hoặc dời hợp đồng sang năm '
                  'sau (khi việc thật sự hoàn thành ở năm sau).',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.best, required this.saving});

  final String best;
  final int saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final which = switch (best) {
      'business' => 'Đăng ký cá nhân kinh doanh',
      'company' => 'Lập công ty TNHH',
      _ => 'Khai theo tiền lương / tiền công',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phương án tối ưu: $which',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                if (saving > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Tiết kiệm ~${_vnd(saving)}/năm so với phương án tốt kế tiếp.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.subtitle,
    required this.annualTax,
    required this.effectiveRate,
    required this.annualNet,
    required this.highlighted,
    required this.rows,
    this.netLabel = 'Thực nhận',
  });

  final String title;
  final String subtitle;
  final int annualTax;
  final double effectiveRate;
  final int annualNet;
  final bool highlighted;
  final List<_Row> rows;
  final String netLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlighted
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (highlighted)
                  Icon(Icons.check_circle,
                      color: theme.colorScheme.primary, size: 20),
              ],
            ),
            Text(subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _vnd(annualTax),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'thuế/năm · ${(effectiveRate * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$netLabel: ${_vnd(annualNet)}/năm',
                style: theme.textTheme.bodyMedium),
            const Divider(height: 24),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('🧮', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 10),
            Text(
              'Nhập số Robux bạn DevEx mỗi tháng và số USD studio trả qua '
              'PayPal.\nApp quy ra đồng, trừ phí, rồi so sánh 3 cách nộp thuế: '
              'lũy tiến tới 35% · cá nhân kinh doanh dịch vụ xuất khẩu ~2% · '
              'công ty TNHH.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              taxDisclaimer,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Regulations ───────────────────────────────

class _NotesTab extends ConsumerWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: taxNotes.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) return _DeadlineReminderCard(onAdd: () => _add(context, ref));
        if (i == taxNotes.length + 1) return const _DisclaimerCard();
        return _NoteCard(note: taxNotes[i - 1]);
      },
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final year = DateTime.now().year;
    final repo = ref.read(eventRepositoryProvider);
    final deadlines = taxDeadlines(year);

    // Idempotent: skip if this year's tax reminders were already added.
    final existing = await repo
        .watchBetween(DateTime(year), DateTime(year, 12, 31, 23, 59))
        .first;
    final already = existing.any((e) => e.title.startsWith('[Thuế]'));
    if (already) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã có nhắc lịch thuế cho năm nay trong Calendar')));
      return;
    }

    for (final d in deadlines) {
      await repo.create(
        title: d.title,
        startTime: DateTime(d.date.year, d.date.month, d.date.day, 9),
        endTime: DateTime(d.date.year, d.date.month, d.date.day, 9, 30),
        description: d.detail,
        isAllDay: true,
        colorTag: 'red',
        reminderMinutes: 7 * 24 * 60, // remind 7 days before
      );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Đã thêm ${deadlines.length} nhắc lịch thuế vào Calendar')));
  }
}

class _DeadlineReminderCard extends StatelessWidget {
  const _DeadlineReminderCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('📅', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhắc lịch thuế ${DateTime.now().year}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Thêm hạn khai quý & quyết toán năm vào Calendar '
                    '(nhắc trước 7 ngày).',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});
  final TaxNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(note.title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      if (note.effective != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            note.effective!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(note.body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Strategies ────────────────────────────────

class _StrategiesTab extends StatelessWidget {
  const _StrategiesTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: taxStrategies.length + 1,
      itemBuilder: (context, i) {
        if (i == taxStrategies.length) return const _DisclaimerCard();
        final s = taxStrategies[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: i == 0,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              leading: Text(s.icon, style: const TextStyle(fontSize: 22)),
              title: Text(s.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(s.summary, style: theme.textTheme.bodyMedium),
                ),
                const SizedBox(height: 12),
                for (var j = 0; j < s.steps.length; j++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Text('${j + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimaryContainer,
                              )),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s.steps[j],
                              style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────── Revenue tracker ────────────────────────────

class _RevenueTab extends ConsumerWidget {
  const _RevenueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final profile =
        ref.watch(taxProfileProvider).valueOrNull ?? const TaxProfile();
    final all = ref.watch(taxRevenueProvider).valueOrNull ?? const [];
    final thisYear = [...all.where((e) => e.year == now.year)]
      ..sort((a, b) => b.month.compareTo(a.month));
    final toDate = thisYear.fold<int>(0, (sum, e) => sum + e.amount);
    final feesToDate = thisYear.fold<int>(0, (sum, e) => sum + e.feeVnd);
    final projection = projectRevenue(toDate: toDate, monthsElapsed: now.month);
    final reserve = computeReserve(
      revenueToDate: toDate,
      projectedAnnualRevenue: projection.projectedAnnual,
      line: profile.line,
    );

    return ListView(
      children: [
        _ThresholdCard(projection: projection, year: now.year),
        const SizedBox(height: 12),
        if (toDate > 0) ...[
          _ReserveCard(reserve: reserve, feesToDate: feesToDate),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Đã ghi nhận (${now.year})',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            FilledButton.tonalIcon(
              onPressed: () => _showAddDialog(context, ref, now, profile),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm khoản'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (thisYear.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Chưa có dữ liệu. Ghi lại mỗi lần DevEx hoặc PayPal về tiền — app '
              'cộng dồn để canh mốc 500 triệu, ước tính thuế cả năm và nhắc bạn '
              'trích quỹ thuế.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final e in thisYear) _RevenueTile(entry: e),
        const SizedBox(height: 8),
        const _DisclaimerCard(),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref, DateTime now,
      TaxProfile profile) async {
    var month = now.month;
    var source = PayoutSource.devex;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    /// Converts whatever the user typed (Robux, USD or triệu VNĐ, depending on
    /// the source) into the gross/fee pair actually stored.
    PayoutBreakdown preview() {
      final raw = int.tryParse(amountCtrl.text.trim()) ?? 0;
      return switch (source) {
        PayoutSource.devex => convertPayout(
            robux: raw,
            devExUsdPerRobux: profile.devExUsdPerRobux,
            usdVndRate: profile.usdVndRate,
            feePct: profile.payoutFeePct,
          ),
        PayoutSource.paypal || PayoutSource.wire => convertPayout(
            usd: raw.toDouble(),
            usdVndRate: profile.usdVndRate,
            feePct: profile.payoutFeePct,
          ),
        // Domestic money arrives in đồng with no FX or platform fee.
        PayoutSource.domestic => convertPayout(
            usd: raw * 1000000 / (profile.usdVndRate == 0 ? 1 : profile.usdVndRate),
            usdVndRate: profile.usdVndRate,
            feePct: 0,
          ),
      };
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final p = preview();
          final unit = switch (source) {
            PayoutSource.devex => 'Robux',
            PayoutSource.domestic => 'triệu ₫',
            _ => 'USD',
          };
          return AlertDialog(
            title: const Text('Ghi nhận tiền về'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<PayoutSource>(
                    initialValue: source,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Nguồn tiền', border: OutlineInputBorder()),
                    items: [
                      for (final s in PayoutSource.values)
                        DropdownMenuItem(
                            value: s, child: Text('${s.icon}  ${s.label}')),
                    ],
                    onChanged: (s) => setLocal(() => source = s ?? source),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: month,
                          decoration: const InputDecoration(
                              labelText: 'Tháng',
                              border: OutlineInputBorder()),
                          items: [
                            for (var m = 1; m <= 12; m++)
                              DropdownMenuItem(
                                  value: m, child: Text('Tháng $m')),
                          ],
                          onChanged: (m) => setLocal(() => month = m ?? month),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (_) => setLocal(() {}),
                          decoration: InputDecoration(
                            labelText: 'Số tiền nhận',
                            suffixText: unit,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú (khách hàng, dự án…)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (p.vndGross > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          if (source == PayoutSource.devex)
                            _Row('DevEx @ ${profile.devExUsdPerRobux}',
                                '\$${p.usdGross.toStringAsFixed(2)}'),
                          _Row('Doanh thu tính thuế', _vnd(p.vndGross)),
                          if (p.vndFee > 0) _Row('Phí ước tính', '−${_vnd(p.vndFee)}'),
                          if (p.vndFee > 0) _Row('Thực về tài khoản', _vnd(p.vndNet)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Lưu')),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      final p = preview();
      final raw = int.tryParse(amountCtrl.text.trim()) ?? 0;
      if (raw > 0 && p.vndGross > 0) {
        await ref.read(taxRepositoryProvider).addRevenue(RevenueEntry(
              id: '${now.year}-$month-${DateTime.now().microsecondsSinceEpoch}',
              year: now.year,
              month: month,
              amount: p.vndGross,
              note: noteCtrl.text.trim(),
              source: source,
              robux: source == PayoutSource.devex ? raw : 0,
              usdCents: source == PayoutSource.domestic
                  ? 0
                  : (p.usdGross * 100).round(),
              feeVnd: p.vndFee,
              fxRate: profile.usdVndRate,
            ));
      }
    }
    amountCtrl.dispose();
    noteCtrl.dispose();
  }
}

class _RevenueTile extends ConsumerWidget {
  const _RevenueTile({required this.entry});
  final RevenueEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final e = entry;

    // Show the original figures, so the row can be checked against a DevEx or
    // PayPal statement without re-doing the maths.
    final origin = [
      if (e.robux > 0) '${_int(e.robux)} R\$',
      if (e.usdCents > 0) '\$${e.usd.toStringAsFixed(2)}',
      if (e.feeVnd > 0) 'phí ${_vnd(e.feeVnd)}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Text('T${e.month}',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
        ),
        title: Row(
          children: [
            Text(_vnd(e.amount),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text(e.source.icon, style: const TextStyle(fontSize: 13)),
          ],
        ),
        subtitle: Text([
          if (origin.isNotEmpty) origin,
          if (e.note.isNotEmpty) e.note,
        ].join(' — ')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Xóa',
          onPressed: () =>
              ref.read(taxRepositoryProvider).removeRevenue(e.id),
        ),
      ),
    );
  }
}

/// The cash-flow half of the feature: how much of the money already received
/// isn't actually yours, and should be sitting in a separate account today.
class _ReserveCard extends StatelessWidget {
  const _ReserveCard({required this.reserve, required this.feesToDate});

  final TaxReserve reserve;
  final int feesToDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (reserve.reserveRate * 100).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏦', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Quỹ thuế nên có ngay bây giờ',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_vnd(reserve.shouldHaveBanked),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                )),
            const SizedBox(height: 4),
            Text(
              'Trích $pct% mỗi lần tiền về — tức khoảng '
              '${_vnd(reserve.perPayoutHint)} cho mỗi 10 triệu nhận được.',
              style: theme.textTheme.bodyMedium,
            ),
            const Divider(height: 24),
            _Row('Thuế dự kiến cả năm', _vnd(reserve.projectedTax)),
            if (feesToDate > 0)
              _Row('Phí PayPal/quy đổi đã mất', _vnd(feesToDate)),
            const SizedBox(height: 8),
            Text(
              reserve.projectedTax == 0
                  ? 'Đang dưới ngưỡng — nhưng app vẫn gợi ý trích sẵn, vì chỉ '
                      'cần một hợp đồng nữa là cả năm bị đánh thuế trên toàn bộ '
                      'doanh thu.'
                  : 'Chuyển số này sang một tài khoản riêng ngay khi tiền về. '
                      'Tiền thuế chưa bao giờ là tiền của bạn — đừng tiêu nó rồi '
                      'đi vay để nộp.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({required this.projection, required this.year});

  final RevenueProjection projection;
  final int year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frac = projection.thresholdFraction.clamp(0.0, 1.0);
    final over = projection.overThreshold;
    final barColor = projection.thresholdFraction >= 1
        ? theme.colorScheme.error
        : projection.thresholdFraction >= 0.8
            ? const Color(0xFFD9A521)
            : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doanh thu $year đến nay',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(_vnd(projection.toDate),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: frac.toDouble(),
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mốc miễn thuế 500 triệu · '
              '${(projection.thresholdFraction * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Divider(height: 24),
            _Row('Ước tính cả năm (run-rate)', _vnd(projection.projectedAnnual)),
            _Row(
              'Thuế dự kiến (cá nhân KD 2%)',
              over ? _vnd(projection.projectedTax) : 'Miễn (dưới ngưỡng)',
            ),
            if (over) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dự kiến vượt 500 triệu/năm → phát sinh nghĩa vụ thuế. '
                        'Chuẩn bị đăng ký kê khai và giữ chứng từ.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────── Risk & compliance ────────────────────────

class _RiskTab extends StatelessWidget {
  const _RiskTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Chấm rủi ro pháp lý từng cách giảm thuế. Mục tiêu: tối ưu HỢP '
            'PHÁP và tránh xa trốn thuế — vì mức phạt luôn lớn hơn số thuế '
            'tiết kiệm được.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        for (final r in taxRisks) _RiskCard(item: r),
        const SizedBox(height: 4),
        Text('Mức phạt & dấu hiệu bị thanh tra',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final p in taxPenalties) _NoteCard(note: p),
        const _DisclaimerCard(),
      ],
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.item});
  final TaxRiskItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (item.level) {
      RiskLevel.safe => const Color(0xFF2E7D32),
      RiskLevel.grey => const Color(0xFFB8860B),
      RiskLevel.illegal => theme.colorScheme.error,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.level.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(item.level.label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            Text(item.what, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.level == RiskLevel.illegal
                      ? Icons.gpp_bad_outlined
                      : Icons.verified_user_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item.consequence,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── DTA (quốc tế) ─────────────────────────────

class _DtaTab extends StatefulWidget {
  const _DtaTab();

  @override
  State<_DtaTab> createState() => _DtaTabState();
}

class _DtaTabState extends State<_DtaTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? dtaCountries
        : dtaCountries
            .where((c) => c.name.toLowerCase().contains(q))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Tìm quốc gia nguồn thu (vd: Mỹ, Singapore, Nhật)…',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(dtaIntro, style: theme.textTheme.bodyMedium),
              ),
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Không thấy "$_query" trong danh sách. VN có hiệp định với '
                    'hơn 80 nước — tra cứu tại cơ quan thuế nếu không có ở đây.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              else
                for (final c in matches) _DtaCard(country: c),
              if (q.isEmpty) ...[
                const SizedBox(height: 4),
                Text('Cách xin miễn/giảm & khấu trừ',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (var i = 0; i < dtaSteps.length; i++)
                  _StepRow(index: i + 1, text: dtaSteps[i]),
              ],
              const SizedBox(height: 8),
              const _DisclaimerCard(),
            ],
          ),
        ),
      ],
    );
  }
}

class _DtaCard extends StatelessWidget {
  const _DtaCard({required this.country});
  final DtaCountry country;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (country.status) {
      DtaStatus.inForce => const Color(0xFF2E7D32),
      DtaStatus.signedNotInForce => const Color(0xFFB8860B),
      DtaStatus.none => theme.colorScheme.error,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
          title: Text(country.name,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('${country.status.emoji} ${country.status.label}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(country.note, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text('$index',
                style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimaryContainer)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// ────────────────────────────────── Roblox ─────────────────────────────────

/// The tab that knows this freelancer's actual business: Robux, DevEx, PayPal,
/// and the paperwork that makes all of it defensible.
class _RobloxTab extends ConsumerWidget {
  const _RobloxTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile =
        ref.watch(taxProfileProvider).valueOrNull ?? const TaxProfile();

    // A concrete anchor: what a single minimum DevEx cash-out is really worth.
    final minCashout = convertPayout(
      robux: PayoutDefaults.devExMinRobux,
      devExUsdPerRobux: profile.devExUsdPerRobux,
      usdVndRate: profile.usdVndRate,
      feePct: profile.payoutFeePct,
    );

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(robloxIntro, style: theme.textTheme.bodyMedium),
        ),
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Một lần rút DevEx tối thiểu '
                  '(${_int(PayoutDefaults.devExMinRobux)} R\$)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '\$${minCashout.usdGross.toStringAsFixed(2)} → '
                  '${_vnd(minCashout.vndGross)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sau phí ${profile.payoutFeePct}% còn '
                  '${_vnd(minCashout.vndNet)} về tài khoản — nhưng thuế vẫn tính '
                  'trên ${_vnd(minCashout.vndGross)}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final f in robloxFacts) _NoteCard(note: f),
        const SizedBox(height: 8),
        Text('Việc cần làm, theo thứ tự',
            style:
                theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (var i = 0; i < robloxSetupSteps.length; i++)
          _StepRow(index: i + 1, text: robloxSetupSteps[i]),
        const SizedBox(height: 12),
        const _ChecklistCard(items: robloxDocChecklist),
        const SizedBox(height: 12),
        Text('Chi phí hợp lệ của một 3D artist',
            style:
                theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'Chỉ trừ được khi kê khai theo LỢI NHUẬN (công ty TNHH). Ở phương pháp '
          '2% trên doanh thu thì không trừ chi phí — đó chính là cái giá của sự '
          'đơn giản, và là lý do tab Máy tính so sánh cả hai.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        for (final e in modelerExpenses) _ExpenseCard(item: e),
        const _DisclaimerCard(),
      ],
    );
  }
}

/// The evidence pack, as a card you can tick through mentally before a filing.
class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📁', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Hồ sơ cần lưu (bảo hiểm khi bị đối chiếu)',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_box_outlined,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            Text(item, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.item});
  final ExpenseItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(item.note,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────── Helpers ─────────────────────────────────

/// Formats đồng with thousands separators, e.g. 12_500_000 → "12.500.000 ₫".
String _vnd(int dong) => '${_int(dong)} ₫';

/// Thousands-separated integer, e.g. 100000 → "100.000".
String _int(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$buf';
}
