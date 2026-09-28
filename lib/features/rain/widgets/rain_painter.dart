import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_durations.dart';

/// Enhanced raindrop with realistic physics & motion blur properties
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

/// Splash particle for ground/sill impact
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

/// Impact ripple - spawns where raindrop hits the ground/sill
class ImpactRipple {
  final double x;
  final double y;
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

/// Photorealistic falling rain painter with motion-blurred streaks,
/// impact ripples, splashes, and atmospheric depth parallax.
class RainPainter extends CustomPainter {
  final List<Raindrop> drops;
  final List<SplashParticle> splashes;
  final List<ImpactRipple> ripples;
  final double intensity;
  final double windOffset;
  final double time;
  final Offset? touchPosition;
  final Paint _streakPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  RainPainter({
    required Listenable repaint,
    required this.drops,
    required this.splashes,
    required this.ripples,
    this.intensity = 0.0,
    this.windOffset = 0.0,
    this.time = 0.0,
    this.touchPosition,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw ground/sill ripples first
    for (final ripple in ripples) {
      _drawRipple(canvas, ripple);
    }

    // 2. Draw falling rain streaks (from far to near)
    for (final drop in drops) {
      _drawDrop(canvas, drop);
    }

    // 3. Draw impact splash particles
    for (final splash in splashes) {
      _drawSplash(canvas, splash);
    }
  }

  void _drawRipple(Canvas canvas, ImpactRipple ripple) {
    final age = time - ripple.startTime;
    const totalDuration = 0.85;
    final progress = (age / totalDuration).clamp(0.0, 1.0).toDouble();

    if (progress >= 1.0) return;

    const perspectiveRatio = 0.22;

    for (int ring = 0; ring < 3; ring++) {
      final ringDelay = ring * 0.14;
      final ringProgress = ((progress - ringDelay) / (1.0 - ringDelay))
          .clamp(0.0, 1.0)
          .toDouble();

      if (ringProgress > 0) {
        final eased = 1.0 - pow(1.0 - ringProgress, 2.6);
        final radius = ripple.maxRadius * eased * (1.0 - ring * 0.22);

        final baseOpacity = (1.0 - ringProgress) * 0.35 * ripple.intensity;
        final ringOpacity = baseOpacity * (1.0 - ring * 0.28);

        if (ringOpacity > 0.01 && radius > 1) {
          final alpha = (ringOpacity * 255).round().clamp(0, 255).toInt();

          final paint = Paint()
            ..color = AppColors.ripple.withAlpha(alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(0.6, 1.2 - ring * 0.3).toDouble();

          final rect = Rect.fromCenter(
            center: Offset(ripple.x, ripple.y),
            width: radius * 2,
            height: radius * 2 * perspectiveRatio,
          );
          canvas.drawOval(rect, paint);

          if (ring == 0 && alpha > 35) {
            final glowPaint = Paint()
              ..color = AppColors.ripple.withAlpha((alpha * 0.28).round())
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.8
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
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
      flickerMultiplier = 0.88 + 0.12 * sin(drop.flickerPhase);
    }

    final adjustedOpacity =
        (drop.opacity * (1.0 + intensity * 0.35) * flickerMultiplier)
            .clamp(0.0, 1.0)
            .toDouble();
    final alpha = (adjustedOpacity * 255).round().clamp(0, 255).toInt();

    // Streak elongates dynamically during heavy rain downpours
    final currentLength = drop.length * (1.0 + intensity * 0.3);

    final startPoint = Offset(drop.x, drop.y);
    final dx = currentLength * sin(drop.angle);
    final dy = currentLength * cos(drop.angle);
    final endPoint = Offset(drop.x + dx, drop.y + dy);

    // Reuse one solid paint per painter and draw a single line per streak.
    // Per-drop gradient and blurred bloom shaders were costly at screen size.
    _streakPaint
      ..color = baseColor.withAlpha(alpha)
      ..strokeWidth = drop.thickness * (1.0 + intensity * 0.15);
    canvas.drawLine(startPoint, endPoint, _streakPaint);
  }

  void _drawSplash(Canvas canvas, SplashParticle splash) {
    final alpha = (splash.life * 220).round().clamp(0, 255).toInt();
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

/// Enhanced rain canvas widget with dynamic storm intensity, wind turbulence & splash simulation
class RainCanvas extends StatefulWidget {
  final double intensity;

  const RainCanvas({super.key, this.intensity = 0.0});

  @override
  RainCanvasState createState() => RainCanvasState();
}

class RainCanvasState extends State<RainCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Raindrop> _drops = [];
  final List<SplashParticle> _splashes = [];
  final List<ImpactRipple> _ripples = [];
  final Random _random = Random();
  Size _size = Size.zero;

  double _windPhase = 0.0;
  double _windOffset = 0.0;
  double _targetWindOffset = 0.0;
  double _time = 0.0;
  Offset? _touchPosition;

  void setTouchPosition(Offset? position) {
    _touchPosition = position;
  }

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
    _syncDropCounts();
    _controller.repeat();
  }

  void _syncDropCounts() {
    if (_size == Size.zero) return;

    final baseMultiplier = 1.0 + widget.intensity * 0.75;
    final targetBg = (VisualConfig.backgroundDropCount * baseMultiplier).round();
    final targetMid = (VisualConfig.midgroundDropCount * baseMultiplier).round();
    final targetFg = (VisualConfig.foregroundDropCount * baseMultiplier).round();

    int currentBg = _drops.where((d) => d.layer == 0).length;
    int currentMid = _drops.where((d) => d.layer == 1).length;
    int currentFg = _drops.where((d) => d.layer == 2).length;

    while (currentBg < targetBg) {
      _drops.add(_createDrop(_size, 0));
      currentBg++;
    }
    while (currentMid < targetMid) {
      _drops.add(_createDrop(_size, 1));
      currentMid++;
    }
    while (currentFg < targetFg) {
      _drops.add(_createDrop(_size, 2));
      currentFg++;
    }
  }

  Raindrop _createDrop(Size size, int layer, {bool fromTop = false}) {
    final baseSpeed = _getBaseSpeedForLayer(layer);
    final speedVariation = baseSpeed * 0.35;

    return Raindrop(
      x: _random.nextDouble() * size.width,
      y: fromTop
          ? -_random.nextDouble() * 180
          : _random.nextDouble() * size.height,
      speed: baseSpeed + (_random.nextDouble() - 0.5) * speedVariation,
      length: _getLengthForLayer(layer) + (_random.nextDouble() - 0.5) * 18,
      angle: (_random.nextDouble() - 0.5) * 0.1 + _windOffset * 0.28,
      opacity: _getOpacityForLayer(layer) + (_random.nextDouble() - 0.5) * 0.12,
      layer: layer,
      thickness:
          _getThicknessForLayer(layer) + (_random.nextDouble() - 0.5) * 0.25,
      wobble: _random.nextDouble() * pi * 2,
      flickerPhase: _random.nextDouble() * pi * 2,
    );
  }

  double _getBaseSpeedForLayer(int layer) {
    switch (layer) {
      case 0:
        return 8.0;
      case 1:
        return 14.5;
      case 2:
        return 24.0;
      default:
        return 14.5;
    }
  }

  double _getLengthForLayer(int layer) {
    switch (layer) {
      case 0:
        return 15.0;
      case 1:
        return 34.0;
      case 2:
        return 68.0;
      default:
        return 34.0;
    }
  }

  double _getOpacityForLayer(int layer) {
    switch (layer) {
      case 0:
        return 0.18;
      case 1:
        return 0.44;
      case 2:
        return 0.78;
      default:
        return 0.44;
    }
  }

  double _getThicknessForLayer(int layer) {
    switch (layer) {
      case 0:
        return 0.55;
      case 1:
        return 1.15;
      case 2:
        return 1.9;
      default:
        return 1.15;
    }
  }

  void _updateFrame() {
    if (_size == Size.zero) return;

    _time += 0.016;

    // Dynamically adjust rain density to intensity
    if (_random.nextDouble() < 0.05) {
      _syncDropCounts();
    }

    // Wind turbulence amplifies with rain intensity
    _windPhase += 0.008 * (1.0 + widget.intensity * 0.5);
    _targetWindOffset =
        sin(_windPhase * 0.7) * (0.16 + widget.intensity * 0.12) +
        sin(_windPhase * 1.5) * (0.09 + widget.intensity * 0.06) +
        sin(_windPhase * 2.8) * 0.04;
    _windOffset += (_targetWindOffset - _windOffset) * 0.03;

    // Stronger speed multiplier during hold
    final speedMultiplier = 1.0 + widget.intensity * 0.75;
    final groundLevel = _size.height - 12;

    // Update falling drops
    for (int i = 0; i < _drops.length; i++) {
      final drop = _drops[i];

      final wobbleEffect = sin(_time * 4.0 + drop.wobble) * 0.02;
      final windEffect = _windOffset * (3 - drop.layer) * (0.45 + widget.intensity * 0.25);

      var touchDrift = 0.0;
      final touch = _touchPosition;
      if (touch != null) {
        final dx = touch.dx - drop.x;
        final dy = touch.dy - drop.y;
        const influenceRadius = 140.0;
        final distance = sqrt(dx * dx + dy * dy);
        if (distance < influenceRadius && distance > 1.0) {
          final proximity = 1.0 - distance / influenceRadius;
          touchDrift =
              (dx / distance) *
              proximity *
              proximity *
              (0.5 + drop.layer * 0.45);
        }
      }

      final newY = drop.y + drop.speed * speedMultiplier;
      final newX =
          drop.x + (windEffect + wobbleEffect) * drop.speed * 0.28 + touchDrift;

      drop.flickerPhase += 0.20;

      if (newY > groundLevel) {
        // Create ripples more vigorously during heavy rain
        final maxRipples = (VisualConfig.maxRipples * (1.0 + widget.intensity * 0.5)).round();
        if (drop.layer >= 1 && _ripples.length < maxRipples) {
          final impactX =
              drop.x +
              (groundLevel - drop.y) /
                  drop.length *
                  sin(drop.angle) *
                  drop.length;

          _ripples.add(
            ImpactRipple(
              x: impactX.clamp(10.0, _size.width - 10.0).toDouble(),
              y: groundLevel,
              startTime: _time,
              maxRadius: drop.layer == 2
                  ? 22 + _random.nextDouble() * (14 + widget.intensity * 8)
                  : 12 + _random.nextDouble() * (8 + widget.intensity * 5),
              intensity: (drop.layer == 2 ? 0.95 : 0.55) * (0.8 + widget.intensity * 0.4),
            ),
          );
        }

        // Multiplied splash particles during heavy downpour
        final splashChance = 0.40 + widget.intensity * 0.35;
        if (drop.layer == 2 && _random.nextDouble() < splashChance) {
          _createSplash(newX, groundLevel);
        }

        _drops[i] = _createDrop(_size, drop.layer, fromTop: true);
      } else {
        drop.x = newX;
        drop.y = newY;
        drop.angle = drop.angle * 0.96 + (_windOffset * 0.16) * 0.04;
      }
    }

    _ripples.removeWhere((ripple) => _time - ripple.startTime > 0.85);
    _updateSplashes();
  }

  void _createSplash(double x, double y) {
    final maxSplashes = (20 * (1.0 + widget.intensity * 0.8)).round();
    if (_splashes.length > maxSplashes) return;

    final count = 2 + _random.nextInt(2 + (widget.intensity * 3).round());
    for (int i = 0; i < count; i++) {
      final angle = -pi / 2 + (_random.nextDouble() - 0.5) * pi * 0.8;
      final speed = (1.4 + _random.nextDouble() * 2.2) * (1.0 + widget.intensity * 0.4);

      _splashes.add(
        SplashParticle(
          x: x + (_random.nextDouble() - 0.5) * 4,
          y: y,
          velocityX: cos(angle) * speed + _windOffset * 0.5,
          velocityY: sin(angle) * speed * 1.7,
          maxLife: 0.30 + _random.nextDouble() * 0.18,
          size: (0.7 + _random.nextDouble() * 0.8) * (1.0 + widget.intensity * 0.3),
        ),
      );
    }
  }

  void _updateSplashes() {
    for (int i = _splashes.length - 1; i >= 0; i--) {
      final splash = _splashes[i];

      splash.velocityY += 0.15;
      splash.x += splash.velocityX;
      splash.y += splash.velocityY;
      splash.life -= 0.050;

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
            repaint: _controller,
            drops: _drops,
            splashes: _splashes,
            ripples: _ripples,
            intensity: widget.intensity,
            windOffset: _windOffset,
            time: _time,
            touchPosition: _touchPosition,
          ),
        );
      },
    );
  }
}
