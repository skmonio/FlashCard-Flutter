import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math';
import '../providers/user_profile_provider.dart';
import '../models/user_profile.dart';
import 'edit_profile_view.dart';

class UserProfileView extends StatefulWidget {
  const UserProfileView({super.key});

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> with TickerProviderStateMixin {
  int _selectedTab = 0;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProfileProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditProfile(),
          ),
        ],
      ),
      body: Consumer<UserProfileProvider>(
        builder: (context, profileProvider, child) {
          if (profileProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profileProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${profileProvider.error}'),
                  ElevatedButton(
                    onPressed: () => profileProvider.clearError(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Profile Header
              _buildProfileHeader(profileProvider),
              
              // Tab Selector
              _buildTabSelector(),
              
              // Tab Content
              Expanded(
                child: _buildTabContent(profileProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(UserProfileProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Image with Circular XP Progress Bar
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Circular XP Progress Bar
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: provider.progressToNextLevel,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              
              // Profile Image/Avatar
              GestureDetector(
                onTap: () => _showEditProfile(),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: provider.profileImageData != null
                      ? ClipOval(
                          child: Image.memory(
                            base64Decode(provider.profileImageData!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          _getAvatarIcon(provider.selectedAvatar),
                          size: 50,
                          color: Colors.blue,
                        ),
                ),
              ),
              
              // Level indicator overlay
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    'Lv.${provider.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // User Info
          Column(
            children: [
              Text(
                provider.username,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Level ${provider.level}',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${provider.xp} XP / ${_getXpForNextLevel(provider.level)} XP',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabButton('Stats', 0),
          _buildTabButton('Achievements', 1),
          _buildTabButton('Rewards', 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(UserProfileProvider provider) {
    switch (_selectedTab) {
      case 0:
        return _buildStatsTab(provider);
      case 1:
        return _buildAchievementsTab(provider);
      case 2:
        return _buildRewardsTab(provider);
      default:
        return _buildStatsTab(provider);
    }
  }

  Widget _buildStatsTab(UserProfileProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStatCard(
            'Total Sessions',
            '${provider.totalSessions}',
            Icons.play_circle_fill,
            Colors.green,
          ),
          _buildStatCard(
            'Current Streak',
            '${provider.currentStreak} days',
            Icons.local_fire_department,
            Colors.orange,
          ),
          _buildStatCard(
            'Best Streak',
            '${provider.bestStreak} days',
            Icons.emoji_events,
            Colors.yellow,
          ),
          _buildStatCard(
            'Accuracy',
            '${(provider.accuracy * 100).toStringAsFixed(1)}%',
            Icons.gps_fixed,
            Colors.blue,
          ),
          _buildStatCard(
            'Cards Studied',
            '${provider.totalCardsStudied}',
            Icons.style,
            Colors.purple,
          ),
          _buildStatCard(
            'Perfect Sessions',
            '${provider.perfectSessions}',
            Icons.star,
            Colors.pink,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab(UserProfileProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.achievements.length,
      itemBuilder: (context, index) {
        final achievement = provider.achievements[index];
        return _buildAchievementCard(achievement);
      },
    );
  }

  Widget _buildRewardsTab(UserProfileProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: provider.levelRewards.length,
      itemBuilder: (context, index) {
        final reward = provider.levelRewards[index];
        return _buildRewardCard(reward, provider);
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: achievement.isUnlocked 
                ? _getAchievementColor(achievement.type).withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(
            _getAchievementIcon(achievement.icon),
            color: achievement.isUnlocked 
                ? _getAchievementColor(achievement.type)
                : Colors.grey,
          ),
        ),
        title: Text(
          achievement.title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: achievement.isUnlocked ? Theme.of(context).colorScheme.onSurface : Colors.grey,
          ),
        ),
        subtitle: Text(
          achievement.description,
          style: TextStyle(
            color: achievement.isUnlocked ? Colors.grey[600] : Colors.grey,
          ),
        ),
        trailing: achievement.isUnlocked
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.lock, color: Colors.grey),
      ),
    );
  }

  Widget _buildRewardCard(LevelReward reward, UserProfileProvider provider) {
    final canClaim = !reward.isClaimed && provider.level >= reward.level;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: reward.isClaimed 
                ? _getRewardColor(reward.type).withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(
            _getRewardIcon(reward.icon),
            color: reward.isClaimed 
                ? _getRewardColor(reward.type)
                : Colors.grey,
          ),
        ),
        title: Text(
          reward.title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: reward.isClaimed ? Theme.of(context).colorScheme.onSurface : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reward.description,
              style: TextStyle(
                color: reward.isClaimed ? Colors.grey[600] : Colors.grey,
              ),
            ),
            Text(
              'Level ${reward.level}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: reward.isClaimed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : canClaim
                ? IconButton(
                    icon: const Icon(Icons.card_giftcard, color: Colors.orange),
                    onPressed: () => provider.claimReward(reward.id),
                  )
                : const Icon(Icons.lock, color: Colors.grey),
      ),
    );
  }

  void _showEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfileView(),
      ),
    );
  }

  // Helper methods for icons and colors
  IconData _getAvatarIcon(String avatar) {
    switch (avatar) {
      case 'person.crop.circle.fill':
        return Icons.person;
      case 'graduationcap.fill':
        return Icons.school;
      case 'book.fill':
        return Icons.book;
      case 'brain.head.profile':
        return Icons.psychology;
      default:
        return Icons.person;
    }
  }

  Color _getAchievementColor(AchievementType type) {
    switch (type) {
      case AchievementType.xp:
        return Colors.yellow;
      case AchievementType.level:
        return Colors.blue;
      case AchievementType.streak:
        return Colors.orange;
      case AchievementType.sessions:
        return Colors.green;
      case AchievementType.perfect:
        return Colors.purple;
      case AchievementType.accuracy:
        return Colors.teal;
    }
  }

  Color _getRewardColor(LevelRewardType type) {
    switch (type) {
      case LevelRewardType.xp:
        return Colors.yellow;
      case LevelRewardType.streak:
        return Colors.orange;
      case LevelRewardType.feature:
        return Colors.blue;
      case LevelRewardType.cosmetic:
        return Colors.purple;
    }
  }

  IconData _getAchievementIcon(String icon) {
    switch (icon) {
      case 'play.circle.fill':
        return Icons.play_circle_fill;
      case 'flame.fill':
        return Icons.local_fire_department;
      case 'star.fill':
        return Icons.star;
      case 'arrow.up.circle.fill':
        return Icons.trending_up;
      case 'gift.fill':
        return Icons.card_giftcard;
      case 'target':
        return Icons.gps_fixed;
      default:
        return Icons.emoji_events;
    }
  }

  IconData _getRewardIcon(String icon) {
    switch (icon) {
      case 'gift.fill':
        return Icons.card_giftcard;
      case 'shield.fill':
        return Icons.shield;
      case 'star.fill':
        return Icons.star;
      case 'person.crop.circle.fill':
        return Icons.person;
      default:
        return Icons.card_giftcard;
    }
  }

  // Helper method to calculate XP needed for next level
  int _getXpForNextLevel(int currentLevel) {
    // XP formula: 100 * level^1.5 (same as in UserProfile model)
    return (100 * pow(currentLevel + 1, 1.5)).round();
  }
} 