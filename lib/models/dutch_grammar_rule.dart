import 'package:flutter/foundation.dart';

// MARK: - Grammar Rule Types
enum GrammarRuleType {
  verbConjugation,
  sentenceStructure,
  pluralization,
  pronunciation,
  spelling,
  tenses,
  wordOrder,
  adjectives,
  prepositions,
  negation,
  articles,
}

// MARK: - Language Levels
enum LanguageLevel {
  a1,
  a2,
  b1,
  b2,
  c1,
  c2,
}

// MARK: - Exercise Types
enum ExerciseType {
  multipleChoice,
  translation,
  fillInTheBlank,
  sentenceOrder,
  trueFalse,
}

// MARK: - Grammar Rule Structure
class DutchGrammarRule {
  final String id;
  final String title;
  final GrammarRuleType type;
  final LanguageLevel level;
  final String explanation;
  final List<String> keyPoints;
  final List<GrammarExample> examples;
  final List<GrammarExercise> exercises;
  final List<CommonMistake> commonMistakes;
  final List<String> tips;
  final List<String> relatedRules;

  const DutchGrammarRule({
    required this.id,
    required this.title,
    required this.type,
    required this.level,
    required this.explanation,
    required this.keyPoints,
    required this.examples,
    required this.exercises,
    required this.commonMistakes,
    required this.tips,
    required this.relatedRules,
  });

  factory DutchGrammarRule.fromJson(Map<String, dynamic> json) {
    return DutchGrammarRule(
      id: json['id'] as String,
      title: json['title'] as String,
      type: GrammarRuleType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      level: LanguageLevel.values.firstWhere(
        (e) => e.toString().split('.').last == json['level'],
      ),
      explanation: json['explanation'] as String,
      keyPoints: List<String>.from(json['keyPoints']),
      examples: (json['examples'] as List)
          .map((e) => GrammarExample.fromJson(e))
          .toList(),
      exercises: (json['exercises'] as List)
          .map((e) => GrammarExercise.fromJson(e))
          .toList(),
      commonMistakes: (json['commonMistakes'] as List)
          .map((e) => CommonMistake.fromJson(e))
          .toList(),
      tips: List<String>.from(json['tips']),
      relatedRules: List<String>.from(json['relatedRules']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.toString().split('.').last,
      'level': level.toString().split('.').last,
      'explanation': explanation,
      'keyPoints': keyPoints,
      'examples': examples.map((e) => e.toJson()).toList(),
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'commonMistakes': commonMistakes.map((e) => e.toJson()).toList(),
      'tips': tips,
      'relatedRules': relatedRules,
    };
  }
}

class GrammarExample {
  final String dutch;
  final String english;
  final String? breakdown;
  final String? audioHint;

  const GrammarExample({
    required this.dutch,
    required this.english,
    this.breakdown,
    this.audioHint,
  });

  factory GrammarExample.fromJson(Map<String, dynamic> json) {
    return GrammarExample(
      dutch: json['dutch'] as String,
      english: json['english'] as String,
      breakdown: json['breakdown'] as String?,
      audioHint: json['audioHint'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dutch': dutch,
      'english': english,
      'breakdown': breakdown,
      'audioHint': audioHint,
    };
  }
}

class GrammarExercise {
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;
  final String? hint;
  final ExerciseType exerciseType;

  const GrammarExercise({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.hint,
    this.exerciseType = ExerciseType.multipleChoice,
  });

  factory GrammarExercise.fromJson(Map<String, dynamic> json) {
    return GrammarExercise(
      question: json['question'] as String,
      options: List<String>.from(json['options']),
      correctAnswer: json['correctAnswer'] as int,
      explanation: json['explanation'] as String,
      hint: json['hint'] as String?,
      exerciseType: ExerciseType.values.firstWhere(
        (e) => e.toString().split('.').last == json['exerciseType'],
        orElse: () => ExerciseType.multipleChoice,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'hint': hint,
      'exerciseType': exerciseType.toString().split('.').last,
    };
  }
}

class CommonMistake {
  final String incorrect;
  final String correct;
  final String explanation;

  const CommonMistake({
    required this.incorrect,
    required this.correct,
    required this.explanation,
  });

  factory CommonMistake.fromJson(Map<String, dynamic> json) {
    return CommonMistake(
      incorrect: json['incorrect'] as String,
      correct: json['correct'] as String,
      explanation: json['explanation'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'incorrect': incorrect,
      'correct': correct,
      'explanation': explanation,
    };
  }
}

// MARK: - Study Session Tracking
class GrammarStudySession {
  final DateTime date;
  final int totalQuestions;
  final int correctAnswers;
  final double accuracy;
  final int timeSpentSeconds;
  final List<int> questionResults; // 1 for correct, 0 for incorrect

  const GrammarStudySession({
    required this.date,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.accuracy,
    required this.timeSpentSeconds,
    required this.questionResults,
  });

  factory GrammarStudySession.fromJson(Map<String, dynamic> json) {
    return GrammarStudySession(
      date: DateTime.parse(json['date'] as String),
      totalQuestions: json['totalQuestions'] as int,
      correctAnswers: json['correctAnswers'] as int,
      accuracy: (json['accuracy'] as num).toDouble(),
      timeSpentSeconds: json['timeSpentSeconds'] as int,
      questionResults: List<int>.from(json['questionResults']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'accuracy': accuracy,
      'timeSpentSeconds': timeSpentSeconds,
      'questionResults': questionResults,
    };
  }
}
