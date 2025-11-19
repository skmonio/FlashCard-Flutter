import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../providers/sound_provider.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  SoundProvider? _soundProvider;
  static const MethodChannel _channel = MethodChannel('com.skmonio.taaltrek/sound_mode');

  Future<void> initialize({SoundProvider? soundProvider}) async {
    if (_isInitialized) return;
    
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _soundProvider = soundProvider;
      _isInitialized = true;
    } catch (e) {
      print('Error initializing SoundManager: $e');
    }
  }

  void setSoundProvider(SoundProvider provider) {
    _soundProvider = provider;
  }

  Future<bool> _shouldPlaySound() async {
    if (_soundProvider == null) return true; // Default to playing sound if no provider
    
    switch (_soundProvider!.soundMode) {
      case SoundMode.never:
        return false;
      case SoundMode.always:
        return true;
      case SoundMode.system:
        // For system mode, respect the device's silent mode
        // If phone is on silent, return false (don't play sound)
        // If phone is not on silent, return true (play sound)
        return await _isDeviceNotSilent();
    }
  }

  Future<bool> _isDeviceNotSilent() async {
    // Check the device's ringer mode using platform channels
    // Returns true if device is NOT silent (normal or vibrate mode)
    // Returns false if device IS silent
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceNotSilent');
      return result ?? true; // Default to playing sound if we can't determine
    } catch (e) {
      print('Error checking device silent mode: $e');
      return true; // Default to playing sound if we can't determine
    }
  }

  Future<void> playBeginSound() async {
    try {
      print('Attempting to play begin sound...');
      await initialize(); // Load settings first
      if (!(await _shouldPlaySound())) {
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
      if (!(await _shouldPlaySound())) return;
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Complete.wav'));
    } catch (e) {
      print('Error playing complete sound: $e');
    }
  }

  Future<void> playCorrectSound() async {
    try {
      await initialize(); // Load settings first
      if (!(await _shouldPlaySound())) return;
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Correct.wav'));
    } catch (e) {
      print('Error playing correct sound: $e');
    }
  }

  Future<void> playWrongSound() async {
    try {
      await initialize(); // Load settings first
      if (!(await _shouldPlaySound())) return;
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Wrong.wav'));
    } catch (e) {
      print('Error playing wrong sound: $e');
    }
  }

  Future<void> playGameSound() async {
    try {
      await initialize(); // Load settings first
      if (!(await _shouldPlaySound())) return;
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Game.wav'));
    } catch (e) {
      print('Error playing game sound: $e');
    }
  }

  Future<void> playSwipeSound() async {
    try {
      await initialize(); // Load settings first
      if (!(await _shouldPlaySound())) return;
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource('audio/Swipe.wav'));
    } catch (e) {
      print('Error playing swipe sound: $e');
    }
  }

  Future<void> playPopSound() async {
    try {
      await initialize(); // Load settings first
      if (!(await _shouldPlaySound())) return;
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