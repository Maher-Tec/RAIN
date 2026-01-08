import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'offscreen_buffer.dart';

/// Ultra Realistic 2-Pass Rain Effect with Bubble Droplets
/// 
/// Pipeline:
/// 1. Buffer A shader renders droplets offscreen at 0.5x resolution
/// 2. Composite shader applies droplets over gradient background
/// 
/// Key features:
/// - Simple navy gradient background (no image needed)
/// - Realistic bubble-style water drops with lens refraction
/// - Smooth blur with chromatic aberration
/// - Zero widget rebuilds per frame (ValueNotifier)
class RainUltra extends StatefulWidget {
  final double intensity;

  const RainUltra({
    super.key,
    this.intensity = 0.8,
  });

  @override
  State<RainUltra> createState() => _RainUltraState();
}

class _RainUltraState extends State<RainUltra>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _progA;
  ui.FragmentProgram? _progB;
  ui.Image? _bgImage;
  OffscreenBufferA? _bufferA;
  
  Size? _lastSize;

  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _initShaders();

    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  Future<void> _initShaders() async {
    try {
      // Load shaders only
      final a = await ui.FragmentProgram.fromAsset('shaders/rain_buffer_a.glsl');
      final b = await ui.FragmentProgram.fromAsset('shaders/rain_composite.glsl');

      _bufferA = OffscreenBufferA(program: a, scale: 0.5);
      _progA = a;
      _progB = b;

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to initialize RainUltra: $e');
    }
  }
  
  /// Generate a simple navy gradient background image
  Future<void> _generateGradientBg(Size size) async {
    if (_lastSize == size && _bgImage != null) return;
    _lastSize = size;
    
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Simple navy gradient - dark at top, slightly lighter at bottom
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [
          const Color(0xFF0A0E14),  // Deep navy (top)
          const Color(0xFF0D1520),  // Slightly lighter (middle)
          const Color(0xFF111A26),  // Softer navy (bottom)
        ],
        [0.0, 0.5, 1.0],
      );
    
    canvas.drawRect(Offset.zero & size, paint);
    
    final pic = recorder.endRecording();
    final img = await pic.toImage(size.width.toInt(), size.height.toInt());
    
    _bgImage?.dispose();
    _bgImage = img;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _bufferA?.dispose();
    _bgImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_progA == null || _progB == null || _bufferA == null) {
      // Show gradient while loading
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E14),
              Color(0xFF0D1520),
              Color(0xFF111A26),
            ],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          
          // Generate gradient background if needed
          _generateGradientBg(size);
          
          return CustomPaint(
            painter: _RainUltraPainter(
              time: _time,
              bgImage: _bgImage,
              progB: _progB!,
              bufferA: _bufferA!,
              intensity: widget.intensity,
              size: size,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _RainUltraPainter extends CustomPainter {
  _RainUltraPainter({
    required this.time,
    required this.bgImage,
    required this.progB,
    required this.bufferA,
    required this.intensity,
    required this.size,
  }) : super(repaint: time);

  final ValueListenable<double> time;
  final ui.Image? bgImage;
  final ui.FragmentProgram progB;
  final OffscreenBufferA bufferA;
  final double intensity;
  final Size size;

  bool _rendering = false;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;

    // Render BufferA offscreen (avoid overlapping renders)
    if (!_rendering) {
      _rendering = true;
      bufferA
          .render(
            fullSize: ui.Size(size.width, size.height),
            time: t,
            intensity: intensity,
          )
          .whenComplete(() => _rendering = false);
    }

    final aImg = bufferA.image;
    
    // Draw gradient background while waiting for shader
    if (aImg == null || bgImage == null) {
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          [
            const Color(0xFF0A0E14),
            const Color(0xFF0D1520),
            const Color(0xFF111A26),
          ],
          [0.0, 0.5, 1.0],
        );
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    // Create the composite shader with bubble refraction
    final shader = progB.fragmentShader()
      // Floats: uResolution(0,1), uTime(2), uIntensity(3)
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, t)
      ..setFloat(3, intensity.clamp(0.0, 1.0))
      // Samplers
      ..setImageSampler(0, aImg)      // uBufferA (droplet data)
      ..setImageSampler(1, bgImage!); // uBg (gradient background)

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _RainUltraPainter oldDelegate) {
    return oldDelegate.intensity != intensity || 
           oldDelegate.bgImage != bgImage;
  }
}
