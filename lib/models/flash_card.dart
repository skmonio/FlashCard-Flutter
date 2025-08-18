import 'dart:math';
import 'package:uuid/uuid.dart';

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
  
  // Learning statistics
  int timesShown;
  int timesCorrect;
  
  // Spaced Repetition System (SRS) fields
  int srsLevel; // 0 = new, 1-10 = learning levels
  DateTime? nextReviewDate; // When this card should be reviewed next
  int consecutiveCorrect; // Streak of correct answers
  int consecutiveIncorrect; // Streak of incorrect answers
  double easeFactor; // Multiplier for interval (starts at 2.5)
  DateTime? lastReviewDate; // When this card was last reviewed
  int totalReviews; // Total number of reviews (not just shown)
  
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
    this.timesShown = 0,
    this.timesCorrect = 0,
    this.srsLevel = 0,
    this.nextReviewDate,
    this.consecutiveCorrect = 0,
    this.consecutiveIncorrect = 0,
    this.easeFactor = 2.5,
    this.lastReviewDate,
    this.totalReviews = 0,
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
    lastModified = lastModified ?? DateTime.now();
  
  // Computed property for learning percentage
  int get learningPercentage {
    // Start with accuracy-based percentage
    if (timesShown == 0) return 0; // New cards start at 0%
    
    double basePercentage = (timesCorrect / timesShown) * 100;
    
    // Apply time decay if not recently reviewed
    double decayFactor = _calculateDecayFactor();
    
    return (basePercentage * decayFactor).clamp(0, 100).round();
  }
  
  // Calculate decay factor based on time since last review
  double _calculateDecayFactor() {
    if (lastReviewDate == null) return 1.0;
    
    final daysSinceReview = DateTime.now().difference(lastReviewDate!).inDays;
    
    // No decay for first 7 days
    if (daysSinceReview <= 7) return 1.0;
    
    // Gradual decay after 7 days: 5% per week
    final weeksSinceReview = (daysSinceReview - 7) / 7.0;
    final decayFactor = 1.0 - (weeksSinceReview * 0.05);
    
    return decayFactor.clamp(0.3, 1.0); // Minimum 30% retention
  }
  
  // Check if card is fully learned (5+ correct answers)
  bool get isFullyLearned {
    return timesCorrect >= 5;
  }
  
  // MARK: - SRS Computed Properties
  
  // Check if card is due for review
  bool get isDueForReview {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }
  
  // Check if card is new (never reviewed)
  bool get isNew {
    return srsLevel == 0 && totalReviews == 0;
  }
  
  // Check if card is in learning phase (levels 1-3)
  bool get isLearning {
    return srsLevel >= 1 && srsLevel <= 3;
  }
  
  // Check if card is in review phase (levels 4+)
  bool get isReviewing {
    return srsLevel >= 4;
  }
  
  // Get the current interval in days
  int get currentInterval {
    switch (srsLevel) {
      case 0: return 0; // New card
      case 1: return 1; // 1 day
      case 2: return 6; // 6 days
      case 3: return 15; // 15 days
      default: return (pow(easeFactor, srsLevel - 3)).round();
    }
  }
  
  // Get days until next review
  int? get daysUntilReview {
    if (nextReviewDate == null) return null;
    final now = DateTime.now();
    return nextReviewDate!.difference(now).inDays;
  }
  
  // MARK: - SRS Methods
  
  void markCorrect() {
    timesShown++;
    timesCorrect++;
    consecutiveCorrect++;
    consecutiveIncorrect = 0;
    totalReviews++;
    lastReviewDate = DateTime.now();
    lastModified = DateTime.now();
    
    // Update SRS level
    if (srsLevel < 10) {
      srsLevel++;
    }
    
    // Calculate next review date
    final interval = currentInterval;
    nextReviewDate = DateTime.now().add(Duration(days: interval));
    
    // Update ease factor (simplified algorithm)
    if (consecutiveCorrect >= 3) {
      easeFactor = (easeFactor + 0.1).clamp(1.3, 2.5);
    }
  }
  
  void markIncorrect() {
    timesShown++;
    consecutiveIncorrect++;
    consecutiveCorrect = 0;
    totalReviews++;
    lastReviewDate = DateTime.now();
    lastModified = DateTime.now();
    
    // Reset SRS level to 1 if it was higher
    if (srsLevel > 1) {
      srsLevel = 1;
    }
    
    // Calculate next review date (1 day for incorrect)
    nextReviewDate = DateTime.now().add(const Duration(days: 1));
    
    // Decrease ease factor
    easeFactor = (easeFactor - 0.2).clamp(1.3, 2.5);
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
      'timesShown': timesShown,
      'timesCorrect': timesCorrect,
      'srsLevel': srsLevel,
      'nextReviewDate': nextReviewDate?.toIso8601String(),
      'consecutiveCorrect': consecutiveCorrect,
      'consecutiveIncorrect': consecutiveIncorrect,
      'easeFactor': easeFactor,
      'lastReviewDate': lastReviewDate?.toIso8601String(),
      'totalReviews': totalReviews,
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
      timesShown: json['timesShown'] ?? 0,
      timesCorrect: json['timesCorrect'] ?? 0,
      srsLevel: json['srsLevel'] ?? 0,
      nextReviewDate: json['nextReviewDate'] != null 
          ? DateTime.parse(json['nextReviewDate']) 
          : null,
      consecutiveCorrect: json['consecutiveCorrect'] ?? 0,
      consecutiveIncorrect: json['consecutiveIncorrect'] ?? 0,
      easeFactor: (json['easeFactor'] ?? 2.5).toDouble(),
      lastReviewDate: json['lastReviewDate'] != null 
          ? DateTime.parse(json['lastReviewDate']) 
          : null,
      totalReviews: json['totalReviews'] ?? 0,
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
    int? timesShown,
    int? timesCorrect,
    int? srsLevel,
    DateTime? nextReviewDate,
    int? consecutiveCorrect,
    int? consecutiveIncorrect,
    double? easeFactor,
    DateTime? lastReviewDate,
    int? totalReviews,
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
      timesShown: timesShown ?? this.timesShown,
      timesCorrect: timesCorrect ?? this.timesCorrect,
      srsLevel: srsLevel ?? this.srsLevel,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      consecutiveIncorrect: consecutiveIncorrect ?? this.consecutiveIncorrect,
      easeFactor: easeFactor ?? this.easeFactor,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      totalReviews: totalReviews ?? this.totalReviews,
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