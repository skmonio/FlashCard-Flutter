import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flash_card.dart';
import '../models/deck.dart';
import '../models/learning_mastery.dart';
import 'supabase_service.dart';

class SupabaseFlashcardService {
  static final SupabaseFlashcardService _instance = SupabaseFlashcardService._internal();
  factory SupabaseFlashcardService() => _instance;
  SupabaseFlashcardService._internal();
  
  SupabaseClient get _client => SupabaseService.instance.client;
  
  // MARK: - Flashcard Operations
  
  /// Get all flashcards for the current user
  Future<List<FlashCard>> getFlashcards() async {
    try {
      final response = await _client
          .from('flashcards')
          .select('''
            *,
            learning_mastery(*)
          ''')
          .order('created_at', ascending: false);
      
      return response.map<FlashCard>((data) {
        final flashcard = FlashCard.fromJson(data);
        
        // Attach learning mastery if it exists
        if (data['learning_mastery'] != null && data['learning_mastery'].isNotEmpty) {
          final masteryData = data['learning_mastery'][0];
          flashcard.learningMastery = LearningMastery.fromJson(masteryData);
        }
        
        return flashcard;
      }).toList();
    } catch (e) {
      print('Error fetching flashcards: $e');
      rethrow;
    }
  }
  
  /// Get a specific flashcard by ID
  Future<FlashCard?> getFlashcard(String id) async {
    try {
      final response = await _client
          .from('flashcards')
          .select('''
            *,
            learning_mastery(*)
          ''')
          .eq('id', id)
          .maybeSingle();
      
      if (response == null) return null;
      
      final flashcard = FlashCard.fromJson(response);
      
      // Attach learning mastery if it exists
      if (response['learning_mastery'] != null && response['learning_mastery'].isNotEmpty) {
        final masteryData = response['learning_mastery'][0];
        flashcard.learningMastery = LearningMastery.fromJson(masteryData);
      }
      
      return flashcard;
    } catch (e) {
      print('Error fetching flashcard: $e');
      rethrow;
    }
  }
  
  /// Create a new flashcard
  Future<FlashCard> createFlashcard(FlashCard flashcard) async {
    try {
      final response = await _client
          .from('flashcards')
          .insert(flashcard.toJson())
          .select()
          .single();
      
      final createdFlashcard = FlashCard.fromJson(response);
      
      // Create learning mastery record
      await _createLearningMastery(createdFlashcard.id, flashcard.learningMastery);
      
      return createdFlashcard;
    } catch (e) {
      print('Error creating flashcard: $e');
      rethrow;
    }
  }
  
  /// Update an existing flashcard
  Future<FlashCard> updateFlashcard(FlashCard flashcard) async {
    try {
      final response = await _client
          .from('flashcards')
          .update(flashcard.toJson())
          .eq('id', flashcard.id)
          .select()
          .single();
      
      final updatedFlashcard = FlashCard.fromJson(response);
      
      // Update learning mastery
      await _updateLearningMastery(flashcard.id, flashcard.learningMastery);
      
      return updatedFlashcard;
    } catch (e) {
      print('Error updating flashcard: $e');
      rethrow;
    }
  }
  
  /// Delete a flashcard
  Future<void> deleteFlashcard(String id) async {
    try {
      await _client
          .from('flashcards')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('Error deleting flashcard: $e');
      rethrow;
    }
  }
  
  // MARK: - Deck Operations
  
  /// Get all decks for the current user
  Future<List<Deck>> getDecks() async {
    try {
      final response = await _client
          .from('decks')
          .select('*')
          .order('created_at', ascending: false);
      
      final decks = response.map<Deck>((data) => Deck.fromJson(data)).toList();
      
      // Load cards for each deck
      for (final deck in decks) {
        await _loadDeckCards(deck);
      }
      
      return decks;
    } catch (e) {
      print('Error fetching decks: $e');
      rethrow;
    }
  }
  
  /// Get a specific deck by ID
  Future<Deck?> getDeck(String id) async {
    try {
      final response = await _client
          .from('decks')
          .select('*')
          .eq('id', id)
          .maybeSingle();
      
      if (response == null) return null;
      
      final deck = Deck.fromJson(response);
      await _loadDeckCards(deck);
      
      return deck;
    } catch (e) {
      print('Error fetching deck: $e');
      rethrow;
    }
  }
  
  /// Create a new deck
  Future<Deck> createDeck(Deck deck) async {
    try {
      final response = await _client
          .from('decks')
          .insert(deck.toJson())
          .select()
          .single();
      
      final createdDeck = Deck.fromJson(response);
      
      // Add cards to the deck
      for (final card in deck.cards) {
        await _addCardToDeck(createdDeck.id, card.id);
      }
      
      return createdDeck;
    } catch (e) {
      print('Error creating deck: $e');
      rethrow;
    }
  }
  
  /// Update an existing deck
  Future<Deck> updateDeck(Deck deck) async {
    try {
      final response = await _client
          .from('decks')
          .update(deck.toJson())
          .eq('id', deck.id)
          .select()
          .single();
      
      final updatedDeck = Deck.fromJson(response);
      
      // Update deck cards
      await _updateDeckCards(deck.id, deck.cards);
      
      return updatedDeck;
    } catch (e) {
      print('Error updating deck: $e');
      rethrow;
    }
  }
  
  /// Delete a deck
  Future<void> deleteDeck(String id) async {
    try {
      await _client
          .from('decks')
          .delete()
          .eq('id', id);
    } catch (e) {
      print('Error deleting deck: $e');
      rethrow;
    }
  }
  
  // MARK: - Learning Mastery Operations
  
  /// Update learning mastery for a flashcard
  Future<void> updateLearningMastery(String flashcardId, LearningMastery mastery) async {
    try {
      await _client
          .from('learning_mastery')
          .upsert({
            'flashcard_id': flashcardId,
            'user_id': SupabaseService.instance.currentUser!.id,
            ...mastery.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Error updating learning mastery: $e');
      rethrow;
    }
  }
  
  /// Get flashcards due for review
  Future<List<FlashCard>> getDueFlashcards() async {
    try {
      final now = DateTime.now().toIso8601String();
      
      final response = await _client
          .from('learning_mastery')
          .select('''
            *,
            flashcards(*)
          ''')
          .or('next_review_date.is.null,next_review_date.lte.$now')
          .order('next_review_date', ascending: true);
      
      return response.map<FlashCard>((data) {
        final flashcard = FlashCard.fromJson(data['flashcards']);
        flashcard.learningMastery = LearningMastery.fromJson(data);
        return flashcard;
      }).toList();
    } catch (e) {
      print('Error fetching due flashcards: $e');
      rethrow;
    }
  }
  
  // MARK: - Private Helper Methods
  
  Future<void> _createLearningMastery(String flashcardId, LearningMastery mastery) async {
    try {
      await _client
          .from('learning_mastery')
          .insert({
            'flashcard_id': flashcardId,
            'user_id': SupabaseService.instance.currentUser!.id,
            ...mastery.toJson(),
          });
    } catch (e) {
      print('Error creating learning mastery: $e');
      rethrow;
    }
  }
  
  Future<void> _updateLearningMastery(String flashcardId, LearningMastery mastery) async {
    try {
      await _client
          .from('learning_mastery')
          .update({
            ...mastery.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('flashcard_id', flashcardId)
          .eq('user_id', SupabaseService.instance.currentUser!.id);
    } catch (e) {
      print('Error updating learning mastery: $e');
      rethrow;
    }
  }
  
  Future<void> _loadDeckCards(Deck deck) async {
    try {
      final response = await _client
          .from('deck_cards')
          .select('''
            flashcard_id,
            flashcards(*,
              learning_mastery(*)
            )
          ''')
          .eq('deck_id', deck.id);
      
      final cards = response.map<FlashCard>((data) {
        final flashcard = FlashCard.fromJson(data['flashcards']);
        
        // Attach learning mastery if it exists
        if (data['flashcards']['learning_mastery'] != null && 
            data['flashcards']['learning_mastery'].isNotEmpty) {
          final masteryData = data['flashcards']['learning_mastery'][0];
          flashcard.learningMastery = LearningMastery.fromJson(masteryData);
        }
        
        return flashcard;
      }).toList();
      
      deck.cards = cards;
    } catch (e) {
      print('Error loading deck cards: $e');
      rethrow;
    }
  }
  
  Future<void> _addCardToDeck(String deckId, String flashcardId) async {
    try {
      await _client
          .from('deck_cards')
          .insert({
            'deck_id': deckId,
            'flashcard_id': flashcardId,
          });
    } catch (e) {
      // Check if it's a duplicate key error - if so, it's actually fine
      if (e.toString().contains('duplicate key value violates unique constraint')) {
        print('Card $flashcardId already in deck $deckId, skipping');
        return; // Don't rethrow for duplicate key errors
      } else {
        print('Error adding card to deck: $e');
        rethrow;
      }
    }
  }
  
  Future<void> _updateDeckCards(String deckId, List<FlashCard> cards) async {
    try {
      // Remove all existing cards from deck
      await _client
          .from('deck_cards')
          .delete()
          .eq('deck_id', deckId);
      
      // Add new cards to deck
      if (cards.isNotEmpty) {
        final deckCards = cards.map((card) => {
          'deck_id': deckId,
          'flashcard_id': card.id,
        }).toList();
        
        await _client
            .from('deck_cards')
            .insert(deckCards);
      }
    } catch (e) {
      print('Error updating deck cards: $e');
      rethrow;
    }
  }
}
