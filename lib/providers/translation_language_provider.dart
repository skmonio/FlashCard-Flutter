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
  static const String _languageKey = 'translation_language';
  
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
  
  TranslationLanguage _targetLanguage = availableLanguages.first; // Default to English
  
  TranslationLanguage get targetLanguage => _targetLanguage;
  String get targetLanguageCode => _targetLanguage.code;
  
  // Initialize language from saved preferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey) ?? 'en';
      
      _targetLanguage = availableLanguages.firstWhere(
        (lang) => lang.code == languageCode,
        orElse: () => availableLanguages.first,
      );
      
      notifyListeners();
    } catch (e) {
      print('Error loading translation language: $e');
    }
  }
  
  // Set target language
  Future<void> setTargetLanguage(TranslationLanguage language) async {
    _targetLanguage = language;
    await _saveLanguage();
    notifyListeners();
  }
  
  // Save language preference
  Future<void> _saveLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, _targetLanguage.code);
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

