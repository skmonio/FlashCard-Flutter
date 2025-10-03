import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundMode {
  system,
  always,
  never,
}

class SoundProvider extends ChangeNotifier {
  static const String _soundModeKey = 'sound_mode';
  
  SoundMode _soundMode = SoundMode.system;
  
  SoundMode get soundMode => _soundMode;
  
  bool get isSystemMode {
    return _soundMode == SoundMode.system;
  }
  
  bool get isAlwaysMode {
    return _soundMode == SoundMode.always;
  }
  
  bool get isNeverMode {
    return _soundMode == SoundMode.never;
  }
  
  // Initialize sound mode from saved preferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final soundModeIndex = prefs.getInt(_soundModeKey) ?? 0;
      _soundMode = SoundMode.values[soundModeIndex];
      notifyListeners();
    } catch (e) {
      print('Error loading sound mode: $e');
    }
  }
  
  // Set specific sound mode
  Future<void> setSoundMode(SoundMode mode) async {
    _soundMode = mode;
    await _saveSoundMode();
    notifyListeners();
  }
  
  // Save sound mode preference
  Future<void> _saveSoundMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_soundModeKey, _soundMode.index);
    } catch (e) {
      print('Error saving sound mode: $e');
    }
  }
  
  // Get display name for sound mode
  String getDisplayName(SoundMode mode) {
    switch (mode) {
      case SoundMode.system:
        return 'System (auto)';
      case SoundMode.always:
        return 'Sound On';
      case SoundMode.never:
        return 'Sound Off';
    }
  }
  
  // Get description for sound mode
  String getDescription(SoundMode mode) {
    switch (mode) {
      case SoundMode.system:
        return 'Follow device silent mode settings';
      case SoundMode.always:
        return 'Always play sounds';
      case SoundMode.never:
        return 'Never play sounds';
    }
  }
  
  // Get icon for sound mode
  IconData getIcon(SoundMode mode) {
    switch (mode) {
      case SoundMode.system:
        return Icons.volume_up_outlined;
      case SoundMode.always:
        return Icons.volume_up;
      case SoundMode.never:
        return Icons.volume_off;
    }
  }
  
  // Get color for sound mode
  Color getColor(SoundMode mode) {
    switch (mode) {
      case SoundMode.system:
        return Colors.blue;
      case SoundMode.always:
        return Colors.green;
      case SoundMode.never:
        return Colors.red;
    }
  }
}
