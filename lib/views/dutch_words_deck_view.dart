import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dutch_word_exercise.dart';
import '../providers/dutch_word_exercise_provider.dart';
import 'dutch_word_exercise_detail_view.dart';
import 'dutch_words_practice_view.dart';

class DutchWordsDeckView extends StatefulWidget {
  final String deckId;
  final String deckName;
  final List<DutchWordExercise> exercises;

  const DutchWordsDeckView({
    super.key,
    required this.deckId,
    required this.deckName,
    required this.exercises,
  });

  @override
  State<DutchWordsDeckView> createState() => _DutchWordsDeckViewState();
}

class _DutchWordsDeckViewState extends State<DutchWordsDeckView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<DutchWordExerciseProvider>(
      builder: (context, provider, child) {
        final exercises = provider.getExercisesByDeck(widget.deckId);
        print('🔍 DutchWordsDeckView: Fetching exercises for deckId: "${widget.deckId}", deckName: "${widget.deckName}"');
        print('🔍 DutchWordsDeckView: Found ${exercises.length} exercises');
        for (final exercise in exercises) {
          print('🔍 DutchWordsDeckView: Exercise - Word: "${exercise.targetWord}", DeckId: "${exercise.deckId}", DeckName: "${exercise.deckName}"');
        }
        
        final filteredExercises = _getFilteredExercises(exercises);

        // If no exercises in deck, show empty state
        if (exercises.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.deckName),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            body: _buildEmptyState(),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.deckName),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () {
                  // TODO: Start practice mode for all words in deck
                  _showPracticeModeDialog(exercises);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search words in this deck...',
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
              ),
              
              // Words list
              Expanded(
                child: filteredExercises.isEmpty
                    ? _buildEmptyState()
                    : _buildWordsList(filteredExercises),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWordsList(List<DutchWordExercise> exercises) {
    // Debug logging
    print('🔍 DutchWordsDeckView: Building list with ${exercises.length} exercises');
    for (int i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      print('🔍 DutchWordsDeckView: Exercise $i - Word: "${exercise.targetWord}", ID: "${exercise.id}"');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
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
                  '${_calculateWordLearningPercentage(exercise)}%',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            title: Text(
              exercise.targetWord,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.wordTranslation),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${exercise.exercises.length} exercises',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildMasteryIndicator(exercise.learningProgress.masteryLevel),
                    if (exercise.learningProgress.nextReviewDate.isBefore(DateTime.now()))
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Review',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteWordDialog(context, exercise),
                ),
                const Icon(Icons.arrow_forward_ios),
              ],
            ),
            onTap: () {
              print('🔍 DutchWordsDeckView: Tapped on word "${exercise.targetWord}" with ID "${exercise.id}"');
              
              // Use word name lookup instead of ID to avoid collisions
              final provider = context.read<DutchWordExerciseProvider>();
              final wordExercise = provider.getWordExerciseByWord(exercise.targetWord);
              
              if (wordExercise != null) {
                print('🔍 DutchWordsDeckView: Found exercise by word name: "${wordExercise.targetWord}" with ID "${wordExercise.id}"');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DutchWordExerciseDetailView(
                      wordExercise: wordExercise,
                      showEditDeleteButtons: false,
                    ),
                  ),
                );
              } else {
                print('🔍 DutchWordsDeckView: No exercise found for word "${exercise.targetWord}"');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not find exercises for "${exercise.targetWord}"'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        );
      },
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
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No words found in this deck',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or add more words to this deck',
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

  List<DutchWordExercise> _getFilteredExercises(List<DutchWordExercise> exercises) {
    if (_searchQuery.isEmpty) {
      return exercises;
    }
    
    return exercises.where((exercise) {
      return exercise.targetWord.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             exercise.wordTranslation.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  int _calculateWordLearningPercentage(DutchWordExercise exercise) {
    // Use real learning progress data
    final percentage = exercise.learningProgress.learningPercentage.round();
    print('🔍 Deck view: Word "${exercise.targetWord}" has ${percentage}% (correct: ${exercise.learningProgress.correctAnswers}, total: ${exercise.learningProgress.totalAttempts})');
    return percentage;
  }

  Widget _buildMasteryIndicator(int masteryLevel) {
    final colors = [
      Colors.grey,    // Level 0
      Colors.red,     // Level 1
      Colors.orange,  // Level 2
      Colors.yellow,  // Level 3
      Colors.lightGreen, // Level 4
      Colors.green,   // Level 5
    ];
    
    final color = colors[masteryLevel.clamp(0, 5)];
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 1),
          decoration: BoxDecoration(
            color: index < masteryLevel ? color : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  void _showDeleteWordDialog(BuildContext context, DutchWordExercise exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word'),
        content: Text(
          'Are you sure you want to delete "${exercise.targetWord}"?\n\n'
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
              _deleteWord(exercise);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteWord(DutchWordExercise exercise) {
    final provider = context.read<DutchWordExerciseProvider>();
    provider.deleteWordExercise(exercise.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${exercise.targetWord}" deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showPracticeModeDialog(List<DutchWordExercise> exercises) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Practice Mode'),
        content: Text('Practice all ${exercises.length} words in "${widget.deckName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DutchWordsPracticeView(
                    deckId: widget.deckId,
                    deckName: widget.deckName,
                    exercises: exercises,
                  ),
                ),
              );
            },
            child: const Text('Start Practice'),
          ),
        ],
      ),
    );
  }
} 