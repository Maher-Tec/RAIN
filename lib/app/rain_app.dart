import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../features/rain/screens/entry_screen.dart';

/// RAIN App Configuration
/// 
/// RAIN must never explain itself inside the app.
/// 
/// Philosophy lock:
/// - No text (after first launch)
/// - No timers
/// - No tracking
/// - No wellness claims
/// - No sound variants (v1)
class RainApp extends StatelessWidget {
  const RainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAIN',
      debugShowCheckedModeBanner: false,
      
      // Dark theme only, no user preference
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.background,
        ),
      ),
      
      // Start with entry screen
      home: const EntryScreen(),
    );
  }
}
