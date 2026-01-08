import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/rain_app.dart';
import 'core/services/first_launch_service.dart';
import 'core/services/sound_service.dart';

/// RAIN — Nervous system regulation through sensory consistency
/// 
/// Slowing the body.
/// Reducing internal noise.
/// Creating safety through predictability.
/// 
/// RAIN works even if the user does nothing.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hide system UI for immersion
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

  // Status bar styling (in case it appears)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize services
  await FirstLaunchService.init();
  await SoundService().init();

  runApp(const RainApp());
}
