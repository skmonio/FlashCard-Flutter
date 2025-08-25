import 'dart:math';
import '../models/dutch_word_exercise.dart';
import '../models/flash_card.dart';

class DutchGrammarExerciseGenerator {
  static final Random _random = Random();

  /// Generate grammar exercises for a flashcard based on available data
  static List<WordExercise> generateGrammarExercises(FlashCard card) {
    final List<WordExercise> exercises = [];

    // Generate article exercise if article is provided
    if (card.article != null && card.article!.isNotEmpty) {
      exercises.add(_generateArticleExercise(card));
    }

    // Generate plural exercise if plural is provided
    if (card.plural != null && card.plural!.isNotEmpty) {
      exercises.add(_generatePluralExercise(card));
    }

    // Generate sentence builder exercise if example sentence and translation are provided
    if (card.example.isNotEmpty && card.exampleTranslation.isNotEmpty) {
      exercises.add(_generateSentenceBuilderExercise(card));
    }

    return exercises;
  }

  /// Generate a De/Het article exercise
  static WordExercise _generateArticleExercise(FlashCard card) {
    final correctAnswer = card.article!;
    final wrongAnswer = correctAnswer == 'de' ? 'het' : 'de';
    
    // Create options with correct answer first (will be shuffled in UI)
    final options = [correctAnswer, wrongAnswer];
    
    return WordExercise(
      id: '${card.id}_article_${DateTime.now().millisecondsSinceEpoch}',
      type: ExerciseType.multipleChoice,
      prompt: 'Is it De or Het "${card.word}"?',
      options: options,
      correctAnswer: correctAnswer,
      explanation: 'The correct article for "${card.word}" is "$correctAnswer".',
      difficulty: ExerciseDifficulty.beginner,
    );
  }

  /// Generate a plural form exercise
  static WordExercise _generatePluralExercise(FlashCard card) {
    final correctPlural = card.plural!;
    final word = card.word;
    
    // Generate plausible wrong options based on Dutch plural rules
    final wrongOptions = _generatePluralOptions(word, correctPlural);
    
    // Create options with correct answer first (will be shuffled in UI)
    final options = [correctPlural, ...wrongOptions];
    
    return WordExercise(
      id: '${card.id}_plural_${DateTime.now().millisecondsSinceEpoch}',
      type: ExerciseType.multipleChoice,
      prompt: 'What is the plural form of "${word}"?',
      options: options,
      correctAnswer: correctPlural,
      explanation: 'The plural form of "${word}" is "${correctPlural}".',
      difficulty: ExerciseDifficulty.beginner,
    );
  }

  /// Generate plausible wrong plural options based on Dutch grammar rules
  static List<String> _generatePluralOptions(String word, String correctPlural) {
    final Set<String> uniqueOptions = <String>{};
    final wordLower = word.toLowerCase();
    final correctPluralLower = correctPlural.toLowerCase();
    
    // Generate all possible plural forms based on Dutch grammar rules
    final List<String> possiblePlurals = _generateAllPossiblePlurals(wordLower);
    
    // Add unique wrong options (excluding the correct answer, case-insensitive)
    for (final plural in possiblePlurals) {
      if (plural.toLowerCase() != correctPluralLower && uniqueOptions.length < 3) {
        uniqueOptions.add(plural);
      }
    }
    
    // If we don't have enough unique options, add some generic ones
    if (uniqueOptions.length < 3) {
      _addGenericPluralOptions(wordLower, correctPluralLower, uniqueOptions);
    }
    
    return uniqueOptions.toList();
  }
  
  /// Generate all possible plural forms for a word based on Dutch grammar rules
  static List<String> _generateAllPossiblePlurals(String word) {
    final List<String> plurals = [];
    
    // Rule 1: -en (most common plural ending)
    plurals.add(word + 'en');
    
    // Rule 2: -s (common for words ending in certain letters)
    plurals.add(word + 's');
    
    // Rule 3: -eren (for some neuter nouns like kind -> kinderen)
    plurals.add(word + 'eren');
    
    // Rule 4: -den (for words ending in -d)
    if (word.endsWith('d')) {
      plurals.add(word + 'den');
    }
    
    // Rule 5: -ten (for words ending in -t)
    if (word.endsWith('t')) {
      plurals.add(word + 'ten');
    }
    
    // Rule 6: -den (for words ending in -nd, like hond -> honden)
    if (word.endsWith('nd')) {
      plurals.add(word + 'den');
    }
    
    // Rule 7: -ten (for words ending in -nt)
    if (word.endsWith('nt')) {
      plurals.add(word + 'ten');
    }
    
    // Rule 8: -en (for words ending in -ing)
    if (word.endsWith('ing')) {
      plurals.add(word + 'en');
    }
    
    // Rule 9: -s (for words ending in -heid)
    if (word.endsWith('heid')) {
      plurals.add(word + 's');
    }
    
    // Rule 10: -en (for words ending in -nis)
    if (word.endsWith('nis')) {
      plurals.add(word + 'en');
    }
    
    // Rule 11: -en (for words ending in -schap)
    if (word.endsWith('schap')) {
      plurals.add(word + 'en');
    }
    
    // Rule 12: -s (for words ending in -isme)
    if (word.endsWith('isme')) {
      plurals.add(word + 's');
    }
    
    // Rule 13: -s (for words ending in -a, -o, -u, -y)
    if (word.endsWith('a') || word.endsWith('o') || 
        word.endsWith('u') || word.endsWith('y')) {
      plurals.add(word + 's');
    }
    
    // Rule 14: -en (for words ending in -el, -er, -em, -ie, -je, -ke, -le, -me, -ne, -re, -se, -te, -ue, -ze)
    if (word.endsWith('el') || word.endsWith('er') || word.endsWith('em') ||
        word.endsWith('ie') || word.endsWith('je') || word.endsWith('ke') ||
        word.endsWith('le') || word.endsWith('me') || word.endsWith('ne') ||
        word.endsWith('re') || word.endsWith('se') || word.endsWith('te') ||
        word.endsWith('ue') || word.endsWith('ze')) {
      plurals.add(word + 'en');
    }
    
    return plurals;
  }
  
  /// Add generic plural options if we need more unique options
  static void _addGenericPluralOptions(String word, String correctPlural, Set<String> options) {
    // Add some common Dutch plural patterns that might not have been generated
    final List<String> genericOptions = [
      word + 'en',
      word + 's', 
      word + 'eren',
      word + 'den',
      word + 'ten',
    ];
    
    for (final option in genericOptions) {
      if (option != correctPlural && options.length < 3) {
        options.add(option);
      }
    }
  }

  /// Generate a sentence builder exercise using the example sentence and translation
  static WordExercise _generateSentenceBuilderExercise(FlashCard card) {
    // Clean the sentence: remove punctuation and convert to lowercase for exercise
    final cleanedSentence = _cleanSentenceForExercise(card.example);
    
    // Split the cleaned sentence into words
    final dutchWords = cleanedSentence.split(' ').where((word) => word.isNotEmpty).toList();
    
    // Create shuffled options for the sentence builder
    final shuffledWords = List<String>.from(dutchWords)..shuffle(_random);
    
    return WordExercise(
      id: '${card.id}_sentencebuilder_${DateTime.now().millisecondsSinceEpoch}',
      type: ExerciseType.sentenceBuilding,
      prompt: 'Build the correct Dutch sentence: ${card.exampleTranslation}',
      options: shuffledWords,
      correctAnswer: cleanedSentence, // Use cleaned sentence as answer
      explanation: 'The correct Dutch sentence is: "${card.example}".',
      difficulty: ExerciseDifficulty.beginner,
    );
  }
  
  /// Clean a sentence for exercise use (remove punctuation, convert to lowercase)
  static String _cleanSentenceForExercise(String sentence) {
    // Remove common punctuation marks
    String cleaned = sentence.replaceAll(RegExp(r'[.!?;:,]'), '');
    
    // Convert to lowercase
    cleaned = cleaned.toLowerCase();
    
    // Remove extra whitespace
    cleaned = cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    return cleaned;
  }
}
