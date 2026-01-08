import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_durations.dart';

/// Enhanced raindrop with realistic physics
class Raindrop {
  double x;
  double y;
  double speed;
  double length;
  double angle;
  double opacity;
  final int layer;
  final double thickness;
  final double wobble;
  double flickerPhase;

  Raindrop({
    required this.x,
    required this.y,
    required this.speed,
    required this.length,
    required this.angle,
    required this.opacity,
    required this.layer,
    required this.thickness,
    required this.wobble,
    this.flickerPhase = 0.0,
  });
}

/// Splash particle for ground impact
class SplashParticle {
  double x;
  double y;
  double velocityX;
  double velocityY;
  double life;
  final double maxLife;
  final double size;

  SplashParticle({
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    required this.maxLife,
    required this.size,
  }) : life = 1.0;
}

/// Impact ripple - spawns WHERE the raindrop hits
class ImpactRipple {
  final double x; // Exact X where drop hit
  final double y; // Ground level Y
  final double startTime;
  final double maxRadius;
  final double intensity;

  ImpactRipple({
    required this.x,
    required this.y,
    required this.startTime,
    required this.maxRadius,
    this.intensity = 1.0,
  });
}

/// Enhanced rain painter with integrated impact ripples
class RainPainter extends CustomPainter {
  final List<Raindrop> drops;
  final List<SplashParticle> splashes;
  final List<ImpactRipple> ripples;
  final double intensity;
  final double windOffset;
  final double time;

  RainPainter({
    required this.drops,
    required this.splashes,
    required this.ripples,
    this.intensity = 0.0,
    this.windOffset = 0.0,
    this.time = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw ripples first (on the "water surface")
    for (final ripple in ripples) {
      _drawRipple(canvas, ripple);
    }
    
    // Draw rain drops
    for (final drop in drops) {
      _drawDrop(canvas, drop);
    }

    // Draw splash particles
    for (final splash in splashes) {
      _drawSplash(canvas, splash);
    }
  }

  void _drawRipple(Canvas canvas, ImpactRipple ripple) {
    final age = time - ripple.startTime;
    final totalDuration = 0.8;
    final progress = (age / totalDuration).clamp(0.0, 1.0);
    
    if (progress >= 1.0) return;
    
    // Perspective: ripples on ground viewed at angle
    // Squish vertical to ~30% to simulate looking at ground surface
    const perspectiveRatio = 0.25;
    
    for (int ring = 0; ring < 3; ring++) {
      final ringDelay = ring * 0.12;
      final ringProgress = ((progress - ringDelay) / (1.0 - ringDelay)).clamp(0.0, 1.0);
      
      if (ringProgress > 0) {
        final eased = 1.0 - pow(1.0 - ringProgress, 2.5);
        final radius = ripple.maxRadius * eased * (1.0 - ring * 0.2);
        
        final baseOpacity = (1.0 - ringProgress) * 0.3 * ripple.intensity;
        final ringOpacity = baseOpacity * (1.0 - ring * 0.25);
        
        if (ringOpacity > 0.01 && radius > 1) {
          final alpha = (ringOpacity * 255).round().clamp(0, 255);
          
          final paint = Paint()
            ..color = AppColors.ripple.withAlpha(alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0 - ring * 0.2;

          // Use ellipse for perspective (ground viewed at angle)
          final rect = Rect.fromCenter(
            center: Offset(ripple.x, ripple.y),
            width: radius * 2,
            height: radius * 2 * perspectiveRatio, // Squished for perspective
          );
          canvas.drawOval(rect, paint);
          
          // Subtle glow on first ring
          if (ring == 0 && alpha > 40) {
            final glowPaint = Paint()
              ..color = AppColors.ripple.withAlpha((alpha * 0.25).round())
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
            canvas.drawOval(rect, glowPaint);
          }
        }
      }
    }
  }

  void _drawDrop(Canvas canvas, Raindrop drop) {
    final baseColor = _getColorForLayer(drop.layer);
    
    double flickerMultiplier = 1.0;
    if (drop.layer == 2) {
      flickerMultiplier = 0.9 + 0.1 * sin(drop.flickerPhase);
    }
    
    final adjustedOpacity = (drop.opacity * (1.0 + intensity * 0.2) * flickerMultiplier).clamp(0.0, 1.0);
    final alpha = (adjustedOpacity * 255).round().clamp(0, 255);
    
    final startPoint = Offset(drop.x, drop.y);
    final dx = drop.length * sin(drop.angle);
    final dy = drop.length * cos(drop.angle);
    final endPoint = Offset(drop.x + dx, drop.y + dy);
    
    final paint = Paint()
      ..color = baseColor.withAlpha(alpha)
      ..strokeWidth = drop.thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(startPoint, endPoint, paint);
    
    // Glow for foreground drops
    if (drop.layer == 2 && alpha > 100) {
      final glowPaint = Paint()
        ..color = baseColor.withAlpha((alpha * 0.2).round().clamp(0, 255))
        ..strokeWidth = drop.thickness * 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawLine(startPoint, endPoint, glowPaint);
    }
  }

  void _drawSplash(Canvas canvas, SplashParticle splash) {
    final alpha = (splash.life * 180).round().clamp(0, 255);
    final paint = Paint()
      ..color = AppColors.rainForeground.withAlpha(alpha)
      ..style = PaintingStyle.fill;
    
    final size = splash.size * splash.life;
    canvas.drawCircle(Offset(splash.x, splash.y), size, paint);
  }

  Color _getColorForLayer(int layer) {
    switch (layer) {
      case 0:
        return AppColors.rainBackground;
      case 1:
        return AppColors.rainMidground;
      case 2:
        return AppColors.rainForeground;
      default:
        return AppColors.rainMidground;
    }
  }

  @override
  bool shouldRepaint(covariant RainPainter oldDelegate) => true;
}

/// Enhanced rain canvas with integrated ripples at impact points
class RainCanvas extends StatefulWidget {
  final double intensity;

  const RainCanvas({
    super.key,
    this.intensity = 0.0,
  });

  @override
  State<RainCanvas> createState() => _RainCanvasState();
}

class _RainCanvasState extends State<RainCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Raindrop> _drops = [];
  final List<SplashParticle> _splashes = [];
  final List<ImpactRipple> _ripples = []; // Ripples at impact points
  final Random _random = Random();
  Size _size = Size.zero;
  
  double _windPhase = 0.0;
  double _windOffset = 0.0;
  double _targetWindOffset = 0.0;
  double _time = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_updateFrame);
  }

  void _initializeDrops(Size size) {
    if (_size == size) return;
    _size = size;
    _drops.clear();
    _splashes.clear();
    _ripples.clear();

    for (int i = 0; i < VisualConfig.backgroundDropCount; i++) {
      _drops.add(_createDrop(size, 0));
    }

    for (int i = 0; i < VisualConfig.midgroundDropCount; i++) {
      _drops.add(_createDrop(size, 1));
    }

    for (int i = 0; i < VisualConfig.foregroundDropCount; i++) {
      _drops.add(_createDrop(size, 2));
    }

    _controller.repeat();
  }

  Raindrop _createDrop(Size size, int layer, {bool fromTop = false}) {
    final baseSpeed = _getBaseSpeedForLayer(layer);
    final speedVariation = baseSpeed * 0.4;

    return Raindrop(
      x: _random.nextDouble() * size.width,
      y: fromTop
          ? -_random.nextDouble() * 150
          : _random.nextDouble() * size.height,
      speed: baseSpeed + (_random.nextDouble() - 0.5) * speedVariation,
      length: _getLengthForLayer(layer) + (_random.nextDouble() - 0.5) * 15,
      angle: (_random.nextDouble() - 0.5) * 0.12 + _windOffset * 0.3,
      opacity: _getOpacityForLayer(layer) + (_random.nextDouble() - 0.5) * 0.15,
      layer: layer,
      thickness: _getThicknessForLayer(layer) + (_random.nextDouble() - 0.5) * 0.3,
      wobble: _random.nextDouble() * pi * 2,
      flickerPhase: _random.nextDouble() * pi * 2,
    );
  }

  double _getBaseSpeedForLayer(int layer) {
    switch (layer) {
      case 0: return 5.0;
      case 1: return 10.0;
      case 2: return 16.0;
      default: return 10.0;
    }
  }

  double _getLengthForLayer(int layer) {
    switch (layer) {
      case 0: return 12.0;
      case 1: return 22.0;
      case 2: return 45.0;
      default: return 22.0;
    }
  }

  double _getOpacityForLayer(int layer) {
    switch (layer) {
      case 0: return 0.18;
      case 1: return 0.38;
      case 2: return 0.65;
      default: return 0.38;
    }
  }

  double _getThicknessForLayer(int layer) {
    switch (layer) {
      case 0: return 0.4;
      case 1: return 0.9;
      case 2: return 1.6;
      default: return 0.9;
    }
  }

  void _updateFrame() {
    if (_size == Size.zero) return;

    _time += 0.016;
    
    // Wind simulation
    _windPhase += 0.008;
    _targetWindOffset = sin(_windPhase * 0.7) * 0.15 + 
                        sin(_windPhase * 1.3) * 0.08 + 
                        sin(_windPhase * 2.1) * 0.04;
    _windOffset += (_targetWindOffset - _windOffset) * 0.02;
    
    final speedMultiplier = 1.0 + widget.intensity * 0.15;
    
    // The ground level where water surface is
    final groundLevel = _size.height - 10;

    // Update drops
    for (int i = 0; i < _drops.length; i++) {
      final drop = _drops[i];
      
      final wobbleEffect = sin(_time * 3.0 + drop.wobble) * 0.02;
      final windEffect = _windOffset * (3 - drop.layer) * 0.5;
      
      final newY = drop.y + drop.speed * speedMultiplier;
      final newX = drop.x + (windEffect + wobbleEffect) * drop.speed * 0.3;
      
      drop.flickerPhase += 0.15;

      // Check if drop hits the ground
      if (newY > groundLevel) {
        // Create ripple at EXACT impact point
        if (drop.layer >= 1 && _ripples.length < VisualConfig.maxRipples) {
          // Calculate exact X position where drop hits ground
          final impactX = drop.x + (groundLevel - drop.y) / drop.length * sin(drop.angle) * drop.length;
          
          _ripples.add(ImpactRipple(
            x: impactX.clamp(10.0, _size.width - 10.0),
            y: groundLevel,
            startTime: _time,
            maxRadius: drop.layer == 2 ? 18 + _random.nextDouble() * 12 : 10 + _random.nextDouble() * 8,
            intensity: drop.layer == 2 ? 0.9 : 0.5,
          ));
        }
        
        // Create splash particles for foreground drops
        if (drop.layer == 2 && _random.nextDouble() > 0.5) {
          _createSplash(newX, groundLevel);
        }
        
        // Respawn drop
        _drops[i] = _createDrop(_size, drop.layer, fromTop: true);
      } else {
        drop.x = newX;
        drop.y = newY;
        drop.angle = drop.angle * 0.98 + (_windOffset * 0.15) * 0.02;
      }
    }

    // Remove old ripples
    _ripples.removeWhere((ripple) => _time - ripple.startTime > 0.8);

    // Update splashes
    _updateSplashes();

    setState(() {});
  }

  void _createSplash(double x, double y) {
    if (_splashes.length > 15) return;
    
    final count = 2 + _random.nextInt(2);
    for (int i = 0; i < count; i++) {
      final angle = -pi / 2 + (_random.nextDouble() - 0.5) * pi * 0.7;
      final speed = 1.0 + _random.nextDouble() * 1.5;
      
      _splashes.add(SplashParticle(
        x: x + (_random.nextDouble() - 0.5) * 3,
        y: y,
        velocityX: cos(angle) * speed,
        velocityY: sin(angle) * speed * 1.5,
        maxLife: 0.25 + _random.nextDouble() * 0.15,
        size: 0.6 + _random.nextDouble() * 0.6,
      ));
    }
  }

  void _updateSplashes() {
    for (int i = _splashes.length - 1; i >= 0; i--) {
      final splash = _splashes[i];
      
      splash.velocityY += 0.12;
      splash.x += splash.velocityX;
      splash.y += splash.velocityY;
      splash.life -= 0.06;
      
      if (splash.life <= 0 || splash.y > _size.height) {
        _splashes.removeAt(i);
      }
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
        _initializeDrops(size);

        return CustomPaint(
          size: size,
          painter: RainPainter(
            drops: _drops,
            splashes: _splashes,
            ripples: _ripples,
            intensity: widget.intensity,
            windOffset: _windOffset,
            time: _time,
          ),
        );
      },
    );
  }
}
