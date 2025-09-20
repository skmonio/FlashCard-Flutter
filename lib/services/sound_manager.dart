import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _soundEnabled = true;
  String _soundMode = 'system'; // 'system', 'always', 'never'

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _loadSoundSettings();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing SoundManager: $e');
    }
  }

  Future<void> _loadSoundSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _soundMode = prefs.getString('sound_mode') ?? 'system';
    } catch (e) {
      print('Error loading sound settings: $e');
    }
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }

  Future<void> setSoundMode(String mode) async {
    _soundMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sound_mode', mode);
  }

  bool get soundEnabled => _soundEnabled;
  String get soundMode => _soundMode;

  bool _shouldPlaySound() {
    if (!_soundEnabled) return false;
    if (_soundMode == 'never') return false;
    if (_soundMode == 'always') return true;
    if (_soundMode == 'system') {
      // For system mode, we'll respect the device's silent mode
      // This is a simplified check - in a real app you might want to use
      // a plugin to check the actual system volume/silent mode
      return true; // For now, always play in system mode
    }
    return true;
  }

  Future<void> playBeginSound() async {
    try {
      print('Attempting to play begin sound...');
      await initialize(); // Load settings first
      if (!_shouldPlaySound()) {
        print('Sound disabled, skipping begin sound');
        return;
      }
      await _audioPlayer.stop(); // Stop any currently playing audio
      print('Playing Begin.wav...');
      await _audioPlayer.play(AssetSource('audio/Begin.wav'));
      print('Begin sound started successfully');
    } catch (e) {
      print('Error playing begin sound: $e');
    }
  }

  Future<void> playCompleteSound() async {
    try {
      await initialize(); // Load settings first
      if (!_shouldPlaySound()) return;
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Complete.wav'));
    } catch (e) {
      print('Error playing complete sound: $e');
    }
  }

  Future<void> playCorrectSound() async {
    try {
      await initialize(); // Load settings first
      if (!_shouldPlaySound()) return;
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Correct.wav'));
    } catch (e) {
      print('Error playing correct sound: $e');
    }
  }

  Future<void> playWrongSound() async {
    try {
      await initialize(); // Load settings first
      if (!_shouldPlaySound()) return;
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Wrong.wav'));
    } catch (e) {
      print('Error playing wrong sound: $e');
    }
  }

  Future<void> playGameSound() async {
    try {
      await initialize(); // Load settings first
      if (!_shouldPlaySound()) return;
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Game.wav'));
    } catch (e) {
      print('Error playing game sound: $e');
    }
  }

  Future<void> playSwipeSound() async {
    try {
      await initialize(); // Load settings first
      if (!_shouldPlaySound()) return;
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Swipe.wav'));
    } catch (e) {
      print('Error playing swipe sound: $e');
    }
  }

  Future<void> playPopSound() async {
    try {
      await initialize(); // Load settings first
      if (!_shouldPlaySound()) return;
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Pop.wav'));
    } catch (e) {
      print('Error playing pop sound: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
} 