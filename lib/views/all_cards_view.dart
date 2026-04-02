import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/flashcard_provider.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../models/deck.dart';
import '../services/xp_service.dart';
import '../components/hp_bar.dart';
import '../components/card_details_dialog.dart';
import '../components/universal_add_button.dart';
import 'add_card_view.dart';
import 'shuffle_cards_view.dart';
import 'dart:async'; // Added for Timer

enum SortOption {
  wordAZ,
  wordZA,
  definitionAZ,
  definitionZA,
  srsLevel,
  learningPercentage,
  learningPercentageLowHigh,
  dateCreated,
  dateCreatedOldestFirst,
  lastModified,
}

class AllCardsView extends StatefulWidget {
  const AllCardsView({super.key});

  @override
  State<AllCardsView> createState() => _AllCardsViewState();
}

class _AllCardsViewState extends State<AllCardsView> {
  String _searchQuery = '';
  SortOption _sortOption = SortOption.wordAZ;
  bool _isSelectionMode = false;
  Set<String> _selectedCardIds = {};
  bool _selectAll = false;
  bool _enteredViaSelectAll = false; // Track how selection mode was entered
  late TextEditingController _searchController;
  
  // Performance optimization: Cache filtered results
  List<FlashCard>? _cachedFilteredCards;
  String _lastSearchQuery = '';
  SortOption _lastSortOption = SortOption.wordAZ;
  
  // Debounce search
  Timer? _searchDebounceTimer;

  static const int _cardsPageSize = 50;
  late ScrollController _scrollController;
  int _visibleCardCount = _cardsPageSize;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController()
      ..addListener(_onScroll);
    
    // Add listener to refresh when provider updates
    final provider = context.read<FlashcardProvider>();
    provider.addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    
    // Remove listener when disposing
    final provider = context.read<FlashcardProvider>();
    provider.removeListener(_onProviderChanged);
    
    super.dispose();
  }

  void _onProviderChanged() {
    // Refresh the UI when cards are updated (debounced to prevent excessive rebuilds)
    if (mounted) {
      // Only clear cache if search query changed, otherwise just invalidate
      final provider = context.read<FlashcardProvider>();
      final currentCards = provider.cards;
      
      // Only rebuild if cards actually changed
      if (currentCards.length != _cachedFilteredCards?.length) {
        setState(() {
          _cachedFilteredCards = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
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
              child: _buildHeader(context),
            ),
          ),
          
          // Search and Sort Bar
          _buildSearchSortBar(),
          
          // Cards List
          Expanded(
            child: Consumer<FlashcardProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final cards = _getFilteredAndSortedCards(provider);
                
                if (cards.isEmpty) {
                  return _buildEmptyState();
                }
                
                final visibleCount = cards.length < _visibleCardCount ? cards.length : _visibleCardCount;
                final hasMore = cards.length > visibleCount;
                final itemCount = hasMore ? visibleCount + 1 : visibleCount;
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  controller: _scrollController,
                  itemCount: itemCount,
                  // Performance optimization: Add key for better widget recycling
                  itemBuilder: (context, index) {
                    if (hasMore && index >= visibleCount) {
                      return _buildLoadMoreIndicator();
                    }
                    final card = cards[index];
                    return _buildCardItem(card, provider, key: ValueKey(card.id));
                  },
                );
              },
            ),
          ),
          
          // Footer with selection actions (shown when in selection mode)
          if (_isSelectionMode) _buildSelectionFooter(),
        ],
      ),
      floatingActionButton: const UniversalAddButton(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            'Cards',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        
        // Left side - Back button
        Positioned(
          left: 16, // Add proper padding from left edge
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        
        // Right side - Home button
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        
      ],
    );
  }

  Widget _buildSelectionFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Cancel button
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isSelectionMode = false;
                _selectedCardIds.clear();
                _selectAll = false;
                _enteredViaSelectAll = false;
              });
            },
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
          
          const Spacer(),
          
          // Select All Toggle
          TextButton.icon(
            onPressed: () {
              setState(() {
                if (_selectAll) {
                  _selectedCardIds.clear();
                  _selectAll = false;
                } else {
                  final provider = context.read<FlashcardProvider>();
                  final cards = _getFilteredAndSortedCards(provider);
                  _selectedCardIds = cards.map((card) => card.id).toSet();
                  _selectAll = true;
                }
              });
            },
            icon: Icon(_selectAll ? Icons.check_box : Icons.check_box_outline_blank),
            label: Text(_selectAll ? 'Deselect All' : 'Select All'),
          ),
          
          const SizedBox(width: 8),
          
          // Bulk Actions Menu
          if (_selectedCardIds.isNotEmpty)
            TextButton.icon(
              onPressed: _showBulkActionsMenu,
              icon: const Icon(Icons.more_vert),
              label: const Text('Actions'),
            ),
        ],
      ),
    );
  }

  void _playCards() {
    final provider = context.read<FlashcardProvider>();
    
    List<FlashCard> cardsToPlay;
    
    if (_selectedCardIds.isNotEmpty) {
      // Play only selected cards
      cardsToPlay = _selectedCardIds
          .map((id) => provider.cards.firstWhere((card) => card.id == id))
          .toList();
    } else {
      // Play all filtered cards
      cardsToPlay = _getFilteredAndSortedCards(provider);
    }
    
    if (cardsToPlay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cards available to play'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Navigate to shuffle cards view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ShuffleCardsView(),
      ),
    );
  }

  Widget _buildSearchSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search cards...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Sort Button
          PopupMenuButton<SortOption>(
            onSelected: (value) {
              setState(() {
                _sortOption = value;
              });
            },
            itemBuilder: (context) => SortOption.values.map((option) {
              return PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    Icon(_getSortIcon(option)),
                    const SizedBox(width: 8),
                    Text(_getSortOptionText(option)),
                  ],
                ),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getSortIcon(_sortOption), size: 16),
                  const SizedBox(width: 4),
                  Text(_getSortOptionText(_sortOption)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    // Debounce search to improve performance
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
        // Clear cache when search changes
        _cachedFilteredCards = null;
        _visibleCardCount = _cardsPageSize;
        _isLoadingMore = false;
      });
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No cards found' : 'No cards yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'Try adjusting your search terms'
                : 'Add your first card to get started!',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _addSearchedWord(),
              icon: const Icon(Icons.add),
              label: Text('Add "${_searchQuery}"'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                minimumSize: const Size(44, 44),
              ),
            ),
          ] else ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _addNewCard(),
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                minimumSize: const Size(44, 44),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore) return;

    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      _loadMoreCards();
    }
  }

  void _loadMoreCards() {
    if (_isLoadingMore || !mounted) return;
    final provider = context.read<FlashcardProvider>();
    final totalCards = _getFilteredAndSortedCards(provider).length;

    if (_visibleCardCount >= totalCards) return;

    setState(() {
      _isLoadingMore = true;
    });

    Future.microtask(() {
      if (!mounted) return;

      final newCount = (_visibleCardCount + _cardsPageSize).clamp(0, totalCards);
      setState(() {
        _visibleCardCount = newCount;
        _isLoadingMore = false;
      });
    });
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Semantics(
          label: 'Loading more cards',
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildCardItem(FlashCard card, FlashcardProvider provider, {Key? key}) {
    final isSelected = _selectedCardIds.contains(card.id);
    final highContrast = MediaQuery.of(context).highContrast;
    final accentColor = Theme.of(context).colorScheme.primary;
    final levelColor = highContrast
        ? accentColor.withValues(alpha: 0.2)
        : Colors.blue.withOpacity(0.1);
    final levelTextColor = highContrast
        ? accentColor
        : Colors.blue[700];
     
    return Semantics(
      label: '${card.word}, ${card.definition}',
      hint: _isSelectionMode
          ? 'Double tap to select or deselect this card'
          : 'Double tap to view details for ${card.word}' ,
      selected: isSelected,
      button: true,
      child: Card(
        key: key,
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: _isSelectionMode ? () => _toggleCardSelection(card.id) : () => _showCardDetails(card),
          onLongPress: () {
            setState(() {
              _isSelectionMode = true;
              _selectedCardIds.add(card.id);
            });
          },
          child: Container(
            decoration: BoxDecoration(
              border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
              borderRadius: BorderRadius.circular(12),
              // Add visual indicator for cards that have reached daily limit
              color: card.hasReachedDailyLimit ? Colors.orange.withOpacity(0.1) : null,
            ),
            child: ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSelectionMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) => _toggleCardSelection(card.id),
                    ),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: levelColor,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Center(
                      child: Text(
                        '${card.learningPercentage}%',
                        style: TextStyle(
                          color: levelTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              title: Row(
                children: [
                  if (card.article.isNotEmpty)
                    Flexible(
                      child: Text(
                        '${card.article} ',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      card.word,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.definition),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.folder_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getDeckNames(card, provider),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Added: ${_formatDate(card.dateCreated)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Daily limit indicator
                      if (card.hasReachedDailyLimit) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Daily limit reached',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ] else if (card.timesStudiedToday > 0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${card.currentHP}/${card.maxHP} HP',
                              style: TextStyle(
                                fontSize: 10,
                                color: card.isDefeated 
                                    ? Colors.grey[600]
                                    : card.hpPercentage > 0.6 
                                        ? Colors.green[600]
                                        : card.hpPercentage > 0.3 
                                            ? Colors.orange[600]
                                            : Colors.red[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              trailing: _isSelectionMode ? null : PopupMenuButton<String>(
                onSelected: (value) => _handleCardAction(value, card, provider),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Edit Card'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Card', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 16),
                        SizedBox(width: 8),
                        Text('Reset Progress'),
                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getSortOptionText(SortOption option) {
    switch (option) {
      case SortOption.wordAZ:
        return 'A-Z';
      case SortOption.wordZA:
        return 'Z-A';
      case SortOption.definitionAZ:
        return 'Definition A-Z';
      case SortOption.definitionZA:
        return 'Definition Z-A';
      case SortOption.srsLevel:
        return 'SRS Level';
      case SortOption.learningPercentage:
        return 'Learning Progress';
      case SortOption.learningPercentageLowHigh:
        return 'Learning Progress (Low-High)';
      case SortOption.dateCreated:
        return 'Date Created (Recent)';
      case SortOption.dateCreatedOldestFirst:
        return 'Date Created (Oldest)';
      case SortOption.lastModified:
        return 'Last Modified';
    }
  }

  IconData _getSortIcon(SortOption option) {
    switch (option) {
      case SortOption.wordAZ:
        return Icons.arrow_upward;
      case SortOption.wordZA:
        return Icons.arrow_downward;
      case SortOption.definitionAZ:
        return Icons.arrow_upward;
      case SortOption.definitionZA:
        return Icons.arrow_downward;
      case SortOption.srsLevel:
        return Icons.timeline;
      case SortOption.learningPercentage:
        return Icons.trending_up;
      case SortOption.learningPercentageLowHigh:
        return Icons.trending_down;
      case SortOption.dateCreated:
        return Icons.keyboard_arrow_up;
      case SortOption.dateCreatedOldestFirst:
        return Icons.keyboard_arrow_down;
      case SortOption.lastModified:
        return Icons.update;
    }
  }

  String _getDeckNames(FlashCard card, FlashcardProvider provider) {
    final deckNames = card.deckIds.map((deckId) {
      final deck = provider.getDeck(deckId);
      return deck?.name ?? 'Unknown Deck';
    }).toList();
    
    if (deckNames.isEmpty) return 'Uncategorized';
    if (deckNames.length == 1) return deckNames.first;
    return '${deckNames.first} +${deckNames.length - 1} more';
  }

  String _getNextReviewText(FlashCard card) {
    if (card.isDueForReview) {
      return 'Due now';
    }
    
    final nextReview = card.nextReviewDate;
    if (nextReview == null) {
      return 'No review scheduled';
    }
    
    final now = DateTime.now();
    final difference = nextReview.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else {
      return '${difference.inMinutes} min${difference.inMinutes == 1 ? '' : 's'}';
    }
  }

  List<FlashCard> _getFilteredAndSortedCards(FlashcardProvider provider) {
    // Performance optimization: Use cached results if search and sort haven't changed
    if (_cachedFilteredCards != null && 
        _lastSearchQuery == _searchQuery && 
        _lastSortOption == _sortOption) {
      return _cachedFilteredCards!;
    }
    
    var cards = List<FlashCard>.from(provider.cards);
    
    // Remove duplicates by ID to prevent crashes
    final seenIds = <String>{};
    cards = cards.where((card) {
      if (seenIds.contains(card.id)) {
        print('🔍 AllCardsView: Removing duplicate card with ID: ${card.id}');
        return false;
      }
      seenIds.add(card.id);
      return true;
    }).toList();
    
    print('AllCardsView: Total cards in provider: ${provider.cards.length}');
    print('AllCardsView: Cards after deduplication: ${cards.length}');

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final searchLower = _searchQuery.toLowerCase();
      cards = cards.where((card) {
        try {
          return card.word.toLowerCase().contains(searchLower) ||
                 card.definition.toLowerCase().contains(searchLower) ||
                 (card.example.isNotEmpty && card.example.toLowerCase().contains(searchLower));
        } catch (e) {
          print('🔍 AllCardsView: Error filtering card ${card.id}: $e');
          return false;
        }
      }).toList();
      print('AllCardsView: Cards after search filter: ${cards.length}');
    }

    // Sort cards
    try {
      switch (_sortOption) {
        case SortOption.wordAZ:
          cards.sort((a, b) => a.word.compareTo(b.word));
          break;
        case SortOption.wordZA:
          cards.sort((a, b) => b.word.compareTo(a.word));
          break;
        case SortOption.definitionAZ:
          cards.sort((a, b) => a.definition.compareTo(b.definition));
          break;
        case SortOption.definitionZA:
          cards.sort((a, b) => b.definition.compareTo(a.definition));
          break;
        case SortOption.srsLevel:
          cards.sort((a, b) => b.srsLevel.compareTo(a.srsLevel));
          break;
        case SortOption.learningPercentage:
          cards.sort((a, b) => (b.learningPercentage ?? 0).compareTo(a.learningPercentage ?? 0));
          break;
        case SortOption.learningPercentageLowHigh:
          cards.sort((a, b) => (a.learningPercentage ?? 0).compareTo(b.learningPercentage ?? 0));
          break;
        case SortOption.dateCreated:
          cards.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
          break;
        case SortOption.dateCreatedOldestFirst:
          cards.sort((a, b) => a.dateCreated.compareTo(b.dateCreated));
          break;
        case SortOption.lastModified:
          cards.sort((a, b) => b.lastModified.compareTo(a.lastModified));
          break;
      }
    } catch (e) {
      print('🔍 AllCardsView: Error sorting cards: $e');
    }

    print('AllCardsView: Final cards to display: ${cards.length}');
    
    // Cache the results
    _cachedFilteredCards = cards;
    _lastSearchQuery = _searchQuery;
    _lastSortOption = _sortOption;
    
    return cards;
  }

  void _toggleCardSelection(String cardId) {
    print('Toggling selection for card: $cardId');
    setState(() {
      if (_selectedCardIds.contains(cardId)) {
        _selectedCardIds.remove(cardId);
        _selectAll = false;
        print('Removed card $cardId from selection. Selected: $_selectedCardIds');
      } else {
        _selectedCardIds.add(cardId);
        // Check if all cards are now selected
        final provider = context.read<FlashcardProvider>();
        final cards = _getFilteredAndSortedCards(provider);
        _selectAll = _selectedCardIds.length == cards.length;
        print('Added card $cardId to selection. Selected: $_selectedCardIds');
      }
    });
  }

  void _handleCardAction(String action, FlashCard card, FlashcardProvider provider) {
    try {
      switch (action) {
        case 'edit':
          _editCard(card);
          break;
        case 'delete':
          _showDeleteCardConfirmation(card, provider);
          break;
        case 'reset':
          _resetCardProgress(card, provider);
          break;
      }
    } catch (e) {
      print('🔍 AllCardsView: Error handling card action $action: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editSelectedCard() {
    try {
      final provider = context.read<FlashcardProvider>();
      final cardId = _selectedCardIds.first;
      final card = provider.cards.firstWhere((c) => c.id == cardId);
      _editCard(card);
    } catch (e) {
      print('🔍 AllCardsView: Error editing selected card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding card to edit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editCard(FlashCard card) {
    try {
      // Get the fresh card data from the provider to ensure we have the latest version
      final provider = context.read<FlashcardProvider>();
      final freshCard = provider.cards.firstWhere((c) => c.id == card.id);
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddCardView(
            cardToEdit: freshCard,
          ),
        ),
      ).then((result) {
        // Refresh the UI if card was updated
        if (result == true) {
          setState(() {
            // Clear cache to force refresh of filtered results
            _cachedFilteredCards = null;
          });
        }
      });
    } catch (e) {
      print('🔍 AllCardsView: Error navigating to edit card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening edit screen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cards'),
        content: Text(
          'Are you sure you want to delete ${_selectedCardIds.length} card${_selectedCardIds.length == 1 ? '' : 's'}? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteSelectedCards();
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCardConfirmation(FlashCard card, FlashcardProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text(
          'Are you sure you want to delete "${card.word}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteCard(card, provider);
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteSelectedCards() async {
    final provider = context.read<FlashcardProvider>();
    int successCount = 0;
    int errorCount = 0;
    
    for (final cardId in _selectedCardIds) {
      try {
        // Get the card first to get the word
        final card = provider.getCard(cardId);
        if (card == null) {
          print('🔍 AllCardsView: Card not found: $cardId');
          errorCount++;
          continue;
        }
        
        final success = await provider.deleteCard(cardId);
        if (success) {
          successCount++;
        } else {
          errorCount++;
        }
      } catch (e) {
        print('🔍 AllCardsView: Error deleting card $cardId: $e');
        errorCount++;
      }
    }
    
    setState(() {
      _isSelectionMode = false;
      _selectedCardIds.clear();
      _selectAll = false;
    });
    
    // Clear cache after deletion
    _cachedFilteredCards = null;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted $successCount card${successCount == 1 ? '' : 's'}'
            '${errorCount > 0 ? ' ($errorCount failed)' : ''}',
          ),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  void _deleteCard(FlashCard card, FlashcardProvider provider) async {
    print('AllCardsView: Deleting card: ${card.word} (${card.id})');
    try {
      // First delete the card
      final success = await provider.deleteCard(card.id);
      print('AllCardsView: Delete result: $success');
      
      // Also delete any exercises for this word
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted card: ${card.word}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete card: ${card.word}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('🔍 AllCardsView: Error deleting card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting card: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetCardProgress(FlashCard card, FlashcardProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: Text(
          'Are you sure you want to reset the learning progress for "${card.word}"? '
          'This will reset SRS level, success count, and learning mastery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final resetCard = card.copyWith(
                  successCount: 0,
                  learningMastery: LearningMastery(),
                );
                await provider.updateCard(resetCard);
                
                // Clear cache after update
                _cachedFilteredCards = null;
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Reset progress for: ${card.word}')),
                  );
                }
              } catch (e) {
                print('🔍 AllCardsView: Error resetting card progress: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error resetting progress: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showCardDetails(FlashCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: CardDetailsDialog(card: card),
      ),
    );
  }

  void _addNewCard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddCardView(),
      ),
    );
  }

  void _selectAllCards() {
    final provider = context.read<FlashcardProvider>();
    final cards = _getFilteredAndSortedCards(provider);
    setState(() {
      _selectedCardIds = cards.map((card) => card.id).toSet();
      _selectAll = true;
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedCardIds.clear();
      _selectAll = false;
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('MMM dd').format(date);
    }
  }

  void _addSearchedWord() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCardView(
          preFilledWord: _searchQuery,
        ),
      ),
    ).then((result) {
      // Refresh the search results if a card was added
      if (result == true) {
        setState(() {
          // Clear cache to force refresh
          _cachedFilteredCards = null;
        });
      }
    });
  }

  void _showSelectionMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Card Selection Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.select_all, color: Colors.black),
              title: const Text('Select All'),
              subtitle: const Text('Select all cards in the current view'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isSelectionMode = true;
                  _enteredViaSelectAll = true;
                });
                _selectAllCards();
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist, color: Colors.green),
              title: const Text('Manual Selection'),
              subtitle: const Text('Select individual cards by tapping them'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isSelectionMode = true;
                  _enteredViaSelectAll = false;
                });
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  void _showBulkActionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bulk Actions (${_selectedCardIds.length} selected)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedCardIds.length == 1)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.black),
                title: const Text('Edit Selected Card'),
                subtitle: const Text('Edit the selected card'),
                onTap: () {
                  Navigator.pop(context);
                  _editSelectedCard();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Selected Cards'),
              subtitle: const Text('Permanently delete all selected cards'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('Reset Progress'),
              subtitle: const Text('Reset learning progress for selected cards'),
              onTap: () {
                Navigator.pop(context);
                _showResetProgressConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move, color: Colors.blue),
              title: const Text('Move/Copy Cards'),
              subtitle: const Text('Move or copy selected cards to another deck'),
              onTap: () {
                Navigator.pop(context);
                _showMoveCopyDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showResetProgressConfirmation() {
    final provider = context.read<FlashcardProvider>();
    final selectedCards = _selectedCardIds.map((id) => provider.getCard(id)).whereType<FlashCard>().toList();
    final cardNames = selectedCards.map((c) => c.word).join(', ');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: Text(
          'Are you sure you want to reset the learning progress for ${_selectedCardIds.length} card(s)?\n\n'
          'This will reset SRS level, success count, and learning mastery for:\n$cardNames\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetSelectedCardsProgress();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reset Progress'),
          ),
        ],
      ),
    );
  }

  void _resetSelectedCardsProgress() async {
    final provider = context.read<FlashcardProvider>();
    int successCount = 0;
    int errorCount = 0;

    for (String cardId in _selectedCardIds) {
      try {
        final card = provider.getCard(cardId);
        if (card != null) {
          final resetCard = card.copyWith(
            successCount: 0,
            learningMastery: LearningMastery(),
          );
          await provider.updateCard(resetCard);
          successCount++;
        } else {
          errorCount++;
        }
      } catch (e) {
        print('🔍 AllCardsView: Error resetting progress for card $cardId: $e');
        errorCount++;
      }
    }

    setState(() {
      _isSelectionMode = false;
      _selectedCardIds.clear();
      _selectAll = false;
    });

    // Clear cache after reset
    _cachedFilteredCards = null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reset progress for $successCount card${successCount == 1 ? '' : 's'}'
            '${errorCount > 0 ? ' ($errorCount failed)' : ''}',
          ),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  Color _getSRSColor(int srsLevel) {
    switch (srsLevel) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.lightGreen;
      default:
        return Colors.green;
    }
  }

  String _getSRSDescription(int srsLevel) {
    switch (srsLevel) {
      case 0:
        return 'New card - never studied';
      case 1:
        return 'Learning phase - review every day';
      case 2:
        return 'Early learning - review every 6 days';
      case 3:
        return 'Mid-learning - review every 15 days';
      case 4:
        return 'Review phase - longer intervals';
      case 5:
        return 'Well learned - review every 2-4 weeks';
      case 6:
        return 'Familiar - review every 1-2 months';
      case 7:
        return 'Very familiar - review every 2-4 months';
      case 8:
        return 'Mastered - review every 4-8 months';
      case 9:
        return 'Expert - review every 6-12 months';
      default:
        return 'Mastered - review every 8+ months';
    }
  }

  void _showMoveCopyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move/Copy Cards'),
        content: const Text(
          'Choose an action for the selected cards:\n\n'
          '• Move: Remove cards from current deck(s) and add to new deck(s)\n'
          '• Copy: Keep cards in current deck(s) and also add to new deck(s)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeckSelectionDialog(isMove: true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Move'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeckSelectionDialog(isMove: false);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _showDeckSelectionDialog({required bool isMove}) {
    final provider = context.read<FlashcardProvider>();
    // Include all decks (main and sub-decks) so users can target any folder
    final availableDecks = provider.decks.toList();
    
    if (availableDecks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No decks available to move/copy cards to'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _DeckSelectionDialog(
        decks: availableDecks,
        isMove: isMove,
        onConfirm: (selectedDeckIds) {
          Navigator.of(context).pop();
          _performMoveCopy(selectedDeckIds, isMove: isMove);
        },
      ),
    );
  }

  Future<void> _performMoveCopy(List<String> targetDeckIds, {required bool isMove}) async {
    final provider = context.read<FlashcardProvider>();
    int successCount = 0;
    int errorCount = 0;
    
    for (final cardId in _selectedCardIds) {
      try {
        final card = provider.getCard(cardId);
        if (card == null) {
          print('🔍 AllCardsView: Card not found: $cardId');
          errorCount++;
          continue;
        }
        
        if (isMove) {
          // Move: Remove from current decks and add to target decks
          final newDeckIds = targetDeckIds.toSet();
          await provider.updateCard(card.copyWith(deckIds: newDeckIds));
        } else {
          // Copy: Add to target decks while keeping current decks
          final newDeckIds = {...card.deckIds, ...targetDeckIds};
          await provider.updateCard(card.copyWith(deckIds: newDeckIds));
        }
        
        successCount++;
      } catch (e) {
        print('🔍 AllCardsView: Error ${isMove ? 'moving' : 'copying'} card $cardId: $e');
        errorCount++;
      }
    }
    
    setState(() {
      _isSelectionMode = false;
      _selectedCardIds.clear();
      _selectAll = false;
    });
    
    // Clear cache after operation
    _cachedFilteredCards = null;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isMove ? 'Moved' : 'Copied'} $successCount card${successCount == 1 ? '' : 's'}'
            '${errorCount > 0 ? ' ($errorCount failed)' : ''}',
          ),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

}

class _DeckSelectionDialog extends StatefulWidget {
  final List<Deck> decks;
  final bool isMove;
  final Function(List<String>) onConfirm;

  const _DeckSelectionDialog({
    required this.decks,
    required this.isMove,
    required this.onConfirm,
  });

  @override
  State<_DeckSelectionDialog> createState() => _DeckSelectionDialogState();
}

class _DeckSelectionDialogState extends State<_DeckSelectionDialog> {
  final Set<String> _selectedDeckIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Deck${widget.decks.length > 1 ? 's' : ''} to ${widget.isMove ? 'Move' : 'Copy'} To'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: widget.decks.length,
          itemBuilder: (context, index) {
            final deck = widget.decks[index];
            final isSelected = _selectedDeckIds.contains(deck.id);
            
            return CheckboxListTile(
              title: Text(deck.name),
              subtitle: Text('${context.read<FlashcardProvider>().getCardsForDeck(deck.id).length} cards'),
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedDeckIds.add(deck.id);
                  } else {
                    _selectedDeckIds.remove(deck.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _selectedDeckIds.isEmpty 
              ? null 
              : () => widget.onConfirm(_selectedDeckIds.toList()),
          style: TextButton.styleFrom(
            foregroundColor: widget.isMove ? Colors.blue : Colors.green,
          ),
          child: Text('${widget.isMove ? 'Move' : 'Copy'} to ${_selectedDeckIds.length} deck${_selectedDeckIds.length == 1 ? '' : 's'}'),
        ),
      ],
    );
  }
} 