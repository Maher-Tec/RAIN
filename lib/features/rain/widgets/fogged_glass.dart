import 'dart:math';
import 'package:flutter/material.dart';

/// A finger-cleared path through condensation on the inside of the glass.
class FogWipeTrace {
  final List<Offset> points;
  final DateTime createdAt;

  const FogWipeTrace({required this.points, required this.createdAt});
}

/// Condensation slowly gathers on the inside of the window. Pointer strokes
/// clear the fog, while the outside rain layer remains visible above it.
/// When rain intensity increases (e.g. holding the screen), condensation forms
/// and re-fogs cleared areas much faster.
class FoggedGlass extends StatefulWidget {
  final DateTime startedAt;
  final List<FogWipeTrace> wipes;
  final List<Offset> activeWipe;
  final double intensity;

  const FoggedGlass({
    super.key,
    required this.startedAt,
    required this.wipes,
    required this.activeWipe,
    this.intensity = 0.5,
  });

  @override
  State<FoggedGlass> createState() => _FoggedGlassState();
}

class _FoggedGlassState extends State<FoggedGlass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _repaint;

  @override
  void initState() {
    super.initState();
    _repaint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat();
  }

  @override
  void dispose() {
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _FogPainter(
            repaint: _repaint,
            startedAt: widget.startedAt,
            wipes: widget.wipes,
            activeWipe: widget.activeWipe,
            intensity: widget.intensity,
          ),
        ),
      ),
    );
  }
}

class _FogPainter extends CustomPainter {
  _FogPainter({
    required Listenable repaint,
    required this.startedAt,
    required this.wipes,
    required this.activeWipe,
    required this.intensity,
  }) : super(repaint: repaint);

  final DateTime startedAt;
  final List<FogWipeTrace> wipes;
  final List<Offset> activeWipe;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds / 1000;

    // Condensation forms faster with higher rain intensity
    final warmupRate = 8.0 / (0.5 + intensity);
    final fogAmount = ((elapsed - 1.0) / warmupRate).clamp(0.0, 1.0).toDouble();
    if (fogAmount <= 0.001) return;

    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());

    final fogPaint = Paint()..shader = _fogShader(size, fogAmount);
    canvas.drawRect(bounds, fogPaint);

    // Fine, stationary mist specks
    final random = Random(3917);
    final speckCount = (size.width * size.height / 2000).round();
    final speckPaint = Paint();
    for (var i = 0; i < speckCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.35 + random.nextDouble() * 1.15;
      final alpha = (fogAmount * (4 + random.nextInt(12))).round();
      speckPaint.color =
          (random.nextBool() ? Colors.white : const Color(0xFF26343B))
              .withAlpha(alpha.clamp(0, 26).toInt());
      canvas.drawCircle(Offset(x, y), radius, speckPaint);
    }

    final now = DateTime.now();
    // Re-fog duration: baseline ~22s, accelerates down to ~6-7s during heavy rain hold
    final refogDuration = 22.0 / (0.6 + intensity * 1.8);

    for (final wipe in wipes) {
      final age = now.difference(wipe.createdAt).inMilliseconds / 1000;
      final strength =
          (1.0 - age / refogDuration).clamp(0.0, 1.0).toDouble() * fogAmount;
      if (strength > 0.01) {
        _eraseStroke(canvas, wipe.points, strength);
      }
    }
    _eraseStroke(canvas, activeWipe, 1.0);

    canvas.restore();
  }

  Shader _fogShader(Size size, double amount) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.fromARGB((amount * 175).round(), 145, 160, 168),
        Color.fromARGB((amount * 165).round(), 155, 170, 175),
        Color.fromARGB((amount * 170).round(), 130, 145, 150),
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Offset.zero & size);
  }

  void _eraseStroke(Canvas canvas, List<Offset> points, double strength) {
    if (points.isEmpty || strength <= 0) return;

    // Smooth feathering that shrinks as the condensation recovers from the edges
    final strokeWidth = 44.0 * sqrt(strength);
    final blurRadius = max(3.0, 7.0 * (1.0 - strength * 0.5));

    final erase = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Colors.white.withAlpha((strength * 255).round())
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

    if (points.length == 1) {
      canvas.drawCircle(
        points.single,
        strokeWidth * 0.5,
        erase..style = PaintingStyle.fill,
      );
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, erase);
  }

  @override
  bool shouldRepaint(covariant _FogPainter oldDelegate) =>
      oldDelegate.startedAt != startedAt ||
      oldDelegate.wipes != wipes ||
      oldDelegate.activeWipe != activeWipe ||
      oldDelegate.intensity != intensity;
}
