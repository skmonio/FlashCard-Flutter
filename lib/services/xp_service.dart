import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/game_session.dart';
import '../providers/user_profile_provider.dart';
import '../models/learning_mastery.dart';

class XpService {
  static final XpService _instance = XpService._internal();
  factory XpService() => _instance;
  XpService._internal();

  // XP rewards for different exercise types (simplified)
  static const Map<String, int> exerciseXPRewards = {
    'multiple_choice': 10,
    'true_false': 10,
    'word_scramble': 10,
    'writing': 10,
    'sentence_building': 10,
    'de_het': 10,
    'plural': 10,
    'fill_in_blank': 10,
    'study': 10, // For advanced study mode
    'test': 10, // For test mode
    'timed_multiple_choice': 10,
    'timed_true_false': 10,
    'timed_word_scramble': 10,
  };

  // No streak bonuses - simple XP system
  static const Map<int, int> streakBonuses = {};

  // Session XP methods (existing functionality)
  static void recordAnswer(GameSession gameSession, bool isCorrect) {
    gameSession.recordAnswer(isCorrect);
    debugPrint('🔍 XpService: Answer recorded - Correct: $isCorrect, Total XP: ${gameSession.xpGained}');
  }
  
  static Future<void> awardSessionXp(UserProfileProvider userProfileProvider, GameSession gameSession, {bool isShuffleMode = false}) async {
    debugPrint('🔍 XpService: awardSessionXp called - isShuffleMode: $isShuffleMode, xpGained: ${gameSession.xpGained}');
    if (!isShuffleMode && gameSession.xpGained > 0) {
      debugPrint('🔍 XpService: About to award ${gameSession.xpGained} XP to user profile');
      try {
        await userProfileProvider.addXp(gameSession.xpGained);
        debugPrint('🔍 XpService: Successfully awarded ${gameSession.xpGained} XP to user profile');
      } catch (e) {
        debugPrint('🔍 XpService: Error awarding XP: $e');
      }
    } else {
      debugPrint('🔍 XpService: Skipping XP award - isShuffleMode: $isShuffleMode, xpGained: ${gameSession.xpGained}');
    }
  }
  
  static Map<String, dynamic> getSessionSummary(GameSession gameSession) {
    return {
      'xpGained': gameSession.xpGained,
      'correctAnswers': gameSession.correctAnswers,
      'totalAnswers': gameSession.totalAnswers,
      'accuracy': gameSession.accuracy,
      'accuracyPercentage': gameSession.accuracyPercentage,
    };
  }

  // Word-level XP methods (new RPG functionality)
  /// Calculate XP for a correct answer (with daily diminishing returns)
  int calculateWordXP(String exerciseType, int consecutiveCorrect) {
    // Only give XP for correct answers
    if (consecutiveCorrect > 0) {
      return exerciseXPRewards[exerciseType] ?? 10;
    } else {
      return 0; // No XP for incorrect answers
    }
  }

  /// Add XP to a word and handle level ups (with daily diminishing returns)
  void addXPToWord(LearningMastery mastery, String exerciseType, int consecutiveCorrect) {
    if (consecutiveCorrect > 0) {
      // Record the game attempt and get XP (with daily diminishing returns)
      final xpGained = mastery.recordGameAttempt(exerciseType);
      
      // Add the XP to the word
      mastery.addXP(xpGained, exerciseType);
      
      // Update last review date to prevent immediate decay
      mastery.lastReviewDate = DateTime.now();
    }
  }

  /// Get level up message
  String getLevelUpMessage(WordLevel newLevel) {
    switch (newLevel) {
      case WordLevel.level1:
        return "Welcome to the journey!";
      case WordLevel.level2:
        return "You're getting the hang of it!";
      case WordLevel.level3:
        return "Making great progress!";
      case WordLevel.level4:
        return "You're becoming quite skilled!";
      case WordLevel.level5:
        return "Mastered! This word is now part of your vocabulary!";
      case WordLevel.level6:
        return "Expert level! You're a Dutch language pro!";
      case WordLevel.level7:
        return "Legendary! This word is now second nature!";
      case WordLevel.level8:
        return "Mythic! You've transcended normal learning!";
      case WordLevel.level9:
        return "Divine! This word is now part of your soul!";
      case WordLevel.level10:
        return "Transcendent! You've achieved the impossible!";
    }
  }

  /// Get level color for UI
  int getLevelColor(WordLevel level) {
    switch (level) {
      case WordLevel.level1:
        return 0xFF9E9E9E; // Grey
      case WordLevel.level2:
        return 0xFF4CAF50; // Green
      case WordLevel.level3:
        return 0xFF2196F3; // Blue
      case WordLevel.level4:
        return 0xFF9C27B0; // Purple
      case WordLevel.level5:
        return 0xFFFF9800; // Orange
      case WordLevel.level6:
        return 0xFFF44336; // Red
      case WordLevel.level7:
        return 0xFFE91E63; // Pink
      case WordLevel.level8:
        return 0xFF673AB7; // Deep Purple
      case WordLevel.level9:
        return 0xFF3F51B5; // Indigo
      case WordLevel.level10:
        return 0xFF000000; // Black (with gold shimmer effect)
    }
  }

  /// Get level icon for UI
  String getLevelIcon(WordLevel level) {
    switch (level) {
      case WordLevel.level1:
        return "🌱";
      case WordLevel.level2:
        return "🌿";
      case WordLevel.level3:
        return "🌳";
      case WordLevel.level4:
        return "🏔️";
      case WordLevel.level5:
        return "⭐";
      case WordLevel.level6:
        return "🌟";
      case WordLevel.level7:
        return "💫";
      case WordLevel.level8:
        return "✨";
      case WordLevel.level9:
        return "🔥";
      case WordLevel.level10:
        return "👑";
    }
  }

  /// Get progress bar color based on level progress
  int getProgressBarColor(double progress) {
    if (progress < 0.3) return 0xFFF44336; // Red
    if (progress < 0.7) return 0xFFFF9800; // Orange
    return 0xFF4CAF50; // Green
  }

  /// Get motivational message based on progress
  String getMotivationalMessage(double progress) {
    if (progress < 0.2) return "Keep going! Every step counts!";
    if (progress < 0.4) return "You're making steady progress!";
    if (progress < 0.6) return "Halfway there! You've got this!";
    if (progress < 0.8) return "Almost there! Don't give up!";
    if (progress < 1.0) return "So close! One more push!";
    return "Level complete! Time to level up!";
  }
}
