import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class DataSyncService {
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();
  
  // Check if user data has been synced to cloud
  static Future<bool> isDataSynced() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('data_synced_to_cloud') ?? false;
  }
  
  // Mark data as synced
  static Future<void> markDataAsSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('data_synced_to_cloud', true);
  }
  
  // Sync user profile data to Supabase
  static Future<void> syncUserProfile() async {
    if (!SupabaseService.instance.isAuthenticated) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = SupabaseService.instance.currentUser!.id;
      
      // Get user profile from JSON (as stored by UserProfileProvider)
      final profileJson = prefs.getString('user_profile');
      Map<String, dynamic> profileData = {};
      
      if (profileJson != null) {
        try {
          profileData = json.decode(profileJson);
        } catch (e) {
          print('❌ Error parsing user profile JSON: $e');
        }
      }
      
      // Get onboarding status
      final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      
      // Upload to Supabase
      await SupabaseService.instance.client
          .from('user_profiles')
          .upsert({
            'id': userId,
            'username': profileData['username'] ?? 'Learner',
            'selected_avatar': profileData['selectedAvatar'] ?? 'person',
            'profile_image_data': profileData['profileImageData'],
            'xp': profileData['xp'] ?? 0,
            'level': profileData['level'] ?? 1,
            'total_sessions': profileData['totalSessions'] ?? 0,
            'current_streak': profileData['currentStreak'] ?? 0,
            'best_streak': profileData['bestStreak'] ?? 0,
            'accuracy': profileData['accuracy'] ?? 0.0,
            'total_cards_studied': profileData['totalCardsStudied'] ?? 0,
            'perfect_sessions': profileData['perfectSessions'] ?? 0,
            'last_study_date': profileData['lastStudyDate'],
            'onboarding_completed': onboardingCompleted,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
      
      print('✅ User profile synced to cloud');
    } catch (e) {
      print('❌ Error syncing user profile: $e');
    }
  }
  
  // Sync flashcard decks to Supabase
  static Future<void> syncDecks() async {
    if (!SupabaseService.instance.isAuthenticated) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = SupabaseService.instance.currentUser!.id;
      
      // Get local decks from SharedPreferences
      final decksJson = prefs.getStringList('decks') ?? [];
      final localDeckIds = <String>{};
      
      // Upsert local decks to cloud
      for (final deckJson in decksJson) {
        try {
          final deckData = json.decode(deckJson);
          localDeckIds.add(deckData['id']);
          
          await SupabaseService.instance.client
              .from('decks')
              .upsert({
                'id': deckData['id'],
                'user_id': userId,
                'name': deckData['name'],
                'parent_id': deckData['parentId'],
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });
        } catch (e) {
          print('❌ Error syncing deck: $e');
        }
      }
      
      // Get all cloud decks for this user
      final cloudDecksResponse = await SupabaseService.instance.client
          .from('decks')
          .select('id')
          .eq('user_id', userId);
      
      // Delete cloud decks that no longer exist locally
      for (final cloudDeck in cloudDecksResponse) {
        final cloudDeckId = cloudDeck['id'] as String;
        if (!localDeckIds.contains(cloudDeckId)) {
          try {
            await SupabaseService.instance.client
                .from('decks')
                .delete()
                .eq('id', cloudDeckId);
            print('🗑️ Deleted cloud deck: $cloudDeckId');
          } catch (e) {
            print('❌ Error deleting cloud deck $cloudDeckId: $e');
          }
        }
      }
      
      print('✅ Decks synced to cloud');
    } catch (e) {
      print('❌ Error syncing decks: $e');
    }
  }
  
  // Sync flashcards to Supabase
  static Future<void> syncFlashcards() async {
    if (!SupabaseService.instance.isAuthenticated) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = SupabaseService.instance.currentUser!.id;
      
      // Get local flashcards from SharedPreferences
      final cardsJson = prefs.getStringList('cards') ?? [];
      final localCardIds = <String>{};
      final localDeckCardRelationships = <Map<String, String>>[];
      
      // Upsert local flashcards to cloud
      for (final cardJson in cardsJson) {
        try {
          final cardData = json.decode(cardJson);
          localCardIds.add(cardData['id']);
          
          // Insert/update flashcard
          await SupabaseService.instance.client
              .from('flashcards')
              .upsert({
                'id': cardData['id'],
                'user_id': userId,
                'word': cardData['word'],
                'definition': cardData['definition'],
                'example': cardData['example'],
                'example_translation': cardData['exampleTranslation'],
                'article': cardData['article'],
                'plural': cardData['plural'],
                'past_tense': cardData['pastTense'],
                'future_tense': cardData['futureTense'],
                'past_participle': cardData['pastParticiple'],
                'success_count': cardData['timesCorrect'] ?? 0,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });
          
          // Track deck relationships
          final deckIds = cardData['deckIds'] as List<dynamic>? ?? [];
          for (final deckId in deckIds) {
            localDeckCardRelationships.add({
              'deck_id': deckId,
              'flashcard_id': cardData['id'],
            });
          }
        } catch (e) {
          print('❌ Error syncing flashcard: $e');
        }
      }
      
      // Get all cloud flashcards for this user
      final cloudCardsResponse = await SupabaseService.instance.client
          .from('flashcards')
          .select('id')
          .eq('user_id', userId);
      
      // Delete cloud flashcards that no longer exist locally
      for (final cloudCard in cloudCardsResponse) {
        final cloudCardId = cloudCard['id'] as String;
        if (!localCardIds.contains(cloudCardId)) {
          try {
            await SupabaseService.instance.client
                .from('flashcards')
                .delete()
                .eq('id', cloudCardId);
            print('🗑️ Deleted cloud flashcard: $cloudCardId');
          } catch (e) {
            print('❌ Error deleting cloud flashcard $cloudCardId: $e');
          }
        }
      }
      
      // Sync deck-card relationships
      // First, delete all existing relationships for this user's cards
      if (localCardIds.isNotEmpty) {
        await SupabaseService.instance.client
            .from('deck_cards')
            .delete()
            .inFilter('flashcard_id', localCardIds.toList());
      }
      
      // Then insert current relationships
      for (final relationship in localDeckCardRelationships) {
        try {
          await SupabaseService.instance.client
              .from('deck_cards')
              .insert({
                'deck_id': relationship['deck_id'],
                'flashcard_id': relationship['flashcard_id'],
                'created_at': DateTime.now().toIso8601String(),
              });
        } catch (e) {
          print('❌ Error syncing deck-card relationship: $e');
        }
      }
      
      print('✅ Flashcards synced to cloud');
    } catch (e) {
      print('❌ Error syncing flashcards: $e');
    }
  }
  
  // Sync learning progress to Supabase
  static Future<void> syncLearningProgress() async {
    if (!SupabaseService.instance.isAuthenticated) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = SupabaseService.instance.currentUser!.id;
      
      // Get learning progress data
      final keys = prefs.getKeys();
      final progressKeys = keys.where((key) => key.startsWith('progress_')).toList();
      
      for (final progressKey in progressKeys) {
        final progressData = prefs.getString(progressKey);
        if (progressData != null) {
          await SupabaseService.instance.client
              .from('learning_mastery')
              .upsert({
                'id': '${userId}_$progressKey',
                'user_id': userId,
                'card_id': progressKey.replaceFirst('progress_', ''),
                'mastery_level': int.tryParse(progressData) ?? 0,
                'last_reviewed': DateTime.now().toIso8601String(),
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              });
        }
      }
      
      print('✅ Learning progress synced to cloud');
    } catch (e) {
      print('❌ Error syncing learning progress: $e');
    }
  }
  
  // Full data sync - call this after user signs in
  static Future<void> syncAllData() async {
    if (!SupabaseService.instance.isAuthenticated) {
      print('❌ User not authenticated, cannot sync data');
      return;
    }
    
    print('🔄 Starting data sync to cloud...');
    
    try {
      await syncUserProfile();
      await syncDecks();
      await syncFlashcards();
      await syncLearningProgress();
      
      await markDataAsSynced();
      print('✅ All data synced to cloud successfully!');
    } catch (e) {
      print('❌ Error during data sync: $e');
    }
  }
  
  // Download data from cloud to local storage
  static List<Map<String, dynamic>> _cleanupDuplicateDefaultDecks(List<Map<String, dynamic>> decks) {
    final result = <Map<String, dynamic>>[];
    final defaultDeckNames = {'Uncategorized', 'Review'};
    
    // Keep track of which default decks we've seen
    final seenDefaultDecks = <String>{};
    
    for (final deck in decks) {
      final deckName = deck['name'] as String;
      
      if (defaultDeckNames.contains(deckName)) {
        if (!seenDefaultDecks.contains(deckName)) {
          // First time seeing this default deck, keep it
          seenDefaultDecks.add(deckName);
          result.add(deck);
          print('🔍 DataSyncService: Keeping default deck: $deckName');
        } else {
          // Duplicate default deck, skip it
          print('🔍 DataSyncService: Removing duplicate default deck: $deckName');
        }
      } else {
        // Custom deck, always keep it
        result.add(deck);
      }
    }
    
    return result;
  }
  
  static Future<void> downloadDataFromCloud() async {
    if (!SupabaseService.instance.isAuthenticated) return;
    
    try {
      final userId = SupabaseService.instance.currentUser!.id;
      final prefs = await SharedPreferences.getInstance();
      
      // Download user profile
      final profileResponse = await SupabaseService.instance.client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (profileResponse != null) {
        // Create user profile JSON as expected by UserProfileProvider
        final profileData = {
          'username': profileResponse['username'] ?? 'Learner',
          'selectedAvatar': profileResponse['selected_avatar'] ?? 'person',
          'profileImageData': profileResponse['profile_image_data'],
          'xp': profileResponse['xp'] ?? 0,
          'level': profileResponse['level'] ?? 1,
          'totalSessions': profileResponse['total_sessions'] ?? 0,
          'currentStreak': profileResponse['current_streak'] ?? 0,
          'bestStreak': profileResponse['best_streak'] ?? 0,
          'accuracy': profileResponse['accuracy'] ?? 0.0,
          'totalCardsStudied': profileResponse['total_cards_studied'] ?? 0,
          'perfectSessions': profileResponse['perfect_sessions'] ?? 0,
          'lastStudyDate': profileResponse['last_study_date'],
          'achievements': [], // Default empty achievements
          'levelRewards': [], // Default empty level rewards
        };
        
        await prefs.setString('user_profile', json.encode(profileData));
        await prefs.setBool('onboarding_completed', profileResponse['onboarding_completed'] ?? false);
      }
      
      // Download decks and merge with local ones to avoid duplicates
      final decksResponse = await SupabaseService.instance.client
          .from('decks')
          .select()
          .eq('user_id', userId);
      
      // Get existing local decks
      final existingDecksJson = prefs.getStringList('decks') ?? [];
      final existingDecks = <String, Map<String, dynamic>>{};
      
      for (final deckJson in existingDecksJson) {
        try {
          final deckData = json.decode(deckJson);
          existingDecks[deckData['id']] = deckData; // Use ID as key instead of name
        } catch (e) {
          print('❌ Error parsing existing deck: $e');
        }
      }
      
      // Merge cloud decks with local ones, avoiding duplicates by ID
      final mergedDecks = <String, Map<String, dynamic>>{};
      
      // Add existing local decks first
      for (final entry in existingDecks.entries) {
        mergedDecks[entry.key] = entry.value;
      }
      
      // Add cloud decks, but only if they don't already exist locally by ID
      for (final deck in decksResponse) {
        final deckId = deck['id'] as String;
        final deckName = deck['name'] as String;
        
        // Check if we already have a deck with this ID
        if (!mergedDecks.containsKey(deckId)) {
          // For default decks, check if we already have one with the same name
          if (deckName == 'Uncategorized' || deckName == 'Review') {
            final existingDefaultDeck = mergedDecks.values
                .where((d) => d['name'] == deckName)
                .firstOrNull;
            
            if (existingDefaultDeck != null) {
              print('🔍 DataSyncService: Skipping duplicate default deck: $deckName');
              continue; // Skip this cloud deck, keep the local one
            }
          }
          
          mergedDecks[deckId] = {
            'id': deck['id'],
            'name': deck['name'],
            'parentId': deck['parent_id'],
          };
        }
      }
      
      // Convert back to JSON list
      final decksJson = mergedDecks.values.map((deck) => json.encode(deck)).toList();
      
      // Clean up any duplicate default decks that might have been created
      final cleanedDecks = _cleanupDuplicateDefaultDecks(mergedDecks.values.toList());
      final cleanedDecksJson = cleanedDecks.map((deck) => json.encode(deck)).toList();
      
      print('🔍 DataSyncService: Saving ${cleanedDecksJson.length} decks to SharedPreferences');
      for (final deckJson in cleanedDecksJson) {
        final deckData = json.decode(deckJson);
        print('🔍 DataSyncService: Deck: ${deckData['name']} (${deckData['id']})');
      }
      
      await prefs.setStringList('decks', cleanedDecksJson);
      
      // Download flashcards and merge with local ones
      final cardsResponse = await SupabaseService.instance.client
          .from('flashcards')
          .select('''
            *,
            deck_cards!inner(deck_id)
          ''')
          .eq('user_id', userId);
      
      // Get existing local cards
      final existingCardsJson = prefs.getStringList('cards') ?? [];
      final existingCards = <String, Map<String, dynamic>>{};
      
      for (final cardJson in existingCardsJson) {
        try {
          final cardData = json.decode(cardJson);
          existingCards[cardData['word']] = cardData; // Use word as unique key
        } catch (e) {
          print('❌ Error parsing existing card: $e');
        }
      }
      
      // Create a mapping of cloud deck IDs to local deck IDs
      final deckIdMapping = <String, String>{};
      for (final entry in mergedDecks.entries) {
        final deckId = entry.key;
        final localDeck = entry.value;
        // Map cloud deck ID to local deck ID (they should be the same)
        deckIdMapping[deckId] = localDeck['id'];
      }
      
      print('🔍 DataSyncService: Deck ID mapping: $deckIdMapping');
      
      // Merge cloud cards with local ones
      final mergedCards = <String, Map<String, dynamic>>{};
      
      // Add existing local cards first
      for (final entry in existingCards.entries) {
        mergedCards[entry.key] = entry.value;
      }
      
      // Add cloud cards, but only if they don't already exist locally
      for (final card in cardsResponse) {
        final cardWord = card['word'] as String;
        if (!mergedCards.containsKey(cardWord)) {
          // Get deck IDs from the relationship and map them to local deck IDs
          final cloudDeckIds = (card['deck_cards'] as List<dynamic>?)
              ?.map((dc) => dc['deck_id'] as String)
              .toList() ?? [];
          
          print('🔍 DataSyncService: Card "$cardWord" has cloud deck IDs: $cloudDeckIds');
          
          final localDeckIds = cloudDeckIds
              .map((cloudId) => deckIdMapping[cloudId])
              .where((id) => id != null)
              .cast<String>()
              .toList();
          
          print('🔍 DataSyncService: Card "$cardWord" mapped to local deck IDs: $localDeckIds');
          
          mergedCards[cardWord] = {
            'id': card['id'],
            'word': card['word'],
            'definition': card['definition'],
            'example': card['example'],
            'exampleTranslation': card['example_translation'],
            'article': card['article'],
            'plural': card['plural'],
            'pastTense': card['past_tense'],
            'futureTense': card['future_tense'],
            'pastParticiple': card['past_participle'],
            'deckIds': localDeckIds,
            'timesShown': 0, // Default value since not stored in DB
            'timesCorrect': card['success_count'] ?? 0,
          };
        } else {
          print('🔍 DataSyncService: Card "$cardWord" already exists locally, skipping');
        }
      }
      
      // Convert back to JSON list
      final cardsJson = mergedCards.values.map((card) => json.encode(card)).toList();
      
      print('🔍 DataSyncService: Saving ${cardsJson.length} cards to SharedPreferences');
      for (final cardJson in cardsJson) {
        final cardData = json.decode(cardJson);
        print('🔍 DataSyncService: Card: ${cardData['word']} in decks: ${cardData['deckIds']}');
      }
      
      await prefs.setStringList('cards', cardsJson);
      
      // Download learning progress
      final progressResponse = await SupabaseService.instance.client
          .from('learning_mastery')
          .select()
          .eq('user_id', userId);
      
      for (final progress in progressResponse) {
        await prefs.setString('progress_${progress['card_id']}', progress['mastery_level'].toString());
      }
      
      print('✅ Data downloaded from cloud successfully!');
    } catch (e) {
      print('❌ Error downloading data from cloud: $e');
    }
  }
}
