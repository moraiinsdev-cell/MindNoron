// Renders the real BibleScreen tabs to PNGs under build/bible_preview/ so the
// Kinh Thánh hub UI can be reviewed without launching the desktop app (which can
// be blocked by Smart App Control). Doubles as a smoke test that every tab and
// both languages lay out.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/core/providers/app_providers.dart';
import 'package:mind_noron/core/theme/app_theme.dart';
import 'package:mind_noron/data/database/app_database.dart';
import 'package:mind_noron/features/bible/bible_repository.dart';
import 'package:mind_noron/features/bible/bible_screen.dart';

Future<void> _capture(WidgetTester tester, Key key, String name) async {
  final boundary =
      tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/bible_preview/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

const _key = Key('bible-preview');

Widget _app(AppDatabase db, {bool? english}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      // A few saved verses so the Yêu thích tab renders with content.
      bibleFavoriteIdsProvider.overrideWith(
        (ref) => Stream.value(
            const ['John 3:16', 'Psalm 23:1', 'Philippians 4:13']),
      ),
      if (english != null)
        bibleEnglishProvider.overrideWith((ref) => Stream.value(english)),
    ],
    child: RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const Scaffold(body: BibleScreen()),
      ),
    ),
  );
}

void main() {
  testWidgets('bible hub tabs render to preview PNGs', (tester) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());

    // ── Vietnamese ────────────────────────────────────────────────────────
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    // Today is the landing tab: the daily verse + its reflection.
    expect(find.text('Suy niệm hôm nay'), findsOneWidget);
    await _capture(tester, _key, '1_today_vi');

    await tester.tap(find.text('Chủ đề'));
    await tester.pumpAndSettle();
    expect(find.text('Tất cả'), findsOneWidget);
    await _capture(tester, _key, '2_topics_vi');

    await tester.tap(find.text('Yêu thích'));
    await tester.pumpAndSettle();
    expect(find.text('Giăng 3:16'), findsOneWidget);
    await _capture(tester, _key, '3_favorites_vi');

    // ── English (KJV) ─────────────────────────────────────────────────────
    // Fully tear down first so the screen rebuilds fresh on the Today tab
    // (the keyed RepaintBoundary would otherwise preserve tab state).
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(db, english: true));
    await tester.pumpAndSettle();
    expect(find.text('Suy niệm hôm nay'), findsOneWidget);
    await _capture(tester, _key, '4_today_en');

    // Cleanly flush any pending stream-close timers before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
