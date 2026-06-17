import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Tiny synthesized blips for office interactions — no audio assets, just
/// short tone bursts shaped with a quick volume decay. Shares the SoLoud
/// engine with [SoundService] (both use `SoLoud.instance`).
///
/// Every call is wrapped so a playback failure can never disrupt the office
/// (same defensive posture as the rest of the audio layer). Sound is a
/// non-critical garnish and can be muted via [enabled].
enum OfficeSfxCue {
  /// Light UI tick when poking an object.
  click(WaveForm.sin, 640, 55, 0.16),

  /// Bright ping when coins are earned.
  coin(WaveForm.fSquare, 920, 95, 0.22),

  /// Soft gurgle at the espresso machine.
  coffee(WaveForm.triangle, 400, 130, 0.15),

  /// Cheerful chirp when someone is hired.
  hire(WaveForm.fSquare, 560, 150, 0.22),

  /// Triumphant blip for celebrations / task completion.
  celebrate(WaveForm.fSquare, 1040, 220, 0.24),

  /// Low plonk for a pool splash.
  splash(WaveForm.sin, 300, 170, 0.18),

  /// Muted poof for placing/removing furniture.
  poof(WaveForm.triangle, 240, 140, 0.15);

  const OfficeSfxCue(this.wave, this.freq, this.ms, this.volume);

  final WaveForm wave;
  final double freq;
  final int ms;
  final double volume;
}

class OfficeSfx {
  // Accessed lazily: touching SoLoud.instance loads the native engine, which
  // isn't available in headless tests — so we only reach it inside the
  // guarded [play] path, never at construction.
  SoLoud get _soloud => SoLoud.instance;
  Future<void>? _initFuture;
  final Map<OfficeSfxCue, AudioSource> _sources = {};

  /// Master mute toggle (driven from settings).
  bool enabled = true;

  /// Scales every cue's volume (0..1).
  double masterVolume = 1.0;

  Future<void> _ensureInit() async {
    if (_soloud.isInitialized) return;
    _initFuture ??= _soloud.init();
    await _initFuture;
  }

  Future<AudioSource> _sourceFor(OfficeSfxCue cue) async {
    final existing = _sources[cue];
    if (existing != null) return existing;
    final src = await _soloud.loadWaveform(cue.wave, false, 1.0, 0.0);
    _soloud.setWaveformFreq(src, cue.freq);
    return _sources[cue] = src;
  }

  /// Plays a one-shot blip for [cue]. No-op when muted; never throws.
  Future<void> play(OfficeSfxCue cue) async {
    if (!enabled || masterVolume <= 0) return;
    try {
      await _ensureInit();
      final src = await _sourceFor(cue);
      final handle = await _soloud.play(
        src,
        volume: (cue.volume * masterVolume).clamp(0.0, 1.0),
      );
      // Decay to silence so the looping waveform reads as a short burst,
      // then stop the voice once it's inaudible.
      _soloud.fadeVolume(handle, 0, Duration(milliseconds: cue.ms));
      Timer(Duration(milliseconds: cue.ms + 50), () {
        try {
          _soloud.stop(handle);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('OfficeSfx.play(${cue.name}) failed: $e');
    }
  }

  void dispose() {
    // The shared engine owns the sources; nothing office-critical to free.
    _sources.clear();
  }
}

final officeSfxProvider = Provider<OfficeSfx>((ref) {
  final sfx = OfficeSfx();
  ref.onDispose(sfx.dispose);
  return sfx;
});
