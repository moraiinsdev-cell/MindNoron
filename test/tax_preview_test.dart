// Renders the real TaxScreen tabs to PNGs under build/tax_preview/ so the tax
// hub UI can be reviewed without launching the desktop app (which can be blocked
// by Smart App Control). Doubles as a smoke test that every tab lays out.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/core/providers/app_providers.dart';
import 'package:mind_noron/data/database/app_database.dart';
import 'package:mind_noron/features/tax/tax_living_cost.dart';
import 'package:mind_noron/features/tax/tax_models.dart';
import 'package:mind_noron/features/tax/tax_repository.dart';
import 'package:mind_noron/features/tax/tax_savings.dart';
import 'package:mind_noron/features/tax/tax_screen.dart';

import 'support/load_fonts.dart';

Future<void> _capture(WidgetTester tester, Key key, String name) async {
  final boundary =
      tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/tax_preview/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('tax hub tabs render to preview PNGs', (tester) async {
    // Wide enough for all nine tab segments — a narrower view scrolls the later
    // ones off-screen and taps on them silently miss. (Inter renders wider
    // than the old test font, hence the extra room.)
    tester.view.physicalSize = const Size(1960, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());

    const key = Key('tax-preview');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          taxProfileProvider.overrideWith(
            // A plausible Roblox 3D freelancer: 200k Robux/month via DevEx plus
            // $1.500/month of direct commissions.
            (ref) => Stream.value(const TaxProfile(
              mode: IncomeMode.usdRobux,
              monthlyRobux: 200000,
              monthlyUsd: 1500,
              dependents: 2,
              expenseRatioPct: 35,
              line: BusinessLine.exportedServices,
              monthlySpend: 20000000,
            )),
          ),
          // The expense log says living costs are 26tr/month while the user
          // typed 20tr — far enough apart that the tab speaks up and offers the
          // real figure, and warns that the runway on screen is flattering.
          livingCostProvider.overrideWith(
            (ref) => Stream.value(LivingCostEstimate(
              essentialMonthly: 26000000,
              totalMonthly: 27000000,
              monthsCovered: 3,
              from: DateTime(DateTime.now().year, DateTime.now().month - 3),
              to: DateTime(DateTime.now().year, DateTime.now().month),
              entryCount: 48,
            )),
          ),
          // Envelopes part-way filled: the buffer is short, gear is nearly
          // there, and the tax fund is behind what the revenue implies — so the
          // Quỹ tab renders every state it can be in.
          taxFundTxnsProvider.overrideWith(
            (ref) => Stream.value([
              FundTxn(
                  id: 't1',
                  fundId: 'buffer',
                  at: DateTime.now().subtract(const Duration(days: 40)),
                  amount: 28000000,
                  kind: FundTxnKind.split,
                  note: 'Chia 15% từ 80.000.000 ₫'),
              FundTxn(
                  id: 't2',
                  fundId: 'emergency',
                  at: DateTime.now().subtract(const Duration(days: 40)),
                  amount: 21000000,
                  kind: FundTxnKind.split),
              FundTxn(
                  id: 't3',
                  fundId: 'gear',
                  at: DateTime.now().subtract(const Duration(days: 12)),
                  amount: 31000000,
                  kind: FundTxnKind.split),
              FundTxn(
                  id: 't4',
                  fundId: 'freedom',
                  at: DateTime.now().subtract(const Duration(days: 12)),
                  amount: 14000000,
                  kind: FundTxnKind.split),
              FundTxn(
                  id: 't5',
                  fundId: 'tax',
                  at: DateTime.now().subtract(const Duration(days: 12)),
                  amount: 2000000,
                  kind: FundTxnKind.split),
              FundTxn(
                  id: 't6',
                  fundId: 'buffer',
                  at: DateTime.now().subtract(const Duration(days: 3)),
                  amount: -6000000,
                  kind: FundTxnKind.withdraw,
                  note: 'Lương tháng này'),
            ]),
          ),
          taxRevenueProvider.overrideWith(
            (ref) => Stream.value([
              RevenueEntry(
                id: 'a',
                year: DateTime.now().year,
                month: 1,
                amount: 60000000,
                source: PayoutSource.devex,
                robux: 660000,
                usdCents: 231000,
                feeVnd: 2640000,
              ),
              RevenueEntry(
                id: 'b',
                year: DateTime.now().year,
                month: 2,
                amount: 80000000,
                source: PayoutSource.paypal,
                usdCents: 307700,
                feeVnd: 3520000,
                note: 'Commission — studio Obby Kingdom',
              ),
              RevenueEntry(
                id: 'c',
                year: DateTime.now().year,
                month: 3,
                amount: 55000000,
                source: PayoutSource.devex,
                robux: 605000,
                usdCents: 211750,
                feeVnd: 2420000,
              ),
            ]),
          ),
        ],
        child: const RepaintBoundary(
          key: key,
          child: MaterialApp(home: Scaffold(body: TaxScreen())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tab 1 — the roadmap is the landing view: countdown + filing cadence.
    expect(find.text('Khai theo tháng hay theo quý?'), findsOneWidget);
    await _capture(tester, key, '1_roadmap');

    await tester.tap(find.text('Máy tính'));
    await tester.pumpAndSettle();
    expect(find.text('Đường đi của tiền (cả năm)'), findsOneWidget);
    await _capture(tester, key, '2_calculator');

    // The comparison cards sit below the fold — scroll them into view (which is
    // also what forces the lazy ListView to build them).
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Công ty TNHH một thành viên'), findsOneWidget);
    await _capture(tester, key, '2b_calculator_compare');

    for (final (label, name) in [
      ('Doanh thu', '3_revenue'),
      ('Quỹ', '3b_funds'),
      ('Roblox', '4_roblox'),
      ('Ngân hàng', '5_banking'),
      ('Rủi ro', '6_risk'),
      ('Quốc tế', '7_dta'),
      ('Quy định', '8_regulations'),
      ('Tối ưu', '9_strategies'),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await _capture(tester, key, name);
    }

    // Cleanly flush any pending stream-close timers before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
