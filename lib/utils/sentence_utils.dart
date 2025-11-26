import 'package:flutter/foundation.dart';

/// Utilities for comparing sentence builder answers fairly.
///
/// Rationale: Some words (articles/conjunctions like "de", "het", "een", "en")
/// can appear multiple times, and users can't distinguish which identical token
/// belongs to which position. We therefore treat these as position-flexible:
/// - The relative order of non-flexible words must match exactly.
/// - Flexible words' counts must match, but their exact positions don't matter.
class SentenceUtils {
  /// Dutch function words that should be position-flexible when duplicated.
  static const Set<String> _flexibleWords = {
    'de', 'het', 'een', 'en',
    // common short function words (keep conservative to avoid false positives)
    'van', 'in', 'op', 'te', 'voor', 'met', 'maar', 'of', 'aan', 'bij'
  };

  /// Compares two sentences represented as lists of words.
  /// Returns true if:
  /// - They are exactly equal, or
  /// - After removing flexible words, the remaining sequences are identical
  ///   AND the counts of each flexible word match between both.
  static bool equalsWithFlexibleDuplicates(List<String> answerWords, List<String> correctWords) {
    if (identical(answerWords, correctWords)) return true;
    if (answerWords.length != correctWords.length) return false;

    // Quick path: strict equality by value
    if (listEquals(answerWords, correctWords)) return true;

    // Normalize to lowercase for safety (generators usually already do this)
    final List<String> a = answerWords.map((w) => w.toLowerCase()).toList();
    final List<String> c = correctWords.map((w) => w.toLowerCase()).toList();

    // Build filtered sequences without flexible words
    final List<String> aFixed = a.where((w) => !_flexibleWords.contains(w)).toList();
    final List<String> cFixed = c.where((w) => !_flexibleWords.contains(w)).toList();
    if (!listEquals(aFixed, cFixed)) return false;

    // Count flexible words in both
    final Map<String, int> aCounts = {};
    final Map<String, int> cCounts = {};
    for (final w in a) {
      if (_flexibleWords.contains(w)) {
        aCounts[w] = (aCounts[w] ?? 0) + 1;
      }
    }
    for (final w in c) {
      if (_flexibleWords.contains(w)) {
        cCounts[w] = (cCounts[w] ?? 0) + 1;
      }
    }

    // Ensure both have identical counts for each flexible word
    if (aCounts.length != cCounts.length) return false;
    for (final entry in aCounts.entries) {
      if (cCounts[entry.key] != entry.value) return false;
    }

    return true;
  }

  /// Checks which words in the answer are in the correct position.
  /// Returns a list of booleans where true means the word at that index is in the correct position.
  /// Each word must be in the exact position (1st, 2nd, 3rd, etc.) to be marked as correct.
  static List<bool> checkWordPositions(List<String> answerWords, List<String> correctWords) {
    if (answerWords.length != correctWords.length) {
      return List.filled(answerWords.length, false);
    }

    // Normalize to lowercase
    final List<String> a = answerWords.map((w) => w.toLowerCase().trim()).toList();
    final List<String> c = correctWords.map((w) => w.toLowerCase().trim()).toList();

    // For each position, check if the word matches exactly at that position
    final List<bool> positionCorrect = [];
    
    for (int i = 0; i < a.length; i++) {
      // Word is correct only if it matches exactly at the same position
      positionCorrect.add(a[i] == c[i]);
    }
    
    return positionCorrect;
  }
}
