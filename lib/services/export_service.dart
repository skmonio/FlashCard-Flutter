import 'dart:convert';
import '../models/flash_card.dart';
import '../models/deck.dart';
import '../models/dutch_word_exercise.dart';
import '../models/dutch_word_exercise.dart' show WordCategory, ExerciseDifficulty;

class ExportService {
  // Export options
  static const String formatCSV = 'csv';
  static const String formatJSON = 'json';
  
  // Content options
  static const String contentCards = 'cards';
  static const String contentExercises = 'exercises';
  static const String contentBoth = 'both';

  // Export cards to CSV
  static String exportCardsToCSV(List<FlashCard> cards, List<Deck> decks) {
    final lines = <String>[];
    
    // Add header
    final headers = [
      'Decks', 'Word', 'Definition', 'Example', 'Article', 'Plural', 
      'Past Tense', 'Future Tense', 'Past Participle'
    ];
    lines.add(headers.join(','));
    
    // Export each card
    for (final card in cards) {
      final deckPaths = _getDeckPathsForCard(card, decks);
      final deckPathsString = deckPaths.join('; ');
      
      lines.add([
        _escapeCSVField(deckPathsString),
        _escapeCSVField(card.word),
        _escapeCSVField(card.definition ?? ''),
        _escapeCSVField(card.example ?? ''),
        _escapeCSVField(card.article ?? ''),
        _escapeCSVField(card.plural ?? ''),
        _escapeCSVField(card.pastTense ?? ''),
        _escapeCSVField(card.futureTense ?? ''),
        _escapeCSVField(card.pastParticiple ?? ''),
      ].join(','));
    }
    
    return lines.join('\n');
  }

  // Export exercises to CSV
  static String exportExercisesToCSV(List<DutchWordExercise> exercises, List<Deck> decks) {
    final lines = <String>[];
    
    // Add header
    final headers = [
      'Word', 'Exercise Type', 'Question', 'Correct Answer', 'Options', 'Explanation'
    ];
    lines.add(headers.join(','));
    
    // Export each exercise
    for (final exercise in exercises) {
      for (final ex in exercise.exercises) {
        lines.add([
          _escapeCSVField(exercise.targetWord),
          _escapeCSVField(_convertExerciseTypeToCSV(ex.type)),
          _escapeCSVField(ex.prompt),
          _escapeCSVField(ex.correctAnswer),
          _escapeCSVField(ex.options.join(';')),
          _escapeCSVField(ex.explanation ?? ''),
        ].join(','));
      }
    }
    
    return lines.join('\n');
  }

  // Export unified (cards + exercises) to CSV
  static String exportUnifiedToCSV(List<FlashCard> cards, List<DutchWordExercise> exercises, List<Deck> decks) {
    final lines = <String>[];
    
    // Add header
    final headers = [
      'Decks', 'Word', 'Definition', 'Example', 'Article', 'Plural', 
      'Past Tense', 'Future Tense', 'Past Participle', 'Exercise Type', 
      'Question', 'Correct Answer', 'Options', 'Explanation'
    ];
    lines.add(headers.join(','));
    
    // Group exercises by word for easier lookup
    final exerciseMap = <String, DutchWordExercise>{};
    for (final exercise in exercises) {
      exerciseMap[exercise.targetWord] = exercise;
    }
    
    // Export each card
    for (final card in cards) {
      final exercise = exerciseMap[card.word];
      final deckPaths = _getDeckPathsForCard(card, decks);
      final deckPathsString = deckPaths.join('; ');
      
      if (exercise != null && exercise.exercises.isNotEmpty) {
        // Add word data row (no exercise)
        lines.add([
          _escapeCSVField(deckPathsString),
          _escapeCSVField(card.word),
          _escapeCSVField(card.definition ?? ''),
          _escapeCSVField(card.example ?? ''),
          _escapeCSVField(card.article ?? ''),
          _escapeCSVField(card.plural ?? ''),
          _escapeCSVField(card.pastTense ?? ''),
          _escapeCSVField(card.futureTense ?? ''),
          _escapeCSVField(card.pastParticiple ?? ''),
          '', // No exercise type
          '', // No question
          '', // No correct answer
          '', // No options
          '', // No explanation
        ].join(','));
        
        // Add exercise rows
        for (final ex in exercise.exercises) {
          lines.add([
            _escapeCSVField(deckPathsString),
            _escapeCSVField(card.word),
            _escapeCSVField(card.definition ?? ''),
            _escapeCSVField(card.example ?? ''),
            _escapeCSVField(card.article ?? ''),
            _escapeCSVField(card.plural ?? ''),
            _escapeCSVField(card.pastTense ?? ''),
            _escapeCSVField(card.futureTense ?? ''),
            _escapeCSVField(card.pastParticiple ?? ''),
            _escapeCSVField(_convertExerciseTypeToCSV(ex.type)),
            _escapeCSVField(ex.prompt),
            _escapeCSVField(ex.correctAnswer),
            _escapeCSVField(ex.options.join(';')),
            _escapeCSVField(ex.explanation ?? ''),
          ].join(','));
        }
      } else {
        // Export as basic flashcard (no exercises)
        lines.add([
          _escapeCSVField(deckPathsString),
          _escapeCSVField(card.word),
          _escapeCSVField(card.definition ?? ''),
          _escapeCSVField(card.example ?? ''),
          _escapeCSVField(card.article ?? ''),
          _escapeCSVField(card.plural ?? ''),
          _escapeCSVField(card.pastTense ?? ''),
          _escapeCSVField(card.futureTense ?? ''),
          _escapeCSVField(card.pastParticiple ?? ''),
          '', // No exercise type
          '', // No question
          '', // No correct answer
          '', // No options
          '', // No explanation
        ].join(','));
      }
    }
    
    return lines.join('\n');
  }

  // Export cards to JSON
  static String exportCardsToJSON(List<FlashCard> cards, List<Deck> decks) {
    final cardsData = cards.map((card) {
      final deckPaths = _getDeckPathsForCard(card, decks);
      return {
        'decks': deckPaths,
        'word': card.word,
        'definition': card.definition,
        'example': card.example,
        'article': card.article,
        'plural': card.plural,
        'pastTense': card.pastTense,
        'futureTense': card.futureTense,
        'pastParticiple': card.pastParticiple,
        'dateCreated': card.dateCreated.toIso8601String(),
        'lastModified': card.lastModified.toIso8601String(),
        'timesShown': card.timesShown,
        'timesCorrect': card.timesCorrect,
        'learningPercentage': card.learningPercentage,
        'isFullyLearned': card.isFullyLearned,
      };
    }).toList();

    return jsonEncode({
      'type': 'flashcards',
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'cardCount': cards.length,
      'cards': cardsData,
    }, toEncodable: (obj) => obj);
  }

  // Export exercises to JSON
  static String exportExercisesToJSON(List<DutchWordExercise> exercises) {
    final exercisesData = exercises.map((exercise) {
      return {
        'targetWord': exercise.targetWord,
        'exercises': exercise.exercises.map((ex) => {
          'type': ex.type.toString().split('.').last,
          'prompt': ex.prompt,
          'correctAnswer': ex.correctAnswer,
          'options': ex.options,
          'explanation': ex.explanation,
        }).toList(),
      };
    }).toList();

    return jsonEncode({
      'type': 'exercises',
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'exerciseCount': exercises.length,
      'exercises': exercisesData,
    }, toEncodable: (obj) => obj);
  }

  // Export unified (cards + exercises) to JSON
  static String exportUnifiedToJSON(List<FlashCard> cards, List<DutchWordExercise> exercises, List<Deck> decks) {
    final cardsData = cards.map((card) {
      final deckPaths = _getDeckPathsForCard(card, decks);
      final exercise = exercises.firstWhere(
        (e) => e.targetWord == card.word,
        orElse: () => DutchWordExercise(
          id: '',
          targetWord: card.word,
          wordTranslation: card.definition,
          deckId: card.deckIds.isNotEmpty ? card.deckIds.first : 'default',
          deckName: 'Default Deck',
          category: WordCategory.common,
          difficulty: ExerciseDifficulty.beginner,
          exercises: [],
          createdAt: DateTime.now(),
        ),
      );
      
      return {
        'decks': deckPaths,
        'word': card.word,
        'definition': card.definition,
        'example': card.example,
        'article': card.article,
        'plural': card.plural,
        'pastTense': card.pastTense,
        'futureTense': card.futureTense,
        'pastParticiple': card.pastParticiple,
        'dateCreated': card.dateCreated.toIso8601String(),
        'lastModified': card.lastModified.toIso8601String(),
        'timesShown': card.timesShown,
        'timesCorrect': card.timesCorrect,
        'learningPercentage': card.learningPercentage,
        'isFullyLearned': card.isFullyLearned,
        'exercises': exercise.exercises.map((ex) => {
          'type': ex.type.toString().split('.').last,
          'prompt': ex.prompt,
          'correctAnswer': ex.correctAnswer,
          'options': ex.options,
          'explanation': ex.explanation,
        }).toList(),
      };
    }).toList();

    return jsonEncode({
      'type': 'unified',
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'cardCount': cards.length,
      'exerciseCount': exercises.length,
      'data': cardsData,
    }, toEncodable: (obj) => obj);
  }

  // Main export method
  static String export({
    required String format,
    required String content,
    required List<FlashCard> cards,
    required List<DutchWordExercise> exercises,
    required List<Deck> decks,
  }) {
    switch (format) {
      case formatCSV:
        switch (content) {
          case contentCards:
            return exportCardsToCSV(cards, decks);
          case contentExercises:
            return exportExercisesToCSV(exercises, decks);
          case contentBoth:
            return exportUnifiedToCSV(cards, exercises, decks);
          default:
            throw ArgumentError('Invalid content type: $content');
        }
      case formatJSON:
        switch (content) {
          case contentCards:
            return exportCardsToJSON(cards, decks);
          case contentExercises:
            return exportExercisesToJSON(exercises);
          case contentBoth:
            return exportUnifiedToJSON(cards, exercises, decks);
          default:
            throw ArgumentError('Invalid content type: $content');
        }
      default:
        throw ArgumentError('Invalid format: $format');
    }
  }

  // Helper methods
  static List<String> _getDeckPathsForCard(FlashCard card, List<Deck> decks) {
    final deckPaths = <String>[];
    
    for (final deckId in card.deckIds) {
      final deck = decks.firstWhere((d) => d.id == deckId);
      final path = _buildDeckPath(deck, decks);
      deckPaths.add(path);
    }
    
    return deckPaths;
  }

  static String _buildDeckPath(Deck deck, List<Deck> allDecks) {
    final path = <String>[deck.name];
    String? currentParentId = deck.parentId;
    
    while (currentParentId != null) {
      try {
        final parentDeck = allDecks.firstWhere((d) => d.id == currentParentId);
        path.insert(0, parentDeck.name);
        currentParentId = parentDeck.parentId;
      } catch (e) {
        break; // Parent not found, stop building path
      }
    }
    
    return path.join(' > ');
  }

  static String _convertExerciseTypeToCSV(ExerciseType type) {
    switch (type) {
      case ExerciseType.sentenceBuilding:
        return 'Sentence Building';
      case ExerciseType.multipleChoice:
        return 'Multiple Choice';
      case ExerciseType.fillInBlank:
        return 'Fill in Blank';
      default:
        return 'Multiple Choice';
    }
  }

  static String _escapeCSVField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
