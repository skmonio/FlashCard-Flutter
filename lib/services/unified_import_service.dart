import 'dart:convert';
import '../models/flash_card.dart';

class UnifiedImportService {
  // Basic flashcard CSV format: Word,Translation,Deck,Example,Article,Plural,Present Tense,Past Tense,Perfect Tense
  static const List<String> basicHeaders = [
    'Word',
    'Translation',
    'Deck',
    'Example',
    'Article',
    'Plural',
    'Present Tense',
    'Past Tense',
    'Perfect Tense',
  ];

  static Future<Map<String, dynamic>> parseUnifiedCSV(String csvContent) async {
    final lines = csvContent.trim().split('\n');
    if (lines.isEmpty) {
      return {
        'cards': [], 
        'errors': ['CSV file is empty or contains no data'],
        'success': false
      };
    }

    final headers = lines[0].split(',').map((h) => h.trim()).toList();
    final data = lines.skip(1).where((line) => line.trim().isNotEmpty).toList();
    
    // Check for basic format
    final hasWord = headers.contains('Word');
    final hasTranslation = headers.contains('Translation') || headers.contains('Definition');
    final hasDeck = headers.contains('Deck') || headers.contains('Decks');
    
    if (!hasWord || !hasTranslation || !hasDeck) {
      return {
        'cards': [], 
        'errors': ['Unsupported CSV format. Expected basic format: Word, Translation/Definition, Deck/Decks, etc.'],
        'success': false
      };
    }

    return _parseBasicFormat(headers, data);
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
        final translationIndex = headers.indexOf('Translation') != -1 ? headers.indexOf('Translation') : headers.indexOf('Definition');
        final deckIndex = headers.indexOf('Deck') != -1 ? headers.indexOf('Deck') : headers.indexOf('Decks');
        
        final word = values[wordIndex].trim();
        final translation = values[translationIndex].trim();
        final deckName = values[deckIndex].trim();
        
        // Optional fields with safe index checking
        final exampleIndex = headers.indexOf('Example');
        final articleIndex = headers.indexOf('Article');
        final pluralIndex = headers.indexOf('Plural');
        final presentTenseIndex = headers.indexOf('Present Tense');
        final pastTenseIndex = headers.indexOf('Past Tense');
        final perfectTenseIndex = headers.indexOf('Perfect Tense');
        
        final example = exampleIndex != -1 && exampleIndex < values.length ? values[exampleIndex].trim() : '';
        final article = articleIndex != -1 && articleIndex < values.length ? values[articleIndex].trim() : '';
        final plural = pluralIndex != -1 && pluralIndex < values.length ? values[pluralIndex].trim() : '';
        final presentTense = presentTenseIndex != -1 && presentTenseIndex < values.length ? values[presentTenseIndex].trim() : '';
        final pastTense = pastTenseIndex != -1 && pastTenseIndex < values.length ? values[pastTenseIndex].trim() : '';
        final perfectTense = perfectTenseIndex != -1 && perfectTenseIndex < values.length ? values[perfectTenseIndex].trim() : '';
        
        // Create FlashCard
        final deckIds = _parseDeckNames(deckName);
        
        final card = FlashCard(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          word: word,
          definition: translation,
          example: example,
          article: article,
          plural: plural,
          presentTense: presentTense,
          pastTense: pastTense,
          perfectTense: perfectTense,
          deckIds: deckIds,
          dateCreated: DateTime.now(),
        );
        cards.add(card);
        
      } catch (e) {
        errors.add('Error parsing line ${i + 1}: ${e.toString()}');
        continue;
      }
    }

    return {
      'cards': cards,
      'errors': errors,
      'success': true,
    };
  }

  // Helper methods
  static List<String> _parseCSVLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    String current = '';
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current += '"';
          i++; 
        } else {
          inQuotes = !inQuotes;
        }
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

  static Set<String> _parseDeckNames(String deckNames) {
    if (deckNames.isEmpty) return {'uncategorized'};
    return deckNames.split(';').map((name) => name.trim()).toSet();
  }
}