import 'package:flutter/material.dart';

/// Global, build-time constants for MindNoron.
class AppConstants {
  AppConstants._();

  static const String appName = 'MindNoron';

  /// Default global hotkey to summon Quick Capture (configurable later).
  static const String defaultCaptureHotkey = 'Ctrl+Shift+Space';

  /// Default Pomodoro durations (minutes).
  static const int defaultWorkMinutes = 25;
  static const int defaultShortBreakMinutes = 5;
  static const int defaultLongBreakMinutes = 15;
  static const int defaultSessionsBeforeLongBreak = 4;

  /// Default task priority (1 = highest, 4 = lowest).
  static const int defaultPriority = 3;

  /// Seeded contexts for first run.
  static const List<String> defaultContexts = <String>[
    '@Home',
    '@Office',
    '@Computer'
  ];

  /// Number of automatic local backups to keep.
  static const int defaultBackupRetention = 7;

  /// Default window size for the desktop shell.
  static const Size defaultWindowSize = Size(1180, 780);
  static const Size minWindowSize = Size(900, 600);
  static const Size captureWindowSize = Size(560, 220);

  static const Locale defaultLocale = Locale('en');
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];
}
