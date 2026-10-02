// Renders every AuroraPalette of the living backdrop (dark + light) to
// build/ui_preview/aurora_*.png so each area's mood can be tuned by eye.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/core/theme/app_theme.dart';
import 'package:mind_noron/presentation/widgets/common/living_backdrop.dart';

import 'support/load_fonts.dart';

const _palettes = {
  'standard': AuroraPalette.standard,
  'focus': AuroraPalette.focus,
  'spark': AuroraPalette.spark,
  'money': AuroraPalette.money,
  'dawn': AuroraPalette.dawn,
  'reflect': AuroraPalette.reflect,
  'plan': AuroraPalette.plan,
};

void main() {
  setUpAll(loadAppFonts);

  testWidgets('aurora palettes render to preview PNGs', (tester) async {
    tester.view.physicalSize = const Size(2100, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (theme, name) in [
      (AppTheme.dark, 'aurora_dark'),
      (AppTheme.light, 'aurora_light'),
    ]) {
      final key = Key(name);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Row(
              children: [
                for (final e in _palettes.entries)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: LivingBackdrop(
                        palette: e.value,
                        child: Center(
                          child: Text(e.key,
                              style: theme.textTheme.titleMedium),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      // The shader loads asynchronously.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      final boundary =
          tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/ui_preview/$name.png');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
