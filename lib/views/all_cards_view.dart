import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../models/flash_card.dart';
import '../models/dutch_word_exercise.dart';
import '../models/learning_mastery.dart';
import 'dutch_word_exercise_detail_view.dart';
import 'create_word_exercise_view.dart';
import 'add_card_view.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
                final cards = _getFilteredAndSortedCards(provider);
                
                if (cards.isEmpty) {
                  return _buildEmptyState();
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    return _buildCardItem(cards[index], provider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No cards found',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or add some cards',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
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
                    // Deck information
                    Consumer<FlashcardProvider>(
                      builder: (context, flashcardProvider, child) {
                        final deckNames = flashcardProvider.getDeckNamesForCard(card);
                        if (deckNames.isNotEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: deckNames.map((deckName) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    deckName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )).toList(),
                              ),
                              const SizedBox(height: 4),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
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
                      Icon(Icons.quiz, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Study This Card', style: TextStyle(color: Colors.green)),
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
        value: card.learningPercentage / 100.0,
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
    var cards = List<FlashCard>.from(provider.cards);
    
    print('AllCardsView: Total cards in provider: ${provider.cards.length}');
    print('AllCardsView: Cards after copy: ${cards.length}');

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      cards = cards.where((card) =>
        card.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        card.definition.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        card.example.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
      print('AllCardsView: Cards after search filter: ${cards.length}');
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

    print('AllCardsView: Final cards to display: ${cards.length}');
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
  }

  void _editSelectedCard() {
    final provider = context.read<FlashcardProvider>();
    final cardId = _selectedCardIds.first;
    final card = provider.cards.firstWhere((c) => c.id == cardId);
    _editCard(card);
  }

  void _editCard(FlashCard card) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCardView(
          cardToEdit: card,
        ),
      ),
    );
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



  void _deleteCard(FlashCard card, FlashcardProvider provider) async {
    print('AllCardsView: Deleting card: ${card.word} (${card.id})');
    final success = await provider.deleteCard(card.id);
    print('AllCardsView: Delete result: $success');
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
  }

  void _resetCardProgress(FlashCard card, FlashcardProvider provider) async {
    final resetCard = card.copyWith(
      learningMastery: LearningMastery(),
    );
    
    await provider.updateCard(resetCard);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset progress for: ${card.word}')),
      );
    }
  }

  void _editExercises(FlashCard card) {
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
  }

  void _studyCard(FlashCard card) {
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
            Text('• A-Z: Alphabetical by word'),
            Text('• Z-A: Reverse alphabetical by word'),
            Text('• Definition A-Z: Alphabetical by definition'),
            Text('• Definition Z-A: Reverse alphabetical by definition'),
            Text('• SRS Level: By spaced repetition level'),
            Text('• Learning %: By learning progress percentage'),
            Text('• Date Created: By creation date (newest first)'),
            Text('• Last Modified: By last modification date'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  void _showCardDetails(FlashCard card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(
              card.article.isNotEmpty ? '${card.article} ' : '',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(child: Text(card.word)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.definition,
              style: const TextStyle(fontSize: 16),
            ),
            if (card.example.isNotEmpty) ...[
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
                card.example,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            if (card.plural.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Plural: ${card.plural}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text('SRS Level: '),
                Tooltip(
                  message: _getSRSDescription(card.srsLevel),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getSRSColor(card.srsLevel),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      card.srsLevel.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Learning Progress: ${card.learningPercentage ?? 0}%'),
            const SizedBox(height: 8),
            Text('Times Shown: ${card.timesShown}'),
            Text('Times Correct: ${card.timesCorrect}'),
            Text('Consecutive Correct: ${card.consecutiveCorrect}'),
            Row(
              children: [
                Text('Ease Factor: '),
                Tooltip(
                  message: 'Affects how quickly review intervals increase. Higher values (2.5) mean longer intervals, lower values (1.3) mean more frequent reviews.',
                  child: Text(
                    '${card.easeFactor.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MM/dd/yyyy').format(date);
  }

  void _addNewCard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddCardView(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const Spacer(),
          const Text(
            'All Cards',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: _cancelSelection,
              child: const Text('Cancel'),
            ),
            if (_selectedCardIds.isNotEmpty)
              IconButton(
                onPressed: _showBulkActionsMenu,
                icon: const Icon(Icons.more_vert),
              ),
          ] else
            IconButton(
              onPressed: _toggleSelectionMode,
              icon: const Icon(Icons.select_all),
            ),
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
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search cards...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
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
              const PopupMenuItem(
                value: SortOption.wordAZ,
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward),
                    SizedBox(width: 8),
                    Text('A-Z'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.wordZA,
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward),
                    SizedBox(width: 8),
                    Text('Z-A'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.definitionAZ,
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward),
                    SizedBox(width: 8),
                    Text('Definition A-Z'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.definitionZA,
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward),
                    SizedBox(width: 8),
                    Text('Definition Z-A'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortOption.srsLevel,
                child: Tooltip(
                  message: 'Sort by learning progress level (0 = new, 10 = mastered)',
                  child: Row(
                    children: [
                      Icon(Icons.trending_up),
                      SizedBox(width: 8),
                      Text('SRS Level'),
                    ],
                  ),
                ),
              ),
              PopupMenuItem(
                value: SortOption.learningPercentage,
                child: Tooltip(
                  message: 'Sort by learning progress percentage (0-100%)',
                  child: Row(
                    children: [
                      Icon(Icons.percent),
                      SizedBox(width: 8),
                      Text('Learning %'),
                    ],
                  ),
                ),
              ),
              const PopupMenuItem(
                value: SortOption.dateCreated,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today),
                    SizedBox(width: 8),
                    Text('Date Created'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: SortOption.lastModified,
                child: Row(
                  children: [
                    Icon(Icons.update),
                    SizedBox(width: 8),
                    Text('Last Modified'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getSortIcon(_sortOption),
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getSortLabel(_sortOption),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSortIcon(SortOption option) {
    switch (option) {
      case SortOption.wordAZ:
      case SortOption.definitionAZ:
        return Icons.arrow_upward;
      case SortOption.wordZA:
      case SortOption.definitionZA:
        return Icons.arrow_downward;
      case SortOption.srsLevel:
        return Icons.trending_up;
      case SortOption.learningPercentage:
        return Icons.percent;
      case SortOption.dateCreated:
        return Icons.calendar_today;
      case SortOption.lastModified:
        return Icons.update;
    }
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.wordAZ:
        return 'A-Z';
      case SortOption.wordZA:
        return 'Z-A';
      case SortOption.definitionAZ:
        return 'Def A-Z';
      case SortOption.definitionZA:
        return 'Def Z-A';
      case SortOption.srsLevel:
        return 'SRS';
      case SortOption.learningPercentage:
        return 'Learning %';
      case SortOption.dateCreated:
        return 'Created';
      case SortOption.lastModified:
        return 'Modified';
    }
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedCardIds.clear();
      _selectAll = false;
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedCardIds.clear();
        _selectAll = false;
      }
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
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Selected Cards'),
              subtitle: const Text('Permanently delete all selected cards'),
              onTap: () {
                Navigator.pop(context);
                _showBulkDeleteConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_copy, color: Colors.blue),
              title: const Text('Move to Deck'),
              subtitle: const Text('Move selected cards to a different deck'),
              onTap: () {
                Navigator.pop(context);
                _showMoveToDeckDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showBulkDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cards'),
        content: Text('Are you sure you want to delete ${_selectedCardIds.length} cards? This action cannot be undone.'),
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

  void _deleteSelectedCards() {
    final provider = context.read<FlashcardProvider>();
    for (final cardId in _selectedCardIds) {
      provider.deleteCard(cardId);
    }
    setState(() {
      _selectedCardIds.clear();
      _isSelectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${_selectedCardIds.length} cards')),
    );
  }

  void _showMoveToDeckDialog() {
    // Implementation for moving cards to deck
    // This would show a deck selection dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Move to deck feature coming soon')),
    );
  }

} 