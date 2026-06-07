import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../constants/app_constants.dart';

/// Registers the system-wide hotkey that summons Quick Capture from any app.
///
/// The combination is user-configurable (Settings → Shortcuts); it is stored as
/// a human string like `Ctrl+Shift+Space` and parsed back into a [HotKey].
class HotkeyService {
  const HotkeyService._();

  /// Preset combinations offered in Settings. Kept conservative to avoid
  /// clashing with common OS shortcuts.
  static const presets = <String>[
    'Ctrl+Shift+Space',
    'Ctrl+Alt+Space',
    'Ctrl+Shift+M',
    'Ctrl+Alt+N',
    'Ctrl+Shift+J',
  ];

  static VoidCallback? _onCapture;

  static Future<void> init({
    required VoidCallback onCapture,
    String hotkey = AppConstants.defaultCaptureHotkey,
  }) async {
    _onCapture = onCapture;
    await _register(hotkey);
  }

  /// Re-register a new combination at runtime (called when Settings changes it).
  static Future<void> update(String hotkey) async {
    if (_onCapture == null) return;
    await _register(hotkey);
  }

  static Future<void> _register(String hotkey) async {
    final cb = _onCapture;
    if (cb == null) return;
    try {
      await hotKeyManager.unregisterAll();
      final parsed = _parse(hotkey) ?? _parse(AppConstants.defaultCaptureHotkey);
      if (parsed == null) return;
      await hotKeyManager.register(parsed, keyDownHandler: (_) => cb());
    } catch (e) {
      debugPrint('HotkeyService register failed: $e');
    }
  }

  /// Parse a string like `Ctrl+Shift+Space` into a [HotKey]. Returns null if
  /// the trailing key is not one we map.
  static HotKey? _parse(String value) {
    final parts =
        value.split('+').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final keyToken = parts.removeLast();
    final modifiers = <HotKeyModifier>[];
    for (final p in parts) {
      switch (p.toLowerCase()) {
        case 'ctrl':
        case 'control':
          modifiers.add(HotKeyModifier.control);
        case 'shift':
          modifiers.add(HotKeyModifier.shift);
        case 'alt':
          modifiers.add(HotKeyModifier.alt);
        case 'meta':
        case 'win':
          modifiers.add(HotKeyModifier.meta);
        default:
          return null;
      }
    }
    final key = _key(keyToken);
    if (key == null) return null;
    return HotKey(
      key: key,
      modifiers: modifiers,
      scope: HotKeyScope.system,
    );
  }

  static PhysicalKeyboardKey? _key(String token) {
    if (token.toLowerCase() == 'space') return PhysicalKeyboardKey.space;
    if (token.length == 1) {
      final c = token.toUpperCase().codeUnitAt(0);
      if (c >= 0x41 && c <= 0x5A) {
        // A..Z map to PhysicalKeyboardKey.keyA .. keyZ (contiguous USB codes).
        return PhysicalKeyboardKey(
            PhysicalKeyboardKey.keyA.usbHidUsage + (c - 0x41));
      }
    }
    return null;
  }

  static Future<void> dispose() async {
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {}
  }
}
