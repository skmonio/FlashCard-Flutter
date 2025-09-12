import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

class SupabaseUserService {
  static final SupabaseUserService _instance = SupabaseUserService._internal();
  factory SupabaseUserService() => _instance;
  SupabaseUserService._internal();
  
  SupabaseClient get _client => SupabaseService.instance.client;
  
  // MARK: - User Profile Operations
  
  /// Get user profile
  Future<UserProfile?> getUserProfile() async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('*')
          .eq('id', SupabaseService.instance.currentUser!.id)
          .maybeSingle();
      
      if (response == null) return null;
      
      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error fetching user profile: $e');
      rethrow;
    }
  }
  
  /// Create or update user profile
  Future<UserProfile> upsertUserProfile(UserProfile profile) async {
    try {
      final response = await _client
          .from('user_profiles')
          .upsert({
            'id': SupabaseService.instance.currentUser!.id,
            'username': profile.username,
            'selected_avatar': profile.selectedAvatar,
            'profile_image_data': profile.profileImageData,
            'xp': profile.xp,
            'level': profile.level,
            'total_sessions': profile.totalSessions,
            'current_streak': profile.currentStreak,
            'best_streak': profile.bestStreak,
            'accuracy': profile.accuracy,
            'total_cards_studied': profile.totalCardsStudied,
            'perfect_sessions': profile.perfectSessions,
            'last_study_date': profile.lastStudyDate?.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      
      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error upserting user profile: $e');
      rethrow;
    }
  }
  
  /// Update user profile fields
  Future<UserProfile> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final response = await _client
          .from('user_profiles')
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', SupabaseService.instance.currentUser!.id)
          .select()
          .single();
      
      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }
  
  // MARK: - Achievement Operations
  
  /// Get user achievements
  Future<List<Achievement>> getAchievements() async {
    try {
      final response = await _client
          .from('achievements')
          .select('*')
          .eq('user_id', SupabaseService.instance.currentUser!.id)
          .order('created_at', ascending: false);
      
      return response.map<Achievement>((data) => Achievement.fromJson(data)).toList();
    } catch (e) {
      print('Error fetching achievements: $e');
      rethrow;
    }
  }
  
  /// Create or update achievement
  Future<Achievement> upsertAchievement(Achievement achievement) async {
    try {
      final response = await _client
          .from('achievements')
          .upsert({
            'id': achievement.id,
            'user_id': SupabaseService.instance.currentUser!.id,
            'title': achievement.title,
            'description': achievement.description,
            'icon': achievement.icon,
            'xp_required': achievement.xpRequired,
            'level_required': achievement.levelRequired,
            'type': achievement.type.toString().split('.').last,
            'is_unlocked': achievement.isUnlocked,
            'unlocked_date': achievement.unlockedDate?.toIso8601String(),
          })
          .select()
          .single();
      
      return Achievement.fromJson(response);
    } catch (e) {
      print('Error upserting achievement: $e');
      rethrow;
    }
  }
  
  /// Unlock an achievement
  Future<void> unlockAchievement(String achievementId) async {
    try {
      await _client
          .from('achievements')
          .update({
            'is_unlocked': true,
            'unlocked_date': DateTime.now().toIso8601String(),
          })
          .eq('id', achievementId)
          .eq('user_id', SupabaseService.instance.currentUser!.id);
    } catch (e) {
      print('Error unlocking achievement: $e');
      rethrow;
    }
  }
  
  // MARK: - Level Reward Operations
  
  /// Get user level rewards
  Future<List<LevelReward>> getLevelRewards() async {
    try {
      final response = await _client
          .from('level_rewards')
          .select('*')
          .eq('user_id', SupabaseService.instance.currentUser!.id)
          .order('level', ascending: true);
      
      return response.map<LevelReward>((data) => LevelReward.fromJson(data)).toList();
    } catch (e) {
      print('Error fetching level rewards: $e');
      rethrow;
    }
  }
  
  /// Create or update level reward
  Future<LevelReward> upsertLevelReward(LevelReward reward) async {
    try {
      final response = await _client
          .from('level_rewards')
          .upsert({
            'id': reward.id,
            'user_id': SupabaseService.instance.currentUser!.id,
            'level': reward.level,
            'title': reward.title,
            'description': reward.description,
            'icon': reward.icon,
            'type': reward.type.toString().split('.').last,
            'value': reward.value,
            'is_claimed': reward.isClaimed,
          })
          .select()
          .single();
      
      return LevelReward.fromJson(response);
    } catch (e) {
      print('Error upserting level reward: $e');
      rethrow;
    }
  }
  
  /// Claim a level reward
  Future<void> claimLevelReward(String rewardId) async {
    try {
      await _client
          .from('level_rewards')
          .update({
            'is_claimed': true,
          })
          .eq('id', rewardId)
          .eq('user_id', SupabaseService.instance.currentUser!.id);
    } catch (e) {
      print('Error claiming level reward: $e');
      rethrow;
    }
  }
  
  // MARK: - Study Session Operations
  
  /// Record a study session
  Future<void> recordStudySession({
    required int xpGained,
    required int cardsStudied,
    required double accuracy,
    required bool isPerfect,
  }) async {
    try {
      final currentProfile = await getUserProfile();
      if (currentProfile == null) return;
      
      final newTotalSessions = currentProfile.totalSessions + 1;
      final newTotalCardsStudied = currentProfile.totalCardsStudied + cardsStudied;
      final newPerfectSessions = isPerfect ? currentProfile.perfectSessions + 1 : currentProfile.perfectSessions;
      
      // Calculate new accuracy (weighted average)
      final newAccuracy = (currentProfile.accuracy * currentProfile.totalSessions + accuracy) / newTotalSessions;
      
      // Calculate new streak
      final now = DateTime.now();
      final lastStudyDate = currentProfile.lastStudyDate;
      int newCurrentStreak = currentProfile.currentStreak;
      
      if (lastStudyDate != null) {
        final daysDifference = now.difference(lastStudyDate).inDays;
        if (daysDifference == 1) {
          newCurrentStreak += 1;
        } else if (daysDifference > 1) {
          newCurrentStreak = 1;
        }
        // If daysDifference == 0, keep current streak (same day)
      } else {
        newCurrentStreak = 1;
      }
      
      final newBestStreak = newCurrentStreak > currentProfile.bestStreak ? newCurrentStreak : currentProfile.bestStreak;
      
      await updateUserProfile({
        'xp': currentProfile.xp + xpGained,
        'total_sessions': newTotalSessions,
        'current_streak': newCurrentStreak,
        'best_streak': newBestStreak,
        'accuracy': newAccuracy,
        'total_cards_studied': newTotalCardsStudied,
        'perfect_sessions': newPerfectSessions,
        'last_study_date': now.toIso8601String(),
      });
    } catch (e) {
      print('Error recording study session: $e');
      rethrow;
    }
  }
  
  /// Add XP to user
  Future<void> addXP(int xp) async {
    try {
      final currentProfile = await getUserProfile();
      if (currentProfile == null) return;
      
      await updateUserProfile({
        'xp': currentProfile.xp + xp,
      });
    } catch (e) {
      print('Error adding XP: $e');
      rethrow;
    }
  }
  
  /// Level up user
  Future<void> levelUp(int newLevel) async {
    try {
      await updateUserProfile({
        'level': newLevel,
      });
    } catch (e) {
      print('Error leveling up user: $e');
      rethrow;
    }
  }
}
