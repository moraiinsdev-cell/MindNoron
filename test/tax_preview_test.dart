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
import 'package:mind_noron/features/tax/tax_models.dart';
import 'package:mind_noron/features/tax/tax_repository.dart';
import 'package:mind_noron/features/tax/tax_screen.dart';

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
  testWidgets('tax hub tabs render to preview PNGs', (tester) async {
    tester.view.physicalSize = const Size(1040, 1500);
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
            )),
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

    // Tab 1 — Robux/USD converted to đồng, then the 3-way comparison below it.
    expect(find.text('Đường đi của tiền (cả năm)'), findsOneWidget);
    await _capture(tester, key, '1_calculator');

    // The comparison cards sit below the fold — scroll them into view (which is
    // also what forces the lazy ListView to build them).
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Công ty TNHH một thành viên'), findsOneWidget);
    await _capture(tester, key, '1b_calculator_compare');

    for (final (label, name) in [
      ('Doanh thu', '2_revenue'),
      ('Roblox', '3_roblox'),
      ('Rủi ro', '4_risk'),
      ('Quốc tế', '5_dta'),
      ('Quy định', '6_regulations'),
      ('Tối ưu', '7_strategies'),
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
