// Renders the premium theme + shared UI kit to PNGs under build/ui_preview/ so
// the design system can be reviewed without launching the desktop app. Doubles
// as a smoke test that the theme and every shared component lay out cleanly.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_noron/core/theme/app_theme.dart';
import 'package:mind_noron/presentation/widgets/common/section_scaffold.dart';
import 'package:mind_noron/presentation/widgets/common/ui_kit.dart';

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

Widget _gallery() {
  return SectionScaffold(
    title: 'Chào buổi chiều, Huy',
    subtitle: '16/07/2026 · Thứ Tư',
    icon: Icons.dashboard_rounded,
    actions: [
      FilledButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Ghi nhanh'),
      ),
    ],
    child: ListView(
      children: [
        Row(
          children: const [
            Expanded(
              child: StatTile(
                icon: Icons.timer_outlined,
                label: 'Tập trung hôm nay',
                value: '2h 30m',
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: StatTile(
                icon: Icons.check_circle_outline,
                label: 'Việc đã xong',
                value: '5',
                accent: AppTheme.accentBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AccentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: AppTheme.seed),
                  const SizedBox(width: 8),
                  Text('Năng lượng tập trung',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  const InfoPill(
                      label: '3/5', icon: Icons.bolt, filled: true),
                ],
              ),
              const SizedBox(height: 14),
              const MeterBar(value: 0.6, animate: false),
              const SizedBox(height: 12),
              Row(
                children: const [
                  InfoPill(label: 'Runway 8.2 tháng', icon: Icons.savings),
                  SizedBox(width: 8),
                  InfoPill(
                      label: 'Quỹ thuế đủ',
                      icon: Icons.verified,
                      color: Color(0xFF34D399)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(
            title: 'Ưu tiên hôm nay', icon: Icons.flag_outlined),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (final (t, p) in const [
                ('Hoàn thiện model nhân vật cho studio', 'Cao'),
                ('Trả lời email khách PayPal', 'Vừa'),
                ('Xuất DevEx tháng này', 'Thấp'),
              ])
                ListTile(
                  leading: const Icon(Icons.circle, size: 12),
                  title: Text(t),
                  trailing: Text(p),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Filled')),
            FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text')),
          ],
        ),
        const SizedBox(height: 16),
        const TextField(
          decoration: InputDecoration(
            hintText: 'Nhập nội dung cần ghi lại…',
            prefixIcon: Icon(Icons.edit_outlined),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: const [
            Chip(label: Text('#công-việc')),
            Chip(label: Text('#3d')),
            Chip(label: Text('#roblox')),
          ],
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('theme + UI kit render to preview PNGs (dark & light)',
      (tester) async {
    tester.view.physicalSize = const Size(1040, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (theme, name) in [
      (AppTheme.dark, 'gallery_dark'),
      (AppTheme.light, 'gallery_light'),
    ]) {
      final key = Key(name);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(body: _gallery()),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await _capture(tester, key, name);
    }
  });
}
