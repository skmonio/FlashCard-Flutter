import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _isInitialized = true;
    } catch (e) {
      print('Error initializing SoundManager: $e');
    }
  }

  Future<void> playBeginSound() async {
    try {
      print('Attempting to play begin sound...');
      await initialize();
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
      await initialize();
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Complete.wav'));
    } catch (e) {
      print('Error playing complete sound: $e');
    }
  }

  Future<void> playCorrectSound() async {
    try {
      await initialize();
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Correct.wav'));
    } catch (e) {
      print('Error playing correct sound: $e');
    }
  }

  Future<void> playWrongSound() async {
    try {
      await initialize();
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Wrong.wav'));
    } catch (e) {
      print('Error playing wrong sound: $e');
    }
  }

  Future<void> playGameSound() async {
    try {
      await initialize();
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Game.wav'));
    } catch (e) {
      print('Error playing game sound: $e');
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