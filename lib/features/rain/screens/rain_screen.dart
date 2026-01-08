import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/sound_service.dart';
import '../widgets/rain_ultra.dart';
import '../widgets/rain_painter.dart';
import '../widgets/film_grain_overlay.dart';

/// Rain Screen — Ultra Realistic Experience
/// 
/// Layer order (back to front):
/// 1. Background image (via RainUltra shader)
/// 2. Bubble droplets on glass (shader refraction)
/// 3. Falling rain streaks (RainCanvas)
/// 4. Film grain + vignette
/// 
/// "Nothing is expected of me."
class RainScreen extends StatefulWidget {
  const RainScreen({super.key});

  @override
  State<RainScreen> createState() => _RainScreenState();
}

class _RainScreenState extends State<RainScreen> with WidgetsBindingObserver {
  double _intensity = 0.8;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      SoundService().stopRain();
    } else if (state == AppLifecycleState.resumed) {
      SoundService().startRain();
    }
  }

  void _onPressStart() {
    _isPressed = true;
    SoundService().rampUpIntensity();
    _updateIntensity();
  }

  void _onPressEnd() {
    _isPressed = false;
    SoundService().returnToBaseline();
    _decayIntensity();
  }

  void _updateIntensity() async {
    const steps = 30;
    const stepDuration = Duration(milliseconds: 16);

    for (int i = 0; i <= steps && _isPressed; i++) {
      await Future.delayed(stepDuration);
      if (mounted && _isPressed) {
        setState(() {
          _intensity = 0.5 + (i / steps) * 0.5;
        });
      }
    }
  }

  void _decayIntensity() async {
    const steps = 90;
    const stepDuration = Duration(milliseconds: 16);
    final startIntensity = _intensity;

    for (int i = 0; i <= steps && !_isPressed; i++) {
      await Future.delayed(stepDuration);
      if (mounted && !_isPressed) {
        final progress = i / steps;
        final easedProgress = 1.0 - (1.0 - progress) * (1.0 - progress);
        setState(() {
          _intensity = 0.5 + (startIntensity - 0.5) * (1.0 - easedProgress);
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: GestureDetector(
        onLongPressStart: (_) => _onPressStart(),
        onLongPressEnd: (_) => _onPressEnd(),
        onLongPressCancel: () => _onPressEnd(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // ============================================
              // LAYER 1: BACKGROUND + BUBBLE DROPLETS (shader)
              // ============================================
              // This is the main shader that:
              // - Shows navy gradient background
              // - Adds bubble-style water droplets ON the glass
              // - Refracts/blurs background through the drops
              Positioned.fill(
                child: RainUltra(
                  intensity: _intensity,
                ),
              ),

              // ============================================
              // LAYER 2: FALLING RAIN STREAKS (CPU rendered)
              // ============================================
              // These are the rain drops FALLING THROUGH THE AIR
              // in front of the glass - visible streaking past
              Positioned.fill(
                child: RainCanvas(
                  intensity: _intensity,
                ),
              ),

              // ============================================
              // LAYER 3: FILM GRAIN (cinematic overlay)
              // ============================================
              const Positioned.fill(
                child: FilmGrainOverlay(),
              ),

              // ============================================
              // LAYER 4: VIGNETTE (depth/focus effect)
              // ============================================
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.0,
                        colors: [
                          Colors.transparent,
                          AppColors.vignette.withAlpha(102),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
