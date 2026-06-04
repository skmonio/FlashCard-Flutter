import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flash_card.dart';
import '../models/deck.dart';
import '../utils/global_navigator.dart';
import 'supabase_service.dart';
import 'data_sync_service.dart';

class FlashcardService {
  static const String _decksKey = 'decks';
  static const String _cardsKey = 'cards';
  static const String _settingsKey = 'settings';

  static final FlashcardService _instance = FlashcardService._internal();
  factory FlashcardService() => _instance;
  FlashcardService._internal();

  List<Deck> _decks = [];
  List<FlashCard> _cards = [];
  Map<String, dynamic> _settings = {};

  // Getters
  List<Deck> get decks => List.unmodifiable(_decks);
  List<FlashCard> get cards => List.unmodifiable(_cards);
  Map<String, dynamic> get settings => Map.unmodifiable(_settings);

  // Initialize the service
  Future<void> initialize() async {
    await _loadData();
    await _loadSettings();
    await _ensureSystemDecks();
  }

  // Reload data from SharedPreferences (useful after data sync)
  Future<void> reloadData() async {
    await _loadData();
  }

  // MARK: - Data Persistence

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load decks
    final decksJson = prefs.getStringList(_decksKey) ?? [];
    _decks = decksJson.map((json) => Deck.fromJson(jsonDecode(json))).toList();

    // Load cards
    final cardsJson = prefs.getStringList(_cardsKey) ?? [];
    _cards = cardsJson
        .map((json) => FlashCard.fromJson(jsonDecode(json)))
        .toList();

    // Populate deck cards after loading both decks and cards
    _populateDeckCards();

    print(
      '🔍 FlashcardService: Loaded ${_decks.length} decks and ${_cards.length} cards',
    );
    for (final deck in _decks) {
      print(
        '🔍 FlashcardService: Deck: ${deck.name} (${deck.id}) with ${deck.cards.length} cards',
      );
    }
  }

  void _populateDeckCards() {
    // Clear existing cards from all decks
    for (final deck in _decks) {
      deck.cards.clear();
    }

    // Populate cards for each deck based on card.deckIds
    for (final card in _cards) {
      for (final deckId in card.deckIds) {
        final deck = _decks.firstWhere(
          (d) => d.id == deckId,
          orElse: () =>
              throw Exception('Deck $deckId not found for card ${card.id}'),
        );
        deck.cards.add(card);
      }
    }
  }

  Future<void> saveData() async {
    print('Service: Starting _saveData...');
    try {
      final prefs = await SharedPreferences.getInstance();
      print('Service: SharedPreferences instance obtained');

      // Save decks
      final decksJson = _decks
          .map((deck) => jsonEncode(deck.toJson()))
          .toList();
      print('Service: Saving ${decksJson.length} decks');
      await prefs.setStringList(_decksKey, decksJson);
      print('Service: Decks saved successfully');

      // Save cards
      final cardsJson = _cards
          .map((card) => jsonEncode(card.toJson()))
          .toList();
      print('Service: Saving ${cardsJson.length} cards');
      await prefs.setStringList(_cardsKey, cardsJson);
      print('Service: Cards saved successfully');

      // Auto-sync to cloud if user is authenticated (throttled)
      if (SupabaseService.instance.isAuthenticated) {
        print('Service: Auto-syncing to cloud (throttled)...');
        try {
          final syncResult = await DataSyncService.syncAllDataThrottled();
          if (syncResult.isFailure) {
            print('Service: Auto-sync failed: ${syncResult.message}');
            GlobalNavigator.showWarningSnackBar(syncResult.message);
          } else if (syncResult.isSuccess) {
            print('Service: Auto-sync completed successfully');
          }
        } catch (e) {
          print('Service: Auto-sync failed (non-critical): $e');
          GlobalNavigator.showWarningSnackBar('Cloud sync failed.');
          // Don't rethrow - local save was successful
        }
      }
    } catch (e) {
      print('Service: Error in _saveData: $e');
      rethrow;
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    if (settingsJson != null) {
      _settings = jsonDecode(settingsJson);
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(_settings));
  }

  // MARK: - System Decks

  Future<void> _ensureSystemDecks() async {
    // First, clean up any duplicate default decks
    await _cleanupDuplicateDefaultDecks();

    // Ensure Uncategorized deck exists
    if (!_decks.any((deck) => deck.name == 'Uncategorized')) {
      print('🔍 FlashcardService: Creating missing Uncategorized deck');
      await createDeck('Uncategorized');
    } else {
      print('🔍 FlashcardService: Uncategorized deck already exists');
    }

    // Ensure Review deck exists
    if (!_decks.any((deck) => deck.name == 'Review')) {
      print('🔍 FlashcardService: Creating missing Review deck');
      await createDeck('Review');
    } else {
      print('🔍 FlashcardService: Review deck already exists');
    }
  }

  Future<void> _cleanupDuplicateDefaultDecks() async {
    final defaultDeckNames = {'Uncategorized', 'Review'};
    final decksToRemove = <String>[];

    for (final deckName in defaultDeckNames) {
      final decksWithName = _decks
          .where((deck) => deck.name == deckName)
          .toList();

      if (decksWithName.length > 1) {
        print(
          '🔍 FlashcardService: Found ${decksWithName.length} duplicate $deckName decks',
        );

        // Keep the first one, remove the rest
        for (int i = 1; i < decksWithName.length; i++) {
          final deckToRemove = decksWithName[i];
          print(
            '🔍 FlashcardService: Removing duplicate $deckName deck: ${deckToRemove.id}',
          );

          // Move any cards from the duplicate deck to the first one
          final firstDeck = decksWithName[0];
          for (final card in _cards) {
            if (card.deckIds.contains(deckToRemove.id)) {
              card.deckIds.remove(deckToRemove.id);
              if (!card.deckIds.contains(firstDeck.id)) {
                card.deckIds.add(firstDeck.id);
              }
            }
          }

          decksToRemove.add(deckToRemove.id);
        }
      }
    }

    // Remove the duplicate decks
    if (decksToRemove.isNotEmpty) {
      _decks.removeWhere((deck) => decksToRemove.contains(deck.id));
      await saveData();
      print(
        '🔍 FlashcardService: Cleaned up ${decksToRemove.length} duplicate default decks',
      );
    }
  }

  // Add card to review deck
  Future<void> addCardToReview(FlashCard card) async {
    final reviewDeck = _decks.firstWhere((deck) => deck.name == 'Review');
    if (!card.deckIds.contains(reviewDeck.id)) {
      card.deckIds.add(reviewDeck.id);
      await saveData();
    }
  }

  // Remove card from review deck
  Future<void> removeCardFromReview(FlashCard card) async {
    final reviewDeck = _decks.firstWhere((deck) => deck.name == 'Review');
    if (card.deckIds.contains(reviewDeck.id)) {
      card.deckIds.remove(reviewDeck.id);
      await saveData();
    }
  }

  // MARK: - Deck Management

  Future<Deck> createDeck(
    String name, {
    String? parentId,
    bool isPublic = false,
    int? colorValue,
  }) async {
    print('Service: Creating deck: $name');
    try {
      final deck = Deck(name: name, parentId: parentId, isPublic: isPublic);

      print('Service: Deck object created: ${deck.name} (${deck.id})');
      _decks.add(deck);
      print('Service: Deck added to list. Total decks: ${_decks.length}');

      await saveData();
      print('Service: Data saved successfully');

      return deck;
    } catch (e) {
      print('Service: Error creating deck "$name": $e');
      rethrow;
    }
  }

  Future<void> updateDeck(Deck deck) async {
    final index = _decks.indexWhere((d) => d.id == deck.id);
    if (index != -1) {
      _decks[index] = deck;
      await saveData();
    }
  }

  Future<void> deleteDeck(String deckId) async {
    // Check if this is a default deck that shouldn't be deleted
    final deck = getDeck(deckId);
    if (deck != null &&
        (deck.name == 'Uncategorized' || deck.name == 'Review')) {
      throw Exception('Cannot delete default decks (${deck.name})');
    }

    // Remove all cards from this deck
    _cards.removeWhere((card) => card.deckIds.contains(deckId));

    // Remove the deck
    _decks.removeWhere((deck) => deck.id == deckId);

    // Remove from parent decks
    for (final deck in _decks) {
      deck.subDeckIds.remove(deckId);
    }

    await saveData();
  }

  Deck? getDeck(String deckId) {
    try {
      return _decks.firstWhere((deck) => deck.id == deckId);
    } catch (e) {
      return null;
    }
  }

  List<Deck> getSubDecks(String parentDeckId) {
    return _decks.where((deck) => deck.parentId == parentDeckId).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<Deck> getRootDecks() {
    return _decks.where((deck) => deck.parentId == null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  // MARK: - Card Management

  Future<FlashCard> createCard({
    required String word,
    required String definition,
    required String example,
    String exampleTranslation = '',
    Set<String>? deckIds,
    String article = '',
    String plural = '',
    String presentTense = '',
    String pastTense = '',
    String perfectTense = '',
  }) async {
    print('Service: Creating card: $word with deckIds: $deckIds');
    try {
      // Handle empty deckIds by defaulting to Uncategorized
      Set<String> finalDeckIds = deckIds ?? {};
      if (finalDeckIds.isEmpty) {
        // Find or create Uncategorized deck
        final uncategorizedDeck = _decks.firstWhere(
          (deck) => deck.name.toLowerCase() == 'uncategorized',
          orElse: () => Deck(id: '', name: '', parentId: null),
        );

        if (uncategorizedDeck.id.isNotEmpty) {
          finalDeckIds.add(uncategorizedDeck.id);
          print(
            'Service: Using existing Uncategorized deck: ${uncategorizedDeck.id}',
          );
        } else {
          // Create Uncategorized deck if it doesn't exist
          final newUncategorizedDeck = await createDeck('Uncategorized');
          if (newUncategorizedDeck != null) {
            finalDeckIds.add(newUncategorizedDeck.id);
            print(
              'Service: Created new Uncategorized deck: ${newUncategorizedDeck.id}',
            );
          } else {
            print(
              'Service: Warning: Could not create Uncategorized deck, card will have no decks',
            );
          }
        }
      }

      final card = FlashCard(
        word: word,
        definition: definition,
        example: example,
        exampleTranslation: exampleTranslation,
        deckIds: finalDeckIds,
        article: article,
        plural: plural,
        presentTense: presentTense,
        pastTense: pastTense,
        perfectTense: perfectTense,
      );

      print('Service: Card object created: ${card.word} (${card.id})');
      _cards.add(card);
      print('Service: Card added to list. Total cards: ${_cards.length}');

      _populateDeckCards(); // Repopulate deck cards after creating new card
      await saveData();
      print('Service: Card data saved successfully');

      return card;
    } catch (e) {
      print('Service: Error creating card "$word": $e');
      rethrow;
    }
  }

  Future<void> updateCard(FlashCard card) async {
    final index = _cards.indexWhere((c) => c.id == card.id);
    if (index != -1) {
      _cards[index] = card;
      _populateDeckCards(); // Repopulate deck cards after updating
      await saveData();
    }
  }

  Future<void> deleteCard(String cardId) async {
    print('Service: Deleting card: $cardId');
    final initialCount = _cards.length;
    _cards.removeWhere((card) => card.id == cardId);
    final finalCount = _cards.length;
    print('Service: Cards before deletion: $initialCount, after: $finalCount');
    _populateDeckCards(); // Repopulate deck cards after deletion
    await saveData();
    print('Service: Card deletion completed');
  }

  FlashCard? getCard(String cardId) {
    try {
      return _cards.firstWhere((card) => card.id == cardId);
    } catch (e) {
      return null;
    }
  }

  List<FlashCard> getCardsForDeck(String deckId) {
    return _cards.where((card) => card.deckIds.contains(deckId)).toList();
  }

  List<FlashCard> getCardsForDeckWithSubDecks(String deckId) {
    // Get cards from the main deck
    final mainDeckCards = getCardsForDeck(deckId);

    // Get all sub-decks
    final subDecks = getSubDecks(deckId);

    // Get cards from all sub-decks
    final subDeckCards = <FlashCard>[];
    for (final subDeck in subDecks) {
      subDeckCards.addAll(getCardsForDeck(subDeck.id));
    }

    // Combine and deduplicate all cards by ID
    final allCards = <FlashCard>[];
    final seenCardIds = <String>{};

    // Add main deck cards
    for (final card in mainDeckCards) {
      if (!seenCardIds.contains(card.id)) {
        allCards.add(card);
        seenCardIds.add(card.id);
      }
    }

    // Add sub-deck cards (deduplicated)
    for (final card in subDeckCards) {
      if (!seenCardIds.contains(card.id)) {
        allCards.add(card);
        seenCardIds.add(card.id);
      }
    }

    return allCards;
  }

  List<FlashCard> getCardsForDecks(List<String> deckIds) {
    // Get all cards that belong to any of the specified decks
    final allCards = _cards
        .where((card) => card.deckIds.any((deckId) => deckIds.contains(deckId)))
        .toList();

    // Deduplicate by card ID
    final uniqueCards = <FlashCard>[];
    final seenCardIds = <String>{};
    for (final card in allCards) {
      if (!seenCardIds.contains(card.id)) {
        uniqueCards.add(card);
        seenCardIds.add(card.id);
      }
    }

    return uniqueCards;
  }

  // MARK: - Study Session Management

  List<FlashCard> getDueCardsForDeck(String deckId) {
    final deckCards = getCardsForDeck(deckId);
    return deckCards.where((card) => card.isDueForReview).toList();
  }

  List<FlashCard> getNewCardsForDeck(String deckId, {int limit = 20}) {
    final deckCards = getCardsForDeck(deckId);
    final newCards = deckCards.where((card) => card.isNew).toList();
    return newCards.take(limit).toList();
  }

  List<FlashCard> getLearningCardsForDeck(String deckId) {
    final deckCards = getCardsForDeck(deckId);
    return deckCards.where((card) => card.isLearning).toList();
  }

  List<FlashCard> getReviewCardsForDeck(String deckId) {
    final deckCards = getCardsForDeck(deckId);
    return deckCards.where((card) => card.isReviewing).toList();
  }

  // MARK: - Statistics

  Map<String, dynamic> getDeckStatistics(String deckId) {
    final cards = getCardsForDeck(deckId);

    int totalCards = cards.length;
    int newCards = cards.where((card) => card.isNew).length;
    int learningCards = cards.where((card) => card.isLearning).length;
    int reviewCards = cards.where((card) => card.isReviewing).length;
    int learnedCards = cards.where((card) => card.isFullyLearned).length;

    int totalShown = 0;
    int totalCorrect = 0;

    for (final card in cards) {
      totalShown += card.timesShown;
      totalCorrect += card.timesCorrect;
    }

    double accuracy = totalShown > 0 ? (totalCorrect / totalShown) * 100 : 0.0;

    return {
      'totalCards': totalCards,
      'newCards': newCards,
      'learningCards': learningCards,
      'reviewCards': reviewCards,
      'learnedCards': learnedCards,
      'totalShown': totalShown,
      'totalCorrect': totalCorrect,
      'accuracy': accuracy,
    };
  }

  // MARK: - Settings Management

  Future<void> updateSetting(String key, dynamic value) async {
    _settings[key] = value;
    await _saveSettings();
  }

  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settings[key] as T? ?? defaultValue;
  }

  // MARK: - Data Import/Export

  Future<Map<String, dynamic>> exportData() async {
    return {
      'decks': _decks.map((deck) => deck.toJson()).toList(),
      'cards': _cards.map((card) => card.toJson()).toList(),
      'settings': _settings,
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    // Import decks
    final decksJson = data['decks'] as List<dynamic>? ?? [];
    _decks = decksJson.map((json) => Deck.fromJson(json)).toList();

    // Import cards
    final cardsJson = data['cards'] as List<dynamic>? ?? [];
    _cards = cardsJson.map((json) => FlashCard.fromJson(json)).toList();

    // Import settings
    _settings = Map<String, dynamic>.from(data['settings'] ?? {});

    await saveData();
    await _saveSettings();
  }

  // MARK: - Search and Filter

  List<FlashCard> searchCards(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _cards
        .where(
          (card) =>
              card.word.toLowerCase().contains(lowercaseQuery) ||
              card.definition.toLowerCase().contains(lowercaseQuery) ||
              card.example.toLowerCase().contains(lowercaseQuery),
        )
        .toList();
  }

  List<Deck> searchDecks(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _decks
        .where((deck) => deck.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }
}
