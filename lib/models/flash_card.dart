import 'dart:math';
import 'package:uuid/uuid.dart';
import 'learning_mastery.dart';

class FlashCard {
  final String id;
  String word;
  String definition; // Translation
  String example;
  String exampleTranslation; // Translation of the example sentence
  Set<String> deckIds;
  int successCount;
  DateTime dateCreated;
  DateTime lastModified;
  bool isPublic; // Whether this card is visible to friends
  bool? isReview; // Whether this card is flagged for the review deck
  
  // CloudKit tracking
  String? cloudKitRecordName;
  
  // Enhanced learning mastery system
  LearningMastery learningMastery;
  
  // Additional grammatical fields
  String article; // "het" or "de" for nouns
  String plural; // Plural form for nouns
  String presentTense; // Present Tense - Tegenwoordige Tijd
  String pastTense; // Past Tense - Verleden Tijd
  String perfectTense; // Perfect Tense - Voltooide Tijd
  
  FlashCard({
    String? id,
    required this.word,
    String? definition,
    String? example,
    String? exampleTranslation,
    Set<String>? deckIds,
    this.successCount = 0,
    DateTime? dateCreated,
    DateTime? lastModified,
    this.isPublic = false,
    this.cloudKitRecordName,
    LearningMastery? learningMastery,
    this.article = '',
    this.plural = '',
    this.presentTense = '',
    this.pastTense = '',
    this.perfectTense = '',
    this.isReview = false,
  }) : 
    id = id ?? const Uuid().v4(),
    definition = definition ?? '',
    example = example ?? '',
    exampleTranslation = exampleTranslation ?? '',
    deckIds = deckIds ?? {},
    dateCreated = dateCreated ?? DateTime.now(),
    lastModified = lastModified ?? DateTime.now(),
    learningMastery = learningMastery ?? _createNewLearningMastery();
  
  // Enhanced learning percentage using the new mastery system
  int get learningPercentage {
    return learningMastery.learningPercentage.round();
  }
  
  // Create a new LearningMastery with no initial XP for new cards
  static LearningMastery _createNewLearningMastery() {
    final mastery = LearningMastery();
    // Don't give new cards any XP - they should start at 0% learned
    return mastery;
  }
  
  // Check if card is fully learned (based on mastery state)
  bool get isFullyLearned {
    return learningMastery.currentState == LearningState.mastered || 
           learningMastery.currentState == LearningState.expert;
  }
  
  // MARK: - SRS Computed Properties (delegated to LearningMastery)
  
  // Check if card is due for review
  bool get isDueForReview => learningMastery.isDueForReview;
  
  // Check if card is new (never reviewed)
  bool get isNew => learningMastery.isNew;
  
  // Check if card is in learning phase (levels 1-3)
  bool get isLearning => learningMastery.isLearning;
  
  // Check if card is in review phase (levels 4+)
  bool get isReviewing => learningMastery.isReviewing;
  
  // Get the current interval in days
  int get currentInterval => learningMastery.currentInterval;
  
  // Get days until next review
  int? get daysUntilReview => learningMastery.daysUntilReview;
  
  // Get current learning state
  LearningState get learningState => learningMastery.currentState;
  
  // Get SRS level
  int get srsLevel => learningMastery.srsLevel;
  
  // Daily study limit features (now HP system)
  bool get hasReachedDailyLimit => learningMastery.hasReachedDailyLimit;
  bool get canBeStudiedToday => learningMastery.canBeStudiedToday;
  int get timesStudiedToday => learningMastery.timesStudiedToday;
  int get remainingStudyAttemptsToday => learningMastery.remainingStudyAttemptsToday;
  static int get dailyStudyLimit => LearningMastery.dailyStudyLimit;
  
  // HP (Health Points) system
  int get currentHP => learningMastery.currentHP;
  int get maxHP => learningMastery.maxHP;
  bool get isDefeated => learningMastery.isDefeated;
  double get hpPercentage => learningMastery.hpPercentage;
  String get hpStatus => learningMastery.hpStatus;
  
  /// Check if card is available for study (has HP and can still gain XP)
  bool get isAvailableForStudy => !isDefeated && learningMastery.currentXP < 1100;
  
  // Legacy getters for backward compatibility
  int get timesShown => learningMastery.totalAttempts;
  int get timesCorrect => learningMastery.totalCorrect;
  int get consecutiveCorrect => learningMastery.consecutiveCorrect;
  int get consecutiveIncorrect => learningMastery.consecutiveIncorrect;
  double get easeFactor => learningMastery.easeFactor;
  DateTime? get lastReviewDate => learningMastery.lastReviewDate;
  DateTime? get nextReviewDate => learningMastery.nextReviewDate;
  int get totalReviews => learningMastery.totalReviews;
  
  // MARK: - Enhanced SRS Methods
  
  /// Mark answer as correct for specific game difficulty
  void markCorrect(GameDifficulty difficulty) {
    learningMastery.markCorrect(difficulty);
    lastModified = DateTime.now();
  }
  
  /// Mark answer as incorrect for specific game difficulty
  void markIncorrect(GameDifficulty difficulty) {
    learningMastery.markIncorrect(difficulty);
    lastModified = DateTime.now();
  }

  /// Mark correct with an explicit exercise type string (for precise game-usage tracking)
  void markCorrectAs(String exerciseType, [GameDifficulty difficulty = GameDifficulty.medium]) {
    learningMastery.markCorrectAs(exerciseType, difficulty);
    lastModified = DateTime.now();
  }

  /// Mark incorrect with an explicit exercise type string (for precise game-usage tracking)
  void markIncorrectAs(String exerciseType, [GameDifficulty difficulty = GameDifficulty.medium]) {
    learningMastery.markIncorrectAs(exerciseType, difficulty);
    lastModified = DateTime.now();
  }
  

  
  // MARK: - JSON Serialization
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'definition': definition,
      'example': example,
      'exampleTranslation': exampleTranslation,
      'deckIds': deckIds.toList(),
      'successCount': successCount,
      'dateCreated': dateCreated.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'isPublic': isPublic,
      'cloudKitRecordName': cloudKitRecordName,
      'learningMastery': learningMastery.toJson(),
      'article': article,
      'plural': plural,
      'presentTense': presentTense,
      'pastTense': pastTense,
      'perfectTense': perfectTense,
      'isReview': isReview,
    };
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }
  
  factory FlashCard.fromJson(Map<String, dynamic> json) {
    return FlashCard(
      id: json['id'],
      word: json['word'] ?? '',
      definition: json['definition'] ?? '',
      example: json['example'] ?? '',
      exampleTranslation: json['exampleTranslation'] ?? '',
      deckIds: Set<String>.from(json['deckIds'] ?? []),
      successCount: json['successCount'] ?? 0,
      dateCreated: json['dateCreated'] != null 
          ? DateTime.parse(json['dateCreated']) 
          : DateTime.now(),
      lastModified: json['lastModified'] != null 
          ? DateTime.parse(json['lastModified']) 
          : DateTime.now(),
      isPublic: json['isPublic'] ?? false,
      cloudKitRecordName: json['cloudKitRecordName'],
      learningMastery: json['learningMastery'] != null
          ? LearningMastery.fromJson(json['learningMastery'])
          : null,
      article: json['article'] ?? '',
      plural: json['plural'] ?? '',
      presentTense: json['presentTense'] ?? '',
      pastTense: json['pastTense'] ?? '',
      // Map old pastParticiple to the new perfectTense
      perfectTense: json['perfectTense'] ?? json['pastParticiple'] ?? '',
      isReview: json['isReview'] ?? false,
    );
  }
  
  // MARK: - Copy Methods
  
  FlashCard copyWith({
    String? word,
    String? definition,
    String? example,
    String? exampleTranslation,
    Set<String>? deckIds,
    int? successCount,
    DateTime? dateCreated,
    DateTime? lastModified,
    bool? isPublic,
    String? cloudKitRecordName,
    LearningMastery? learningMastery,
    String? article,
    String? plural,
    String? presentTense,
    String? pastTense,
    String? perfectTense,
    bool? isReview,
  }) {
    return FlashCard(
      id: id,
      word: word ?? this.word,
      definition: definition ?? this.definition,
      example: example ?? this.example,
      exampleTranslation: exampleTranslation ?? this.exampleTranslation,
      deckIds: deckIds ?? Set<String>.from(this.deckIds),
      successCount: successCount ?? this.successCount,
      dateCreated: dateCreated ?? this.dateCreated,
      lastModified: lastModified ?? this.lastModified,
      isPublic: isPublic ?? this.isPublic,
      cloudKitRecordName: cloudKitRecordName ?? this.cloudKitRecordName,
      learningMastery: learningMastery ?? this.learningMastery,
      article: article ?? this.article,
      plural: plural ?? this.plural,
      presentTense: presentTense ?? this.presentTense,
      pastTense: pastTense ?? this.pastTense,
      perfectTense: perfectTense ?? this.perfectTense,
      isReview: isReview ?? this.isReview,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlashCard && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'FlashCard(id: $id, word: $word, definition: $definition)';
  }
} 