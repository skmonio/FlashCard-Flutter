import 'package:flutter/foundation.dart';
import '../models/flash_card.dart';
import '../models/deck.dart';
import '../models/learning_mastery.dart';
import '../models/dutch_word_exercise.dart';
import '../services/flashcard_service.dart';
import '../services/unified_import_service.dart';
import '../services/dutch_grammar_exercise_generator.dart';
import '../providers/dutch_word_exercise_provider.dart';

class FlashcardProvider extends ChangeNotifier {
  final FlashcardService _service = FlashcardService();
  
  List<Deck> _decks = [];
  List<FlashCard> _cards = [];
  Map<String, dynamic> _settings = {};
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<Deck> get decks => _decks;
  List<FlashCard> get cards => _cards;
  Map<String, dynamic> get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Initialize the provider
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _service.initialize();
      _decks = _service.decks;
      _cards = _service.cards;
      _settings = _service.settings;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  // MARK: - Deck Management
  
  Future<Deck?> createDeck(String name, {String? parentId}) async {
    print('Creating deck: $name');
    try {
      final deck = await _service.createDeck(name, parentId: parentId);
      print('Deck created successfully: ${deck.name} (${deck.id})');
      // Refresh the decks list from the service instead of trying to modify the unmodifiable list
      _decks = _service.decks;
      notifyListeners();
      return deck;
    } catch (e) {
      print('Error creating deck "$name": $e');
      _setError(e.toString());
      return null;
    }
  }
  
  Future<bool> updateDeck(Deck deck) async {
    try {
      await _service.updateDeck(deck);
      // Refresh the decks list from the service
      _decks = _service.decks;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  Future<bool> deleteDeck(String deckId) async {
    try {
      await _service.deleteDeck(deckId);
      // Refresh both lists from the service
      _decks = _service.decks;
      _cards = _service.cards;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  Deck? getDeck(String deckId) {
    return _service.getDeck(deckId);
  }
  
  List<Deck> getRootDecks() {
    return _service.getRootDecks();
  }
  
  List<Deck> getSubDecks(String parentDeckId) {
    return _service.getSubDecks(parentDeckId);
  }
  
  List<Deck> getAllDecksHierarchical() {
    // Returns all decks organized hierarchically (parents first, then their children)
    List<Deck> result = [];
    final topLevel = getRootDecks()..sort((a, b) => a.name.compareTo(b.name));
    
    for (final deck in topLevel) {
      result.add(deck);
      final subDecks = getSubDecks(deck.id)..sort((a, b) => a.name.compareTo(b.name));
      result.addAll(subDecks);
    }
    
    return result;
  }
  
  // MARK: - Card Management
  
  Future<FlashCard?> createCard({
    required String word,
    String? definition,
    String? example,
    String? exampleTranslation,
    Set<String>? deckIds,
    String article = '',
    String? plural,
    String? pastTense,
    String? futureTense,
    String? pastParticiple,
  }) async {
    try {
      print('Provider: Creating card: $word');
      final card = await _service.createCard(
        word: word,
        definition: definition ?? '',
        example: example ?? '',
        exampleTranslation: exampleTranslation ?? '',
        deckIds: deckIds,
        article: article,
        plural: plural ?? '',
        pastTense: pastTense ?? '',
        futureTense: futureTense ?? '',
        pastParticiple: pastParticiple ?? '',
      );
      
      // Refresh the cards list from the service
      _cards = _service.cards;
      print('Provider: Card created and refreshed. Total cards: ${_cards.length}');
      
      // Auto-generate grammar exercises if grammar data is provided
      if (card != null && (article.isNotEmpty || (plural != null && plural!.isNotEmpty) || 
          (exampleTranslation != null && exampleTranslation!.isNotEmpty && card.example.isNotEmpty))) {
        await _generateGrammarExercisesForCard(card);
      }
      
      notifyListeners();
      return card;
    } catch (e) {
      print('Provider: Error creating card: $e');
      _setError(e.toString());
      return null;
    }
  }
  
  /// Generate grammar exercises for a card and add them to the Dutch word exercise provider
  Future<void> _generateGrammarExercisesForCard(FlashCard card) async {
    try {
      print('Provider: Generating grammar exercises for card: ${card.word}');
      
      // Generate grammar exercises
      final grammarExercises = DutchGrammarExerciseGenerator.generateGrammarExercises(card);
      
      if (grammarExercises.isNotEmpty) {
        print('Provider: Generated ${grammarExercises.length} grammar exercises');
        
        // Get the Dutch word exercise provider
        final dutchProvider = DutchWordExerciseProvider();
        await dutchProvider.initialize();
        
        // Check if there's already an exercise for this word
        final existingExercise = dutchProvider.getWordExerciseByWord(card.word);
        
        if (existingExercise != null) {
          // Check for existing grammar exercises to avoid duplicates
          final existingGrammarExercises = existingExercise.exercises.where((exercise) {
            return exercise.prompt.contains('De or Het') || 
                   exercise.prompt.contains('plural form') ||
                   exercise.prompt.contains('Build the correct Dutch sentence');
          }).toList();
          
          // Filter out exercises that already exist
          final newGrammarExercises = grammarExercises.where((newExercise) {
            return !existingGrammarExercises.any((existing) {
              // Check if this type of exercise already exists
              if (newExercise.prompt.contains('De or Het') && existing.prompt.contains('De or Het')) {
                return true; // Article exercise already exists
              }
              if (newExercise.prompt.contains('plural form') && existing.prompt.contains('plural form')) {
                return true; // Plural exercise already exists
              }
              if (newExercise.prompt.contains('Build the correct Dutch sentence') && existing.prompt.contains('Build the correct Dutch sentence')) {
                return true; // Sentence builder exercise already exists
              }
              return false;
            });
          }).toList();
          
          if (newGrammarExercises.isNotEmpty) {
            // Add only new exercises to existing word exercise
            final updatedExercise = DutchWordExercise(
              id: existingExercise.id,
              targetWord: existingExercise.targetWord,
              wordTranslation: existingExercise.wordTranslation,
              deckId: existingExercise.deckId,
              deckName: existingExercise.deckName,
              category: existingExercise.category,
              difficulty: existingExercise.difficulty,
              exercises: [...existingExercise.exercises, ...newGrammarExercises],
              createdAt: existingExercise.createdAt,
              isUserCreated: existingExercise.isUserCreated,
              learningProgress: existingExercise.learningProgress,
            );
            
            await dutchProvider.updateWordExercise(updatedExercise);
            print('Provider: Updated existing exercise with ${newGrammarExercises.length} new grammar exercises');
          } else {
            print('Provider: No new grammar exercises to add (all already exist)');
          }
        } else {
          // Create new word exercise
          final deckId = card.deckIds.isNotEmpty ? card.deckIds.first : 'default';
          final deckName = getDeck(deckId)?.name ?? 'Default';
          
          final newWordExercise = DutchWordExercise(
            id: card.id,
            targetWord: card.word,
            wordTranslation: card.definition,
            deckId: deckId,
            deckName: deckName,
            category: WordCategory.common,
            difficulty: ExerciseDifficulty.beginner,
            exercises: grammarExercises,
            createdAt: DateTime.now(),
            isUserCreated: true,
            learningProgress: LearningProgress(),
          );
          
          await dutchProvider.addWordExercise(newWordExercise);
          print('Provider: Created new word exercise with ${grammarExercises.length} grammar exercises');
        }
      }
    } catch (e) {
      print('Provider: Error generating grammar exercises: $e');
      // Don't throw the error as this is not critical for card creation
    }
  }
  
  Future<bool> updateCard(FlashCard card) async {
    try {
      await _service.updateCard(card);
      // Refresh the cards list from the service
      _cards = _service.cards;
      
      // Auto-generate grammar exercises if grammar data is provided
      if ((card.article != null && card.article!.isNotEmpty) || 
          (card.plural != null && card.plural!.isNotEmpty) ||
          (card.example.isNotEmpty && card.exampleTranslation.isNotEmpty)) {
        await _generateGrammarExercisesForCard(card);
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  Future<bool> deleteCard(String cardId) async {
    print('Provider: Deleting card: $cardId');
    try {
      await _service.deleteCard(cardId);
      // Refresh the cards list from the service
      _cards = _service.cards;
      print('Provider: Cards after deletion: ${_cards.length}');
      notifyListeners();
      print('Provider: Notified listeners of card deletion');
      return true;
    } catch (e) {
      print('Provider: Error deleting card: $e');
      _setError(e.toString());
      return false;
    }
  }
  
  FlashCard? getCard(String cardId) {
    return _service.getCard(cardId);
  }
  
  List<FlashCard> getCardsForDeck(String deckId) {
    return _service.getCardsForDeck(deckId);
  }
  
  List<FlashCard> getCardsForDeckWithSubDecks(String deckId) {
    return _service.getCardsForDeckWithSubDecks(deckId);
  }
  
  List<FlashCard> getCardsForDecks(List<String> deckIds) {
    return _service.getCardsForDecks(deckIds);
  }
  
  // MARK: - Study Session Management
  
  List<FlashCard> getDueCardsForDeck(String deckId) {
    return _service.getDueCardsForDeck(deckId);
  }
  
  List<FlashCard> getNewCardsForDeck(String deckId, {int limit = 20}) {
    return _service.getNewCardsForDeck(deckId, limit: limit);
  }
  
  List<FlashCard> getLearningCardsForDeck(String deckId) {
    return _service.getLearningCardsForDeck(deckId);
  }
  
  List<FlashCard> getReviewCardsForDeck(String deckId) {
    return _service.getReviewCardsForDeck(deckId);
  }
  
  // MARK: - Card Progress Updates
  
  Future<bool> markCardCorrect(FlashCard card) async {
    try {
      card.markCorrect(GameDifficulty.medium);
      await _service.updateCard(card);
      
      // Update the card in our local list
      final index = _cards.indexWhere((c) => c.id == card.id);
      if (index != -1) {
        _cards[index] = card;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  Future<bool> markCardIncorrect(FlashCard card) async {
    try {
      card.markIncorrect(GameDifficulty.medium);
      await _service.updateCard(card);
      
      // Update the card in our local list
      final index = _cards.indexWhere((c) => c.id == card.id);
      if (index != -1) {
        _cards[index] = card;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  // MARK: - Review Deck Management
  
  Future<bool> addCardToReview(FlashCard card) async {
    try {
      await _service.addCardToReview(card);
      // Update the card in our local list
      final index = _cards.indexWhere((c) => c.id == card.id);
      if (index != -1) {
        _cards[index] = card;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  Future<bool> removeCardFromReview(FlashCard card) async {
    try {
      await _service.removeCardFromReview(card);
      // Update the card in our local list
      final index = _cards.indexWhere((c) => c.id == card.id);
      if (index != -1) {
        _cards[index] = card;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  // MARK: - Statistics
  
  Map<String, dynamic> getDeckStatistics(String deckId) {
    return _service.getDeckStatistics(deckId);
  }
  
  Map<String, dynamic> getOverallStatistics() {
    int totalCards = _cards.length;
    int newCards = _cards.where((card) => card.isNew).length;
    int learningCards = _cards.where((card) => card.isLearning).length;
    int reviewCards = _cards.where((card) => card.isReviewing).length;
    int learnedCards = _cards.where((card) => card.isFullyLearned).length;
    
    int totalShown = 0;
    int totalCorrect = 0;
    
    for (final card in _cards) {
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
      'totalDecks': _decks.length,
    };
  }
  
  // MARK: - Settings Management
  
  Future<bool> updateSetting(String key, dynamic value) async {
    try {
      await _service.updateSetting(key, value);
      _settings[key] = value;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  T? getSetting<T>(String key, {T? defaultValue}) {
    return _service.getSetting<T>(key, defaultValue: defaultValue);
  }
  
  // MARK: - Search and Filter
  
  List<FlashCard> searchCards(String query) {
    return _service.searchCards(query);
  }
  
  List<Deck> searchDecks(String query) {
    return _service.searchDecks(query);
  }
  
  // MARK: - Data Import/Export
  
  Future<Map<String, dynamic>?> exportData() async {
    try {
      return await _service.exportData();
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }
  
  Future<bool> importData(Map<String, dynamic> data) async {
    try {
      await _service.importData(data);
      _decks = _service.decks;
      _cards = _service.cards;
      _settings = _service.settings;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
  
  // MARK: - CSV Export/Import
  
  String exportDecksToCSV(Set<String> deckIds) {
    final headers = [
      'Word', 'Definition', 'Example', 'Article', 'Plural', 
      'Past Tense', 'Future Tense', 'Past Participle', 'Decks', 
      'Success Count', 'Times Shown', 'Times Correct'
    ];
    
    var csvContent = headers.join(',') + '\n';
    
    // Collect all cards from selected decks (including hierarchy)
    final allCards = <FlashCard>{};
    
    for (final deckId in deckIds) {
      final deck = _decks.firstWhere((d) => d.id == deckId);
      
      // Get cards from the main deck
      final deckCards = getCardsForDeck(deck.id);
      allCards.addAll(deckCards);
      
      // Get cards from all sub-decks recursively
      final subDeckCards = _getAllCardsFromSubDecks(deck.id);
      allCards.addAll(subDeckCards);
    }
    
    // Convert to sorted list for consistent output
    final sortedCards = allCards.toList()
      ..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    
    for (final card in sortedCards) {
      final deckPaths = _getDeckPathsForCard(card);
      final deckPathsString = deckPaths.join('; ');
      
      final row = [
        _escapeCSVField(card.word),
        _escapeCSVField(card.definition),
        _escapeCSVField(card.example),
        _escapeCSVField(card.article),
        _escapeCSVField(card.plural),
        _escapeCSVField(card.pastTense),
        _escapeCSVField(card.futureTense),
        _escapeCSVField(card.pastParticiple),
        _escapeCSVField(deckPathsString),
        card.successCount.toString(),
        card.timesShown.toString(),
        card.timesCorrect.toString(),
      ];
      
      csvContent += row.join(',') + '\n';
    }
    
    return csvContent;
  }

  // Helper method to get all cards from sub-decks recursively
  List<FlashCard> _getAllCardsFromSubDecks(String parentDeckId) {
    final allCards = <FlashCard>[];
    final subDecks = getSubDecks(parentDeckId);
    
    for (final subDeck in subDecks) {
      // Get cards from this sub-deck
      final subDeckCards = getCardsForDeck(subDeck.id);
      allCards.addAll(subDeckCards);
      
      // Recursively get cards from sub-sub-decks
      final subSubDeckCards = _getAllCardsFromSubDecks(subDeck.id);
      allCards.addAll(subSubDeckCards);
    }
    
    return allCards;
  }

  // Helper method to get hierarchical deck paths for a card
  List<String> _getDeckPathsForCard(FlashCard card) {
    final deckPaths = <String>[];
    
    for (final deckId in card.deckIds) {
      final deck = _decks.firstWhere((d) => d.id == deckId);
      final path = _buildDeckPath(deck);
      deckPaths.add(path);
    }
    
    return deckPaths;
  }

  // Helper method to build hierarchical path for a deck
  String _buildDeckPath(Deck deck) {
    final path = <String>[deck.name];
    Deck? currentDeck = deck;
    
    // Walk up the hierarchy to build the full path
    while (currentDeck?.parentId != null) {
      try {
        currentDeck = _decks.firstWhere((d) => d.id == currentDeck!.parentId);
        path.insert(0, currentDeck!.name);
      } catch (e) {
        // Parent deck not found, stop here
        break;
      }
    }
    
    return path.join(' > ');
  }
  
  Future<Map<String, dynamic>> importFromCSV(String csvContent) async {
    print('Starting CSV import...');
    final lines = csvContent.split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    print('CSV has ${lines.length} non-empty lines');
    
    if (lines.length < 2) {
      return {
        'success': 0,
        'errors': ['CSV file appears to be empty or invalid']
      };
    }
    
    var successCount = 0;
    final errors = <String>[];
    
    // Pre-process to collect all unique deck names and their hierarchy
    final allDeckPaths = <String>{};
    final deckPathToHierarchy = <String, List<String>>{};
    
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      final fields = _parseCSVLine(line);
      if (fields.length > 0) {
        final deckNames = fields[0].trim(); // Deck info is in first column
        if (deckNames.isNotEmpty) {
          // Handle both semicolon-separated and hierarchical formats
          List<String> deckNameList;
          if (deckNames.contains(' > ')) {
            // Hierarchical format: "Chapter 2 > 2.5"
            deckNameList = deckNames.split(' > ').map((name) => name.trim()).toList();
          } else {
            // Semicolon-separated format: "Deck1; Deck2"
            deckNameList = deckNames.split(';').map((name) => name.trim()).toList();
          }
          final validDeckNames = deckNameList.where((String name) => name.isNotEmpty).toList();
          
          if (validDeckNames.isNotEmpty) {
            // Create a path representation for hierarchy
            final deckPath = validDeckNames.join(' > ');
            allDeckPaths.add(deckPath);
            deckPathToHierarchy[deckPath] = validDeckNames;
          }
        }
      }
    }
    
    print('Found deck paths: $allDeckPaths');
    
    // Create hierarchical deck structure
    final deckNameToId = <String, String>{};
    for (final deckPath in allDeckPaths) {
      final hierarchy = deckPathToHierarchy[deckPath]!;
      String? parentId;
      
      for (int i = 0; i < hierarchy.length; i++) {
        final deckName = hierarchy[i];
        final isSubDeck = i > 0;
        
        try {
          // Check if deck exists at this level
          Deck? existingDeck;
          if (isSubDeck && parentId != null) {
            // Look for existing sub-deck under the parent
            existingDeck = _decks.firstWhere((d) => 
              d.name == deckName && d.parentId == parentId);
          } else if (!isSubDeck) {
            // Look for existing root deck
            existingDeck = _decks.firstWhere((d) => 
              d.name == deckName && d.parentId == null);
          }
          
          if (existingDeck != null) {
            deckNameToId[deckName] = existingDeck.id;
            parentId = existingDeck.id;
            print('Found existing deck: $deckName (${existingDeck.id})');
          } else {
            // Create new deck
            print('Creating new deck: $deckName${isSubDeck ? ' (sub-deck)' : ''}');
            final newDeck = await createDeck(deckName, parentId: parentId);
            if (newDeck != null) {
              deckNameToId[deckName] = newDeck.id;
              parentId = newDeck.id;
              print('Created deck: $deckName (${newDeck.id})');
              // Refresh the decks list to include the new deck
              _decks = _service.decks;
            } else {
              print('ERROR: Failed to create deck "$deckName"');
              errors.add('Failed to create deck "$deckName"');
              break; // Stop creating hierarchy for this path
            }
          }
        } catch (e) {
          // Deck doesn't exist, create it
          print('Creating new deck: $deckName${isSubDeck ? ' (sub-deck)' : ''}');
          final newDeck = await createDeck(deckName, parentId: parentId);
          if (newDeck != null) {
            deckNameToId[deckName] = newDeck.id;
            parentId = newDeck.id;
            print('Created deck: $deckName (${newDeck.id})');
            // Refresh the decks list to include the new deck
            _decks = _service.decks;
          } else {
            print('ERROR: Failed to create deck "$deckName"');
            errors.add('Failed to create deck "$deckName"');
            break; // Stop creating hierarchy for this path
          }
        }
      }
    }
    
    print('Final deckNameToId map: $deckNameToId');
    print('Current decks in provider: ${_decks.map((d) => '${d.name} (${d.id})').toList()}');
    
    // Ensure Uncategorized deck exists
    Deck? uncategorizedDeck;
    try {
      uncategorizedDeck = _decks.firstWhere((d) => d.name == 'Uncategorized');
      print('Found existing Uncategorized deck: ${uncategorizedDeck.name}');
    } catch (e) {
      print('Uncategorized deck not found, creating new one...');
      // Try to create the Uncategorized deck
      uncategorizedDeck = await createDeck('Uncategorized');
      if (uncategorizedDeck == null) {
        print('ERROR: Failed to create Uncategorized deck');
        errors.add('Failed to create Uncategorized deck. Please try again.');
        return {
          'success': 0,
          'errors': errors,
        };
      } else {
        print('Successfully created Uncategorized deck: ${uncategorizedDeck.name}');
      }
    }
    
    // Skip header row
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1; // 1-based indexing
      
      try {
        print('Processing line $lineNumber: $line');
        final fields = _parseCSVLine(line);
        print('Parsed fields: $fields');
        
        // Validate minimum required fields
        if (fields.length < 3 || 
            fields[1].trim().isEmpty || 
            fields[2].trim().isEmpty) {
          errors.add('Line $lineNumber: Missing required word or definition');
          continue;
        }
        
        final word = fields[1].trim(); // Word is in second column
        final definition = fields[2].trim(); // Definition is in third column
        final example = fields.length > 3 ? fields[3].trim() : '';
        final article = fields.length > 4 ? fields[4].trim() : '';
        final plural = fields.length > 5 ? fields[5].trim() : '';
        final pastTense = fields.length > 6 ? fields[6].trim() : '';
        final futureTense = fields.length > 7 ? fields[7].trim() : '';
        final pastParticiple = fields.length > 8 ? fields[8].trim() : '';
        
        // Handle deck assignment using pre-created decks
        final deckNames = fields[0].trim(); // Deck info is in first column
        final deckIds = <String>{};
        
        if (deckNames.isNotEmpty) {
          // Handle both semicolon-separated and hierarchical formats
          List<String> deckNameList;
          if (deckNames.contains(' > ')) {
            // Single hierarchical format: "Chapter 2 > 2.5"
            deckNameList = [deckNames];
          } else {
            // Semicolon-separated format: "Deck1; Deck2"
            deckNameList = deckNames.split(';').map((name) => name.trim()).toList();
          }
          print('Deck names from CSV: $deckNameList');
          
          for (final deckPath in deckNameList) {
            if (deckPath.isNotEmpty) {
              // Handle hierarchical deck paths (e.g., "Parent > Child > Grandchild")
              final hierarchy = deckPath.split('>').map((name) => name.trim()).toList();
              
              if (hierarchy.length == 1) {
                // Simple deck name (no hierarchy)
                final deckName = hierarchy[0];
                final deckId = deckNameToId[deckName];
                print('Looking for deck "$deckName", found ID: $deckId');
                if (deckId != null) {
                  deckIds.add(deckId);
                  print('Added deck ID $deckId for deck "$deckName"');
                } else {
                  print('ERROR: Deck "$deckName" not found in deckNameToId map');
                  errors.add('Line $lineNumber: Deck "$deckName" not found or could not be created');
                }
              } else {
                // Hierarchical deck path - find the leaf deck (last in hierarchy)
                final leafDeckName = hierarchy.last;
                final deckId = deckNameToId[leafDeckName];
                print('Looking for hierarchical deck "$deckPath" (leaf: "$leafDeckName"), found ID: $deckId');
                if (deckId != null) {
                  deckIds.add(deckId);
                  print('Added deck ID $deckId for hierarchical deck "$deckPath"');
                } else {
                  print('ERROR: Hierarchical deck "$deckPath" not found in deckNameToId map');
                  errors.add('Line $lineNumber: Hierarchical deck "$deckPath" not found or could not be created');
                }
              }
            }
          }
        }
        
        // If no decks specified, add to Uncategorized
        if (deckIds.isEmpty && uncategorizedDeck != null) {
          deckIds.add(uncategorizedDeck.id);
        }
        
        // Handle statistics
        int cardSuccessCount = 0;
        int timesShown = 0;
        int timesCorrect = 0;
        
        if (fields.length > 9) {
          cardSuccessCount = int.tryParse(fields[9].trim()) ?? 0;
        }
        if (fields.length > 10) {
          timesShown = int.tryParse(fields[10].trim()) ?? 0;
        }
        if (fields.length > 11) {
          timesCorrect = int.tryParse(fields[11].trim()) ?? 0;
        }
        
        // Validate statistics to prevent invalid learning percentages
        if (timesCorrect > timesShown) {
          print('Warning: timesCorrect ($timesCorrect) > timesShown ($timesShown), clamping to valid values');
          timesCorrect = timesShown; // Clamp to prevent percentages over 100%
        }
        
        print('Creating card with deckIds: $deckIds');
        // Create the card
        final newCard = await createCard(
          word: word,
          definition: definition,
          example: example,
          deckIds: deckIds,
          article: article,
          plural: plural,
          pastTense: pastTense,
          futureTense: futureTense,
          pastParticiple: pastParticiple,
        );
        
        if (newCard != null) {
          // Update statistics if provided
          newCard.successCount = cardSuccessCount;
          // Note: timesShown and timesCorrect are now computed from learningMastery
          // The legacy setters are no longer available
          
          // Update the card in the service
          await _service.updateCard(newCard);
          
          successCount++;
          print('Successfully created card: ${newCard.word}');
        } else {
          print('Failed to create card: $word');
          errors.add('Line $lineNumber: Failed to create card "$word"');
        }
      } catch (e) {
        errors.add('Line $lineNumber: ${e.toString()}');
      }
    }
    
    // Refresh data after import
    refresh();
    
    return {
      'success': successCount,
      'errors': errors,
    };
  }
  
  String _escapeCSVField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
  
  List<String> _parseCSVLine(String line) {
    print('Parsing CSV line: "$line"');
    final fields = <String>[];
    var currentField = '';
    var inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          currentField += '"';
          i++; // Skip next quote
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // End of field
        fields.add(currentField);
        currentField = '';
      } else {
        currentField += char;
      }
    }
    
    // Add the last field
    fields.add(currentField);
    
    print('Parsed fields: $fields');
    return fields;
  }
  
  List<String> getDeckNamesForCard(FlashCard card) {
    return card.deckIds.map((deckId) {
      try {
        return _decks.firstWhere((d) => d.id == deckId).name;
      } catch (e) {
        return 'Unknown Deck';
      }
    }).toList();
  }
  
  // MARK: - Unified Import/Export
  
  Future<Map<String, dynamic>> importUnifiedCSV(String csvContent) async {
    print('Starting unified CSV import...');
    try {
      final result = await UnifiedImportService.parseUnifiedCSV(csvContent);
      
      if (!result['success']) {
        return {
          'success': 0,
          'errors': result['errors'],
        };
      }
      
      final cards = (result['cards'] as List<dynamic>).cast<FlashCard>();
      final exercises = (result['exercises'] as List<dynamic>).cast<DutchWordExercise>();
      final errors = (result['errors'] as List<dynamic>).cast<String>();
      
      var successCount = 0;
      var skippedCount = 0;
      
      // Import cards with duplicate prevention
      for (final card in cards) {
        // Check if card already exists (case-insensitive word match)
        final existingCard = _cards.firstWhere(
          (existing) => existing.word.toLowerCase() == card.word.toLowerCase(),
          orElse: () => FlashCard(
            id: '',
            word: '',
            definition: '',
            example: '',
          ),
        );
        
        if (existingCard.id.isNotEmpty) {
          // Card already exists, skip it
          skippedCount++;
          print('Skipping duplicate card: ${card.word}');
          continue;
        }
        
        final newCard = await createCard(
          word: card.word,
          definition: card.definition,
          example: card.example,
          deckIds: card.deckIds,
          article: card.article,
          plural: card.plural,
          pastTense: card.pastTense,
          futureTense: card.futureTense,
          pastParticiple: card.pastParticiple,
        );
        
        if (newCard != null) {
          successCount++;
        }
      }
      
      // Import exercises to DutchWordExerciseProvider
      var exerciseSuccessCount = 0;
      if (exercises.isNotEmpty) {
        try {
          // Get the DutchWordExerciseProvider from the same context
          // We'll need to pass it as a parameter or access it differently
          print('Found ${exercises.length} exercises to import');
          // TODO: Actually import exercises to DutchWordExerciseProvider
          // This requires access to the provider context
        } catch (e) {
          print('Error importing exercises: $e');
          errors.add('Failed to import exercises: $e');
        }
      }
      
      // Refresh data
      refresh();
      
      return {
        'success': successCount,
        'skipped': skippedCount,
        'exercises': exercises.length,
        'errors': errors,
      };
    } catch (e) {
      return {
        'success': 0,
        'errors': [e.toString()],
      };
    }
  }
  
  // MARK: - Data Persistence
  
  Future<void> saveData() async {
    try {
      await _service.saveData();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  String exportUnifiedCSV(Set<String> deckIds, {List<DutchWordExercise>? exercises}) {
    // Get cards from selected decks
    final allCards = <FlashCard>{};
    
    for (final deckId in deckIds) {
      final deck = _decks.firstWhere((d) => d.id == deckId);
      final deckCards = getCardsForDeck(deck.id);
      allCards.addAll(deckCards);
      
      // Add cards from sub-decks
      final subDecks = getSubDecks(deck.id);
      for (final subDeck in subDecks) {
        final subDeckCards = getCardsForDeck(subDeck.id);
        allCards.addAll(subDeckCards);
      }
    }
    
    // Get exercises for the cards in these decks
    final allExercises = <DutchWordExercise>[];
    final cardWords = allCards.map((card) => card.word).toSet();
    
    // Use provided exercises or empty list
    if (exercises != null) {
      // Filter exercises to only include those for cards in the selected decks
      for (final exercise in exercises) {
        if (cardWords.contains(exercise.targetWord)) {
          allExercises.add(exercise);
        }
      }
    }
    
    final cards = allCards.toList()
      ..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    
    // Create a custom export that includes hierarchical deck names
    return _exportUnifiedCSVWithDeckNames(cards, allExercises);
  }
  
  // MARK: - Custom Export Methods
  
  String _exportUnifiedCSVWithDeckNames(List<FlashCard> cards, List<DutchWordExercise> exercises) {
    final lines = <String>[];
    
    // Add header
    final headers = [
      'Decks', 'Word', 'Definition', 'Example', 'Article', 'Plural', 
      'Past Tense', 'Future Tense', 'Past Participle', 'Exercise Type', 
      'Question', 'Correct Answer', 'Options', 'Explanation'
    ];
    lines.add(headers.join(','));
    
    // Group exercises by word for easier lookup
    final exerciseMap = <String, DutchWordExercise>{};
    for (final exercise in exercises) {
      exerciseMap[exercise.targetWord] = exercise;
    }
    
    // Export each card
    for (final card in cards) {
      final exercise = exerciseMap[card.word];
      final deckPaths = _getDeckPathsForCard(card);
      final deckPathsString = deckPaths.join('; ');
      
      if (exercise != null && exercise.exercises.isNotEmpty) {
        // Add word data row (no exercise)
        lines.add([
          _escapeCSVField(deckPathsString),
          _escapeCSVField(card.word),
          _escapeCSVField(card.definition ?? ''),
          _escapeCSVField(card.example ?? ''),
          _escapeCSVField(card.article ?? ''),
          _escapeCSVField(card.plural ?? ''),
          _escapeCSVField(card.pastTense ?? ''),
          _escapeCSVField(card.futureTense ?? ''),
          _escapeCSVField(card.pastParticiple ?? ''),
          '', // No exercise type
          '', // No question
          '', // No correct answer
          '', // No options
          '', // No explanation
        ].join(','));
        
        // Add exercise rows
        for (final ex in exercise.exercises) {
          lines.add([
            _escapeCSVField(deckPathsString),
            _escapeCSVField(card.word),
            _escapeCSVField(card.definition ?? ''),
            _escapeCSVField(card.example ?? ''),
            _escapeCSVField(card.article ?? ''),
            _escapeCSVField(card.plural ?? ''),
            _escapeCSVField(card.pastTense ?? ''),
            _escapeCSVField(card.futureTense ?? ''),
            _escapeCSVField(card.pastParticiple ?? ''),
            _escapeCSVField(_convertExerciseTypeToCSV(ex.type)),
            _escapeCSVField(ex.prompt),
            _escapeCSVField(ex.correctAnswer),
            _escapeCSVField(ex.options.join(';')),
            _escapeCSVField(ex.explanation ?? ''),
          ].join(','));
        }
      } else {
        // Export as basic flashcard (no exercises)
        lines.add([
          _escapeCSVField(deckPathsString),
          _escapeCSVField(card.word),
          _escapeCSVField(card.definition ?? ''),
          _escapeCSVField(card.example ?? ''),
          _escapeCSVField(card.article ?? ''),
          _escapeCSVField(card.plural ?? ''),
          _escapeCSVField(card.pastTense ?? ''),
          _escapeCSVField(card.futureTense ?? ''),
          _escapeCSVField(card.pastParticiple ?? ''),
          '', // No exercise type
          '', // No question
          '', // No correct answer
          '', // No options
          '', // No explanation
        ].join(','));
      }
    }
    
    return lines.join('\n');
  }
  
  String _convertExerciseTypeToCSV(ExerciseType type) {
    switch (type) {
      case ExerciseType.sentenceBuilding:
        return 'Sentence Building';
      case ExerciseType.multipleChoice:
        return 'Multiple Choice';
      case ExerciseType.fillInBlank:
        return 'Fill in Blank';
      default:
        return 'Multiple Choice';
    }
  }
  
  // MARK: - Utility Methods
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void refresh() {
    _decks = _service.decks;
    _cards = _service.cards;
    _settings = _service.settings;
    notifyListeners();
  }
} 