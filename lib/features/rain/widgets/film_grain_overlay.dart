import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_durations.dart';

/// A subtle static grain texture, cached by a repaint boundary.
/// Animated rain already gives the scene motion; animating thousands of grain
/// dots adds raster work without materially changing the appearance.
class FilmGrainOverlay extends StatelessWidget {
  const FilmGrainOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: GrainPainter(opacity: VisualConfig.grainOpacity),
        ),
      ),
    );
  }
}

class GrainPainter extends CustomPainter {
  GrainPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(3741);
    final paint = Paint();
    final dotCount = (size.width * size.height / 1800).round();

    for (var i = 0; i < dotCount; i++) {
      paint.color = Color.fromRGBO(255, 255, 255, random.nextDouble() * opacity);
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        0.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GrainPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
