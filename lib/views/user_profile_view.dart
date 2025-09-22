import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math';
import '../providers/user_profile_provider.dart';
import '../models/user_profile.dart';
import '../utils/avatar_utils.dart';
import 'edit_profile_view.dart';
import 'friends_view.dart';
import 'leaderboard_view.dart';

class UserProfileView extends StatefulWidget {
  const UserProfileView({super.key});

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> with TickerProviderStateMixin {
  int _selectedTab = 0;
  late PageController _pageController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
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
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
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
              // Fixed Header - matching Taal Trek header height
              SafeArea(
                child: Container(
                  height: kToolbarHeight,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: _buildCustomHeader(context),
                ),
              ),
              
              // Profile Header (only show on Stats page)
              if (_selectedTab == 0) _buildProfileHeader(profileProvider),
              
              // Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _selectedTab = index;
                    });
                  },
                  children: [
                    _buildStatsTab(profileProvider),
                    _buildFriendsTab(),
                    _buildLeaderboardTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigation(),
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
                          AvatarUtils.getAvatarIcon(provider.selectedAvatar),
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

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Separator line
            Container(
              height: 0.5,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
            // Tab buttons with flexible height
            Container(
              height: 60,
              child: Row(
                children: [
                  _buildBottomNavItem('Stats', Icons.analytics, 0),
                  _buildBottomNavItem('Friends', Icons.people, 1),
                  _buildBottomNavItem('Leaderboard', Icons.emoji_events, 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(String title, IconData icon, int index) {
    final isSelected = _selectedTab == index;
    final color = isSelected 
        ? Theme.of(context).colorScheme.primary 
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
              ),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsTab(UserProfileProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20), // Standard padding
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


  void _showEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfileView(),
      ),
    );
  }

  // Helper methods for icons and colors


  // Helper method to calculate XP needed for next level
  int _getXpForNextLevel(int currentLevel) {
    // XP formula: 100 * level^1.5 (same as in UserProfile model)
    return (100 * pow(currentLevel + 1, 1.5)).round();
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            'Profile',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        
        // Left side - Back button with proper padding
        Positioned(
          left: 16, // Add proper padding from left edge
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        
        // Right side - Edit button
        Positioned(
          right: 16, // Add proper padding from right edge
          top: 0,
          bottom: 0,
          child: IconButton(
            icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => _showEditProfile(),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsTab() {
    return const FriendsView();
  }

  Widget _buildLeaderboardTab() {
    return const LeaderboardView();
  }
} 