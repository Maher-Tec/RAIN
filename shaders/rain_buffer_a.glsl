// Buffer A — Photorealistic Water on Glass Physics Field
// Multi-scale droplet simulation: stick-slip rivulets, static clinging beads,
// micro-condensation, and interactive fluid clearing.

#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2  uResolution;
uniform float uTime;
uniform float uIntensity;
uniform vec2  uTouch;

out vec4 fragColor;

#define S(a,b,t) (smoothstep((a), (b), (t)))

// High quality pseudo-random hash functions
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

// 2D Value Noise
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

// Organic stick-slip movement (drops hold, gather weight, then rush down)
float stickSlipMotion(float t, float seed) {
  float cycle = fract(t + seed);
  // Stays stationary for 60% of cycle, then surges downward with gravity
  float slide = smoothstep(0.55, 0.92, cycle);
  return floor(t + seed) + slide;
}

// Large sliding droplets (Rivulets with trails)
vec4 slidingDropLayer(vec2 uv, float t) {
  vec2 gridScale = vec2(6.0, 1.2);
  vec2 st = uv * gridScale;

  // Stagger alternating columns
  st.y += step(1.0, mod(st.x, 2.0)) * 0.5;

  vec2 id = floor(st);
  vec2 gv = fract(st) - 0.5;

  float n = hash21(id);
  if (n > 0.65 * uIntensity) return vec4(0.0);

  float dropSpeed = 0.22 + n * 0.28;
  float dropT = stickSlipMotion(t * dropSpeed, n * 6.28);

  // Vertical position with realistic downward progression
  float yProg = fract(dropT);
  float yPos = yProg - 0.5;

  // Lateral meander (wobble along the path avoiding dry spots)
  float xOffset = (n - 0.5) * 0.45;
  xOffset += sin(yProg * 14.0 + n * 20.0) * 0.05 * (1.0 + n);

  vec2 dropCenter = vec2(xOffset, yPos);
  vec2 delta = gv - dropCenter;

  // Teardrop distortion: wider at the bottom, tapered at top
  float yDist = delta.y;
  delta.x *= 1.0 + yDist * 0.6;
  delta.y *= 1.2;

  float dist = length(delta);
  float radius = 0.09 + n * 0.08;

  // Main drop mask
  float dropMask = S(radius, radius * 0.7, dist);

  // Spherical normal calculation
  vec2 normal = vec2(0.0);
  if (dropMask > 0.001) {
    float normDist = clamp(dist / radius, 0.0, 1.0);
    float height = sqrt(max(0.0, 1.0 - normDist * normDist));
    normal = -normalize(delta + vec2(0.0001)) * height;
  }

  // Wet trail above sliding drop
  float trailMask = 0.0;
  float trailLength = 0.45 + n * 0.35;
  if (gv.y < dropCenter.y && gv.y > dropCenter.y - trailLength) {
    float trailProgress = (dropCenter.y - gv.y) / trailLength;
    float trailWidth = radius * (0.35 * (1.0 - trailProgress * 0.7));
    float trailDistX = abs(gv.x - dropCenter.x);

    // Trail micro-beads
    float beadGrid = fract(gv.y * 12.0 + n * 5.0) - 0.5;
    float bead = S(0.2, 0.05, length(vec2(trailDistX * 2.0, beadGrid))) * (1.0 - trailProgress);

    trailMask = S(trailWidth, trailWidth * 0.2, trailDistX) * (1.0 - trailProgress * 0.85);
    trailMask = max(trailMask * 0.35, bead * 0.8);

    if (trailMask > dropMask) {
      normal = vec2(sin(trailDistX * 40.0), 0.3) * trailMask * 0.5;
    }
  }

  float finalMask = max(dropMask, trailMask);
  return vec4(normal, finalMask, dropMask > 0.1 ? 1.0 : trailMask);
}

// Medium static / clinging resting droplets
vec4 staticDropLayer(vec2 uv, float density) {
  vec2 gridScale = vec2(16.0, 16.0);
  vec2 st = uv * gridScale;

  // Hexagonal-like stagger
  st.x += step(1.0, mod(st.y, 2.0)) * 0.5;

  vec2 id = floor(st);
  vec2 gv = fract(st) - 0.5;

  float n = hash21(id);
  if (n > density) return vec4(0.0);

  vec2 offset = hash22(id) * 0.38;
  vec2 delta = gv - offset;

  // Gravitational asymmetry: bottom of drop sags slightly
  delta.y += delta.x * delta.x * 0.35;

  float dist = length(delta);
  float radius = 0.08 + n * 0.14;

  float mask = S(radius, radius * 0.65, dist);
  vec2 normal = vec2(0.0);

  if (mask > 0.001) {
    float normDist = clamp(dist / radius, 0.0, 1.0);
    float height = sqrt(max(0.0, 1.0 - normDist * normDist));
    normal = -normalize(delta + vec2(0.0001)) * height;
  }

  return vec4(normal, mask, mask);
}

// Micro condensation beads
vec4 condensationLayer(vec2 uv, float density) {
  vec2 gridScale = vec2(42.0, 42.0);
  vec2 st = uv * gridScale;

  vec2 id = floor(st);
  vec2 gv = fract(st) - 0.5;

  float n = hash21(id);
  if (n > density) return vec4(0.0);

  vec2 offset = hash22(id) * 0.35;
  vec2 delta = gv - offset;
  float dist = length(delta);
  float radius = 0.06 + n * 0.08;

  float mask = S(radius, radius * 0.5, dist);
  vec2 normal = vec2(0.0);

  if (mask > 0.001) {
    float normDist = clamp(dist / radius, 0.0, 1.0);
    float height = sqrt(max(0.0, 1.0 - normDist * normDist));
    normal = -normalize(delta + vec2(0.0001)) * height * 0.5;
  }

  return vec4(normal, mask * 0.7, mask * 0.7);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uResolution;

  float t = uTime;
  float intensity = clamp(uIntensity, 0.0, 1.0);

  // Aspect ratio correction for spherical droplet distortion
  vec2 aspect = vec2(uResolution.x / uResolution.y, 1.0);
  vec2 aspectUv = uv * aspect;

  // Touch wipe & fluid displacement interaction
  float touchWipe = 0.0;
  vec2 touchDisplace = vec2(0.0);
  if (uTouch.x >= 0.0) {
    vec2 touchUv = (uTouch / uResolution) * aspect;
    vec2 deltaTouch = aspectUv - touchUv;
    float distToTouch = length(deltaTouch);
    touchWipe = exp(-distToTouch * 22.0);
    touchDisplace = normalize(deltaTouch + vec2(0.0001)) * exp(-distToTouch * 12.0) * 0.015;
  }

  vec2 sampleUv = aspectUv + touchDisplace;

  // 1. Sliding heavy drops (rivulets)
  vec4 sliding = slidingDropLayer(sampleUv * 0.8, t);

  // 2. Medium static clinging drops
  vec4 staticDrops = staticDropLayer(sampleUv * 1.2, 0.72 * intensity);

  // 3. Fine condensation mist beads
  vec4 condensation = condensationLayer(sampleUv * 1.5, 0.82 * intensity);

  // Blend layers from front to back
  vec2 finalNormal = vec2(0.0);
  float finalClarity = 0.0;
  float finalSheen = 0.0;

  // Sliding drops take highest priority
  if (sliding.z > 0.01) {
    finalNormal = sliding.xy;
    finalClarity = sliding.z;
    finalSheen = sliding.w;
  } else if (staticDrops.z > 0.01) {
    finalNormal = staticDrops.xy;
    finalClarity = staticDrops.z;
    finalSheen = staticDrops.w;
  } else {
    finalNormal = condensation.xy;
    finalClarity = condensation.z;
    finalSheen = condensation.w;
  }

  // Apply intensity scaling and touch wipe
  float wipeInv = 1.0 - touchWipe * 0.98;
  finalNormal *= intensity * wipeInv;
  finalClarity *= intensity * wipeInv;
  finalSheen *= intensity * wipeInv;

  // Pack output for composite shader:
  // RG: Normalized 2D Surface Normal [0.0..1.0]
  // B: Droplet Optical Clarity / Sharpness factor [0.0..1.0]
  // A: Droplet Sheen & Meniscus Mask [0.0..1.0]
  vec2 packedNormal = finalNormal * 0.5 + 0.5;
  fragColor = vec4(packedNormal, finalClarity, finalSheen);
}
