import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../models/deck.dart';
import '../models/flash_card.dart';
import '../models/dutch_word_exercise.dart';
import 'add_deck_view.dart';
import 'deck_detail_view.dart';
import 'add_card_view.dart';
import 'edit_deck_view.dart';
import 'dutch_words_practice_view.dart';

class AllDecksView extends StatefulWidget {
  const AllDecksView({super.key});

  @override
  State<AllDecksView> createState() => _AllDecksViewState();
}

class _AllDecksViewState extends State<AllDecksView> {
  String _searchText = '';
  String _sortOption = 'A-Z';
  bool _isSelectionMode = false;
  Set<String> _selectedDeckIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
          SafeArea(
            child: _buildHeader(context),
          ),
          
          // Search and Sort Bar
          _buildSearchSortBar(),
          
          // Main content
          Expanded(
            child: Consumer<FlashcardProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                return _buildContent(context, provider);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDeckDialog(context),
        tooltip: 'Add New Deck',
        child: const Icon(Icons.add),
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
            'Decks',
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
            if (_selectedDeckIds.isNotEmpty)
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
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search decks...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            _searchText = '';
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
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortOption = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'A-Z',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward),
                    SizedBox(width: 8),
                    Text('A-Z'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Z-A',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward),
                    SizedBox(width: 8),
                    Text('Z-A'),
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
                  Icon(
                    _sortOption == 'A-Z' ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(_sortOption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, FlashcardProvider provider) {
    final allDecks = provider.getAllDecksHierarchical();
    final filteredDecks = _filterDecks(allDecks);
    final sortedDecks = _sortDecks(filteredDecks);

    if (sortedDecks.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDecks.length,
      itemBuilder: (context, index) {
        final deck = sortedDecks[index];
        return _buildDeckCard(context, provider, deck);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Decks Found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchText.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Create your first deck to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          if (_searchText.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddDeckDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create First Deck'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeckCard(BuildContext context, FlashcardProvider provider, Deck deck) {
    // For parent decks, get cards including sub-decks; for sub-decks, get only their own cards
    final cards = deck.isSubDeck 
        ? provider.getCardsForDeck(deck.id)
        : provider.getCardsForDeckWithSubDecks(deck.id);
    final subDecks = provider.getSubDecks(deck.id);
    final isSelected = _selectedDeckIds.contains(deck.id);
    
    // Debug: Print deck info
    print('🔍 AllDecksView: Deck "${deck.name}" (${deck.id}) has ${cards.length} cards (${deck.isSubDeck ? 'sub-deck' : 'parent deck'})');
    for (final card in cards) {
      print('🔍 AllDecksView:   - Card "${card.word}" has ${card.learningPercentage}% (timesShown: ${card.timesShown}, timesCorrect: ${card.timesCorrect})');
    }
    print('🔍 AllDecksView: Deck "${deck.name}" calculated percentage: ${Deck.calculateLearningPercentage(deck.name, cards).round()}%');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _isSelectionMode ? () => _toggleDeckSelection(deck.id) : () => _openDeck(context, deck),
        onLongPress: () => _toggleSelectionMode(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) => _toggleDeckSelection(deck.id),
                  ),
                  const SizedBox(width: 8),
                ],
                // Indentation for sub-decks
                if (deck.isSubDeck) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.subdirectory_arrow_right,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                                      child: Text(
                    '${Deck.calculateLearningPercentage(deck.name, cards).round()}%',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
                        deck.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (deck.isSubDeck)
                        Text(
                          'Sub-deck',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${cards.length} cards',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_searchText.isNotEmpty && _hasCardMatches(deck, cards))
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search,
                                size: 12,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Contains matching cards',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Consumer<DutchWordExerciseProvider>(
                        builder: (context, dutchProvider, child) {
                          int totalExercises = 0;
                          for (final card in cards) {
                            final exercise = dutchProvider.getWordExerciseByWord(card.word);
                            totalExercises += exercise?.exercises.length ?? 0;
                          }
                          
                          if (totalExercises > 0) {
                            return Text(
                              '$totalExercises exercise${totalExercises == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.green[600],
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                if (!_isSelectionMode)
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleDeckMenuAction(context, deck, value),
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
                        value: 'add_card',
                        child: Row(
                          children: [
                            Icon(Icons.add_card),
                            SizedBox(width: 8),
                            Text('Add Card'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add_subdeck',
                        child: Row(
                          children: [
                            Icon(Icons.create_new_folder),
                            SizedBox(width: 8),
                            Text('Add Sub-deck'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'study',
                        child: Row(
                          children: [
                            Icon(Icons.quiz, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Study This Deck', style: TextStyle(color: Colors.green)),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Deck> _filterDecks(List<Deck> decks) {
    if (_searchText.isEmpty) return decks;
    
    final provider = context.read<FlashcardProvider>();
    final searchLower = _searchText.toLowerCase();
    
    return decks.where((deck) {
      // Search in deck name
      if (deck.name.toLowerCase().contains(searchLower)) {
        return true;
      }
      
      // Search in cards within this deck
      final cards = deck.isSubDeck 
          ? provider.getCardsForDeck(deck.id)
          : provider.getCardsForDeckWithSubDecks(deck.id);
      
      for (final card in cards) {
        // Search in word
        if (card.word.toLowerCase().contains(searchLower)) {
          return true;
        }
        // Search in definition
        if (card.definition.toLowerCase().contains(searchLower)) {
          return true;
        }
        // Search in example
        if (card.example.isNotEmpty && card.example.toLowerCase().contains(searchLower)) {
          return true;
        }
        // Search in article
        if (card.article.isNotEmpty && card.article.toLowerCase().contains(searchLower)) {
          return true;
        }
        // Search in plural
        if (card.plural.isNotEmpty && card.plural.toLowerCase().contains(searchLower)) {
          return true;
        }
        // Search in verb forms
        if (card.pastTense.isNotEmpty && card.pastTense.toLowerCase().contains(searchLower)) {
          return true;
        }
        if (card.futureTense.isNotEmpty && card.futureTense.toLowerCase().contains(searchLower)) {
          return true;
        }
        if (card.pastParticiple.isNotEmpty && card.pastParticiple.toLowerCase().contains(searchLower)) {
          return true;
        }
      }
      
      return false;
    }).toList();
  }

  bool _hasCardMatches(Deck deck, List<FlashCard> cards) {
    if (_searchText.isEmpty) return false;
    
    final searchLower = _searchText.toLowerCase();
    
    // Check if deck name matches (if it does, we don't need to show card match indicator)
    if (deck.name.toLowerCase().contains(searchLower)) {
      return false;
    }
    
    // Check if any cards match
    for (final card in cards) {
      // Search in word
      if (card.word.toLowerCase().contains(searchLower)) {
        return true;
      }
      // Search in definition
      if (card.definition.toLowerCase().contains(searchLower)) {
        return true;
      }
      // Search in example
      if (card.example.isNotEmpty && card.example.toLowerCase().contains(searchLower)) {
        return true;
      }
      // Search in article
      if (card.article.isNotEmpty && card.article.toLowerCase().contains(searchLower)) {
        return true;
      }
      // Search in plural
      if (card.plural.isNotEmpty && card.plural.toLowerCase().contains(searchLower)) {
        return true;
      }
      // Search in verb forms
      if (card.pastTense.isNotEmpty && card.pastTense.toLowerCase().contains(searchLower)) {
        return true;
      }
      if (card.futureTense.isNotEmpty && card.futureTense.toLowerCase().contains(searchLower)) {
        return true;
      }
      if (card.pastParticiple.isNotEmpty && card.pastParticiple.toLowerCase().contains(searchLower)) {
        return true;
      }
    }
    
    return false;
  }

  List<Deck> _sortDecks(List<Deck> decks) {
    final provider = context.read<FlashcardProvider>();
    
    // Separate parent and child decks
    final parentDecks = decks.where((deck) => deck.parentId == null).toList();
    final childDecks = decks.where((deck) => deck.parentId != null).toList();
    
    // Sort parent decks
    parentDecks.sort((a, b) {
      if (_sortOption == 'A-Z') {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      }
    });
    
    // Sort child decks within each parent
    childDecks.sort((a, b) {
      // First sort by parent deck name
      final parentA = provider.getDeck(a.parentId!);
      final parentB = provider.getDeck(b.parentId!);
      
      if (parentA != null && parentB != null) {
        final parentComparison = _sortOption == 'A-Z' 
            ? parentA.name.toLowerCase().compareTo(parentB.name.toLowerCase())
            : parentB.name.toLowerCase().compareTo(parentA.name.toLowerCase());
        
        if (parentComparison != 0) {
          return parentComparison;
        }
      }
      
      // Then sort by child deck name
      if (_sortOption == 'A-Z') {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      }
    });
    
    // Combine parent and child decks in hierarchical order
    final result = <Deck>[];
    
    // Add parent decks and their children in hierarchical order
    for (final parentDeck in parentDecks) {
      // Add the parent deck
      result.add(parentDeck);
      
      // Add all children of this parent deck immediately after
      final children = childDecks.where((child) => child.parentId == parentDeck.id).toList();
      result.addAll(children);
    }
    
    return result;
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedDeckIds.clear();
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedDeckIds.clear();
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
              'Bulk Actions (${_selectedDeckIds.length} selected)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Selected Decks'),
              subtitle: const Text('Permanently delete all selected decks and their cards'),
              onTap: () {
                Navigator.pop(context);
                _showBulkDeleteConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_copy, color: Colors.blue),
              title: const Text('Export Selected Decks'),
              subtitle: const Text('Export all selected decks to CSV'),
              onTap: () {
                Navigator.pop(context);
                _exportSelectedDecks();
              },
            ),
            ListTile(
              leading: const Icon(Icons.merge_type, color: Colors.green),
              title: const Text('Merge Selected Decks'),
              subtitle: const Text('Combine all selected decks into one'),
              onTap: () {
                Navigator.pop(context);
                _showMergeDecksDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _toggleDeckSelection(String deckId) {
    setState(() {
      if (_selectedDeckIds.contains(deckId)) {
        _selectedDeckIds.remove(deckId);
      } else {
        _selectedDeckIds.add(deckId);
      }
    });
  }

  void _showBulkDeleteConfirmation() {
    final provider = context.read<FlashcardProvider>();
    final selectedDecks = _selectedDeckIds.map((id) => provider.getDeck(id)).whereType<Deck>().toList();
    final deckNames = selectedDecks.map((d) => d.name).join(', ');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Decks'),
        content: Text(
          'Are you sure you want to permanently delete ${_selectedDeckIds.length} deck(s)?\n\n'
          'This will also delete all cards in these decks:\n$deckNames\n\n'
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
              _performBulkDelete();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _performBulkDelete() async {
    final provider = context.read<FlashcardProvider>();
    int successCount = 0;
    int errorCount = 0;
    
    for (final deckId in _selectedDeckIds) {
      try {
        final success = await provider.deleteDeck(deckId);
        if (success) {
          successCount++;
        } else {
          errorCount++;
        }
      } catch (e) {
        errorCount++;
        print('Error deleting deck $deckId: $e');
      }
    }
    
    // Clear selection and show result
    setState(() {
      _isSelectionMode = false;
      _selectedDeckIds.clear();
    });
    
    if (mounted) {
      String message = 'Deleted $successCount deck(s) successfully';
      if (errorCount > 0) {
        message += '. Failed to delete $errorCount deck(s)';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  void _exportSelectedDecks() async {
    try {
      final provider = context.read<FlashcardProvider>();
      final dutchProvider = context.read<DutchWordExerciseProvider>();
      
      // Get all exercises for the selected decks
      final allExercises = dutchProvider.wordExercises;
      
      final csvContent = provider.exportUnifiedCSV(_selectedDeckIds, exercises: allExercises);
      
      // Save file using FilePicker for mobile compatibility
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Bulk Export',
        fileName: 'FlashCards_BulkExport_$timestamp.csv',
        allowedExtensions: ['csv'],
        type: FileType.custom,
        bytes: utf8.encode(csvContent), // Convert string to bytes for mobile
      );
      
      // Clear selection
      setState(() {
        _isSelectionMode = false;
        _selectedDeckIds.clear();
      });
      
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export successful! File saved to your device.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMergeDecksDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge Decks'),
        content: const Text(
          'Enter a name for the merged deck:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final textController = TextEditingController();
              Navigator.pop(context);
              _showMergeNameDialog(textController);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showMergeNameDialog(TextEditingController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge Decks'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Merged Deck Name',
            hintText: 'e.g., Combined Vocabulary',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                _performMergeDecks(name);
              }
            },
            child: const Text('Merge'),
          ),
        ],
      ),
    );
  }

  void _performMergeDecks(String mergedDeckName) async {
    final provider = context.read<FlashcardProvider>();
    
    try {
      // Create the merged deck
      final mergedDeck = await provider.createDeck(mergedDeckName);
      if (mergedDeck == null) {
        throw Exception('Failed to create merged deck');
      }
      
      // Collect all cards from selected decks
      final allCards = <FlashCard>[];
      for (final deckId in _selectedDeckIds) {
        final deck = provider.getDeck(deckId);
        if (deck != null) {
          final deckCards = deck.isSubDeck 
              ? provider.getCardsForDeck(deck.id)
              : provider.getCardsForDeckWithSubDecks(deck.id);
          allCards.addAll(deckCards);
        }
      }
      
      // Add all cards to the merged deck
      for (final card in allCards) {
        if (!card.deckIds.contains(mergedDeck.id)) {
          card.deckIds.add(mergedDeck.id);
        }
      }
      
      // Save the changes
      await provider.saveData();
      
      // Clear selection
      setState(() {
        _isSelectionMode = false;
        _selectedDeckIds.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully merged ${allCards.length} cards into "$mergedDeckName"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merge failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddDeckDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddDeckView(),
      ),
    );
  }

  void _openDeck(BuildContext context, Deck deck) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeckDetailView(deck: deck),
      ),
    );
  }

  void _handleDeckMenuAction(BuildContext context, Deck deck, String action) {
    switch (action) {
      case 'edit':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EditDeckView(deck: deck),
          ),
        );
        break;
      case 'add_card':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddCardView(selectedDeck: deck),
          ),
        );
        break;
      case 'add_subdeck':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddDeckView(parentDeckId: deck.id),
          ),
        );
        break;
      case 'study':
        _studyDeck(context, deck);
        break;
      case 'delete':
        _showDeleteDeckDialog(context, deck);
        break;
    }
  }

  void _studyDeck(BuildContext context, Deck deck) {
    // Get all cards in this deck including sub-decks for parent decks
    final provider = context.read<FlashcardProvider>();
    final dutchProvider = context.read<DutchWordExerciseProvider>();
    final deckCards = deck.isSubDeck 
        ? provider.getCardsForDeck(deck.id)
        : provider.getCardsForDeckWithSubDecks(deck.id);
    
    if (deckCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No cards in "${deck.name}"${deck.isSubDeck ? '' : ' or its sub-decks'} to study!')),
      );
      return;
    }
    
    // Create Dutch word exercises from the deck cards, checking for existing exercises first
    final exercises = deckCards.map((card) {
      // Check if there's already an existing exercise for this card
      final existingExercise = dutchProvider.getWordExerciseByWord(card.word);
      
      if (existingExercise != null) {
        // Use existing exercise if found
        print('🔍 AllDecksView: Found existing exercise for "${card.word}" with ${existingExercise.exercises.length} exercises');
        return existingExercise;
      } else {
        // Create a new exercise if none exists
        print('🔍 AllDecksView: Created new exercise for "${card.word}" with 1 exercise');
        return DutchWordExercise(
          id: card.id,
          targetWord: card.word,
          wordTranslation: card.definition,
          deckId: deck.id,
          deckName: deck.name,
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
          deckId: deck.id,
          deckName: deck.name,
          exercises: exercises,
        ),
      ),
    );
  }

  void _showDeleteDeckDialog(BuildContext context, Deck deck) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text('Are you sure you want to delete "${deck.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<FlashcardProvider>().deleteDeck(deck.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
} 