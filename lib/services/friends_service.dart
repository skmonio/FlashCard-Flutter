import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'data_sync_service.dart';
import 'dart:async';

class Friend {
  final String id;
  final String userId;
  final String friendId;
  final String username;
  final String selectedAvatar;
  final String? profileImageData; // Base64 encoded profile image
  final int level;
  final int xp;
  final int currentStreak;
  final DateTime? lastActivity;
  final String status;

  Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.username,
    required this.selectedAvatar,
    this.profileImageData,
    required this.level,
    required this.xp,
    required this.currentStreak,
    this.lastActivity,
    required this.status,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['friend_id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? '',
      friendId: json['friend_id'] ?? '',
      username: json['username'] ?? '',
      selectedAvatar: json['selected_avatar'] ?? 'person',
      profileImageData: json['profile_image_data'],
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      lastActivity: json['last_activity'] != null
          ? DateTime.parse(json['last_activity'])
          : null,
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'username': username,
      'selected_avatar': selectedAvatar,
      'profile_image_data': profileImageData,
      'level': level,
      'xp': xp,
      'current_streak': currentStreak,
      'last_activity': lastActivity?.toIso8601String(),
      'status': status,
    };
  }
}

class FriendRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderUsername;
  final String senderAvatar;
  final String? message;
  final String status;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderUsername,
    required this.senderAvatar,
    this.message,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      senderUsername: json['sender_username'] ?? json['username'] ?? '',
      senderAvatar:
          json['sender_avatar'] ?? json['selected_avatar'] ?? 'person',
      message: json['message'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class FriendsService {
  static const Duration _defaultTimeout = Duration(seconds: 15);
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();

  SupabaseClient get _client => SupabaseService.instance.client;

  Future<T> _runWithTimeout<T>(Future<T> future) =>
      future.timeout(_defaultTimeout);

  // MARK: - Friend Management

  /// Search for users by username
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final response = await _runWithTimeout(
        _client
            .from('user_profiles')
            .select('id, username, selected_avatar, level, xp, current_streak')
            .ilike('username', '%$query%')
            .neq('id', currentUser.id)
            .limit(20),
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error searching users: $e');
      rethrow;
    }
  }

  /// Send a friend request
  Future<void> sendFriendRequest(String receiverId, {String? message}) async {
    try {
      await _client.from('friend_requests').insert({
        'sender_id': SupabaseService.instance.currentUser!.id,
        'receiver_id': receiverId,
        'message': message,
        'status': 'pending',
      });

      // Create notification for the receiver
      await _createNotification(
        receiverId,
        'friend_request',
        'New Friend Request',
        'You have received a new friend request',
        {'sender_id': SupabaseService.instance.currentUser!.id},
      );
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  /// Cancel a sent friend request
  Future<void> cancelFriendRequest(String receiverId) async {
    try {
      await _client
          .from('friend_requests')
          .delete()
          .eq('sender_id', SupabaseService.instance.currentUser!.id)
          .eq('receiver_id', receiverId)
          .eq('status', 'pending');
    } catch (e) {
      print('Error cancelling friend request: $e');
      rethrow;
    }
  }

  /// Get pending friend requests
  Future<List<FriendRequest>> getPendingFriendRequests() async {
    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final response = await _runWithTimeout(
        _client
            .from('friend_requests')
            .select('''
              *,
              sender:user_profiles!friend_requests_sender_id_fkey(
                username,
                selected_avatar
              )
            ''')
            .eq('receiver_id', currentUser.id)
            .eq('status', 'pending')
            .order('created_at', ascending: false),
      );

      return response.map<FriendRequest>((data) {
        final sender = data['sender'] as Map<String, dynamic>?;
        return FriendRequest(
          id: data['id'],
          senderId: data['sender_id'],
          receiverId: data['receiver_id'],
          senderUsername: sender?['username'] ?? '',
          senderAvatar: sender?['selected_avatar'] ?? 'person',
          message: data['message'],
          status: data['status'],
          createdAt: DateTime.parse(data['created_at']),
        );
      }).toList();
    } catch (e) {
      print('Error getting friend requests: $e');
      rethrow;
    }
  }

  /// Accept a friend request
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      // Get the friend request details
      final requestResponse = await _client
          .from('friend_requests')
          .select('sender_id, receiver_id')
          .eq('id', requestId)
          .single();

      final senderId = requestResponse['sender_id'] as String;
      final receiverId = requestResponse['receiver_id'] as String;

      // Update the friend request status
      await _client
          .from('friend_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);

      // Create friendship relationship (both directions)
      // Insert them one by one to avoid RLS issues
      await _client.from('friends').insert({
        'user_id': senderId,
        'friend_id': receiverId,
        'status': 'accepted',
      });

      await _client.from('friends').insert({
        'user_id': receiverId,
        'friend_id': senderId,
        'status': 'accepted',
      });

      // Create notification for the sender
      await _createNotification(
        senderId,
        'friend_accepted',
        'Friend Request Accepted',
        'Your friend request has been accepted!',
        {'friend_id': receiverId},
      );
    } catch (e) {
      print('Error accepting friend request: $e');
      rethrow;
    }
  }

  /// Decline a friend request
  Future<void> declineFriendRequest(String requestId) async {
    try {
      await _client
          .from('friend_requests')
          .update({'status': 'declined'})
          .eq('id', requestId);
    } catch (e) {
      print('Error declining friend request: $e');
      rethrow;
    }
  }

  /// Get user's friends
  Future<List<Friend>> getFriends() async {
    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final userId = currentUser.id;

      // Get friends relationships
      final friendsResponse = await _runWithTimeout(
        _client
            .from('friends')
            .select('friend_id')
            .eq('user_id', userId)
            .eq('status', 'accepted'),
      );

      if (friendsResponse.isEmpty) {
        return [];
      }

      final friendIds = friendsResponse
          .map((f) => f['friend_id'] as String)
          .toList();

      // Get friends' profiles
      final profilesResponse = await _runWithTimeout(
        _client
            .from('user_profiles')
            .select(
              'id, username, selected_avatar, profile_image_data, level, xp, current_streak, updated_at',
            )
            .inFilter('id', friendIds),
      );

      return profilesResponse.map<Friend>((data) {
        return Friend(
          id: data['id'] ?? '',
          userId: userId,
          friendId: data['id'] ?? '',
          username: data['username'] ?? '',
          selectedAvatar: data['selected_avatar'] ?? 'person',
          profileImageData: data['profile_image_data'],
          level: data['level'] ?? 1,
          xp: data['xp'] ?? 0,
          currentStreak: data['current_streak'] ?? 0,
          lastActivity: data['updated_at'] != null
              ? DateTime.parse(data['updated_at'])
              : null,
          status: 'accepted',
        );
      }).toList();
    } catch (e) {
      print('Error getting friends: $e');
      rethrow;
    }
  }

  /// Remove a friend
  Future<void> removeFriend(String friendId) async {
    try {
      final userId = SupabaseService.instance.currentUser!.id;

      // Remove friendship from both directions
      await _client
          .from('friends')
          .delete()
          .or(
            'and(user_id.eq.$userId,friend_id.eq.$friendId),and(user_id.eq.$friendId,friend_id.eq.$userId)',
          );
    } catch (e) {
      print('Error removing friend: $e');
      rethrow;
    }
  }

  /// Get friend's decks
  Future<List<Map<String, dynamic>>> getFriendDecks(String friendId) async {
    try {
      print('🔍 FriendsService: Getting decks for friend: $friendId');

      // Try to get public decks first
      try {
        final response = await _client
            .from('decks')
            .select('*')
            .eq('user_id', friendId)
            .eq('is_public', true)
            .order('created_at', ascending: false);

        final decks = List<Map<String, dynamic>>.from(response);
        print(
          '🔍 FriendsService: Found ${decks.length} public decks for friend $friendId',
        );
        for (final deck in decks) {
          print('  - Deck: ${deck['name']} (public: ${deck['is_public']})');
        }
        return decks;
      } catch (e) {
        // If is_public column doesn't exist, fall back to getting all decks
        print(
          '⚠️ is_public column not found in decks table, showing all decks: $e',
        );
        final response = await _client
            .from('decks')
            .select('*')
            .eq('user_id', friendId)
            .order('created_at', ascending: false);

        final decks = List<Map<String, dynamic>>.from(response);
        print(
          '🔍 FriendsService: Found ${decks.length} total decks for friend $friendId (fallback)',
        );
        return decks;
      }
    } catch (e) {
      print('❌ Error getting friend decks: $e');
      // Return empty list instead of rethrowing to prevent UI crashes
      return [];
    }
  }

  /// Get friend's cards (both individually public cards and cards from public decks)
  Future<List<Map<String, dynamic>>> getFriendCards(String friendId) async {
    try {
      print('🔍 FriendsService: Getting cards for friend: $friendId');

      Set<String> cardIds = {}; // Use Set to avoid duplicates
      List<Map<String, dynamic>> allCards = [];

      // 1. Get individually public cards
      try {
        final publicCardsResponse = await _client
            .from('flashcards')
            .select('*')
            .eq('user_id', friendId)
            .eq('is_public', true)
            .order('created_at', ascending: false);

        final publicCards = List<Map<String, dynamic>>.from(
          publicCardsResponse,
        );
        print(
          '🔍 FriendsService: Found ${publicCards.length} individually public cards',
        );

        for (final card in publicCards) {
          if (!cardIds.contains(card['id'])) {
            cardIds.add(card['id']);
            allCards.add(card);
          }
        }
      } catch (e) {
        print('⚠️ is_public column not found in flashcards table: $e');
      }

      // 2. Get cards from public decks
      try {
        // First get all public deck IDs for this friend
        final publicDecksResponse = await _client
            .from('decks')
            .select('id')
            .eq('user_id', friendId)
            .eq('is_public', true);

        final publicDeckIds = publicDecksResponse
            .map((deck) => deck['id'] as String)
            .toList();
        print('🔍 FriendsService: Found ${publicDeckIds.length} public decks');

        if (publicDeckIds.isNotEmpty) {
          // Then get all cards from those public decks via deck_cards table
          final publicDeckCardsResponse = await _client
              .from('deck_cards')
              .select('''
                flashcard_id,
                flashcards!inner(*)
              ''')
              .eq('flashcards.user_id', friendId)
              .inFilter('deck_id', publicDeckIds);

          print(
            '🔍 FriendsService: Found ${publicDeckCardsResponse.length} cards from public decks via deck_cards',
          );

          for (final deckCard in publicDeckCardsResponse) {
            final card = deckCard['flashcards'] as Map<String, dynamic>;
            if (!cardIds.contains(card['id'])) {
              cardIds.add(card['id']);
              allCards.add(card);
            }
          }

          // If no cards found via deck_cards but friend has public decks,
          // it means deck_cards relationships are missing - use fallback
          if (publicDeckCardsResponse.isEmpty) {
            print(
              '🔍 FriendsService: No deck_cards relationships found for public decks',
            );
            print(
              '🔍 FriendsService: This means when deck is public, all cards should be public',
            );
            print(
              '🔍 FriendsService: Using fallback - all friend cards are considered public',
            );

            // Get all friend's cards since deck_cards relationships are missing
            final allFriendCardsResponse = await _client
                .from('flashcards')
                .select('*')
                .eq('user_id', friendId)
                .order('created_at', ascending: false);

            print(
              '🔍 FriendsService: Found ${allFriendCardsResponse.length} total friend cards (fallback for public decks)',
            );

            for (final card in allFriendCardsResponse) {
              if (!cardIds.contains(card['id'])) {
                cardIds.add(card['id']);
                allCards.add(card);
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ Error getting cards from public decks: $e');
      }

      // 3. Final fallback - if still no cards found (no public decks, no individual public cards)
      if (allCards.isEmpty) {
        print(
          '⚠️ No public cards found - no public decks and no individual public cards',
        );
        print('🔍 FriendsService: This friend has no public content to share');
      }

      print(
        '🔍 FriendsService: Total cards available to friend: ${allCards.length}',
      );
      for (final card in allCards) {
        print('  - Card: ${card['word']} -> ${card['definition']}');
      }

      return allCards;
    } catch (e) {
      print('❌ Error getting friend cards: $e');
      // Return empty list instead of rethrowing to prevent UI crashes
      return [];
    }
  }

  /// Get cards for a specific friend's deck
  Future<List<Map<String, dynamic>>> getFriendDeckCards(
    String friendId,
    String deckId,
  ) async {
    try {
      print(
        '🔍 FriendsService: Getting cards for friend $friendId in deck $deckId',
      );

      // First, let's check if the deck exists and get its info
      final deckResponse = await _client
          .from('decks')
          .select('*')
          .eq('id', deckId)
          .eq('user_id', friendId)
          .single();

      print(
        '🔍 FriendsService: Deck info: ${deckResponse['name']} (public: ${deckResponse['is_public']})',
      );

      // Get all deck_cards entries for this deck (without user filter first)
      final allDeckCardsResponse = await _client
          .from('deck_cards')
          .select('''
            flashcard_id,
            flashcards!inner(*)
          ''')
          .eq('deck_id', deckId);

      print(
        '🔍 FriendsService: Total cards in deck (any user): ${allDeckCardsResponse.length}',
      );
      if (allDeckCardsResponse.isNotEmpty) {
        print(
          '🔍 FriendsService: First card user_id: ${allDeckCardsResponse.first['flashcards']['user_id']}',
        );
        print('🔍 FriendsService: Looking for friend_id: $friendId');
      }

      // Let's also check if the friend has any cards at all
      final friendCardsResponse = await _client
          .from('flashcards')
          .select('*')
          .eq('user_id', friendId);

      print(
        '🔍 FriendsService: Friend has ${friendCardsResponse.length} total cards',
      );
      if (friendCardsResponse.isNotEmpty) {
        print('🔍 FriendsService: First few friend cards:');
        for (int i = 0; i < friendCardsResponse.length && i < 3; i++) {
          final card = friendCardsResponse[i];
          print(
            '  - Card: ${card['word']} -> ${card['definition']} (id: ${card['id']})',
          );
        }
      }

      // Check if any of the friend's cards are linked to any deck
      final friendCardsInAnyDeck = await _client
          .from('deck_cards')
          .select('''
            deck_id,
            flashcard_id,
            flashcards!inner(*)
          ''')
          .eq('flashcards.user_id', friendId);

      print(
        '🔍 FriendsService: Friend has ${friendCardsInAnyDeck.length} cards linked to decks',
      );
      if (friendCardsInAnyDeck.isNotEmpty) {
        print('🔍 FriendsService: Friend cards in decks:');
        for (final deckCard in friendCardsInAnyDeck) {
          final card = deckCard['flashcards'];
          print('  - Card: ${card['word']} in deck: ${deckCard['deck_id']}');
        }
      }

      // Now get cards from the deck using the deck_cards relationship table with user filter
      final deckCardsResponse = await _client
          .from('deck_cards')
          .select('''
            flashcard_id,
            flashcards!inner(*)
          ''')
          .eq('deck_id', deckId)
          .eq('flashcards.user_id', friendId);

      final cards = deckCardsResponse
          .map((deckCard) => deckCard['flashcards'] as Map<String, dynamic>)
          .toList();

      print(
        '🔍 FriendsService: Found ${cards.length} cards in deck $deckId for friend $friendId',
      );
      for (final card in cards) {
        print('  - Card: ${card['word']} -> ${card['definition']}');
      }

      // If no cards found and friend has cards but no deck relationships, simulate relationships locally
      if (cards.isEmpty &&
          friendCardsResponse.isNotEmpty &&
          friendCardsInAnyDeck.isEmpty) {
        print('🔍 FriendsService: No deck_cards relationships found.');
        print(
          '🔍 FriendsService: Friend has ${friendCardsResponse.length} cards but 0 deck relationships.',
        );
        print(
          '🔍 FriendsService: This suggests the friend\'s data was imported before deck_cards table was populated.',
        );
        print(
          '🔍 FriendsService: Simulating deck-card relationships locally...',
        );

        // Simulate deck-card relationships locally without inserting into database
        final simulatedCards = await _simulateDeckCardRelationships(
          friendId,
          deckId,
          friendCardsResponse,
        );
        print(
          '🔍 FriendsService: Simulated ${simulatedCards.length} cards for deck $deckId',
        );
        return simulatedCards;
      }

      return cards;
    } catch (e) {
      print('❌ Error getting friend deck cards: $e');
      return [];
    }
  }

  /// Populate deck_cards relationships for a specific deck (more efficient)
  Future<bool> populateDeckCardsForSpecificDeck(
    String friendId,
    String deckId,
    List<Map<String, dynamic>> friendCards,
  ) async {
    try {
      print(
        '🔍 FriendsService: Populating deck_cards for specific deck: $deckId',
      );

      // Check if relationships already exist for this deck (without inFilter to avoid URL size issues)
      final existingRelationships = await _client
          .from('deck_cards')
          .select('flashcard_id')
          .eq('deck_id', deckId);

      if (existingRelationships.isNotEmpty) {
        print(
          '🔍 FriendsService: Deck_cards relationships already exist for deck $deckId (${existingRelationships.length} found)',
        );
        return true;
      }

      // Create relationships for this specific deck
      int successCount = 0;
      int errorCount = 0;

      for (final card in friendCards) {
        try {
          await _client.from('deck_cards').insert({
            'deck_id': deckId,
            'flashcard_id': card['id'],
            'created_at': DateTime.now().toIso8601String(),
          });
          successCount++;

          // Log progress every 50 relationships
          if (successCount % 50 == 0) {
            print(
              '🔍 FriendsService: Created $successCount relationships for deck $deckId...',
            );
          }
        } catch (e) {
          // Check if it's a duplicate key error - if so, it's actually fine
          if (e.toString().contains(
            'duplicate key value violates unique constraint',
          )) {
            print(
              '🔍 FriendsService: Relationship already exists, skipping: $deckId -> ${card['id']}',
            );
            successCount++; // Count as success since the relationship exists
          } else {
            errorCount++;
            print(
              '❌ Error creating relationship for card ${card['id']} in deck $deckId: $e',
            );

            // If we get too many errors, stop
            if (errorCount > 10) {
              print(
                '❌ Too many errors, stopping deck_cards population for deck $deckId',
              );
              break;
            }
          }
        }
      }

      if (successCount > 0) {
        print(
          '✅ FriendsService: Successfully created $successCount deck_cards relationships for deck $deckId',
        );
        if (errorCount > 0) {
          print(
            '⚠️ FriendsService: $errorCount relationships failed to create for deck $deckId',
          );
        }
        return true;
      } else {
        print(
          '❌ FriendsService: Failed to create any deck_cards relationships for deck $deckId',
        );
        return false;
      }
    } catch (e) {
      print('❌ Error populating deck_cards for specific deck: $e');
      return false;
    }
  }

  /// Populate deck_cards relationships for a friend (data migration)
  Future<bool> populateFriendDeckCards(String friendId) async {
    try {
      print(
        '🔍 FriendsService: Starting deck_cards population for friend: $friendId',
      );

      // Get all friend's cards
      final friendCardsResponse = await _client
          .from('flashcards')
          .select('*')
          .eq('user_id', friendId);

      if (friendCardsResponse.isEmpty) {
        print('🔍 FriendsService: No cards found for friend $friendId');
        return false;
      }

      // Get all friend's decks
      final friendDecksResponse = await _client
          .from('decks')
          .select('*')
          .eq('user_id', friendId);

      if (friendDecksResponse.isEmpty) {
        print('🔍 FriendsService: No decks found for friend $friendId');
        return false;
      }

      print(
        '🔍 FriendsService: Found ${friendCardsResponse.length} cards and ${friendDecksResponse.length} decks',
      );

      // Check if deck_cards relationships already exist (without inFilter to avoid URL size issues)
      final existingRelationships = await _client
          .from('deck_cards')
          .select('flashcard_id')
          .limit(1); // Just check if any relationships exist at all

      if (existingRelationships.isNotEmpty) {
        print(
          '🔍 FriendsService: Deck_cards relationships already exist for friend $friendId',
        );
        return true;
      }

      // Create deck_cards relationships
      // For now, we'll add all cards to all decks (this is a simple migration)
      // In a more sophisticated system, we'd need to infer the relationships from the data

      print(
        '🔍 FriendsService: Creating deck_cards relationships for ${friendCardsResponse.length} cards across ${friendDecksResponse.length} decks',
      );

      // Insert relationships one by one to avoid URL size limits
      int successCount = 0;
      int errorCount = 0;

      for (final deck in friendDecksResponse) {
        for (final card in friendCardsResponse) {
          try {
            await _client.from('deck_cards').insert({
              'deck_id': deck['id'],
              'flashcard_id': card['id'],
              'created_at': DateTime.now().toIso8601String(),
            });
            successCount++;

            // Log progress every 100 relationships
            if (successCount % 100 == 0) {
              print(
                '🔍 FriendsService: Created $successCount relationships so far...',
              );
            }
          } catch (e) {
            errorCount++;
            print(
              '❌ Error creating relationship for card ${card['id']} in deck ${deck['id']}: $e',
            );

            // If we get too many errors, stop
            if (errorCount > 50) {
              print('❌ Too many errors, stopping deck_cards population');
              break;
            }
          }
        }

        // If we hit too many errors, stop processing decks
        if (errorCount > 50) {
          break;
        }
      }

      if (successCount > 0) {
        print(
          '✅ FriendsService: Successfully created $successCount deck_cards relationships for friend $friendId',
        );
        if (errorCount > 0) {
          print(
            '⚠️ FriendsService: $errorCount relationships failed to create',
          );
        }
        return true;
      } else {
        print(
          '❌ FriendsService: Failed to create any deck_cards relationships',
        );
        return false;
      }

      return false;
    } catch (e) {
      print('❌ Error populating friend deck_cards: $e');
      return false;
    }
  }

  /// Get card count for a specific friend's deck
  Future<int> getFriendDeckCardCount(String friendId, String deckId) async {
    try {
      print(
        '🔍 FriendsService: Getting card count for friend $friendId in deck $deckId',
      );

      // Try to get count from deck_cards table with proper join
      final deckCardsResponse = await _client
          .from('deck_cards')
          .select('''
            flashcard_id,
            flashcards!inner(user_id)
          ''')
          .eq('deck_id', deckId)
          .eq('flashcards.user_id', friendId);

      if (deckCardsResponse.isNotEmpty) {
        print(
          '🔍 FriendsService: Found ${deckCardsResponse.length} cards in deck via deck_cards table',
        );
        return deckCardsResponse.length;
      }

      // If no cards found via deck_cards, check if friend has cards but no deck relationships
      final friendCardsResponse = await _client
          .from('flashcards')
          .select('id')
          .eq('user_id', friendId);

      if (friendCardsResponse.isNotEmpty) {
        print(
          '🔍 FriendsService: Friend has ${friendCardsResponse.length} total cards but no deck_cards relationships',
        );
        print(
          '🔍 FriendsService: This suggests the friend\'s data was imported before deck_cards table was populated',
        );
        print(
          '🔍 FriendsService: Simulating deck-card relationships for count...',
        );

        // Simulate deck-card relationships locally to get count
        final simulatedCards = await _simulateDeckCardRelationships(
          friendId,
          deckId,
          friendCardsResponse,
        );
        print(
          '🔍 FriendsService: Simulated ${simulatedCards.length} cards for deck $deckId',
        );
        return simulatedCards.length;
      }

      return 0;
    } catch (e) {
      print('❌ Error getting friend deck card count: $e');
      return 0;
    }
  }

  /// Simulate deck-card relationships locally without inserting into database
  Future<List<Map<String, dynamic>>> _simulateDeckCardRelationships(
    String friendId,
    String deckId,
    List<Map<String, dynamic>> allFriendCards,
  ) async {
    try {
      print(
        '🔍 FriendsService: Simulating deck-card relationships for deck $deckId',
      );

      // Get all friend's decks to understand the deck structure
      final friendDecksResponse = await _client
          .from('decks')
          .select('*')
          .eq('user_id', friendId);

      if (friendDecksResponse.isEmpty) {
        print('🔍 FriendsService: No decks found for friend $friendId');
        return [];
      }

      // Find the current deck
      final currentDeck = friendDecksResponse
          .where((deck) => deck['id'] == deckId)
          .firstOrNull;

      if (currentDeck == null) {
        print('🔍 FriendsService: Deck $deckId not found for friend $friendId');
        return [];
      }

      final deckName = currentDeck['name'] as String;
      print('🔍 FriendsService: Simulating cards for deck: $deckName');

      // Strategy: Distribute cards based on deck type and position
      final defaultDeckNames = {'Uncategorized', 'Review'};
      final isDefaultDeck = defaultDeckNames.contains(deckName);

      List<Map<String, dynamic>> simulatedCards = [];

      if (isDefaultDeck) {
        // For default decks, take a smaller subset of cards
        final limit = deckName == 'Uncategorized' ? 10 : 5;
        simulatedCards = allFriendCards.take(limit).toList();
        print(
          '🔍 FriendsService: Default deck "$deckName" - simulating ${simulatedCards.length} cards',
        );
      } else {
        // For custom decks, distribute cards more evenly
        final customDecks = friendDecksResponse
            .where((deck) => !defaultDeckNames.contains(deck['name']))
            .toList();
        final deckIndex = customDecks.indexWhere(
          (deck) => deck['id'] == deckId,
        );

        if (deckIndex != -1) {
          // Calculate which cards should belong to this deck
          final cardsForDefaultDecks =
              15; // 10 for Uncategorized + 5 for Review
          final remainingCards = allFriendCards
              .skip(cardsForDefaultDecks)
              .toList();

          if (remainingCards.isNotEmpty && customDecks.isNotEmpty) {
            final cardsPerDeck = (remainingCards.length / customDecks.length)
                .ceil();
            final startIndex = deckIndex * cardsPerDeck;
            final endIndex = (startIndex + cardsPerDeck).clamp(
              0,
              remainingCards.length,
            );

            if (startIndex < remainingCards.length) {
              simulatedCards = remainingCards.sublist(startIndex, endIndex);
            }
          }
        }

        print(
          '🔍 FriendsService: Custom deck "$deckName" - simulating ${simulatedCards.length} cards',
        );
      }

      return simulatedCards;
    } catch (e) {
      print('❌ Error simulating deck-card relationships: $e');
      return [];
    }
  }

  /// Populate deck_cards relationships by inferring them from existing data
  Future<bool> _populateFriendDeckCardsInferred(String friendId) async {
    try {
      print(
        '🔍 FriendsService: Starting inferred deck_cards population for friend: $friendId',
      );

      // Get all friend's decks
      final friendDecksResponse = await _client
          .from('decks')
          .select('*')
          .eq('user_id', friendId);

      // Get all friend's cards
      final friendCardsResponse = await _client
          .from('flashcards')
          .select('*')
          .eq('user_id', friendId);

      if (friendDecksResponse.isEmpty || friendCardsResponse.isEmpty) {
        print(
          '🔍 FriendsService: No decks or cards found for friend $friendId',
        );
        return false;
      }

      print(
        '🔍 FriendsService: Found ${friendDecksResponse.length} decks and ${friendCardsResponse.length} cards',
      );

      // Strategy: Distribute cards evenly across decks, with some logic for default decks
      final defaultDeckNames = {'Uncategorized', 'Review'};
      final customDecks = friendDecksResponse
          .where((deck) => !defaultDeckNames.contains(deck['name']))
          .toList();
      final defaultDecks = friendDecksResponse
          .where((deck) => defaultDeckNames.contains(deck['name']))
          .toList();

      int successCount = 0;
      int errorCount = 0;

      // First, put some cards in default decks
      for (final deck in defaultDecks) {
        final deckId = deck['id'] as String;
        final deckName = deck['name'] as String;

        // For default decks, put a smaller number of cards
        final cardsForThisDeck = friendCardsResponse
            .take(deckName == 'Uncategorized' ? 10 : 5)
            .toList();

        for (final card in cardsForThisDeck) {
          try {
            await _client.from('deck_cards').insert({
              'deck_id': deckId,
              'flashcard_id': card['id'],
              'created_at': DateTime.now().toIso8601String(),
            });
            successCount++;
          } catch (e) {
            if (!e.toString().contains(
              'duplicate key value violates unique constraint',
            )) {
              errorCount++;
              print(
                '❌ Error creating relationship for card ${card['id']} in deck $deckId: $e',
              );
            }
          }
        }
      }

      // Then, distribute remaining cards across custom decks
      final remainingCards = friendCardsResponse
          .skip(15)
          .toList(); // Skip cards already assigned to default decks
      if (customDecks.isNotEmpty && remainingCards.isNotEmpty) {
        final cardsPerDeck = (remainingCards.length / customDecks.length)
            .ceil();

        for (int i = 0; i < customDecks.length; i++) {
          final deck = customDecks[i];
          final deckId = deck['id'] as String;
          final startIndex = i * cardsPerDeck;
          final endIndex = (startIndex + cardsPerDeck).clamp(
            0,
            remainingCards.length,
          );
          final cardsForThisDeck = remainingCards.sublist(startIndex, endIndex);

          for (final card in cardsForThisDeck) {
            try {
              await _client.from('deck_cards').insert({
                'deck_id': deckId,
                'flashcard_id': card['id'],
                'created_at': DateTime.now().toIso8601String(),
              });
              successCount++;
            } catch (e) {
              if (!e.toString().contains(
                'duplicate key value violates unique constraint',
              )) {
                errorCount++;
                print(
                  '❌ Error creating relationship for card ${card['id']} in deck $deckId: $e',
                );
              }
            }
          }
        }
      }

      if (successCount > 0) {
        print(
          '✅ FriendsService: Successfully created $successCount deck_cards relationships',
        );
        if (errorCount > 0) {
          print(
            '⚠️ FriendsService: $errorCount relationships failed to create',
          );
        }
        return true;
      } else {
        print(
          '❌ FriendsService: Failed to create any deck_cards relationships',
        );
        return false;
      }
    } catch (e) {
      print('❌ Error populating friend deck_cards (inferred): $e');
      return false;
    }
  }

  /// Get friend's stats
  Future<Map<String, dynamic>> getFriendStats(String friendId) async {
    try {
      // Get basic profile info - only use columns that exist in the schema
      final profileResponse = await _client
          .from('user_profiles')
          .select(
            'level, xp, current_streak, total_sessions, total_cards_studied',
          )
          .eq('id', friendId)
          .single();

      // Get deck count - try to get public decks first
      int publicDeckCount = 0;
      try {
        try {
          final deckCountResponse = await _client
              .from('decks')
              .select('id')
              .eq('user_id', friendId)
              .eq('is_public', true);

          publicDeckCount = (deckCountResponse as List).length;
        } catch (e) {
          // If is_public column doesn't exist, count all decks
          print(
            '⚠️ is_public column not found in decks table, counting all decks',
          );
          final deckCountResponse = await _client
              .from('decks')
              .select('id')
              .eq('user_id', friendId);

          publicDeckCount = (deckCountResponse as List).length;
        }
      } catch (e) {
        print('⚠️ Decks table not found, using 0 for deck count');
        publicDeckCount = 0;
      }

      // Get card count - try to get public cards first
      int publicCardCount = 0;
      try {
        try {
          final cardCountResponse = await _client
              .from('flashcards')
              .select('id')
              .eq('user_id', friendId)
              .eq('is_public', true);

          publicCardCount = (cardCountResponse as List).length;
        } catch (e) {
          // If is_public column doesn't exist, count all cards
          print(
            '⚠️ is_public column not found in flashcards table, counting all cards',
          );
          final cardCountResponse = await _client
              .from('flashcards')
              .select('id')
              .eq('user_id', friendId);

          publicCardCount = (cardCountResponse as List).length;
        }
      } catch (e) {
        print('⚠️ Flashcards table not found, using 0 for card count');
        publicCardCount = 0;
      }

      return {
        'level': profileResponse['level'] ?? 1,
        'xp': profileResponse['xp'] ?? 0,
        'current_streak': profileResponse['current_streak'] ?? 0,
        'total_study_time':
            profileResponse['total_sessions'] ??
            0, // Use total_sessions as proxy
        'cards_created':
            profileResponse['total_cards_studied'] ??
            0, // Use total_cards_studied as proxy
        'decks_created': publicDeckCount, // Use actual count
        'public_deck_count': publicDeckCount,
        'public_card_count': publicCardCount,
      };
    } catch (e) {
      print('❌ Error getting friend stats: $e');
      rethrow;
    }
  }

  /// Copy friend's deck
  Future<void> copyFriendDeck(
    String friendId,
    String deckId,
    String newDeckName, {
    Function(int current, int total)? onProgress,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUser!.id;

      // Get the original deck
      final deckResponse = await _client
          .from('decks')
          .select('*')
          .eq('id', deckId)
          .eq('user_id', friendId)
          .eq('is_public', true)
          .single();

      // Create new deck for current user
      print('🔍 FriendsService: Creating new deck: "$newDeckName"');
      final newDeckResponse = await _client
          .from('decks')
          .insert({
            'name': newDeckName,
            'description':
                '${deckResponse['description'] ?? ''} (Copied from ${deckResponse['name']})',
            'user_id': userId,
            'is_public': false, // Copied decks are private by default
            'color': deckResponse['color'] ?? 4280391411, // Default blue color
            'icon': deckResponse['icon'] ?? 58968, // Default folder icon
          })
          .select()
          .single();

      final newDeckId = newDeckResponse['id'] as String;
      print('🔍 FriendsService: Created new deck with ID: $newDeckId');

      // Get all cards from the original deck using the deck_cards relationship table
      // We need to join with flashcards to filter by user_id
      print(
        '🔍 FriendsService: Looking for cards in deck $deckId for friend $friendId',
      );

      final deckCardsResponse = await _client
          .from('deck_cards')
          .select('''
            flashcard_id,
            flashcards!inner(*)
          ''')
          .eq('deck_id', deckId)
          .eq('flashcards.user_id', friendId);

      print(
        '🔍 FriendsService: Found ${deckCardsResponse.length} cards to copy',
      );

      // Debug: Let's also try without the user_id filter to see if there are any cards at all
      final allDeckCardsResponse = await _client
          .from('deck_cards')
          .select('''
            flashcard_id,
            flashcards!inner(*)
          ''')
          .eq('deck_id', deckId);

      print(
        '🔍 FriendsService: Total cards in deck (any user): ${allDeckCardsResponse.length}',
      );
      if (allDeckCardsResponse.isNotEmpty) {
        print(
          '🔍 FriendsService: First card user_id: ${allDeckCardsResponse.first['flashcards']['user_id']}',
        );
        print('🔍 FriendsService: Looking for friend_id: $friendId');
      }

      // If no cards found via deck_cards, simulate relationships locally
      List<Map<String, dynamic>> cardsToCopy = [];
      if (deckCardsResponse.isEmpty && allDeckCardsResponse.isEmpty) {
        print('🔍 FriendsService: No deck_cards relationships found.');
        print(
          '🔍 FriendsService: Simulating deck-card relationships for copying...',
        );

        // Get all friend's cards to simulate relationships
        final friendCardsResponse = await _client
            .from('flashcards')
            .select('*')
            .eq('user_id', friendId);

        if (friendCardsResponse.isNotEmpty) {
          // Simulate deck-card relationships locally
          cardsToCopy = await _simulateDeckCardRelationships(
            friendId,
            deckId,
            friendCardsResponse,
          );
          print(
            '🔍 FriendsService: Simulated ${cardsToCopy.length} cards to copy for deck $deckId',
          );
        } else {
          print('🔍 FriendsService: No friend cards found to copy');
          cardsToCopy = [];
        }
      } else {
        // Use the cards found via deck_cards relationship
        cardsToCopy = deckCardsResponse
            .map((deckCard) => deckCard['flashcards'] as Map<String, dynamic>)
            .toList();
      }

      // Copy each card with progress tracking
      int copiedCount = 0;
      int totalCards = cardsToCopy.length;
      print('🔍 FriendsService: Starting to copy $totalCards cards...');

      for (final card in cardsToCopy) {
        copiedCount++;
        print(
          '🔍 FriendsService: Copying card $copiedCount/$totalCards: "${card['word']}" -> "${card['definition']}"',
        );

        // Report progress
        onProgress?.call(copiedCount, totalCards);

        try {
          // Insert the new card with all required fields
          final newCardResponse = await _client
              .from('flashcards')
              .insert({
                'word': card['word'],
                'definition': card['definition'],
                'example': card['example'] ?? '',
                'example_translation': card['example_translation'] ?? '',
                'article': card['article'] ?? '',
                'plural': card['plural'] ?? '',
                'past_tense': card['past_tense'] ?? '',
                'future_tense': card['future_tense'] ?? '',
                'past_participle': card['past_participle'] ?? '',
                'user_id': userId,
                'success_count': 0,
              })
              .select()
              .single();

          final newCardId = newCardResponse['id'] as String;
          print('🔍 FriendsService: Created new card with ID: $newCardId');

          // Add the card to the new deck using the deck_cards relationship table
          try {
            await _client.from('deck_cards').insert({
              'deck_id': newDeckId,
              'flashcard_id': newCardId,
            });

            print(
              '🔍 FriendsService: Added card $newCardId to deck $newDeckId',
            );
          } catch (e) {
            // Check if it's a duplicate key error - if so, it's actually fine
            if (e.toString().contains(
              'duplicate key value violates unique constraint',
            )) {
              print(
                '🔍 FriendsService: Card $newCardId already in deck $newDeckId, skipping',
              );
            } else {
              print(
                '❌ FriendsService: Error adding card $newCardId to deck $newDeckId: $e',
              );
              rethrow; // Re-throw if it's not a duplicate key error
            }
          }
        } catch (e) {
          print('❌ FriendsService: Error copying card "${card['word']}": $e');
          // Continue with other cards even if one fails
        }
      }

      // Sync the new data to local storage so it appears in the UI
      print('🔍 FriendsService: Syncing copied data to local storage...');
      final syncResult = await DataSyncService.downloadDataFromCloud();
      if (syncResult.isFailure) {
        throw Exception(syncResult.message);
      }
      print('🔍 FriendsService: Data sync completed');
    } catch (e) {
      print('❌ Error copying friend deck: $e');
      rethrow;
    }
  }

  /// Copy friend's card
  Future<void> copyFriendCard(
    String friendId,
    String cardId,
    List<String> targetDeckIds,
  ) async {
    try {
      final userId = SupabaseService.instance.currentUser!.id;

      // Get the original card
      final cardResponse = await _client
          .from('flashcards')
          .select('*')
          .eq('id', cardId)
          .eq('user_id', friendId)
          .single();

      print(
        '🔍 FriendsService: Copying card: "${cardResponse['word']}" -> "${cardResponse['definition']}"',
      );
      print('🔍 FriendsService: Target deck IDs: $targetDeckIds');

      // Create new card for current user with all required fields
      final newCardResponse = await _client
          .from('flashcards')
          .insert({
            'word': cardResponse['word'],
            'definition': cardResponse['definition'],
            'example': cardResponse['example'] ?? '',
            'example_translation': cardResponse['example_translation'] ?? '',
            'article': cardResponse['article'] ?? '',
            'plural': cardResponse['plural'] ?? '',
            'past_tense': cardResponse['past_tense'] ?? '',
            'future_tense': cardResponse['future_tense'] ?? '',
            'past_participle': cardResponse['past_participle'] ?? '',
            'user_id': userId,
            'success_count': 0,
          })
          .select()
          .single();

      final newCardId = newCardResponse['id'] as String;
      print('🔍 FriendsService: Created new card with ID: $newCardId');

      // Add the card to target decks using the deck_cards relationship table
      for (final deckId in targetDeckIds) {
        try {
          await _client.from('deck_cards').insert({
            'deck_id': deckId,
            'flashcard_id': newCardId,
          });
          print(
            '🔍 FriendsService: Successfully added card $newCardId to deck $deckId',
          );
        } catch (e) {
          // Check if it's a duplicate key error - if so, it's actually fine
          if (e.toString().contains(
            'duplicate key value violates unique constraint',
          )) {
            print(
              '🔍 FriendsService: Card $newCardId already in deck $deckId, skipping',
            );
          } else {
            print(
              '❌ FriendsService: Error adding card $newCardId to deck $deckId: $e',
            );
          }
        }
      }

      // Sync the new data to local storage so it appears in the UI
      print('🔍 FriendsService: Syncing copied card to local storage...');
      final syncResult = await DataSyncService.downloadDataFromCloud();
      if (syncResult.isFailure) {
        throw Exception(syncResult.message);
      }
      print('🔍 FriendsService: Data sync completed');
    } catch (e) {
      print('❌ Error copying friend card: $e');
      rethrow;
    }
  }

  /// Check if two users are friends
  Future<bool> areFriends(String otherUserId) async {
    try {
      final userId = SupabaseService.instance.currentUser!.id;

      final response = await _client
          .from('friends')
          .select('id')
          .eq('user_id', userId)
          .eq('friend_id', otherUserId)
          .eq('status', 'accepted')
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking friendship: $e');
      return false;
    }
  }

  /// Check if there's a pending friend request between users
  Future<bool> hasPendingRequest(String otherUserId) async {
    try {
      final userId = SupabaseService.instance.currentUser!.id;

      final response = await _client
          .from('friend_requests')
          .select('id')
          .or(
            'and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)',
          )
          .eq('status', 'pending')
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking pending request: $e');
      return false;
    }
  }

  // MARK: - Helper Methods

  /// Create a notification for a user
  Future<void> _createNotification(
    String userId,
    String type,
    String title,
    String message,
    Map<String, dynamic>? data,
  ) async {
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'data': data,
        'is_read': false,
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  /// Get user's notifications
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await _client
          .from('notifications')
          .select('*')
          .eq('user_id', SupabaseService.instance.currentUser!.id)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting notifications: $e');
      rethrow;
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', SupabaseService.instance.currentUser!.id)
          .eq('is_read', false);
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }
}
