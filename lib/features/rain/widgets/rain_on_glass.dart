import 'dart:math';
import 'package:flutter/material.dart';

/// A water droplet on glass - ultra realistic
class GlassDroplet {
  double x;
  double y;
  double radius;
  bool isSliding;
  double mass;
  List<Offset> trail;
  final double wobblePhase;
  double stickTime;
  double slideSpeed;
  final double irregularity; // Slight shape variation

  GlassDroplet({
    required this.x,
    required this.y,
    required this.radius,
    this.isSliding = false,
    double? mass,
    List<Offset>? trail,
    required this.wobblePhase,
    this.stickTime = 0,
    this.slideSpeed = 0,
    required this.irregularity,
  }) : mass = mass ?? (pi * radius * radius),
       trail = trail ?? [];
}

/// Ultra Realistic Rain on Glass Effect
/// 
/// Real water droplets are:
/// - Very transparent (you see through them)
/// - Soft, blurred edges (not sharp circles)
/// - Subtle refraction (slight distortion)
/// - Irregular shapes (not perfect circles)
/// - Tiny pinpoint highlights
class RainOnGlass extends StatefulWidget {
  final double intensity;

  const RainOnGlass({
    super.key,
    this.intensity = 0.0,
  });

  @override
  State<RainOnGlass> createState() => _RainOnGlassState();
}

class _RainOnGlassState extends State<RainOnGlass>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<GlassDroplet> _droplets = [];
  final Random _random = Random();
  Size _size = Size.zero;
  double _time = 0.0;
  double _nextSpawnTime = 0.0;

  static const int maxDroplets = 100;
  static const double minRadius = 1.0;
  static const double maxRadius = 6.0; // Smaller for realism
  static const double slideThreshold = 50.0;
  static const double maxSlideSpeed = 0.6;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_updateFrame);
  }

  void _initializeDroplets(Size size) {
    if (_size == size) return;
    _size = size;
    _droplets.clear();

    for (int i = 0; i < 50; i++) {
      _droplets.add(_createDroplet(isInitial: true));
    }

    _controller.repeat();
  }

  GlassDroplet _createDroplet({bool isInitial = false}) {
    final sizeRandom = _random.nextDouble();
    // Power curve for more small droplets
    final radius = minRadius + (maxRadius - minRadius) * pow(sizeRandom, 3.5);
    
    return GlassDroplet(
      x: 8 + _random.nextDouble() * (_size.width - 16),
      y: isInitial 
          ? 15 + _random.nextDouble() * (_size.height - 30)
          : 5 + _random.nextDouble() * _size.height * 0.25,
      radius: radius,
      isSliding: false,
      wobblePhase: _random.nextDouble() * pi * 2,
      stickTime: isInitial ? _random.nextDouble() * 4.0 : 0,
      slideSpeed: 0,
      irregularity: 0.85 + _random.nextDouble() * 0.3, // 0.85 to 1.15
    );
  }

  void _updateFrame() {
    if (_size == Size.zero) return;
    _time += 0.016;

    if (_time >= _nextSpawnTime && _droplets.length < maxDroplets) {
      _droplets.add(_createDroplet());
      final baseInterval = 0.5 - widget.intensity * 0.2;
      _nextSpawnTime = _time + baseInterval + _random.nextDouble() * 0.4;
    }

    _updateDroplets();
    _handleMerging();
    _droplets.removeWhere((d) => d.y > _size.height + 15);

    setState(() {});
  }

  void _updateDroplets() {
    for (final d in _droplets) {
      d.stickTime += 0.016;
      
      if (d.isSliding) {
        d.slideSpeed += 0.001;
        d.slideSpeed = d.slideSpeed.clamp(0, maxSlideSpeed);
        
        if (_random.nextDouble() < 0.008) {
          d.slideSpeed *= 0.2;
        }
        
        d.x += sin(_time * 0.3 + d.wobblePhase) * 0.08;
        d.x = d.x.clamp(d.radius, _size.width - d.radius);
        d.y += d.slideSpeed;
        
        if (d.slideSpeed > 0.05) {
          d.trail.add(Offset(d.x, d.y));
          if (d.trail.length > 100) d.trail.removeAt(0);
        }
      } else {
        if (_random.nextDouble() < 0.002 * (1 + widget.intensity)) {
          d.mass += _random.nextDouble() * 2;
          d.radius = sqrt(d.mass / pi).clamp(minRadius, maxRadius * 1.5);
        }
        
        if (d.mass > slideThreshold && d.stickTime > 2.5) {
          if (_random.nextDouble() < 0.002) {
            d.isSliding = true;
            d.slideSpeed = 0.05;
          }
        }
      }
    }
  }

  void _handleMerging() {
    final toRemove = <GlassDroplet>[];
    
    for (int i = 0; i < _droplets.length; i++) {
      if (toRemove.contains(_droplets[i])) continue;
      
      for (int j = i + 1; j < _droplets.length; j++) {
        if (toRemove.contains(_droplets[j])) continue;
        
        final d1 = _droplets[i];
        final d2 = _droplets[j];
        
        final dist = sqrt(pow(d1.x - d2.x, 2) + pow(d1.y - d2.y, 2));
        
        if (dist < (d1.radius + d2.radius) * 0.7) {
          final larger = d1.mass >= d2.mass ? d1 : d2;
          final smaller = d1.mass >= d2.mass ? d2 : d1;
          
          larger.mass += smaller.mass * 0.6;
          larger.radius = sqrt(larger.mass / pi).clamp(minRadius, maxRadius * 1.8);
          
          if (smaller.isSliding) {
            larger.isSliding = true;
            larger.slideSpeed = max(larger.slideSpeed, smaller.slideSpeed);
          }
          
          larger.trail.addAll(smaller.trail);
          toRemove.add(smaller);
        }
      }
    }
    
    for (final d in toRemove) {
      _droplets.remove(d);
    }
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
        _initializeDroplets(size);

        return CustomPaint(
          size: size,
          painter: RealisticDropletPainter(droplets: _droplets, time: _time),
        );
      },
    );
  }
}

/// Ultra-realistic droplet renderer
class RealisticDropletPainter extends CustomPainter {
  final List<GlassDroplet> droplets;
  final double time;

  RealisticDropletPainter({required this.droplets, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw trails
    for (final d in droplets) {
      if (d.trail.length > 1 && d.isSliding) {
        _drawTrail(canvas, d);
      }
    }

    // Draw droplets
    for (final d in droplets) {
      _drawRealisticDroplet(canvas, d);
    }
  }

  void _drawTrail(Canvas canvas, GlassDroplet d) {
    if (d.trail.length < 2) return;
    
    for (int i = 1; i < d.trail.length; i++) {
      final progress = i / d.trail.length;
      final width = d.radius * 0.3 * progress;
      // Very subtle trail
      final alpha = (0.06 * progress * 255).round().clamp(0, 255);
      
      final paint = Paint()
        ..color = Color.fromRGBO(200, 210, 220, alpha / 255)
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(d.trail[i - 1], d.trail[i], paint);
    }
  }

  void _drawRealisticDroplet(Canvas canvas, GlassDroplet d) {
    final center = Offset(d.x, d.y);
    final r = d.radius;
    
    // Apply irregularity - slightly oval
    final rx = r * d.irregularity;
    final ry = r * (2 - d.irregularity);
    
    // 1. REFRACTION LAYER - subtle dark ring (light bending at edge)
    final refractionPaint = Paint()
      ..color = const Color(0x08000000) // Very subtle dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.2
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.8, height: ry * 1.8),
      refractionPaint,
    );
    
    // 2. BODY - extremely transparent, barely visible
    final bodyPaint = Paint()
      ..color = const Color(0x0AFFFFFF) // 4% opacity white
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      bodyPaint,
    );
    
    // 3. EDGE SHADOW - very soft bottom shadow
    final shadowCenter = Offset(center.dx, center.dy + r * 0.15);
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x00000000),
          const Color(0x0C000000), // 5% black at edge
        ],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCircle(center: shadowCenter, radius: r));
    canvas.drawOval(
      Rect.fromCenter(center: shadowCenter, width: rx * 2, height: ry * 2),
      shadowPaint,
    );
    
    // 4. EDGE HIGHLIGHT - thin bright edge (surface tension)
    final edgePaint = Paint()
      ..color = const Color(0x12FFFFFF) // 7% white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.85, height: ry * 1.85),
      edgePaint,
    );
    
    // 5. PRIMARY HIGHLIGHT - tiny bright spot (light reflection)
    if (r > 2) {
      final hlOffset = Offset(center.dx - r * 0.28, center.dy - r * 0.28);
      final hlRadius = r * 0.18;
      
      final hlPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x40FFFFFF), // 25% center
            const Color(0x00FFFFFF),
          ],
        ).createShader(Rect.fromCircle(center: hlOffset, radius: hlRadius));
      canvas.drawCircle(hlOffset, hlRadius, hlPaint);
    }
    
    // 6. SECONDARY MICRO HIGHLIGHT - pinpoint sparkle
    if (r > 3.5) {
      final sparkleOffset = Offset(center.dx - r * 0.35, center.dy - r * 0.4);
      final sparklePaint = Paint()
        ..color = const Color(0x30FFFFFF) // Small bright dot
        ..style = PaintingStyle.fill;
      canvas.drawCircle(sparkleOffset, 0.6, sparklePaint);
    }
    
    // 7. SUBTLE INNER GRADIENT - depth illusion
    final innerGradient = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          const Color(0x08FFFFFF),
          const Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.7],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.8, height: ry * 1.8),
      innerGradient,
    );
  }

  @override
  bool shouldRepaint(covariant RealisticDropletPainter oldDelegate) => true;
}
