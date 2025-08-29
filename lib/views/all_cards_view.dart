import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../models/flash_card.dart';
import '../models/dutch_word_exercise.dart';
import '../models/learning_mastery.dart';
import '../services/xp_service.dart';

import 'dutch_word_exercise_detail_view.dart';
import 'create_word_exercise_view.dart';
import 'add_card_view.dart';
import 'dart:async'; // Added for Timer

enum SortOption {
  wordAZ,
  wordZA,
  definitionAZ,
  definitionZA,
  srsLevel,
  learningPercentage,
  dateCreated,
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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    
    // Add listener to refresh when provider updates
    final provider = context.read<FlashcardProvider>();
    provider.addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    
    // Remove listener when disposing
    final provider = context.read<FlashcardProvider>();
    provider.removeListener(_onProviderChanged);
    
    super.dispose();
  }

  void _onProviderChanged() {
    // Refresh the UI when cards are updated
    if (mounted) {
      setState(() {
        // Clear cache to force refresh of filtered results
        _cachedFilteredCards = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewCard(),
        tooltip: 'Add New Card',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Header
          SafeArea(
            child: _buildHeader(context),
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
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cards.length,
                  // Performance optimization: Add key for better widget recycling
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return _buildCardItem(card, provider, key: ValueKey(card.id));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              'All Cards',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isSelectionMode) ...[
            if (_selectedCardIds.isNotEmpty)
              IconButton(
                onPressed: _showBulkActionsMenu,
                icon: const Icon(Icons.more_vert),
              ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedCardIds.clear();
                  _selectAll = false;
                  _enteredViaSelectAll = false;
                });
              },
              child: const Text('Cancel'),
            ),
          ] else ...[
            IconButton(
              onPressed: _showSelectionMenu,
              icon: const Icon(Icons.select_all),
              tooltip: 'Select Cards',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardItem(FlashCard card, FlashcardProvider provider, {Key? key}) {
    final isSelected = _selectedCardIds.contains(card.id);
    
    return Card(
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
              ],
            ),
            title: Row(
              children: [
                Text(
                  card.article.isNotEmpty ? '${card.article} ' : '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    card.word,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            subtitle: Consumer<DutchWordExerciseProvider>(
              builder: (context, dutchProvider, child) {
                final existingExercise = dutchProvider.getWordExerciseByWord(card.word);
                final exerciseCount = existingExercise?.exercises.length ?? 0;
                
                return Column(
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
                        Text(
                          'Added: ${_formatDate(card.dateCreated)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        if (exerciseCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
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
                PopupMenuItem(
                  value: 'edit_exercises',
                  child: Consumer<DutchWordExerciseProvider>(
                    builder: (context, dutchProvider, child) {
                      final existingExercise = dutchProvider.getWordExerciseByWord(card.word);
                      final hasExercises = existingExercise?.exercises.isNotEmpty ?? false;
                      
                      return Row(
                        children: [
                          Icon(hasExercises ? Icons.quiz : Icons.add, size: 16),
                          SizedBox(width: 8),
                          Text(hasExercises ? 'Edit Exercises' : 'Add Exercises'),
                        ],
                      );
                    },
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
                const PopupMenuItem(
                  value: 'study',
                  child: Row(
                    children: [
                      Icon(Icons.school, size: 16),
                      SizedBox(width: 8),
                      Text('Study Card'),
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

  String _getSortOptionText(SortOption option) {
    switch (option) {
      case SortOption.wordAZ:
        return 'Word (A-Z)';
      case SortOption.wordZA:
        return 'Word (Z-A)';
      case SortOption.definitionAZ:
        return 'Definition (A-Z)';
      case SortOption.definitionZA:
        return 'Definition (Z-A)';
      case SortOption.srsLevel:
        return 'SRS Level';
      case SortOption.learningPercentage:
        return 'Learning Progress';
      case SortOption.dateCreated:
        return 'Date Created';
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
      case SortOption.dateCreated:
        return Icons.calendar_today;
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
        case SortOption.dateCreated:
          cards.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
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
        case 'edit_exercises':
          _editExercises(card);
          break;
        case 'delete':
          _showDeleteCardConfirmation(card, provider);
          break;
        case 'reset':
          _resetCardProgress(card, provider);
          break;
        case 'study':
          _studyCard(card);
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
      final success = await provider.deleteCard(card.id);
      print('AllCardsView: Delete result: $success');
      
      // Clear cache after deletion
      _cachedFilteredCards = null;
      
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

  void _editExercises(FlashCard card) {
    try {
      // Check if there's already an existing exercise for this card
      final dutchProvider = context.read<DutchWordExerciseProvider>();
      final existingExercise = dutchProvider.getWordExerciseByWord(card.word);
      
      DutchWordExercise exerciseToEdit;
      
      if (existingExercise != null) {
        // Use existing exercise
        exerciseToEdit = existingExercise;
        print('🔍 AllCardsView: Editing existing exercise for "${card.word}" with ${existingExercise.exercises.length} exercises');
      } else {
        // Create a new exercise if none exists
        exerciseToEdit = DutchWordExercise(
          id: card.id,
          targetWord: card.word,
          wordTranslation: card.definition,
          deckId: card.deckIds.isNotEmpty ? card.deckIds.first : '',
          deckName: card.deckIds.isNotEmpty ? card.deckIds.first : 'Default',
          category: WordCategory.common,
          difficulty: ExerciseDifficulty.beginner,
          exercises: [],
          createdAt: card.dateCreated,
          isUserCreated: true,
        );
        print('🔍 AllCardsView: Creating new exercise for "${card.word}"');
      }
      
      // Navigate to the create word exercise view for this card
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreateWordExerciseView(
            editingExercise: exerciseToEdit,
          ),
        ),
      );
    } catch (e) {
      print('🔍 AllCardsView: Error editing exercises: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening exercises: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _studyCard(FlashCard card) {
    try {
      // Check if there's already an existing exercise for this card
      final dutchProvider = context.read<DutchWordExerciseProvider>();
      final existingExercise = dutchProvider.getWordExerciseByWord(card.word);
      
      if (existingExercise == null || existingExercise.exercises.isEmpty) {
        // Show message that no exercises exist
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No exercises found for "${card.word}". Please add exercises first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Use existing exercise
      print('🔍 AllCardsView: Found existing exercise for "${card.word}" with ${existingExercise.exercises.length} exercises');
      
      // Navigate to the Dutch word exercise detail view for this card
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DutchWordExerciseDetailView(
            wordExercise: existingExercise,
          ),
        ),
      );
    } catch (e) {
      print('🔍 AllCardsView: Error studying card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening study mode: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCardDetails(FlashCard card) {
    // Get the fresh card data from the provider to ensure we have the latest XP and learning progress
    final provider = context.read<FlashcardProvider>();
    final freshCard = provider.getCard(card.id) ?? card;
    
    final xpService = XpService();
    final wordLevel = freshCard.learningMastery.rpgWordLevel;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(
              freshCard.article.isNotEmpty ? '${freshCard.article} ' : '',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(child: Text(freshCard.word)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              freshCard.definition,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.folder_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Decks: ${_getDeckNames(freshCard, provider)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (freshCard.example.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Example:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                freshCard.example,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              if (freshCard.exampleTranslation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  freshCard.exampleTranslation,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
            if (freshCard.plural.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Plural: ${freshCard.plural}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),
            
            // Card Level and XP Section
            Row(
              children: [
                Text(
                  'Card Level: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  xpService.getLevelIcon(wordLevel),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  'Level ${wordLevel.level} (${wordLevel.title})',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Current XP: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '${freshCard.learningMastery.currentXPWithDecay}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Learning Progress: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '${freshCard.learningPercentage}%',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'SRS Level: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '${freshCard.srsLevel}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Next Review: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: Text(
                    _getNextReviewText(freshCard),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Success Count: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '${freshCard.successCount}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Created: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(freshCard.dateCreated),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Last Modified: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(freshCard.lastModified),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _editCard(card);
            },
            child: const Text('Edit'),
          ),
        ],
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
              leading: const Icon(Icons.select_all, color: Colors.blue),
              title: const Text('Select All Cards'),
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
                leading: const Icon(Icons.edit, color: Colors.blue),
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

} 