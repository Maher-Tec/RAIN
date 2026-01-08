/// RAIN Animation & Transition Timing
/// 
/// All durations calibrated for nervous system regulation.
/// Slow, predictable, safe.
class AppDurations {
  AppDurations._();

  // Entry screen
  static const Duration entryFade = Duration(milliseconds: 1800);
  static const Duration textDelay = Duration(milliseconds: 800);
  static const Duration textFade = Duration(milliseconds: 1000);
  
  // Sound
  static const Duration soundFadeIn = Duration(milliseconds: 2000);
  static const Duration soundFadeOut = Duration(milliseconds: 300);
  
  // Intensity interaction
  static const Duration intensityRampUp = Duration(milliseconds: 500);
  static const Duration intensityReturn = Duration(milliseconds: 1500);
  
  // App lifecycle
  static const Duration exitFade = Duration(milliseconds: 300);
  
  // Animation frame rate
  static const Duration animationTick = Duration(milliseconds: 16); // ~60fps
}

/// RAIN Audio Configuration
/// 
/// Refined per user feedback:
/// - Playback rate max 1.02 (not 1.05)
/// - Volume baseline 0.55-0.65
/// - Peak should feel "closer", not "loud"
class AudioConfig {
  AudioConfig._();
  
  // Volume range
  static const double volumeBaseline = 0.60;
  static const double volumePeak = 0.85;
  
  // Playback rate (subtle, nearly imperceptible)
  static const double rateBaseline = 1.0;
  static const double ratePeak = 1.02;
}

/// RAIN Visual Configuration
class VisualConfig {
  VisualConfig._();
  
  // Rain layers
  static const int backgroundDropCount = 80;
  static const int midgroundDropCount = 50;
  static const int foregroundDropCount = 25;
  
  // Ground ripples (capped per user feedback: 8-10, not 15)
  static const int maxRipples = 8;
  
  // Film grain
  static const double grainOpacity = 0.03;
}
