// Renders every real screen inside the real AppShell with seeded sample data
// to build/screens_preview/<route>_<theme>.png — the review sheet for the
// per-screen polish pass. Office (a live simulation) is skipped.
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
import 'package:mind_noron/l10n/app_localizations.dart';
import 'package:mind_noron/presentation/navigation/app_router.dart' as nav;
import 'package:mind_noron/presentation/navigation/destinations.dart';

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

  final only = Platform.environment['SCREEN'];
  for (final d in AppDestinations.all) {
    if (d.route == nav.Routes.office) continue;
    final slug = d.route.substring(1);
    if (only != null && only != slug) continue;
    for (final (theme, tname) in [
      (AppTheme.dark, 'dark'),
      (AppTheme.light, 'light'),
    ]) {
      testWidgets('$slug renders ($tname)', (tester) async {
        tester.view.physicalSize = const Size(1440, 940);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() => db.close());
        await tester.runAsync(() => _seed(db));

        // The app's real route table, starting on this destination.
        final shell = nav.appRouter.configuration.routes
            .whereType<ShellRoute>()
            .first;
        final router = GoRouter(
          initialLocation: d.route,
          routes: [shell],
        );
        final key = Key('$slug-$tname');
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
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
              ),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 60)));
          await tester.pump(const Duration(milliseconds: 200));
        }
        // Step frames (not one jump) so delayed entrances and springs run;
        // pumpAndSettle can't be used — some screens animate forever.
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }

        Future<void> capture(String name) async {
          final boundary =
              tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build/screens_preview/$name.png');
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }

        await capture('${slug}_$tname');

        // The Focus screen's second face: a running session.
        if (d.route == nav.Routes.timer) {
          await tester.tap(find.text('Start Focus'));
          for (var i = 0; i < 40; i++) {
            await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 5)));
            await tester.pump(const Duration(milliseconds: 80));
          }
          await capture('${slug}_running_$tname');
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      });
    }
  }
}
