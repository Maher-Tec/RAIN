import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Ultra-Realistic Rain Effect with Full Native Resolution Glass Optics
///
/// Features:
/// - 100% native display resolution (zero pixelation or buffer scaling)
/// - Single-pass GPU fragment shader with multi-scale water beads & rivulets
/// - Frosted background bokeh blur with sharp convex lens droplet refraction
/// - High-performance ticker driven via ValueNotifier (zero widget rebuilds)
class RainUltra extends StatefulWidget {
  final double intensity;
  final Offset? touchPosition;

  const RainUltra({super.key, this.intensity = 0.8, this.touchPosition});

  @override
  State<RainUltra> createState() => _RainUltraState();
}

class _RainUltraState extends State<RainUltra>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  ui.Image? _bgImage;

  Size? _lastSize;
  bool _loadingAsset = false;

  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0.0);
  double _lastShaderFrame = 0;

  @override
  void initState() {
    super.initState();
    _initShader();

    _ticker = createTicker((elapsed) {
      final seconds = elapsed.inMicroseconds / 1e6;
      // Keep the refraction shader at 30 fps; the falling rain painter
      // continues at display refresh independently.
      if (seconds - _lastShaderFrame >= 1 / 30) {
        _lastShaderFrame = seconds;
        _time.value = seconds;
      }
    })..start();
  }

  Future<void> _initShader() async {
    try {
      final prog = await ui.FragmentProgram.fromAsset(
        'shaders/rain_composite.glsl',
      );
      _program = prog;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to initialize RainUltra shader: $e');
    }
  }

  /// Load background asset or generate rich cinematic night background
  Future<void> _ensureBackground(Size size) async {
    if (_lastSize == size && _bgImage != null) return;
    _lastSize = size;

    if (!_loadingAsset) {
      _loadingAsset = true;
      try {
        final byteData = await rootBundle.load('assets/images/bg_calm.png');
        final codec = await ui.instantiateImageCodec(
          byteData.buffer.asUint8List(),
          targetWidth: size.width.round(),
          targetHeight: size.height.round(),
        );
        final frameInfo = await codec.getNextFrame();
        _bgImage?.dispose();
        _bgImage = frameInfo.image;
        if (mounted) setState(() {});
        return;
      } catch (e) {
        debugPrint('Falling back to procedural background: $e');
      } finally {
        _loadingAsset = false;
      }
    }

    // Procedural fallback background with rich depth & bokeh street lights
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
    );

    final random = math.Random(20260928);
    final horizon = size.height * 0.65;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        [
          const Color(0xFF060911),
          const Color(0xFF0F1522),
          const Color(0xFF24222E),
          const Color(0xFF151419),
          const Color(0xFF040508),
        ],
        [0.0, 0.35, 0.58, 0.70, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint);

    // Atmospheric cloud glow
    final haze = Paint()
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 36)
      ..blendMode = BlendMode.screen;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, horizon * 0.76),
        width: size.width * 1.2,
        height: size.height * 0.22,
      ),
      haze..color = const Color(0x403E485C),
    );

    // City skyline silhouettes
    var x = -size.width * 0.05;
    while (x < size.width * 1.05) {
      final buildingWidth = size.width * (0.08 + random.nextDouble() * 0.12);
      final buildingHeight = size.height * (0.08 + random.nextDouble() * 0.18);
      final top = horizon - buildingHeight;
      final building = Rect.fromLTWH(x, top, buildingWidth, size.height - top);
      canvas.drawRect(
        building,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, top),
            Offset(0, size.height),
            const [Color(0xFF0F121A), Color(0xFF06080C)],
          ),
      );

      // Window lights
      final rows = (buildingHeight / 18).floor().clamp(1, 14).toInt();
      final cols = (buildingWidth / 12).floor().clamp(1, 10).toInt();
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < cols; col++) {
          if (random.nextDouble() > 0.38) continue;
          final lightColor = random.nextDouble() > 0.55
              ? const Color(0x55C49563)
              : const Color(0x429EAFC0);
          canvas.drawRect(
            Rect.fromLTWH(x + 4 + col * 12, top + 6 + row * 18, 2.5, 4.5),
            Paint()..color = lightColor,
          );
        }
      }
      x += buildingWidth * (0.75 + random.nextDouble() * 0.32);
    }

    // Wet pavement reflections
    final roadTop = size.height * 0.72;
    canvas.drawRect(
      Rect.fromLTWH(0, roadTop, size.width, size.height - roadTop),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, roadTop),
          Offset(0, size.height),
          const [Color(0xFF1D181F), Color(0xFF06070B)],
        ),
    );

    // Soft bokeh streetlight pools
    for (final lampX in [
      size.width * 0.22,
      size.width * 0.48,
      size.width * 0.78,
    ]) {
      final reflection = Paint()
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = size.width * 0.025;
      canvas.drawLine(
        Offset(lampX, horizon + 5),
        Offset(lampX + (random.nextDouble() - 0.5) * 32, size.height),
        reflection..color = const Color(0x42C29367),
      );
    }

    // Out-of-focus bokeh light orbs
    for (var i = 0; i < 12; i++) {
      final lightX = random.nextDouble() * size.width;
      final lightY = horizon + (random.nextDouble() - 0.2) * size.height * 0.12;
      final radius = 2.0 + random.nextDouble() * 4.5;
      canvas.drawCircle(
        Offset(lightX, lightY),
        radius * 3.5,
        Paint()
          ..color = const Color(0x4082A2BF)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 9),
      );
      canvas.drawCircle(
        Offset(lightX, lightY),
        radius * 1.5,
        Paint()
          ..color = const Color(0xB5DEC096)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
      );
    }
    canvas.restore();

    final pic = recorder.endRecording();
    final img = await pic.toImage(size.width.round(), size.height.round());

    _bgImage?.dispose();
    _bgImage = img;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _bgImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF060911), Color(0xFF24222E), Color(0xFF040508)],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _ensureBackground(size);

          return CustomPaint(
            painter: _RainUltraPainter(
              time: _time,
              bgImage: _bgImage,
              program: _program!,
              intensity: widget.intensity,
              touchPosition: widget.touchPosition,
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
    required this.program,
    required this.intensity,
    required this.touchPosition,
    required this.size,
  }) : super(repaint: time);

  final ValueListenable<double> time;
  final ui.Image? bgImage;
  final ui.FragmentProgram program;
  final double intensity;
  final Offset? touchPosition;
  final Size size;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final bg = bgImage;

    if (bg == null) {
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [
            const Color(0xFF060911),
            const Color(0xFF0F1522),
            const Color(0xFF24222E),
            const Color(0xFF040508),
          ],
          [0.0, 0.35, 0.58, 1.0],
        );
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    // Set uniforms directly for 100% native resolution execution on GPU
    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, t)
      ..setFloat(3, intensity.clamp(0.0, 1.0).toDouble())
      ..setFloat(4, touchPosition?.dx ?? -1.0)
      ..setFloat(5, touchPosition?.dy ?? -1.0)
      ..setImageSampler(0, bg);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _RainUltraPainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
        oldDelegate.touchPosition != touchPosition ||
        oldDelegate.bgImage != bgImage;
  }
}
