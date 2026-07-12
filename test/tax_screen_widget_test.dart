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
    // Wide enough that all seven tab segments fit without horizontal scrolling —
    // otherwise tapping a tab by label silently misses an off-screen segment.
    tester.view.physicalSize = const Size(1500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // 1.2 tỷ/năm foreign income, 1 dependent, exporting services. Entered
          // as a flat VND figure rather than USD + Robux.
          taxProfileProvider.overrideWith(
            (ref) => Stream.value(const TaxProfile(
              mode: IncomeMode.vnd,
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
        // AppShell wraps every screen in a Scaffold in the real app; mirror
        // that so bare Material widgets (e.g. the DTA search field) resolve.
        child: const MaterialApp(home: Scaffold(body: TaxScreen())),
      ),
    );
    await tester.pumpAndSettle();

    // The hub opens on the roadmap: the filing cadence is answered up front.
    expect(find.text('Khai theo tháng hay theo quý?'), findsOneWidget);
    expect(find.text('Khai theo QUÝ'), findsOneWidget);
    expect(find.text('ÁP DỤNG CHO BẠN'), findsOneWidget);
    expect(find.textContaining('Còn '), findsWidgets); // countdown to 31/12

    await tester.tap(find.text('Máy tính'));
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

    // DTA tab lists treaty countries incl. the US (signed-not-in-force).
    await tester.tap(find.text('Quốc tế'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hoa Kỳ'), findsOneWidget);

    // Roblox tab prices a minimum DevEx cash-out and warns that tax lands on
    // the gross, not on what survives the PayPal fee.
    await tester.tap(find.text('Roblox'));
    await tester.pumpAndSettle();
    expect(find.textContaining('30.000 R\$'), findsWidgets);
    expect(
      find.textContaining('Thuế tính trên USD gộp'),
      findsOneWidget,
    );

    // Banking tab leads with the misunderstanding that costs the most: money
    // arriving in VNĐ through a correspondent bank has NOT had tax withheld.
    await tester.tap(find.text('Ngân hàng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('đã bị khấu trừ thuế chưa?'), findsOneWidget);
    expect(find.textContaining('KHÔNG. Đó là chuyển tiền'), findsOneWidget);
  });

  testWidgets('penalties state exact thresholds and cite their source',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          taxProfileProvider
              .overrideWith((ref) => Stream.value(const TaxProfile())),
          taxRevenueProvider
              .overrideWith((ref) => Stream.value(const <RevenueEntry>[])),
        ],
        child: const MaterialApp(home: Scaffold(body: TaxScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rủi ro'));
    await tester.pumpAndSettle();

    // The penalty list sits below the risk items — scroll it into view (which is
    // what forces the lazy ListView to build it).
    await tester.dragUntilVisible(
      find.textContaining('lằn ranh bắt đầu từ 100 triệu'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    // "Số tiền lớn thì đi tù" is useless. The criminal threshold is a number.
    expect(
      find.textContaining('lằn ranh bắt đầu từ 100 triệu'),
      findsOneWidget,
    );
    // And every penalty carries the law it comes from.
    expect(find.textContaining('Điều 200 Bộ luật Hình sự'), findsWidgets);
    expect(find.textContaining('Căn cứ:'), findsWidgets);
  });
}
