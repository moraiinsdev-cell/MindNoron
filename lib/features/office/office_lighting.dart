import 'dart:ui';

/// Time-of-day lighting for the campus.
///
/// Replaces the old step-wise hourly tint with a value interpolated by the
/// minute, so dawn/dusk roll in smoothly instead of snapping. Exposes both a
/// flat colour wash ([tint]) and a [darkness] factor (0 = midday, 1 = deep
/// night) that drives how strongly the lamps and monitors glow.
class SkyLight {
  const SkyLight(this.tint, this.darkness);

  /// Colour washed over the whole scene (may be fully transparent at midday).
  final Color tint;

  /// 0 at midday → 1 in the dead of night. Scales additive light pools.
  final double darkness;

  /// Lighting for a continuous hour-of-day (e.g. 18.5 = 18:30).
  static SkyLight at(double hour) {
    for (var i = 0; i < _keys.length - 1; i++) {
      final a = _keys[i];
      final b = _keys[i + 1];
      if (hour >= a.hour && hour <= b.hour) {
        final t = (hour - a.hour) / (b.hour - a.hour);
        return SkyLight(
          Color.lerp(a.tint, b.tint, t)!,
          a.darkness + (b.darkness - a.darkness) * t,
        );
      }
    }
    return SkyLight(_keys.last.tint, _keys.last.darkness);
  }

  static SkyLight now() {
    final n = DateTime.now();
    return at(n.hour + n.minute / 60.0);
  }

  // Keyframes across the day. Tints are deliberately low-alpha so the pixel
  // art keeps reading; the warmth/coolness sells the hour.
  static const _keys = <_SkyKey>[
    _SkyKey(0, Color(0x551A2342), 1.0), // deep night, cool blue
    _SkyKey(5.5, Color(0x4C1C2A46), 0.92), // pre-dawn
    _SkyKey(7.0, Color(0x1FE8B860), 0.32), // sunrise warmth
    _SkyKey(8.5, Color(0x00000000), 0.0), // clear morning
    _SkyKey(16.5, Color(0x00000000), 0.0), // clear afternoon
    _SkyKey(17.5, Color(0x22E0902E), 0.16), // golden hour
    _SkyKey(19.0, Color(0x33324063), 0.5), // dusk
    _SkyKey(20.5, Color(0x4A1E2A4C), 0.86), // nightfall
    _SkyKey(24.0, Color(0x551A2342), 1.0), // wraps to deep night
  ];
}

class _SkyKey {
  const _SkyKey(this.hour, this.tint, this.darkness);
  final double hour;
  final Color tint;
  final double darkness;
}
