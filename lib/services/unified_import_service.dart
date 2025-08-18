import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../models/flash_card.dart';
import '../models/dutch_word_exercise.dart';

class UnifiedImportService {
  // Unified CSV format: Deck,Word,Definition,Exercise Type,Question,Options,Explanation
  static const List<String> unifiedHeaders = [
    'Deck',
    'Word',
    'Definition',
    'Exercise Type',
    'Question',
    'Options',
    'Explanation',
  ];

  // Basic flashcard CSV format: Word,Translation,Deck,Example,Article,Plural,Past Tense,Future Tense,Past Participle
  static const List<String> basicHeaders = [
    'Word',
    'Translation',
    'Deck',
    'Example',
    'Article',
    'Plural',
    'Past Tense',
    'Future Tense',
    'Past Participle',
  ];

  static Future<Map<String, dynamic>> parseUnifiedCSV(String csvContent) async {
    final lines = csvContent.trim().split('\n');
    if (lines.isEmpty) {
      return {
        'cards': [], 
        'exercises': [], 
        'errors': ['CSV file is empty or contains no data']
      };
    }

    final headers = lines[0].split(',').map((h) => h.trim()).toList();
    final data = lines.skip(1).where((line) => line.trim().isNotEmpty).toList();
    
    // Detect CSV format
    final isUnifiedFormat = _isUnifiedFormat(headers);
    final isBasicFormat = _isBasicFormat(headers);
    
    if (!isUnifiedFormat && !isBasicFormat) {
      return {
        'cards': [], 
        'exercises': [], 
        'errors': ['Unsupported CSV format. Expected either unified format (Deck,Word,Definition,Exercise Type,Question,Options,Explanation) or basic format (Word,Translation,Deck,Example,Article,Plural,Past Tense,Future Tense,Past Participle)']
      };
    }

    if (isUnifiedFormat) {
      return _parseUnifiedFormat(headers, data);
    } else {
      return _parseBasicFormat(headers, data);
    }
  }

  static bool _isUnifiedFormat(List<String> headers) {
    final requiredHeaders = ['Deck', 'Word', 'Definition', 'Exercise Type', 'Question', 'Options', 'Explanation'];
    return requiredHeaders.every((header) => headers.contains(header));
  }

  static bool _isBasicFormat(List<String> headers) {
    final requiredHeaders = ['Word', 'Translation', 'Deck'];
    return requiredHeaders.every((header) => headers.contains(header));
  }

  static Map<String, dynamic> _parseBasicFormat(List<String> headers, List<String> data) {
    final cards = <FlashCard>[];
    final errors = <String>[];
    
    for (int i = 0; i < data.length; i++) {
      final line = data[i].trim();
      if (line.isEmpty) continue;

      try {
        final values = _parseCSVLine(line);
        if (values.length < 3) {
          continue;
        }

        final wordIndex = headers.indexOf('Word');
        final translationIndex = headers.indexOf('Translation');
        final deckIndex = headers.indexOf('Deck');
        
        if (wordIndex == -1 || translationIndex == -1 || deckIndex == -1) {
          errors.add('Missing required headers: Word, Translation, or Deck');
          continue;
        }
        
        final word = values[wordIndex].trim();
        final translation = values[translationIndex].trim();
        final deckName = values[deckIndex].trim();
        
        // Optional fields with safe index checking
        final exampleIndex = headers.indexOf('Example');
        final articleIndex = headers.indexOf('Article');
        final pluralIndex = headers.indexOf('Plural');
        final pastTenseIndex = headers.indexOf('Past Tense');
        final futureTenseIndex = headers.indexOf('Future Tense');
        final pastParticipleIndex = headers.indexOf('Past Participle');
        
        final example = exampleIndex != -1 && exampleIndex < values.length ? values[exampleIndex].trim() : '';
        final article = articleIndex != -1 && articleIndex < values.length ? values[articleIndex].trim() : '';
        final plural = pluralIndex != -1 && pluralIndex < values.length ? values[pluralIndex].trim() : '';
        final pastTense = pastTenseIndex != -1 && pastTenseIndex < values.length ? values[pastTenseIndex].trim() : '';
        final futureTense = futureTenseIndex != -1 && futureTenseIndex < values.length ? values[futureTenseIndex].trim() : '';
        final pastParticiple = pastParticipleIndex != -1 && pastParticipleIndex < values.length ? values[pastParticipleIndex].trim() : '';
        
        print('🔍 Basic CSV parsing: Word="$word", Translation="$translation", Deck="$deckName"');

        // Create FlashCard
        final deckIds = _parseDeckNames(deckName);
        print('🔍 Creating basic card for "$word" with deckIds: $deckIds');
        
        final card = FlashCard(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          word: word,
          definition: translation,
          example: example,
          article: article,
          plural: plural,
          pastTense: pastTense,
          futureTense: futureTense,
          pastParticiple: pastParticiple,
          deckIds: deckIds,
          dateCreated: DateTime.now(),
        );
        cards.add(card);
        
      } catch (e) {
        final errorMsg = 'Error parsing line ${i + 1}: ${e.toString()}';
        print(errorMsg);
        errors.add(errorMsg);
        continue;
      }
    }

    print('Basic import completed: ${cards.length} cards');
    
    return {
      'cards': cards,
      'exercises': <DutchWordExercise>[],
      'errors': errors,
      'success': true,
    };
  }

  static Map<String, dynamic> _parseUnifiedFormat(List<String> headers, List<String> data) {
    final cards = <FlashCard>[];
    final wordExercises = <DutchWordExercise>[];
    final wordMap = <String, Map<String, dynamic>>{};
    final errors = <String>[];
    
    // Counter for unique ID generation
    int idCounter = 0;

    for (int i = 0; i < data.length; i++) {
      final line = data[i].trim();
      if (line.isEmpty) continue;

      try {
        final values = _parseCSVLine(line);
        if (values.length < headers.length) {
          continue;
        }

        final deckIndex = headers.indexOf('Deck');
        final wordIndex = headers.indexOf('Word');
        final definitionIndex = headers.indexOf('Definition');
        final exerciseTypeIndex = headers.indexOf('Exercise Type');
        final questionIndex = headers.indexOf('Question');
        final optionsIndex = headers.indexOf('Options');
        final explanationIndex = headers.indexOf('Explanation');
        
        if (deckIndex == -1 || wordIndex == -1 || definitionIndex == -1 || 
            exerciseTypeIndex == -1 || questionIndex == -1 || optionsIndex == -1 || explanationIndex == -1) {
          errors.add('Missing required headers for unified format');
          continue;
        }
        
        final deckName = values[deckIndex].trim();
        final word = values[wordIndex].trim();
        final definition = values[definitionIndex].trim();
        final exerciseType = values[exerciseTypeIndex].trim();
        final question = values[questionIndex].trim();
        final options = values[optionsIndex].trim();
        final explanation = values[explanationIndex].trim();
        
        print('🔍 Unified CSV parsing: Word="$word", DeckName="$deckName"');

        // Create or update word entry
        if (!wordMap.containsKey(word)) {
          wordMap[word] = {
            'word': word,
            'definition': definition,
            'example': '', // Optional field - empty for this CSV
            'article': '', // Optional field - empty for this CSV
            'plural': '', // Optional field - empty for this CSV
            'pastTense': '', // Optional field - empty for this CSV
            'futureTense': '', // Optional field - empty for this CSV
            'pastParticiple': '', // Optional field - empty for this CSV
            'deckNames': deckName,
            'exercises': <Map<String, dynamic>>[],
          };
          print('🔍 Created new word entry for "$word" with deck "$deckName"');
        } else {
          // Update existing word entry
          wordMap[word]!['deckNames'] = deckName;
          print('🔍 Updated existing word entry for "$word" with deck "$deckName"');
        }

        // Only add exercise if it has valid data
        if (exerciseType.isNotEmpty && 
            exerciseType.toLowerCase() != 'basic' &&
            question.isNotEmpty && 
            options.isNotEmpty) {
          
          // Parse options - first option is always correct
          final parsedOptions = _parseOptions(options, exerciseType);
          String correctAnswer;
          
          if (exerciseType.toLowerCase() == 'sentence building') {
            // For sentence building, the correct answer is all options joined together
            correctAnswer = parsedOptions.join(' ');
          } else {
            // For other exercise types, the first option is the correct answer
            correctAnswer = parsedOptions.isNotEmpty ? parsedOptions.first : '';
          }
          
          wordMap[word]!['exercises'].add({
            'type': _convertExerciseTypeToEnum(exerciseType),
            'prompt': question,
            'options': parsedOptions,
            'correctAnswer': correctAnswer,
            'explanation': explanation,
          });
        }
      } catch (e) {
        final errorMsg = 'Error parsing line ${i + 1}: ${e.toString()}';
        print(errorMsg);
        errors.add(errorMsg);
        continue;
      }
    }

    // Convert to FlashCard and DutchWordExercise objects
    print('Processing ${wordMap.length} unique words...');
    for (final wordData in wordMap.values) {
      print('Creating card for word: ${wordData['word']}');
      // Create FlashCard
      final deckIds = _parseDeckNames(wordData['deckNames']);
      print('🔍 Creating card for "${wordData['word']}" with deckIds: $deckIds');
      
      final card = FlashCard(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        word: wordData['word'],
        definition: wordData['definition'],
        example: wordData['example'] ?? '', // Optional field
        article: wordData['article'] ?? '', // Optional field
        plural: wordData['plural'] ?? '', // Optional field
        pastTense: wordData['pastTense'] ?? '', // Optional field
        futureTense: wordData['futureTense'] ?? '', // Optional field
        pastParticiple: wordData['pastParticiple'] ?? '', // Optional field
        deckIds: deckIds,
        dateCreated: DateTime.now(),
      );
      cards.add(card);

      // Create DutchWordExercise if exercises exist
      if (wordData['exercises'].isNotEmpty) {
        print('Creating ${wordData['exercises'].length} exercises for word: ${wordData['word']}');
        final individualExercises = <WordExercise>[];
        for (final ex in wordData['exercises']) {
          print('Creating exercise: ${ex['type']} - ${ex['prompt']}');
          individualExercises.add(WordExercise(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: ex['type'], // Already an enum
            prompt: ex['prompt'],
            options: List<String>.from(ex['options']),
            correctAnswer: ex['correctAnswer'],
            explanation: ex['explanation'],
            difficulty: ExerciseDifficulty.beginner,
          ));
        }
        
        // Create DutchWordExercise
        final deckId = _getPrimaryDeckId(wordData['deckNames']);
        final deckName = _getPrimaryDeckName(wordData['deckNames']);
        print('🔍 Creating DutchWordExercise for "${wordData['word']}" with deckId: "$deckId", deckName: "$deckName"');
        
        final dutchWordExercise = DutchWordExercise(
          id: '${DateTime.now().millisecondsSinceEpoch}_${idCounter++}',
          targetWord: wordData['word'],
          wordTranslation: wordData['definition'],
          deckId: deckId,
          deckName: deckName,
          category: WordCategory.common,
          difficulty: ExerciseDifficulty.beginner,
          exercises: individualExercises,
          createdAt: DateTime.now(),
          isUserCreated: false,
          learningProgress: LearningProgress(),
        );
        wordExercises.add(dutchWordExercise);
      }
    }

    print('Unified import completed: ${cards.length} cards, ${wordExercises.length} exercises');
    
    // Add summary errors if no data was imported
    if (cards.isEmpty && wordExercises.isEmpty && errors.isEmpty) {
      errors.add('No valid data found in CSV. Please check the format and ensure all required fields are filled.');
    }
    
    return {
      'cards': cards,
      'exercises': wordExercises,
      'errors': errors,
      'success': true,
    };
  }

  static String exportUnifiedCSV(List<FlashCard> cards, List<DutchWordExercise> exercises) {
    final lines = <String>[];
    
    // Add header
    lines.add(unifiedHeaders.join(','));
    
    // Group exercises by word for easier lookup
    final exerciseMap = <String, DutchWordExercise>{};
    for (final exercise in exercises) {
      exerciseMap[exercise.targetWord] = exercise;
    }
    
    // Export each card
    for (final card in cards) {
      final exercise = exerciseMap[card.word];
      
      if (exercise != null && exercise.exercises.isNotEmpty) {
        // Add word data
        lines.add([
          _escapeCSVField(_getDeckNames(card.deckIds)),
          _escapeCSVField(card.word),
          _escapeCSVField(card.definition),
          '', // No exercise type
          '', // No question
          '', // No options
          '', // No explanation
        ].join(','));
        
        // Add exercises
        for (final ex in exercise.exercises) {
          lines.add([
            _escapeCSVField(_getDeckNames(card.deckIds)),
            _escapeCSVField(card.word),
            _escapeCSVField(card.definition),
            _escapeCSVField(_convertExerciseTypeToCSV(ex.type)),
            _escapeCSVField(ex.prompt),
            _escapeCSVField(ex.options.join(';')),
            _escapeCSVField(ex.explanation),
          ].join(','));
        }
      } else {
        // Export as basic flashcard (no exercises)
        final row = [
          _escapeCSVField(_getDeckNames(card.deckIds)),
          _escapeCSVField(card.word),
          _escapeCSVField(card.definition),
          '', // No exercise type
          '', // No question
          '', // No options
          '', // No explanation
        ];
        lines.add(row.join(','));
      }
    }

    return lines.join('\n');
  }

  // Helper methods
  static List<String> _parseCSVLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    String current = '';
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    
    result.add(current.trim());
    return result;
  }

  static List<String> _parseOptions(String options, String exerciseType) {
    if (options.isEmpty) return [];
    
    // Split by semicolon and trim each option
    final optionList = options.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    // Remove numbers in parentheses (e.g., "word (1)" becomes "word")
    final cleanedOptions = optionList.map((option) {
      // Remove pattern like " (1)", " (2)", etc. from the end of the option
      // This regex matches optional whitespace, followed by parentheses with digits, followed by optional whitespace
      String cleaned = option;
      
      // First try the regex approach
      cleaned = cleaned.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '');
      
      // If that didn't work, try a simpler approach
      if (cleaned == option) {
        // Look for the pattern manually
        final lastParenIndex = cleaned.lastIndexOf('(');
        if (lastParenIndex != -1) {
          final afterParen = cleaned.substring(lastParenIndex);
          if (RegExp(r'^\(\d+\)\s*$').hasMatch(afterParen)) {
            cleaned = cleaned.substring(0, lastParenIndex).trim();
          }
        }
      }
      
      print('🔍 Cleaning option: "$option" -> "$cleaned"');
      return cleaned.trim();
    }).toList();
    
    // For sentence building, we might have more options than needed
    if (exerciseType.toLowerCase() == 'sentence building') {
      return cleanedOptions;
    }
    
    return cleanedOptions;
  }

  static ExerciseType _convertExerciseTypeToEnum(String csvType) {
    switch (csvType.toLowerCase()) {
      case 'sentence building':
        return ExerciseType.sentenceBuilding;
      case 'multiple choice':
        return ExerciseType.multipleChoice;
      case 'fill in the blank':
      case 'fill in blank':
        return ExerciseType.fillInBlank;
      default:
        return ExerciseType.multipleChoice; // Default fallback
    }
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

  static Set<String> _parseDeckNames(String deckNames) {
    if (deckNames.isEmpty) return {'uncategorized'};
    return deckNames.split(';').map((name) => name.trim()).toSet();
  }

  static String _getPrimaryDeckId(String deckNames) {
    if (deckNames.isEmpty) return 'uncategorized';
    final names = deckNames.split(';');
    return names.first.trim();
  }

  static String _getPrimaryDeckName(String deckNames) {
    if (deckNames.isEmpty) return 'Uncategorized';
    final names = deckNames.split(';');
    return names.first.trim();
  }

  static String _getDeckNames(Set<String> deckIds) {
    // This would need to be implemented with actual deck name lookup
    // For now, return the first deck ID
    return deckIds.isNotEmpty ? deckIds.first : 'Uncategorized';
  }

  static String _escapeCSVField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
} 