// Living aurora — the iOS-wallpaper wash every glass surface floats above.
//
// A four-point mesh gradient: soft gaussian colour fields drift on slow,
// incommensurate Lissajous paths through a gently domain-warped space, so the
// pattern never visibly repeats. Dark mode adds light (glows on near-black);
// light mode tints a pale canvas. A whisper of film grain dithers the
// gradients so they never band on 8-bit displays.
#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;       // 0,1   canvas size in logical pixels
uniform float uTime;      // 2     seconds
uniform float uIntensity; // 3     glow strength (1 = default)
uniform vec2 uParallax;   // 4,5   pointer offset, -1..1
uniform vec3 uBg;         // 6-8   canvas colour
uniform vec3 uC0;         // 9-11  palette — top-left anchor
uniform vec3 uC1;         // 12-14 right
uniform vec3 uC2;         // 15-17 bottom
uniform vec3 uC3;         // 18-20 bottom-left accent
uniform float uDark;      // 21    1 = dark theme, 0 = light

out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float field(vec2 p, vec2 c, float spread) {
  vec2 d = p - c;
  return exp(-dot(d, d) * spread);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float aspect = uSize.x / max(uSize.y, 1.0);
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime * 0.045;

  // Slow organic warp so the fields flow rather than slide.
  vec2 w = p + 0.09 * vec2(sin(p.y * 2.7 + t * 2.3), cos(p.x * 2.1 - t * 1.9));
  w += 0.035 * vec2(sin(w.y * 5.3 - t * 3.1), cos(w.x * 4.7 + t * 2.7));
  // Depth: the light sits "behind" the glass, so it shifts against the pointer.
  w -= uParallax * vec2(0.035, 0.025);

  vec2 c0 = vec2(0.10 * aspect + 0.14 * sin(t * 1.30), 0.02 + 0.12 * cos(t * 1.10));
  vec2 c1 = vec2(0.98 * aspect + 0.12 * cos(t * 0.93), 0.22 + 0.16 * sin(t * 1.37));
  vec2 c2 = vec2(0.62 * aspect + 0.18 * sin(t * 0.71 + 1.0), 1.04 + 0.10 * cos(t * 1.21));
  vec2 c3 = vec2(0.02 * aspect + 0.12 * cos(t * 1.03 + 2.0), 0.92 + 0.12 * sin(t * 0.83));

  // Each field: a luminous core inside a wide halo.
  float f0 = field(w, c0, 4.2) + 0.35 * field(w, c0, 1.3);
  float f1 = field(w, c1, 4.6) + 0.30 * field(w, c1, 1.4);
  float f2 = field(w, c2, 3.8) + 0.30 * field(w, c2, 1.2);
  float f3 = field(w, c3, 7.0) + 0.20 * field(w, c3, 2.2);

  vec3 col = uBg;
  if (uDark > 0.5) {
    // Additive light on near-black, with a soft shoulder so overlaps glow
    // instead of clipping.
    vec3 glow = uC0 * f0 * 0.62 + uC1 * f1 * 0.50 + uC2 * f2 * 0.42 + uC3 * f3 * 0.34;
    glow *= uIntensity;
    col += glow / (1.0 + glow * 0.8);
    // Vignette: deep edges make the light feel like it's behind glass.
    vec2 v = uv - 0.5;
    col *= 1.0 - 0.55 * dot(v, v);
  } else {
    // Pastel tints on a pale canvas.
    col = mix(col, uC0, f0 * 0.42 * uIntensity);
    col = mix(col, uC1, f1 * 0.30 * uIntensity);
    col = mix(col, uC2, f2 * 0.26 * uIntensity);
    col = mix(col, uC3, f3 * 0.20 * uIntensity);
  }

  // Film grain / dither (±1.5 / 255).
  col += (hash(frag + fract(uTime)) - 0.5) * (3.0 / 255.0);

  fragColor = vec4(col, 1.0);
}
