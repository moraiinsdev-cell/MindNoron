// Loads the bundled Inter families into the test environment so preview PNGs
// render real glyphs instead of the Ahem placeholder boxes. Call from a
// `setUpAll` before pumping widgets.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final inter = FontLoader('Inter')
    ..addFont(_read('assets/fonts/Inter-Regular.ttf'))
    ..addFont(_read('assets/fonts/Inter-Italic.ttf'))
    ..addFont(_read('assets/fonts/Inter-Medium.ttf'))
    ..addFont(_read('assets/fonts/Inter-SemiBold.ttf'))
    ..addFont(_read('assets/fonts/Inter-Bold.ttf'));
  final display = FontLoader('InterDisplay')
    ..addFont(_read('assets/fonts/InterDisplay-SemiBold.ttf'))
    ..addFont(_read('assets/fonts/InterDisplay-Bold.ttf'));

  await inter.load();
  await display.load();

  // Georgia (the welcome screen's editorial serif) ships with Windows —
  // load it from the system font folder when present.
  final winFonts = '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts';
  final georgia = FontLoader('Georgia');
  var anyGeorgia = false;
  for (final f in const [
    'georgia.ttf',
    'georgiab.ttf',
    'georgiai.ttf',
    'georgiaz.ttf',
  ]) {
    final file = File('$winFonts/$f');
    if (file.existsSync()) {
      georgia.addFont(_read(file.path));
      anyGeorgia = true;
    }
  }
  if (anyGeorgia) await georgia.load();

  // Material Icons live in the Flutter SDK cache — load them too so preview
  // PNGs show real glyph icons instead of boxes. Best-effort: skip silently
  // if the SDK layout ever changes.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final iconFont = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconFont.existsSync()) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(_read(iconFont.path));
      await icons.load();
    }
  }
}

Future<ByteData> _read(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.view(bytes.buffer);
}
