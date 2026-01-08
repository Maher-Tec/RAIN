import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../constants/app_durations.dart';

/// RAIN Sound Service
/// 
/// The heart of RAIN. 80% of the experience.
/// 
/// Controls:
/// - Fade in/out for transitions
/// - Intensity via volume + subtle playback rate
/// - SEAMLESS CROSSFADE LOOPING (no gaps!)
/// 
/// Rules (per user feedback):
/// - Playback rate max 1.02 (imperceptible speed change)
/// - Volume baseline 0.60, peak 0.85 (closer, not louder)
/// - No visual indicators for intensity changes
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  // Dual players for crossfade looping
  AudioPlayer? _playerA;
  AudioPlayer? _playerB;
  bool _isPlayerAActive = true;
  
  Timer? _fadeTimer;
  Timer? _intensityTimer;
  Timer? _crossfadeTimer;
  Timer? _positionCheckTimer;
  
  double _currentVolume = 0.0;
  double _currentIntensity = 0.0; // 0.0 = baseline, 1.0 = peak
  
  bool _isPlaying = false;
  bool _isCrossfading = false;
  
  // Audio duration in milliseconds
  int _audioDurationMs = 0;
  static const int _crossfadeLeadTimeMs = 3000; // Start crossfade 3s before end

  /// Initialize the audio players
  Future<void> init() async {
    _playerA = AudioPlayer();
    _playerB = AudioPlayer();
    
    // No automatic loop - we handle it with crossfade
    _playerA!.setReleaseMode(ReleaseMode.stop);
    _playerB!.setReleaseMode(ReleaseMode.stop);
    
    // Preload the rain sound on both players
    await _playerA!.setSource(AssetSource('audio/rain.mp3'));
    await _playerB!.setSource(AssetSource('audio/rain.mp3'));
    
    // Get audio duration when it's available
    _playerA!.onDurationChanged.listen((duration) {
      _audioDurationMs = duration.inMilliseconds;
      print('[SoundService] Audio duration: ${_audioDurationMs}ms');
    });
    
    // Also listen for completion on both players as backup
    _playerA!.onPlayerComplete.listen((_) => _onPlayerComplete(true));
    _playerB!.onPlayerComplete.listen((_) => _onPlayerComplete(false));
  }
  
  void _onPlayerComplete(bool isPlayerA) {
    print('[SoundService] Player ${isPlayerA ? "A" : "B"} completed');
    // If this player completed and we're still playing, restart it for next cycle
    if (_isPlaying && !_isCrossfading) {
      // Trigger crossfade immediately if somehow we missed the timing
      _performCrossfade();
    }
  }
  
  AudioPlayer? get _activePlayer => _isPlayerAActive ? _playerA : _playerB;
  AudioPlayer? get _inactivePlayer => _isPlayerAActive ? _playerB : _playerA;

  /// Start rain with fade in
  Future<void> startRain() async {
    if (_isPlaying) return;
    _isPlaying = true;
    
    _currentVolume = 0.0;
    _isPlayerAActive = true;
    _isCrossfading = false;
    
    await _playerA?.setVolume(0.0);
    await _playerA?.seek(Duration.zero);
    await _playerA?.resume();
    
    // Start position monitoring with a timer (more reliable than stream)
    _startPositionMonitoring();
    
    _fadeIn();
  }

  /// Stop rain with fade out
  Future<void> stopRain() async {
    if (!_isPlaying) return;
    
    _fadeTimer?.cancel();
    _intensityTimer?.cancel();
    _crossfadeTimer?.cancel();
    _positionCheckTimer?.cancel();
    
    await _fadeOut();
  }
  
  /// Monitor position using a periodic timer (more reliable)
  void _startPositionMonitoring() {
    _positionCheckTimer?.cancel();
    
    // Check position every 500ms
    _positionCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!_isPlaying || _isCrossfading || _audioDurationMs == 0) return;
      
      try {
        final position = await _activePlayer?.getCurrentPosition();
        if (position == null) return;
        
        final positionMs = position.inMilliseconds;
        final remainingMs = _audioDurationMs - positionMs;
        
        // Trigger crossfade when approaching end
        if (remainingMs <= _crossfadeLeadTimeMs && remainingMs > 0) {
          print('[SoundService] Triggering crossfade, remaining: ${remainingMs}ms');
          _performCrossfade();
        }
      } catch (e) {
        print('[SoundService] Position check error: $e');
      }
    });
  }
  
  /// Crossfade to the other player for seamless looping
  void _performCrossfade() async {
    if (_isCrossfading || !_isPlaying) return;
    _isCrossfading = true;
    
    print('[SoundService] Starting crossfade...');
    
    final fadeOutPlayer = _activePlayer;
    final fadeInPlayer = _inactivePlayer;
    
    // Prepare the fade-in player
    await fadeInPlayer?.setVolume(0.0);
    await fadeInPlayer?.seek(Duration.zero);
    await fadeInPlayer?.resume();
    
    // Switch active player for future operations
    _isPlayerAActive = !_isPlayerAActive;
    
    // Calculate current target volume based on intensity
    final targetVolume = AudioConfig.volumeBaseline + 
        (AudioConfig.volumePeak - AudioConfig.volumeBaseline) * _currentIntensity;
    
    // Perform crossfade over ~2 seconds
    const steps = 60;
    const stepDuration = Duration(milliseconds: 33);
    int currentStep = 0;
    final startVolume = _currentVolume > 0 ? _currentVolume : targetVolume;
    
    _crossfadeTimer?.cancel();
    _crossfadeTimer = Timer.periodic(stepDuration, (timer) {
      if (!_isPlaying) {
        timer.cancel();
        _isCrossfading = false;
        return;
      }
      
      currentStep++;
      final progress = currentStep / steps;
      
      // Equal power crossfade curve for smooth transition
      final fadeOutVol = startVolume * (1.0 - progress);
      final fadeInVol = targetVolume * progress;
      
      fadeOutPlayer?.setVolume(fadeOutVol);
      fadeInPlayer?.setVolume(fadeInVol);
      
      if (currentStep >= steps) {
        timer.cancel();
        fadeOutPlayer?.pause();
        fadeOutPlayer?.seek(Duration.zero); // Reset for next crossfade
        _isCrossfading = false;
        _currentVolume = targetVolume;
        print('[SoundService] Crossfade complete');
      }
    });
  }

  /// Set intensity (0.0 = baseline, 1.0 = peak)
  void setIntensity(double value) {
    _currentIntensity = value.clamp(0.0, 1.0);
    _applyIntensity();
  }

  /// Gradually increase intensity (for long-press)
  void rampUpIntensity() {
    _intensityTimer?.cancel();
    
    const steps = 30;
    const stepDuration = Duration(milliseconds: 16);
    int currentStep = 0;
    final startIntensity = _currentIntensity;
    
    _intensityTimer = Timer.periodic(stepDuration, (timer) {
      currentStep++;
      final progress = currentStep / steps;
      _currentIntensity = startIntensity + (1.0 - startIntensity) * progress;
      _applyIntensity();
      
      if (currentStep >= steps) {
        timer.cancel();
        _currentIntensity = 1.0;
        _applyIntensity();
      }
    });
  }

  /// Gradually return to baseline (for long-press release)
  void returnToBaseline() {
    _intensityTimer?.cancel();
    
    const steps = 90; // 1.5 seconds at 60fps
    const stepDuration = Duration(milliseconds: 16);
    int currentStep = 0;
    final startIntensity = _currentIntensity;
    
    _intensityTimer = Timer.periodic(stepDuration, (timer) {
      currentStep++;
      final progress = currentStep / steps;
      // Ease-out curve for natural return
      final easedProgress = 1.0 - (1.0 - progress) * (1.0 - progress);
      _currentIntensity = startIntensity * (1.0 - easedProgress);
      _applyIntensity();
      
      if (currentStep >= steps) {
        timer.cancel();
        _currentIntensity = 0.0;
        _applyIntensity();
      }
    });
  }

  void _applyIntensity() {
    if (_activePlayer == null || !_isPlaying) return;
    
    // Volume: baseline → peak
    final volume = AudioConfig.volumeBaseline + 
        (AudioConfig.volumePeak - AudioConfig.volumeBaseline) * _currentIntensity;
    
    // Playback rate: 1.0 → 1.02 (very subtle)
    final rate = AudioConfig.rateBaseline + 
        (AudioConfig.ratePeak - AudioConfig.rateBaseline) * _currentIntensity;
    
    // Apply to active player
    _activePlayer!.setVolume(volume);
    _activePlayer!.setPlaybackRate(rate);
    
    // Also apply rate to inactive player during crossfade
    if (_isCrossfading) {
      _inactivePlayer?.setPlaybackRate(rate);
    }
    
    _currentVolume = volume;
  }

  void _fadeIn() {
    _fadeTimer?.cancel();
    
    const steps = 120; // 2 seconds at 60fps
    const stepDuration = Duration(milliseconds: 16);
    int currentStep = 0;
    
    _fadeTimer = Timer.periodic(stepDuration, (timer) {
      currentStep++;
      final progress = currentStep / steps;
      // Ease-in curve
      _currentVolume = AudioConfig.volumeBaseline * progress * progress;
      _activePlayer?.setVolume(_currentVolume);
      
      if (currentStep >= steps) {
        timer.cancel();
        _currentVolume = AudioConfig.volumeBaseline;
        _activePlayer?.setVolume(_currentVolume);
      }
    });
  }

  Future<void> _fadeOut() async {
    _fadeTimer?.cancel();
    
    const steps = 18; // 300ms at 60fps
    const stepDuration = Duration(milliseconds: 16);
    int currentStep = 0;
    final startVolume = _currentVolume;
    
    final completer = Completer<void>();
    
    _fadeTimer = Timer.periodic(stepDuration, (timer) {
      currentStep++;
      final progress = currentStep / steps;
      _currentVolume = startVolume * (1.0 - progress);
      _playerA?.setVolume(_currentVolume);
      _playerB?.setVolume(_currentVolume * 0.5);
      
      if (currentStep >= steps) {
        timer.cancel();
        _playerA?.pause();
        _playerB?.pause();
        _isPlaying = false;
        _isCrossfading = false;
        _currentIntensity = 0.0;
        completer.complete();
      }
    });
    
    return completer.future;
  }

  /// Current intensity for rain animation to respond to
  double get intensity => _currentIntensity;
  
  /// Whether rain is currently playing
  bool get isPlaying => _isPlaying;

  /// Dispose resources
  void dispose() {
    _fadeTimer?.cancel();
    _intensityTimer?.cancel();
    _crossfadeTimer?.cancel();
    _positionCheckTimer?.cancel();
    _playerA?.dispose();
    _playerB?.dispose();
    _playerA = null;
    _playerB = null;
  }
}
