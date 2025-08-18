import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/dutch_grammar_provider.dart';
import '../models/flash_card.dart';
import '../models/dutch_word_exercise.dart';
import '../models/dutch_grammar_rule.dart';
import 'multiple_choice_view.dart';
import 'true_false_view.dart';
import 'memory_game_view.dart';
import 'word_scramble_view.dart';
import 'writing_view.dart';
import 'dutch_word_exercise_detail_view.dart';
import 'dutch_grammar_exercise_view.dart';

enum ShuffleMode {
  multipleChoice,
  trueFalse,
  memoryGame,
  wordScramble,
  writing,
  dutchExercise,
  grammarExercise,
}

class ShuffleCardsView extends StatefulWidget {
  const ShuffleCardsView({super.key});

  @override
  State<ShuffleCardsView> createState() => _ShuffleCardsViewState();
}

class _ShuffleCardsViewState extends State<ShuffleCardsView> {
  int _currentScore = 0;
  int _highScore = 0;
  bool _isGameActive = false;
  ShuffleMode? _currentMode;
  FlashCard? _currentCard;
  DutchWordExercise? _currentExercise;
  GrammarExercise? _currentGrammarExercise;
  DutchGrammarRule? _currentGrammarRule;
  final Random _random = Random();
  
  // Exercise type customization
  Map<ShuffleMode, bool> _enabledModes = {
    ShuffleMode.multipleChoice: true,
    ShuffleMode.trueFalse: true,
    ShuffleMode.memoryGame: true,
    ShuffleMode.wordScramble: true,
    ShuffleMode.writing: true,
    ShuffleMode.dutchExercise: true,
    ShuffleMode.grammarExercise: true,
  };

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _loadEnabledModes();
  }

  void _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('shuffle_high_score') ?? 0;
    });
  }

  void _loadEnabledModes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabledModes = {
        ShuffleMode.multipleChoice: prefs.getBool('shuffle_mode_multiple_choice') ?? true,
        ShuffleMode.trueFalse: prefs.getBool('shuffle_mode_true_false') ?? true,
        ShuffleMode.memoryGame: prefs.getBool('shuffle_mode_memory_game') ?? true,
        ShuffleMode.wordScramble: prefs.getBool('shuffle_mode_word_scramble') ?? true,
        ShuffleMode.writing: prefs.getBool('shuffle_mode_writing') ?? true,
        ShuffleMode.dutchExercise: prefs.getBool('shuffle_mode_dutch_exercise') ?? true,
        ShuffleMode.grammarExercise: prefs.getBool('shuffle_mode_grammar_exercise') ?? true,
      };
    });
  }

  void _saveEnabledModes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shuffle_mode_multiple_choice', _enabledModes[ShuffleMode.multipleChoice] ?? true);
    await prefs.setBool('shuffle_mode_true_false', _enabledModes[ShuffleMode.trueFalse] ?? true);
    await prefs.setBool('shuffle_mode_memory_game', _enabledModes[ShuffleMode.memoryGame] ?? true);
    await prefs.setBool('shuffle_mode_word_scramble', _enabledModes[ShuffleMode.wordScramble] ?? true);
    await prefs.setBool('shuffle_mode_writing', _enabledModes[ShuffleMode.writing] ?? true);
    await prefs.setBool('shuffle_mode_dutch_exercise', _enabledModes[ShuffleMode.dutchExercise] ?? true);
    await prefs.setBool('shuffle_mode_grammar_exercise', _enabledModes[ShuffleMode.grammarExercise] ?? true);
  }

  void _saveHighScore() async {
    if (_currentScore > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('shuffle_high_score', _currentScore);
      setState(() {
        _highScore = _currentScore;
      });
    }
  }

  void _startGame() {
    setState(() {
      _currentScore = 0;
      _isGameActive = true;
    });
    _nextChallenge();
  }

  void _nextChallenge() {
    if (!_isGameActive) return;

    final provider = context.read<FlashcardProvider>();
    final dutchProvider = context.read<DutchWordExerciseProvider>();
    final grammarProvider = context.read<DutchGrammarProvider>();
    
    // Get all available cards and exercises
    final allCards = provider.cards;
    final allExercises = dutchProvider.wordExercises;
    final allGrammarRules = grammarProvider.allRules;
    final allGrammarExercises = <GrammarExercise>[];
    
    // Collect all grammar exercises from all rules
    for (final rule in allGrammarRules) {
      allGrammarExercises.addAll(rule.exercises);
    }
    
    // Debug logging
    print('🔍 ShuffleCardsView: Available cards: ${allCards.length}');
    print('🔍 ShuffleCardsView: Available exercises: ${allExercises.length}');
    print('🔍 ShuffleCardsView: Available grammar rules: ${allGrammarRules.length}');
    print('🔍 ShuffleCardsView: Available grammar exercises: ${allGrammarExercises.length}');
    
    if (allCards.isEmpty && allExercises.isEmpty && allGrammarExercises.isEmpty) {
      _showGameOver('No cards or exercises available!');
      return;
    }

    // Randomly select a mode from enabled modes only
    final availableModes = <ShuffleMode>[];
    
    if (allCards.isNotEmpty) {
      if (_enabledModes[ShuffleMode.multipleChoice] == true) {
        availableModes.add(ShuffleMode.multipleChoice);
      }
      if (_enabledModes[ShuffleMode.trueFalse] == true) {
        availableModes.add(ShuffleMode.trueFalse);
      }
      if (_enabledModes[ShuffleMode.memoryGame] == true) {
        availableModes.add(ShuffleMode.memoryGame);
      }
      if (_enabledModes[ShuffleMode.wordScramble] == true) {
        availableModes.add(ShuffleMode.wordScramble);
      }
      if (_enabledModes[ShuffleMode.writing] == true) {
        availableModes.add(ShuffleMode.writing);
      }
    }
    
    if (allExercises.isNotEmpty && _enabledModes[ShuffleMode.dutchExercise] == true) {
      availableModes.add(ShuffleMode.dutchExercise);
    }
    
    if (allGrammarExercises.isNotEmpty && _enabledModes[ShuffleMode.grammarExercise] == true) {
      availableModes.add(ShuffleMode.grammarExercise);
    }

    if (availableModes.isEmpty) {
      _showGameOver('No content available!');
      return;
    }

    final selectedMode = availableModes[_random.nextInt(availableModes.length)];
    
    // Debug logging
    print('🔍 ShuffleCardsView: Selected mode: $selectedMode');
    print('🔍 ShuffleCardsView: Available modes: $availableModes');
    
    setState(() {
      _currentMode = selectedMode;
    });

    switch (selectedMode) {
      case ShuffleMode.multipleChoice:
      case ShuffleMode.trueFalse:
      case ShuffleMode.memoryGame:
      case ShuffleMode.wordScramble:
      case ShuffleMode.writing:
        _currentCard = allCards[_random.nextInt(allCards.length)];
        _launchCardMode(selectedMode);
        break;
      case ShuffleMode.dutchExercise:
        _currentExercise = allExercises[_random.nextInt(allExercises.length)];
        _launchDutchExercise();
        break;
      case ShuffleMode.grammarExercise:
        _currentGrammarExercise = allGrammarExercises[_random.nextInt(allGrammarExercises.length)];
        _launchGrammarExercise();
        break;
    }
  }

  void _launchCardMode(ShuffleMode mode) {
    if (_currentCard == null) return;

    Widget targetView;
    switch (mode) {
      case ShuffleMode.multipleChoice:
        // For multiple choice, we need multiple cards to create meaningful wrong options
        // Get 5 random cards for variety
        final allCards = context.read<FlashcardProvider>().cards;
        final multipleChoiceCards = <FlashCard>[];
        
        // Add the current card first
        multipleChoiceCards.add(_currentCard!);
        
        // Add 4 more random cards (avoiding duplicates)
        final otherCards = allCards.where((card) => card.id != _currentCard!.id).toList();
        final random = Random();
        
        for (int i = 0; i < 4 && i < otherCards.length; i++) {
          final randomCard = otherCards[random.nextInt(otherCards.length)];
          if (!multipleChoiceCards.any((card) => card.id == randomCard.id)) {
            multipleChoiceCards.add(randomCard);
          }
        }
        
        targetView = MultipleChoiceView(
          cards: multipleChoiceCards,
          title: 'Multiple Choice',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
        );
        break;
      case ShuffleMode.trueFalse:
        // For true/false, we need multiple cards to create false questions
        // Get 5 random cards for variety
        final allCards = context.read<FlashcardProvider>().cards;
        final trueFalseCards = <FlashCard>[];
        
        // Add the current card first
        trueFalseCards.add(_currentCard!);
        
        // Add 4 more random cards (avoiding duplicates)
        final otherCards = allCards.where((card) => card.id != _currentCard!.id).toList();
        final random = Random();
        
        for (int i = 0; i < 4 && i < otherCards.length; i++) {
          final randomCard = otherCards[random.nextInt(otherCards.length)];
          if (!trueFalseCards.any((card) => card.id == randomCard.id)) {
            trueFalseCards.add(randomCard);
          }
        }
        
        targetView = TrueFalseView(
          cards: trueFalseCards,
          title: 'True or False',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
        );
        break;
      case ShuffleMode.memoryGame:
        // For memory game, we need multiple cards to create pairs
        // Get 5 random cards for the memory game
        final allCards = context.read<FlashcardProvider>().cards;
        final memoryCards = <FlashCard>[];
        
        // Add the current card first
        memoryCards.add(_currentCard!);
        
        // Add 4 more random cards (avoiding duplicates)
        final otherCards = allCards.where((card) => card.id != _currentCard!.id).toList();
        final random = Random();
        
        for (int i = 0; i < 4 && i < otherCards.length; i++) {
          final randomCard = otherCards[random.nextInt(otherCards.length)];
          if (!memoryCards.any((card) => card.id == randomCard.id)) {
            memoryCards.add(randomCard);
          }
        }
        
        targetView = MemoryGameView(
          cards: memoryCards,
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
        );
        break;
      case ShuffleMode.wordScramble:
        targetView = WordScrambleView(
          cards: [_currentCard!],
          title: 'Word Scramble',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
        );
        break;
      case ShuffleMode.writing:
        targetView = WritingView(
          cards: [_currentCard!],
          title: 'Write Your Card',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
        );
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => targetView,
      ),
    );
  }

  void _launchDutchExercise() {
    if (_currentExercise == null) return;

    // For shuffle mode, we'll create a single-question version
    // by modifying the exercise to only have one question
    final singleQuestionExercise = DutchWordExercise(
      id: _currentExercise!.id,
      targetWord: _currentExercise!.targetWord,
      wordTranslation: _currentExercise!.wordTranslation,
      deckId: _currentExercise!.deckId,
      deckName: _currentExercise!.deckName,
      category: _currentExercise!.category,
      difficulty: _currentExercise!.difficulty,
      exercises: [_currentExercise!.exercises.first], // Only use the first exercise
      createdAt: _currentExercise!.createdAt,
      isUserCreated: _currentExercise!.isUserCreated,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DutchWordExerciseDetailView(
          wordExercise: singleQuestionExercise,
          showEditDeleteButtons: false,
          onComplete: _handleDutchExerciseComplete,
          singleQuestionMode: true,
        ),
      ),
    );
  }

  void _launchGrammarExercise() {
    if (_currentGrammarExercise == null) return;

    // Find the rule that contains this exercise
    final grammarProvider = context.read<DutchGrammarProvider>();
    DutchGrammarRule? containingRule;
    
    for (final rule in grammarProvider.allRules) {
      if (rule.exercises.contains(_currentGrammarExercise)) {
        containingRule = rule;
        break;
      }
    }

    if (containingRule == null) return;

    // Create a single exercise view for shuffle mode
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DutchGrammarExerciseView(
          exercises: [_currentGrammarExercise!],
          ruleTitle: containingRule?.title ?? 'Grammar Exercise',
          ruleId: containingRule?.id ?? 'unknown',
          onComplete: _handleGrammarExerciseComplete,
          shuffleMode: true,
        ),
      ),
    );
  }

  void _handleCardModeComplete(bool wasCorrect) {
    _handleChallengeComplete(wasCorrect);
  }

  void _handleDutchExerciseComplete(bool wasCorrect) {
    _handleChallengeComplete(wasCorrect);
  }

  void _handleGrammarExerciseComplete(bool wasCorrect) {
    _handleChallengeComplete(wasCorrect);
  }

  // For Dutch exercises, we need to track individual question results
  void _handleDutchExerciseQuestionComplete(bool wasCorrect) {
    if (!wasCorrect) {
      Navigator.pop(context);
      _showGameOver('Game Over! You got one wrong.');
      return;
    }

    setState(() {
      _currentScore++;
    });

    // Show success message briefly
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Correct! Score: $_currentScore'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    // Wait a moment then continue to next challenge
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_isGameActive) {
        _nextChallenge();
      }
    });
  }

  void _handleChallengeComplete(bool wasCorrect) {
    if (!wasCorrect) {
      // Set game inactive and save high score first
      setState(() {
        _isGameActive = false;
      });
      _saveHighScore();
      
      // Pop the current game view and show game over immediately
      Navigator.pop(context);
      _showGameOver('Game Over! You got one wrong.');
      return;
    }

    setState(() {
      _currentScore++;
    });

    // Show success message briefly before next challenge
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Correct! Score: $_currentScore'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 400), // Even faster duration
      ),
    );

    // Much faster transition to next challenge
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isGameActive && mounted) {
        // Pop the current game view first
        Navigator.pop(context);
        // Then immediately launch the next challenge
        _nextChallenge();
      }
    });
  }

  void _showGameOver(String message) {
    // Note: _saveHighScore() and _isGameActive = false are now called before this method
    // to ensure proper state management

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text('Final Score: $_currentScore'),
            if (_currentScore > 0) ...[
              const SizedBox(height: 8),
              Text(
                _currentScore > _highScore ? 'New High Score! 🎉' : 'High Score: $_highScore',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _currentScore > _highScore ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Back to Home'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Reset game state when user goes back
        if (_isGameActive) {
          setState(() {
            _isGameActive = false;
            _currentScore = 0;
            _currentMode = null;
            _currentCard = null;
            _currentExercise = null;
          });
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shuffle'),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Reset game state when user goes back
              if (_isGameActive) {
                setState(() {
                  _isGameActive = false;
                  _currentScore = 0;
                  _currentMode = null;
                  _currentCard = null;
                  _currentExercise = null;
                });
              }
              Navigator.of(context).pop();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showCustomizationDialog,
            ),
          ],
        ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Game Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Icon(
                    Icons.shuffle,
                    size: 60,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                const Text(
                  'Shuffle Your Cards',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Description
                const Text(
                  'Test your knowledge with a mix of all exercise types!\n'
                  'Get as far as you can without making a mistake.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                
                // High Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'High Score: $_highScore',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Start Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isGameActive ? null : _startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _isGameActive ? 'Game in Progress...' : 'Start Shuffle',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Current Score (if game is active)
                if (_isGameActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Current Score: $_currentScore',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ] else ...[
                  // Enabled modes summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.settings, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Enabled Exercise Types:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _buildEnabledModeChips(),
                        ),
                      ],
                    ),
                  ),
                ],
                

              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  void _showCustomizationDialog() {
    showDialog(
      context: context,
      builder: (context) => ShuffleCustomizationDialog(
        enabledModes: Map.from(_enabledModes),
        onSettingsChanged: (newEnabledModes) {
          setState(() {
            _enabledModes = newEnabledModes;
          });
          _saveEnabledModes();
        },
      ),
    );
  }

  List<Widget> _buildEnabledModeChips() {
    final enabledCount = _enabledModes.values.where((enabled) => enabled).length;
    final totalCount = _enabledModes.length;
    
    if (enabledCount == totalCount) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Text(
            'All Types Enabled',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ];
    } else if (enabledCount == 0) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Text(
            'No Types Enabled',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ];
    } else {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Text(
            '$enabledCount of $totalCount Types',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ];
    }
  }
}

// Separate stateful widget for the customization dialog
class ShuffleCustomizationDialog extends StatefulWidget {
  final Map<ShuffleMode, bool> enabledModes;
  final Function(Map<ShuffleMode, bool>) onSettingsChanged;

  const ShuffleCustomizationDialog({
    super.key,
    required this.enabledModes,
    required this.onSettingsChanged,
  });

  @override
  State<ShuffleCustomizationDialog> createState() => _ShuffleCustomizationDialogState();
}

class _ShuffleCustomizationDialogState extends State<ShuffleCustomizationDialog> {
  late Map<ShuffleMode, bool> _localEnabledModes;

  @override
  void initState() {
    super.initState();
    _localEnabledModes = Map.from(widget.enabledModes);
  }

  void _updateMode(ShuffleMode mode, bool value) {
    setState(() {
      _localEnabledModes[mode] = value;
    });
    widget.onSettingsChanged(_localEnabledModes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Customize Exercise Types'),
      content: SizedBox(
        width: double.maxFinite,
        height: 350, // Reduced height to prevent overflow
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select which exercise types to include in shuffle mode:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildModeToggle('Multiple Choice', ShuffleMode.multipleChoice, Icons.check_circle, Colors.teal),
                    _buildModeToggle('True or False', ShuffleMode.trueFalse, Icons.help_outline, Colors.orange),
                    _buildModeToggle('Memory Game', ShuffleMode.memoryGame, Icons.psychology, Colors.purple),
                    _buildModeToggle('Word Scramble', ShuffleMode.wordScramble, Icons.text_fields, Colors.blue),
                    _buildModeToggle('Write Your Card', ShuffleMode.writing, Icons.edit, Colors.blue),
                    _buildModeToggle('Words', ShuffleMode.dutchExercise, Icons.school, Colors.green),
                    _buildModeToggle('Grammar', ShuffleMode.grammarExercise, Icons.book, Colors.indigo),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildModeToggle(String title, ShuffleMode mode, IconData icon, Color color) {
    return SwitchListTile(
      dense: true, // Make the tiles more compact
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
      value: _localEnabledModes[mode] ?? true,
      onChanged: (value) => _updateMode(mode, value),
    );
  }
}
