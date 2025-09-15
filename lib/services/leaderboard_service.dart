import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'friends_service.dart';

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String username;
  final String selectedAvatar;
  final int level;
  final int xp;
  final int currentStreak;
  final int totalSessions;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.selectedAvatar,
    required this.level,
    required this.xp,
    required this.currentStreak,
    required this.totalSessions,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, {bool isCurrentUser = false}) {
    return LeaderboardEntry(
      rank: json['rank'] ?? 0,
      userId: json['user_id'] ?? '',
      username: json['username'] ?? '',
      selectedAvatar: json['selected_avatar'] ?? 'person',
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      totalSessions: json['total_sessions'] ?? 0,
      isCurrentUser: isCurrentUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'user_id': userId,
      'username': username,
      'selected_avatar': selectedAvatar,
      'level': level,
      'xp': xp,
      'current_streak': currentStreak,
      'total_sessions': totalSessions,
      'is_current_user': isCurrentUser,
    };
  }
}

class UserRank {
  final int rank;
  final int totalUsers;

  UserRank({
    required this.rank,
    required this.totalUsers,
  });

  factory UserRank.fromJson(Map<String, dynamic> json) {
    return UserRank(
      rank: json['rank'] ?? 0,
      totalUsers: json['total_users'] ?? 0,
    );
  }
}

enum LeaderboardType {
  overall,
  weekly,
  monthly,
  friends,
}

class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  SupabaseClient get _client => SupabaseService.instance.client;

  // MARK: - Leaderboard Operations

  /// Get the global leaderboard
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({int limit = 50}) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('id, username, selected_avatar, level, xp, current_streak, total_sessions')
          .order('xp', ascending: false)
          .order('level', ascending: false)
          .limit(limit);

      final currentUserId = SupabaseService.instance.currentUser?.id;
      
      return response.asMap().entries.map<LeaderboardEntry>((entry) {
        final index = entry.key;
        final data = entry.value;
        
        return LeaderboardEntry.fromJson(
          {
            ...data,
            'rank': index + 1,
          },
          isCurrentUser: currentUserId != null && data['id'] == currentUserId,
        );
      }).toList();
    } catch (e) {
      print('Error getting global leaderboard: $e');
      rethrow;
    }
  }

  /// Get the user's current rank
  Future<UserRank> getUserRank() async {
    try {
      final currentUserId = SupabaseService.instance.currentUser!.id;
      
      // Get all users ordered by XP
      final allUsers = await _client
          .from('user_profiles')
          .select('id, xp, level')
          .order('xp', ascending: false)
          .order('level', ascending: false);

      // Find current user's rank
      int userRank = 0;
      for (int i = 0; i < allUsers.length; i++) {
        if (allUsers[i]['id'] == currentUserId) {
          userRank = i + 1;
          break;
        }
      }

      return UserRank(
        rank: userRank,
        totalUsers: allUsers.length,
      );
    } catch (e) {
      print('Error getting user rank: $e');
      rethrow;
    }
  }

  /// Get friends leaderboard
  Future<List<LeaderboardEntry>> getFriendsLeaderboard() async {
    try {
      final friendsService = FriendsService();
      final friends = await friendsService.getFriends();
      
      if (friends.isEmpty) {
        return [];
      }

      final friendIds = friends.map((f) => f.friendId).toList();
      final currentUserId = SupabaseService.instance.currentUser!.id;
      
      // Get friends' profiles with their stats
      final response = await _client
          .from('user_profiles')
          .select('id, username, selected_avatar, level, xp, current_streak, total_sessions')
          .inFilter('id', [...friendIds, currentUserId])
          .order('xp', ascending: false)
          .order('level', ascending: false);

      // Create leaderboard entries with ranks
      final entries = <LeaderboardEntry>[];
      int rank = 1;
      
      for (final data in response) {
        entries.add(LeaderboardEntry.fromJson(
          {
            ...data,
            'rank': rank,
          },
          isCurrentUser: data['id'] == currentUserId,
        ));
        rank++;
      }

      return entries;
    } catch (e) {
      print('Error getting friends leaderboard: $e');
      rethrow;
    }
  }

  /// Get weekly leaderboard (users with highest XP gained this week)
  Future<List<LeaderboardEntry>> getWeeklyLeaderboard({int limit = 50}) async {
    try {
      // Get users who have been active this week
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final response = await _client
          .from('user_profiles')
          .select('id, username, selected_avatar, level, xp, current_streak, total_sessions, updated_at')
          .gte('updated_at', weekAgo.toIso8601String())
          .order('xp', ascending: false)
          .order('level', ascending: false)
          .limit(limit);

      final currentUserId = SupabaseService.instance.currentUser?.id;
      
      return response.asMap().entries.map<LeaderboardEntry>((entry) {
        final index = entry.key;
        final data = entry.value;
        
        return LeaderboardEntry.fromJson(
          {
            ...data,
            'rank': index + 1,
          },
          isCurrentUser: currentUserId != null && data['id'] == currentUserId,
        );
      }).toList();
    } catch (e) {
      print('Error getting weekly leaderboard: $e');
      rethrow;
    }
  }

  /// Get monthly leaderboard (users with highest XP gained this month)
  Future<List<LeaderboardEntry>> getMonthlyLeaderboard({int limit = 50}) async {
    try {
      // Get users who have been active this month
      final monthAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final response = await _client
          .from('user_profiles')
          .select('id, username, selected_avatar, level, xp, current_streak, total_sessions, updated_at')
          .gte('updated_at', monthAgo.toIso8601String())
          .order('xp', ascending: false)
          .order('level', ascending: false)
          .limit(limit);

      final currentUserId = SupabaseService.instance.currentUser?.id;
      
      return response.asMap().entries.map<LeaderboardEntry>((entry) {
        final index = entry.key;
        final data = entry.value;
        
        return LeaderboardEntry.fromJson(
          {
            ...data,
            'rank': index + 1,
          },
          isCurrentUser: currentUserId != null && data['id'] == currentUserId,
        );
      }).toList();
    } catch (e) {
      print('Error getting monthly leaderboard: $e');
      rethrow;
    }
  }

  /// Get leaderboard by type
  Future<List<LeaderboardEntry>> getLeaderboard(
    LeaderboardType type, {
    int limit = 50,
  }) async {
    switch (type) {
      case LeaderboardType.overall:
        return getGlobalLeaderboard(limit: limit);
      case LeaderboardType.weekly:
        return getWeeklyLeaderboard(limit: limit);
      case LeaderboardType.monthly:
        return getMonthlyLeaderboard(limit: limit);
      case LeaderboardType.friends:
        return getFriendsLeaderboard();
    }
  }

  /// Get top performers in specific categories
  Future<List<LeaderboardEntry>> getTopPerformers({
    String category = 'xp',
    int limit = 10,
  }) async {
    try {
      String orderBy;
      switch (category) {
        case 'streak':
          orderBy = 'current_streak';
          break;
        case 'sessions':
          orderBy = 'total_sessions';
          break;
        case 'level':
          orderBy = 'level';
          break;
        default:
          orderBy = 'xp';
      }

      final response = await _client
          .from('user_profiles')
          .select('id, username, selected_avatar, level, xp, current_streak, total_sessions')
          .order(orderBy, ascending: false)
          .limit(limit);

      final currentUserId = SupabaseService.instance.currentUser?.id;
      
      return response.asMap().entries.map<LeaderboardEntry>((entry) {
        final index = entry.key;
        final data = entry.value;
        
        return LeaderboardEntry.fromJson(
          {
            ...data,
            'rank': index + 1,
          },
          isCurrentUser: currentUserId != null && data['id'] == currentUserId,
        );
      }).toList();
    } catch (e) {
      print('Error getting top performers: $e');
      rethrow;
    }
  }

  /// Get user's position in leaderboard with surrounding users
  Future<List<LeaderboardEntry>> getUserContext({int contextSize = 5}) async {
    try {
      final userRank = await getUserRank();
      if (userRank.rank == 0) {
        return [];
      }

      // Get users around the current user's rank
      final startRank = (userRank.rank - contextSize).clamp(1, userRank.totalUsers);
      final endRank = (userRank.rank + contextSize).clamp(1, userRank.totalUsers);

      final response = await _client
          .from('user_profiles')
          .select('id, username, selected_avatar, level, xp, current_streak, total_sessions')
          .order('xp', ascending: false)
          .order('level', ascending: false)
          .range(startRank - 1, endRank - 1);

      final currentUserId = SupabaseService.instance.currentUser?.id;
      
      return response.asMap().entries.map<LeaderboardEntry>((entry) {
        final index = entry.key;
        final data = entry.value;
        
        return LeaderboardEntry.fromJson(
          {
            ...data,
            'rank': startRank + index,
          },
          isCurrentUser: currentUserId != null && data['id'] == currentUserId,
        );
      }).toList();
    } catch (e) {
      print('Error getting user context: $e');
      rethrow;
    }
  }

  /// Get leaderboard statistics
  Future<Map<String, dynamic>> getLeaderboardStats() async {
    try {
      final userRank = await getUserRank();
      
      // Get total number of users
      final totalUsersResponse = await _client
          .from('user_profiles')
          .select('id');
      
      final totalUsers = totalUsersResponse.length;
      
      // Get top 3 users
      final topUsers = await getGlobalLeaderboard(limit: 3);
      
      return {
        'user_rank': userRank.rank,
        'total_users': totalUsers,
        'top_users': topUsers.map((u) => u.toJson()).toList(),
        'percentile': totalUsers > 0 ? ((totalUsers - userRank.rank + 1) / totalUsers * 100).round() : 0,
      };
    } catch (e) {
      print('Error getting leaderboard stats: $e');
      rethrow;
    }
  }
}
