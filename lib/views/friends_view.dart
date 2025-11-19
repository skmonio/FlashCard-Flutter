import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/friends_service.dart';
import '../utils/enhanced_snackbar.dart';
import '../utils/avatar_utils.dart';
import 'friend_profile_view.dart';
import '../components/cached_profile_avatar.dart';

class FriendsView extends StatefulWidget {
  const FriendsView({super.key});

  @override
  State<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> with TickerProviderStateMixin {
  late TabController _tabController;
  final FriendsService _friendsService = FriendsService();
  
  List<Friend> _friends = [];
  List<FriendRequest> _pendingRequests = [];
  List<Map<String, dynamic>> _searchResults = [];
  Set<String> _sentRequests = {}; // Track sent friend requests
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final friends = await _friendsService.getFriends();
      final requests = await _friendsService.getPendingFriendRequests();
      
      setState(() {
        _friends = friends;
        _pendingRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      
      // Provide clearer error messages
      String errorMessage;
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('null check') || errorString.contains('user not logged in')) {
        errorMessage = 'Please log in to view your friends';
      } else if (errorString.contains('network') || errorString.contains('connection')) {
        errorMessage = 'Unable to load friends. Please check your internet connection';
      } else {
        errorMessage = 'Unable to load friends. Please try again later';
      }
      
      _showErrorSnackBar(errorMessage);
    }
  }

  Future<void> _searchUsers() async {
    if (_searchQuery.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    try {
      final results = await _friendsService.searchUsers(_searchQuery);
      setState(() => _searchResults = results);
    } catch (e) {
      _showErrorSnackBar('Failed to search users: $e');
    }
  }

  Future<void> _sendFriendRequest(String userId) async {
    try {
      await _friendsService.sendFriendRequest(userId);
      setState(() {
        _sentRequests.add(userId);
      });
      _showSuccessSnackBar('Friend request sent!');
      _searchUsers(); // Refresh search results
    } catch (e) {
      _showErrorSnackBar('Failed to send friend request: $e');
    }
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      await _friendsService.acceptFriendRequest(requestId);
      _showSuccessSnackBar('Friend request accepted!');
      _loadData(); // Reload all data
    } catch (e) {
      _showErrorSnackBar('Failed to accept friend request: $e');
    }
  }

  Future<void> _declineFriendRequest(String requestId) async {
    try {
      await _friendsService.declineFriendRequest(requestId);
      _showSuccessSnackBar('Friend request declined');
      _loadData(); // Reload all data
    } catch (e) {
      _showErrorSnackBar('Failed to decline friend request: $e');
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final confirmed = await _showRemoveFriendDialog();
    if (confirmed == true) {
      try {
        await _friendsService.removeFriend(friendId);
        _showSuccessSnackBar('Friend removed');
        _loadData(); // Reload all data
      } catch (e) {
        _showErrorSnackBar('Failed to remove friend: $e');
      }
    }
  }

  void _viewFriendProfile(Friend friend) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendProfileView(friend: friend),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    EnhancedSnackBar.showError(context, message: message);
  }

  void _showSuccessSnackBar(String message) {
    EnhancedSnackBar.showSuccess(context, message: message);
  }

  Future<bool?> _showRemoveFriendDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: const Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
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
            child: Material(
              color: Colors.transparent,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                indicatorSize: TabBarIndicatorSize.tab,
                isScrollable: false,
                physics: const ClampingScrollPhysics(),
                onTap: (index) {
                  // Ensure tab switching works
                  _tabController.animateTo(index);
                },
                tabs: const [
                  Tab(text: 'Friends', icon: Icon(Icons.people)),
                  Tab(text: 'Requests', icon: Icon(Icons.person_add)),
                  Tab(text: 'Search', icon: Icon(Icons.search)),
                ],
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const ClampingScrollPhysics(),
              children: [
                _buildFriendsTab(),
                _buildRequestsTab(),
                _buildSearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFriendsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for users to add as friends',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(2);
              },
              icon: const Icon(Icons.search),
              label: const Text('Find Friends'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                minimumSize: const Size(44, 44),
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
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          return _buildFriendCard(friend);
        },
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          final request = _pendingRequests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for users...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _searchResults = [];
                        });
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _searchUsers();
            },
          ),
        ),
        
        // Search results
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'Search for users to add as friends'
                        : 'No users found',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return _buildSearchResultCard(user);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFriendCard(Friend friend) {
    return Semantics(
      label: '${friend.username}, level ${friend.level} with ${friend.xp} XP',
      hint: 'Double tap to view profile options',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CachedProfileAvatar(
            size: 48,
            base64Image: friend.profileImageData,
            fallbackIcon: AvatarUtils.getAvatarIcon(friend.selectedAvatar),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
            semanticLabel: '${friend.username} profile picture',
          ),
          title: Text(
            friend.username,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level ${friend.level} • ${friend.xp} XP'),
              if ((friend.currentStreak ?? 0) > 0)
                Text(
                  '${friend.currentStreak ?? 0} day streak',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'view_profile') {
                _viewFriendProfile(friend);
              } else if (value == 'remove') {
                _removeFriend(friend.friendId);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view_profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('View Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Remove Friend'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(FriendRequest request) {
    return Semantics(
      label: 'Friend request from ${request.senderUsername}',
      hint: 'Use the buttons to accept or decline the request',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CachedProfileAvatar(
                    size: 48,
                    base64Image: null,
                    fallbackIcon: AvatarUtils.getAvatarIcon(request.senderAvatar),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
                    semanticLabel: '${request.senderUsername} profile picture',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.senderUsername,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'wants to be your friend',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              if (request.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  request.message!,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _declineFriendRequest(request.id),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptFriendRequest(request.id),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> user) {
    final userId = user['id'];
    final hasRequestSent = _sentRequests.contains(userId);
    
    return Semantics(
      label: '${user['username'] ?? 'User'}, level ${user['level'] ?? 1}, ${user['xp'] ?? 0} XP',
      hint: hasRequestSent ? 'Request already sent' : 'Double tap to send a friend request',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CachedProfileAvatar(
            size: 48,
            base64Image: user['profile_image_data'] as String?,
            fallbackIcon: AvatarUtils.getAvatarIcon(user['selected_avatar'] ?? 'person'),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
            semanticLabel: '${user['username'] ?? 'User'} profile picture',
          ),
          title: Text(
            user['username'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('Level ${user['level'] ?? 1} • ${user['xp'] ?? 0} XP'),
          trailing: hasRequestSent
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  constraints: const BoxConstraints(minHeight: 44),
                  child: const Text(
                    'Requested',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: () => _sendFriendRequest(userId),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('Add Friend'),
                ),
        ),
      ),
    );
  }

}
