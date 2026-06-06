import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import '../constants/app_constants.dart';

/// System-tray presence: lets MindNoron live in the background and be summoned.
class TrayService with TrayListener {
  TrayService({
    required this.onCapture,
    required this.onShow,
    required this.onExit,
  });

  final VoidCallback onCapture;
  final VoidCallback onShow;
  final Future<void> Function() onExit;

  Future<void> init() async {
    try {
      trayManager.addListener(this);
      // NOTE: ship a real icon at assets/images/tray_icon.ico (Phase 0 TODO).
      await trayManager.setIcon('assets/images/tray_icon.ico');
      await trayManager.setToolTip(AppConstants.appName);
      await _setMenu();
    } catch (e) {
      debugPrint('TrayService init failed (icon asset missing?): $e');
    }
  }

  Future<void> _setMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'capture', label: 'Quick capture'),
          MenuItem(key: 'show', label: 'Open MindNoron'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: 'Quit'),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() => onShow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'capture':
        onCapture();
      case 'show':
        onShow();
      case 'exit':
        onExit();
    }
  }

  void dispose() => trayManager.removeListener(this);
}
