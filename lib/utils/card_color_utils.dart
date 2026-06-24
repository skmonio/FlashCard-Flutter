import 'package:flutter/material.dart';
import '../models/flash_card.dart';
import '../providers/flashcard_provider.dart';

class CardColorUtils {
  // Generate consistent vibrant colors based on card content
  static const List<Color> vibrantColors = [
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF673AB7), // Deep Purple
    Color(0xFF3F51B5), // Indigo
    Color(0xFF2196F3), // Blue
    Color(0xFF03A9F4), // Light Blue
    Color(0xFF00BCD4), // Cyan
    Color(0xFF009688), // Teal
    Color(0xFF4CAF50), // Green
    Color(0xFF8BC34A), // Light Green
    Color(0xFFCDDC39), // Lime
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFFC107), // Amber
    Color(0xFFFF9800), // Orange
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF795548), // Brown
  ];

  /// Returns a consistent color for a card based on its word and definition hash.
  static Color getBorderColor(FlashCard card) {
    final hash = card.word.hashCode + card.definition.hashCode;
    final index = hash.abs() % vibrantColors.length;
    return vibrantColors[index];
  }

  static Color getSrsColor(int srsLevel) {
    switch (srsLevel) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.lightGreen;
      default:
        return Colors.green;
    }
  }

  static String getSrsDescription(int srsLevel) {
    switch (srsLevel) {
      case 0:
        return 'New card - never studied';
      case 1:
        return 'Learning phase - review every day';
      case 2:
        return 'Early learning - review every 6 days';
      case 3:
        return 'Mid-learning - review every 15 days';
      case 4:
        return 'Review phase - longer intervals';
      case 5:
        return 'Well learned - review every 2-4 weeks';
      case 6:
        return 'Familiar - review every 1-2 months';
      case 7:
        return 'Very familiar - review every 2-4 months';
      case 8:
        return 'Mastered - review every 4-8 months';
      case 9:
        return 'Expert - review every 6-12 months';
      default:
        return 'Mastered - review every 8+ months';
    }
  }

  static String getDeckNames(FlashCard card, FlashcardProvider provider) {
    final deckNames = card.deckIds.map((deckId) {
      final deck = provider.getDeck(deckId);
      return deck?.name ?? 'Unknown Deck';
    }).toList();

    if (deckNames.isEmpty) return 'Uncategorized';
    if (deckNames.length == 1) return deckNames.first;
    return '${deckNames.first} +${deckNames.length - 1} more';
  }
}
