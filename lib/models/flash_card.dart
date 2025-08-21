import 'dart:math';
import 'package:uuid/uuid.dart';
import 'learning_mastery.dart';

class FlashCard {
  final String id;
  String word;
  String definition; // Translation
  String example;
  Set<String> deckIds;
  int successCount;
  DateTime dateCreated;
  DateTime lastModified;
  
  // CloudKit tracking
  String? cloudKitRecordName;
  
  // Enhanced learning mastery system
  LearningMastery learningMastery;
  
  // Additional grammatical fields
  String article; // "het" or "de" for nouns
  String plural; // Plural form for nouns
  String pastTense; // Past tense form
  String futureTense; // Future tense form
  String pastParticiple; // Past participle form
  
  FlashCard({
    String? id,
    required this.word,
    String? definition,
    String? example,
    Set<String>? deckIds,
    this.successCount = 0,
    DateTime? dateCreated,
    DateTime? lastModified,
    this.cloudKitRecordName,
    LearningMastery? learningMastery,
    this.article = '',
    this.plural = '',
    this.pastTense = '',
    this.futureTense = '',
    this.pastParticiple = '',
  }) : 
    id = id ?? const Uuid().v4(),
    definition = definition ?? '',
    example = example ?? '',
    deckIds = deckIds ?? {},
    dateCreated = dateCreated ?? DateTime.now(),
    lastModified = lastModified ?? DateTime.now(),
    learningMastery = learningMastery ?? LearningMastery();
  
  // Enhanced learning percentage using the new mastery system
  int get learningPercentage {
    return learningMastery.learningPercentage.round();
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
  
  // Legacy getters for backward compatibility
  int get timesShown => learningMastery.totalAttempts;
  int get timesCorrect => learningMastery.totalCorrect;
  int get consecutiveCorrect => learningMastery.consecutiveCorrect;
  int get consecutiveIncorrect => learningMastery.consecutiveIncorrect;
  double get easeFactor => learningMastery.easeFactor;
  DateTime? get lastReviewDate => learningMastery.lastReviewDate;
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
  

  
  // MARK: - JSON Serialization
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'definition': definition,
      'example': example,
      'deckIds': deckIds.toList(),
      'successCount': successCount,
      'dateCreated': dateCreated.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'cloudKitRecordName': cloudKitRecordName,
      'learningMastery': learningMastery.toJson(),
      'article': article,
      'plural': plural,
      'pastTense': pastTense,
      'futureTense': futureTense,
      'pastParticiple': pastParticiple,
    };
  }
  
  factory FlashCard.fromJson(Map<String, dynamic> json) {
    return FlashCard(
      id: json['id'],
      word: json['word'] ?? '',
      definition: json['definition'] ?? '',
      example: json['example'] ?? '',
      deckIds: Set<String>.from(json['deckIds'] ?? []),
      successCount: json['successCount'] ?? 0,
      dateCreated: json['dateCreated'] != null 
          ? DateTime.parse(json['dateCreated']) 
          : DateTime.now(),
      lastModified: json['lastModified'] != null 
          ? DateTime.parse(json['lastModified']) 
          : DateTime.now(),
      cloudKitRecordName: json['cloudKitRecordName'],
      learningMastery: json['learningMastery'] != null 
          ? LearningMastery.fromJson(json['learningMastery'])
          : null,
      article: json['article'] ?? '',
      plural: json['plural'] ?? '',
      pastTense: json['pastTense'] ?? '',
      futureTense: json['futureTense'] ?? '',
      pastParticiple: json['pastParticiple'] ?? '',
    );
  }
  
  // MARK: - Copy Methods
  
  FlashCard copyWith({
    String? word,
    String? definition,
    String? example,
    Set<String>? deckIds,
    int? successCount,
    DateTime? dateCreated,
    DateTime? lastModified,
    String? cloudKitRecordName,
    LearningMastery? learningMastery,
    String? article,
    String? plural,
    String? pastTense,
    String? futureTense,
    String? pastParticiple,
  }) {
    return FlashCard(
      id: id,
      word: word ?? this.word,
      definition: definition ?? this.definition,
      example: example ?? this.example,
      deckIds: deckIds ?? this.deckIds,
      successCount: successCount ?? this.successCount,
      dateCreated: dateCreated ?? this.dateCreated,
      lastModified: lastModified ?? this.lastModified,
      cloudKitRecordName: cloudKitRecordName ?? this.cloudKitRecordName,
      learningMastery: learningMastery ?? this.learningMastery,
      article: article ?? this.article,
      plural: plural ?? this.plural,
      pastTense: pastTense ?? this.pastTense,
      futureTense: futureTense ?? this.futureTense,
      pastParticiple: pastParticiple ?? this.pastParticiple,
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