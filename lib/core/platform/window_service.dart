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

  static Future<void> hideToTray() => windowManager.hide();

  /// Actually quit the app (bypasses the close-to-tray guard).
  static Future<void> quit() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
