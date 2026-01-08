import 'package:shared_preferences/shared_preferences.dart';

/// First Launch Detection Service
/// 
/// Used only to show "Just listen." once, ever.
/// No tracking. No stats. Just one boolean.
class FirstLaunchService {
  static const String _key = 'rain_first_launch_complete';
  
  static SharedPreferences? _prefs;
  
  /// Initialize the service
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Returns true only on the very first launch
  static bool isFirstLaunch() {
    if (_prefs == null) return false;
    return !(_prefs!.getBool(_key) ?? false);
  }
  
  /// Mark first launch as complete (called after showing "Just listen.")
  static Future<void> markLaunched() async {
    await _prefs?.setBool(_key, true);
  }
}
