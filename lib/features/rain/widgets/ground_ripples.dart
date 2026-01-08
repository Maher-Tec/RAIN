import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_durations.dart';

/// Enhanced ripple with realistic water physics
class Ripple {
  final Offset position;
  final double startTime;
  final double maxRadius;
  final double intensity; // How strong the ripple is

  Ripple({
    required this.position,
    required this.startTime,
    required this.maxRadius,
    this.intensity = 1.0,
  });
}

/// Ground ripple effects widget with enhanced realism
/// 
/// Features:
/// - Multiple concentric rings per ripple
/// - Soft fade out with easing
/// - Realistic water surface tension simulation
/// - Variable ripple intensities
class GroundRipples extends StatefulWidget {
  final double intensity;

  const GroundRipples({
    super.key,
    this.intensity = 0.0,
  });

  @override
  State<GroundRipples> createState() => _GroundRipplesState();
}

class _GroundRipplesState extends State<GroundRipples>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Ripple> _ripples = [];
  final Random _random = Random();
  double _time = 0.0;
  double _nextSpawnTime = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_update);
    _controller.repeat();
  }

  void _update() {
    _time += 0.016;

    // Remove old ripples
    _ripples.removeWhere((ripple) => _time - ripple.startTime > 1.0);

    setState(() {});
  }

  void _spawnRipple(Size size) {
    if (_ripples.length >= VisualConfig.maxRipples) return;

    // Ripples appear in the bottom 15% of screen (water surface area)
    final yPosition = size.height * (0.88 + _random.nextDouble() * 0.12);
    
    _ripples.add(Ripple(
      position: Offset(
        20 + _random.nextDouble() * (size.width - 40),
        yPosition,
      ),
      startTime: _time,
      maxRadius: 15 + _random.nextDouble() * 20,
      intensity: 0.6 + _random.nextDouble() * 0.4,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // Spawn logic with intensity-based rate
        if (_time >= _nextSpawnTime && _ripples.length < VisualConfig.maxRipples) {
          _spawnRipple(size);
          // Faster spawning with higher intensity
          final baseInterval = 0.5 - widget.intensity * 0.15;
          _nextSpawnTime = _time + baseInterval + _random.nextDouble() * 0.4;
        }

        return CustomPaint(
          size: size,
          painter: RipplePainter(
            ripples: _ripples,
            currentTime: _time,
          ),
        );
      },
    );
  }
}

class RipplePainter extends CustomPainter {
  final List<Ripple> ripples;
  final double currentTime;

  RipplePainter({
    required this.ripples,
    required this.currentTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ripple in ripples) {
      _drawRipple(canvas, ripple);
    }
  }

  void _drawRipple(Canvas canvas, Ripple ripple) {
    final age = currentTime - ripple.startTime;
    final totalDuration = 1.0;
    final progress = (age / totalDuration).clamp(0.0, 1.0);
    
    // Multiple concentric rings for realistic water effect
    final rings = 3;
    for (int i = 0; i < rings; i++) {
      final ringDelay = i * 0.15; // Stagger ring appearances
      final ringProgress = ((progress - ringDelay) / (1.0 - ringDelay)).clamp(0.0, 1.0);
      
      if (ringProgress > 0) {
        final ringEased = 1.0 - pow(1.0 - ringProgress, 2.5);
        final radius = ripple.maxRadius * ringEased * (1.0 - i * 0.25);
        
        // Opacity fades faster for outer rings
        final baseOpacity = (1.0 - ringProgress) * 0.25 * ripple.intensity;
        final ringOpacity = baseOpacity * (1.0 - i * 0.3);
        
        if (ringOpacity > 0.01 && radius > 1) {
          final alpha = (ringOpacity * 255).round().clamp(0, 255);
          
          // Main ring
          final paint = Paint()
            ..color = AppColors.ripple.withAlpha(alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 - i * 0.3;

          canvas.drawCircle(ripple.position, radius, paint);
          
          // Subtle inner glow for first ring
          if (i == 0 && alpha > 30) {
            final glowPaint = Paint()
              ..color = AppColors.ripple.withAlpha((alpha * 0.3).round())
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
            canvas.drawCircle(ripple.position, radius, glowPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) => true;
}
