// Buffer A — Ultra Realistic Water on Window
// Inspired by Shadertoy's realistic rain effects
// Creates organic water drops with trails, merging, and natural physics

#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2  uResolution;
uniform float uTime;
uniform float uIntensity;

out vec4 fragColor;

#define S(a,b,t) smoothstep(a,b,t)

// High quality noise functions
vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy) * 2.0 - 1.0;
}

float hash21(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// Smooth noise
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Organic droplet shape using multiple layered circles with noise distortion
vec3 dropLayer(vec2 uv, float t) {
  // Grid for drops
  vec2 aspect = vec2(2.0, 1.0);
  vec2 st = uv * 20.0 * aspect;
  
  // Offset every other row
  st.x += step(1.0, mod(st.y, 2.0)) * 0.5;
  
  vec2 gv = fract(st) - 0.5;
  vec2 id = floor(st);
  
  float n = hash21(id);
  
  // Skip some cells for varied density
  if (n > 0.7 * uIntensity) return vec3(0.0);
  
  // Individual drop properties
  float delay = n * 6.28;
  float speed = 0.5 + n * 0.5;
  
  // Vertical movement with wobble - DROPS FALL DOWN
  float dropT = fract(t * speed + delay);
  float y = dropT - 0.5; // Goes from -0.5 (top) to 0.5 (bottom)
  
  // Horizontal drift
  float x = (n - 0.5) * 0.3;
  x += sin(dropT * 8.0 + delay) * 0.02;
  
  vec2 dropPos = vec2(x, y);
  vec2 delta = gv - dropPos;
  
  // Organic shape - main dome with distortion
  float distort = noise(id * 10.0 + t) * 0.3;
  delta.x *= 1.0 + distort * 0.5;
  delta.y *= 0.8 + distort * 0.3; // Taller drops
  
  float dist = length(delta);
  float dropRadius = 0.15 + n * 0.1;
  
  // Soft drop edge
  float drop = S(dropRadius, dropRadius * 0.5, dist);
  
  // Height map for refraction (dome shape)
  float height = 1.0 - dist / dropRadius;
  height = height * height * drop;
  
  // Trail ABOVE the drop (where it came from)
  float trail = 0.0;
  float trailWidth = dropRadius * 0.3;
  float trailLen = 0.4 + n * 0.3;
  
  // Trail is ABOVE drop (lower Y values = higher on screen)
  if (gv.y < dropPos.y && gv.y > dropPos.y - trailLen) {
    float trailX = abs(gv.x - dropPos.x);
    
    // Trail gets thinner further from drop
    float trailProgress = (dropPos.y - gv.y) / trailLen;
    float currentWidth = trailWidth * (1.0 - trailProgress * 0.7);
    
    trail = S(currentWidth, currentWidth * 0.3, trailX);
    trail *= (1.0 - trailProgress); // Fade out
    trail *= 0.4;
  }
  
  // Normal calculation based on position in drop
  vec2 normal = vec2(0.0);
  if (drop > 0.01) {
    normal = -normalize(delta) * height * 2.0;
  }
  
  return vec3(normal, max(drop, trail));
}

// Condensation - many tiny static drops
float condensation(vec2 uv, float density) {
  vec2 grid = uv * 80.0;
  vec2 id = floor(grid);
  vec2 f = fract(grid) - 0.5;
  
  float n = hash21(id);
  if (n > density) return 0.0;
  
  vec2 offset = hash22(id) * 0.35;
  float dist = length(f - offset);
  float size = 0.08 + n * 0.12;
  
  return S(size, size * 0.2, dist) * 0.3;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uResolution;
  
  float aspect = uResolution.x / uResolution.y;
  float t = uTime * 0.15;
  float rain = clamp(uIntensity, 0.0, 1.0);
  
  // Accumulate from multiple drop layers for depth
  vec3 layer1 = dropLayer(uv, t);
  vec3 layer2 = dropLayer(uv * 1.3 + 10.0, t * 0.9) * 0.6;
  vec3 layer3 = dropLayer(uv * 0.8 + 20.0, t * 1.1) * 0.4;
  
  // Combine layers
  vec2 totalNormal = layer1.xy + layer2.xy + layer3.xy;
  float totalMask = max(max(layer1.z, layer2.z), layer3.z);
  
  // Add condensation
  float conden = condensation(uv, 0.4 * rain);
  totalMask = max(totalMask, conden);
  
  // Apply intensity
  totalNormal *= rain;
  totalMask *= rain;
  
  // Blur: more behind drops, less through drops
  float blur = mix(0.6, 0.15, totalMask);
  
  // Fog/mist effect
  float fog = noise(uv * 4.0 + t * 0.2) * 0.3;
  fog *= mix(0.3, 1.0, 1.0 - uv.y); // More fog at bottom
  fog *= rain * 0.5;
  
  // Pack output: RG = normal, B = blur, A = fog+mask
  vec2 packedNormal = totalNormal * 0.15 + 0.5;
  fragColor = vec4(packedNormal, blur, fog + totalMask * 0.3);
}
