import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Registers the system-wide hotkey that summons Quick Capture from any app.
class HotkeyService {
  const HotkeyService._();

  /// Default: Ctrl+Shift+Space (configurable later — see PLAN.md §11).
  static Future<void> init({required VoidCallback onCapture}) async {
    try {
      await hotKeyManager.unregisterAll();
      final hotKey = HotKey(
        key: PhysicalKeyboardKey.space,
        modifiers: const [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(hotKey, keyDownHandler: (_) => onCapture());
    } catch (e) {
      debugPrint('HotkeyService init failed: $e');
    }
  }

  static Future<void> dispose() async {
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {}
  }
}
