import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/game_session.dart';
import '../providers/user_profile_provider.dart';

class XpService {
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
}
