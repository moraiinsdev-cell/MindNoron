import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether the app is running on a desktop OS.
///
/// The window, system-tray and global-hotkey integrations only exist on
/// Windows/macOS/Linux. On mobile (Android/iOS) and web this returns `false`,
/// so those desktop-only services degrade to no-ops instead of throwing
/// `MissingPluginException` at runtime.
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}
