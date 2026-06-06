// Procedurally generates MindNoron's sound assets as 16-bit mono PCM WAV files.
//
// These are synthesized from scratch (sine partials + filtered noise), so the
// resulting audio is fully original and royalty-free — no third-party samples.
//
// Run from the project root:
//   dart run tool/generate_sounds.dart
//
// Outputs to assets/sounds/. Re-run any time to regenerate.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 44100;

void main() {
  final dir = Directory('assets/sounds');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  _write('assets/sounds/focus_complete.wav', _focusComplete());
  _write('assets/sounds/break_complete.wav', _breakComplete());
  _write('assets/sounds/task_complete.wav', _taskComplete());
  _write('assets/sounds/ambient_rain.wav', _ambientRain());
  _write('assets/sounds/ambient_forest.wav', _ambientForest());
  _write('assets/sounds/ambient_brown.wav', _ambientBrown());
  _write('assets/sounds/ambient_warm.wav', _ambientWarm());
  _write('assets/sounds/ambient_deep.wav', _ambientDeep());

  stdout.writeln('Done. Generated 8 WAV files in assets/sounds/.');
}

// ---------------------------------------------------------------------------
// Cues (one-shots)
// ---------------------------------------------------------------------------

/// Bright ascending major arpeggio — "nice work, you finished".
List<double> _focusComplete() {
  const notes = [523.25, 659.25, 783.99, 1046.50]; // C5 E5 G5 C6
  const stagger = 0.11; // seconds between note onsets
  final total = (sampleRate * 1.5).round();
  final buf = List<double>.filled(total, 0);
  for (var n = 0; n < notes.length; n++) {
    final onset = (n * stagger * sampleRate).round();
    _addBell(buf, onset, notes[n], decay: 0.55, gain: 0.5);
  }
  _normalize(buf, 0.82);
  return buf;
}

/// Soft two-note descending chime — gentle "break's over".
List<double> _breakComplete() {
  final total = (sampleRate * 1.6).round();
  final buf = List<double>.filled(total, 0);
  _addBell(buf, 0, 659.25, decay: 0.7, gain: 0.5); // E5
  _addBell(buf, (sampleRate * 0.28).round(), 440.0,
      decay: 0.95, gain: 0.55); // A4
  _normalize(buf, 0.72);
  return buf;
}

/// Short, bright "ding + sparkle" — a satisfying task-done flourish.
List<double> _taskComplete() {
  final total = (sampleRate * 0.6).round();
  final buf = List<double>.filled(total, 0);
  _addBell(buf, 0, 880.0, decay: 0.28, gain: 0.5); // A5
  _addBell(buf, (sampleRate * 0.05).round(), 1318.5,
      decay: 0.22, gain: 0.3); // E6
  _normalize(buf, 0.7);
  return buf;
}

/// A decaying bell tone: fundamental + a couple of soft harmonics, with a
/// quick attack and exponential decay envelope.
void _addBell(List<double> buf, int onset, double freq,
    {required double decay, required double gain}) {
  const attack = 0.006;
  for (var i = onset; i < buf.length; i++) {
    final t = (i - onset) / sampleRate;
    if (t < 0) continue;
    final env = t < attack ? (t / attack) : exp(-(t - attack) / decay);
    final sample = sin(2 * pi * freq * t) +
        0.35 * sin(2 * pi * freq * 2 * t) +
        0.12 * sin(2 * pi * freq * 3 * t);
    buf[i] += gain * env * sample;
  }
}

// ---------------------------------------------------------------------------
// Ambient loops (seamless, long enough to avoid an obvious repeat)
// ---------------------------------------------------------------------------

const double _loopSeconds = 12.0;

/// Soft rain bed: a dark wet-air layer, gentle curtain noise, and warm
/// pitter-patter droplets. The goal is "rain on a window / wet pavement",
/// not sharp white-noise hiss.
List<double> _ambientRain() {
  final n = (sampleRate * _loopSeconds).round();
  final fade = (sampleRate * 0.9).round();
  final total = n + fade;
  final out = List<double>.filled(total, 0);

  // Damp, low "wet air" body. This gives the rain weight without rumbling.
  final air = _brownNoise(total, step: 0.009, leak: 0.997);
  _lowPass(air, 0.035);
  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;
    final swell = 0.76 +
        0.16 * sin(2 * pi * (1 / _loopSeconds) * t + 0.7) +
        0.08 * sin(2 * pi * (3 / _loopSeconds) * t + 2.4);
    out[i] += 0.55 * swell * air[i];
  }

  // A soft rain curtain: filtered away from the painful, icy top end.
  final curtain = _whiteNoise(total, 17);
  _highPass(curtain, 0.5);
  _lowPass(curtain, 0.13);
  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;
    final shimmer = 0.70 +
        0.12 * sin(2 * pi * (2 / _loopSeconds) * t + 1.3) +
        0.08 * sin(2 * pi * (5 / _loopSeconds) * t);
    out[i] += 0.18 * shimmer * curtain[i];
  }

  // Window/pavement droplets: sparse, rounded transients in the lower-mid
  // range. These are the little "ti tach" details.
  final rng = Random(11);
  for (var i = 0; i < total; i++) {
    if (rng.nextDouble() >= 0.00042) continue;

    final freq = 420 + rng.nextDouble() * 980;
    final amp = 0.018 + rng.nextDouble() * 0.04;
    final len = (sampleRate * (0.012 + rng.nextDouble() * 0.035)).round();
    for (var j = 0; j < len && i + j < total; j++) {
      final t = j / sampleRate;
      final attack = min(1.0, j / (sampleRate * 0.002));
      final env = attack * exp(-j / (len * 0.32));
      final tone =
          sin(2 * pi * freq * t) + 0.24 * sin(2 * pi * freq * 1.7 * t + 1.2);
      out[i + j] += amp * env * tone;
    }
  }

  // Tiny leaf/roof ticks, kept very quiet so they sparkle without piercing.
  for (var i = 0; i < total; i++) {
    if (rng.nextDouble() >= 0.00016) continue;

    final freq = 1100 + rng.nextDouble() * 1300;
    final amp = 0.006 + rng.nextDouble() * 0.014;
    final len = (sampleRate * (0.004 + rng.nextDouble() * 0.011)).round();
    for (var j = 0; j < len && i + j < total; j++) {
      final t = j / sampleRate;
      final env = exp(-j / (len * 0.28));
      out[i + j] += amp * env * sin(2 * pi * freq * t);
    }
  }

  // A little distant room tone so the loop feels like weather, not static.
  final room = _brownNoise(total, step: 0.006, leak: 0.998);
  _lowPass(room, 0.018);
  for (var i = 0; i < total; i++) {
    out[i] += 0.35 * room[i];
  }

  final loop = _crossfadeLoop(out, n, fade);
  _normalize(loop, 0.42);
  return loop;
}

/// Forest-wind bed — low-passed wind with slow gusts plus a quiet, faster
/// "leaf rustle" layer. Reads as wind moving through trees.
List<double> _ambientForest() {
  final n = (sampleRate * _loopSeconds).round();
  final fade = (sampleRate * 0.6).round();
  final total = n + fade;

  // Wind body: low-passed noise modulated by slow overlapping gusts.
  final wind = _whiteNoise(total, 3);
  _lowPass(wind, 0.04);
  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;
    final gust = 0.45 +
        0.30 * sin(2 * pi * (1 / _loopSeconds) * t) +
        0.18 * sin(2 * pi * (2 / _loopSeconds) * t + 1.7) +
        0.10 * sin(2 * pi * (5 / _loopSeconds) * t + 0.5);
    wind[i] *= 2.4 * gust.clamp(0.0, 1.2);
  }

  // Leaf rustle: high-passed noise, gated by a faster fluttering envelope.
  final rustle = _whiteNoise(total, 91);
  _highPass(rustle, 0.7);
  for (var i = 0; i < total; i++) {
    final t = i / sampleRate;
    final flutter = (0.5 + 0.5 * sin(2 * pi * (7 / _loopSeconds) * t)) *
        (0.5 + 0.5 * sin(2 * pi * (13 / _loopSeconds) * t + 2.1));
    wind[i] += 0.18 * flutter * rustle[i];
  }

  final loop = _crossfadeLoop(wind, n, fade);
  _normalize(loop, 0.6);
  return loop;
}

/// Brown-noise bed — like distant rain / airflow. Good for deep focus.
List<double> _ambientBrown() {
  final n = (sampleRate * _loopSeconds).round();
  final raw =
      _brownNoise(n + (sampleRate * 0.5).round(), step: 0.02, leak: 0.997);
  final loop = _crossfadeLoop(raw, n, (sampleRate * 0.5).round());
  _normalize(loop, 0.5);
  return loop;
}

/// Warm bed — pink-ish noise over a low, consonant drone (A2 + E3).
List<double> _ambientWarm() {
  final n = (sampleRate * _loopSeconds).round();
  // Frequencies chosen so cycles*_loopSeconds are whole numbers => seamless.
  final drone = _drone(n, const [
    _Partial(110.0, 0.16), // A2 (660 cycles over 6s)
    _Partial(164.5, 0.10), // ~E3 (987 cycles)
    _Partial(55.0, 0.12), // A1 (330 cycles)
  ]);
  final raw =
      _brownNoise(n + (sampleRate * 0.5).round(), step: 0.012, leak: 0.996);
  final noise = _crossfadeLoop(raw, n, (sampleRate * 0.5).round());
  final out = List<double>.generate(n, (i) => drone[i] + 0.35 * noise[i]);
  _normalize(out, 0.6);
  return out;
}

/// Deep bed — low hum layers for a calm, "deep space" feel.
List<double> _ambientDeep() {
  final n = (sampleRate * _loopSeconds).round();
  final drone = _drone(n, const [
    _Partial(60.0, 0.3), // 360 cycles
    _Partial(90.0, 0.16), // 540 cycles
    _Partial(120.0, 0.1), // 720 cycles
  ]);
  // Very slow amplitude swell (1 full cycle across the loop) for life.
  for (var i = 0; i < n; i++) {
    final lfo = 0.85 + 0.15 * sin(2 * pi * (i / n));
    drone[i] *= lfo;
  }
  _normalize(drone, 0.62);
  return drone;
}

class _Partial {
  const _Partial(this.freq, this.amp);
  final double freq;
  final double amp;
}

List<double> _drone(int n, List<_Partial> partials) {
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var s = 0.0;
    for (final p in partials) {
      s += p.amp * sin(2 * pi * p.freq * t);
    }
    out[i] = s;
  }
  return out;
}

/// Integrated white noise (a random walk) with a leak toward zero to avoid DC
/// drift, then a one-pole low-pass for a softer, less hissy character.
List<double> _brownNoise(int n, {required double step, required double leak}) {
  final rng = Random(42);
  final out = List<double>.filled(n, 0);
  var last = 0.0;
  var lp = 0.0;
  for (var i = 0; i < n; i++) {
    last = last * leak + (rng.nextDouble() * 2 - 1) * step;
    lp += 0.05 * (last - lp); // gentle low-pass
    out[i] = lp;
  }
  return out;
}

/// Uniform white noise in [-1, 1].
List<double> _whiteNoise(int n, int seed) {
  final rng = Random(seed);
  return List<double>.generate(n, (_) => rng.nextDouble() * 2 - 1);
}

/// One-pole low-pass, in place. [a] is the smoothing factor (0..1, smaller =
/// darker).
void _lowPass(List<double> buf, double a) {
  var lp = 0.0;
  for (var i = 0; i < buf.length; i++) {
    lp += a * (buf[i] - lp);
    buf[i] = lp;
  }
}

/// One-pole high-pass, in place. [r] near 1.0 removes more low end.
void _highPass(List<double> buf, double r) {
  var prevIn = 0.0;
  var prevOut = 0.0;
  for (var i = 0; i < buf.length; i++) {
    final x = buf[i];
    final y = r * (prevOut + x - prevIn);
    prevIn = x;
    prevOut = y;
    buf[i] = y;
  }
}

/// Takes a buffer longer than [n] by [fade] samples and equal-power
/// crossfades the overhang back onto the head so the [n]-sample loop is
/// seamless when repeated.
List<double> _crossfadeLoop(List<double> raw, int n, int fade) {
  final out = List<double>.generate(n, (i) => raw[i]);
  for (var j = 0; j < fade; j++) {
    final t = j / fade;
    final a = cos(t * pi / 2); // head weight
    final b = sin(t * pi / 2); // overhang weight
    out[j] = out[j] * a + raw[n + j] * b;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _normalize(List<double> buf, double peak) {
  var maxAbs = 0.0;
  for (final v in buf) {
    final a = v.abs();
    if (a > maxAbs) maxAbs = a;
  }
  if (maxAbs < 1e-9) return;
  final scale = peak / maxAbs;
  for (var i = 0; i < buf.length; i++) {
    buf[i] *= scale;
  }
}

void _write(String path, List<double> samples) {
  final dataSize = samples.length * 2;
  final bytes = BytesBuilder();
  final header = ByteData(44);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  header.setUint32(4, 36 + dataSize, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits per sample
  str(36, 'data');
  header.setUint32(40, dataSize, Endian.little);
  bytes.add(header.buffer.asUint8List());

  final pcm = ByteData(dataSize);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    pcm.setInt16(i * 2, v, Endian.little);
  }
  bytes.add(pcm.buffer.asUint8List());

  File(path).writeAsBytesSync(bytes.toBytes());
  stdout.writeln('  wrote $path (${samples.length} samples)');
}
