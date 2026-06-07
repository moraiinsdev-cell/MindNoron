import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// One-shot session cues.
enum SoundCue {
  focusComplete('assets/sounds/focus_complete.wav'),
  breakComplete('assets/sounds/break_complete.wav'),
  taskComplete('assets/sounds/task_complete.wav');

  const SoundCue(this.asset);

  /// Bundled asset key passed to [SoLoud.loadAsset].
  final String asset;
}

/// Looping ambient soundscapes for the "noron space" focus/break experience.
/// All beds are bundled offline and loop seamlessly (gaplessly) forever.
enum AmbientSound {
  none('', 'Off'),
  rain('assets/sounds/ambient_rain.wav', 'Soft rain'),
  forest('assets/sounds/ambient_forest.wav', 'Forest wind'),
  brown('assets/sounds/ambient_brown.wav', 'Brown noise'),
  warm('assets/sounds/ambient_warm.wav', 'Warm drone'),
  deep('assets/sounds/ambient_deep.wav', 'Deep space');

  const AmbientSound(this.asset, this.label);

  final String asset;
  final String label;

  /// Soundscapes the user can pick (excludes [none]).
  static List<AmbientSound> get choices =>
      values.where((s) => s != AmbientSound.none).toList();

  static AmbientSound fromName(String? name) => values.firstWhere(
        (s) => s.name == name,
        orElse: () => AmbientSound.rain,
      );
}

/// A user-imported audio file used as a focus soundscape. Stored (as JSON) in
/// settings and referenced by [id] (`custom:<path>`) wherever a built-in
/// [AmbientSound] name would otherwise appear.
class CustomTrack {
  const CustomTrack({required this.path, required this.name});

  final String path;
  final String name;

  /// Selection id, distinguishable from a built-in [AmbientSound] name.
  String get id => '${SoundService.customPrefix}$path';

  Map<String, dynamic> toJson() => {'path': path, 'name': name};

  factory CustomTrack.fromJson(Map<String, dynamic> j) =>
      CustomTrack(path: j['path'] as String, name: j['name'] as String);

  static String encodeList(List<CustomTrack> tracks) =>
      jsonEncode([for (final t in tracks) t.toJson()]);

  static List<CustomTrack> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw) as List;
      return [
        for (final e in data) CustomTrack.fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// Plays session cues and looping ambient beds via SoLoud (miniaudio/WASAPI).
///
/// Audio is non-critical: every call is wrapped so a playback failure can never
/// disrupt the timer (same defensive posture as `NotificationService`). The
/// engine is initialized lazily on first use and assets are cached after first
/// load so repeated cues/loops are instant.
class SoundService {
  /// Selection-id prefix marking an imported [CustomTrack] (vs a built-in name).
  static const customPrefix = 'custom:';

  final SoLoud _soloud = SoLoud.instance;
  Future<void>? _initFuture;
  final Map<String, AudioSource> _sources = {};

  /// '' = nothing playing; an [AmbientSound] name; or a `custom:<path>` id.
  String _ambientId = '';
  SoundHandle? _ambientHandle;

  String get currentAmbientId => _ambientId;
  bool get ambientPlaying => _ambientId.isNotEmpty;

  Future<void> _ensureInit() async {
    if (_soloud.isInitialized) return;
    _initFuture ??= _soloud.init();
    await _initFuture;
  }

  Future<AudioSource> _source(String asset) async {
    return _sources[asset] ??= await _soloud.loadAsset(asset);
  }

  /// Resolve a selection id to a (cached) source: a `custom:<path>` id loads the
  /// file from disk, anything else is treated as a built-in [AmbientSound] name.
  Future<AudioSource> _ambientSource(String id) async {
    if (id.startsWith(customPrefix)) {
      final path = id.substring(customPrefix.length);
      return _sources[id] ??= await _soloud.loadFile(path);
    }
    return _source(AmbientSound.fromName(id).asset);
  }

  /// Play a one-shot cue (e.g. the session-complete chime).
  Future<void> playCue(SoundCue cue, {double volume = 0.7}) async {
    try {
      await _ensureInit();
      final src = await _source(cue.asset);
      await _soloud.play(src, volume: volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('SoundService.playCue failed: $e');
    }
  }

  /// Start (or switch to) a looping bed by selection id — either a built-in
  /// [AmbientSound] name or a `custom:<path>` id from an imported [CustomTrack].
  Future<void> startAmbientId(String id, {double volume = 0.4}) async {
    if (id.isEmpty || id == AmbientSound.none.name) {
      await stopAmbient();
      return;
    }
    try {
      await _ensureInit();
      await _stopAmbientHandle();
      final src = await _ambientSource(id);
      _ambientId = id;
      _ambientHandle = await _soloud.play(src,
          volume: volume.clamp(0.0, 1.0), looping: true);
    } catch (e) {
      debugPrint('SoundService.startAmbientId failed: $e');
    }
  }

  Future<void> _stopAmbientHandle() async {
    final handle = _ambientHandle;
    _ambientHandle = null;
    if (handle != null) {
      try {
        await _soloud.stop(handle);
      } catch (_) {}
    }
  }

  Future<void> stopAmbient() async {
    _ambientId = '';
    await _stopAmbientHandle();
  }

  Future<void> setAmbientVolume(double volume) async {
    final handle = _ambientHandle;
    if (handle == null) return;
    try {
      _soloud.setVolume(handle, volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('SoundService.setAmbientVolume failed: $e');
    }
  }

  Future<void> dispose() async {
    await _stopAmbientHandle();
    try {
      if (_soloud.isInitialized) _soloud.deinit();
    } catch (_) {}
  }
}
