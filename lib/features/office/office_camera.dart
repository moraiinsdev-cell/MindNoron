import 'dart:math';
import 'dart:ui';

/// Maps between screen and world pixels for the office canvas.
///
/// The base transform auto-fits the whole campus into the viewport (as the
/// office always has). On top of that the player may zoom in with the scroll
/// wheel and pan by dragging the floor. At fit (userZoom == 1) panning is
/// disabled and the campus stays centered, preserving the original feel.
class OfficeCamera {
  static const double minUserZoom = 1.0;
  static const double maxUserZoom = 4.0;

  /// Player-applied magnification on top of the auto-fit zoom.
  double userZoom = 1.0;

  /// Player-applied screen-space pan, relative to the centered base origin.
  Offset pan = Offset.zero;

  double _baseZoom = 1;
  Offset _baseOrigin = Offset.zero;
  Size _canvas = Size.zero;
  double _worldW = 0;
  double _worldH = 0;

  /// Recomputes the auto-fit base transform for the current viewport.
  void fit(Size canvas, double worldW, double worldH) {
    _canvas = canvas;
    _worldW = worldW;
    _worldH = worldH;
    // Fill the canvas: integer scale when generous, otherwise snap to quarter
    // steps so the campus never renders postage-stamp small.
    var zoom = min(canvas.width / worldW, canvas.height / worldH);
    zoom = zoom >= 3
        ? zoom.floorToDouble()
        : max(0.75, (zoom * 4).floorToDouble() / 4);
    _baseZoom = zoom;
    _baseOrigin = Offset(
      (canvas.width - worldW * zoom) / 2,
      (canvas.height - worldH * zoom) / 2,
    );
    _clamp();
  }

  double get zoom => _baseZoom * userZoom;

  Offset get origin => _baseOrigin + pan;

  bool get canPan => userZoom > 1.0001;

  Offset toWorld(Offset local) => (local - origin) / zoom;

  /// Zooms by [factor] keeping the world point under [focal] (screen px) fixed.
  void zoomAt(Offset focal, double factor) {
    final worldBefore = toWorld(focal);
    final next = (userZoom * factor).clamp(minUserZoom, maxUserZoom);
    if (next == userZoom) return;
    userZoom = next;
    // Keep focal stable: focal = origin + worldBefore * zoom.
    pan = focal - worldBefore * zoom - _baseOrigin;
    _clamp();
  }

  void panBy(Offset delta) {
    pan += delta;
    _clamp();
  }

  /// Resets to the fully fitted, centered view.
  void reset() {
    userZoom = 1.0;
    pan = Offset.zero;
  }

  void _clamp() {
    pan = Offset(
      _clampAxis(pan.dx, _baseOrigin.dx, _worldW * zoom, _canvas.width),
      _clampAxis(pan.dy, _baseOrigin.dy, _worldH * zoom, _canvas.height),
    );
  }

  // Keeps the world covering the viewport when it is larger than the canvas;
  // re-centers (pan 0) on any axis where the world still fits.
  static double _clampAxis(
      double panV, double base, double world, double canvas) {
    if (world <= canvas + 0.5) return 0;
    final origin = (base + panV).clamp(canvas - world, 0.0);
    return origin - base;
  }
}
