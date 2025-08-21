import '../models/learning_mastery.dart';

class GameDifficultyHelper {
  /// Map game modes to their difficulty levels
  static GameDifficulty getDifficultyForGameMode(String gameMode) {
    switch (gameMode.toLowerCase()) {
      case 'multiple choice':
      case 'multiplechoice':
      case 'test':
        return GameDifficulty.easy;
        
      case 'true false':
      case 'truefalse':
      case 'word scramble':
      case 'wordscramble':
      case 'jumble':
        return GameDifficulty.medium;
        
      case 'writing':
      case 'sentence building':
      case 'sentencebuilding':
        return GameDifficulty.hard;
        
      case 'timed':
      case 'timed test':
      case 'timed true false':
      case 'timed word scramble':
        return GameDifficulty.expert;
        
      default:
        return GameDifficulty.medium; // Default fallback
    }
  }
  
  /// Get difficulty description for UI
  static String getDifficultyDescription(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return 'Easy (Multiple Choice)';
      case GameDifficulty.medium:
        return 'Medium (True/False, Word Scramble)';
      case GameDifficulty.hard:
        return 'Hard (Writing, Sentence Building)';
      case GameDifficulty.expert:
        return 'Expert (Timed Modes)';
    }
  }
  
  /// Get difficulty weight for calculations
  static double getDifficultyWeight(GameDifficulty difficulty) {
    return difficulty.weight;
  }
  
  /// Get color for difficulty in UI
  static String getDifficultyColor(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return '#4CAF50'; // Green
      case GameDifficulty.medium:
        return '#FF9800'; // Orange
      case GameDifficulty.hard:
        return '#F44336'; // Red
      case GameDifficulty.expert:
        return '#9C27B0'; // Purple
    }
  }
}
