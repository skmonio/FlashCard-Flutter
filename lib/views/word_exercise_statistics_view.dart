import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dutch_word_exercise_provider.dart';

class WordExerciseStatisticsView extends StatelessWidget {
  const WordExerciseStatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Exercise Statistics'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Consumer<DutchWordExerciseProvider>(
        builder: (context, provider, child) {
          final statistics = provider.getStatistics();
          final deckNames = provider.getDeckNames();
          final decks = provider.getDecks();
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall statistics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall Statistics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow('Total Decks', '${decks.length}'),
                        _buildStatRow('Total Words', '${statistics.totalWordExercises}'),
                        _buildStatRow('Total Exercises', '${statistics.totalQuestions}'),
                        _buildStatRow('User Created', '${statistics.userCreated}'),
                        _buildStatRow('Imported', '${statistics.imported}'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Deck breakdown
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deck Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (decks.isNotEmpty) ...[
                          ...decks.map((deckId) {
                            final deckExercises = provider.getExercisesByDeck(deckId);
                            final totalExercises = deckExercises.fold<int>(0, (sum, exercise) => sum + exercise.exercises.length);
                            
                            return _buildDeckStatRow(
                              deckNames[deckId] ?? deckId,
                              deckExercises.length,
                              totalExercises,
                            );
                          }),
                        ] else ...[
                          const Text(
                            'No decks found',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Category breakdown
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Category Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...statistics.categoryBreakdown.entries.map((entry) {
                          return _buildStatRow(
                            entry.key,
                            '${entry.value} words',
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Difficulty breakdown
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Difficulty Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...statistics.difficultyBreakdown.entries.map((entry) {
                          return _buildStatRow(
                            entry.key,
                            '${entry.value} words',
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Last activity
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow(
                          'Last Activity',
                          _formatDate(statistics.lastActivity),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckStatRow(String deckName, int wordCount, int exerciseCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deckName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$wordCount words • $exerciseCount exercises',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
} 