import 'dart:convert';
import '../models/flash_card.dart';
import '../models/deck.dart';

class ExportService {
  // Export options
  static const String formatCSV = 'csv';
  static const String formatJSON = 'json';
  
  // Content options (simplified for flashcards only)
  static const String contentCards = 'cards';

  // Export cards to CSV
  static String exportCardsToCSV(List<FlashCard> cards, List<Deck> decks) {
    final lines = <String>[];
    
    // Header
    lines.add('Word,Translation,Deck,Example,Article,Plural,Present Tense,Past Tense,Perfect Tense');
    
    for (final card in cards) {
      final deckNames = card.deckIds.map((id) {
        final deck = decks.firstWhere(
          (d) => d.id == id,
          orElse: () => Deck(id: '', name: 'Uncategorized', parentId: null),
        );
        return deck.name;
      }).join('|');
      
      final row = [
        _escapeCSVField(card.word),
        _escapeCSVField(card.definition),
        _escapeCSVField(deckNames),
        _escapeCSVField(card.example),
        _escapeCSVField(card.article),
        _escapeCSVField(card.plural),
        _escapeCSVField(card.presentTense),
        _escapeCSVField(card.pastTense),
        _escapeCSVField(card.perfectTense),
      ];
      
      lines.add(row.join(','));
    }
    
    return lines.join('\n');
  }

  // Export cards to JSON
  static String exportCardsToJSON(List<FlashCard> cards, List<Deck> decks) {
    final exportData = <String, dynamic>{};
    exportData['cards'] = cards.map((card) => card.toMap()).toList();
    exportData['decks'] = decks.map((deck) => deck.toMap()).toList();
    exportData['exportDate'] = DateTime.now().toIso8601String();
    exportData['cardCount'] = cards.length;
    
    return jsonEncode(exportData);
  }

  // Master export method simplified for flashcards
  static String export({
    required List<FlashCard> cards,
    required List<Deck> decks,
    required String format,
    required String content,
  }) {
    if (format == formatCSV) {
      return exportCardsToCSV(cards, decks);
    } else {
      return exportCardsToJSON(cards, decks);
    }
  }

  // Private helper to escape CSV fields
  static String _escapeCSVField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
