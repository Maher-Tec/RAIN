import 'dart:ui';

/// RAIN Color Palette
/// 
/// Deep navy, soft charcoal, muted blue-gray.
/// No bright accents. Timeless.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0A0E14);
  static const Color backgroundLight = Color(0xFF151A21);
  
  // Vignette
  static const Color vignette = Color(0xFF000000);
  
  // Rain drops - varying depths
  static const Color rainForeground = Color(0xCCB8C5D6);  // 80% opacity
  static const Color rainMidground = Color(0x80A0B0C4);   // 50% opacity
  static const Color rainBackground = Color(0x4D8899AA);  // 30% opacity
  
  // Ripples
  static const Color ripple = Color(0x40C8D4E0);          // 25% opacity
  
  // Text (first launch only)
  static const Color whisper = Color(0x99FFFFFF);         // 60% opacity
}
