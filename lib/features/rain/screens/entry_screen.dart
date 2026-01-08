import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/services/first_launch_service.dart';
import '../../../core/services/sound_service.dart';
import 'rain_screen.dart';

/// Entry Screen — Arrival
/// 
/// "I stepped outside into rain."
/// 
/// Flow:
/// 1. Full black screen initially
/// 2. Rain sound starts immediately (before visuals)
/// 3. If first launch: "Just listen." fades in (small, centered, white)
/// 4. Text fades out after ~1.5s
/// 5. Fade to rain visuals over 1.5–2s
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _textController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _textAnimation;

  bool _showText = false;
  bool _isFirstLaunch = false;

  @override
  void initState() {
    super.initState();

    // Hide system UI for immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _isFirstLaunch = FirstLaunchService.isFirstLaunch();

    // Main fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: AppDurations.entryFade,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Text fade animation (only used on first launch)
    _textController = AnimationController(
      vsync: this,
      duration: AppDurations.textFade,
    );
    _textAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Start rain sound immediately (before visuals)
    await SoundService().startRain();

    // Wait a moment for sound to establish
    await Future.delayed(const Duration(milliseconds: 500));

    if (_isFirstLaunch) {
      // Show "Just listen." text
      setState(() => _showText = true);
      _textController.forward();

      // Mark as launched
      await FirstLaunchService.markLaunched();

      // Wait, then fade text out
      await Future.delayed(const Duration(milliseconds: 1500));
      await _textController.reverse();
      setState(() => _showText = false);

      // Small pause before visual fade
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Fade to rain screen
    _fadeController.forward();

    // Navigate after animation completes
    await Future.delayed(AppDurations.entryFade);
    _navigateToRain();
  }

  void _navigateToRain() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RainScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Black background (always)
          Container(color: Colors.black),

          // "Just listen." text (first launch only)
          if (_showText)
            Center(
              child: FadeTransition(
                opacity: _textAnimation,
                child: Text(
                  'Just listen.',
                  style: TextStyle(
                    color: AppColors.whisper,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),

          // Fade out overlay
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: AppColors.background,
            ),
          ),
        ],
      ),
    );
  }
}
