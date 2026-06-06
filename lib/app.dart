import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants/app_constants.dart';
import 'core/platform/window_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/settings_repository.dart';
import 'l10n/app_localizations.dart';
import 'presentation/navigation/app_router.dart';

class MindNoronApp extends ConsumerStatefulWidget {
  const MindNoronApp({super.key});

  @override
  ConsumerState<MindNoronApp> createState() => _MindNoronAppState();
}

class _MindNoronAppState extends ConsumerState<MindNoronApp>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    // Close button hides to tray instead of quitting (preventClose enabled).
    WindowService.hideToTray();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      locale: AppConstants.defaultLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
