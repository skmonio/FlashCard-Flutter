import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flash_card.dart';
import '../models/deck.dart';

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
  
  // MARK: - Data Persistence
  
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load decks
    final decksJson = prefs.getStringList(_decksKey) ?? [];
    _decks = decksJson
        .map((json) => Deck.fromJson(jsonDecode(json)))
        .toList();
    
    // Load cards
    final cardsJson = prefs.getStringList(_cardsKey) ?? [];
    _cards = cardsJson
        .map((json) => FlashCard.fromJson(jsonDecode(json)))
        .toList();
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
    // Ensure Uncategorized deck exists
    if (!_decks.any((deck) => deck.name == 'Uncategorized')) {
      await createDeck('Uncategorized');
    }
    
    // Ensure Review deck exists
    if (!_decks.any((deck) => deck.name == 'Review')) {
      await createDeck('Review');
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
  
  Future<Deck> createDeck(String name, {String? parentId}) async {
    print('Service: Creating deck: $name');
    try {
      final deck = Deck(
        name: name,
        parentId: parentId,
      );
      
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
    return _decks.where((deck) => deck.parentId == parentDeckId).toList();
  }
  
  List<Deck> getRootDecks() {
    return _decks.where((deck) => deck.parentId == null).toList();
  }
  
  // MARK: - Card Management
  
  Future<FlashCard> createCard({
    required String word,
    required String definition,
    required String example,
    Set<String>? deckIds,
    String article = '',
    String plural = '',
    String pastTense = '',
    String futureTense = '',
    String pastParticiple = '',
  }) async {
    print('Service: Creating card: $word with deckIds: $deckIds');
    try {
      final card = FlashCard(
        word: word,
        definition: definition,
        example: example,
        deckIds: deckIds ?? {},
        article: article,
        plural: plural,
        pastTense: pastTense,
        futureTense: futureTense,
        pastParticiple: pastParticiple,
      );
      
      print('Service: Card object created: ${card.word} (${card.id})');
      _cards.add(card);
      print('Service: Card added to list. Total cards: ${_cards.length}');
      
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
      await saveData();
    }
  }
  
  Future<void> deleteCard(String cardId) async {
    print('Service: Deleting card: $cardId');
    final initialCount = _cards.length;
    _cards.removeWhere((card) => card.id == cardId);
    final finalCount = _cards.length;
    print('Service: Cards before deletion: $initialCount, after: $finalCount');
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
    
    // Combine and return all cards
    final allCards = <FlashCard>[];
    allCards.addAll(mainDeckCards);
    allCards.addAll(subDeckCards);
    
    return allCards;
  }
  
  List<FlashCard> getCardsForDecks(List<String> deckIds) {
    return _cards.where((card) => 
        card.deckIds.any((deckId) => deckIds.contains(deckId))).toList();
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
    _decks = decksJson
        .map((json) => Deck.fromJson(json))
        .toList();
    
    // Import cards
    final cardsJson = data['cards'] as List<dynamic>? ?? [];
    _cards = cardsJson
        .map((json) => FlashCard.fromJson(json))
        .toList();
    
    // Import settings
    _settings = Map<String, dynamic>.from(data['settings'] ?? {});
    
    await saveData();
    await _saveSettings();
  }
  
  // MARK: - Search and Filter
  
  List<FlashCard> searchCards(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _cards.where((card) =>
        card.word.toLowerCase().contains(lowercaseQuery) ||
        card.definition.toLowerCase().contains(lowercaseQuery) ||
        card.example.toLowerCase().contains(lowercaseQuery)).toList();
  }
  
  List<Deck> searchDecks(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _decks.where((deck) =>
        deck.name.toLowerCase().contains(lowercaseQuery)).toList();
  }
} 