import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/store_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/phrase_provider.dart';
import '../providers/dutch_grammar_provider.dart';
import '../components/unified_header.dart';
import '../models/learning_mastery.dart';

class ClearDataView extends StatefulWidget {
  const ClearDataView({super.key});

  @override
  State<ClearDataView> createState() => _ClearDataViewState();
}

class _ClearDataViewState extends State<ClearDataView> {
  Set<String> _selectedOptions = {};

  void _toggleOption(String option) {
    setState(() {
      if (_selectedOptions.contains(option)) {
        _selectedOptions.remove(option);
      } else {
        _selectedOptions.add(option);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedOptions = {
        'cards',
        'decks',
        'exercises',
        'phrases',
        'stats',
        'everything',
      };
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedOptions.clear();
    });
  }

  Future<void> _executeClear() async {
    if (_selectedOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one option to clear'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Clear Data'),
        content: Text(
          'Are you sure you want to clear the selected data? This action cannot be undone.\n\n'
          'Selected: ${_getSelectedOptionsText()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (_selectedOptions.contains('everything') || _selectedOptions.contains('cards')) {
        await _clearAllCards();
      }
      
      if (_selectedOptions.contains('everything') || _selectedOptions.contains('decks')) {
        await _clearAllDecks();
      }
      
      if (_selectedOptions.contains('everything') || _selectedOptions.contains('exercises')) {
        await _clearAllExercises();
      }
      
      if (_selectedOptions.contains('everything') || _selectedOptions.contains('phrases')) {
        await _clearAllPhrases();
      }
      
      if (_selectedOptions.contains('everything') || _selectedOptions.contains('stats')) {
        await _clearAllStats();
      }

      if (mounted) {
        String message = 'Cleared: ';
        if (_selectedOptions.contains('everything')) {
          message = 'All data cleared successfully';
        } else {
          List<String> cleared = [];
          if (_selectedOptions.contains('cards')) cleared.add('cards');
          if (_selectedOptions.contains('decks')) cleared.add('decks');
          if (_selectedOptions.contains('exercises')) cleared.add('exercises');
          if (_selectedOptions.contains('phrases')) cleared.add('phrases');
          if (_selectedOptions.contains('stats')) cleared.add('stats & progress');
          message += cleared.join(', ');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getSelectedOptionsText() {
    List<String> options = [];
    if (_selectedOptions.contains('cards')) options.add('All Cards');
    if (_selectedOptions.contains('decks')) options.add('All Decks');
    if (_selectedOptions.contains('exercises')) options.add('All Exercises');
    if (_selectedOptions.contains('phrases')) options.add('All Phrases');
    if (_selectedOptions.contains('stats')) options.add('Stats & Progress');
    if (_selectedOptions.contains('everything')) options.add('Everything');
    return options.join(', ');
  }

  Future<void> _clearAllCards() async {
    final flashcardProvider = context.read<FlashcardProvider>();
    
    // Clear all cards
    final cards = List.from(flashcardProvider.cards);
    for (final card in cards) {
      await flashcardProvider.deleteCard(card.id);
    }
  }

  Future<void> _clearAllDecks() async {
    final flashcardProvider = context.read<FlashcardProvider>();
    
    // Clear all decks (except default ones)
    final decks = List.from(flashcardProvider.decks);
    for (final deck in decks) {
      if (deck.name != 'Uncategorized' && deck.name != 'Default') {
        await flashcardProvider.deleteDeck(deck.id);
      }
    }
  }

  Future<void> _clearAllExercises() async {
    try {
      final dutchProvider = context.read<DutchWordExerciseProvider>();
      await dutchProvider.clearAllExercises();
    } catch (e) {
      print('DutchWordExerciseProvider not available: $e');
    }
  }

  Future<void> _clearAllPhrases() async {
    try {
      final phraseProvider = context.read<PhraseProvider>();
      final phrases = List.from(phraseProvider.phrases);
      for (final phrase in phrases) {
        await phraseProvider.deletePhrase(phrase.id);
      }
    } catch (e) {
      print('PhraseProvider not available: $e');
    }
  }

  Future<void> _clearAllStats() async {
    try {
      final userProfileProvider = context.read<UserProfileProvider>();
      await userProfileProvider.resetXpAndProgress();
    } catch (e) {
      print('UserProfileProvider not available: $e');
    }
    
    try {
      final storeProvider = context.read<StoreProvider>();
      await storeProvider.clearAllUnlockedPacks();
    } catch (e) {
      print('StoreProvider not available: $e');
    }
    
    try {
      final grammarProvider = context.read<DutchGrammarProvider>();
      grammarProvider.resetProgress();
    } catch (e) {
      print('DutchGrammarProvider not available: $e');
    }
    
    // Clear individual word RPG progress (XP and learning mastery)
    try {
      final flashcardProvider = context.read<FlashcardProvider>();
      final cards = List.from(flashcardProvider.cards);
      for (final card in cards) {
        // Reset the learning mastery for each card
        final resetMastery = LearningMastery(
          easyCorrect: 0,
          mediumCorrect: 0,
          hardCorrect: 0,
          expertCorrect: 0,
          easyAttempts: 0,
          mediumAttempts: 0,
          hardAttempts: 0,
          expertAttempts: 0,
          currentXP: 0,
          currentLevel: 1,
          levelUpHistory: [],
          exerciseHistory: [],
          dailyGameAttempts: {},
          lastGameResetDate: null,
        );
        
        final updatedCard = card.copyWith(learningMastery: resetMastery);
        await flashcardProvider.updateCard(updatedCard);
      }
    } catch (e) {
      print('Error clearing word RPG progress: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
          UnifiedHeader(
            title: 'Clear Data',
            onBack: () => Navigator.of(context).pop(),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.red[700],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Warning: This action cannot be undone. Please select carefully what you want to clear.',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Select All / Clear All buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectAll,
                          icon: const Icon(Icons.select_all),
                          label: const Text('Select All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearSelection,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear All'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Options
                  _buildOptionTile(
                    'cards',
                    'All Cards',
                    'Delete all flashcards',
                    Icons.style,
                    Colors.blue,
                  ),
                  _buildOptionTile(
                    'decks',
                    'All Decks',
                    'Delete all custom decks',
                    Icons.folder,
                    Colors.indigo,
                  ),
                  _buildOptionTile(
                    'exercises',
                    'All Exercises',
                    'Delete all Dutch word exercises',
                    Icons.quiz,
                    Colors.green,
                  ),
                  _buildOptionTile(
                    'phrases',
                    'All Phrases',
                    'Delete all phrases',
                    Icons.translate,
                    Colors.teal,
                  ),
                  _buildOptionTile(
                    'stats',
                    'Stats & Progress',
                    'Reset XP, levels, achievements, and word RPG progress',
                    Icons.analytics,
                    Colors.orange,
                  ),
                  _buildOptionTile(
                    'everything',
                    'Everything',
                    'Clear all data (cards, decks, exercises, phrases, stats)',
                    Icons.delete_forever,
                    Colors.red,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Clear Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedOptions.isNotEmpty ? _executeClear : null,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Clear Selected Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    String option,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedOptions.contains(option);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        value: isSelected,
        onChanged: (bool? value) {
          _toggleOption(option);
        },
        secondary: Icon(
          icon,
          color: color,
          size: 24,
        ),
        activeColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
