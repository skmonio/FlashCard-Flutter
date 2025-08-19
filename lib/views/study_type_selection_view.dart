import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../components/unified_header.dart';
import '../models/flash_card.dart';
import '../models/deck.dart';

import 'advanced_study_view.dart';
import 'multiple_choice_view.dart';
import 'true_false_view.dart';
import 'writing_view.dart';
import 'memory_game_view.dart';
import 'word_scramble_view.dart';

enum GameMode {
  study,
  test,
  trueFalse,
  write,
  game,
  bubbleWord,
}

class StudyTypeSelectionView extends StatefulWidget {
  final GameMode gameMode;
  
  const StudyTypeSelectionView({
    super.key,
    required this.gameMode,
  });

  @override
  State<StudyTypeSelectionView> createState() => _StudyTypeSelectionViewState();
}

class _StudyTypeSelectionViewState extends State<StudyTypeSelectionView> {
  int _selectedCardCount = 10;
  bool _startFlipped = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
          UnifiedHeader(
            title: 'Study Type',
            onBack: () => Navigator.of(context).pop(),
            trailing: IconButton(
              onPressed: () => _showGameInfo(context),
              icon: const Icon(Icons.info, color: Colors.blue),
            ),
          ),
          
          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 32),
                  
                  // Study Type Options
                  _buildStudyTypeOptions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'How would you like to study?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStudyTypeOptions() {
    return Column(
      children: [
        // Quick Study Option
        _buildStudyTypeCard(
          'Quick Study',
          'Random cards from all decks',
          'Perfect for quick practice sessions',
          Icons.flash_on,
          Colors.orange,
          () => _navigateToQuickStudy(),
        ),

        
        // Normal Study Option
        _buildStudyTypeCard(
          'Normal Study',
          'Choose specific decks',
          'Focused study on selected topics',
          Icons.folder,
          Colors.blue,
          () => _navigateToNormalStudy(),
        ),
        
        // Timed Study Option - only for memory games
        if (widget.gameMode == GameMode.game) ...[
          const SizedBox(height: 20),
          _buildStudyTypeCard(
            'Timed Study',
            'Race against the clock',
            'Complete challenges before time runs out',
            Icons.timer,
            Colors.red,
            () => _navigateToTimedStudy(),
          ),
        ],
        const SizedBox(height: 20),
        
        // Card count selector (for all modes)
        _buildCardCountSelector(),
        
        // Start Flipped toggle (for study and test modes)
        if (widget.gameMode == GameMode.study || widget.gameMode == GameMode.test || widget.gameMode == GameMode.trueFalse)
          _buildStartFlippedToggle(),
      ],
    );
  }

  Widget _buildStudyTypeCard(
    String title,
    String subtitle,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardCountSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_numbered, size: 20),
              const SizedBox(width: 12),
              const Text(
                'Number of Cards',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _selectedCardCount.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: '$_selectedCardCount',
                  onChanged: (value) {
                    setState(() {
                      _selectedCardCount = value.round();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$_selectedCardCount',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartFlippedToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.flip, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start Flipped',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Show translation first, then word',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _startFlipped,
            onChanged: (value) {
              setState(() {
                _startFlipped = value;
              });
            },
          ),
        ],
      ),
    );
  }

  void _navigateToQuickStudy() {
    final provider = context.read<FlashcardProvider>();
    final allCards = provider.cards;
    
    if (allCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available. Please add some cards first.')),
      );
      return;
    }
    
    // Shuffle and take a subset of cards for quick study
    final shuffledCards = List<FlashCard>.from(allCards)..shuffle();
    final studyCards = shuffledCards.take(_selectedCardCount).toList();
    
    // Navigate based on game mode
    switch (widget.gameMode) {
      case GameMode.study:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AdvancedStudyView(
              cards: studyCards,
              startFlipped: _startFlipped,
              title: 'Quick Study',
            ),
          ),
        );
        break;
      case GameMode.test:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MultipleChoiceView(
              cards: studyCards,
              title: 'Quick Test',
            ),
          ),
        );
        break;
      case GameMode.trueFalse:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TrueFalseView(
              cards: studyCards,
              title: 'Quick True or False',
            ),
          ),
        );
        break;
      case GameMode.write:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WritingView(
              cards: studyCards,
              title: 'Quick Write',
            ),
          ),
        );
        break;
      case GameMode.game:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MemoryGameView(
              cards: studyCards,
              startFlipped: _startFlipped,
            ),
          ),
        );
        break;
      case GameMode.bubbleWord:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WordScrambleView(
              cards: studyCards,
              title: 'Quick Jumble',
              startFlipped: _startFlipped,
            ),
          ),
        );
        break;
    }
  }



  void _navigateToNormalStudy() {
    final provider = context.read<FlashcardProvider>();
    final decks = provider.getAllDecksHierarchical();
    
    if (decks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No decks available. Please create some decks first.')),
      );
      return;
    }
    
    // Show multi-deck selection dialog
    showDialog(
      context: context,
      builder: (context) => _MultiDeckSelectionDialog(
        decks: decks,
        provider: provider,
        gameMode: widget.gameMode,
        startFlipped: _startFlipped,
        selectedCardCount: _selectedCardCount,
      ),
    );
  }

  void _showGameInfo(BuildContext context) {
    String title = '';
    String content = '';
    
    switch (widget.gameMode) {
      case GameMode.study:
        title = 'Study Mode';
        content = 'Practice with your flashcards using spaced repetition learning.';
        break;
      case GameMode.test:
        title = 'Test Mode';
        content = 'Challenge yourself with multiple choice questions to assess your knowledge.';
        break;
      case GameMode.trueFalse:
        title = 'True or False Mode';
        content = 'Test your knowledge with true or false questions about translations.';
        break;
      case GameMode.write:
        title = 'Write Mode';
        content = 'Practice writing translations with a hangman-style game.';
        break;
      case GameMode.game:
        title = 'Memory Game';
        content = 'Match pairs of cards to improve your memory and recognition.';
        break;
      case GameMode.bubbleWord:
        title = 'Jumble Mode';
        content = 'Arrange scrambled letters to form the correct translation.';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _navigateToTimedStudy() {
    final provider = context.read<FlashcardProvider>();
    final allCards = provider.cards;
    
    if (allCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available. Please add some cards first.')),
      );
      return;
    }
    
    // Show difficulty selection dialog
    _showTimedDifficultyDialog(allCards);
  }

  void _showTimedDifficultyDialog(List<FlashCard> allCards) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Difficulty'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select the difficulty level for your timed challenge:'),
            SizedBox(height: 16),
            Text('• Easy: Relaxed pace with plenty of time'),
            Text('• Medium: Balanced challenge'),
            Text('• Hard: Race against the clock'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTimedStudy(allCards, 'easy');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Easy - 8 seconds per pair'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTimedStudy(allCards, 'medium');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Medium - 5 seconds per pair'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTimedStudy(allCards, 'hard');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hard - 3 seconds per pair'),
          ),
        ],
      ),
    );
  }

  void _startTimedStudy(List<FlashCard> allCards, String difficulty) {
    // Calculate time based on difficulty and card count
    int secondsPerPair;
    switch (difficulty) {
      case 'easy':
        secondsPerPair = 8; // 8 seconds per pair - relaxed pace
        break;
      case 'medium':
        secondsPerPair = 5; // 5 seconds per pair - balanced challenge
        break;
      case 'hard':
        secondsPerPair = 3; // 3 seconds per pair - challenging but achievable
        break;
      default:
        secondsPerPair = 5;
    }
    
    // Shuffle and take a subset of cards
    final shuffledCards = List<FlashCard>.from(allCards)..shuffle();
    final studyCards = shuffledCards.take(_selectedCardCount).toList();
    
    // Calculate total time (5 pairs = 10 cards, so 5 pairs * secondsPerPair)
    final totalPairs = (studyCards.length / 2).ceil();
    final totalTimeSeconds = totalPairs * secondsPerPair;
    
    // Navigate to memory game with timed mode
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MemoryGameView(
          cards: studyCards,
          startFlipped: _startFlipped,
          timedMode: true,
          timeLimitSeconds: totalTimeSeconds,
          difficulty: difficulty,
        ),
      ),
    );
  }
}

class _MultiDeckSelectionDialog extends StatefulWidget {
  final List<Deck> decks;
  final FlashcardProvider provider;
  final GameMode gameMode;
  final bool startFlipped;
  final int selectedCardCount;

  const _MultiDeckSelectionDialog({
    required this.decks,
    required this.provider,
    required this.gameMode,
    required this.startFlipped,
    required this.selectedCardCount,
  });

  @override
  State<_MultiDeckSelectionDialog> createState() => _MultiDeckSelectionDialogState();
}

class _MultiDeckSelectionDialogState extends State<_MultiDeckSelectionDialog> {
  final Set<String> _selectedDeckIds = {};
  int _totalSelectedCards = 0;

  @override
  void initState() {
    super.initState();
    _calculateTotalCards();
  }

  void _calculateTotalCards() {
    _totalSelectedCards = 0;
    for (final deckId in _selectedDeckIds) {
      final deck = widget.decks.firstWhere((d) => d.id == deckId);
      final deckCards = widget.provider.getCardsForDeck(deck.id);
      _totalSelectedCards += deckCards.length;
    }
  }

  void _toggleDeckSelection(String deckId) {
    setState(() {
      if (_selectedDeckIds.contains(deckId)) {
        _selectedDeckIds.remove(deckId);
      } else {
        _selectedDeckIds.add(deckId);
      }
      _calculateTotalCards();
    });
  }

  void _startStudy() {
    if (_selectedDeckIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one deck.')),
      );
      return;
    }

    // Collect all cards from selected decks
    List<FlashCard> allSelectedCards = [];
    List<String> selectedDeckNames = [];
    
    for (final deckId in _selectedDeckIds) {
      final deck = widget.decks.firstWhere((d) => d.id == deckId);
      final deckCards = widget.provider.getCardsForDeck(deck.id);
      allSelectedCards.addAll(deckCards);
      selectedDeckNames.add(deck.name);
    }

    if (allSelectedCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available in selected decks.')),
      );
      return;
    }

    // Shuffle and limit cards if needed
    allSelectedCards.shuffle();
    if (allSelectedCards.length > widget.selectedCardCount) {
      allSelectedCards = allSelectedCards.take(widget.selectedCardCount).toList();
    }

    Navigator.of(context).pop();

    // Create title from selected deck names
    String title = selectedDeckNames.length == 1 
        ? selectedDeckNames.first 
        : '${selectedDeckNames.length} Decks';

    // Navigate based on game mode
    switch (widget.gameMode) {
      case GameMode.study:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AdvancedStudyView(
              cards: allSelectedCards,
              startFlipped: widget.startFlipped,
              title: title,
            ),
          ),
        );
        break;
      case GameMode.test:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MultipleChoiceView(
              cards: allSelectedCards,
              title: title,
            ),
          ),
        );
        break;
      case GameMode.trueFalse:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TrueFalseView(
              cards: allSelectedCards,
              title: title,
            ),
          ),
        );
        break;
      case GameMode.write:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WritingView(
              cards: allSelectedCards,
              title: title,
            ),
          ),
        );
        break;
      case GameMode.game:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MemoryGameView(
              cards: allSelectedCards,
              startFlipped: widget.startFlipped,
            ),
          ),
        );
        break;
      case GameMode.bubbleWord:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WordScrambleView(
              cards: allSelectedCards,
              title: title,
              startFlipped: widget.startFlipped,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Decks'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Summary of selected decks
            if (_selectedDeckIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedDeckIds.length} deck${_selectedDeckIds.length == 1 ? '' : 's'} selected • $_totalSelectedCards cards',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedDeckIds.isNotEmpty) const SizedBox(height: 16),
            
            // Deck list
            Expanded(
              child: ListView.builder(
                itemCount: widget.decks.length,
                itemBuilder: (context, index) {
                  final deck = widget.decks[index];
                  final deckCards = widget.provider.getCardsForDeck(deck.id);
                  final isSelected = _selectedDeckIds.contains(deck.id);
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: CheckboxListTile(
                      title: Text(deck.name),
                      subtitle: Text('${deckCards.length} cards'),
                      value: isSelected,
                      onChanged: (bool? value) {
                        _toggleDeckSelection(deck.id);
                      },
                      secondary: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? Colors.blue : Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedDeckIds.isNotEmpty ? _startStudy : null,
          child: const Text('Start Study'),
        ),
      ],
    );
  }
}

 