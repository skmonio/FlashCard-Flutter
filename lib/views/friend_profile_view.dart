import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/friends_service.dart';
import '../providers/flashcard_provider.dart';
import '../models/flash_card.dart';
import '../models/deck.dart';
import '../utils/enhanced_snackbar.dart';
import 'add_card_view.dart';
import 'add_deck_view.dart';

class FriendProfileView extends StatefulWidget {
  final Friend friend;

  const FriendProfileView({
    super.key,
    required this.friend,
  });

  @override
  State<FriendProfileView> createState() => _FriendProfileViewState();
}

class _FriendProfileViewState extends State<FriendProfileView> with TickerProviderStateMixin {
  late TabController _tabController;
  final FriendsService _friendsService = FriendsService();
  
  List<Map<String, dynamic>> _friendDecks = [];
  List<Map<String, dynamic>> _friendCards = [];
  Map<String, dynamic> _friendStats = {};
  bool _isLoading = true;
  String _currentTab = 'stats';
  
  // Search and sorting for cards tab
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'word'; // 'word', 'definition', 'created_at'
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriendData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendData() async {
    setState(() => _isLoading = true);
    
    try {
      final futures = await Future.wait([
        _friendsService.getFriendStats(widget.friend.friendId),
        _friendsService.getFriendDecks(widget.friend.friendId),
        _friendsService.getFriendCards(widget.friend.friendId),
      ]);
      
      setState(() {
        _friendStats = futures[0] as Map<String, dynamic>;
        _friendDecks = futures[1] as List<Map<String, dynamic>>;
        _friendCards = futures[2] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load friend data: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredAndSortedCards {
    List<Map<String, dynamic>> filtered = _friendCards;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((card) {
        final word = (card['word'] ?? '').toString().toLowerCase();
        final definition = (card['definition'] ?? '').toString().toLowerCase();
        final example = (card['example'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        
        return word.contains(query) || 
               definition.contains(query) || 
               example.contains(query);
      }).toList();
    }
    
    // Apply sorting
    filtered.sort((a, b) {
      dynamic aValue, bValue;
      
      switch (_sortBy) {
        case 'word':
          aValue = (a['word'] ?? '').toString().toLowerCase();
          bValue = (b['word'] ?? '').toString().toLowerCase();
          break;
        case 'definition':
          aValue = (a['definition'] ?? '').toString().toLowerCase();
          bValue = (b['definition'] ?? '').toString().toLowerCase();
          break;
        case 'created_at':
          aValue = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
          bValue = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
          break;
        default:
          aValue = (a['word'] ?? '').toString().toLowerCase();
          bValue = (b['word'] ?? '').toString().toLowerCase();
      }
      
      if (aValue is String && bValue is String) {
        return _sortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      } else if (aValue is DateTime && bValue is DateTime) {
        return _sortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      }
      
      return 0;
    });
    
    return filtered;
  }

  void _showErrorSnackBar(String message) {
    EnhancedSnackBar.showError(context, message: message);
  }

  void _showSuccessSnackBar(String message) {
    EnhancedSnackBar.showSuccess(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friend.username),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        ),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {
              _currentTab = ['stats', 'decks', 'cards'][index];
            });
          },
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Stats'),
            Tab(icon: Icon(Icons.folder), text: 'Decks'),
            Tab(icon: Icon(Icons.style), text: 'Cards'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(),
                _buildDecksTab(),
                _buildCardsTab(),
              ],
            ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      widget.friend.selectedAvatar,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.friend.username,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Level ${_friendStats['level'] ?? 1} • ${_friendStats['xp'] ?? 0} XP',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((_friendStats['current_streak'] ?? 0) > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_friendStats['current_streak'] ?? 0} day streak',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Learning Statistics
          _buildStatsSection(
            title: 'Learning Statistics',
            icon: Icons.school,
            children: [
              _buildStatRow('Total Study Time', _formatStudyTime(_friendStats['total_study_time'] ?? 0)),
              _buildStatRow('Current Streak', '${_friendStats['current_streak'] ?? 0} days'),
              _buildStatRow('Level', '${_friendStats['level'] ?? 1}'),
              _buildStatRow('Total XP', '${_friendStats['xp'] ?? 0}'),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Content Statistics
          _buildStatsSection(
            title: 'Content Created',
            icon: Icons.create,
            children: [
              _buildStatRow('Public Decks', '${_friendStats['public_deck_count'] ?? 0}'),
              _buildStatRow('Public Cards', '${_friendStats['public_card_count'] ?? 0}'),
              _buildStatRow('Total Decks Created', '${_friendStats['decks_created'] ?? 0}'),
              _buildStatRow('Total Cards Created', '${_friendStats['cards_created'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecksTab() {
    if (_friendDecks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No public decks',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.friend.username} hasn\'t made any decks public yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriendData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friendDecks.length,
        itemBuilder: (context, index) {
          final deck = _friendDecks[index];
          return _buildDeckCard(deck);
        },
      ),
    );
  }

  Widget _buildCardsTab() {
    if (_friendCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.style_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No public cards',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.friend.username} hasn\'t made any cards public yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final filteredCards = _filteredAndSortedCards;

    return RefreshIndicator(
      onRefresh: _loadFriendData,
      child: Column(
        children: [
          // Search and sort controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search cards...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 12),
                // Sort controls
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: InputDecoration(
                          labelText: 'Sort by',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'word', child: Text('Word')),
                          DropdownMenuItem(value: 'definition', child: Text('Definition')),
                          DropdownMenuItem(value: 'created_at', child: Text('Date Created')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sortBy = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        setState(() => _sortAscending = !_sortAscending);
                      },
                      icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                      tooltip: _sortAscending ? 'Sort ascending' : 'Sort descending',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Results count
                Text(
                  '${filteredCards.length} of ${_friendCards.length} cards',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          // Cards list
          Expanded(
            child: filteredCards.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No cards found',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or sort criteria',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredCards.length,
                    itemBuilder: (context, index) {
                      final card = filteredCards[index];
                      return _buildCardItem(card);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckCard(Map<String, dynamic> deck) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: FutureBuilder<int>(
        future: _friendsService.getFriendDeckCardCount(widget.friend.friendId, deck['id']),
        builder: (context, snapshot) {
          final cardCount = snapshot.data ?? 0;
          return ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(deck['color'] ?? 0xFF2196F3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                deck['icon'] != null ? IconData(deck['icon'], fontFamily: 'MaterialIcons') : Icons.folder,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: Text(
              deck['name'] ?? 'Unnamed Deck',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deck['description'] ?? 'No description',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$cardCount cards',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            onTap: () => _showDeckCardsDialog(deck),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'view_cards') {
                  _showDeckCardsDialog(deck);
                } else if (value == 'copy') {
                  _showCopyDeckDialog(deck);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view_cards',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('View Cards'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Copy Deck'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> card) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              card['word']?.toString().substring(0, 1).toUpperCase() ?? '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        title: Text(
          card['word'] ?? 'Unknown Word',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          card['definition'] ?? 'No definition',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _showCardDetailsDialog(card),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'copy') {
              _showCopyCardDialog(card);
            } else if (value == 'view_details') {
              _showCardDetailsDialog(card);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view_details',
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.copy, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Copy Card'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCopyDeckDialog(Map<String, dynamic> deck) {
    final TextEditingController nameController = TextEditingController(
      text: '${deck['name']} (Copy)',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy Deck'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Copy "${deck['name']}" to your decks?'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'New Deck Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _copyDeck(deck, nameController.text);
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _showCopyCardDialog(Map<String, dynamic> card) {
    final provider = context.read<FlashcardProvider>();
    final userDecks = provider.decks;
    
    if (userDecks.isEmpty) {
      _showErrorSnackBar('You need to create a deck first before copying cards');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _CopyCardDialog(
        card: card,
        userDecks: userDecks,
        onCopy: (selectedDeckIds) async {
          Navigator.of(context).pop();
          await _copyCardToDecks(card, selectedDeckIds);
        },
      ),
    );
  }

  Future<void> _copyDeck(Map<String, dynamic> deck, String newName) async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CopyProgressDialog(
        deckName: deck['name'],
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );

    try {
      int currentProgress = 0;
      int totalProgress = 0;
      
      await _friendsService.copyFriendDeck(
        widget.friend.friendId,
        deck['id'],
        newName,
        onProgress: (current, total) {
          currentProgress = current;
          totalProgress = total;
          // Update the progress dialog
          if (context.mounted) {
            // Find the progress dialog and update it
            final progressDialog = context.findAncestorStateOfType<_CopyProgressDialogState>();
            progressDialog?.updateProgress(current, total);
          }
        },
      );
      
      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      _showSuccessSnackBar('Deck copied successfully!');
      
      // Refresh the current user's data
      final provider = context.read<FlashcardProvider>();
      await provider.refresh();
    } catch (e) {
      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      _showErrorSnackBar('Failed to copy deck: $e');
    }
  }

  Future<void> _copyCardToDecks(Map<String, dynamic> card, List<String> selectedDeckIds) async {
    try {
      await _friendsService.copyFriendCard(
        widget.friend.friendId,
        card['id'],
        selectedDeckIds,
      );
      _showSuccessSnackBar('Card copied successfully to ${selectedDeckIds.length} deck(s)!');
      
      // Refresh the current user's data
      final provider = context.read<FlashcardProvider>();
      await provider.refresh();
    } catch (e) {
      _showErrorSnackBar('Failed to copy card: $e');
    }
  }

  void _showCardDetailsDialog(Map<String, dynamic> card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Card Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Word', card['word'] ?? 'N/A'),
              _buildDetailRow('Definition', card['definition'] ?? 'N/A'),
              if (card['example']?.isNotEmpty == true)
                _buildDetailRow('Example', card['example']),
              if (card['example_translation']?.isNotEmpty == true)
                _buildDetailRow('Example Translation', card['example_translation']),
              if (card['article']?.isNotEmpty == true)
                _buildDetailRow('Article (de/het)', card['article']),
              if (card['plural']?.isNotEmpty == true)
                _buildDetailRow('Plural', card['plural']),
              if (card['past_tense']?.isNotEmpty == true)
                _buildDetailRow('Past Tense', card['past_tense']),
              if (card['future_tense']?.isNotEmpty == true)
                _buildDetailRow('Future Tense', card['future_tense']),
              if (card['past_participle']?.isNotEmpty == true)
                _buildDetailRow('Past Participle', card['past_participle']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showCopyCardDialog(card);
            },
            child: const Text('Copy Card'),
          ),
        ],
      ),
    );
  }

  void _showDeckCardsDialog(Map<String, dynamic> deck) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading cards...'),
          ],
        ),
      ),
    );

    try {
      // Get cards for this deck
      final cards = await _friendsService.getFriendDeckCards(
        widget.friend.friendId,
        deck['id'],
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show cards dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${deck['name']} - Cards'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: cards.isEmpty
                ? const Center(
                    child: Text('No cards in this deck'),
                  )
                : ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                card['word']?.toString().substring(0, 1).toUpperCase() ?? '?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            card['word'] ?? 'Unknown Word',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            card['definition'] ?? 'No definition',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            _showCardDetailsDialog(card);
                          },
                          trailing: IconButton(
                            onPressed: () {
                              _showCopyCardDialog(card);
                            },
                            icon: const Icon(Icons.copy, color: Colors.blue),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showCopyDeckDialog(deck);
              },
              child: const Text('Copy Deck'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show error
      _showErrorSnackBar('Failed to load deck cards: $e');
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatStudyTime(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else if (minutes < 1440) {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      return remainingMinutes > 0 ? '$hours hours $remainingMinutes minutes' : '$hours hours';
    } else {
      final days = (minutes / 1440).floor();
      final remainingHours = ((minutes % 1440) / 60).floor();
      return remainingHours > 0 ? '$days days $remainingHours hours' : '$days days';
    }
  }
}

class _CopyCardDialog extends StatefulWidget {
  final Map<String, dynamic> card;
  final List<Deck> userDecks;
  final Function(List<String>) onCopy;

  const _CopyCardDialog({
    required this.card,
    required this.userDecks,
    required this.onCopy,
  });

  @override
  State<_CopyCardDialog> createState() => _CopyCardDialogState();
}

class _CopyCardDialogState extends State<_CopyCardDialog> {
  final Set<String> _selectedDeckIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Copy Card'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Details Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Card Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              widget.card['word']?.toString().substring(0, 1).toUpperCase() ?? '?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.card['word'] ?? 'Unknown Word',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                widget.card['definition'] ?? 'No definition',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Additional card details
                    if (widget.card['article']?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text('Article: ${widget.card['article']}'),
                    ],
                    if (widget.card['plural']?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text('Plural: ${widget.card['plural']}'),
                    ],
                    if (widget.card['example']?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Example: ${widget.card['example']}',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Deck Selection Section
              Text(
                'Select Decks to Copy To:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Deck List
              ...widget.userDecks.map((deck) => CheckboxListTile(
                title: Text(deck.name),
                subtitle: Text('${deck.cards.length} cards'),
                value: _selectedDeckIds.contains(deck.id),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedDeckIds.add(deck.id);
                    } else {
                      _selectedDeckIds.remove(deck.id);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedDeckIds.isEmpty ? null : () {
            widget.onCopy(_selectedDeckIds.toList());
          },
          child: Text('Copy to ${_selectedDeckIds.length} deck(s)'),
        ),
      ],
    );
  }
}

class _CopyProgressDialog extends StatefulWidget {
  final String deckName;
  final VoidCallback onCancel;

  const _CopyProgressDialog({
    required this.deckName,
    required this.onCancel,
  });

  @override
  State<_CopyProgressDialog> createState() => _CopyProgressDialogState();
}

class _CopyProgressDialogState extends State<_CopyProgressDialog> {
  int _currentProgress = 0;
  int _totalProgress = 0;

  void updateProgress(int current, int total) {
    if (mounted) {
      setState(() {
        _currentProgress = current;
        _totalProgress = total;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Copying "${widget.deckName}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Copying cards...'),
          const SizedBox(height: 16),
          if (_totalProgress > 0) ...[
            LinearProgressIndicator(
              value: _currentProgress / _totalProgress,
            ),
            const SizedBox(height: 8),
            Text('$_currentProgress of $_totalProgress cards copied'),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Preparing to copy...'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
