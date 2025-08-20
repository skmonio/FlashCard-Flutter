import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/phrase_provider.dart';
import '../models/phrase.dart';
import 'phrase_exercise_detail_view.dart';

class PhrasesListView extends StatefulWidget {
  const PhrasesListView({super.key});

  @override
  State<PhrasesListView> createState() => _PhrasesListViewState();
}

class _PhrasesListViewState extends State<PhrasesListView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrases'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Consumer<PhraseProvider>(
        builder: (context, phraseProvider, child) {
          final phrases = phraseProvider.phrases;
          
          if (phrases.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.translate,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No phrases yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add your first phrase to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return Column(
            children: [
              // Statistics card
              _buildStatisticsCard(phrases),
              
              // Phrases list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: phrases.length,
                  itemBuilder: (context, index) {
                    final phrase = phrases[index];
                    return _buildPhraseCard(phrase);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatisticsCard(List<Phrase> phrases) {
    final totalPhrases = phrases.length;
    final newPhrases = phrases.where((p) => p.isNew).length;
    final duePhrases = phrases.where((p) => p.isDueForReview).length;
    final learnedPhrases = phrases.where((p) => p.learningPercentage >= 100).length;
    
    final averageProgress = phrases.isEmpty 
        ? 0 
        : phrases.map((p) => p.learningPercentage).reduce((a, b) => a + b) / phrases.length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: Colors.teal,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Phrases Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Total', totalPhrases.toString(), Colors.teal),
              ),
              Expanded(
                child: _buildStatItem('New', newPhrases.toString(), Colors.orange),
              ),
              Expanded(
                child: _buildStatItem('Due', duePhrases.toString(), Colors.red),
              ),
              Expanded(
                child: _buildStatItem('Learned', learnedPhrases.toString(), Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Avg Progress', '${averageProgress.toInt()}%', Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPhraseCard(Phrase phrase) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _openPhraseExercise(phrase),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phrase and translation
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            phrase.phrase,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phrase.translation,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Learning percentage
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getProgressColor(phrase.learningPercentage).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getProgressColor(phrase.learningPercentage).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${phrase.learningPercentage.toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getProgressColor(phrase.learningPercentage),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Progress bar
                LinearProgressIndicator(
                  value: phrase.learningPercentage / 100,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(phrase.learningPercentage),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Status and actions
                Row(
                  children: [
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(phrase).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getStatusText(phrase),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getStatusColor(phrase),
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Menu button
                    PopupMenuButton<String>(
                      onSelected: (action) => _handlePhraseAction(action, phrase),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'practice',
                          child: Row(
                            children: [
                              Icon(Icons.play_arrow),
                              SizedBox(width: 8),
                              Text('Practice'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
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

  Color _getProgressColor(num percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    if (percentage >= 40) return Colors.yellow;
    return Colors.red;
  }

  Color _getStatusColor(Phrase phrase) {
    if (phrase.isNew) return Colors.blue;
    if (phrase.isDueForReview) return Colors.red;
    if (phrase.learningPercentage >= 100) return Colors.green;
    return Colors.orange;
  }

  String _getStatusText(Phrase phrase) {
    if (phrase.isNew) return 'New';
    if (phrase.isDueForReview) return 'Due';
    if (phrase.learningPercentage >= 100) return 'Learned';
    return 'Learning';
  }

  void _openPhraseExercise(Phrase phrase) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhraseExerciseDetailView(
          phrase: phrase,
          onComplete: (wasSuccessful) {
            // Optionally show a success message or update UI
            if (wasSuccessful) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Great job! Keep practicing!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _handlePhraseAction(String action, Phrase phrase) {
    switch (action) {
      case 'practice':
        _openPhraseExercise(phrase);
        break;
      case 'edit':
        // TODO: Implement edit phrase functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Edit functionality coming soon!'),
          ),
        );
        break;
      case 'delete':
        _showDeleteConfirmation(phrase);
        break;
    }
  }

  void _showDeleteConfirmation(Phrase phrase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Phrase'),
        content: Text('Are you sure you want to delete "${phrase.phrase}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePhrase(phrase);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deletePhrase(Phrase phrase) {
    final phraseProvider = context.read<PhraseProvider>();
    phraseProvider.deletePhrase(phrase.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${phrase.phrase}"'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
