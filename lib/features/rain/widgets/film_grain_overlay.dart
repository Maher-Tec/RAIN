import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_durations.dart';

/// Film grain overlay
/// 
/// Very subtle noise texture for premium feel.
/// Opacity: 0.03 (if anyone notices it, remove it)
/// 
/// Rule: Grain is for FELT texture, not SEEN texture.
class FilmGrainOverlay extends StatefulWidget {
  const FilmGrainOverlay({super.key});

  @override
  State<FilmGrainOverlay> createState() => _FilmGrainOverlayState();
}

class _FilmGrainOverlayState extends State<FilmGrainOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  int _seed = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(() {
        // Change grain pattern occasionally
        if (_random.nextDouble() > 0.7) {
          _seed = _random.nextInt(10000);
          setState(() {});
        }
      });
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: GrainPainter(
          seed: _seed,
          opacity: VisualConfig.grainOpacity,
        ),
      ),
    );
  }
}

class GrainPainter extends CustomPainter {
  final int seed;
  final double opacity;

  GrainPainter({
    required this.seed,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final paint = Paint();
    
    // Draw sparse noise dots
    final dotCount = (size.width * size.height / 400).round();
    
    for (int i = 0; i < dotCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final brightness = random.nextDouble();
      
      paint.color = Color.fromRGBO(
        255,
        255,
        255,
        brightness * opacity,
      );
      
      canvas.drawCircle(
        Offset(x, y),
        0.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GrainPainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}
