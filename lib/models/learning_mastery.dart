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

// NEW: Quality rating system for SuperMemo SM-2
enum AnswerQuality {
  completeBlackout(0),    // Total blank - couldn't recall at all
  incorrect(1),           // Wrong answer - remembered incorrectly
  hard(2),                // Hard to remember - struggled but got it
  good(3),                // Good response - recalled with some effort
  easy(4),                // Easy to remember - recalled easily
  perfect(5);             // Perfect response - immediate recall
  
  const AnswerQuality(this.value);
  final int value;
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
  
  // NEW: SuperMemo SM-2 specific fields
  int repetitions = 0;      // Number of successful repetitions
  int lapses = 0;           // Number of times forgotten (quality < 3)
  int interval = 1;         // Current interval in days (SM-2 style)
  
  // Legacy SRS fields (kept for backward compatibility)
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
  
  // Getter for debugging
  Map<String, int> get dailyAttemptsDebug => Map.from(dailyGameAttempts);
  
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
    // NEW: SuperMemo SM-2 fields
    this.repetitions = 0,
    this.lapses = 0,
    this.interval = 1,
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
  
  /// Learning percentage based on XP with SRS bonus
  double get learningPercentage {
    // Base percentage from XP
    final currentXP = currentXPWithDecay;
    final basePercentage = (currentXP / 11.0).clamp(0.0, 100.0);
    
    // SRS bonus: +5% per SRS level (max +50% at level 10)
    final srsBonus = (srsLevel * 5.0).clamp(0.0, 50.0);
    
    // Final percentage: base + bonus, capped at 100%
    final finalPercentage = (basePercentage + srsBonus).clamp(0.0, 100.0);
    
    return finalPercentage;
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
  
  // NEW: SuperMemo SM-2 computed properties
  
  /// Check if item is due for review (SM-2 style)
  bool get isDueForReview {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }
  
  /// Check if item is new (never reviewed)
  bool get isNew {
    return repetitions == 0 && totalReviews == 0;
  }
  
  /// Check if item is in learning phase (repetitions 1-2)
  bool get isLearning {
    return repetitions >= 1 && repetitions <= 2;
  }
  
  /// Check if item is in review phase (repetitions 3+)
  bool get isReviewing {
    return repetitions >= 3;
  }
  
  /// Get current interval in days (SM-2 style)
  int get currentInterval {
    return interval;
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
  
  // MARK: - SuperMemo SM-2 Methods
  
  /// NEW: Process answer using SuperMemo SM-2 algorithm
  /// This replaces the old markCorrect/markIncorrect methods
  void processAnswer(GameDifficulty difficulty, AnswerQuality quality) {
    _incrementAttempts(difficulty);
    
    // Update legacy fields for backward compatibility
    totalReviews++;
    lastReviewDate = DateTime.now();
    
    // Update consecutive counters
    if (quality.value >= 3) {
      _incrementCorrect(difficulty);
      consecutiveCorrect++;
      consecutiveIncorrect = 0;
    } else {
      consecutiveIncorrect++;
      consecutiveCorrect = 0;
    }
    
    // SuperMemo SM-2 algorithm
    if (quality.value < 3) {
      // Lapse: forgot the item
      _handleLapse();
    } else {
      // Success: remembered the item
      _handleSuccess(quality);
    }
    
    // Calculate next review date
    nextReviewDate = DateTime.now().add(Duration(days: interval));
    
    // Update legacy SRS level for backward compatibility
    _updateLegacySRSLevel();
  }
  
  /// Handle successful recall (quality >= 3)
  void _handleSuccess(AnswerQuality quality) {
    repetitions++;
    
    // Calculate new interval based on repetitions
    if (repetitions == 1) {
      interval = 1;
    } else if (repetitions == 2) {
      interval = 6;
    } else {
      interval = (interval * easeFactor).round();
    }
    
    // Update ease factor using SuperMemo SM-2 formula
    easeFactor = _calculateNewEaseFactor(quality.value, easeFactor);
  }
  
  /// Handle lapse (quality < 3)
  void _handleLapse() {
    lapses++;
    repetitions = 0;
    interval = 1;
    
    // Graduated ease factor reduction
    if (lapses == 1) {
      easeFactor = (easeFactor - 0.2).clamp(1.3, 2.5);
    } else {
      easeFactor = (easeFactor - 0.15).clamp(1.3, 2.5);
    }
  }
  
  /// Calculate new ease factor using SuperMemo SM-2 formula
  double _calculateNewEaseFactor(int quality, double oldEaseFactor) {
    // SM-2 formula: EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
    double newEaseFactor = oldEaseFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    return newEaseFactor.clamp(1.3, 2.5);
  }
  
  /// Update legacy SRS level for backward compatibility
  void _updateLegacySRSLevel() {
    // Map repetitions to legacy SRS levels
    if (repetitions == 0) {
      srsLevel = 0;
    } else if (repetitions == 1) {
      srsLevel = 1;
    } else if (repetitions == 2) {
      srsLevel = 2;
    } else {
      // For higher repetitions, use a formula that approximates the old system
      srsLevel = (repetitions + 1).clamp(3, 10);
    }
  }
  
  // MARK: - Legacy Methods (for backward compatibility)
  
  /// Legacy method - now delegates to processAnswer
  void markCorrect(GameDifficulty difficulty) {
    // Default to "good" quality for legacy calls
    processAnswer(difficulty, AnswerQuality.good);
  }
  
  /// Legacy method - now delegates to processAnswer
  void markIncorrect(GameDifficulty difficulty) {
    // Default to "incorrect" quality for legacy calls
    processAnswer(difficulty, AnswerQuality.incorrect);
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
    print('🔍 LearningMastery: resetDailyAttempts called - before clear: $dailyAttemptsDebug');
    dailyGameAttempts.clear();
    // Set to yesterday so _resetDailyAttemptsIfNeeded() will think it's a new day
    lastGameResetDate = DateTime.now().subtract(const Duration(days: 1));
    print('🔍 LearningMastery: resetDailyAttempts called - after clear: $dailyAttemptsDebug, lastGameResetDate: $lastGameResetDate');
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
    currentLevel = rpgWordLevel.level;
    
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
    final totalWeightedAttempts = (easyAttempts * GameDifficulty.easy.weight) + 
                                 (mediumAttempts * GameDifficulty.medium.weight) + 
                                 (hardAttempts * GameDifficulty.hard.weight) + 
                                 (expertAttempts * GameDifficulty.expert.weight);
    
    if (totalWeightedAttempts == 0) return 0.0;
    
    return totalWeightedScore / totalWeightedAttempts;
  }
  
  /// Apply time decay to learning percentage
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
      // NEW: SuperMemo SM-2 fields
      'repetitions': repetitions,
      'lapses': lapses,
      'interval': interval,
    };
    
    return json;
  }
  
  factory LearningMastery.fromJson(Map<String, dynamic> json) {
    final dailyGameAttempts = (json['dailyGameAttempts'] as Map<String, dynamic>?)
        ?.map((key, value) => MapEntry(key, value as int))
        ?? {};
    
    final lastGameResetDate = json['lastGameResetDate'] != null 
        ? DateTime.parse(json['lastGameResetDate']) 
        : null;
    
    print('🔍 LearningMastery: fromJson - dailyGameAttempts: $dailyGameAttempts, lastGameResetDate: $lastGameResetDate');
    
    // Check if we need to reset daily attempts (it's a new day)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shouldReset = lastGameResetDate == null || 
        DateTime(lastGameResetDate.year, lastGameResetDate.month, lastGameResetDate.day) != today;
    
    final finalDailyGameAttempts = shouldReset ? <String, int>{} : dailyGameAttempts;
    final finalLastGameResetDate = shouldReset ? now : lastGameResetDate;
    
    if (shouldReset) {
      print('🔍 LearningMastery: fromJson - Resetting daily attempts for new day');
    }
    
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
      dailyGameAttempts: finalDailyGameAttempts,
      lastGameResetDate: finalLastGameResetDate,
      // NEW: SuperMemo SM-2 fields
      repetitions: json['repetitions'] ?? 0,
      lapses: json['lapses'] ?? 0,
      interval: json['interval'] ?? 1,
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
    // NEW: SuperMemo SM-2 fields
    int? repetitions,
    int? lapses,
    int? interval,
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
      // NEW: SuperMemo SM-2 fields
      repetitions: repetitions ?? this.repetitions,
      lapses: lapses ?? this.lapses,
      interval: interval ?? this.interval,
    );
  }
}

