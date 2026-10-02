import 'dart:math' as math;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../constants/app_constants.dart';
import 'platform_capabilities.dart';

/// Owns the main desktop window: sizing, showing, and "close-to-tray".
///
/// Every method is a no-op off desktop (mobile/web have no OS window to manage),
/// so callers can stay platform-agnostic.
class WindowService {
  const WindowService._();

  static Future<void> init() async {
    if (!isDesktopPlatform) return;
    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: _fitToScreen(AppConstants.defaultWindowSize),
      minimumSize: AppConstants.minWindowSize,
      center: true,
      title: AppConstants.appName,
      // Frameless: the app draws its own unified toolbar + window controls.
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      backgroundColor: Colors.black,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await _applyFrameless();
      await windowManager.show();
      await windowManager.focus();
    });
    // Hide to tray instead of quitting when the user clicks the close button.
    await windowManager.setPreventClose(true);
  }

  /// Shrinks [size] to fit the primary display's work area, so the window
  /// (and its drag strip) never opens partly off-screen on small or
  /// high-DPI laptop screens where the default is taller than the screen.
  static Size _fitToScreen(Size size) {
    final displays = WidgetsBinding.instance.platformDispatcher.displays;
    if (displays.isEmpty) return size;
    final d = displays.first;
    final logical = d.size / d.devicePixelRatio;
    // Leave room for the taskbar and a little breathing space.
    final maxW = logical.width * 0.92;
    final maxH = (logical.height - 48) * 0.94;
    return Size(
      math.max(AppConstants.minWindowSize.width, math.min(size.width, maxW)),
      math.max(AppConstants.minWindowSize.height, math.min(size.height, maxH)),
    );
  }

  /// True frameless window: the whole window is client area (no leftover
  /// DWM caption strip), while a 1px DWM margin keeps the native Windows 11
  /// shadow and rounded corners. Edge resizing is handled in Flutter by
  /// `DragToResizeArea` (see app.dart).
  static Future<void> _applyFrameless() async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(true);
  }

  static Future<void> showAndFocus() async {
    if (!isDesktopPlatform) return;
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
    if (!isDesktopPlatform) return;
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
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
  }

  /// Restores the normal full-size, non-pinned window (frameless, with the
  /// app's own toolbar).
  static Future<void> exitFloating() async {
    if (!isDesktopPlatform) return;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(AppConstants.minWindowSize);
    await windowManager.setSize(_fitToScreen(AppConstants.defaultWindowSize));
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> hideToTray() async {
    if (!isDesktopPlatform) return;
    await windowManager.hide();
  }

  /// Actually quit the app (bypasses the close-to-tray guard).
  static Future<void> quit() async {
    if (!isDesktopPlatform) return;
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
