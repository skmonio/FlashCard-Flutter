import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../components/unified_header.dart';
import '../models/flash_card.dart';
import 'study_view.dart';
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
          'Choose Study Type',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'How would you like to study?',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
    
    // Show deck selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Deck'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: decks.length,
            itemBuilder: (context, index) {
              final deck = decks[index];
              final deckCards = provider.getCardsForDeck(deck.id);
              return ListTile(
                title: Text(deck.name),
                subtitle: Text('${deckCards.length} cards'),
                onTap: () {
                  if (deckCards.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No cards in deck "${deck.name}". Please add some cards first.')),
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                  
                  // Navigate based on game mode
                  switch (widget.gameMode) {
                    case GameMode.study:
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AdvancedStudyView(
                            cards: deckCards,
                            startFlipped: _startFlipped,
                            title: deck.name,
                          ),
                        ),
                      );
                      break;
                    case GameMode.test:
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MultipleChoiceView(
                            cards: deckCards,
                            title: deck.name,
                          ),
                        ),
                      );
                      break;
                    case GameMode.trueFalse:
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TrueFalseView(
                            cards: deckCards,
                            title: deck.name,
                          ),
                        ),
                      );
                      break;
                    case GameMode.write:
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => WritingView(
                            cards: deckCards,
                            title: deck.name,
                          ),
                        ),
                      );
                      break;
                    case GameMode.game:
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MemoryGameView(
                            cards: deckCards,
                            startFlipped: _startFlipped,
                          ),
                        ),
                      );
                      break;
                    case GameMode.bubbleWord:
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => WordScrambleView(
                            cards: deckCards,
                            title: deck.name,
                            startFlipped: _startFlipped,
                          ),
                        ),
                      );
                      break;
                  }
                },
              );
            },
          ),
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
}

 