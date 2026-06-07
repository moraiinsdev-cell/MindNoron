import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/platform/sound_service.dart';
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
  static const _kSoundEnabled = 'soundEnabled';
  static const _kSoundVolume = 'soundVolume';
  static const _kAmbientSound = 'ambientSound';
  static const _kAmbientVolume = 'ambientVolume';
  static const _kAmbientAutostart = 'ambientAutostart';
  static const _kNeuronBackdrop = 'neuronBackdrop';
  static const _kCustomTracks = 'customTracks';
  static const _kUserName = 'userName';
  static const _kUserNamePrompted = 'userNamePrompted';

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

  Stream<String?> watchUserName() => _watch(_kUserName).map(_cleanName);
  Future<String?> getUserName() async =>
      _cleanName(await readValue(_kUserName));
  Future<void> setUserName(String name) =>
      _set(_kUserName, _cleanName(name) ?? '');

  Future<bool> hasPromptedForUserName() async =>
      (await readValue(_kUserNamePrompted)) == 'true';
  Future<void> markUserNamePrompted() => _set(_kUserNamePrompted, 'true');

  Stream<int> watchWorkMinutes() => _watch(_kWorkMinutes)
      .map((v) => int.tryParse(v ?? '') ?? AppConstants.defaultWorkMinutes);
  Future<void> setWorkMinutes(int m) => _set(_kWorkMinutes, '$m');

  Stream<int> watchShortBreakMinutes() => _watch(_kShortBreak).map(
      (v) => int.tryParse(v ?? '') ?? AppConstants.defaultShortBreakMinutes);
  Future<void> setShortBreakMinutes(int m) => _set(_kShortBreak, '$m');

  Stream<int> watchLongBreakMinutes() => _watch(_kLongBreak).map(
      (v) => int.tryParse(v ?? '') ?? AppConstants.defaultLongBreakMinutes);
  Future<void> setLongBreakMinutes(int m) => _set(_kLongBreak, '$m');

  // --- Session-completion sound -------------------------------------------

  Stream<bool> watchSoundEnabled() =>
      _watch(_kSoundEnabled).map((v) => v != 'false'); // default on
  Future<void> setSoundEnabled(bool v) => _set(_kSoundEnabled, '$v');

  /// Synchronous read for the timer's completion path (avoids stream warm-up).
  Future<bool> getSoundEnabled() async =>
      (await readValue(_kSoundEnabled)) != 'false';

  Stream<double> watchSoundVolume() => _watch(_kSoundVolume)
      .map((v) => double.tryParse(v ?? '') ?? AppConstants.defaultSoundVolume);
  Future<void> setSoundVolume(double v) => _set(_kSoundVolume, '$v');

  Future<double> getSoundVolume() async =>
      double.tryParse(await readValue(_kSoundVolume) ?? '') ??
      AppConstants.defaultSoundVolume;

  // --- Ambient focus soundscape -------------------------------------------

  /// Stored as the [AmbientSound] enum name (e.g. 'rain'). Defaults to rain.
  Stream<String> watchAmbientSound() =>
      _watch(_kAmbientSound).map((v) => v ?? 'rain');
  Future<void> setAmbientSound(String name) => _set(_kAmbientSound, name);
  Future<String> getAmbientSound() async =>
      (await readValue(_kAmbientSound)) ?? 'rain';

  Stream<double> watchAmbientVolume() => _watch(_kAmbientVolume).map(
      (v) => double.tryParse(v ?? '') ?? AppConstants.defaultAmbientVolume);
  Future<void> setAmbientVolume(double v) => _set(_kAmbientVolume, '$v');
  Future<double> getAmbientVolume() async =>
      double.tryParse(await readValue(_kAmbientVolume) ?? '') ??
      AppConstants.defaultAmbientVolume;

  /// Whether the chosen soundscape auto-plays when a session starts.
  Stream<bool> watchAmbientAutostart() =>
      _watch(_kAmbientAutostart).map((v) => v == 'true'); // default off
  Future<void> setAmbientAutostart(bool v) => _set(_kAmbientAutostart, '$v');
  Future<bool> getAmbientAutostart() async =>
      (await readValue(_kAmbientAutostart)) == 'true';

  // --- Imported custom soundscapes ----------------------------------------

  /// User-imported audio files usable as focus soundscapes (JSON-encoded).
  Stream<List<CustomTrack>> watchCustomTracks() =>
      _watch(_kCustomTracks).map(CustomTrack.decodeList);
  Future<List<CustomTrack>> getCustomTracks() async =>
      CustomTrack.decodeList(await readValue(_kCustomTracks));

  Future<void> addCustomTrack(CustomTrack track) async {
    final list = await getCustomTracks();
    if (list.any((t) => t.path == track.path)) return; // already imported
    await _set(_kCustomTracks, CustomTrack.encodeList([...list, track]));
  }

  Future<void> removeCustomTrack(String path) async {
    final list = await getCustomTracks();
    await _set(
      _kCustomTracks,
      CustomTrack.encodeList(list.where((t) => t.path != path).toList()),
    );
  }

  // --- Noron-space animated backdrop --------------------------------------

  Stream<bool> watchNeuronBackdrop() =>
      _watch(_kNeuronBackdrop).map((v) => v != 'false'); // default on
  Future<void> setNeuronBackdrop(bool v) => _set(_kNeuronBackdrop, '$v');

  static ThemeMode _parseTheme(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark, // dark-first default
      };

  static String? _cleanName(String? raw) {
    final name = raw?.trim();
    if (name == null || name.isEmpty) return null;
    return name.length <= 40 ? name : name.substring(0, 40).trim();
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});

final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  return ref.watch(settingsRepositoryProvider).watchThemeMode();
});

final userNameProvider = StreamProvider<String?>((ref) {
  return ref.watch(settingsRepositoryProvider).watchUserName();
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

final soundEnabledProvider = StreamProvider<bool>((ref) {
  return ref.watch(settingsRepositoryProvider).watchSoundEnabled();
});

final soundVolumeProvider = StreamProvider<double>((ref) {
  return ref.watch(settingsRepositoryProvider).watchSoundVolume();
});

final ambientSoundProvider = StreamProvider<String>((ref) {
  return ref.watch(settingsRepositoryProvider).watchAmbientSound();
});

final ambientVolumeProvider = StreamProvider<double>((ref) {
  return ref.watch(settingsRepositoryProvider).watchAmbientVolume();
});

final ambientAutostartProvider = StreamProvider<bool>((ref) {
  return ref.watch(settingsRepositoryProvider).watchAmbientAutostart();
});

final neuronBackdropProvider = StreamProvider<bool>((ref) {
  return ref.watch(settingsRepositoryProvider).watchNeuronBackdrop();
});

final customTracksProvider = StreamProvider<List<CustomTrack>>((ref) {
  return ref.watch(settingsRepositoryProvider).watchCustomTracks();
});
