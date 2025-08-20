import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/phrase_provider.dart';
import '../models/phrase.dart';
import 'add_phrase_view.dart';
import 'phrase_exercise_view.dart';

class PhrasesView extends StatefulWidget {
  const PhrasesView({super.key});

  @override
  State<PhrasesView> createState() => _PhrasesViewState();
}

class _PhrasesViewState extends State<PhrasesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhraseProvider>().loadPhrases();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrases'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              final phraseProvider = context.read<PhraseProvider>();
              final randomPhrase = phraseProvider.getRandomPhraseForExercise();
              if (randomPhrase != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PhraseExerciseView(phrase: randomPhrase),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No phrases available for practice')),
                );
              }
            },
            tooltip: 'Practice Phrases',
          ),
        ],
      ),
      body: Consumer<PhraseProvider>(
        builder: (context, phraseProvider, child) {
          final phrases = phraseProvider.phrases;
          final stats = phraseProvider.getStatistics();

          if (phrases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.translate,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No phrases yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first phrase to get started!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToAddPhrase(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Phrase'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Statistics Card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Statistics',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            Icons.analytics,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              'Total',
                              stats['total'].toString(),
                              Icons.list,
                            ),
                          ),
                          Expanded(
                            child: _buildStatItem(
                              'New',
                              stats['new'].toString(),
                              Icons.new_releases,
                              color: Colors.orange,
                            ),
                          ),
                          Expanded(
                            child: _buildStatItem(
                              'Due',
                              stats['dueForReview'].toString(),
                              Icons.schedule,
                              color: Colors.red,
                            ),
                          ),
                          Expanded(
                            child: _buildStatItem(
                              'Learned',
                              stats['fullyLearned'].toString(),
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: stats['averagePercentage'] / 100,
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Average Progress: ${stats['averagePercentage'].toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),

              // Phrases List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: phrases.length,
                  itemBuilder: (context, index) {
                    final phrase = phrases[index];
                    return _buildPhraseCard(phrase, context);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddPhrase(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(
          icon,
          color: color ?? Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPhraseCard(Phrase phrase, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          phrase.phrase,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              phrase.translation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: phrase.learningPercentage / 100,
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(phrase.learningPercentage),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${phrase.learningPercentage}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handlePhraseAction(value, phrase, context),
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
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhraseExerciseView(phrase: phrase),
            ),
          );
        },
      ),
    );
  }

  Color _getProgressColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    if (percentage >= 40) return Colors.yellow.shade700;
    return Colors.red;
  }

  void _navigateToAddPhrase(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPhraseView()),
    );
  }

  void _handlePhraseAction(String action, Phrase phrase, BuildContext context) {
    switch (action) {
      case 'practice':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhraseExerciseView(phrase: phrase),
          ),
        );
        break;
      case 'edit':
        _showEditDialog(context, phrase);
        break;
      case 'delete':
        _showDeleteDialog(context, phrase);
        break;
    }
  }

  void _showEditDialog(BuildContext context, Phrase phrase) {
    final phraseController = TextEditingController(text: phrase.phrase);
    final translationController = TextEditingController(text: phrase.translation);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Phrase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phraseController,
              decoration: const InputDecoration(
                labelText: 'Dutch Phrase',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: translationController,
              decoration: const InputDecoration(
                labelText: 'English Translation',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<PhraseProvider>().updatePhrase(
                phrase.id,
                phraseController.text.trim(),
                translationController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Phrase phrase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Phrase'),
        content: Text('Are you sure you want to delete "${phrase.phrase}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<PhraseProvider>().deletePhrase(phrase.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
