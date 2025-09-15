import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';

class LeaderboardView extends StatefulWidget {
  const LeaderboardView({super.key});

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> with TickerProviderStateMixin {
  late TabController _tabController;
  final LeaderboardService _leaderboardService = LeaderboardService();
  
  List<LeaderboardEntry> _leaderboard = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  LeaderboardType _currentType = LeaderboardType.overall;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final leaderboard = await _leaderboardService.getLeaderboard(_currentType);
      final stats = await _leaderboardService.getLeaderboardStats();
      
      setState(() {
        _leaderboard = leaderboard;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load leaderboard: $e');
    }
  }

  Future<void> _switchLeaderboard(LeaderboardType type) async {
    if (_currentType == type) return;
    
    setState(() {
      _currentType = type;
      _isLoading = true;
    });
    
    try {
      final leaderboard = await _leaderboardService.getLeaderboard(type);
      setState(() {
        _leaderboard = leaderboard;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load leaderboard: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getLeaderboardTitle(LeaderboardType type) {
    switch (type) {
      case LeaderboardType.overall:
        return 'Global';
      case LeaderboardType.weekly:
        return 'This Week';
      case LeaderboardType.monthly:
        return 'This Month';
      case LeaderboardType.friends:
        return 'Friends';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
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
              child: _buildHeader(),
            ),
          ),
          
          // Stats Card
          if (_stats.isNotEmpty) _buildStatsCard(),
          
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (index) {
                final types = [
                  LeaderboardType.overall,
                  LeaderboardType.weekly,
                  LeaderboardType.monthly,
                  LeaderboardType.friends,
                ];
                _switchLeaderboard(types[index]);
              },
              tabs: const [
                Tab(text: 'Global', icon: Icon(Icons.public)),
                Tab(text: 'Weekly', icon: Icon(Icons.calendar_view_week)),
                Tab(text: 'Monthly', icon: Icon(Icons.calendar_month)),
                Tab(text: 'Friends', icon: Icon(Icons.people)),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        // Centered title
        Center(
          child: Text(
            'Leaderboard',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        
        // Back button
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios),
            iconSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    final userRank = _stats['user_rank'] ?? 0;
    final totalUsers = _stats['total_users'] ?? 0;
    final percentile = _stats['percentile'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Rank',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '#$userRank',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'of $totalUsers users',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '$percentile%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Top',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_leaderboard.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No data available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to appear on the leaderboard!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaderboard.length,
        itemBuilder: (context, index) {
          final entry = _leaderboard[index];
          return _buildLeaderboardEntry(entry, index);
        },
      ),
    );
  }

  Widget _buildLeaderboardEntry(LeaderboardEntry entry, int index) {
    final isTopThree = entry.rank <= 3;
    final rankColor = _getRankColor(entry.rank);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: entry.isCurrentUser ? 4 : 1,
      color: entry.isCurrentUser 
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: rankColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: isTopThree
                ? Icon(
                    _getRankIcon(entry.rank),
                    color: Colors.white,
                    size: 20,
                  )
                : Text(
                    '${entry.rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.username,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: entry.isCurrentUser 
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),
            if (entry.isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Level ${entry.level}'),
                const SizedBox(width: 16),
                Text('${entry.xp} XP'),
                if (entry.currentStreak > 0) ...[
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text('${entry.currentStreak}'),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: _currentType == LeaderboardType.friends
            ? IconButton(
                onPressed: () {
                  // Navigate to friend's profile or send message
                  _showFriendOptions(entry);
                },
                icon: const Icon(Icons.more_vert),
              )
            : null,
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // Gold
      case 2:
        return Colors.grey[400]!; // Silver
      case 3:
        return Colors.brown[400]!; // Bronze
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.emoji_events; // Trophy
      case 2:
        return Icons.stars; // Silver star
      case 3:
        return Icons.military_tech; // Award
      default:
        return Icons.person;
    }
  }

  void _showFriendOptions(LeaderboardEntry entry) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to friend's profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Send Message'),
              onTap: () {
                Navigator.pop(context);
                // Open chat with friend
              },
            ),
            ListTile(
              leading: const Icon(Icons.sports_esports),
              title: const Text('Challenge'),
              onTap: () {
                Navigator.pop(context);
                // Send study challenge
              },
            ),
          ],
        ),
      ),
    );
  }
}
