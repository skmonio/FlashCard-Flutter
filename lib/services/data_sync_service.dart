import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class SyncResult {
  final bool isSuccess;
  final bool isSkipped;
  final String message;
  final List<String> details;

  const SyncResult.success([
    this.message = 'Sync complete',
    this.details = const [],
  ]) : isSuccess = true,
       isSkipped = false;

  const SyncResult.skipped([
    this.message = 'Sync skipped',
    this.details = const [],
  ]) : isSuccess = false,
       isSkipped = true;

  const SyncResult.failure(this.message, {this.details = const []})
    : isSuccess = false,
      isSkipped = false;

  bool get isFailure => !isSuccess && !isSkipped;
}

class DataSyncService {
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();

  static DateTime? _lastSyncTime;
  static const Duration _syncThrottleDuration = Duration(minutes: 5);

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
  static Future<SyncResult> syncUserProfile() async {
    if (!SupabaseService.instance.isAuthenticated) {
      return const SyncResult.skipped('Sign in to sync your profile.');
    }

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
          return SyncResult.failure(
            'Profile sync failed because saved profile data could not be read.',
            details: [e.toString()],
          );
        }
      }

      // Get onboarding status
      final onboardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;

      // Upload to Supabase
      await SupabaseService.instance.client.from('user_profiles').upsert({
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
      return const SyncResult.success('Profile synced to cloud.');
    } catch (e) {
      print('❌ Error syncing user profile: $e');
      return SyncResult.failure(
        'Profile sync failed.',
        details: [e.toString()],
      );
    }
  }

  // Sync flashcard decks to Supabase
  static Future<SyncResult> syncDecks() async {
    if (!SupabaseService.instance.isAuthenticated) {
      print('❌ DataSyncService: User not authenticated, skipping deck sync');
      return const SyncResult.skipped('Sign in to sync decks.');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = SupabaseService.instance.currentUser!.id;
      print('🔍 DataSyncService: Starting deck sync for user: $userId');

      // Get local decks from SharedPreferences
      final decksJson = prefs.getStringList('decks') ?? [];
      if (decksJson.isEmpty) {
        print('🔍 DataSyncService: No decks to sync');
        return const SyncResult.success('No decks to sync.');
      }

      final syncErrors = <String>[];
      final localDeckIds = <String>{};
      final decksToUpsert = <Map<String, dynamic>>[];

      // Prepare batch data
      for (final deckJson in decksJson) {
        try {
          final deckData = json.decode(deckJson);
          localDeckIds.add(deckData['id']);

          // Prepare deck data for batch upsert
          decksToUpsert.add({
            'id': deckData['id'],
            'user_id': userId,
            'name': deckData['name'],
            'parent_id': deckData['parentId'],
            'is_public': deckData['isPublic'] ?? false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          print('❌ Error preparing deck for sync: $e');
          syncErrors.add('A deck could not be prepared: $e');
        }
      }

      // Batch upsert all decks at once
      if (decksToUpsert.isNotEmpty) {
        print(
          '🔍 DataSyncService: Batch upserting ${decksToUpsert.length} decks',
        );
        print('🔍 DataSyncService: Current user ID: $userId');
        print('🔍 DataSyncService: Sample deck data: ${decksToUpsert.first}');
        try {
          // Test authentication first
          final authUser = SupabaseService.instance.client.auth.currentUser;
          print('🔍 DataSyncService: Auth user: ${authUser?.id}');
          print('🔍 DataSyncService: Auth session: ${authUser?.aud}');

          await SupabaseService.instance.client
              .from('decks')
              .upsert(decksToUpsert);
          print('✅ Decks batch upserted successfully');
        } catch (e) {
          print('❌ Error syncing decks: $e');
          print('❌ Error details: ${e.toString()}');
          return SyncResult.failure(
            'Deck sync failed.',
            details: [e.toString()],
          );
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
            syncErrors.add('Cloud deck $cloudDeckId could not be deleted: $e');
          }
        }
      }

      print('✅ Decks synced to cloud');
      if (syncErrors.isNotEmpty) {
        return SyncResult.failure(
          'Deck sync completed with ${syncErrors.length} issue${syncErrors.length == 1 ? '' : 's'}.',
          details: syncErrors,
        );
      }
      return const SyncResult.success('Decks synced to cloud.');
    } catch (e) {
      print('❌ Error syncing decks: $e');
      return SyncResult.failure('Deck sync failed.', details: [e.toString()]);
    }
  }

  // Sync flashcards to Supabase
  static Future<SyncResult> syncFlashcards() async {
    if (!SupabaseService.instance.isAuthenticated) {
      print(
        '❌ DataSyncService: User not authenticated, skipping flashcard sync',
      );
      return const SyncResult.skipped('Sign in to sync cards.');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = SupabaseService.instance.currentUser!.id;
      print('🔍 DataSyncService: Starting flashcard sync for user: $userId');

      // Get local flashcards from SharedPreferences
      final cardsJson = prefs.getStringList('cards') ?? [];
      if (cardsJson.isEmpty) {
        print('🔍 DataSyncService: No cards to sync');
        return const SyncResult.success('No cards to sync.');
      }

      final syncErrors = <String>[];
      final localCardIds = <String>{};
      final localDeckCardRelationships = <Map<String, String>>[];
      final cardsToUpsert = <Map<String, dynamic>>[];

      // Prepare batch data
      for (final cardJson in cardsJson) {
        try {
          final cardData = json.decode(cardJson);
          localCardIds.add(cardData['id']);

          // Prepare flashcard data for batch upsert
          cardsToUpsert.add({
            'id': cardData['id'],
            'user_id': userId,
            'word': cardData['word'],
            'definition': cardData['definition'],
            'example': cardData['example'],
            'example_translation': cardData['exampleTranslation'],
            'article': cardData['article'],
            'plural': cardData['plural'],
            'present_tense': cardData['presentTense'],
            'past_tense': cardData['pastTense'],
            'perfect_tense': cardData['perfectTense'],
            'success_count': cardData['timesCorrect'] ?? 0,
            'is_public': cardData['isPublic'] ?? false,
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
          print('❌ Error preparing flashcard for sync: $e');
          syncErrors.add('A card could not be prepared: $e');
        }
      }

      // Batch upsert all flashcards at once
      if (cardsToUpsert.isNotEmpty) {
        print(
          '🔍 DataSyncService: Batch upserting ${cardsToUpsert.length} flashcards',
        );
        print('🔍 DataSyncService: Current user ID: $userId');
        print('🔍 DataSyncService: Sample card data: ${cardsToUpsert.first}');
        try {
          // Test authentication first
          final authUser = SupabaseService.instance.client.auth.currentUser;
          print('🔍 DataSyncService: Auth user: ${authUser?.id}');
          print('🔍 DataSyncService: Auth session: ${authUser?.aud}');

          await SupabaseService.instance.client
              .from('flashcards')
              .upsert(cardsToUpsert);
          print('✅ Flashcards batch upserted successfully');
        } catch (e) {
          print('❌ Error syncing flashcards: $e');
          print('❌ Error details: ${e.toString()}');
          return SyncResult.failure(
            'Card sync failed.',
            details: [e.toString()],
          );
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
            syncErrors.add('Cloud card $cloudCardId could not be deleted: $e');
          }
        }
      }

      // Sync deck-card relationships using upsert to avoid duplicate key violations
      if (localDeckCardRelationships.isNotEmpty) {
        try {
          // Use upsert to insert or update relationships, avoiding duplicates
          await SupabaseService.instance.client
              .from('deck_cards')
              .upsert(
                localDeckCardRelationships
                    .map(
                      (relationship) => {
                        'deck_id': relationship['deck_id'],
                        'flashcard_id': relationship['flashcard_id'],
                        'created_at':
                            relationship['created_at'] ??
                            DateTime.now().toIso8601String(),
                      },
                    )
                    .toList(),
                onConflict:
                    'deck_id,flashcard_id', // Use composite primary key for conflict resolution
              );
          print('✅ Deck-card relationships synced successfully');
        } catch (e) {
          print('❌ Error syncing deck-card relationships: $e');

          // Fallback: try individual inserts with duplicate handling
          print('🔍 Attempting fallback: individual relationship sync...');
          int successCount = 0;
          int errorCount = 0;

          for (final relationship in localDeckCardRelationships) {
            try {
              await SupabaseService.instance.client.from('deck_cards').insert({
                'deck_id': relationship['deck_id'],
                'flashcard_id': relationship['flashcard_id'],
                'created_at':
                    relationship['created_at'] ??
                    DateTime.now().toIso8601String(),
              });
              successCount++;
            } catch (e) {
              errorCount++;
              // Check if it's a duplicate key error - if so, it's actually fine
              if (e.toString().contains(
                'duplicate key value violates unique constraint',
              )) {
                print(
                  '🔍 Relationship already exists, skipping: ${relationship['deck_id']} -> ${relationship['flashcard_id']}',
                );
                successCount++; // Count as success since the relationship exists
                errorCount--; // Don't count as error
              } else {
                print('❌ Error syncing individual deck-card relationship: $e');
              }
            }
          }

          print(
            '🔍 Fallback sync complete: $successCount successful, $errorCount errors',
          );
          if (errorCount > 0) {
            syncErrors.add(
              '$errorCount deck-card relationship${errorCount == 1 ? '' : 's'} could not be synced.',
            );
          }
        }
      }

      print('✅ Flashcards synced to cloud');
      if (syncErrors.isNotEmpty) {
        return SyncResult.failure(
          'Card sync completed with ${syncErrors.length} issue${syncErrors.length == 1 ? '' : 's'}.',
          details: syncErrors,
        );
      }
      return const SyncResult.success('Cards synced to cloud.');
    } catch (e) {
      print('❌ Error syncing flashcards: $e');
      return SyncResult.failure('Card sync failed.', details: [e.toString()]);
    }
  }

  // Sync learning progress to Supabase
  static Future<SyncResult> syncLearningProgress() async {
    if (!SupabaseService.instance.isAuthenticated) {
      return const SyncResult.skipped('Sign in to sync learning progress.');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = SupabaseService.instance.currentUser!.id;

      // Get learning progress data
      final keys = prefs.getKeys();
      final progressKeys = keys
          .where((key) => key.startsWith('progress_'))
          .toList();

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
      return const SyncResult.success('Learning progress synced to cloud.');
    } catch (e) {
      print('❌ Error syncing learning progress: $e');
      return SyncResult.failure(
        'Learning progress sync failed.',
        details: [e.toString()],
      );
    }
  }

  // Full data sync - call this after user signs in
  static Future<SyncResult> syncAllData() async {
    if (!SupabaseService.instance.isAuthenticated) {
      print('❌ User not authenticated, cannot sync data');
      return const SyncResult.skipped('Sign in to sync your data.');
    }

    print('🔄 Starting data sync to cloud...');

    try {
      final results = [
        await syncUserProfile(),
        await syncDecks(),
        await syncFlashcards(),
        await syncLearningProgress(),
      ];
      final failedResults = results
          .where((result) => result.isFailure)
          .toList();
      if (failedResults.isNotEmpty) {
        final details = failedResults
            .expand((result) => [result.message, ...result.details])
            .toList();
        return SyncResult.failure(
          'Sync failed. ${failedResults.first.message}',
          details: details,
        );
      }

      await markDataAsSynced();
      _lastSyncTime = DateTime.now();
      print('✅ All data synced to cloud successfully!');
      return const SyncResult.success('All data synced to cloud.');
    } catch (e) {
      print('❌ Error during data sync: $e');
      return SyncResult.failure('Data sync failed.', details: [e.toString()]);
    }
  }

  // Throttled sync - only sync if enough time has passed since last sync
  static Future<SyncResult> syncAllDataThrottled() async {
    if (!SupabaseService.instance.isAuthenticated) {
      print('❌ User not authenticated, cannot sync data');
      return const SyncResult.skipped('Sign in to sync your data.');
    }

    // Check if we should throttle this sync
    if (_lastSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceLastSync < _syncThrottleDuration) {
        print(
          '🔍 DataSyncService: Sync throttled (${timeSinceLastSync.inMinutes}min since last sync)',
        );
        return const SyncResult.skipped(
          'Sync skipped because it ran recently.',
        );
      }
    }

    print('🔄 Starting throttled data sync to cloud...');
    return syncAllData();
  }

  // Download data from cloud to local storage
  static List<Map<String, dynamic>> _cleanupDuplicateDefaultDecks(
    List<Map<String, dynamic>> decks,
  ) {
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
          print(
            '🔍 DataSyncService: Removing duplicate default deck: $deckName',
          );
        }
      } else {
        // Custom deck, always keep it
        result.add(deck);
      }
    }

    return result;
  }

  static Future<SyncResult> downloadDataFromCloud() async {
    if (!SupabaseService.instance.isAuthenticated) {
      return const SyncResult.skipped('Sign in to download cloud data.');
    }

    try {
      final userId = SupabaseService.instance.currentUser!.id;
      final prefs = await SharedPreferences.getInstance();
      final syncErrors = <String>[];

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
        await prefs.setBool(
          'onboarding_completed',
          profileResponse['onboarding_completed'] ?? false,
        );
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
          existingDecks[deckData['id']] =
              deckData; // Use ID as key instead of name
        } catch (e) {
          print('❌ Error parsing existing deck: $e');
          syncErrors.add('A saved deck could not be read: $e');
        }
      }

      // Merge cloud decks with local ones, respecting local deletions
      final mergedDecks = <String, Map<String, dynamic>>{};

      // Add existing local decks first (these represent the current state)
      for (final entry in existingDecks.entries) {
        mergedDecks[entry.key] = entry.value;
      }

      // Only add cloud decks that don't exist locally AND are not in the deleted list
      // This prevents re-adding decks that were intentionally deleted locally
      for (final deck in decksResponse) {
        final deckId = deck['id'] as String;
        final deckName = deck['name'] as String;

        // Check if we already have a deck with this ID locally
        if (!mergedDecks.containsKey(deckId)) {
          // For default decks, check if we already have one with the same name
          if (deckName == 'Uncategorized' || deckName == 'Review') {
            final existingDefaultDeck = mergedDecks.values
                .where((d) => d['name'] == deckName)
                .firstOrNull;

            if (existingDefaultDeck != null) {
              print(
                '🔍 DataSyncService: Skipping duplicate default deck: $deckName',
              );
              continue; // Skip this cloud deck, keep the local one
            }
          }

          // Only add the cloud deck if it's not in our local deleted list
          // This prevents re-adding decks that were deleted locally
          print(
            '🔍 DataSyncService: Adding cloud deck that doesn\'t exist locally: $deckName ($deckId)',
          );
          mergedDecks[deckId] = {
            'id': deck['id'],
            'name': deck['name'],
            'parentId': deck['parent_id'],
          };
        } else {
          print(
            '🔍 DataSyncService: Deck already exists locally: $deckName ($deckId)',
          );
        }
      }

      // Convert back to JSON list
      final decksJson = mergedDecks.values
          .map((deck) => json.encode(deck))
          .toList();

      // Clean up any duplicate default decks that might have been created
      final cleanedDecks = _cleanupDuplicateDefaultDecks(
        mergedDecks.values.toList(),
      );
      final cleanedDecksJson = cleanedDecks
          .map((deck) => json.encode(deck))
          .toList();

      print(
        '🔍 DataSyncService: Saving ${cleanedDecksJson.length} decks to SharedPreferences',
      );
      for (final deckJson in cleanedDecksJson) {
        final deckData = json.decode(deckJson);
        print(
          '🔍 DataSyncService: Deck: ${deckData['name']} (${deckData['id']})',
        );
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
          syncErrors.add('A saved card could not be read: $e');
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
          final cloudDeckIds =
              (card['deck_cards'] as List<dynamic>?)
                  ?.map((dc) => dc['deck_id'] as String)
                  .toList() ??
              [];

          print(
            '🔍 DataSyncService: Card "$cardWord" has cloud deck IDs: $cloudDeckIds',
          );

          final localDeckIds = cloudDeckIds
              .map((cloudId) => deckIdMapping[cloudId])
              .where((id) => id != null)
              .cast<String>()
              .toList();

          print(
            '🔍 DataSyncService: Card "$cardWord" mapped to local deck IDs: $localDeckIds',
          );

          mergedCards[cardWord] = {
            'id': card['id'],
            'word': card['word'],
            'definition': card['definition'],
            'example': card['example'],
            'exampleTranslation': card['example_translation'],
            'article': card['article'],
            'plural': card['plural'],
            'presentTense': card['present_tense'],
            'pastTense': card['past_tense'],
            'perfectTense': card['perfect_tense'],
            'deckIds': localDeckIds,
            'timesShown': 0, // Default value since not stored in DB
            'timesCorrect': card['success_count'] ?? 0,
          };
        } else {
          print(
            '🔍 DataSyncService: Card "$cardWord" already exists locally, skipping',
          );
        }
      }

      // Convert back to JSON list
      final cardsJson = mergedCards.values
          .map((card) => json.encode(card))
          .toList();

      print(
        '🔍 DataSyncService: Saving ${cardsJson.length} cards to SharedPreferences',
      );
      for (final cardJson in cardsJson) {
        final cardData = json.decode(cardJson);
        print(
          '🔍 DataSyncService: Card: ${cardData['word']} in decks: ${cardData['deckIds']}',
        );
      }

      await prefs.setStringList('cards', cardsJson);

      // Download learning progress
      final progressResponse = await SupabaseService.instance.client
          .from('learning_mastery')
          .select()
          .eq('user_id', userId);

      for (final progress in progressResponse) {
        await prefs.setString(
          'progress_${progress['card_id']}',
          progress['mastery_level'].toString(),
        );
      }

      print('✅ Data downloaded from cloud successfully!');
      if (syncErrors.isNotEmpty) {
        return SyncResult.failure(
          'Cloud download completed with ${syncErrors.length} issue${syncErrors.length == 1 ? '' : 's'}.',
          details: syncErrors,
        );
      }
      return const SyncResult.success('Data downloaded from cloud.');
    } catch (e) {
      print('❌ Error downloading data from cloud: $e');
      return SyncResult.failure(
        'Cloud download failed.',
        details: [e.toString()],
      );
    }
  }
}
