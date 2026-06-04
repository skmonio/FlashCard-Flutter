import 'package:flutter/material.dart';
import '../models/flash_card.dart';

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
}
