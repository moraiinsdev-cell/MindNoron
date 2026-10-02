// Renders the Spotlight command palette (idle + searching) over the living
// backdrop to build/ui_preview/palette_*.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/core/providers/app_providers.dart';
import 'package:mind_noron/core/theme/app_theme.dart';
import 'package:mind_noron/data/database/app_database.dart';
import 'package:mind_noron/features/command_palette/command_palette.dart';
import 'package:mind_noron/presentation/widgets/common/living_backdrop.dart';

import 'support/load_fonts.dart';

Future<void> _capture(WidgetTester tester, Key key, String name) async {
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

void main() {
  setUpAll(loadAppFonts);

  testWidgets('command palette renders to preview PNGs', (tester) async {
    tester.view.physicalSize = const Size(1200, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());

    for (final (theme, name) in [
      (AppTheme.dark, 'palette_dark'),
      (AppTheme.light, 'palette_light'),
    ]) {
      final key = Key(name);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: Scaffold(
                body: LivingBackdrop(
                  child: Builder(
                    builder: (context) => Center(
                      child: FilledButton(
                        onPressed: () => showCommandPalette(context),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _capture(tester, key, name);

      await tester.enterText(find.byType(TextField), 'fo');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await _capture(tester, key, '${name}_search');
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
