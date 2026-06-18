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

  /// Compact, always-on-top "float" size for the mini office + countdown.
  /// The campus aspect ratio is ~1.55; this leaves room for the count pill.
  static const _floatingSize = Size(320, 232);

  /// Shrinks the window into a small, borderless, always-on-top widget so the
  /// mini office and countdown stay visible over other apps. Reversed by
  /// [exitFloating].
  static Future<void> enterFloating() async {
    // A maximized (or fullscreen) window ignores setSize on Windows, so it must
    // be returned to a normal state first — otherwise the "float" stays huge.
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
    }
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    }
    await windowManager.setMinimumSize(const Size(260, 188));
    await windowManager.setSize(_floatingSize);
    await windowManager.setAlignment(Alignment.topRight);
    await windowManager.setResizable(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
  }

  /// Restores the normal full-size, framed, non-pinned window.
  static Future<void> exitFloating() async {
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(AppConstants.minWindowSize);
    await windowManager.setSize(AppConstants.defaultWindowSize);
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
