// Renders the real AppShell (glass nav rail over the aurora backdrop) to
// build/ui_preview/shell_*.png so the frame every screen lives in can be
// reviewed without launching the desktop app.
// ignore_for_file: prefer_const_constructors
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_noron/core/providers/app_providers.dart';
import 'package:mind_noron/core/theme/app_theme.dart';
import 'package:mind_noron/data/database/app_database.dart';
import 'package:mind_noron/l10n/app_localizations.dart';
import 'package:mind_noron/presentation/navigation/app_router.dart';
import 'package:mind_noron/presentation/shell/app_shell.dart';
import 'package:mind_noron/presentation/widgets/common/section_scaffold.dart';
import 'package:mind_noron/presentation/widgets/common/ui_kit.dart';

import 'support/load_fonts.dart';

const _allRoutes = [
  Routes.dashboard,
  Routes.office,
  Routes.catalyst,
  Routes.tax,
  Routes.bible,
  Routes.tasks,
  Routes.calendar,
  Routes.timer,
  Routes.inbox,
  Routes.notes,
  Routes.journal,
  Routes.habits,
  Routes.expenses,
  Routes.activity,
  Routes.settings,
];

Widget _body() {
  return SectionScaffold(
    title: 'Good afternoon, Huy',
    subtitle: 'Saturday · July 26',
    icon: Icons.dashboard_rounded,
    actions: [
      FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Quick capture'),
      ),
    ],
    child: ListView(
      children: [
        Row(
          children: const [
            Expanded(
              child: StatTile(
                icon: Icons.timer_outlined,
                label: 'Focus today',
                value: '2h 30m',
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: StatTile(
                icon: Icons.check_circle_outline,
                label: 'Tasks done',
                value: '5',
                accent: AppTheme.accentBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AccentCard(
          child: Row(
            children: const [
              Icon(Icons.bolt, color: AppTheme.seed),
              SizedBox(width: 8),
              Expanded(
                child: Text('Focus energy',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              InfoPill(label: '3/5', icon: Icons.bolt, filled: true),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> _capture(WidgetTester tester, Key key, String name) async {
  final boundary =
      tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui_preview/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('app shell renders to preview PNGs (dark & light)',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 980);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());

    for (final (theme, name) in [
      (AppTheme.dark, 'shell_dark'),
      (AppTheme.light, 'shell_light'),
    ]) {
      final key = Key(name);
      // Fresh router per pump — GoRouter carries navigation state.
      final router = GoRouter(
        initialLocation: Routes.dashboard,
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              for (final r in _allRoutes)
                GoRoute(path: r, builder: (c, s) => _body()),
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
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await _capture(tester, key, name);
    }

    // Unmount so the event-reminder scheduler's periodic timer is disposed
    // before the test binding checks for pending timers, then settle the
    // zero-duration timers drift schedules while closing its query streams.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
