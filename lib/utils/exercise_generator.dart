import 'dart:math';
import '../models/dutch_word_exercise.dart';
import '../models/flash_card.dart';

class ExerciseGenerator {
  /// Generates or updates automated exercises for a given FlashCard.
  /// This includes Article (de/het), Plural, and Sentence Building exercises.
  static List<WordExercise> generateExercises(FlashCard card) {
    final List<WordExercise> exercises = [];
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. De/Het Article Exercise
    if (card.article != null && card.article!.isNotEmpty) {
      final correctAnswer = card.article!.toLowerCase().trim();
      if (correctAnswer == 'de' || correctAnswer == 'het') {
        final wrongAnswer = correctAnswer == 'de' ? 'het' : 'de';
        exercises.add(WordExercise(
          id: '${card.id}_article_$now',
          type: ExerciseType.multipleChoice,
          prompt: 'Is it De or Het "${card.word}"?',
          options: [correctAnswer, wrongAnswer],
          correctAnswer: '0', // Index 0 is correct
          explanation: 'The correct article for "${card.word}" is "$correctAnswer".',
          difficulty: ExerciseDifficulty.beginner,
        ));
      }
    }

    // 2. Plural Form Exercise
    if (card.plural != null && card.plural!.isNotEmpty) {
      final correctPlural = card.plural!.trim();
      final List<String> wrongOptions = [];
      
      // Common incorrect Dutch plural patterns
      if (!correctPlural.endsWith('s')) wrongOptions.add('${card.word}s');
      if (!correctPlural.endsWith('en')) wrongOptions.add('${card.word}en');
      if (!correctPlural.endsWith('eren')) wrongOptions.add('${card.word}eren');
      
      // Ensure we have at least some options
      while (wrongOptions.length < 2) {
        wrongOptions.add('${card.word}e');
        if (wrongOptions.length < 2) wrongOptions.add('${card.word}t');
      }

      final options = [correctPlural, ...wrongOptions.take(3)];
      
      exercises.add(WordExercise(
        id: '${card.id}_plural_$now',
        type: ExerciseType.multipleChoice,
        prompt: 'What is the plural form of "${card.word}"?',
        options: options,
        correctAnswer: '0', // Index 0 is correct
        explanation: 'The plural form of "${card.word}" is "$correctPlural".',
        difficulty: ExerciseDifficulty.beginner,
      ));
    }

    // 3. Sentence Building Exercise
    if (card.example != null && card.example!.isNotEmpty && 
        card.exampleTranslation != null && card.exampleTranslation!.isNotEmpty) {
      final originalSentence = card.example!;
      // Split into words, avoiding empty strings
      final dutchWords = originalSentence.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      
      if (dutchWords.length >= 2) {
        final shuffledWords = List<String>.from(dutchWords)..shuffle();
        exercises.add(WordExercise(
          id: '${card.id}_sentencebuilder_$now',
          type: ExerciseType.sentenceBuilding,
          prompt: 'Build the correct Dutch sentence: ${card.exampleTranslation}',
          options: shuffledWords,
          correctAnswer: originalSentence,
          explanation: 'Dutch: $originalSentence\nTranslation: ${card.exampleTranslation}',
          difficulty: ExerciseDifficulty.beginner,
        ));
      }
    }

    return exercises;
  }
}
