import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/phrase.dart';
import '../services/translation_service.dart';

class PhraseProvider with ChangeNotifier {
  List<Phrase> _phrases = [];
  final TranslationService _translationService = TranslationService();
  
  List<Phrase> get phrases => List.unmodifiable(_phrases);
  
  // Get phrases due for review
  List<Phrase> get phrasesDueForReview => 
      _phrases.where((phrase) => phrase.isDueForReview).toList();
  
  // Get new phrases
  List<Phrase> get newPhrases => 
      _phrases.where((phrase) => phrase.isNew).toList();
  
  // Get phrases by learning percentage
  List<Phrase> get phrasesByLearningPercentage {
    final sorted = List<Phrase>.from(_phrases);
    sorted.sort((a, b) => b.learningPercentage.compareTo(a.learningPercentage));
    return sorted;
  }
  
  // Get phrases that need practice (low percentage)
  List<Phrase> get phrasesNeedingPractice =>
      _phrases.where((phrase) => phrase.learningPercentage < 70).toList();
  
  // Get total phrases count
  int get totalPhrases => _phrases.length;
  
  // Get average learning percentage
  double get averageLearningPercentage {
    if (_phrases.isEmpty) return 0.0;
    final total = _phrases.fold(0, (sum, phrase) => sum + phrase.learningPercentage);
    return total / _phrases.length;
  }
  
  // MARK: - CRUD Operations
  
  Future<void> addPhrase(String phrase, String translation) async {
    final newPhrase = Phrase(
      phrase: phrase.trim(),
      translation: translation.trim(),
    );
    
    _phrases.add(newPhrase);
    await _savePhrases();
    notifyListeners();
  }
  
  Future<void> updatePhrase(String id, String phrase, String translation) async {
    final index = _phrases.indexWhere((p) => p.id == id);
    if (index != -1) {
      _phrases[index] = _phrases[index].copyWith(
        phrase: phrase.trim(),
        translation: translation.trim(),
        lastModified: DateTime.now(),
      );
      await _savePhrases();
      notifyListeners();
    }
  }
  
  Future<void> deletePhrase(String id) async {
    _phrases.removeWhere((phrase) => phrase.id == id);
    await _savePhrases();
    notifyListeners();
  }
  
  Phrase? getPhraseById(String id) {
    try {
      return _phrases.firstWhere((phrase) => phrase.id == id);
    } catch (e) {
      return null;
    }
  }
  
  // MARK: - Learning Methods
  
  void markPhraseCorrect(String id) {
    final index = _phrases.indexWhere((p) => p.id == id);
    if (index != -1) {
      _phrases[index].markCorrect();
      _savePhrases();
      notifyListeners();
    }
  }
  
  void markPhraseIncorrect(String id) {
    final index = _phrases.indexWhere((p) => p.id == id);
    if (index != -1) {
      _phrases[index].markIncorrect();
      _savePhrases();
      notifyListeners();
    }
  }
  
  // MARK: - Exercise Generation
  
  // Generate translation exercise (multiple choice)
  Map<String, dynamic> generateTranslationExercise(Phrase targetPhrase) {
    final random = Random();
    final List<String> options = [targetPhrase.translation];
    
    // Get other phrases' translations as distractors
    final otherTranslations = _phrases
        .where((p) => p.id != targetPhrase.id)
        .map((p) => p.translation)
        .toList();
    
    // Add up to 3 other translations as options
    if (otherTranslations.isNotEmpty) {
      otherTranslations.shuffle(random);
      for (int i = 0; i < min(3, otherTranslations.length); i++) {
        if (!options.contains(otherTranslations[i])) {
          options.add(otherTranslations[i]);
        }
      }
    }
    
    // If we don't have enough options, add some generic ones
    while (options.length < 4) {
      final genericOptions = [
        "I don't know",
        "Maybe",
        "Not sure",
        "Can't remember"
      ];
      for (final option in genericOptions) {
        if (!options.contains(option) && options.length < 4) {
          options.add(option);
        }
      }
    }
    
    // Shuffle options
    options.shuffle(random);
    
    return {
      'type': 'multiple_choice',
      'prompt': 'Choose the correct translation:',
      'question': 'What does "${targetPhrase.phrase}" mean?',
      'correctAnswer': targetPhrase.translation,
      'options': options,
      'explanation': 'The correct translation of "${targetPhrase.phrase}" is "${targetPhrase.translation}".',
      'phraseId': targetPhrase.id,
    };
  }
  
  // Generate sentence builder exercise
  Map<String, dynamic> generateSentenceBuilderExercise(Phrase targetPhrase) {
    final words = targetPhrase.phrase.split(' ');
    final shuffledWords = List<String>.from(words)..shuffle();
    
    return {
      'type': 'sentence_builder',
      'prompt': 'Build the correct sentence:',
      'question': 'Translate: "${targetPhrase.translation}"',
      'correctOrder': words,
      'availableWords': shuffledWords,
      'explanation': 'The correct order is: "${targetPhrase.phrase}".',
      'phraseId': targetPhrase.id,
    };
  }
  
  // Get random phrase for exercise
  Phrase? getRandomPhraseForExercise() {
    if (_phrases.isEmpty) return null;
    
    // Prioritize phrases that need practice
    final phrasesNeedingPractice = _phrases.where((p) => p.learningPercentage < 70).toList();
    if (phrasesNeedingPractice.isNotEmpty) {
      phrasesNeedingPractice.shuffle();
      return phrasesNeedingPractice.first;
    }
    
    // If all phrases are well learned, pick a random one
    _phrases.shuffle();
    return _phrases.first;
  }
  
  // MARK: - Translation Service Integration
  
  Future<String?> translatePhrase(String phrase) async {
    try {
      return await _translationService.translateDutchToEnglish(phrase);
    } catch (e) {
      debugPrint('Translation error: $e');
      return null;
    }
  }
  
  // MARK: - Data Persistence
  
  Future<void> loadPhrases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phrasesJson = prefs.getStringList('phrases') ?? [];
      
      _phrases = phrasesJson
          .map((json) => Phrase.fromJson(jsonDecode(json)))
          .toList();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading phrases: $e');
      _phrases = [];
    }
  }
  
  Future<void> _savePhrases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phrasesJson = _phrases
          .map((phrase) => jsonEncode(phrase.toJson()))
          .toList();
      
      await prefs.setStringList('phrases', phrasesJson);
    } catch (e) {
      debugPrint('Error saving phrases: $e');
    }
  }
  
  // MARK: - Import/Export
  
  Future<void> exportPhrases() async {
    // This would be implemented for CSV export
    // For now, just return the phrases as JSON
  }
  
  Future<void> importPhrases(List<Map<String, dynamic>> phrasesData) async {
    for (final data in phrasesData) {
      if (data['phrase'] != null && data['translation'] != null) {
        await addPhrase(data['phrase'], data['translation']);
      }
    }
  }
  
  // MARK: - Statistics
  
  Map<String, dynamic> getStatistics() {
    final total = _phrases.length;
    final newCount = newPhrases.length;
    final dueCount = phrasesDueForReview.length;
    final learnedCount = _phrases.where((p) => p.isFullyLearned).length;
    
    return {
      'total': total,
      'new': newCount,
      'dueForReview': dueCount,
      'fullyLearned': learnedCount,
      'averagePercentage': averageLearningPercentage,
    };
  }
}
