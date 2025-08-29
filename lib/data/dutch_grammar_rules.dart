import '../models/dutch_grammar_rule.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class DutchGrammarRulesDatabase {
  static List<DutchGrammarRule> _cachedRules = [];
  static bool _isLoaded = false;

  static Future<List<DutchGrammarRule>> get allRules async {
    if (!_isLoaded) {
      await _loadRulesFromJson();
    }
    return _cachedRules;
  }

  static Future<void> _loadRulesFromJson() async {
    if (_isLoaded) return;

    final List<DutchGrammarRule> rules = [];
    
    // List of JSON files to load
    final jsonFiles = [
      'present_tense_a1.json',
      'irregular_verbs_a1.json',
      'articles_a1.json',
      'past_tense_a2.json',
      'pluralization_a2.json',
      'adjectives_a2.json',
      'negation_a2.json',
      'worden_werden_a2.json',
      'verbs_fixed_prepositions_b1.json',
      'connecting_words_b1.json',
    ];

    for (final fileName in jsonFiles) {
      try {
        final jsonString = await rootBundle.loadString('assets/data/grammar_rules/$fileName');
        final jsonData = json.decode(jsonString);
        rules.add(DutchGrammarRule.fromJson(jsonData));
      } catch (e) {
        print('Error loading grammar rule from $fileName: $e');
      }
    }

    _cachedRules = rules;
    _isLoaded = true;
  }
}
