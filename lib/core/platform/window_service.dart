import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../constants/app_constants.dart';

/// Owns the main desktop window: sizing, showing, and "close-to-tray".
class WindowService {
  const WindowService._();

  static Future<void> init() async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: AppConstants.defaultWindowSize,
      minimumSize: AppConstants.minWindowSize,
      center: true,
      title: AppConstants.appName,
      titleBarStyle: TitleBarStyle.normal,
      backgroundColor: null,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    // Hide to tray instead of quitting when the user clicks the close button.
    await windowManager.setPreventClose(true);
  }

  static Future<void> showAndFocus() async {
    if (!await windowManager.isVisible()) {
      await windowManager.show();
    }
    await windowManager.focus();
  }

  /// Compact, always-on-top "float" size for the focus countdown.
  static const _floatingSize = Size(248, 118);

  /// Shrinks the window into a small, borderless, always-on-top widget so the
  /// countdown stays visible over other apps. Reversed by [exitFloating].
  static Future<void> enterFloating() async {
    await windowManager.setMinimumSize(const Size(200, 96));
    await windowManager.setResizable(false);
    await windowManager.setSize(_floatingSize);
    await windowManager.setAlignment(Alignment.topRight);
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
  }

  /// Restores the normal full-size, framed, non-pinned window.
  static Future<void> exitFloating() async {
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setResizable(true);
    await windowManager.setSize(AppConstants.defaultWindowSize);
    await windowManager.setMinimumSize(AppConstants.minWindowSize);
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> hideToTray() => windowManager.hide();

  /// Actually quit the app (bypasses the close-to-tray guard).
  static Future<void> quit() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
