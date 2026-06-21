import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/flashcard_provider.dart';
import '../models/deck.dart';
import '../models/flash_card.dart';
import '../services/xp_service.dart';
import '../components/hp_bar.dart';
import '../components/card_details_dialog.dart';
import 'add_card_view.dart';
import '../components/universal_add_button.dart';
import 'all_cards_view.dart'; // Import for SortOption enum
import 'study_type_selection_view.dart';

class DeckDetailView extends StatefulWidget {
  final Deck deck;
  
  const DeckDetailView({
    super.key,
    required this.deck,
  });

  @override
  State<DeckDetailView> createState() => _DeckDetailViewState();
}

class _DeckDetailViewState extends State<DeckDetailView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _sortOption = SortOption.wordAZ; // Changed from String to SortOption
  bool _showOnlyParentCards = false; // Track whether to show only parent deck cards
  
  // Selection mode variables
  bool _isSelectionMode = false;
  Set<String> _selectedCardIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              child: _buildCustomHeader(context),
            ),
          ),
          
          // Search and Sort
          _buildSearchAndSort(),
          
          // Cards List
          Expanded(
            child: Consumer<FlashcardProvider>(
              builder: (context, provider, child) {
                final cards = _getFilteredAndSortedCards(provider);
                
                if (cards.isEmpty) {
                  return _buildEmptyState();
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        '${cards.length} Cards',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: cards.length,
                        itemBuilder: (context, index) {
                          return _buildCardItem(cards[index], provider);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Selection Footer
          if (_isSelectionMode) _buildSelectionFooter(),
        ],
      ),
      floatingActionButton: UniversalAddButton(
        initialDeckId: widget.deck.id,
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search and Sort Row
          Row(
            children: [
              // Search Bar
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search cards...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
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
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: SortOption.wordAZ,
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_upward),
                        const SizedBox(width: 8),
                        const Text('A-Z'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.wordZA,
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_downward),
                        const SizedBox(width: 8),
                        const Text('Z-A'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.definitionAZ,
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_upward),
                        const SizedBox(width: 8),
                        const Text('Definition A-Z'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.definitionZA,
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_downward),
                        const SizedBox(width: 8),
                        const Text('Definition Z-A'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.dateCreated,
                    child: Row(
                      children: [
                        const Icon(Icons.keyboard_arrow_up),
                        const SizedBox(width: 8),
                        const Text('Date Added (Recent)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.dateCreatedOldestFirst,
                    child: Row(
                      children: [
                        const Icon(Icons.keyboard_arrow_down),
                        const SizedBox(width: 8),
                        const Text('Date Added (Oldest)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.srsLevel,
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up),
                        const SizedBox(width: 8),
                        const Text('SRS Level'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.learningPercentage,
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up),
                        const SizedBox(width: 8),
                        const Text('Learning % High-Low'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.learningPercentageLowHigh,
                    child: Row(
                      children: [
                        const Icon(Icons.trending_down),
                        const SizedBox(width: 8),
                        const Text('Learning % Low-High'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.lastModified,
                    child: Row(
                      children: [
                        const Icon(Icons.access_time),
                        const SizedBox(width: 8),
                        const Text('Last Modified'),
                      ],
                    ),
                  ),
                ],
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
          
          // View Mode Toggle (only for parent decks with sub-decks)
          if (!widget.deck.isSubDeck && context.read<FlashcardProvider>().getSubDecks(widget.deck.id).isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'View: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 8),
                _buildViewModeChip('all', 'All Cards', !_showOnlyParentCards),
                const SizedBox(width: 8),
                _buildViewModeChip('parent', 'Parent Only', _showOnlyParentCards),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViewModeChip(String value, String label, bool isSelected) {
    Widget chip = FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _showOnlyParentCards = value == 'parent';
        });
      },
    );
    
    return chip;
  }
  
  IconData _getSortIcon(SortOption sortOption) {
    switch (sortOption) {
      case SortOption.wordAZ:
      case SortOption.definitionAZ:
        return Icons.arrow_upward;
      case SortOption.wordZA:
      case SortOption.definitionZA:
        return Icons.arrow_downward;
      case SortOption.dateCreated:
      case SortOption.dateCreatedOldestFirst:
        return Icons.access_time;
      case SortOption.lastModified:
      case SortOption.srsLevel:
      case SortOption.learningPercentage:
      case SortOption.learningPercentageLowHigh:
        return Icons.trending_up;
    }
  }

  String _getSortOptionText(SortOption sortOption) {
    switch (sortOption) {
      case SortOption.wordAZ:
        return 'A-Z';
      case SortOption.wordZA:
        return 'Z-A';
      case SortOption.definitionAZ:
        return 'Definition A-Z';
      case SortOption.definitionZA:
        return 'Definition Z-A';
      case SortOption.dateCreated:
        return 'Date Added (Recent)';
      case SortOption.dateCreatedOldestFirst:
        return 'Date Added (Oldest)';
      case SortOption.srsLevel:
        return 'SRS Level';
      case SortOption.learningPercentage:
        return 'Learning %';
      case SortOption.learningPercentageLowHigh:
        return 'Learning % (Low-High)';
      case SortOption.lastModified:
        return 'Last Modified';
    }
  }

  Widget _buildEmptyState() {
    final provider = context.read<FlashcardProvider>();
    final hasSearchQuery = _searchQuery.isNotEmpty;
    final allCards = widget.deck.isSubDeck
        ? provider.getCardsForDeck(widget.deck.id)
        : provider.getCardsForDeckWithSubDecks(widget.deck.id);
    final hasCardsInDeck = allCards.isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearchQuery ? Icons.search_off : Icons.folder_open,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearchQuery
                ? 'This card does not exist in this deck'
                : 'No cards in this deck',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearchQuery
                ? 'Tap the button below to add "${_searchQuery}" to this deck'
                : 'Tap the + button to add your first card',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addCardToDeck(preFilledWord: hasSearchQuery ? _searchQuery : null),
            icon: const Icon(Icons.add),
            label: Text(hasSearchQuery ? 'Add This Card' : 'Add First Card'),
          ),
        ],
      ),
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
            onPressed: _exitSelectionMode,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
          
          const Spacer(),
          
          // Select All Toggle
          TextButton.icon(
            onPressed: () {
              setState(() {
                if (_selectedCardIds.length == _getFilteredAndSortedCards(context.read<FlashcardProvider>()).length) {
                  _selectedCardIds.clear();
                } else {
                  final provider = context.read<FlashcardProvider>();
                  final cards = _getFilteredAndSortedCards(provider);
                  _selectedCardIds = cards.map((card) => card.id).toSet();
                }
              });
            },
            icon: Icon(_selectedCardIds.length == _getFilteredAndSortedCards(context.read<FlashcardProvider>()).length 
                ? Icons.check_box 
                : Icons.check_box_outline_blank),
            label: Text(_selectedCardIds.length == _getFilteredAndSortedCards(context.read<FlashcardProvider>()).length 
                ? 'Deselect All' 
                : 'Select All'),
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

  Widget _buildCardItem(FlashCard card, FlashcardProvider provider) {
    final isSelected = _selectedCardIds.contains(card.id);
    
    return Card(
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
            leading: _isSelectionMode 
              ? Checkbox(
                  value: isSelected,
                  onChanged: (value) => _toggleCardSelection(card.id),
                )
              : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      '${card.learningPercentage}%',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
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
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: card.hasReachedDailyLimit 
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          card.hasReachedDailyLimit 
                              ? 'Daily limit reached'
                              : '${card.currentHP}/${card.maxHP} HP',
                          style: TextStyle(
                            fontSize: 10,
                            color: card.hasReachedDailyLimit
                                ? Colors.orange[700]
                                : card.isDefeated 
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
                ),
              ],
            ),
            trailing: _isSelectionMode ? null : PopupMenuButton<String>(
              onSelected: (value) => _handleCardAction(value, card),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(FlashCard card) {
    return Expanded(
      child: LinearProgressIndicator(
        value: (card.learningPercentage ?? 0).toDouble(),
        backgroundColor: Colors.grey.withValues(alpha: 0.2),
        valueColor: AlwaysStoppedAnimation<Color>(_getSRSColor(card.srsLevel)),
      ),
    );
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

  List<FlashCard> _getFilteredAndSortedCards(FlashcardProvider provider) {
    // Get cards based on the current view mode
    List<FlashCard> cards;
    if (widget.deck.isSubDeck) {
      // For sub-decks, always show only their own cards
      cards = provider.getCardsForDeck(widget.deck.id);
    } else {
      // For parent decks, show either only parent cards or all cards including sub-decks
      cards = _showOnlyParentCards 
          ? provider.getCardsForDeck(widget.deck.id)
          : provider.getCardsForDeckWithSubDecks(widget.deck.id);
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      cards = cards.where((card) =>
        card.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        card.definition.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        card.example.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Sort cards
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
      case SortOption.dateCreated:
        cards.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
        break;
      case SortOption.dateCreatedOldestFirst:
        cards.sort((a, b) => a.dateCreated.compareTo(b.dateCreated));
        break;
      case SortOption.srsLevel:
        cards.sort((a, b) => a.srsLevel.compareTo(b.srsLevel));
        break;
      case SortOption.learningPercentage:
        cards.sort((a, b) => (b.learningPercentage ?? 0).compareTo(a.learningPercentage ?? 0));
        break;
      case SortOption.learningPercentageLowHigh:
        cards.sort((a, b) => (a.learningPercentage ?? 0).compareTo(b.learningPercentage ?? 0));
        break;
      case SortOption.lastModified:
        cards.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
    }

    return cards;
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _editDeck();
        break;
      case 'study':
        _studyDeck();
        break;
      case 'toggle_public':
        _toggleDeckPublicStatus();
        break;
      case 'delete':
        _deleteDeck();
        break;
    }
  }

  void _handleCardAction(String action, FlashCard card) {
    switch (action) {
      case 'edit':
        _editCard(card);
        break;
      case 'delete':
        _deleteCard(card);
        break;
      case 'study':
        // Study case removed as exercises are now part of regular games
        break;
    }
  }

  void _addCardToDeck({String? preFilledWord}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCardView(
          selectedDeck: widget.deck,
          preFilledWord: preFilledWord,
        ),
      ),
    );
  }

  void _editDeck() {
    final nameController = TextEditingController(text: widget.deck.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Deck'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Deck Name',
            hintText: 'Enter deck name...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final navigator = Navigator.of(context);
                final provider = context.read<FlashcardProvider>();
                                 final updatedDeck = widget.deck.copyWith(name: nameController.text.trim());
                 await provider.updateDeck(updatedDeck);
                if (mounted) {
                  navigator.pop();
                  setState(() {}); // Refresh the UI
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }


  void _studyDeck() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudyTypeSelectionView(
          gameMode: GameMode.study,
          initialDeckId: widget.deck.id,
        ),
      ),
    );
  }


  void _toggleDeckPublicStatus() async {
    try {
      final provider = context.read<FlashcardProvider>();
      final freshDeck = provider.getDeck(widget.deck.id) ?? widget.deck;
      await provider.updateDeckPublicStatus(widget.deck.id, !freshDeck.isPublic);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              freshDeck.isPublic 
                ? 'Deck and all cards made private' 
                : 'Deck and all cards made public'
            ),
            backgroundColor: freshDeck.isPublic ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update deck: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteDeck() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete "${widget.deck.name}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red, size: 16),
                      SizedBox(width: 6),
                      Text('This cannot be undone', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text('• All cards exclusive to this deck will be permanently deleted', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('• All study history (XP, progress, streaks) for those cards will be lost', style: TextStyle(fontSize: 12)),
                ],
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
              final navigator = Navigator.of(context);
              final provider = context.read<FlashcardProvider>();
              await provider.deleteDeck(widget.deck.id);
              if (mounted) {
                navigator.pop();
                Navigator.of(context).pop(); // Go back to cards view
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _editCard(FlashCard card) {
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
          // Trigger rebuild to show updated card information
        });
      }
    });
  }

  void _deleteCard(FlashCard card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text(
          'Are you sure you want to delete "${card.word}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final provider = context.read<FlashcardProvider>();
              
              // Delete the card
              await provider.deleteCard(card.id);
              
              if (mounted) {
                navigator.pop();
                setState(() {}); // Refresh the list
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }



  // Removed _studyCard method as exercises are replaced by games

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


  String _formatDate(DateTime date) {
    return DateFormat('MM/dd/yyyy').format(date);
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            widget.deck.name,
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
        
        // Right side - Home button
        Positioned(
          right: 56, // Positioned to the left of the menu button
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        
        // Right side - Menu button
        Positioned(
          right: 16, // Add proper padding from right edge
          top: 0,
          bottom: 0,
          child: PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Edit Deck'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_public',
                child: Row(
                  children: [
                    Icon(
                      widget.deck.isPublic ? Icons.visibility_off : Icons.visibility,
                      color: widget.deck.isPublic ? Colors.orange : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.deck.isPublic ? 'Make Private' : 'Make Public',
                      style: TextStyle(
                        color: widget.deck.isPublic ? Colors.orange : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Deck', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

  // Selection mode helper methods
  void _toggleCardSelection(String cardId) {
    setState(() {
      if (_selectedCardIds.contains(cardId)) {
        _selectedCardIds.remove(cardId);
        if (_selectedCardIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedCardIds.add(cardId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedCardIds.clear();
    });
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

  void _editSelectedCard() {
    try {
      final provider = context.read<FlashcardProvider>();
      final cardId = _selectedCardIds.first;
      final card = provider.getCard(cardId);
      if (card != null) {
        _editCard(card);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding card to edit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation() {
    final provider = context.read<FlashcardProvider>();
    final selectedCards = _selectedCardIds.map((id) => provider.getCard(id)).whereType<FlashCard>().toList();
    final cardNames = selectedCards.map((c) => c.word).join(', ');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cards'),
        content: Text(
          'Are you sure you want to delete ${_selectedCardIds.length} card(s)?\n\n'
          'This will permanently delete:\n$cardNames\n\n'
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
              _deleteSelectedCards();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

    for (String cardId in _selectedCardIds) {
      try {
        await provider.deleteCard(cardId);
        successCount++;
      } catch (e) {
        errorCount++;
        print('Error deleting card $cardId: $e');
      }
    }

    setState(() {
      _isSelectionMode = false;
      _selectedCardIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $successCount card(s)${errorCount > 0 ? ', $errorCount failed' : ''}'),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
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
            learningMastery: card.learningMastery.copyWith(
              srsLevel: 0,
              easyCorrect: 0,
              mediumCorrect: 0,
              hardCorrect: 0,
              expertCorrect: 0,
              easyAttempts: 0,
              mediumAttempts: 0,
              hardAttempts: 0,
              expertAttempts: 0,
              consecutiveCorrect: 0,
              consecutiveIncorrect: 0,
              lastReviewDate: null,
              nextReviewDate: null,
              exerciseHistory: [],
              currentXP: 0,
              currentLevel: 0,
              repetitions: 0,
              lapses: 0,
              interval: 1,
            ),
          );
          await provider.updateCard(resetCard);
          successCount++;
        }
      } catch (e) {
        errorCount++;
        print('Error resetting card $cardId: $e');
      }
    }

    setState(() {
      _isSelectionMode = false;
      _selectedCardIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset progress for $successCount card(s)${errorCount > 0 ? ', $errorCount failed' : ''}'),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  void _showMoveCopyDialog() {
    final provider = context.read<FlashcardProvider>();
    // Include all decks except the current one
    final availableDecks = provider.decks.where((d) => d.id != widget.deck.id).toList();

    if (availableDecks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No decks available to move/copy cards to'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Move/Copy Cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.drive_file_move),
                        label: const Text('Move'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showDeckSelectionDialog(isMove: true);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showDeckSelectionDialog(isMove: false);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Choose Move to replace current decks, or Copy to add to decks.')
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeckSelectionDialog({required bool isMove}) {
    final provider = context.read<FlashcardProvider>();
    final availableDecks = provider.decks.where((d) => d.id != widget.deck.id).toList();

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
          errorCount++;
          continue;
        }

        if (isMove) {
          final newDeckIds = targetDeckIds.toSet();
          await provider.updateCard(card.copyWith(deckIds: newDeckIds));
        } else {
          final newDeckIds = {...card.deckIds, ...targetDeckIds};
          await provider.updateCard(card.copyWith(deckIds: newDeckIds));
        }

        successCount++;
      } catch (e) {
        errorCount++;
      }
    }

    setState(() {
      _isSelectionMode = false;
      _selectedCardIds.clear();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${isMove ? 'Moved' : 'Copied'} $successCount card(s)${errorCount > 0 ? ', $errorCount failed' : ''}'),
        backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
      ),
    );
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
        height: 360,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
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
          onPressed: _selectedDeckIds.isEmpty ? null : () => widget.onConfirm(_selectedDeckIds.toList()),
          style: TextButton.styleFrom(
            foregroundColor: widget.isMove ? Colors.blue : Colors.green,
          ),
          child: Text('${widget.isMove ? "Move" : "Copy"} to ${_selectedDeckIds.length} deck${_selectedDeckIds.length == 1 ? '' : 's'}'),
        ),
      ],
    );
  }
} 