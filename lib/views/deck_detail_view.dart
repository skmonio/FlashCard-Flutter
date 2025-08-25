import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../components/unified_header.dart';
import '../models/deck.dart';
import '../models/flash_card.dart';
import '../models/dutch_word_exercise.dart';
import 'add_card_view.dart';
import 'study_view.dart';
import 'dutch_word_exercise_detail_view.dart';
import 'create_word_exercise_view.dart';
import 'dutch_words_practice_view.dart';

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
  String _searchQuery = '';
  String _sortBy = 'word'; // word, definition, dateCreated, srsLevel

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
          UnifiedHeader(
            title: widget.deck.name,
            onBack: () => Navigator.of(context).pop(),
            trailing: PopupMenuButton<String>(
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
                const PopupMenuItem(
                  value: 'study',
                  child: Row(
                    children: [
                      Icon(Icons.school),
                      SizedBox(width: 8),
                      Text('Study Deck'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('Export Deck'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCardToDeck(),
        tooltip: 'Add Card to Deck',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search cards...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
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
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceVariant,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          
          // Sort Options
          Row(
            children: [
              Text(
                'Sort by: ',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('word', 'Word'),
                      _buildSortChip('definition', 'Definition'),
                      _buildSortChip('dateCreated', 'Date Added'),
                      _buildSortChip('srsLevel', 'SRS Level'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String value, String label) {
    final isSelected = _sortBy == value;
    
    Widget chip = FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _sortBy = value;
        });
      },
    );
    
    // Add tooltip for SRS Level
    if (value == 'srsLevel') {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tooltip(
          message: 'Sort by learning progress level (0 = new, 10 = mastered)',
          child: chip,
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: chip,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No cards in this deck',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first card',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addCardToDeck,
            icon: const Icon(Icons.add),
            label: const Text('Add First Card'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(FlashCard card, FlashcardProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
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
                if (card.example.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    card.example,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (card.exampleTranslation.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      card.exampleTranslation,
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
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
        trailing: PopupMenuButton<String>(
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
                  Text('Delete', style: TextStyle(color: Colors.red)),
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
        onTap: () => _showCardDetails(card),
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
    // Get cards from the deck including all sub-decks
    var cards = provider.getCardsForDeckWithSubDecks(widget.deck.id);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      cards = cards.where((card) =>
        card.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        card.definition.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        card.example.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Sort cards
    switch (_sortBy) {
      case 'word':
        cards.sort((a, b) => a.word.compareTo(b.word));
        break;
      case 'definition':
        cards.sort((a, b) => a.definition.compareTo(b.definition));
        break;
      case 'dateCreated':
        cards.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
        break;
      case 'srsLevel':
        cards.sort((a, b) => a.srsLevel.compareTo(b.srsLevel));
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
      case 'export':
        _exportDeck();
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
      case 'edit_exercises':
        _editExercises(card);
        break;
      case 'delete':
        _deleteCard(card);
        break;
      case 'study':
        _studyCard(card);
        break;
    }
  }

  void _addCardToDeck() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCardView(selectedDeck: widget.deck),
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
    // Get all cards in this deck including sub-decks
    final provider = context.read<FlashcardProvider>();
    final dutchProvider = context.read<DutchWordExerciseProvider>();
    final deckCards = provider.getCardsForDeckWithSubDecks(widget.deck.id);
    
    if (deckCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards in this deck or its sub-decks to study!')),
      );
      return;
    }
    
    // Create Dutch word exercises from the deck cards, checking for existing exercises first
    final exercises = deckCards.map((card) {
      // Check if there's already an existing exercise for this card
      final existingExercise = dutchProvider.getWordExerciseByWord(card.word);
      
      if (existingExercise != null) {
        // Use existing exercise if found
        print('🔍 DeckDetailView: Found existing exercise for "${card.word}" with ${existingExercise.exercises.length} exercises');
        return existingExercise;
      } else {
        // Create a new exercise if none exists
        print('🔍 DeckDetailView: Created new exercise for "${card.word}" with 1 exercise');
        return DutchWordExercise(
          id: card.id,
          targetWord: card.word,
          wordTranslation: card.definition,
          deckId: widget.deck.id,
          deckName: widget.deck.name,
          category: WordCategory.common,
          difficulty: ExerciseDifficulty.beginner,
          exercises: [
            WordExercise(
              id: '${card.id}_exercise_1',
              type: ExerciseType.multipleChoice,
              prompt: 'Translate "${card.word}" to English',
              correctAnswer: card.definition,
              options: [card.definition, 'Incorrect option 1', 'Incorrect option 2', 'Incorrect option 3'],
              explanation: 'The Dutch word "${card.word}" means "${card.definition}" in English.',
              difficulty: ExerciseDifficulty.beginner,
            ),
          ],
          createdAt: card.dateCreated,
          isUserCreated: true,
        );
      }
    }).toList();
    
    // Navigate to the Dutch words practice view
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DutchWordsPracticeView(
          deckId: widget.deck.id,
          deckName: widget.deck.name,
          exercises: exercises,
        ),
      ),
    );
  }

  void _exportDeck() {
    // TODO: Implement deck export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon!')),
    );
  }

  void _deleteDeck() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text(
          'Are you sure you want to delete "${widget.deck.name}"? '
          'This will also remove all cards in this deck.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

  void _editExercises(FlashCard card) {
    // Check if there's already an existing exercise for this card
    final dutchProvider = context.read<DutchWordExerciseProvider>();
    final existingExercise = dutchProvider.getWordExerciseByWord(card.word);
    
    DutchWordExercise exerciseToEdit;
    
    if (existingExercise != null) {
      // Use existing exercise
      exerciseToEdit = existingExercise;
      print('🔍 DeckDetailView: Editing existing exercise for "${card.word}" with ${existingExercise.exercises.length} exercises');
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
      print('🔍 DeckDetailView: Creating new exercise for "${card.word}"');
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
    print('🔍 DeckDetailView: Found existing exercise for "${card.word}" with ${existingExercise.exercises.length} exercises');
    
    // Navigate to the Dutch word exercise detail view for this card
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DutchWordExerciseDetailView(
          wordExercise: existingExercise,
          showEditDeleteButtons: false,
        ),
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
              if (card.exampleTranslation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  card.exampleTranslation,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
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
            Text('Learning Progress: ${((card.learningPercentage ?? 0) * 100).toInt()}%'),
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
} 