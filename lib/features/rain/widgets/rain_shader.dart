import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Production-ready rain glass shader overlay
/// 
/// Key optimizations:
/// - Uses ValueNotifier instead of setState per frame
/// - Only the CustomPainter repaints, not the widget tree
/// - RepaintBoundary isolates this layer
/// - Android-safe shader (no GLSL 460)
class RainShaderOverlay extends StatefulWidget {
  final double intensity;

  const RainShaderOverlay({
    super.key,
    this.intensity = 1.0,
  });

  @override
  State<RainShaderOverlay> createState() => _RainShaderOverlayState();
}

class _RainShaderOverlayState extends State<RainShaderOverlay>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late final Ticker _ticker;

  // This drives repaints WITHOUT rebuilding widgets
  final ValueNotifier<double> _time = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _loadShader();

    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6; // seconds
    })..start();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/rain_glass.glsl');
      _shader = program.fragmentShader();
      if (mounted) setState(() {}); // ONE-TIME setState only
    } catch (e) {
      debugPrint('Failed to load rain shader: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) return const SizedBox.shrink();

    return RepaintBoundary(
      child: CustomPaint(
        painter: _RainGlassPainter(
          shader: shader,
          time: _time,
          intensity: widget.intensity,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RainGlassPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ValueListenable<double> time;
  final double intensity;

  _RainGlassPainter({
    required this.shader,
    required this.time,
    required this.intensity,
  }) : super(repaint: time); // Key: repaint driven by ValueNotifier

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform order must match GLSL declaration:
    // uniform vec2  uResolution;  -> index 0, 1
    // uniform float uTime;        -> index 2
    // uniform float uIntensity;   -> index 3
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value)
      ..setFloat(3, intensity.clamp(0.0, 1.0));

    final paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.srcOver; // overlay with alpha

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _RainGlassPainter oldDelegate) {
    // repaint is driven by `repaint: time`, so only check other props
    return oldDelegate.intensity != intensity || oldDelegate.shader != shader;
  }
}
