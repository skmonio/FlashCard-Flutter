import 'dart:math';

enum GameDifficulty {
  easy(0.7),      // Multiple choice
  medium(1.0),    // True/false, word scramble
  hard(1.3),      // Writing, sentence building
  expert(1.5);    // Timed modes
  
  const GameDifficulty(this.weight);
  final double weight;
}

enum LearningState {
  newCard,       // Never studied or very few attempts
  learning,      // 1-2 correct answers
  reviewing,     // 3-7 correct answers
  familiar,      // 8-14 correct answers
  mastered,      // 15+ correct answers
  expert         // 20+ correct answers with high accuracy
}

enum WordLevel {
  level0(0, "Seed", 0, 0, 0, 0),
  level1(1, "Beginner", 1, 10, 1, 30),
  level2(2, "Novice", 11, 20, 31, 70),
  level3(3, "Intermediate", 21, 30, 71, 130),
  level4(4, "Advanced", 31, 40, 131, 210),
  level5(5, "Mastered", 41, 50, 211, 310),
  level6(6, "Expert", 51, 60, 311, 430),
  level7(7, "Legendary", 61, 70, 431, 570),
  level8(8, "Mythic", 71, 80, 571, 730),
  level9(9, "Divine", 81, 90, 731, 910),
  level10(10, "Transcendent", 91, 100, 911, 1100);
  
  const WordLevel(this.level, this.title, this.minPercentage, this.maxPercentage, this.minXP, this.maxXP);
  final int level;
  final String title;
  final int minPercentage;
  final int maxPercentage;
  final int minXP;
  final int maxXP;
  
  static WordLevel fromPercentage(double percentage) {
    final int percent = percentage.round();
    for (final level in WordLevel.values) {
      if (percent >= level.minPercentage && percent <= level.maxPercentage) {
        return level;
      }
    }
    return WordLevel.level0;
  }
  
  static WordLevel fromXP(int xp) {
    for (final level in WordLevel.values) {
      if (xp >= level.minXP && xp <= level.maxXP) {
        return level;
      }
    }
    return WordLevel.level0;
  }
  
  static WordLevel fromLevel(int level) {
    return WordLevel.values.firstWhere(
      (l) => l.level == level,
      orElse: () => WordLevel.level0,
    );
  }
  
  // Get progress within current level (0.0 to 1.0) - for percentage system
  double getProgressWithinLevel(double percentage) {
    final int percent = percentage.round();
    if (percent <= minPercentage) return 0.0;
    if (percent >= maxPercentage) return 1.0;
    
    final levelRange = maxPercentage - minPercentage;
    final progressInLevel = percent - minPercentage;
    return progressInLevel / levelRange;
  }
}

class LearningMastery {
  // Game-specific correct answers
  int easyCorrect = 0;      // Multiple choice correct
  int mediumCorrect = 0;    // True/false, word scramble correct
  int hardCorrect = 0;      // Writing, sentence building correct
  int expertCorrect = 0;    // Timed mode correct
  
  // Game-specific total attempts
  int easyAttempts = 0;
  int mediumAttempts = 0;
  int hardAttempts = 0;
  int expertAttempts = 0;
  
  // SRS and timing data
  DateTime? lastReviewDate;
  int consecutiveCorrect = 0;
  int consecutiveIncorrect = 0;
  double easeFactor = 2.5;
  int srsLevel = 0;
  DateTime? nextReviewDate;
  int totalReviews = 0;
  
  // RPG-style leveling system
  int currentXP = 0;
  int currentLevel = 0;
  List<DateTime> levelUpHistory = [];
  List<Map<String, dynamic>> exerciseHistory = []; // Track exercise types and XP gained
  
  // Daily game tracking to prevent gaming the system
  Map<String, int> dailyGameAttempts = {}; // exerciseType -> attempts today
  DateTime? lastGameResetDate; // When daily attempts were last reset
  
  LearningMastery({
    this.easyCorrect = 0,
    this.mediumCorrect = 0,
    this.hardCorrect = 0,
    this.expertCorrect = 0,
    this.easyAttempts = 0,
    this.mediumAttempts = 0,
    this.hardAttempts = 0,
    this.expertAttempts = 0,
    this.lastReviewDate,
    this.consecutiveCorrect = 0,
    this.consecutiveIncorrect = 0,
    this.easeFactor = 2.5,
    this.srsLevel = 0,
    this.nextReviewDate,
    this.totalReviews = 0,
    this.currentXP = 0,
    this.currentLevel = 0,
    List<DateTime>? levelUpHistory,
    List<Map<String, dynamic>>? exerciseHistory,
    Map<String, int>? dailyGameAttempts,
    this.lastGameResetDate,
  }) : levelUpHistory = levelUpHistory ?? [],
       exerciseHistory = exerciseHistory ?? [],
       dailyGameAttempts = dailyGameAttempts ?? {};
  
  // MARK: - Computed Properties
  
  /// Total weighted score based on game difficulty
  double get totalWeightedScore {
    return (easyCorrect * GameDifficulty.easy.weight) + 
           (mediumCorrect * GameDifficulty.medium.weight) + 
           (hardCorrect * GameDifficulty.hard.weight) + 
           (expertCorrect * GameDifficulty.expert.weight);
  }
  
  /// Total attempts across all game types
  int get totalAttempts {
    return easyAttempts + mediumAttempts + hardAttempts + expertAttempts;
  }
  
  /// Total correct answers across all game types
  int get totalCorrect {
    return easyCorrect + mediumCorrect + hardCorrect + expertCorrect;
  }
  
  /// Overall accuracy percentage
  double get accuracy {
    return totalAttempts > 0 ? totalCorrect / totalAttempts : 0.0;
  }
  
  /// Current learning state based on weighted score
  LearningState get currentState {
    final score = totalWeightedScore;
    
    if (score < 3) return LearningState.newCard;
    if (score < 8) return LearningState.learning;
    if (score < 15) return LearningState.reviewing;
    if (score < 25) return LearningState.familiar;
    if (score < 40) return LearningState.mastered;
    return LearningState.expert;
  }
  
  /// Learning percentage directly based on XP (reasonable progression system)
  double get learningPercentage {
    // Reasonable progression: XP to percentage
    // 1100 XP total = 100% learned (slightly more than original 1000)
    // Each 11 XP = 1% learned (slightly more than original 10)
    
    final currentXP = currentXPWithDecay;
    final percentage = (currentXP / 11.0).clamp(0.0, 100.0);
    
    return percentage;
  }
  
  /// Get current XP with time decay applied
  int get currentXPWithDecay {
    if (lastReviewDate == null) return currentXP;
    
    final daysSinceReview = DateTime.now().difference(lastReviewDate!).inDays;
    
    // No decay for first 3 days
    if (daysSinceReview <= 3) return currentXP;
    
    // Decay rate: 3 XP per day after 3 days (reduced from 5)
    final decayDays = daysSinceReview - 3;
    final decayAmount = decayDays * 3; // 3 XP per day
    
    final decayedXP = currentXP - decayAmount;
    
    // Minimum 0 XP (can't go below 0)
    return decayedXP.clamp(0, currentXP);
  }
  
  /// Check if item is due for review
  bool get isDueForReview {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }
  
  /// Check if item is new (never reviewed)
  bool get isNew {
    return srsLevel == 0 && totalReviews == 0;
  }
  
  /// Check if item is in learning phase
  bool get isLearning {
    return srsLevel >= 1 && srsLevel <= 3;
  }
  
  /// Check if item is in review phase
  bool get isReviewing {
    return srsLevel >= 4;
  }
  
  /// Get current interval in days
  int get currentInterval {
    switch (srsLevel) {
      case 0: return 0; // New item
      case 1: return 1; // 1 day
      case 2: return 3; // 3 days (improved from 6)
      case 3: return 7; // 1 week (improved from 15)
      case 4: return 14; // 2 weeks
      case 5: return 30; // 1 month
      case 6: return 60; // 2 months
      case 7: return 120; // 4 months
      case 8: return 240; // 8 months
      case 9: return 365; // 1 year
      case 10: return 730; // 2 years
      default: return (pow(easeFactor, srsLevel - 3)).round();
    }
  }
  
  /// Get days until next review
  int? get daysUntilReview {
    if (nextReviewDate == null) return null;
    final now = DateTime.now();
    return nextReviewDate!.difference(now).inDays;
  }
  
  // MARK: - RPG Leveling System
  
  /// Get current word level based on learning percentage (for card list)
  WordLevel get wordLevel => WordLevel.fromPercentage(learningPercentage);
  
  /// Get current word level based on XP (for RPG system) - with decay applied
  WordLevel get rpgWordLevel => WordLevel.fromXP(currentXPWithDecay);
  
  /// Get progress within current level (0.0 to 1.0) - for card list
  double get levelProgress {
    final level = wordLevel;
    return level.getProgressWithinLevel(learningPercentage);
  }
  
  /// Get XP progress within current level (0.0 to 1.0) - for RPG system
  double get rpgLevelProgress {
    final level = rpgWordLevel;
    final xpInLevel = currentXPWithDecay - level.minXP;
    final xpNeededForLevel = level.maxXP - level.minXP;
    return xpNeededForLevel > 0 ? xpInLevel / xpNeededForLevel : 1.0;
  }
  
  /// Get percentage needed for next level
  int get percentageNeededForNextLevel {
    final currentLevel = wordLevel;
    if (currentLevel == WordLevel.level10) return 0; // Max level
    final nextLevel = WordLevel.fromLevel(currentLevel.level + 1);
    return nextLevel.minPercentage - learningPercentage.round();
  }
  
  /// Get XP needed for next level (for RPG system)
  int get xpNeededForNextLevel {
    final currentLevel = rpgWordLevel;
    if (currentLevel == WordLevel.level10) return 0; // Max level
    final nextLevel = WordLevel.fromLevel(currentLevel.level + 1);
    return nextLevel.minXP - currentXPWithDecay;
  }
  
  /// Check if word can level up
  bool get canLevelUp {
    return learningPercentage >= wordLevel.maxPercentage;
  }
  
  /// Reset daily game attempts if it's a new day
  void _resetDailyAttemptsIfNeeded() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (lastGameResetDate == null || 
        DateTime(lastGameResetDate!.year, lastGameResetDate!.month, lastGameResetDate!.day) != today) {
      dailyGameAttempts.clear();
      lastGameResetDate = now;
    }
  }
  
  /// Force reset daily attempts (for "Study Again" functionality)
  void resetDailyAttempts() {
    print('🔍 LearningMastery: resetDailyAttempts called - before clear: $dailyGameAttempts');
    dailyGameAttempts.clear();
    lastGameResetDate = DateTime.now();
    print('🔍 LearningMastery: resetDailyAttempts called - after clear: $dailyGameAttempts');
  }
  
  /// Get XP for a game attempt (with daily diminishing returns)
  int getXPForGame(String exerciseType) {
    _resetDailyAttemptsIfNeeded();
    
    final attempts = dailyGameAttempts[exerciseType] ?? 0;
    
    // First attempt: 10 XP, then -1 each time
    final baseXP = 10 - attempts;
    
    // Minimum 0 XP
    final finalXP = baseXP.clamp(0, 10);
    
    print('🔍 LearningMastery: getXPForGame - exerciseType: $exerciseType, attempts: $attempts, baseXP: $baseXP, finalXP: $finalXP');
    
    return finalXP;
  }
  
  /// Record a game attempt and return XP gained
  int recordGameAttempt(String exerciseType) {
    _resetDailyAttemptsIfNeeded();
    
    final currentAttempts = dailyGameAttempts[exerciseType] ?? 0;
    print('🔍 LearningMastery: recordGameAttempt - exerciseType: $exerciseType, current attempts: $currentAttempts');
    
    final xpGained = getXPForGame(exerciseType);
    
    // Increment daily attempts
    dailyGameAttempts[exerciseType] = currentAttempts + 1;
    
    print('🔍 LearningMastery: recordGameAttempt - exerciseType: $exerciseType, xpGained: $xpGained, dailyAttempts after: ${dailyGameAttempts[exerciseType]}');
    
    return xpGained;
  }
  
  /// Add XP and handle level ups
  void addXP(int xp, String exerciseType) {
    final previousLevel = currentLevel;
    currentXP += xp;
    currentLevel = wordLevel.level;
    
    // Record exercise history
    exerciseHistory.add({
      'timestamp': DateTime.now().toIso8601String(),
      'exerciseType': exerciseType,
      'xpGained': xp,
      'totalXP': currentXP,
    });
    
    // Check for level up
    if (currentLevel > previousLevel) {
      levelUpHistory.add(DateTime.now());
    }
  }
  
  /// Get recent exercise history (last 10 entries)
  List<Map<String, dynamic>> get recentExerciseHistory {
    return exerciseHistory.take(10).toList();
  }
  
  /// Get total XP gained today
  int get xpGainedToday {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    return exerciseHistory
        .where((entry) {
          final timestamp = DateTime.parse(entry['timestamp']);
          return timestamp.isAfter(todayStart);
        })
        .fold(0, (sum, entry) => sum + (entry['xpGained'] as int));
  }
  
  // MARK: - Private Methods
  
  /// Calculate weighted accuracy based on game difficulty
  double _calculateWeightedAccuracy() {
    if (totalAttempts == 0) return 0.0;
    
    double weightedCorrect = totalWeightedScore;
    double weightedTotal = (easyAttempts * GameDifficulty.easy.weight) + 
                          (mediumAttempts * GameDifficulty.medium.weight) + 
                          (hardAttempts * GameDifficulty.hard.weight) + 
                          (expertAttempts * GameDifficulty.expert.weight);
    
    return weightedTotal > 0 ? weightedCorrect / weightedTotal : 0.0;
  }
  
  /// Calculate mastery bonus based on current state
  double _calculateMasteryBonus() {
    switch (currentState) {
      case LearningState.newCard:
        return 0.3; // 30% cap for new items
      case LearningState.learning:
        return 0.6; // 60% cap for learning items
      case LearningState.reviewing:
        return 0.8; // 80% cap for reviewing items
      case LearningState.familiar:
        return 0.9; // 90% cap for familiar items
      case LearningState.mastered:
        return 0.95; // 95% cap for mastered items
      case LearningState.expert:
        return 1.0; // 100% cap for expert items
    }
  }
  
  /// Calculate time decay factor (old method - kept for compatibility)
  double _calculateDecayFactor() {
    if (lastReviewDate == null) return 1.0;
    
    final daysSinceReview = DateTime.now().difference(lastReviewDate!).inDays;
    
    // No decay for first 7 days
    if (daysSinceReview <= 7) return 1.0;
    
    // Gradual decay after 7 days: 3% per week (improved from 5%)
    final weeksSinceReview = (daysSinceReview - 7) / 7.0;
    final decayFactor = 1.0 - (weeksSinceReview * 0.03);
    
    return decayFactor.clamp(0.5, 1.0); // Minimum 50% retention (improved from 30%)
  }
  
  /// Apply time decay to learning percentage
  /// Cards lose percentage over time if not reviewed
  double _applyTimeDecay(double basePercentage) {
    if (lastReviewDate == null) return basePercentage;
    
    final daysSinceReview = DateTime.now().difference(lastReviewDate!).inDays;
    
    // No decay for first 3 days
    if (daysSinceReview <= 3) return basePercentage;
    
    // Decay rate: 1% per day after 3 days (reduced from 2%)
    final decayDays = daysSinceReview - 3;
    final decayAmount = decayDays * 1.0; // 1% per day
    
    final decayedPercentage = basePercentage - decayAmount;
    
    // Minimum 0% (can't go below 0)
    return decayedPercentage.clamp(0.0, 100.0);
  }
  
  /// Calculate SRS level bonus
  double _calculateSRSBonus() {
    // Higher SRS levels indicate better retention
    if (srsLevel >= 8) return 1.1; // 10% bonus for high SRS levels
    if (srsLevel >= 5) return 1.05; // 5% bonus for medium SRS levels
    return 1.0; // No bonus for low SRS levels
  }
  
  // MARK: - SRS Methods
  
  /// Mark answer as correct for specific game difficulty
  void markCorrect(GameDifficulty difficulty) {
    _incrementAttempts(difficulty);
    _incrementCorrect(difficulty);
    
    consecutiveCorrect++;
    consecutiveIncorrect = 0;
    totalReviews++;
    lastReviewDate = DateTime.now();
    
    // Update SRS level
    if (srsLevel < 10) {
      srsLevel++;
    }
    
    // Calculate next review date
    final interval = currentInterval;
    nextReviewDate = DateTime.now().add(Duration(days: interval));
    
    // Update ease factor (improved algorithm)
    if (consecutiveCorrect >= 3) {
      easeFactor = (easeFactor + 0.1).clamp(1.3, 2.5);
    }
  }
  
  /// Mark answer as incorrect for specific game difficulty
  void markIncorrect(GameDifficulty difficulty) {
    _incrementAttempts(difficulty);
    
    consecutiveIncorrect++;
    consecutiveCorrect = 0;
    totalReviews++;
    lastReviewDate = DateTime.now();
    
    // Reset SRS level to 1 if it was higher
    if (srsLevel > 1) {
      srsLevel = 1;
    }
    
    // Calculate next review date (1 day for incorrect)
    nextReviewDate = DateTime.now().add(const Duration(days: 1));
    
    // Decrease ease factor
    easeFactor = (easeFactor - 0.2).clamp(1.3, 2.5);
  }
  
  /// Helper method to increment attempts for specific difficulty
  void _incrementAttempts(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        easyAttempts++;
        break;
      case GameDifficulty.medium:
        mediumAttempts++;
        break;
      case GameDifficulty.hard:
        hardAttempts++;
        break;
      case GameDifficulty.expert:
        expertAttempts++;
        break;
    }
  }
  
  /// Helper method to increment correct answers for specific difficulty
  void _incrementCorrect(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        easyCorrect++;
        break;
      case GameDifficulty.medium:
        mediumCorrect++;
        break;
      case GameDifficulty.hard:
        hardCorrect++;
        break;
      case GameDifficulty.expert:
        expertCorrect++;
        break;
    }
  }
  
  // MARK: - JSON Serialization
  
  Map<String, dynamic> toJson() {
    final json = {
      'easyCorrect': easyCorrect,
      'mediumCorrect': mediumCorrect,
      'hardCorrect': hardCorrect,
      'expertCorrect': expertCorrect,
      'easyAttempts': easyAttempts,
      'mediumAttempts': mediumAttempts,
      'hardAttempts': hardAttempts,
      'expertAttempts': expertAttempts,
      'lastReviewDate': lastReviewDate?.toIso8601String(),
      'consecutiveCorrect': consecutiveCorrect,
      'consecutiveIncorrect': consecutiveIncorrect,
      'easeFactor': easeFactor,
      'srsLevel': srsLevel,
      'nextReviewDate': nextReviewDate?.toIso8601String(),
      'totalReviews': totalReviews,
      // RPG fields
      'currentXP': currentXP,
      'currentLevel': currentLevel,
      'levelUpHistory': levelUpHistory.map((date) => date.toIso8601String()).toList(),
      'exerciseHistory': exerciseHistory,
      'dailyGameAttempts': dailyGameAttempts,
      'lastGameResetDate': lastGameResetDate?.toIso8601String(),
    };
    
    print('🔍 LearningMastery: toJson - dailyGameAttempts: $dailyGameAttempts');
    return json;
  }
  
  factory LearningMastery.fromJson(Map<String, dynamic> json) {
    final dailyGameAttempts = (json['dailyGameAttempts'] as Map<String, dynamic>?)
        ?.map((key, value) => MapEntry(key, value as int))
        ?? {};
    
    print('🔍 LearningMastery: fromJson - dailyGameAttempts: $dailyGameAttempts');
    
    return LearningMastery(
      easyCorrect: json['easyCorrect'] ?? 0,
      mediumCorrect: json['mediumCorrect'] ?? 0,
      hardCorrect: json['hardCorrect'] ?? 0,
      expertCorrect: json['expertCorrect'] ?? 0,
      easyAttempts: json['easyAttempts'] ?? 0,
      mediumAttempts: json['mediumAttempts'] ?? 0,
      hardAttempts: json['hardAttempts'] ?? 0,
      expertAttempts: json['expertAttempts'] ?? 0,
      lastReviewDate: json['lastReviewDate'] != null 
          ? DateTime.parse(json['lastReviewDate']) 
          : null,
      consecutiveCorrect: json['consecutiveCorrect'] ?? 0,
      consecutiveIncorrect: json['consecutiveIncorrect'] ?? 0,
      easeFactor: json['easeFactor']?.toDouble() ?? 2.5,
      srsLevel: json['srsLevel'] ?? 0,
      nextReviewDate: json['nextReviewDate'] != null 
          ? DateTime.parse(json['nextReviewDate']) 
          : null,
      totalReviews: json['totalReviews'] ?? 0,
      // RPG fields
      currentXP: json['currentXP'] ?? 0,
      currentLevel: json['currentLevel'] ?? 0,
      levelUpHistory: (json['levelUpHistory'] as List<dynamic>?)
          ?.map((date) => DateTime.parse(date))
          .toList() ?? [],
      exerciseHistory: (json['exerciseHistory'] as List<dynamic>?)
          ?.map((entry) => Map<String, dynamic>.from(entry))
          .toList() ?? [],
      dailyGameAttempts: dailyGameAttempts,
      lastGameResetDate: json['lastGameResetDate'] != null 
          ? DateTime.parse(json['lastGameResetDate']) 
          : null,
    );
  }
  
  /// Create a copy with updated values
  LearningMastery copyWith({
    int? easyCorrect,
    int? mediumCorrect,
    int? hardCorrect,
    int? expertCorrect,
    int? easyAttempts,
    int? mediumAttempts,
    int? hardAttempts,
    int? expertAttempts,
    DateTime? lastReviewDate,
    int? consecutiveCorrect,
    int? consecutiveIncorrect,
    double? easeFactor,
    int? srsLevel,
    DateTime? nextReviewDate,
    int? totalReviews,
    int? currentXP,
    int? currentLevel,
    List<DateTime>? levelUpHistory,
    List<Map<String, dynamic>>? exerciseHistory,
    Map<String, int>? dailyGameAttempts,
    DateTime? lastGameResetDate,
  }) {
    return LearningMastery(
      easyCorrect: easyCorrect ?? this.easyCorrect,
      mediumCorrect: mediumCorrect ?? this.mediumCorrect,
      hardCorrect: hardCorrect ?? this.hardCorrect,
      expertCorrect: expertCorrect ?? this.expertCorrect,
      easyAttempts: easyAttempts ?? this.easyAttempts,
      mediumAttempts: mediumAttempts ?? this.mediumAttempts,
      hardAttempts: hardAttempts ?? this.hardAttempts,
      expertAttempts: expertAttempts ?? this.expertAttempts,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      consecutiveIncorrect: consecutiveIncorrect ?? this.consecutiveIncorrect,
      easeFactor: easeFactor ?? this.easeFactor,
      srsLevel: srsLevel ?? this.srsLevel,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      totalReviews: totalReviews ?? this.totalReviews,
      currentXP: currentXP ?? this.currentXP,
      currentLevel: currentLevel ?? this.currentLevel,
      levelUpHistory: levelUpHistory ?? this.levelUpHistory,
      exerciseHistory: exerciseHistory ?? this.exerciseHistory,
      dailyGameAttempts: dailyGameAttempts ?? this.dailyGameAttempts,
      lastGameResetDate: lastGameResetDate ?? this.lastGameResetDate,
    );
  }
}

