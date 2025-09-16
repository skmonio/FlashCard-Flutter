import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class Friend {
  final String id;
  final String userId;
  final String friendId;
  final String username;
  final String selectedAvatar;
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
      senderAvatar: json['sender_avatar'] ?? json['selected_avatar'] ?? 'person',
      message: json['message'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class FriendsService {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();

  SupabaseClient get _client => SupabaseService.instance.client;

  // MARK: - Friend Management

  /// Search for users by username
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('id, username, selected_avatar, level, xp, current_streak')
          .ilike('username', '%$query%')
          .neq('id', SupabaseService.instance.currentUser!.id)
          .limit(20);
      
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

  /// Get pending friend requests
  Future<List<FriendRequest>> getPendingFriendRequests() async {
    try {
      final response = await _client
          .from('friend_requests')
          .select('''
            *,
            sender:user_profiles!friend_requests_sender_id_fkey(
              username,
              selected_avatar
            )
          ''')
          .eq('receiver_id', SupabaseService.instance.currentUser!.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

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
      final userId = SupabaseService.instance.currentUser!.id;
      
      // Get friends relationships
      final friendsResponse = await _client
          .from('friends')
          .select('friend_id')
          .eq('user_id', userId)
          .eq('status', 'accepted');

      if (friendsResponse.isEmpty) {
        return [];
      }

      final friendIds = friendsResponse.map((f) => f['friend_id'] as String).toList();
      
      // Get friends' profiles
      final profilesResponse = await _client
          .from('user_profiles')
          .select('id, username, selected_avatar, level, xp, current_streak, updated_at')
          .inFilter('id', friendIds);

      return profilesResponse.map<Friend>((data) {
        return Friend(
          id: data['id'] ?? '',
          userId: userId,
          friendId: data['id'] ?? '',
          username: data['username'] ?? '',
          selectedAvatar: data['selected_avatar'] ?? 'person',
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
          .or('and(user_id.eq.$userId,friend_id.eq.$friendId),and(user_id.eq.$friendId,friend_id.eq.$userId)');
    } catch (e) {
      print('Error removing friend: $e');
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
          .or('and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)')
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
