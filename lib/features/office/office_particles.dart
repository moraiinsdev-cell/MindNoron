import 'dart:math';
import 'dart:ui';

/// What a particle looks like and how it moves.
enum ParticleKind {
  /// Soft steam rising from coffee.
  steam,

  /// Faint dust motes drifting indoors.
  dust,

  /// Petals/leaves tumbling over the garden.
  petal,

  /// Bright confetti for celebrations (gravity + flutter).
  confetti,

  /// Water droplets from a splash.
  splash,
}

class Particle {
  Particle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.maxLife,
    required this.size,
    required this.color,
    required this.kind,
    this.seed = 0,
  });

  Offset pos;
  Offset vel;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  final ParticleKind kind;
  final double seed;

  double get t => 1 - (life / maxLife); // 0 at birth → 1 at death
}

/// A lightweight, pooled particle system for office ambience and effects.
///
/// Ambient emitters (dust, petals) self-spawn on timers; contextual effects
/// (coffee steam, splashes, confetti) are triggered by the simulation. The
/// painter draws everything in world space.
class ParticleField {
  ParticleField(this._rng);

  final Random _rng;
  final particles = <Particle>[];

  static const _max = 260;

  // Indoor footprint (tiles 1..38) and garden (tiles 39..55) in world px.
  static const _indoor = Rect.fromLTWH(16, 32, 37 * 16, 31 * 16);
  static const _garden = Rect.fromLTWH(39 * 16, 48, 16 * 16, 30 * 16);

  double _dustTimer = 0;
  double _petalTimer = 1.5;

  void tick(double dt) {
    for (final p in particles) {
      p.life -= dt;
      switch (p.kind) {
        case ParticleKind.steam:
          // Rise and waver, expanding slightly.
          p.pos += p.vel * dt +
              Offset(sin((p.t + p.seed) * 6) * 4 * dt, 0);
        case ParticleKind.dust:
          p.pos += p.vel * dt +
              Offset(sin((p.t + p.seed) * 2) * 1.5 * dt, 0);
        case ParticleKind.petal:
          p.pos += p.vel * dt +
              Offset(sin((p.t + p.seed) * 4) * 9 * dt, 0);
        case ParticleKind.confetti:
          p.vel = Offset(p.vel.dx, p.vel.dy + 60 * dt); // gravity
          p.pos += p.vel * dt +
              Offset(sin((p.t + p.seed) * 12) * 14 * dt, 0);
        case ParticleKind.splash:
          p.vel = Offset(p.vel.dx, p.vel.dy + 120 * dt); // gravity
          p.pos += p.vel * dt;
      }
    }
    particles.removeWhere((p) => p.life <= 0);

    // Ambient dust motes catching the light indoors.
    _dustTimer -= dt;
    if (_dustTimer <= 0) {
      _dustTimer = 0.35 + _rng.nextDouble() * 0.5;
      if (_countOf(ParticleKind.dust) < 46) _spawnDust();
    }

    // Occasional petals over the garden.
    _petalTimer -= dt;
    if (_petalTimer <= 0) {
      _petalTimer = 1.4 + _rng.nextDouble() * 2.6;
      if (_countOf(ParticleKind.petal) < 18) _spawnPetal();
    }
  }

  int _countOf(ParticleKind kind) {
    var n = 0;
    for (final p in particles) {
      if (p.kind == kind) n++;
    }
    return n;
  }

  void _add(Particle p) {
    if (particles.length >= _max) return;
    particles.add(p);
  }

  void _spawnDust() {
    final pos = Offset(
      _indoor.left + _rng.nextDouble() * _indoor.width,
      _indoor.top + _rng.nextDouble() * _indoor.height,
    );
    _add(Particle(
      pos: pos,
      vel: Offset((_rng.nextDouble() - 0.5) * 3, -2 - _rng.nextDouble() * 3),
      life: 4 + _rng.nextDouble() * 4,
      maxLife: 8,
      size: 1,
      color: const Color(0xFFFFF4D8),
      kind: ParticleKind.dust,
      seed: _rng.nextDouble() * 6.28,
    ));
  }

  void _spawnPetal() {
    final pos = Offset(
      _garden.left + _rng.nextDouble() * _garden.width,
      _garden.top + _rng.nextDouble() * 40,
    );
    const palette = [
      Color(0xFFE89CB8),
      Color(0xFFF2E8C8),
      Color(0xFF8FBF6F),
      Color(0xFFE8C84A),
    ];
    _add(Particle(
      pos: pos,
      vel: Offset((_rng.nextDouble() - 0.5) * 6, 10 + _rng.nextDouble() * 8),
      life: 5 + _rng.nextDouble() * 4,
      maxLife: 9,
      size: 2,
      color: palette[_rng.nextInt(palette.length)],
      kind: ParticleKind.petal,
      seed: _rng.nextDouble() * 6.28,
    ));
  }

  /// A small puff of steam at [at] (e.g. above a coffee cup).
  void emitSteam(Offset at) {
    _add(Particle(
      pos: at + Offset((_rng.nextDouble() - 0.5) * 2, 0),
      vel: Offset((_rng.nextDouble() - 0.5) * 2, -8 - _rng.nextDouble() * 4),
      life: 1.0 + _rng.nextDouble() * 0.8,
      maxLife: 1.8,
      size: 2,
      color: const Color(0xFFFFFFFF),
      kind: ParticleKind.steam,
      seed: _rng.nextDouble() * 6.28,
    ));
  }

  /// A ring of water droplets at [at] (pool splash).
  void splash(Offset at, {int count = 10}) {
    for (var i = 0; i < count; i++) {
      final a = (i / count) * pi * 2 + _rng.nextDouble();
      final speed = 18 + _rng.nextDouble() * 22;
      _add(Particle(
        pos: at,
        vel: Offset(cos(a) * speed, -sin(a).abs() * speed - 10),
        life: 0.5 + _rng.nextDouble() * 0.4,
        maxLife: 0.9,
        size: 1.6,
        color: const Color(0xFFE8F4FA),
        kind: ParticleKind.splash,
        seed: 0,
      ));
    }
  }

  /// A low puff of dust kicked up at [at] (a landing / pick-up).
  void puff(Offset at, {int count = 8}) {
    for (var i = 0; i < count; i++) {
      final a = (i / count) * pi * 2 + _rng.nextDouble();
      final speed = 8 + _rng.nextDouble() * 16;
      _add(Particle(
        pos: at,
        vel: Offset(cos(a) * speed, -sin(a).abs() * speed * 0.5 - 4),
        life: 0.4 + _rng.nextDouble() * 0.4,
        maxLife: 0.8,
        size: 1.5 + _rng.nextDouble(),
        color: const Color(0xFFD8CFBE),
        kind: ParticleKind.dust,
        seed: _rng.nextDouble() * 6.28,
      ));
    }
  }

  /// A short upward spark fountain at [at] (an energy jolt).
  void spark(Offset at, {int count = 10}) {
    const palette = [Color(0xFFFFE27A), Color(0xFFFFD24A), Color(0xFFFFFFFF)];
    for (var i = 0; i < count; i++) {
      final a = -pi / 2 + (_rng.nextDouble() - 0.5) * 1.4;
      final speed = 24 + _rng.nextDouble() * 40;
      _add(Particle(
        pos: at,
        vel: Offset(cos(a) * speed, sin(a) * speed),
        life: 0.4 + _rng.nextDouble() * 0.4,
        maxLife: 0.8,
        size: 1.5,
        color: palette[_rng.nextInt(palette.length)],
        kind: ParticleKind.splash,
        seed: _rng.nextDouble() * 6.28,
      ));
    }
  }

  /// A celebratory confetti burst at [at].
  void confetti(Offset at, {int count = 26}) {
    const palette = [
      Color(0xFFE85C6A),
      Color(0xFFFFD24A),
      Color(0xFF4EC8E0),
      Color(0xFF8FE06A),
      Color(0xFFE89CD8),
      Color(0xFFFFFFFF),
    ];
    for (var i = 0; i < count; i++) {
      final a = -pi / 2 + (_rng.nextDouble() - 0.5) * 2.2;
      final speed = 30 + _rng.nextDouble() * 70;
      _add(Particle(
        pos: at,
        vel: Offset(cos(a) * speed, sin(a) * speed),
        life: 1.1 + _rng.nextDouble() * 1.0,
        maxLife: 2.1,
        size: 2 + _rng.nextDouble() * 2,
        color: palette[_rng.nextInt(palette.length)],
        kind: ParticleKind.confetti,
        seed: _rng.nextDouble() * 6.28,
      ));
    }
  }

  void clear() => particles.clear();
}
