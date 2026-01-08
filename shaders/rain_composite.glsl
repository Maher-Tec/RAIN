// Composite shader — Ultra Realistic Water on Window
// Makes water drops VISIBLE on gradient background

#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2  uResolution;
uniform float uTime;
uniform float uIntensity;

uniform sampler2D uBufferA;
uniform sampler2D uBg;

out vec4 fragColor;

// Vignette
float vignette(vec2 uv) {
  vec2 p = uv - 0.5;
  return 1.0 - dot(p, p) * 0.6;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uResolution;
  vec2 px = 1.0 / uResolution;

  // Read Buffer A
  vec4 a = texture(uBufferA, uv);
  
  // Unpack data
  vec2 normal = (a.xy - 0.5) * 2.0;
  float blurMask = a.z;
  float fogMask = a.w;
  
  // Smooth normals by sampling neighbors
  vec2 e = px * 2.0;
  vec4 aL = texture(uBufferA, uv - vec2(e.x, 0.0));
  vec4 aR = texture(uBufferA, uv + vec2(e.x, 0.0));
  vec4 aU = texture(uBufferA, uv - vec2(0.0, e.y));
  vec4 aD = texture(uBufferA, uv + vec2(0.0, e.y));
  
  vec2 smoothNormal = normal * 0.5;
  smoothNormal += (aL.xy - 0.5) * 2.0 * 0.125;
  smoothNormal += (aR.xy - 0.5) * 2.0 * 0.125;
  smoothNormal += (aU.xy - 0.5) * 2.0 * 0.125;
  smoothNormal += (aD.xy - 0.5) * 2.0 * 0.125;
  
  float k = clamp(uIntensity, 0.0, 1.0);
  float normalStrength = length(smoothNormal);
  
  // === BACKGROUND ===
  // Sample background with slight refraction offset
  vec2 refraction = smoothNormal * 0.02 * k;
  vec3 col = texture(uBg, uv + refraction).rgb;
  
  // === WATER DROP VISIBILITY ===
  // Make drops visible even on solid gradient!
  
  // Detect if we're inside a water drop (low blur = inside drop)
  float insideDrop = smoothstep(0.4, 0.1, blurMask);
  
  // 1. HIGHLIGHT at top of drops (light from above)
  float topHighlight = smoothstep(-0.1, 0.3, smoothNormal.y);
  float highlight = topHighlight * normalStrength * insideDrop * 3.0;
  
  // 2. FRESNEL RIM HIGHLIGHT at edges
  float fresnel = pow(normalStrength, 1.5) * insideDrop * 2.0;
  
  // 3. BOTTOM CAUSTIC (light gathering at bottom of drop)
  float bottomCaustic = smoothstep(0.1, -0.2, smoothNormal.y) * normalStrength * insideDrop;
  
  // Combine highlights
  vec3 highlightColor = vec3(0.7, 0.75, 0.85);
  col += highlightColor * (highlight + fresnel * 0.5 + bottomCaustic * 0.3) * k;
  
  // 4. SLIGHT TRANSPARENCY in drop center
  float dropCenter = (1.0 - normalStrength * 2.0) * insideDrop;
  col *= 1.0 - dropCenter * 0.1 * k;
  
  // 5. EDGE DARKENING (water absorbs light at edges)
  float edgeDarken = fresnel * 0.15 * k;
  col *= 1.0 - edgeDarken;
  
  // === TRAILS ===
  // Show trails as slight highlights
  float trail = fogMask * (1.0 - insideDrop);
  col += vec3(0.3, 0.35, 0.4) * trail * 0.5 * k;
  
  // === FOG/MIST ===
  vec3 fogColor = vec3(0.12, 0.14, 0.18);
  col = mix(col, fogColor, fogMask * 0.1 * k);
  
  // === COLOR GRADING ===
  col *= vec3(0.97, 0.98, 1.02);
  
  // === VIGNETTE ===
  col *= vignette(uv);
  
  fragColor = vec4(col, 1.0);
}
