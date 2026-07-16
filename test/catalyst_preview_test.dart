// Renders the real CatalystScreen to PNGs under build/catalyst_preview/ with
// the premium theme applied, so the Idea Catalyst UI can be reviewed without a
// network call. Doubles as a smoke test that the screen lays out cleanly.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/core/theme/app_theme.dart';
import 'package:mind_noron/data/repositories/settings_repository.dart';
import 'package:mind_noron/features/catalyst/catalyst_idea.dart';
import 'package:mind_noron/features/catalyst/catalyst_repository.dart';
import 'package:mind_noron/features/catalyst/catalyst_screen.dart';

Future<void> _capture(WidgetTester tester, Key key, String name) async {
  final boundary =
      tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/catalyst_preview/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('catalyst screen renders to preview PNG', (tester) async {
    tester.view.physicalSize = const Size(1040, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ideas = [
      CatalystIdea(
        id: '1',
        brief: 'giảm ô nhiễm không khí đô thị bằng tảo',
        conceptName: 'Bức tường Tảo Thở',
        paradigmShift:
            'Đô thị không thiếu cây — thiếu bề mặt quang hợp trên mỗi mét vuông.',
        coreMechanism:
            'Panel vi tảo gắn mặt tiền toà nhà, bơm khí thải qua bể phản ứng sinh học.',
        asymmetricAdvantage:
            'Hấp thụ CO₂ gấp 50 lần cây xanh cùng diện tích, lại sản ra biofuel.',
        createdAt: DateTime.now(),
        starred: true,
      ),
      CatalystIdea(
        id: '2',
        brief: 'giảm ô nhiễm không khí đô thị bằng tảo',
        conceptName: 'Lưới Đèn Sinh Học',
        paradigmShift: 'Chiếu sáng công cộng có thể là bộ lọc không khí.',
        coreMechanism: 'Cột đèn tích hợp bể tảo phát quang sinh học ban đêm.',
        asymmetricAdvantage: 'Thay hạ tầng sẵn có, không cần đất mới.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    ];

    const key = Key('catalyst-preview');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalystIdeasProvider.overrideWith((ref) => Stream.value(ideas)),
          catalystApiKeyProvider.overrideWith((ref) => Stream.value('sk-set')),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: const Scaffold(body: CatalystScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Idea Catalyst'), findsOneWidget);
    expect(find.text('Bức tường Tảo Thở'), findsOneWidget);
    await _capture(tester, key, 'catalyst_dark');
  });
}
