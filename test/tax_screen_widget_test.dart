// Pumps the real TaxScreen with a seeded profile (no database) and verifies the
// calculator renders both options and picks exported-services as the optimum.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/core/providers/app_providers.dart';
import 'package:mind_noron/data/database/app_database.dart';
import 'package:mind_noron/features/tax/tax_models.dart';
import 'package:mind_noron/features/tax/tax_repository.dart';
import 'package:mind_noron/features/tax/tax_screen.dart';

void main() {
  testWidgets('tax screen computes and highlights the optimal option',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // 1.2 tỷ/năm foreign income, 1 dependent, exporting services.
          taxProfileProvider.overrideWith(
            (ref) => Stream.value(const TaxProfile(
              annualIncome: 1200000000,
              dependents: 1,
              line: BusinessLine.exportedServices,
            )),
          ),
          // Static stream so the revenue tab doesn't spin up the real Drift
          // stream (whose teardown leaves a pending timer under FakeAsync).
          taxRevenueProvider
              .overrideWith((ref) => Stream.value(const <RevenueEntry>[])),
        ],
        child: const MaterialApp(home: TaxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // All three comparison cards are present.
    expect(find.text('Cá nhân kinh doanh'), findsOneWidget);
    expect(find.text('Tiền lương / tiền công'), findsOneWidget);
    expect(find.text('Công ty TNHH một thành viên'), findsOneWidget);

    // At 1.2 tỷ, registering as an individual business is the optimum.
    expect(
      find.textContaining('Đăng ký cá nhân kinh doanh'),
      findsWidgets,
    );

    // The 2% figure (24.000.000 ₫) shows for exported services.
    expect(find.textContaining('24.000.000'), findsWidgets);

    // Switching to the Regulations tab renders the curated notes.
    await tester.tap(find.text('Quy định'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bỏ thuế khoán'), findsOneWidget);

    // Risk tab renders risk-rated items incl. the illegal-evasion warning.
    await tester.tap(find.text('Rủi ro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trốn thuế'), findsWidgets);

    // Revenue tab renders the 500tr threshold gauge and empty state.
    await tester.tap(find.text('Doanh thu'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mốc miễn thuế 500 triệu'), findsOneWidget);
  });
}
