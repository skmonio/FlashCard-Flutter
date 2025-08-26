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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
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
            TextButton(
              onPressed: _selectAll ? _deselectAll : _selectAllCards,
              child: Text(_selectAll ? 'Deselect All' : 'Select All'),
            ),
            if (_selectedCardIds.isNotEmpty) ...[
              TextButton(
                onPressed: _selectedCardIds.length == 1 ? _editSelectedCard : null,
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: _showDeleteConfirmation,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedCardIds.clear();
                  _selectAll = false;
                });
              },
              child: const Text('Cancel'),
            ),
          ] else ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
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
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),
          // Sort options
          Row(
            children: [
              const Text('Sort by: '),
              Expanded(
                child: DropdownButton<SortOption>(
                  value: _sortOption,
                  isExpanded: true,
                  items: SortOption.values.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(_getSortOptionText(option)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortOption = value;
                      });
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: _showSortInfo,
                icon: const Icon(Icons.info_outline),
                tooltip: 'Sort Info',
              ),
            ],
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
                Expanded(
                  child: Text(
                    card.word,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (card.article.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      card.article,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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
                    Icon(Icons.timeline, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'SRS Level ${card.srsLevel}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _getNextReviewText(card),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddCardView(
            cardToEdit: card,
          ),
        ),
      );
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(card.word),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (card.article.isNotEmpty) ...[
                Text('Article: ${card.article}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
              ],
              Text('Definition: ${card.definition}'),
              if (card.example.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Example: ${card.example}'),
              ],
              if (card.exampleTranslation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Translation: ${card.exampleTranslation}', style: TextStyle(color: Colors.grey[600])),
              ],
              if (card.plural.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Plural: ${card.plural}'),
              ],
              if (card.pastTense.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Past Tense: ${card.pastTense}'),
              ],
              if (card.futureTense.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Future Tense: ${card.futureTense}'),
              ],
              if (card.pastParticiple.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Past Participle: ${card.pastParticiple}'),
              ],
              const SizedBox(height: 16),
              Text('SRS Level: ${card.srsLevel}'),
              Text('Learning Progress: ${card.learningPercentage}%'),
              Text('Success Count: ${card.successCount}'),
              Text('Created: ${DateFormat('MMM dd, yyyy').format(card.dateCreated)}'),
              Text('Last Modified: ${DateFormat('MMM dd, yyyy').format(card.lastModified)}'),
            ],
          ),
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

  void _showSortInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Options'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Word (A-Z/Z-A): Sort alphabetically by word'),
            SizedBox(height: 8),
            Text('• Definition (A-Z/Z-A): Sort alphabetically by definition'),
            SizedBox(height: 8),
            Text('• SRS Level: Sort by spaced repetition level'),
            SizedBox(height: 8),
            Text('• Learning Progress: Sort by learning percentage'),
            SizedBox(height: 8),
            Text('• Date Created: Sort by creation date'),
            SizedBox(height: 8),
            Text('• Last Modified: Sort by last modification date'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
} 