import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/sound_service.dart';
import '../widgets/rain_ultra.dart';
import '../widgets/rain_painter.dart';
import '../widgets/film_grain_overlay.dart';
import '../widgets/fogged_glass.dart';

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
  final GlobalKey<RainCanvasState> _rainCanvasKey =
      GlobalKey<RainCanvasState>();
  double _intensity = 0.8;
  bool _isPressed = false;
  bool _isDragging = false;
  bool _showWipeHint = false;
  Offset? _pointerPosition;
  final DateTime _startedAt = DateTime.now();
  final List<FogWipeTrace> _wipeTraces = [];
  List<Offset> _activeWipe = [];
  Timer? _wipeHintTimer;

  void _updatePointer(Offset localPosition) {
    if (!_isDragging) return;
    setState(() {
      _pointerPosition = localPosition;
      if (_activeWipe.isEmpty ||
          (_activeWipe.last - localPosition).distance >= 3.0) {
        _activeWipe.add(localPosition);
      }
      _showWipeHint = false;
    });
    _rainCanvasKey.currentState?.setTouchPosition(localPosition);
  }

  void _beginWipe(Offset localPosition) {
    _isDragging = true;
    _activeWipe = [localPosition];
    _updatePointer(localPosition);
  }

  void _clearPointer() {
    _isDragging = false;
    final now = DateTime.now();
    if (_activeWipe.isNotEmpty) {
      _wipeTraces.add(
        FogWipeTrace(points: List.of(_activeWipe), createdAt: now),
      );
      _wipeTraces.removeWhere(
        (trace) => now.difference(trace.createdAt).inSeconds > 55,
      );
      if (_wipeTraces.length > 80) _wipeTraces.removeAt(0);
    }
    setState(() {
      _pointerPosition = null;
      _activeWipe = [];
    });
    _rainCanvasKey.currentState?.setTouchPosition(null);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _wipeHintTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && _wipeTraces.isEmpty && _activeWipe.isEmpty) {
        setState(() => _showWipeHint = true);
      }
    });
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
    _wipeHintTimer?.cancel();
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
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          _beginWipe(event.localPosition);
        },
        onPointerMove: (event) => _updatePointer(event.localPosition),
        onPointerUp: (_) => _clearPointer(),
        onPointerCancel: (_) => _clearPointer(),
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
                    touchPosition: _pointerPosition,
                  ),
                ),

                // Condensation gathers on the inside of the pane. Dragging
                // clears it, while the outside rain remains visible above it.
                Positioned.fill(
                  child: FoggedGlass(
                    startedAt: _startedAt,
                    wipes: _wipeTraces,
                    activeWipe: _activeWipe,
                    intensity: _intensity,
                  ),
                ),

                // ============================================
                // LAYER 2: FALLING RAIN STREAKS (CPU rendered)
                // ============================================
                // These are the rain drops FALLING THROUGH THE AIR
                // in front of the glass - visible streaking past
                Positioned.fill(
                  child: RainCanvas(key: _rainCanvasKey, intensity: _intensity),
                ),

                // ============================================
                // LAYER 3: FILM GRAIN (cinematic overlay)
                // ============================================
                const Positioned.fill(child: FilmGrainOverlay()),

                if (_showWipeHint)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 44,
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          'Drag to clear the glass',
                          style: TextStyle(
                            color: Colors.white.withAlpha(150),
                            fontSize: 13,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w300,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
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
      ),
    );
  }
}
