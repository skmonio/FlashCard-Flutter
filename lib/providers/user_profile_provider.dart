import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../models/user_profile.dart';

class UserProfileProvider extends ChangeNotifier {
  static const String _profileKey = 'user_profile';
  
  UserProfile _profile = UserProfile(
    username: 'Learner',
    selectedAvatar: 'person',
    xp: 0,
    level: 1,
    achievements: UserProfileDefaults.defaultAchievements,
    levelRewards: UserProfileDefaults.defaultLevelRewards,
    totalSessions: 0,
    currentStreak: 0,
    bestStreak: 0,
    accuracy: 0.0,
    totalCardsStudied: 0,
    perfectSessions: 0,
  );

  bool _isLoading = false;
  String? _error;

  // Getters
  UserProfile get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Computed properties
  String get username => _profile.username;
  String get selectedAvatar => _profile.selectedAvatar;
  String? get profileImageData => _profile.profileImageData;
  int get xp => _profile.xp;
  int get level => _profile.level;
  List<Achievement> get achievements => _profile.achievements;
  List<LevelReward> get levelRewards => _profile.levelRewards;
  int get totalSessions => _profile.totalSessions;
  int get currentStreak => _profile.currentStreak;
  int get bestStreak => _profile.bestStreak;
  double get accuracy => _profile.accuracy;
  int get totalCardsStudied => _profile.totalCardsStudied;
  int get perfectSessions => _profile.perfectSessions;
  double get progressToNextLevel => _profile.progressToNextLevel;

  // Initialize the provider
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadFromStorage();
    } catch (e) {
      _error = 'Failed to load profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load profile from storage
  Future<void> _loadFromStorage() async {
    print('🔍 UserProfileProvider: _loadFromStorage called');
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(_profileKey);
    
    print('🔍 UserProfileProvider: Loaded profile JSON: $profileJson');
    
    if (profileJson != null) {
      try {
        final profileData = json.decode(profileJson);
        print('🔍 UserProfileProvider: Decoded profile data: $profileData');
        _profile = UserProfile.fromJson(profileData);
        print('🔍 UserProfileProvider: Loaded profile - XP: ${_profile.xp}, Level: ${_profile.level}');
      } catch (e) {
        print('🔍 UserProfileProvider: Error loading profile, using default: $e');
        // If loading fails, use default profile
        _profile = UserProfile(
          username: 'Learner',
          selectedAvatar: 'person',
          xp: 0,
          level: 1,
          achievements: UserProfileDefaults.defaultAchievements,
          levelRewards: UserProfileDefaults.defaultLevelRewards,
          totalSessions: 0,
          currentStreak: 0,
          bestStreak: 0,
          accuracy: 0.0,
          totalCardsStudied: 0,
          perfectSessions: 0,
        );
      }
    } else {
      print('🔍 UserProfileProvider: No profile found in storage, using default');
    }
  }

  // Save profile to storage
  Future<void> _saveToStorage() async {
    try {
      print('🔍 UserProfileProvider: _saveToStorage called');
      final prefs = await SharedPreferences.getInstance();
      final profileJson = json.encode(_profile.toJson());
      print('🔍 UserProfileProvider: Profile JSON: $profileJson');
      await prefs.setString(_profileKey, profileJson);
      print('🔍 UserProfileProvider: Profile saved to SharedPreferences successfully');
    } catch (e) {
      print('🔍 UserProfileProvider: Error saving profile: $e');
      _error = 'Failed to save profile: $e';
      notifyListeners();
    }
  }

  // Update username
  Future<void> updateUsername(String newUsername) async {
    _profile = _profile.copyWith(username: newUsername);
    await _saveToStorage();
    notifyListeners();
  }

  // Update avatar
  Future<void> updateAvatar(String newAvatar) async {
    _profile = _profile.copyWith(selectedAvatar: newAvatar);
    await _saveToStorage();
    notifyListeners();
  }

  // Update profile image
  Future<void> updateProfileImage(String? imageData) async {
    _profile = _profile.copyWith(profileImageData: imageData);
    await _saveToStorage();
    notifyListeners();
  }

  // Add XP and check for level up
  Future<void> addXp(int xpToAdd) async {
    print('🔍 UserProfileProvider: addXp called with $xpToAdd XP');
    print('🔍 UserProfileProvider: Current profile XP: ${_profile.xp}, Level: ${_profile.level}');
    
    final oldLevel = _profile.level;
    final oldXp = _profile.xp;
    final newXp = _profile.xp + xpToAdd;
    
    print('🔍 UserProfileProvider: Old XP: $oldXp, New XP: $newXp, Old Level: $oldLevel');
    
    // Calculate new level
    int newLevel = oldLevel;
    while (_getXpForLevel(newLevel + 1) <= newXp) {
      newLevel++;
    }
    
    print('🔍 UserProfileProvider: New Level: $newLevel');
    print('🔍 UserProfileProvider: XP for current level ${newLevel}: ${_getXpForLevel(newLevel)}');
    print('🔍 UserProfileProvider: XP for next level ${newLevel + 1}: ${_getXpForLevel(newLevel + 1)}');
    
    _profile = _profile.copyWith(xp: newXp, level: newLevel);
    
    print('🔍 UserProfileProvider: After copyWith - XP: ${_profile.xp}, Level: ${_profile.level}');
    print('🔍 UserProfileProvider: Progress to next level: ${_profile.progressToNextLevel}');
    
    // Check for level up
    if (newLevel > oldLevel) {
      print('🔍 UserProfileProvider: Level up detected! ${oldLevel} -> ${newLevel}');
      _checkLevelRewards(newLevel);
    }
    
    // Check achievements
    _checkAchievements();
    
    print('🔍 UserProfileProvider: About to save to storage');
    await _saveToStorage();
    print('🔍 UserProfileProvider: Storage save complete');
    
    print('🔍 UserProfileProvider: About to call notifyListeners');
    notifyListeners();
    print('🔍 UserProfileProvider: notifyListeners called - XP update complete');
  }

  // Update session statistics
  Future<void> updateSessionStats({
    required int cardsStudied,
    required double sessionAccuracy,
    required bool isPerfect,
  }) async {
    final newTotalSessions = _profile.totalSessions + 1;
    final newTotalCardsStudied = _profile.totalCardsStudied + cardsStudied;
    final newPerfectSessions = _profile.perfectSessions + (isPerfect ? 1 : 0);
    
    // Calculate new accuracy
    final totalAccuracy = (_profile.accuracy * _profile.totalSessions) + sessionAccuracy;
    final newAccuracy = (totalAccuracy / newTotalSessions).clamp(0.0, 1.0); // Clamp to 0-100%
    
    _profile = _profile.copyWith(
      totalSessions: newTotalSessions,
      totalCardsStudied: newTotalCardsStudied,
      perfectSessions: newPerfectSessions,
      accuracy: newAccuracy,
    );
    
    // Check achievements
    _checkAchievements();
    
    await _saveToStorage();
    notifyListeners();
  }

  // Update streak based on study activity (Duolingo-style)
  Future<void> updateStreakFromStudyActivity() async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // If no last study date, this is the first study session
    if (_profile.lastStudyDate == null) {
      _profile = _profile.copyWith(
        currentStreak: 1,
        bestStreak: 1,
        lastStudyDate: todayDate,
      );
    } else {
      final lastStudyDate = DateTime(
        _profile.lastStudyDate!.year,
        _profile.lastStudyDate!.month,
        _profile.lastStudyDate!.day,
      );
      
      final daysDifference = todayDate.difference(lastStudyDate).inDays;
      
      if (daysDifference == 0) {
        // Already studied today, don't change streak
        return;
      } else if (daysDifference == 1) {
        // Consecutive day, increment streak
        final newStreak = _profile.currentStreak + 1;
        final newBestStreak = newStreak > _profile.bestStreak ? newStreak : _profile.bestStreak;
        
        _profile = _profile.copyWith(
          currentStreak: newStreak,
          bestStreak: newBestStreak,
          lastStudyDate: todayDate,
        );
      } else {
        // Streak broken (more than 1 day gap), reset to 1
        _profile = _profile.copyWith(
          currentStreak: 1,
          lastStudyDate: todayDate,
        );
      }
    }
    
    // Check achievements
    _checkAchievements();
    
    await _saveToStorage();
    notifyListeners();
  }

  // Legacy method for backward compatibility
  Future<void> updateStreak(int newStreak) async {
    final newBestStreak = newStreak > _profile.bestStreak ? newStreak : _profile.bestStreak;
    
    _profile = _profile.copyWith(
      currentStreak: newStreak,
      bestStreak: newBestStreak,
    );
    
    // Check achievements
    _checkAchievements();
    
    await _saveToStorage();
    notifyListeners();
  }

  // Check and unlock achievements
  void _checkAchievements() {
    final updatedAchievements = List<Achievement>.from(_profile.achievements);
    bool hasChanges = false;
    
    for (int i = 0; i < updatedAchievements.length; i++) {
      final achievement = updatedAchievements[i];
      
      if (!achievement.isUnlocked) {
        bool shouldUnlock = false;
        
        switch (achievement.type) {
          case AchievementType.xp:
            shouldUnlock = _profile.xp >= achievement.xpRequired;
            break;
          case AchievementType.level:
            shouldUnlock = _profile.level >= achievement.levelRequired;
            break;
          case AchievementType.streak:
            shouldUnlock = _profile.currentStreak >= achievement.xpRequired;
            break;
          case AchievementType.sessions:
            shouldUnlock = _profile.totalSessions >= achievement.xpRequired;
            break;
          case AchievementType.perfect:
            shouldUnlock = _profile.perfectSessions >= achievement.xpRequired;
            break;
          case AchievementType.accuracy:
            shouldUnlock = _profile.accuracy >= (achievement.xpRequired / 100.0);
            break;
        }
        
        if (shouldUnlock) {
          updatedAchievements[i] = achievement.copyWith(
            isUnlocked: true,
            unlockedDate: DateTime.now(),
          );
          hasChanges = true;
        }
      }
    }
    
    if (hasChanges) {
      _profile = _profile.copyWith(achievements: updatedAchievements);
    }
  }

  // Check level rewards
  void _checkLevelRewards(int newLevel) {
    final updatedRewards = List<LevelReward>.from(_profile.levelRewards);
    bool hasChanges = false;
    
    for (int i = 0; i < updatedRewards.length; i++) {
      final reward = updatedRewards[i];
      
      if (!reward.isClaimed && reward.level <= newLevel) {
        // Auto-claim rewards when level is reached
        updatedRewards[i] = reward.copyWith(isClaimed: true);
        hasChanges = true;
        
        // Apply reward effects
        _applyReward(reward);
      }
    }
    
    if (hasChanges) {
      _profile = _profile.copyWith(levelRewards: updatedRewards);
    }
  }

  // Apply reward effects
  void _applyReward(LevelReward reward) {
    switch (reward.type) {
      case LevelRewardType.xp:
        addXp(reward.value);
        break;
      case LevelRewardType.streak:
        // Streak protection logic would go here
        break;
      case LevelRewardType.feature:
        // Feature unlock logic would go here
        break;
      case LevelRewardType.cosmetic:
        // Cosmetic unlock logic would go here
        break;
    }
  }

  // Claim a level reward manually
  Future<void> claimReward(String rewardId) async {
    final updatedRewards = List<LevelReward>.from(_profile.levelRewards);
    final rewardIndex = updatedRewards.indexWhere((r) => r.id == rewardId);
    
    if (rewardIndex != -1) {
      final reward = updatedRewards[rewardIndex];
      if (!reward.isClaimed && reward.level <= _profile.level) {
        updatedRewards[rewardIndex] = reward.copyWith(isClaimed: true);
        _profile = _profile.copyWith(levelRewards: updatedRewards);
        
        // Apply reward effects
        _applyReward(reward);
        
        await _saveToStorage();
        notifyListeners();
      }
    }
  }

  // Reset profile (for testing)
  Future<void> resetProfile() async {
    _profile = UserProfile(
      username: 'Learner',
      selectedAvatar: 'person',
      xp: 0,
      level: 1,
      achievements: UserProfileDefaults.defaultAchievements,
      levelRewards: UserProfileDefaults.defaultLevelRewards,
      totalSessions: 0,
      currentStreak: 0,
      bestStreak: 0,
      accuracy: 0.0,
      totalCardsStudied: 0,
      perfectSessions: 0,
    );
    
    await _saveToStorage();
    notifyListeners();
  }

  // Reset XP and progress
  Future<void> resetXpAndProgress() async {
    _profile = _profile.copyWith(
      xp: 0,
      level: 1,
      achievements: UserProfileDefaults.defaultAchievements,
      levelRewards: UserProfileDefaults.defaultLevelRewards,
      totalSessions: 0,
      currentStreak: 0,
      bestStreak: 0,
      accuracy: 0.0,
      totalCardsStudied: 0,
      perfectSessions: 0,
    );
    
    await _saveToStorage();
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Helper method to calculate XP for a level
  int _getXpForLevel(int level) {
    return (100 * pow(level, 1.5)).round();
  }
} 