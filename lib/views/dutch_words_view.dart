import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../models/dutch_word_exercise.dart';
import 'dutch_word_exercise_detail_view.dart';
import 'dutch_words_deck_view.dart';
import 'create_word_exercise_view.dart';
import 'import_word_exercises_view.dart';
import 'export_word_exercises_view.dart';

class DutchWordsView extends StatefulWidget {
  const DutchWordsView({super.key});

  @override
  State<DutchWordsView> createState() => _DutchWordsViewState();
}

class _DutchWordsViewState extends State<DutchWordsView> {
  String _searchQuery = '';
  bool _isSelectionMode = false;
  Set<String> _selectedDeckIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DutchWordExerciseProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dutch Words'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: _isSelectionMode ? _buildSelectionActions() : _buildHeaderActions(),
      ),
      body: Consumer<DutchWordExerciseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${provider.error}'),
                  ElevatedButton(
                    onPressed: () => provider.clearError(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final filteredExercises = _getFilteredExercises(provider);

          return Column(
            children: [
              // Search and filter section
              _buildSearchAndFilterSection(),
              
              // Action buttons (only show when not in selection mode)
              if (!_isSelectionMode) _buildActionButtons(),
              
              // Exercises list
              Expanded(
                child: filteredExercises.isEmpty
                    ? _buildEmptyState()
                    : _buildExercisesList(filteredExercises),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildHeaderActions() {
    return [
      IconButton(
        onPressed: () => _showInfo(),
        icon: const Icon(Icons.info_outline),
        tooltip: 'Info',
      ),
    ];
  }

  List<Widget> _buildSelectionActions() {
    return [
      // Select All Toggle
      IconButton(
        onPressed: () {
          setState(() {
            if (_selectAll) {
              _selectedDeckIds.clear();
              _selectAll = false;
            } else {
              final provider = context.read<DutchWordExerciseProvider>();
              final exercises = _getFilteredExercises(provider);
              final deckIds = _getDeckIdsFromExercises(exercises);
              _selectedDeckIds = deckIds.toSet();
              _selectAll = true;
            }
          });
        },
        icon: Icon(_selectAll ? Icons.check_box : Icons.check_box_outline_blank),
        tooltip: _selectAll ? 'Deselect All' : 'Select All',
      ),
      
      // Delete Selected
      if (_selectedDeckIds.isNotEmpty)
        IconButton(
          onPressed: () => _showDeleteSelectedDialog(),
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete Selected',
        ),
      
      // Selection Count
      if (_selectedDeckIds.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_selectedDeckIds.length}',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ),
    ];
  }

  Set<String> _getDeckIdsFromExercises(List<DutchWordExercise> exercises) {
    final Set<String> deckIds = {};
    for (final exercise in exercises) {
      deckIds.add(exercise.deckId);
    }
    return deckIds;
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search words...',
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
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          // Selection Mode Toggle
          Row(
            children: [
              Expanded(child: Container()), // Spacer
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSelectionMode = !_isSelectionMode;
                    if (!_isSelectionMode) {
                      _selectedDeckIds.clear();
                      _selectAll = false;
                    }
                  });
                },
                icon: Icon(
                  _isSelectionMode ? Icons.close : Icons.select_all,
                  color: _isSelectionMode ? Colors.red : Colors.green,
                ),
                tooltip: _isSelectionMode ? 'Exit Selection' : 'Select Decks',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImportWordExercisesView(
                      onImportComplete: () {
                        // Refresh the view when import is complete
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.file_upload),
              label: const Text('Import'),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExportWordExercisesView(),
                  ),
                );
              },
              icon: const Icon(Icons.file_download),
              label: const Text('Export'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(DutchWordExerciseProvider provider) {
    // Removed statistics cards as requested
    return const SizedBox.shrink();
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExercisesList(List<DutchWordExercise> exercises) {
    // Group exercises by deck
    final Map<String, List<DutchWordExercise>> deckGroups = {};
    for (final exercise in exercises) {
      if (!deckGroups.containsKey(exercise.deckId)) {
        deckGroups[exercise.deckId] = [];
      }
      deckGroups[exercise.deckId]!.add(exercise);
    }

    final deckIds = deckGroups.keys.toList()..sort();
    
    // Filter out empty decks
    final nonEmptyDeckIds = deckIds.where((deckId) => deckGroups[deckId]!.isNotEmpty).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: nonEmptyDeckIds.length,
      itemBuilder: (context, index) {
        final deckId = nonEmptyDeckIds[index];
        final deckExercises = deckGroups[deckId]!;
        final deckName = deckExercises.first.deckName;
        final totalExercises = deckExercises.fold<int>(0, (sum, exercise) => sum + exercise.exercises.length);
        final isSelected = _selectedDeckIds.contains(deckId);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: _isSelectionMode ? () => _toggleDeckSelection(deckId) : () => _openDeck(deckId, deckName, deckExercises),
            onLongPress: () {
              setState(() {
                _isSelectionMode = true;
                _selectedDeckIds.add(deckId);
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: isSelected ? Border.all(color: Colors.green, width: 2) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSelectionMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) => _toggleDeckSelection(deckId),
                        activeColor: Colors.green,
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
                          '${_calculateLearningPercentage(deckExercises)}%',
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
                title: Text(
                  deckName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${deckExercises.length} words • $totalExercises exercises',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isSelectionMode) ...[
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditDeckDialog(context, deckId, deckName),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteDeckDialog(context, deckId, deckName, deckExercises),
                      ),
                      const Icon(Icons.arrow_forward_ios),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditDeckDialog(BuildContext context, String deckId, String deckName) {
    final _nameController = TextEditingController(text: deckName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Deck Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Deck Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.of(context).pop();
                _updateDeckName(deckId, newName);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _updateDeckName(String deckId, String newName) {
    final provider = context.read<DutchWordExerciseProvider>();
    final exercisesInDeck = provider.getExercisesByDeck(deckId);
    
    for (final exercise in exercisesInDeck) {
      final updatedExercise = DutchWordExercise(
        id: exercise.id,
        targetWord: exercise.targetWord,
        wordTranslation: exercise.wordTranslation,
        deckId: deckId,
        deckName: newName,
        category: exercise.category,
        difficulty: exercise.difficulty,
        exercises: exercise.exercises,
        createdAt: exercise.createdAt,
        isUserCreated: exercise.isUserCreated,
      );
      provider.updateWordExercise(updatedExercise);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deck renamed to "$newName"'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showDeleteDeckDialog(BuildContext context, String deckId, String deckName, List<DutchWordExercise> deckExercises) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text(
          'Are you sure you want to delete the deck "$deckName"?\n\n'
          'This will permanently delete ${deckExercises.length} words and ${deckExercises.fold<int>(0, (sum, exercise) => sum + exercise.exercises.length)} exercises.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteDeck(deckId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteDeck(String deckId) {
    final provider = context.read<DutchWordExerciseProvider>();
    final exercisesToDelete = provider.getExercisesByDeck(deckId);
    
    for (final exercise in exercisesToDelete) {
      provider.deleteWordExercise(exercise.id);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deck deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.text_fields,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No word exercises found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first word exercise or import some examples',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<DutchWordExercise> _getFilteredExercises(DutchWordExerciseProvider provider) {
    return provider.searchWordExercises(_searchQuery);
  }

  int _calculateLearningPercentage(List<DutchWordExercise> exercises) {
    if (exercises.isEmpty) return 0;
    
    // Calculate average learning percentage from real progress data
    double totalPercentage = 0;
    
    print('🔍 DutchWordsView: Calculating percentage for ${exercises.length} exercises');
    for (final exercise in exercises) {
      final percentage = exercise.learningProgress.learningPercentage;
      print('🔍 DutchWordsView: Word "${exercise.targetWord}" has ${percentage}% (correct: ${exercise.learningProgress.correctAnswers}, total: ${exercise.learningProgress.totalAttempts})');
      totalPercentage += percentage;
    }
    
    final average = (totalPercentage / exercises.length).round();
    print('🔍 DutchWordsView: Average percentage for deck: $average%');
    return average;
  }

  Color _getCategoryColor(WordCategory category) {
    switch (category) {
      case WordCategory.common:
        return Colors.blue;
      case WordCategory.business:
        return Colors.green;
      case WordCategory.academic:
        return Colors.purple;
      case WordCategory.casual:
        return Colors.orange;
      case WordCategory.formal:
        return Colors.indigo;
      case WordCategory.technical:
        return Colors.red;
      case WordCategory.cultural:
        return Colors.teal;
      case WordCategory.other:
        return Colors.grey;
    }
  }

  Color _getDifficultyColor(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.beginner:
        return Colors.green;
      case ExerciseDifficulty.intermediate:
        return Colors.orange;
      case ExerciseDifficulty.advanced:
        return Colors.red;
    }
  }

  void _toggleDeckSelection(String deckId) {
    setState(() {
      if (_selectedDeckIds.contains(deckId)) {
        _selectedDeckIds.remove(deckId);
        _selectAll = false;
      } else {
        _selectedDeckIds.add(deckId);
      }
    });
  }

  void _openDeck(String deckId, String deckName, List<DutchWordExercise> deckExercises) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DutchWordsDeckView(
          deckId: deckId,
          deckName: deckName,
          exercises: deckExercises,
        ),
      ),
    );
  }

  void _showDeleteSelectedDialog() {
    if (_selectedDeckIds.isEmpty) return;

    final provider = context.read<DutchWordExerciseProvider>();
    final selectedDecks = <String, List<DutchWordExercise>>{};
    int totalWords = 0;
    int totalExercises = 0;

    for (final deckId in _selectedDeckIds) {
      final exercises = provider.getExercisesByDeck(deckId);
      selectedDecks[deckId] = exercises;
      totalWords += exercises.length;
      totalExercises += exercises.fold<int>(0, (sum, exercise) => sum + exercise.exercises.length);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Decks'),
        content: Text(
          'Are you sure you want to delete ${_selectedDeckIds.length} deck(s)?\n\n'
          'This will permanently delete $totalWords words and $totalExercises exercises.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteSelectedDecks();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteSelectedDecks() {
    final provider = context.read<DutchWordExerciseProvider>();
    final selectedCount = _selectedDeckIds.length;
    
    for (final deckId in _selectedDeckIds) {
      final exercisesToDelete = provider.getExercisesByDeck(deckId);
      for (final exercise in exercisesToDelete) {
        provider.deleteWordExercise(exercise.id);
      }
    }
    
    setState(() {
      _selectedDeckIds.clear();
      _selectAll = false;
      _isSelectionMode = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$selectedCount deck(s) deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dutch Words'),
        content: const Text(
          'Manage your Dutch word exercises and decks.\n\n'
          '• Tap on a deck to practice its exercises\n'
          '• Long press to enter selection mode\n'
          '• Use the selection mode to delete multiple decks\n'
          '• Import/export your exercises for backup',
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