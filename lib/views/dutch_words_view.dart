import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../models/dutch_word_exercise.dart';
import 'dutch_word_exercise_detail_view.dart';
import 'dutch_words_deck_view.dart';
import 'create_word_exercise_view.dart';

class DutchWordsView extends StatefulWidget {
  const DutchWordsView({super.key});

  @override
  State<DutchWordsView> createState() => _DutchWordsViewState();
}

class _DutchWordsViewState extends State<DutchWordsView> {
  String _searchQuery = '';
  String _sortOption = 'A-Z';
  bool _isSelectionMode = false;
  Set<String> _selectedExerciseIds = {};
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
          title: const Text('Exercises'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black,
          actions: _isSelectionMode ? _buildSelectionActions() : _buildHeaderActions(),
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateExercise(),
        tooltip: 'Add Exercise',
        child: const Icon(Icons.add),
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
          onPressed: _toggleSelectionMode,
          icon: const Icon(Icons.select_all),
          tooltip: 'Select',
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
              _selectedExerciseIds.clear();
              _selectAll = false;
            } else {
              final provider = context.read<DutchWordExerciseProvider>();
              final exercises = _getFilteredExercises(provider);
              final exerciseIds = _getExerciseIdsFromExercises(exercises);
              _selectedExerciseIds = exerciseIds.toSet();
              _selectAll = true;
            }
          });
        },
        icon: Icon(_selectAll ? Icons.check_box : Icons.check_box_outline_blank),
        tooltip: _selectAll ? 'Deselect All' : 'Select All',
      ),
      
      // Delete Selected
      if (_selectedExerciseIds.isNotEmpty)
        IconButton(
          onPressed: () => _showDeleteSelectedDialog(),
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Delete Selected',
        ),
      
      // Selection Count
      if (_selectedExerciseIds.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_selectedExerciseIds.length}',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ),
    ];
  }

  Set<String> _getExerciseIdsFromExercises(List<DutchWordExercise> exercises) {
    final Set<String> exerciseIds = {};
    for (final exercise in exercises) {
      exerciseIds.add(exercise.id);
    }
    return exerciseIds;
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Search bar
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search exercises...',
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
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               decoration: BoxDecoration(
                 border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                 borderRadius: BorderRadius.circular(12),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(
                     _sortOption == 'A-Z' ? Icons.arrow_upward : Icons.arrow_downward,
                     size: 20,
                     color: Colors.grey[600],
                   ),
                   const SizedBox(width: 8),
                   Text(
                     _sortOption,
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final isSelected = _selectedExerciseIds.contains(exercise.id);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: _isSelectionMode ? () => _toggleExerciseSelection(exercise.id) : () => _openExercise(exercise),
            onLongPress: () {
              setState(() {
                _isSelectionMode = true;
                _selectedExerciseIds.add(exercise.id);
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
                        onChanged: (value) => _toggleExerciseSelection(exercise.id),
                        activeColor: Colors.green,
                      ),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Text(
                          '${exercise.learningProgress.learningPercentage.toInt()}%',
                          style: TextStyle(
                            color: Colors.indigo[700],
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
                        exercise.targetWord,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.wordTranslation,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exercise.exercises.length} exercises • ${exercise.deckName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                trailing: _isSelectionMode ? null : PopupMenuButton<String>(
                  onSelected: (value) => _handleExerciseAction(value, exercise),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Exercise'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Exercise', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
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



  void _showDeleteExerciseDialog(BuildContext context, DutchWordExercise exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text(
          'Are you sure you want to delete the exercise for "${exercise.targetWord}"?\n\n'
          'This will permanently delete ${exercise.exercises.length} exercises.\n\n'
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
              context.read<DutchWordExerciseProvider>().deleteWordExercise(exercise.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
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
            Icons.quiz,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No word exercises found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first word exercise to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToCreateExercise(),
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Exercise'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  List<DutchWordExercise> _getFilteredExercises(DutchWordExerciseProvider provider) {
    var exercises = provider.searchWordExercises(_searchQuery);
    
    // Sort exercises
    if (_sortOption == 'A-Z') {
      exercises.sort((a, b) => a.targetWord.toLowerCase().compareTo(b.targetWord.toLowerCase()));
    } else if (_sortOption == 'Z-A') {
      exercises.sort((a, b) => b.targetWord.toLowerCase().compareTo(a.targetWord.toLowerCase()));
    }
    
    return exercises;
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

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedExerciseIds.clear();
        _selectAll = false;
      }
    });
  }

  void _toggleExerciseSelection(String exerciseId) {
    setState(() {
      if (_selectedExerciseIds.contains(exerciseId)) {
        _selectedExerciseIds.remove(exerciseId);
        _selectAll = false;
      } else {
        _selectedExerciseIds.add(exerciseId);
      }
    });
  }



  void _openExercise(DutchWordExercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DutchWordExerciseDetailView(
          wordExercise: exercise,
        ),
      ),
    );
  }

  void _editExercise(DutchWordExercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateWordExerciseView(
          editingExercise: exercise,
        ),
      ),
    );
  }

  void _handleExerciseAction(String action, DutchWordExercise exercise) {
    switch (action) {
      case 'edit':
        _editExercise(exercise);
        break;
      case 'delete':
        _showDeleteExerciseDialog(context, exercise);
        break;
    }
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
    if (_selectedExerciseIds.isEmpty) return;

    final provider = context.read<DutchWordExerciseProvider>();
    final selectedExercises = <DutchWordExercise>[];
    int totalExercises = 0;

    for (final exerciseId in _selectedExerciseIds) {
      final exercise = provider.getWordExercise(exerciseId);
      if (exercise != null) {
        selectedExercises.add(exercise);
        totalExercises += exercise.exercises.length;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Exercises'),
        content: Text(
          'Are you sure you want to delete ${_selectedExerciseIds.length} exercise(s)?\n\n'
          'This will permanently delete $totalExercises individual exercises.\n\n'
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
              _deleteSelectedExercises();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteSelectedExercises() {
    final provider = context.read<DutchWordExerciseProvider>();
    final selectedCount = _selectedExerciseIds.length;
    
    for (final exerciseId in _selectedExerciseIds) {
      provider.deleteWordExercise(exerciseId);
    }
    
    setState(() {
      _selectedExerciseIds.clear();
      _selectAll = false;
      _isSelectionMode = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$selectedCount exercise(s) deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }



  void _navigateToCreateExercise() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateWordExerciseView(),
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
          '• Use the + button to create new exercises',
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