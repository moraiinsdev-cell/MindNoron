// Pumps the real OfficeScreen (live simulation, providers, panel) against an
// in-memory database and captures screenshots to build/office_preview/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/core/providers/app_providers.dart';
import 'package:mind_noron/data/database/app_database.dart';
import 'package:mind_noron/data/repositories/task_repository.dart';
import 'package:mind_noron/features/office/office_screen.dart';

void main() {
  testWidgets('office screen runs live: staff list, profile, simulation',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() {
      db.close(); // fire-and-forget: awaiting inside FakeAsync would hang
    });
    // Drift work must run outside FakeAsync or its futures never complete.
    await tester.runAsync(() async {
      await TaskRepository(db).create(title: 'Ship the MindNoron Office');
      await TaskRepository(db).create(title: 'Water the pixel plants');
    });

    const screenshotKey = Key('office-screenshot');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const RepaintBoundary(
          key: screenshotKey,
          child: MaterialApp(home: OfficeScreen()),
        ),
      ),
    );

    // Let the staff/task streams deliver (real async via runAsync) and the
    // simulation tick a little while.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Company overview: header + all founding staff listed.
    expect(find.text('MindNoron Inc.'), findsOneWidget);
    for (final name in ['Elon', 'Jeff', 'Bill', 'Oprah']) {
      expect(find.textContaining(name), findsWidgets,
          reason: '$name missing from the staff list');
    }
    expect(find.text('Hire someone'), findsOneWidget);

    await _capture(tester, screenshotKey, 'widget_company');

    // Open a profile from the staff list.
    await tester.tap(find.textContaining('Warren').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Finance Oracle'), findsOneWidget);
    expect(find.textContaining('Coffee addict'), findsOneWidget);
    expect(find.text('Assigned task'), findsOneWidget);
    expect(find.text('Energy'), findsOneWidget);

    await _capture(tester, screenshotKey, 'widget_profile');

    // Panel commands route through the sim without throwing.
    await tester.tap(find.text('Coffee'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Desk'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Praise'));
    await tester.pump(const Duration(milliseconds: 400));

    // Let the simulation run a while longer — nothing should throw while
    // employees walk, chat and take breaks.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Unmount to stop the ticker cleanly, then flush drift's zero-duration
    // stream-close timers so the test ends without pending timers.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}

Future<void> _capture(WidgetTester tester, Key key, String name) async {
  final boundary =
      tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/office_preview/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
