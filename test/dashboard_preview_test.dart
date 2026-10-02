// Renders the real Dashboard inside the real AppShell, seeded with sample
// data, at three window widths (3-, 2- and 1-column bento) to
// build/ui_preview/dashboard_*.png. Doubles as a layout smoke test: any
// overflow or intrinsic-size error in the bento fails the test.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_noron/core/enums.dart';
import 'package:mind_noron/core/providers/app_providers.dart';
import 'package:mind_noron/core/theme/app_theme.dart';
import 'package:mind_noron/data/database/app_database.dart';
import 'package:mind_noron/data/repositories/habit_repository.dart';
import 'package:mind_noron/data/repositories/settings_repository.dart';
import 'package:mind_noron/data/repositories/task_repository.dart';
import 'package:mind_noron/data/repositories/timer_repository.dart';
import 'package:mind_noron/features/dashboard/dashboard_screen.dart';
import 'package:mind_noron/l10n/app_localizations.dart';
import 'package:mind_noron/presentation/navigation/app_router.dart';
import 'package:mind_noron/presentation/navigation/destinations.dart';
import 'package:mind_noron/presentation/shell/app_shell.dart';

import 'support/load_fonts.dart';

Future<void> _seed(AppDatabase db) async {
  final tasks = TaskRepository(db);
  for (final (t, p) in [
    ('Finish the hero character model for the studio', 1),
    ('Reply to the PayPal client email', 2),
    ('Export this month\'s DevEx', 3),
    ('Plan next week\'s sprint', 3),
  ]) {
    await tasks.create(title: t, priority: p);
  }
  final habits = HabitRepository(db);
  final ids = [
    await habits.create('Read', emoji: '📖'),
    await habits.create('Run', emoji: '🏃'),
    await habits.create('Pray', emoji: '🙏'),
  ];
  await habits.toggleToday(ids[0]);
  await habits.toggleToday(ids[2]);
  final now = DateTime.now();
  await TimerRepository(db, tasks).logSession(
    type: SessionType.work,
    start: now.subtract(const Duration(minutes: 150)),
    end: now,
    plannedMinutes: 150,
    actualMinutes: 150,
  );
  await SettingsRepository(db).setUserName('Huy');
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('dashboard bento renders at three widths', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());
    await tester.runAsync(() => _seed(db));

    for (final (theme, name, size) in [
      (AppTheme.dark, 'dashboard_wide_dark', const Size(1560, 1000)),
      (AppTheme.light, 'dashboard_wide_light', const Size(1560, 1000)),
      (AppTheme.dark, 'dashboard_medium_dark', const Size(1100, 1150)),
      (AppTheme.dark, 'dashboard_narrow_dark', const Size(640, 1500)),
    ]) {
      tester.view.physicalSize = size;
      final key = Key(name);
      final router = GoRouter(
        initialLocation: Routes.dashboard,
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              for (final d in AppDestinations.all)
                GoRoute(
                  path: d.route,
                  builder: (c, s) => d.route == Routes.dashboard
                      ? const DashboardScreen()
                      : const SizedBox(),
                ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: theme,
              routerConfig: router,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
            ),
          ),
        ),
      );
      // Let drift streams deliver, then let the springs settle.
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      final boundary =
          tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.25);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/ui_preview/$name.png');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  });
}
