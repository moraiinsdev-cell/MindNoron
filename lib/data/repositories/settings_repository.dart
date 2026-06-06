import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../database/app_database.dart';

/// Typed wrapper over the key/value [Settings] table.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  static const _kThemeMode = 'themeMode';
  static const _kWorkMinutes = 'workMinutes';
  static const _kShortBreak = 'shortBreakMinutes';
  static const _kLongBreak = 'longBreakMinutes';

  Future<void> _set(String key, String value) {
    return _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> setValue(String key, String value) => _set(key, value);

  Future<String?> readValue(String key) async {
    final row = await (_db.select(_db.settings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Stream<String?> _watch(String key) {
    return (_db.select(_db.settings)..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((r) => r?.value);
  }

  Stream<ThemeMode> watchThemeMode() => _watch(_kThemeMode).map(_parseTheme);
  Future<void> setThemeMode(ThemeMode mode) => _set(_kThemeMode, mode.name);

  Stream<int> watchWorkMinutes() => _watch(_kWorkMinutes)
      .map((v) => int.tryParse(v ?? '') ?? AppConstants.defaultWorkMinutes);
  Future<void> setWorkMinutes(int m) => _set(_kWorkMinutes, '$m');

  Stream<int> watchShortBreakMinutes() => _watch(_kShortBreak).map(
      (v) => int.tryParse(v ?? '') ?? AppConstants.defaultShortBreakMinutes);
  Future<void> setShortBreakMinutes(int m) => _set(_kShortBreak, '$m');

  Stream<int> watchLongBreakMinutes() => _watch(_kLongBreak).map(
      (v) => int.tryParse(v ?? '') ?? AppConstants.defaultLongBreakMinutes);
  Future<void> setLongBreakMinutes(int m) => _set(_kLongBreak, '$m');

  static ThemeMode _parseTheme(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark, // dark-first default
      };
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});

final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  return ref.watch(settingsRepositoryProvider).watchThemeMode();
});

final workMinutesProvider = StreamProvider<int>((ref) {
  return ref.watch(settingsRepositoryProvider).watchWorkMinutes();
});

final shortBreakMinutesProvider = StreamProvider<int>((ref) {
  return ref.watch(settingsRepositoryProvider).watchShortBreakMinutes();
});

final longBreakMinutesProvider = StreamProvider<int>((ref) {
  return ref.watch(settingsRepositoryProvider).watchLongBreakMinutes();
});
