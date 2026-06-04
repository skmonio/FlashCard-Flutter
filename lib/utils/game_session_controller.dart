import 'package:flutter/material.dart';
import '../models/flash_card.dart';
import '../models/game_session.dart';
import '../models/learning_mastery.dart';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/xp_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_manager.dart';

/// Controller to encapsulate and standardize game session state, XP rewards,
/// HP penalties, sounds, haptics, and data updates across all game modes.
class GameSessionController {
  final GameSession session = GameSession();
  
  final List<FlashCard> studiedWords = [];
  final Map<String, int> xpGainedPerWord = {};
  final Map<String, LearningMastery> wordMastery = {};
  final Map<String, int> initialHPPerWord = {};
  
  final FlashcardProvider flashcardProvider;
  final UserProfileProvider userProfileProvider;
  
  GameSessionController({
    required this.flashcardProvider,
    required this.userProfileProvider,
  });

  /// Ensures a card is registered and its baseline state is tracked for results.
  void _ensureCardTracked(FlashCard card) {
    if (!studiedWords.any((word) => word.id == card.id)) {
      studiedWords.add(card);
      initialHPPerWord[card.id] = card.currentHP;
    }
  }

  /// Records a correct answer, performs haptics and sounds, calculates XP, and saves state.
  Future<void> recordCorrect(
    FlashCard card, {
    required String exerciseType,
    required GameDifficulty difficulty,
    int hintsUsed = 0,
    int wrongAttempts = 0,
  }) async {
    _ensureCardTracked(card);
    
    // 1. Success feedback & sounds
    HapticService().successFeedback();
    SoundManager().playCorrectSound();
    
    // 2. Track correct answer in the game session
    XpService.recordAnswer(session, true);
    
    // 3. Mark correct in the card model (applies HP/XP adjustments)
    card.markCorrect(difficulty);
    
    // 4. Calculate word-level XP including penalties
    final latestEntry = card.learningMastery.exerciseHistory.isNotEmpty
        ? card.learningMastery.exerciseHistory.last
        : null;
    final baseXP = latestEntry != null ? (latestEntry['xpGained'] as int? ?? 0) : 0;
    
    // Apply hint penalty (50% for 1 hint, 25% for 2 hints, 0% for 3 hints)
    var finalXP = hintsUsed == 1
        ? (baseXP * 0.5).round()
        : hintsUsed == 2
            ? (baseXP * 0.25).round()
            : hintsUsed >= 3
                ? 0
                : baseXP;
                
    // Apply penalty for wrong attempts: -1 XP per wrong attempt, min 0
    if (wrongAttempts > 0 && wrongAttempts < 5) {
      finalXP = (finalXP - wrongAttempts).clamp(0, baseXP);
    }
    
    // Update the card's current XP with the final calculated value
    if (latestEntry != null) {
      card.learningMastery.currentXP += finalXP - baseXP;
      latestEntry['xpGained'] = finalXP;
    }
    
    xpGainedPerWord[card.id] = (xpGainedPerWord[card.id] ?? 0) + finalXP;
    wordMastery[card.id] = card.learningMastery;
    
    // 5. Update card in provider
    await flashcardProvider.updateCard(card);
  }

  /// Records an incorrect answer or timeout, performs haptics and sounds, and saves state.
  Future<void> recordIncorrect(
    FlashCard card, {
    required String exerciseType,
    required GameDifficulty difficulty,
    bool isTimeout = false,
  }) async {
    _ensureCardTracked(card);
    
    // 1. Failure feedback & sounds
    HapticService().errorFeedback();
    SoundManager().playWrongSound();
    
    // 2. Track incorrect answer in the game session
    XpService.recordAnswer(session, false);
    
    // 3. Mark incorrect in the card model (applies HP decay)
    card.markIncorrect(difficulty);
    
    xpGainedPerWord[card.id] = 0;
    wordMastery[card.id] = card.learningMastery;
    
    // 4. Update card in provider
    await flashcardProvider.updateCard(card);
  }

  /// Finalizes the study session by awarding XP to the user profile and updating stats.
  Future<void> finalizeSession() async {
    final totalXPGained = xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp);
    
    // Award session XP to the user profile
    if (totalXPGained > 0) {
      await userProfileProvider.addXp(totalXPGained);
    }
    
    // Update session statistics
    final accuracy = session.totalAnswers > 0 ? (session.correctAnswers / session.totalAnswers) : 0.0;
    final isPerfect = session.correctAnswers == session.totalAnswers && session.totalAnswers > 0;
    
    await userProfileProvider.updateSessionStats(
      cardsStudied: session.totalAnswers,
      sessionAccuracy: accuracy,
      isPerfect: isPerfect,
    );
    
    // Update daily study streak
    await userProfileProvider.updateStreakFromStudyActivity();
  }
}
