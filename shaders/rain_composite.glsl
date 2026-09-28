// Photorealistic Rain on Glass Shader — Single Pass Full Native Resolution
// Features:
// - Delicate multi-scale water beads & slender stick-slip rivulets
// - Authentic frosted glass background bokeh
// - Crystal convex lens refraction with chromatic dispersion
// - Realistic dual specular highlights, caustics, and dark meniscus edges
// - Fluid interactive finger wipe clearing

#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2  uResolution;
uniform float uTime;
uniform float uIntensity;
uniform vec2  uTouch;

uniform sampler2D uBg;

out vec4 fragColor;

#define S(a,b,t) (smoothstep((a), (b), (t)))

// High precision pseudo-random hash functions
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

// Five-tap soft blur for dreamy out-of-focus background bokeh.
vec3 sampleBokehBg(vec2 uv, vec2 px, float blurRadius) {
  vec2 off = px * blurRadius;
  vec3 col = texture(uBg, uv).rgb * 0.40;
  col += texture(uBg, uv + vec2(off.x, 0.0)).rgb * 0.15;
  col += texture(uBg, uv - vec2(off.x, 0.0)).rgb * 0.15;
  col += texture(uBg, uv + vec2(0.0, off.y)).rgb * 0.15;
  col += texture(uBg, uv - vec2(0.0, off.y)).rgb * 0.15;
  return col;
}

// Slender sliding rivulet layer with stick-slip physics
vec4 slidingRivulets(vec2 p, float t, float intensity) {
  vec2 gridScale = vec2(14.0, 3.2);
  vec2 st = p * gridScale;
  st.y += step(1.0, mod(st.x, 2.0)) * 0.5;

  vec2 id = floor(st);
  vec2 gv = fract(st) - 0.5;

  float n = hash21(id);
  if (n > 0.45 * intensity) return vec4(0.0);

  float speed = 0.18 + n * 0.22;
  float dropTime = t * speed + n * 6.28;

  // Stick-slip: drop lingers, then accelerates downward
  float cycle = fract(dropTime);
  float slide = smoothstep(0.55, 0.92, cycle);
  float yDrop = fract(floor(dropTime) + slide) - 0.5;

  // Delicate lateral meander
  float xWobble = (n - 0.5) * 0.35 + sin(yDrop * 12.0 + n * 18.0) * 0.04;
  vec2 dropCenter = vec2(xWobble, yDrop);
  vec2 delta = gv - dropCenter;

  // Teardrop elongation
  delta.x *= 1.0 + delta.y * 0.7;
  delta.y *= 1.15;

  float dist = length(delta);
  float radius = 0.045 + n * 0.035; // delicate drop size

  float dropMask = S(radius, radius * 0.65, dist);
  vec2 normal = vec2(0.0);

  if (dropMask > 0.001) {
    float normDist = clamp(dist / radius, 0.0, 1.0);
    float h = sqrt(max(0.0, 1.0 - normDist * normDist));
    normal = -normalize(delta + vec2(0.0001)) * h;
  }

  // Slender trail with trailing micro-beads
  float trailMask = 0.0;
  float trailLen = 0.42 + n * 0.28;
  if (gv.y < dropCenter.y && gv.y > dropCenter.y - trailLen) {
    float trailProgress = (dropCenter.y - gv.y) / trailLen;
    float trailWidth = radius * (0.3 * (1.0 - trailProgress * 0.75));
    float trailDistX = abs(gv.x - dropCenter.x);

    // Tiny beads along trail
    float beadGrid = fract(gv.y * 14.0 + n * 7.0) - 0.5;
    float bead = S(0.18, 0.04, length(vec2(trailDistX * 2.2, beadGrid))) * (1.0 - trailProgress);

    trailMask = S(trailWidth, trailWidth * 0.2, trailDistX) * (1.0 - trailProgress * 0.85);
    trailMask = max(trailMask * 0.3, bead * 0.7);

    if (trailMask > dropMask) {
      normal = vec2(sin(trailDistX * 45.0), 0.25) * trailMask * 0.4;
    }
  }

  float finalMask = max(dropMask, trailMask);
  return vec4(normal, finalMask, dropMask > 0.05 ? 1.0 : trailMask * 0.5);
}

// Medium static / clinging resting beads
vec4 staticBeads(vec2 p, float intensity) {
  vec2 gridScale = vec2(26.0, 26.0);
  vec2 st = p * gridScale;
  st.x += step(1.0, mod(st.y, 2.0)) * 0.5;

  vec2 id = floor(st);
  vec2 gv = fract(st) - 0.5;

  float n = hash21(id);
  if (n > 0.62 * intensity) return vec4(0.0);

  vec2 offset = hash22(id) * 0.36;
  vec2 delta = gv - offset;

  // Subtle gravitational sag
  delta.y += delta.x * delta.x * 0.25;

  float dist = length(delta);
  float radius = 0.04 + n * 0.05; // delicate round beads

  float mask = S(radius, radius * 0.65, dist);
  vec2 normal = vec2(0.0);

  if (mask > 0.001) {
    float normDist = clamp(dist / radius, 0.0, 1.0);
    float h = sqrt(max(0.0, 1.0 - normDist * normDist));
    normal = -normalize(delta + vec2(0.0001)) * h;
  }

  return vec4(normal, mask, mask);
}

// Small fine condensation droplets
vec4 fineMist(vec2 p, float intensity) {
  vec2 gridScale = vec2(52.0, 52.0);
  vec2 st = p * gridScale;

  vec2 id = floor(st);
  vec2 gv = fract(st) - 0.5;

  float n = hash21(id);
  if (n > 0.75 * intensity) return vec4(0.0);

  vec2 offset = hash22(id) * 0.32;
  vec2 delta = gv - offset;
  float dist = length(delta);
  float radius = 0.03 + n * 0.04;

  float mask = S(radius, radius * 0.5, dist);
  vec2 normal = vec2(0.0);

  if (mask > 0.001) {
    float normDist = clamp(dist / radius, 0.0, 1.0);
    float h = sqrt(max(0.0, 1.0 - normDist * normDist));
    normal = -normalize(delta + vec2(0.0001)) * h * 0.5;
  }

  return vec4(normal, mask * 0.6, mask * 0.6);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uResolution;
  vec2 px = 1.0 / uResolution;

  float t = uTime;
  float intensity = clamp(uIntensity, 0.0, 1.0);

  // Aspect ratio correction for spherical droplet proportions
  vec2 aspect = vec2(uResolution.x / uResolution.y, 1.0);
  vec2 p = uv * aspect;

  // Interactive finger touch wipe & fluid displacement
  float touchWipe = 0.0;
  if (uTouch.x >= 0.0) {
    vec2 touchP = (uTouch / uResolution) * aspect;
    float distToTouch = length(p - touchP);
    touchWipe = exp(-distToTouch * 24.0);
  }

  // Calculate multi-scale droplet layers directly at native resolution
  vec4 rivulets = slidingRivulets(p, t, intensity);
  vec4 beads = staticBeads(p, intensity);
  vec4 mist = fineMist(p, intensity);

  // Priority blending
  vec2 normal = vec2(0.0);
  float clarity = 0.0;
  float sheen = 0.0;

  if (rivulets.z > 0.01) {
    normal = rivulets.xy;
    clarity = rivulets.z;
    sheen = rivulets.w;
  } else if (beads.z > 0.01) {
    normal = beads.xy;
    clarity = beads.z;
    sheen = beads.w;
  } else if (mist.z > 0.01) {
    normal = mist.xy;
    clarity = mist.z;
    sheen = mist.w;
  }

  // Apply intensity and touch wipe
  float wipeFactor = 1.0 - touchWipe * 0.98;
  normal *= intensity * wipeFactor;
  clarity *= intensity * wipeFactor;
  sheen *= intensity * wipeFactor;

  float normLen = length(normal);

  // 1. Frosted Glass Background with Soft Bokeh Blur
  // Through the misty pane, the background is softly out-of-focus
  float bgBlur = mix(3.5, 0.3, clarity) * (0.6 + intensity * 0.4);
  vec3 blurredBg = sampleBokehBg(uv, px, bgBlur);

  // 2. Crystal Droplet Lensing (Refraction & Inversion)
  // Water droplets act as convex optical lenses with chromatic dispersion
  float refrScale = 0.034 * intensity;
  vec2 refrOffset = normal * refrScale;

  vec3 refractedColor = texture(uBg, uv + refrOffset).rgb;

  // Blend refracted drop interior over blurred background
  vec3 col = mix(blurredBg, refractedColor, clamp(clarity * 1.4, 0.0, 1.0));

  // 3. Specular Optics & Meniscus Borders
  if (normLen > 0.01 && clarity > 0.04) {
    // Primary top skylight reflection
    float topGleam = pow(max(0.0, -normal.y * 0.85 - normal.x * 0.35), 16.0);
    vec3 skyHighlight = vec3(0.96, 0.98, 1.0) * topGleam * 2.4;

    // Secondary lower caustic arc
    float bottomCaustic = pow(max(0.0, normal.y * 0.8), 3.5);
    vec3 causticColor = vec3(0.85, 0.92, 1.0) * bottomCaustic * 0.7;

    // Fresnel rim glow
    float fresnel = pow(normLen, 2.2) * 0.55;
    vec3 fresnelColor = vec3(0.82, 0.90, 0.98) * fresnel;

    // Total internal reflection dark meniscus border (creates crisp 3D pop)
    float meniscusDarken = smoothstep(0.72, 0.96, normLen) * 0.38;
    col *= (1.0 - meniscusDarken);

    col += (skyHighlight + causticColor + fresnelColor) * intensity;
  }

  // Subtle wet trail sheen
  if (sheen > 0.1 && clarity < 0.4) {
    col += vec3(0.18, 0.22, 0.30) * sheen * 0.35 * intensity;
  }

  // Atmospheric grading
  col = pow(col, vec3(0.96));
  col *= vec3(0.98, 0.99, 1.02);

  // Top sky darkening to prevent washed-out sky and enhance fog contrast
  float topSkyDarken = smoothstep(0.65, 0.0, uv.y) * 0.32;
  col *= (1.0 - topSkyDarken);

  // Vignette
  vec2 vP = uv - 0.5;
  col *= clamp(1.0 - dot(vP, vP) * 0.70, 0.0, 1.0);

  fragColor = vec4(col, 1.0);
}
