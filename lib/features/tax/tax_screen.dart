import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/widgets/common/section_scaffold.dart';
import 'tax_dta.dart';
import 'tax_engine.dart';
import 'tax_knowledge.dart';
import 'tax_models.dart';
import 'tax_repository.dart';

/// Offline Tax hub for a freelancer billing foreign clients: a calculator that
/// compares taxing the same income as employment (progressive) vs as an
/// individual business exporting services (flat ~2%), a regulations digest, and
/// legal optimization strategies. No network, no LLM — pure local math + curated
/// content, consistent with the app's offline-first design.
class TaxScreen extends ConsumerStatefulWidget {
  const TaxScreen({super.key});

  @override
  ConsumerState<TaxScreen> createState() => _TaxScreenState();
}

enum _Tab { calculator, revenue, risk, dta, regulations, strategies }

class _TaxScreenState extends ConsumerState<TaxScreen> {
  _Tab _tab = _Tab.calculator;

  final _incomeCtrl = TextEditingController();
  final _depsCtrl = TextEditingController();
  final _insCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  BusinessLine _line = BusinessLine.exportedServices;
  bool _seeded = false;

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _depsCtrl.dispose();
    _insCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  void _seed(TaxProfile p) {
    if (_seeded) return;
    _seeded = true;
    if (p.annualIncome > 0) {
      _incomeCtrl.text = (p.annualIncome ~/ 1000000).toString();
    }
    if (p.dependents > 0) _depsCtrl.text = p.dependents.toString();
    if (p.monthlyInsurance > 0) {
      _insCtrl.text = (p.monthlyInsurance ~/ 1000000).toString();
    }
    _expCtrl.text = p.expenseRatioPct.toString();
    _line = p.line;
  }

  int get _annualIncome =>
      (int.tryParse(_incomeCtrl.text.trim()) ?? 0) * 1000000;
  int get _dependents => int.tryParse(_depsCtrl.text.trim()) ?? 0;
  int get _monthlyInsurance =>
      (int.tryParse(_insCtrl.text.trim()) ?? 0) * 1000000;
  int get _expenseRatioPct =>
      (int.tryParse(_expCtrl.text.trim()) ?? 30).clamp(0, 100);

  void _persist() {
    ref.read(taxRepositoryProvider).save(TaxProfile(
          annualIncome: _annualIncome,
          dependents: _dependents,
          monthlyInsurance: _monthlyInsurance,
          expenseRatioPct: _expenseRatioPct,
          line: _line,
        ));
  }

  @override
  Widget build(BuildContext context) {
    // Seed inputs once from the persisted profile.
    ref.watch(taxProfileProvider).whenData(_seed);

    return SectionScaffold(
      title: 'Thuế',
      subtitle:
          'Trợ lý thuế cho freelancer nhận tiền từ nước ngoài — tính, hiểu quy '
          'định, và tối ưu hợp pháp (offline).',
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
                  incomeCtrl: _incomeCtrl,
                  depsCtrl: _depsCtrl,
                  insCtrl: _insCtrl,
                  expCtrl: _expCtrl,
                  line: _line,
                  annualIncome: _annualIncome,
                  dependents: _dependents,
                  monthlyInsurance: _monthlyInsurance,
                  expenseRatioPct: _expenseRatioPct,
                  onChanged: () {
                    setState(() {});
                    _persist();
                  },
                  onLineChanged: (l) {
                    setState(() => _line = l);
                    _persist();
                  },
                ),
              _Tab.revenue => const _RevenueTab(),
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
    required this.incomeCtrl,
    required this.depsCtrl,
    required this.insCtrl,
    required this.expCtrl,
    required this.line,
    required this.annualIncome,
    required this.dependents,
    required this.monthlyInsurance,
    required this.expenseRatioPct,
    required this.onChanged,
    required this.onLineChanged,
  });

  final TextEditingController incomeCtrl;
  final TextEditingController depsCtrl;
  final TextEditingController insCtrl;
  final TextEditingController expCtrl;
  final BusinessLine line;
  final int annualIncome;
  final int dependents;
  final int monthlyInsurance;
  final int expenseRatioPct;
  final VoidCallback onChanged;
  final ValueChanged<BusinessLine> onLineChanged;

  @override
  Widget build(BuildContext context) {
    final salary = computeSalaryTax(
      annualGross: annualIncome,
      dependents: dependents,
      monthlyInsurance: monthlyInsurance,
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

    return ListView(
      children: [
        _InputsCard(
          incomeCtrl: incomeCtrl,
          depsCtrl: depsCtrl,
          insCtrl: insCtrl,
          expCtrl: expCtrl,
          line: line,
          onChanged: onChanged,
          onLineChanged: onLineChanged,
        ),
        const SizedBox(height: 14),
        if (!hasIncome)
          const _HintCard()
        else ...[
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
    final report = '''
BÁO CÁO THUẾ — Thu nhập từ nước ngoài
Thu nhập/năm: ${_vnd(annualIncome)}
Người phụ thuộc: $dependents

1) Cá nhân kinh doanh (${line.label})
   Thuế/năm: ${_vnd(business.annualTax)} (${pct(business.effectiveRate)})
2) Tiền lương / tiền công (lũy tiến)
   Thuế/năm: ${_vnd(salary.annualTax)} (${pct(salary.effectiveRate)})
3) Công ty TNHH (chi phí $expenseRatioPct%)
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
    required this.incomeCtrl,
    required this.depsCtrl,
    required this.insCtrl,
    required this.expCtrl,
    required this.line,
    required this.onChanged,
    required this.onLineChanged,
  });

  final TextEditingController incomeCtrl;
  final TextEditingController depsCtrl;
  final TextEditingController insCtrl;
  final TextEditingController expCtrl;
  final BusinessLine line;
  final VoidCallback onChanged;
  final ValueChanged<BusinessLine> onLineChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: incomeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Thu nhập từ nước ngoài / năm',
                suffixText: 'triệu ₫',
                border: OutlineInputBorder(),
                helperText: 'Ví dụ: 600 = 600 triệu đồng/năm',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<BusinessLine>(
              initialValue: line,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ngành nghề (khi khai cá nhân kinh doanh)',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final l in BusinessLine.values)
                  DropdownMenuItem(value: l, child: Text(l.label)),
              ],
              onChanged: (l) => l == null ? null : onLineChanged(l),
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
              'Nhập thu nhập/năm để so sánh hai cách nộp thuế:\n'
              'khai lũy tiến (tới 35%) vs đăng ký cá nhân kinh doanh dịch vụ '
              'xuất khẩu (~2%).',
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

class _NotesTab extends StatelessWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: taxNotes.length + 1,
      itemBuilder: (context, i) {
        if (i == taxNotes.length) return const _DisclaimerCard();
        final n = taxNotes[i];
        return _NoteCard(note: n);
      },
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
    final all = ref.watch(taxRevenueProvider).valueOrNull ?? const [];
    final thisYear = [...all.where((e) => e.year == now.year)]
      ..sort((a, b) => b.month.compareTo(a.month));
    final toDate =
        thisYear.fold<int>(0, (sum, e) => sum + e.amount);
    final projection =
        projectRevenue(toDate: toDate, monthsElapsed: now.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            children: [
              _ThresholdCard(projection: projection, year: now.year),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Đã ghi nhận (${now.year})',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  FilledButton.tonalIcon(
                    onPressed: () => _showAddDialog(context, ref, now),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm tháng'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (thisYear.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Chưa có dữ liệu. Ghi lại doanh thu mỗi tháng để theo dõi '
                    'mốc 500 triệu và ước tính thuế cả năm.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              else
                for (final e in thisYear)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Text('T${e.month}',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color:
                                    theme.colorScheme.onSecondaryContainer)),
                      ),
                      title: Text(_vnd(e.amount),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: e.note.isEmpty ? null : Text(e.note),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Xóa',
                        onPressed: () => ref
                            .read(taxRepositoryProvider)
                            .removeRevenue(e.id),
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              const _DisclaimerCard(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog(
      BuildContext context, WidgetRef ref, DateTime now) async {
    var month = now.month;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Thêm doanh thu tháng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: month,
                decoration: const InputDecoration(
                    labelText: 'Tháng', border: OutlineInputBorder()),
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(value: m, child: Text('Tháng $m')),
                ],
                onChanged: (m) => setLocal(() => month = m ?? month),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Doanh thu',
                  suffixText: 'triệu ₫',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                    labelText: 'Ghi chú (tùy chọn)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Lưu')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final trieu = int.tryParse(amountCtrl.text.trim()) ?? 0;
      if (trieu > 0) {
        await ref.read(taxRepositoryProvider).addRevenue(RevenueEntry(
              id: '${now.year}-$month-${DateTime.now().microsecondsSinceEpoch}',
              year: now.year,
              month: month,
              amount: trieu * 1000000,
              note: noteCtrl.text.trim(),
            ));
      }
    }
    amountCtrl.dispose();
    noteCtrl.dispose();
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

// ───────────────────────────────── Helpers ─────────────────────────────────

/// Formats đồng with thousands separators, e.g. 12_500_000 → "12.500.000 ₫".
String _vnd(int dong) {
  final s = dong.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${dong < 0 ? '-' : ''}$buf ₫';
}
