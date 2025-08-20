import 'dart:math';
import 'package:uuid/uuid.dart';

class Phrase {
  final String id;
  String phrase; // The Dutch phrase
  String translation; // The English translation
  DateTime dateCreated;
  DateTime lastModified;
  
  // CloudKit tracking
  String? cloudKitRecordName;
  
  // Learning statistics
  int timesShown;
  int timesCorrect;
  
  // Spaced Repetition System (SRS) fields
  int srsLevel; // 0 = new, 1-10 = learning levels
  DateTime? nextReviewDate; // When this phrase should be reviewed next
  int consecutiveCorrect; // Streak of correct answers
  int consecutiveIncorrect; // Streak of incorrect answers
  double easeFactor; // Multiplier for interval (starts at 2.5)
  DateTime? lastReviewDate; // When this phrase was last reviewed
  int totalReviews; // Total number of reviews
  
  Phrase({
    String? id,
    required this.phrase,
    required this.translation,
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
  }) : 
    id = id ?? const Uuid().v4(),
    dateCreated = dateCreated ?? DateTime.now(),
    lastModified = lastModified ?? DateTime.now();
  
  // Computed property for learning percentage
  int get learningPercentage {
    // Start with accuracy-based percentage
    if (timesShown == 0) return 0; // New phrases start at 0%
    
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
  
  // Check if phrase is fully learned (5+ correct answers)
  bool get isFullyLearned {
    return timesCorrect >= 5;
  }
  
  // MARK: - SRS Computed Properties
  
  // Check if phrase is due for review
  bool get isDueForReview {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }
  
  // Check if phrase is new (never reviewed)
  bool get isNew {
    return srsLevel == 0 && totalReviews == 0;
  }
  
  // Check if phrase is in learning phase (levels 1-3)
  bool get isLearning {
    return srsLevel >= 1 && srsLevel <= 3;
  }
  
  // Check if phrase is in review phase (levels 4+)
  bool get isReviewing {
    return srsLevel >= 4;
  }
  
  // Get the current interval in days
  int get currentInterval {
    switch (srsLevel) {
      case 0: return 0; // New phrase
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
      'phrase': phrase,
      'translation': translation,
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
    };
  }
  
  factory Phrase.fromJson(Map<String, dynamic> json) {
    return Phrase(
      id: json['id'],
      phrase: json['phrase'] ?? '',
      translation: json['translation'] ?? '',
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
    );
  }
  
  // MARK: - Copy Methods
  
  Phrase copyWith({
    String? phrase,
    String? translation,
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
  }) {
    return Phrase(
      id: id,
      phrase: phrase ?? this.phrase,
      translation: translation ?? this.translation,
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
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Phrase && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'Phrase(id: $id, phrase: $phrase, translation: $translation)';
  }
}
