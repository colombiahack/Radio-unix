#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uLon0;
uniform float uLat0;
uniform float uRadius;
uniform sampler2D uTex;

out vec4 fragColor;

const float PI = 3.14159265359;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uSize * 0.5) / uRadius;
  p.y = -p.y;
  float r2 = dot(p, p);
  if (r2 > 1.0) {
    fragColor = vec4(0.0);
    return;
  }
  float z = sqrt(1.0 - r2);
  float c0 = cos(uLat0);
  float s0 = sin(uLat0);
  float phi = asin(clamp(p.y * c0 + z * s0, -1.0, 1.0));
  float dl = atan(p.x, z * c0 - p.y * s0);
  float lon = uLon0 + dl;
  float u = fract(lon / (2.0 * PI) + 0.5);
  float v = 0.5 - phi / PI;
  vec3 col = texture(uTex, vec2(u, v)).rgb;

  vec3 n = vec3(p.x, p.y, z);
  vec3 L = normalize(vec3(-0.45, 0.5, 0.75));
  float diff = clamp(dot(n, L), 0.0, 1.0);
  col *= 0.28 + 0.9 * diff;

  float rim = pow(1.0 - z, 2.5);
  col = mix(col, vec3(0.25, 0.6, 1.0), rim * 0.55);
  fragColor = vec4(col, 1.0);
}
