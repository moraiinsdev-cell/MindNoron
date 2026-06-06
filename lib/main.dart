import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import 'app.dart';
import 'core/platform/hotkey_service.dart';
import 'core/platform/notification_service.dart';
import 'core/platform/single_instance.dart';
import 'core/platform/tray_service.dart';
import 'core/platform/window_service.dart';
import 'data/backup/backup_service.dart';
import 'data/repositories/task_repository.dart';
import 'features/capture/capture_dialog.dart';
import 'features/tasks/task_urgency.dart';
import 'presentation/navigation/app_router.dart';

late final ProviderContainer _container;
TrayService? _tray;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // hotkey_manager requires clearing any hotkeys left over from a hot restart.
  await hotKeyManager.unregisterAll();

  await SingleInstance.acquire();
  await WindowService.init();
  await NotificationService.init();

  _container = ProviderContainer();

  _tray = TrayService(
    onCapture: _onCaptureRequested,
    onShow: WindowService.showAndFocus,
    onExit: _onExit,
  );
  await _tray!.init();
  await HotkeyService.init(onCapture: _onCaptureRequested);

  runApp(
    UncontrolledProviderScope(
      container: _container,
      child: const MindNoronApp(),
    ),
  );

  // Nudge about long-neglected tasks shortly after the window is up.
  unawaited(_remindStaleTasksOnLaunch());
}

/// On launch, surface a desktop reminder if open tasks have been sitting too
/// long (urgency >= 2). Best-effort: never blocks or crashes startup.
Future<void> _remindStaleTasksOnLaunch() async {
  try {
    final repo = _container.read(taskRepositoryProvider);
    final now = DateTime.now();
    final stale = (await repo.getOpen())
        .where((t) => taskUrgency(t, now) >= 2)
        .toList()
      ..sort((a, b) => taskUrgency(b, now).compareTo(taskUrgency(a, now)));
    if (stale.isEmpty) return;
    final top = stale.first;
    final others = stale.length - 1;
    await NotificationService.show(
      title:
          '${stale.length} task${stale.length == 1 ? '' : 's'} need attention',
      body: others > 0
          ? "'${top.title}' + $others more have been waiting. Time to wrap them up."
          : "'${top.title}' has been waiting a while. Time to wrap it up.",
    );
  } catch (_) {}
}

/// Summon the window and open Quick Capture (from the global hotkey or tray).
Future<void> _onCaptureRequested() async {
  await WindowService.showAndFocus();
  final ctx = rootNavigatorKey.currentContext;
  if (ctx != null) {
    // ctx is fetched fresh from a GlobalKey after the await, so it is valid.
    // ignore: use_build_context_synchronously
    await showCaptureDialog(ctx, source: 'hotkey');
  }
}

Future<void> _onExit() async {
  // Safety net: snapshot data before quitting.
  try {
    await _container.read(backupServiceProvider).backupNow();
  } catch (_) {}
  await HotkeyService.dispose();
  _tray?.dispose();
  await SingleInstance.release();
  _container.dispose();
  await WindowService.quit();
}
