import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../providers/flashcard_provider.dart';
import '../models/deck.dart';
import '../models/flash_card.dart';
import 'add_deck_view.dart';
import 'deck_detail_view.dart';
import 'add_card_view.dart';
import 'edit_deck_view.dart';
import 'study_type_selection_view.dart';
import '../components/universal_add_button.dart';

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
          child: Consumer<FlashcardProvider>(
            builder: (context, provider, child) {
              return Text(
                'Decks',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              );
            },
          ),
        ),
        
        // Left side - Back button
        Positioned(
          left: 16,
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
                _selectedDeckIds.clear();
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
                final provider = context.read<FlashcardProvider>();
                final decks = provider.decks;
                if (_selectedDeckIds.length == decks.length) {
                  _selectedDeckIds.clear();
                } else {
                  _selectedDeckIds = decks.map((deck) => deck.id).toSet();
                }
              });
            },
            icon: Icon(_selectedDeckIds.length == context.read<FlashcardProvider>().decks.length 
                ? Icons.check_box 
                : Icons.check_box_outline_blank),
            label: Text(_selectedDeckIds.length == context.read<FlashcardProvider>().decks.length 
                ? 'Deselect All' 
                : 'Select All'),
          ),
          
          const SizedBox(width: 8),
          
          // Bulk Actions Menu
          if (_selectedDeckIds.isNotEmpty)
            TextButton.icon(
              onPressed: _showBulkActionsMenu,
              icon: const Icon(Icons.more_vert),
              label: const Text('Actions'),
            ),
        ],
      ),
    );
  }

  void _playDecks() {
    final provider = context.read<FlashcardProvider>();
    
    List<Deck> decksToPlay;
    
    if (_selectedDeckIds.isNotEmpty) {
      // Play only selected decks
      decksToPlay = _selectedDeckIds
          .map((id) => provider.decks.firstWhere((deck) => deck.id == id))
          .toList();
    } else {
      // Play all decks
      decksToPlay = provider.decks;
    }
    
    if (decksToPlay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No decks available to play'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Navigate to study type selection
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudyTypeSelectionView(
          gameMode: GameMode.study,
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            '${provider.decks.length} Decks',
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
            itemCount: sortedDecks.length,
            itemBuilder: (context, index) {
              final deck = sortedDecks[index];
              return _buildDeckCard(context, provider, deck);
            },
          ),
        ),
      ],
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
        boxShadow: [
          // Removed color-based shadow since deck colors are no longer supported
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: _isSelectionMode ? () => _toggleDeckSelection(deck.id) : () => _openDeck(context, deck),
        onLongPress: () {
          setState(() {
            _isSelectionMode = true;
            _selectedDeckIds.add(deck.id);
          });
        },
        borderRadius: BorderRadius.circular(12),
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
        if (card.presentTense.isNotEmpty && card.presentTense.toLowerCase().contains(searchLower)) {
          return true;
        }
        if (card.perfectTense.isNotEmpty && card.perfectTense.toLowerCase().contains(searchLower)) {
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
      if (card.presentTense.isNotEmpty && card.presentTense.toLowerCase().contains(searchLower)) {
        return true;
      }
      if (card.perfectTense.isNotEmpty && card.perfectTense.toLowerCase().contains(searchLower)) {
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
            if (_selectedDeckIds.length == 1)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.black),
                title: const Text('Edit Selected Deck'),
                subtitle: const Text('Edit the selected deck'),
                onTap: () {
                  Navigator.pop(context);
                  _editSelectedDeck();
                },
              ),
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
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('Reset Progress'),
              subtitle: const Text('Reset learning progress for all cards in selected decks'),
              onTap: () {
                Navigator.pop(context);
                _showResetProgressConfirmation();
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

  void _editSelectedDeck() {
    try {
      final provider = context.read<FlashcardProvider>();
      final deckId = _selectedDeckIds.first;
      final deck = provider.decks.firstWhere((d) => d.id == deckId);
      _editDeck(deck);
    } catch (e) {
      print('🔍 AllDecksView: Error editing selected deck: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding deck to edit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editDeck(Deck deck) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditDeckView(deck: deck),
        ),
      );
    } catch (e) {
      print('🔍 AllDecksView: Error navigating to edit deck: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening edit deck: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      
      final csvContent = provider.exportUnifiedCSV(_selectedDeckIds);
      
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
      case 'delete':
        _showDeleteDeckDialog(context, deck);
        break;
    }
  }
  List<String> _generateIntelligentOptions(FlashCard targetCard, {String? preferredDeckId}) {
    // Start with the correct answer at position 0 (option 1)
    final options = <String>[targetCard.definition];
    final usedOptions = <String>{targetCard.definition}; // Track all used options to prevent duplicates
    
    // Get all cards from the provider
    final provider = context.read<FlashcardProvider>();
    final allCards = provider.cards;
    
    // Get other definitions, prioritizing the preferred deck if specified
    List<String> otherDefinitions = [];
    
    if (preferredDeckId != null) {
      // First, try to get definitions from the preferred deck
      final deckCards = allCards.where((card) => 
        card.id != targetCard.id && 
        card.definition.isNotEmpty &&
        card.deckIds.contains(preferredDeckId)
      ).map((card) => card.definition).toList();
      
      otherDefinitions.addAll(deckCards);
    }
    
    // If we don't have enough options, add from all other cards
    if (otherDefinitions.length < 5) {
      final remainingCards = allCards.where((card) => 
        card.id != targetCard.id && 
        card.definition.isNotEmpty &&
        !otherDefinitions.contains(card.definition)
      ).map((card) => card.definition).toList();
      
      otherDefinitions.addAll(remainingCards);
    }
    
    // Shuffle and take up to 5 more options (to make 6 total)
    otherDefinitions.shuffle();
    final additionalOptions = otherDefinitions.take(5).toList();
    
    // Add the additional options, ensuring no duplicates
    for (final option in additionalOptions) {
      if (!usedOptions.contains(option)) {
        options.add(option);
        usedOptions.add(option);
      }
    }
    
    // If we don't have enough options from other cards, add some generic but realistic options
    final genericOptions = [
      'to walk',
      'to eat',
      'to sleep',
      'to work',
      'to play',
      'to read',
      'to write',
      'to speak',
      'to listen',
      'to watch',
      'to buy',
      'to sell',
      'to give',
      'to take',
      'to come',
      'to go',
      'to see',
      'to know',
      'to think',
      'to feel',
    ];
    
    // Add generic options until we have 6 total, ensuring no duplicates
    for (final genericOption in genericOptions) {
      if (options.length >= 6) break;
      if (!usedOptions.contains(genericOption)) {
        options.add(genericOption);
        usedOptions.add(genericOption);
      }
    }
    
    // Don't shuffle - keep correct answer at index 0 (option 1)
    // Ensure we have exactly 6 options
    return options.take(6).toList();
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

  void _showResetProgressConfirmation() {
    final provider = context.read<FlashcardProvider>();
    final selectedDecks = _selectedDeckIds.map((id) => provider.getDeck(id)).whereType<Deck>().toList();
    final deckNames = selectedDecks.map((d) => d.name).join(', ');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: Text(
          'Are you sure you want to reset the learning progress for all cards in the selected deck${selectedDecks.length == 1 ? '' : 's'}?\n\n'
          'This will reset:\n'
          '• Times shown\n'
          '• Times correct\n'
          '• Learning percentage\n'
          '• All progress data\n\n'
          'Selected deck${selectedDecks.length == 1 ? '' : 's'}: $deckNames\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _resetSelectedDecksProgress();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reset Progress'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSelectedDecksProgress() async {
    final provider = context.read<FlashcardProvider>();
    int successCount = 0;
    int errorCount = 0;
    
    for (final deckId in _selectedDeckIds) {
      try {
        final deck = provider.getDeck(deckId);
        if (deck == null) {
          print('🔍 AllDecksView: Deck not found: $deckId');
          errorCount++;
          continue;
        }
        
        // Get all cards in this deck (including sub-decks)
        final cards = deck.isSubDeck 
            ? provider.getCardsForDeck(deck.id)
            : provider.getCardsForDeckWithSubDecks(deck.id);
        
        // Reset progress for each card
        for (final card in cards) {
          try {
            await provider.resetCardProgress(card.id);
            successCount++;
          } catch (e) {
            print('🔍 AllDecksView: Error resetting progress for card ${card.id}: $e');
            errorCount++;
          }
        }
      } catch (e) {
        print('🔍 AllDecksView: Error resetting progress for deck $deckId: $e');
        errorCount++;
      }
    }
    
    setState(() {
      _isSelectionMode = false;
      _selectedDeckIds.clear();
    });
    
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