import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationLanguage {
  final String code;
  final String name;
  final String nativeName;

  const TranslationLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationLanguage &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$name ($nativeName)';
}

class TranslationLanguageProvider extends ChangeNotifier {
  static const String _wordLanguageKey = 'word_language';
  static const String _translationLanguageKey = 'translation_language';
  
  // Common languages for language learning
  static const List<TranslationLanguage> availableLanguages = [
    TranslationLanguage(code: 'en', name: 'English', nativeName: 'English'),
    TranslationLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
    TranslationLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
    TranslationLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
    TranslationLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano'),
    TranslationLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
    TranslationLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский'),
    TranslationLanguage(code: 'zh', name: 'Chinese', nativeName: '中文'),
    TranslationLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語'),
    TranslationLanguage(code: 'ko', name: 'Korean', nativeName: '한국어'),
    TranslationLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
    TranslationLanguage(code: 'nl', name: 'Dutch', nativeName: 'Nederlands'),
  ];
  
  // Word language is the language you're learning (source language)
  TranslationLanguage _wordLanguage = availableLanguages.firstWhere(
    (lang) => lang.code == 'nl',
    orElse: () => availableLanguages.first,
  ); // Default to Dutch for backward compatibility
  
  // Translation language is the language for translations (target language)
  TranslationLanguage _translationLanguage = availableLanguages.first; // Default to English
  
  TranslationLanguage get wordLanguage => _wordLanguage;
  String get wordLanguageCode => _wordLanguage.code;
  
  TranslationLanguage get targetLanguage => _translationLanguage; // Backward compatibility
  String get targetLanguageCode => _translationLanguage.code;
  
  TranslationLanguage get translationLanguage => _translationLanguage;
  String get translationLanguageCode => _translationLanguage.code;
  
  // Initialize languages from saved preferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load word language (default to Dutch for backward compatibility)
      final wordLanguageCode = prefs.getString(_wordLanguageKey) ?? 'nl';
      _wordLanguage = availableLanguages.firstWhere(
        (lang) => lang.code == wordLanguageCode,
        orElse: () => availableLanguages.firstWhere(
          (lang) => lang.code == 'nl',
          orElse: () => availableLanguages.first,
        ),
      );
      
      // Load translation language (backward compatibility: check old key first)
      final translationLanguageCode = prefs.getString(_translationLanguageKey) ?? 'en';
      _translationLanguage = availableLanguages.firstWhere(
        (lang) => lang.code == translationLanguageCode,
        orElse: () => availableLanguages.first,
      );
      
      notifyListeners();
    } catch (e) {
      print('Error loading language preferences: $e');
    }
  }
  
  // Set word language (the language you're learning)
  Future<void> setWordLanguage(TranslationLanguage language) async {
    _wordLanguage = language;
    await _saveWordLanguage();
    notifyListeners();
  }
  
  // Set translation language (the language for translations)
  Future<void> setTranslationLanguage(TranslationLanguage language) async {
    _translationLanguage = language;
    await _saveTranslationLanguage();
    notifyListeners();
  }
  
  // Set target language (backward compatibility)
  Future<void> setTargetLanguage(TranslationLanguage language) async {
    await setTranslationLanguage(language);
  }
  
  // Save word language preference
  Future<void> _saveWordLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_wordLanguageKey, _wordLanguage.code);
    } catch (e) {
      print('Error saving word language: $e');
    }
  }
  
  // Save translation language preference
  Future<void> _saveTranslationLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_translationLanguageKey, _translationLanguage.code);
    } catch (e) {
      print('Error saving translation language: $e');
    }
  }
  
  // Get language by code
  TranslationLanguage? getLanguageByCode(String code) {
    try {
      return availableLanguages.firstWhere(
        (lang) => lang.code == code,
      );
    } catch (e) {
      return null;
    }
  }
}


