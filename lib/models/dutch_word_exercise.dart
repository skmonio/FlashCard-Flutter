import 'dart:convert';

enum ExerciseType {
  fillInBlank,
  sentenceBuilding,
  multipleChoice,
}

enum ExerciseDifficulty {
  beginner,
  intermediate,
  advanced
}

enum WordCategory {
  common,
  business,
  academic,
  casual,
  formal,
  technical,
  cultural,
  other
}

class WordExercise {
  final String id;
  final ExerciseType type;
  final String prompt;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String? hint;
  final ExerciseDifficulty difficulty;
  final String? context;

  WordExercise({
    required this.id,
    required this.type,
    required this.prompt,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.hint,
    required this.difficulty,
    this.context,
  });

  factory WordExercise.fromJson(Map<String, dynamic> json) {
    return WordExercise(
      id: json['id'] ?? '',
      type: ExerciseType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ExerciseType.fillInBlank,
      ),
      prompt: json['prompt'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? '',
      explanation: json['explanation'] ?? '',
      hint: json['hint'],
      difficulty: ExerciseDifficulty.values.firstWhere(
        (e) => e.toString().split('.').last == json['difficulty'],
        orElse: () => ExerciseDifficulty.beginner,
      ),
      context: json['context'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'prompt': prompt,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'hint': hint,
      'difficulty': difficulty.toString().split('.').last,
      'context': context,
    };
  }

  // Get shuffled options for multiple choice questions
  List<String> getShuffledOptions() {
    if (type == ExerciseType.multipleChoice || type == ExerciseType.fillInBlank) {
      final shuffledOptions = List<String>.from(options);
      shuffledOptions.shuffle();
      return shuffledOptions;
    }
    return options;
  }
}

class LearningProgress {
  final int correctAnswers;
  final int totalAttempts;
  final DateTime lastReviewed;
  final int consecutiveCorrect;
  final int masteryLevel; // 0-5, where 5 is mastered
  final DateTime nextReviewDate;

  LearningProgress({
    this.correctAnswers = 0,
    this.totalAttempts = 0,
    DateTime? lastReviewed,
    this.consecutiveCorrect = 0,
    this.masteryLevel = 0,
    DateTime? nextReviewDate,
  }) : 
    lastReviewed = lastReviewed ?? DateTime.now(),
    nextReviewDate = nextReviewDate ?? DateTime.now();

  double get accuracy => totalAttempts > 0 ? correctAnswers / totalAttempts : 0.0;
  
  double get learningPercentage {
    // Start with accuracy-based percentage
    double basePercentage = accuracy * 100;
    
    // If no attempts yet, return 0%
    if (totalAttempts == 0) return 0.0;
    
    // Apply time decay if not recently practiced
    double decayFactor = _calculateDecayFactor();
    
    return (basePercentage * decayFactor).clamp(0.0, 100.0);
  }

  double _calculateDecayFactor() {
    final daysSinceReview = DateTime.now().difference(lastReviewed).inDays;
    
    // No decay for first 7 days
    if (daysSinceReview <= 7) return 1.0;
    
    // Gradual decay after 7 days: 5% per week
    final weeksSinceReview = (daysSinceReview - 7) / 7.0;
    final decayFactor = 1.0 - (weeksSinceReview * 0.05);
    
    return decayFactor.clamp(0.3, 1.0); // Minimum 30% retention
  }

  LearningProgress copyWith({
    int? correctAnswers,
    int? totalAttempts,
    DateTime? lastReviewed,
    int? consecutiveCorrect,
    int? masteryLevel,
    DateTime? nextReviewDate,
  }) {
    return LearningProgress(
      correctAnswers: correctAnswers ?? this.correctAnswers,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    );
  }

  factory LearningProgress.fromJson(Map<String, dynamic> json) {
    return LearningProgress(
      correctAnswers: json['correctAnswers'] ?? 0,
      totalAttempts: json['totalAttempts'] ?? 0,
      lastReviewed: DateTime.parse(json['lastReviewed'] ?? DateTime.now().toIso8601String()),
      consecutiveCorrect: json['consecutiveCorrect'] ?? 0,
      masteryLevel: json['masteryLevel'] ?? 0,
      nextReviewDate: DateTime.parse(json['nextReviewDate'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'correctAnswers': correctAnswers,
      'totalAttempts': totalAttempts,
      'lastReviewed': lastReviewed.toIso8601String(),
      'consecutiveCorrect': consecutiveCorrect,
      'masteryLevel': masteryLevel,
      'nextReviewDate': nextReviewDate.toIso8601String(),
    };
  }
}

class DutchWordExercise {
  final String id;
  final String targetWord;
  final String wordTranslation;
  final String deckId;
  final String deckName;
  final WordCategory category;
  final ExerciseDifficulty difficulty;
  final List<WordExercise> exercises;
  final DateTime createdAt;
  final bool isUserCreated;
  final LearningProgress learningProgress;

  DutchWordExercise({
    required this.id,
    required this.targetWord,
    required this.wordTranslation,
    required this.deckId,
    required this.deckName,
    required this.category,
    required this.difficulty,
    required this.exercises,
    required this.createdAt,
    this.isUserCreated = true,
    LearningProgress? learningProgress,
  }) : learningProgress = learningProgress ?? LearningProgress();

  factory DutchWordExercise.fromJson(Map<String, dynamic> json) {
    return DutchWordExercise(
      id: json['id'] ?? '',
      targetWord: json['targetWord'] ?? '',
      wordTranslation: json['wordTranslation'] ?? '',
      deckId: json['deckId'] ?? 'default',
      deckName: json['deckName'] ?? 'Default Deck',
      category: WordCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
        orElse: () => WordCategory.common,
      ),
      difficulty: ExerciseDifficulty.values.firstWhere(
        (e) => e.toString().split('.').last == json['difficulty'],
        orElse: () => ExerciseDifficulty.beginner,
      ),
      exercises: (json['exercises'] as List?)
          ?.map((e) => WordExercise.fromJson(e))
          .toList() ?? [],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isUserCreated: _parseBool(json['isUserCreated'], defaultValue: true),
      learningProgress: json['learningProgress'] != null 
          ? LearningProgress.fromJson(json['learningProgress'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'targetWord': targetWord,
      'wordTranslation': wordTranslation,
      'deckId': deckId,
      'deckName': deckName,
      'category': category.toString().split('.').last,
      'difficulty': difficulty.toString().split('.').last,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isUserCreated': isUserCreated,
      'learningProgress': learningProgress.toJson(),
    };
  }

  // Method to update learning progress after an exercise attempt
  DutchWordExercise updateProgress({required bool wasCorrect}) {
    final newProgress = learningProgress.copyWith(
      correctAnswers: learningProgress.correctAnswers + (wasCorrect ? 1 : 0),
      totalAttempts: learningProgress.totalAttempts + 1,
      lastReviewed: DateTime.now(),
      consecutiveCorrect: wasCorrect 
          ? learningProgress.consecutiveCorrect + 1 
          : 0,
      masteryLevel: _calculateNewMasteryLevel(wasCorrect),
      nextReviewDate: _calculateNextReviewDate(wasCorrect),
    );

    return DutchWordExercise(
      id: id,
      targetWord: targetWord,
      wordTranslation: wordTranslation,
      deckId: deckId,
      deckName: deckName,
      category: category,
      difficulty: difficulty,
      exercises: exercises,
      createdAt: createdAt,
      isUserCreated: isUserCreated,
      learningProgress: newProgress,
    );
  }

  int _calculateNewMasteryLevel(bool wasCorrect) {
    int currentLevel = learningProgress.masteryLevel;
    
    if (wasCorrect) {
      // Increase mastery level based on consecutive correct answers
      if (learningProgress.consecutiveCorrect >= 3 && currentLevel < 5) {
        return currentLevel + 1;
      }
    } else {
      // Decrease mastery level on incorrect answers
      if (currentLevel > 0) {
        return currentLevel - 1;
      }
    }
    
    return currentLevel;
  }

  DateTime _calculateNextReviewDate(bool wasCorrect) {
    final now = DateTime.now();
    
    if (wasCorrect) {
      // Spaced repetition: longer intervals for higher mastery levels
      final daysToAdd = (learningProgress.masteryLevel + 1) * 2;
      return now.add(Duration(days: daysToAdd));
    } else {
      // Review soon if incorrect
      return now.add(const Duration(days: 1));
    }
  }

  // Helper method to safely parse boolean values
  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      final lowerValue = value.toLowerCase();
      if (lowerValue == 'true' || lowerValue == '1') return true;
      if (lowerValue == 'false' || lowerValue == '0') return false;
    }
    if (value is int) return value != 0;
    return defaultValue;
  }
}

class DutchWordExerciseImport {
  final ImportMetadata metadata;
  final List<DutchWordExercise> exercises;

  DutchWordExerciseImport({
    required this.metadata,
    required this.exercises,
  });

  factory DutchWordExerciseImport.fromJson(Map<String, dynamic> json) {
    return DutchWordExerciseImport(
      metadata: ImportMetadata.fromJson(json['metadata'] ?? {}),
      exercises: (json['exercises'] as List?)
          ?.map((e) => DutchWordExercise.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata.toJson(),
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }
}

class ImportMetadata {
  final String version;
  final DateTime exportDate;
  final String description;
  final String author;

  ImportMetadata({
    required this.version,
    required this.exportDate,
    required this.description,
    required this.author,
  });

  factory ImportMetadata.fromJson(Map<String, dynamic> json) {
    return ImportMetadata(
      version: json['version'] ?? '1.0',
      exportDate: DateTime.parse(json['exportDate'] ?? DateTime.now().toIso8601String()),
      description: json['description'] ?? '',
      author: json['author'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportDate': exportDate.toIso8601String(),
      'description': description,
      'author': author,
    };
  }
}

class WordExerciseStatistics {
  final int totalWordExercises;
  final int totalQuestions;
  final int userCreated;
  final int imported;
  final Map<String, int> categoryBreakdown;
  final Map<String, int> difficultyBreakdown;
  final DateTime lastActivity;

  WordExerciseStatistics({
    required this.totalWordExercises,
    required this.totalQuestions,
    required this.userCreated,
    required this.imported,
    required this.categoryBreakdown,
    required this.difficultyBreakdown,
    required this.lastActivity,
  });
}

// Extension to provide example data
extension DutchWordExerciseExamples on DutchWordExercise {
  static List<DutchWordExercise> get examples {
    return [
      DutchWordExercise(
        id: '1',
        targetWord: 'terecht',
        wordTranslation: 'justified',
        deckId: 'common_words',
        deckName: 'Common Words',
        category: WordCategory.common,
        difficulty: ExerciseDifficulty.intermediate,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        learningProgress: LearningProgress(
          correctAnswers: 8,
          totalAttempts: 10,
          lastReviewed: DateTime.now().subtract(const Duration(days: 2)),
          consecutiveCorrect: 3,
          masteryLevel: 3,
          nextReviewDate: DateTime.now().add(const Duration(days: 8)),
        ),
        exercises: [
          WordExercise(
            id: '1-1',
            type: ExerciseType.fillInBlank,
            prompt: 'Zijn woede was volledig _____.',
            options: ['terecht', 'terechte', 'terechten', 'terechts'],
            correctAnswer: 'terecht',
            explanation: '"Terecht" means "justified" and is used as an adverb here.',
            difficulty: ExerciseDifficulty.intermediate,
          ),
          WordExercise(
            id: '1-2',
            type: ExerciseType.multipleChoice,
            prompt: 'When someone receives a punishment they deserve, it is:',
            options: ['wrong', 'justified', 'unfair', 'unnecessary'],
            correctAnswer: 'justified',
            explanation: 'When something is "terecht", it means it is justified or deserved.',
            difficulty: ExerciseDifficulty.beginner,
          ),
          WordExercise(
            id: '1-3',
            type: ExerciseType.sentenceBuilding,
            prompt: 'Build the correct Dutch sentence: He was justifiably angry.',
            options: ['hij', 'was', 'terecht', 'boos'],
            correctAnswer: 'hij was terecht boos',
            explanation: 'This sentence means "He was justifiably angry." The word order is correct in Dutch.',
            difficulty: ExerciseDifficulty.advanced,
          ),
          WordExercise(
            id: '1-4',
            type: ExerciseType.fillInBlank,
            prompt: 'De kritiek was _____ en nuttig.',
            options: ['terecht', 'terechte', 'terechten', 'terechts'],
            correctAnswer: 'terecht',
            explanation: '"Terecht" is used as an adjective meaning "justified" here.',
            difficulty: ExerciseDifficulty.intermediate,
          ),
          WordExercise(
            id: '1-5',
            type: ExerciseType.multipleChoice,
            prompt: 'Which situation describes something that is "terecht"?',
            options: ['A student failing without studying', 'A driver getting a ticket for speeding', 'A person winning the lottery', 'A child getting a gift for no reason'],
            correctAnswer: 'A driver getting a ticket for speeding',
            explanation: 'Getting a ticket for speeding is "terecht" because it is a justified consequence.',
            difficulty: ExerciseDifficulty.beginner,
          ),
          WordExercise(
            id: '1-6',
            type: ExerciseType.fillInBlank,
            prompt: 'Ze kreeg _____ een boete voor te hard rijden.',
            options: ['terecht', 'terechte', 'terechten', 'terechts'],
            correctAnswer: 'terecht',
            explanation: '"Terecht" means "rightfully" in this context.',
            difficulty: ExerciseDifficulty.intermediate,
          ),
          WordExercise(
            id: '1-7',
            type: ExerciseType.sentenceBuilding,
            prompt: 'Build the correct Dutch sentence: The criticism was justified.',
            options: ['de', 'kritiek', 'was', 'terecht'],
            correctAnswer: 'de kritiek was terecht',
            explanation: 'This sentence means "The criticism was justified." The word order follows Dutch grammar rules.',
            difficulty: ExerciseDifficulty.advanced,
          ),
        ],
      ),
      DutchWordExercise(
        id: '2',
        targetWord: 'eigenlijk',
        wordTranslation: 'actually',
        deckId: 'common_words',
        deckName: 'Common Words',
        category: WordCategory.common,
        difficulty: ExerciseDifficulty.beginner,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        learningProgress: LearningProgress(
          correctAnswers: 6,
          totalAttempts: 8,
          lastReviewed: DateTime.now().subtract(const Duration(days: 1)),
          consecutiveCorrect: 2,
          masteryLevel: 2,
          nextReviewDate: DateTime.now().add(const Duration(days: 6)),
        ),
        exercises: [
          WordExercise(
            id: '2-1',
            type: ExerciseType.fillInBlank,
            prompt: '_____ woon ik in Amsterdam.',
            options: ['Eigenlijk', 'Eigenlijke', 'Eigenlijken', 'Eigenlijks'],
            correctAnswer: 'Eigenlijk',
            explanation: '"Eigenlijk" means "actually" and is used as an adverb.',
            difficulty: ExerciseDifficulty.beginner,
          ),
          WordExercise(
            id: '2-2',
            type: ExerciseType.multipleChoice,
            prompt: 'When you want to correct a previous statement, you might say:',
            options: ['maybe', 'actually', 'never', 'always'],
            correctAnswer: 'actually',
            explanation: '"Eigenlijk" is used to correct or clarify a previous statement, meaning "actually" or "in fact".',
            difficulty: ExerciseDifficulty.beginner,
          ),
          WordExercise(
            id: '2-3',
            type: ExerciseType.fillInBlank,
            prompt: '_____ ben ik niet zo moe.',
            options: ['Eigenlijk', 'Eigenlijke', 'Eigenlijken', 'Eigenlijks'],
            correctAnswer: 'Eigenlijk',
            explanation: '"Eigenlijk" is used to express a contrast or correction.',
            difficulty: ExerciseDifficulty.intermediate,
          ),
        ],
      ),
      DutchWordExercise(
        id: '3',
        targetWord: 'misschien',
        wordTranslation: 'maybe',
        deckId: 'common_words',
        deckName: 'Common Words',
        category: WordCategory.common,
        difficulty: ExerciseDifficulty.beginner,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        learningProgress: LearningProgress(
          correctAnswers: 12,
          totalAttempts: 15,
          lastReviewed: DateTime.now().subtract(const Duration(days: 5)),
          consecutiveCorrect: 5,
          masteryLevel: 4,
          nextReviewDate: DateTime.now().add(const Duration(days: 10)),
        ),
        exercises: [
          WordExercise(
            id: '3-1',
            type: ExerciseType.fillInBlank,
            prompt: '_____ kom ik morgen langs.',
            options: ['Misschien', 'Misschiene', 'Misschiens', 'Misschienes'],
            correctAnswer: 'Misschien',
            explanation: '"Misschien" means "maybe" or "perhaps".',
            difficulty: ExerciseDifficulty.beginner,
          ),
          WordExercise(
            id: '3-2',
            type: ExerciseType.multipleChoice,
            prompt: 'When you are not sure about something, you might say:',
            options: ['definitely', 'maybe', 'never', 'always'],
            correctAnswer: 'maybe',
            explanation: '"Misschien" expresses uncertainty or possibility, similar to "maybe" or "perhaps".',
            difficulty: ExerciseDifficulty.beginner,
          ),
        ],
      ),
      DutchWordExercise(
        id: '4',
        targetWord: 'waarschijnlijk',
        wordTranslation: 'probably',
        deckId: 'common_words',
        deckName: 'Common Words',
        category: WordCategory.common,
        difficulty: ExerciseDifficulty.intermediate,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        learningProgress: LearningProgress(
          correctAnswers: 3,
          totalAttempts: 5,
          lastReviewed: DateTime.now().subtract(const Duration(hours: 2)),
          consecutiveCorrect: 1,
          masteryLevel: 1,
          nextReviewDate: DateTime.now().add(const Duration(days: 4)),
        ),
        exercises: [
          WordExercise(
            id: '4-1',
            type: ExerciseType.fillInBlank,
            prompt: 'Het gaat _____ regenen.',
            options: ['waarschijnlijk', 'waarschijnlijke', 'waarschijnlijken', 'waarschijnlijks'],
            correctAnswer: 'waarschijnlijk',
            explanation: '"Waarschijnlijk" means "probably" and is used as an adverb.',
            difficulty: ExerciseDifficulty.intermediate,
          ),
          WordExercise(
            id: '4-2',
            type: ExerciseType.multipleChoice,
            prompt: 'When something is very likely to happen, you would say:',
            options: ['definitely', 'maybe', 'probably', 'never'],
            correctAnswer: 'probably',
            explanation: '"Waarschijnlijk" indicates a high probability, meaning "probably" or "likely".',
            difficulty: ExerciseDifficulty.beginner,
          ),
        ],
      ),
      // Add a new word with 0% progress to show the starting state
      DutchWordExercise(
        id: '5',
        targetWord: 'nieuw',
        wordTranslation: 'new',
        deckId: 'common_words',
        deckName: 'Common Words',
        category: WordCategory.common,
        difficulty: ExerciseDifficulty.beginner,
        createdAt: DateTime.now(),
        learningProgress: LearningProgress(
          correctAnswers: 0,
          totalAttempts: 0,
          lastReviewed: DateTime.now(),
          consecutiveCorrect: 0,
          masteryLevel: 0,
          nextReviewDate: DateTime.now().add(const Duration(days: 1)),
        ),
        exercises: [
          WordExercise(
            id: '5-1',
            type: ExerciseType.fillInBlank,
            prompt: 'Dit is een _____ auto.',
            options: ['nieuw', 'nieuwe', 'nieuwen', 'nieuws'],
            correctAnswer: 'nieuw',
            explanation: '"Nieuw" means "new" and is used as an adjective here.',
            difficulty: ExerciseDifficulty.beginner,
          ),
        ],
      ),
    ];
  }
} 