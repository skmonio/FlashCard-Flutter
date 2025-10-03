import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../views/add_deck_view.dart';
import '../views/add_card_view.dart';
import '../views/create_word_exercise_view.dart';
import '../views/add_phrase_view.dart';

class UniversalAddButton extends StatelessWidget {
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;

  const UniversalAddButton({
    super.key,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showCreateItemDialog(context),
      tooltip: tooltip ?? 'Add New Item',
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      child: const Icon(Icons.add),
    );
  }

  void _showCreateItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What would you like to create?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCreateOption(
              context,
              icon: Icons.folder,
              title: 'New Deck',
              subtitle: 'Create a new deck to organize your cards',
              color: Colors.blue,
              onTap: () {
                Navigator.of(context).pop();
                _navigateToAddDeck(context);
              },
            ),
            const SizedBox(height: 12),
            _buildCreateOption(
              context,
              icon: Icons.style,
              title: 'New Card',
              subtitle: 'Add a new flashcard with word and definition',
              color: Colors.green,
              onTap: () {
                Navigator.of(context).pop();
                _navigateToAddCard(context);
              },
            ),
            const SizedBox(height: 12),
            _buildCreateOption(
              context,
              icon: Icons.quiz,
              title: 'New Exercise',
              subtitle: 'Create a new word exercise for practice',
              color: Colors.orange,
              onTap: () {
                Navigator.of(context).pop();
                _navigateToCreateExercise(context);
              },
            ),
            const SizedBox(height: 12),
            _buildCreateOption(
              context,
              icon: Icons.translate,
              title: 'New Phrase',
              subtitle: 'Add a new phrase with translation',
              color: Colors.purple,
              onTap: () {
                Navigator.of(context).pop();
                _navigateToAddPhrase(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddDeck(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddDeckView(),
      ),
    );
  }

  void _navigateToAddCard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddCardView(),
      ),
    );
  }

  void _navigateToCreateExercise(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateWordExerciseView(),
      ),
    );
  }

  void _navigateToAddPhrase(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddPhraseView(),
      ),
    );
  }
}
