import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/widgets/common/section_scaffold.dart';
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

enum _Tab { calculator, regulations, strategies }

class _TaxScreenState extends ConsumerState<TaxScreen> {
  _Tab _tab = _Tab.calculator;

  final _incomeCtrl = TextEditingController();
  final _depsCtrl = TextEditingController();
  final _insCtrl = TextEditingController();
  BusinessLine _line = BusinessLine.exportedServices;
  bool _seeded = false;

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _depsCtrl.dispose();
    _insCtrl.dispose();
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
    _line = p.line;
  }

  int get _annualIncome =>
      (int.tryParse(_incomeCtrl.text.trim()) ?? 0) * 1000000;
  int get _dependents => int.tryParse(_depsCtrl.text.trim()) ?? 0;
  int get _monthlyInsurance =>
      (int.tryParse(_insCtrl.text.trim()) ?? 0) * 1000000;

  void _persist() {
    ref.read(taxRepositoryProvider).save(TaxProfile(
          annualIncome: _annualIncome,
          dependents: _dependents,
          monthlyInsurance: _monthlyInsurance,
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
          SegmentedButton<_Tab>(
            segments: const [
              ButtonSegment(
                value: _Tab.calculator,
                icon: Icon(Icons.calculate_outlined),
                label: Text('Máy tính'),
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
          const SizedBox(height: 16),
          Expanded(
            child: switch (_tab) {
              _Tab.calculator => _CalculatorTab(
                  incomeCtrl: _incomeCtrl,
                  depsCtrl: _depsCtrl,
                  insCtrl: _insCtrl,
                  line: _line,
                  annualIncome: _annualIncome,
                  dependents: _dependents,
                  monthlyInsurance: _monthlyInsurance,
                  onChanged: () {
                    setState(() {});
                    _persist();
                  },
                  onLineChanged: (l) {
                    setState(() => _line = l);
                    _persist();
                  },
                ),
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
    required this.line,
    required this.annualIncome,
    required this.dependents,
    required this.monthlyInsurance,
    required this.onChanged,
    required this.onLineChanged,
  });

  final TextEditingController incomeCtrl;
  final TextEditingController depsCtrl;
  final TextEditingController insCtrl;
  final BusinessLine line;
  final int annualIncome;
  final int dependents;
  final int monthlyInsurance;
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
    final hasIncome = annualIncome > 0;
    final businessCheaper = business.annualTax <= salary.annualTax;
    final saving = (salary.annualTax - business.annualTax).abs();

    return ListView(
      children: [
        _InputsCard(
          incomeCtrl: incomeCtrl,
          depsCtrl: depsCtrl,
          insCtrl: insCtrl,
          line: line,
          onChanged: onChanged,
          onLineChanged: onLineChanged,
        ),
        const SizedBox(height: 14),
        if (!hasIncome)
          const _HintCard()
        else ...[
          _WinnerBanner(
            businessCheaper: businessCheaper,
            saving: saving,
          ),
          const SizedBox(height: 12),
          _ResultCard(
            title: 'Khai theo cá nhân kinh doanh',
            subtitle: line.label,
            annualTax: business.annualTax,
            effectiveRate: business.effectiveRate,
            annualNet: business.annualNet,
            highlighted: businessCheaper,
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
            title: 'Khai theo tiền lương / tiền công',
            subtitle: 'Biểu lũy tiến 5%–35%, giảm trừ gia cảnh',
            annualTax: salary.annualTax,
            effectiveRate: salary.effectiveRate,
            annualNet: salary.annualNet,
            highlighted: !businessCheaper,
            rows: [
              _Row('Thu nhập tính thuế/năm', _vnd(salary.annualTaxableIncome)),
              _Row('Thuế suất biên', '${(salary.marginalRate * 100).round()}%'),
              const _Row('Giảm trừ bản thân', '15,5 triệu/tháng'),
              if (dependents > 0)
                _Row('Người phụ thuộc', '$dependents × 6,2 triệu/tháng'),
            ],
          ),
          const SizedBox(height: 12),
          const _DisclaimerCard(),
        ],
      ],
    );
  }
}

class _InputsCard extends StatelessWidget {
  const _InputsCard({
    required this.incomeCtrl,
    required this.depsCtrl,
    required this.insCtrl,
    required this.line,
    required this.onChanged,
    required this.onLineChanged,
  });

  final TextEditingController incomeCtrl;
  final TextEditingController depsCtrl;
  final TextEditingController insCtrl;
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  const _WinnerBanner({required this.businessCheaper, required this.saving});

  final bool businessCheaper;
  final int saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final which = businessCheaper
        ? 'Đăng ký cá nhân kinh doanh'
        : 'Khai theo tiền lương / tiền công';
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
                    'Tiết kiệm ~${_vnd(saving)}/năm so với cách còn lại.',
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
  });

  final String title;
  final String subtitle;
  final int annualTax;
  final double effectiveRate;
  final int annualNet;
  final bool highlighted;
  final List<_Row> rows;

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
            Text('Thực nhận: ${_vnd(annualNet)}/năm',
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
