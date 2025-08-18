import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _hapticEnabled = true;

  /// Initialize haptic service and load user preferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _hapticEnabled = prefs.getBool('haptic_enabled') ?? true;
  }

  /// Update haptic enabled setting
  Future<void> setHapticEnabled(bool enabled) async {
    _hapticEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_enabled', enabled);
  }

  /// Get current haptic enabled state
  bool get hapticEnabled => _hapticEnabled;

  /// Light impact - for subtle interactions like button taps
  void lightImpact() {
    if (!_hapticEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Medium impact - for more noticeable interactions like card flips
  void mediumImpact() {
    if (!_hapticEnabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for significant events like completing a lesson
  void heavyImpact() {
    if (!_hapticEnabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Selection feedback - for selection changes
  void selectionFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// Success feedback - for correct answers
  void successFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Error feedback - for incorrect answers
  void errorFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Warning feedback - for warnings or important notifications
  void warningFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Card flip feedback - for flipping flashcards
  void cardFlipFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Button tap feedback - for general button interactions
  void buttonTapFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Navigation feedback - for navigation actions
  void navigationFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// Achievement feedback - for unlocking achievements
  void achievementFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Progress feedback - for progress updates
  void progressFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Game feedback - for game interactions
  void gameFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Bubble word feedback - for bubble word interactions
  void bubbleWordFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Memory game feedback - for memory game interactions
  void memoryGameFeedback() {
    if (!_hapticEnabled) return;
    HapticFeedback.mediumImpact();
  }
}
