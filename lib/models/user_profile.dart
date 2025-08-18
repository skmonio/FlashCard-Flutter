import 'dart:convert';
import 'dart:math';

// MARK: - Achievement System
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int xpRequired;
  final int levelRequired;
  final AchievementType type;
  bool isUnlocked;
  DateTime? unlockedDate;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.xpRequired,
    required this.levelRequired,
    required this.type,
    this.isUnlocked = false,
    this.unlockedDate,
  });

  factory Achievement.create({
    required String title,
    required String description,
    required String icon,
    required int xpRequired,
    required int levelRequired,
    required AchievementType type,
  }) {
    return Achievement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      icon: icon,
      xpRequired: xpRequired,
      levelRequired: levelRequired,
      type: type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'xpRequired': xpRequired,
      'levelRequired': levelRequired,
      'type': type.toString().split('.').last,
      'isUnlocked': isUnlocked,
      'unlockedDate': unlockedDate?.toIso8601String(),
    };
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      xpRequired: json['xpRequired'] ?? 0,
      levelRequired: json['levelRequired'] ?? 0,
      type: AchievementType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => AchievementType.xp,
      ),
      isUnlocked: json['isUnlocked'] ?? false,
      unlockedDate: json['unlockedDate'] != null 
          ? DateTime.parse(json['unlockedDate']) 
          : null,
    );
  }

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    int? xpRequired,
    int? levelRequired,
    AchievementType? type,
    bool? isUnlocked,
    DateTime? unlockedDate,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      xpRequired: xpRequired ?? this.xpRequired,
      levelRequired: levelRequired ?? this.levelRequired,
      type: type ?? this.type,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedDate: unlockedDate ?? this.unlockedDate,
    );
  }
}

enum AchievementType {
  xp,
  level,
  streak,
  sessions,
  perfect,
  accuracy,
}

extension AchievementTypeExtension on AchievementType {
  String get color {
    switch (this) {
      case AchievementType.xp:
        return '#FFD700'; // Yellow
      case AchievementType.level:
        return '#007AFF'; // Blue
      case AchievementType.streak:
        return '#FF9500'; // Orange
      case AchievementType.sessions:
        return '#34C759'; // Green
      case AchievementType.perfect:
        return '#AF52DE'; // Purple
      case AchievementType.accuracy:
        return '#5AC8FA'; // Teal
    }
  }
}

// MARK: - Level Reward System
class LevelReward {
  final String id;
  final int level;
  final String title;
  final String description;
  final String icon;
  final LevelRewardType type;
  final int value;
  bool isClaimed;

  LevelReward({
    required this.id,
    required this.level,
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
    required this.value,
    this.isClaimed = false,
  });

  factory LevelReward.create({
    required int level,
    required String title,
    required String description,
    required String icon,
    required LevelRewardType type,
    required int value,
  }) {
    return LevelReward(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      level: level,
      title: title,
      description: description,
      icon: icon,
      type: type,
      value: value,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level': level,
      'title': title,
      'description': description,
      'icon': icon,
      'type': type.toString().split('.').last,
      'value': value,
      'isClaimed': isClaimed,
    };
  }

  factory LevelReward.fromJson(Map<String, dynamic> json) {
    return LevelReward(
      id: json['id'] ?? '',
      level: json['level'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      type: LevelRewardType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => LevelRewardType.xp,
      ),
      value: json['value'] ?? 0,
      isClaimed: json['isClaimed'] ?? false,
    );
  }

  LevelReward copyWith({
    String? id,
    int? level,
    String? title,
    String? description,
    String? icon,
    LevelRewardType? type,
    int? value,
    bool? isClaimed,
  }) {
    return LevelReward(
      id: id ?? this.id,
      level: level ?? this.level,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      value: value ?? this.value,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }
}

enum LevelRewardType {
  xp,
  streak,
  feature,
  cosmetic,
}

extension LevelRewardTypeExtension on LevelRewardType {
  String get color {
    switch (this) {
      case LevelRewardType.xp:
        return '#FFD700'; // Yellow
      case LevelRewardType.streak:
        return '#FF9500'; // Orange
      case LevelRewardType.feature:
        return '#007AFF'; // Blue
      case LevelRewardType.cosmetic:
        return '#AF52DE'; // Purple
    }
  }
}

// MARK: - User Profile
class UserProfile {
  final String username;
  final String selectedAvatar;
  final String? profileImageData;
  final int xp;
  final int level;
  final List<Achievement> achievements;
  final List<LevelReward> levelRewards;
  final int totalSessions;
  final int currentStreak;
  final int bestStreak;
  final double accuracy;
  final int totalCardsStudied;
  final int perfectSessions;
  final DateTime? lastStudyDate;

  UserProfile({
    required this.username,
    required this.selectedAvatar,
    this.profileImageData,
    required this.xp,
    required this.level,
    required this.achievements,
    required this.levelRewards,
    required this.totalSessions,
    required this.currentStreak,
    required this.bestStreak,
    required this.accuracy,
    required this.totalCardsStudied,
    required this.perfectSessions,
    this.lastStudyDate,
  });

  double get progressToNextLevel {
    final xpForCurrentLevel = _getXpForLevel(level);
    final xpForNextLevel = _getXpForLevel(level + 1);
    final xpProgress = xp - xpForCurrentLevel;
    final xpNeeded = xpForNextLevel - xpForCurrentLevel;
    return xpProgress / xpNeeded;
  }

  int _getXpForLevel(int level) {
    // XP formula: 100 * level^1.5
    return (100 * pow(level, 1.5)).round();
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'selectedAvatar': selectedAvatar,
      'profileImageData': profileImageData,
      'xp': xp,
      'level': level,
      'achievements': achievements.map((a) => a.toJson()).toList(),
      'levelRewards': levelRewards.map((r) => r.toJson()).toList(),
      'totalSessions': totalSessions,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'accuracy': accuracy,
      'totalCardsStudied': totalCardsStudied,
      'perfectSessions': perfectSessions,
      'lastStudyDate': lastStudyDate?.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username'] ?? 'Learner',
      selectedAvatar: json['selectedAvatar'] ?? 'person',
      profileImageData: json['profileImageData'],
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 1,
      achievements: (json['achievements'] as List?)
          ?.map((a) => Achievement.fromJson(a))
          .toList() ?? [],
      levelRewards: (json['levelRewards'] as List?)
          ?.map((r) => LevelReward.fromJson(r))
          .toList() ?? [],
      totalSessions: json['totalSessions'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      bestStreak: json['bestStreak'] ?? 0,
      accuracy: json['accuracy']?.toDouble() ?? 0.0,
      totalCardsStudied: json['totalCardsStudied'] ?? 0,
      perfectSessions: json['perfectSessions'] ?? 0,
      lastStudyDate: json['lastStudyDate'] != null ? DateTime.parse(json['lastStudyDate']) : null,
    );
  }

  UserProfile copyWith({
    String? username,
    String? selectedAvatar,
    String? profileImageData,
    int? xp,
    int? level,
    List<Achievement>? achievements,
    List<LevelReward>? levelRewards,
    int? totalSessions,
    int? currentStreak,
    int? bestStreak,
    double? accuracy,
    int? totalCardsStudied,
    int? perfectSessions,
    DateTime? lastStudyDate,
  }) {
    return UserProfile(
      username: username ?? this.username,
      selectedAvatar: selectedAvatar ?? this.selectedAvatar,
      profileImageData: profileImageData ?? this.profileImageData,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      achievements: achievements ?? this.achievements,
      levelRewards: levelRewards ?? this.levelRewards,
      totalSessions: totalSessions ?? this.totalSessions,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      accuracy: accuracy ?? this.accuracy,
      totalCardsStudied: totalCardsStudied ?? this.totalCardsStudied,
      perfectSessions: perfectSessions ?? this.perfectSessions,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
    );
  }
}

// MARK: - Default Data
class UserProfileDefaults {
  static List<Achievement> get defaultAchievements => [
    Achievement.create(
      title: 'First Steps',
      description: 'Complete your first study session',
      icon: 'play.circle.fill',
      xpRequired: 0,
      levelRequired: 1,
      type: AchievementType.sessions,
    ),
    Achievement.create(
      title: 'Streak Master',
      description: 'Maintain a 7-day study streak',
      icon: 'flame.fill',
      xpRequired: 0,
      levelRequired: 1,
      type: AchievementType.streak,
    ),
    Achievement.create(
      title: 'Perfect Score',
      description: 'Get 100% accuracy in a session',
      icon: 'star.fill',
      xpRequired: 0,
      levelRequired: 1,
      type: AchievementType.perfect,
    ),
    Achievement.create(
      title: 'Level Up',
      description: 'Reach level 5',
      icon: 'arrow.up.circle.fill',
      xpRequired: 0,
      levelRequired: 5,
      type: AchievementType.level,
    ),
    Achievement.create(
      title: 'XP Collector',
      description: 'Earn 1000 XP',
      icon: 'gift.fill',
      xpRequired: 1000,
      levelRequired: 1,
      type: AchievementType.xp,
    ),
    Achievement.create(
      title: 'Accuracy Expert',
      description: 'Maintain 90%+ accuracy over 10 sessions',
      icon: 'target',
      xpRequired: 0,
      levelRequired: 1,
      type: AchievementType.accuracy,
    ),
  ];

  static List<LevelReward> get defaultLevelRewards => [
    LevelReward.create(
      level: 2,
      title: 'Bonus XP',
      description: 'Earn 50 bonus XP',
      icon: 'gift.fill',
      type: LevelRewardType.xp,
      value: 50,
    ),
    LevelReward.create(
      level: 3,
      title: 'Streak Protection',
      description: 'One free streak protection',
      icon: 'shield.fill',
      type: LevelRewardType.streak,
      value: 1,
    ),
    LevelReward.create(
      level: 5,
      title: 'Advanced Features',
      description: 'Unlock advanced study modes',
      icon: 'star.fill',
      type: LevelRewardType.feature,
      value: 1,
    ),
    LevelReward.create(
      level: 7,
      title: 'Custom Avatar',
      description: 'Unlock premium avatar options',
      icon: 'person.crop.circle.fill',
      type: LevelRewardType.cosmetic,
      value: 1,
    ),
  ];
} 