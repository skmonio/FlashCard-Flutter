import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  // Using Google Translate API (more reliable)
  static const String _baseUrl = 'https://translate.googleapis.com/translate_a/single';
  
  /// Translate a Dutch word to English
  Future<String?> translateDutchToEnglish(String dutchWord) async {
    try {
      print('TranslationService: Translating "$dutchWord" from Dutch to English');
      
      final response = await http.get(
        Uri.parse('$_baseUrl?client=gtx&sl=nl&tl=en&dt=t&q=${Uri.encodeComponent(dutchWord)}'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Google Translate returns a complex nested structure
        if (data is List && data.isNotEmpty && data[0] is List) {
          final translations = data[0] as List;
          if (translations.isNotEmpty && translations[0] is List) {
            final translation = translations[0][0] as String?;
            
            if (translation != null && translation.isNotEmpty) {
              print('TranslationService: Successfully translated "$dutchWord" to "$translation"');
              return translation;
            }
          }
        }
      }
      
      print('TranslationService: Failed to translate "$dutchWord" - Status: ${response.statusCode}');
      return null;
    } catch (e) {
      print('TranslationService: Error translating "$dutchWord": $e');
      return null;
    }
  }

  /// Translate multiple Dutch words to English
  Future<Map<String, String>> translateMultipleWords(List<String> dutchWords) async {
    final Map<String, String> translations = {};
    
    print('TranslationService: Translating ${dutchWords.length} words');
    
    for (String word in dutchWords) {
      try {
        final translation = await translateDutchToEnglish(word);
        if (translation != null) {
          translations[word] = translation;
        }
        
        // Add a small delay to avoid overwhelming the API
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        print('TranslationService: Error translating word "$word": $e');
      }
    }
    
    print('TranslationService: Completed translations for ${translations.length} words');
    return translations;
  }

  /// Check if a word looks like Dutch (basic heuristic)
  bool isLikelyDutch(String word) {
    // Common Dutch letter combinations and patterns
    final dutchPatterns = [
      'ij', 'ei', 'ui', 'ou', 'au', 'eu', 'oe', 'aa', 'ee', 'oo', 'uu',
      'sch', 'ng', 'nk', 'cht', 'st', 'sp', 'sl', 'sm', 'sn', 'sw'
    ];
    
    final lowercaseWord = word.toLowerCase();
    
    // Check for common Dutch patterns
    for (String pattern in dutchPatterns) {
      if (lowercaseWord.contains(pattern)) {
        return true;
      }
    }
    
    // Check for common Dutch word endings
    final dutchEndings = ['en', 'er', 'el', 'ig', 'lijk', 'heid', 'ing', 'teit'];
    for (String ending in dutchEndings) {
      if (lowercaseWord.endsWith(ending)) {
        return true;
      }
    }
    
    // If no Dutch patterns found, still try to translate words longer than 3 characters
    // as they might be Dutch words without obvious patterns
    return lowercaseWord.length > 3;
  }
}
