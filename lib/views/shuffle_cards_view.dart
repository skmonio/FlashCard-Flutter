import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../models/flash_card.dart';
import '../models/dutch_word_exercise.dart';
import 'multiple_choice_view.dart';
import 'true_false_view.dart';
import 'memory_game_view.dart';
import 'word_scramble_view.dart';
import 'writing_view.dart';
import 'pop_your_card_view.dart';
import 'pick_your_card_view.dart';
import 'dutch_word_exercise_detail_view.dart';
import '../components/unified_end_screen.dart';
import '../models/learning_mastery.dart';
import '../models/game_session.dart';
import '../services/xp_service.dart';

enum ShuffleMode {
  multipleChoice,
  trueFalse,
  memoryGame,
  wordScramble,
  writing,
  popYourCards,
  pickYourCards,
  dutchExercise,
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
  bool _isTransitioningToNextChallenge = false; // Track if we're transitioning between challenges
  ShuffleMode? _currentMode;
  FlashCard? _currentCard;
  DutchWordExercise? _currentExercise;
  final Random _random = Random();
  
  // XP and card tracking for end screen
  List<FlashCard> _studiedWords = [];
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  final GameSession _gameSession = GameSession();
  
  // Track cards used in current challenge
  List<FlashCard> _currentChallengeCards = [];
  
  // Exercise type customization
  Map<ShuffleMode, bool> _enabledModes = {
    ShuffleMode.multipleChoice: true,
    ShuffleMode.trueFalse: true,
    ShuffleMode.memoryGame: true,
    ShuffleMode.wordScramble: true,
    ShuffleMode.writing: true,
    ShuffleMode.popYourCards: true,
    ShuffleMode.pickYourCards: true,
    ShuffleMode.dutchExercise: true,
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
        ShuffleMode.popYourCards: prefs.getBool('shuffle_mode_pop_your_cards') ?? true,
        ShuffleMode.pickYourCards: prefs.getBool('shuffle_mode_pick_your_cards') ?? true,
        ShuffleMode.dutchExercise: prefs.getBool('shuffle_mode_dutch_exercise') ?? true,
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
    await prefs.setBool('shuffle_mode_pop_your_cards', _enabledModes[ShuffleMode.popYourCards] ?? true);
    await prefs.setBool('shuffle_mode_pick_your_cards', _enabledModes[ShuffleMode.pickYourCards] ?? true);
    await prefs.setBool('shuffle_mode_dutch_exercise', _enabledModes[ShuffleMode.dutchExercise] ?? true);
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
      _isTransitioningToNextChallenge = false;
      // Reset tracking data
      _studiedWords.clear();
      _xpGainedPerWord.clear();
      _wordMastery.clear();
      _gameSession.reset();
      _currentChallengeCards.clear();
    });
    _nextChallenge();
  }

  void _trackCardStudy(FlashCard card, bool wasCorrect) {
    // Track the studied word
    if (!_studiedWords.any((w) => w.id == card.id)) {
      _studiedWords.add(card);
    }
    
    // Mark the card as correct/incorrect to properly record the attempt and reduce HP
    if (wasCorrect) {
      card.markCorrect(GameDifficulty.medium);
    } else {
      card.markIncorrect(GameDifficulty.medium);
    }
    
    // Track XP
    XpService.recordAnswer(_gameSession, wasCorrect);
    
    if (wasCorrect) {
      // Award XP to the word
      final xpService = XpService();
      xpService.addXPToWord(card.learningMastery, "shuffleCards", 1);
      
      // Get the actual XP gained
      final actualXPGained = card.learningMastery.exerciseHistory.isNotEmpty 
          ? card.learningMastery.exerciseHistory.last['xpGained'] as int 
          : 0;
      
      _xpGainedPerWord[card.id] = actualXPGained;
    } else {
      _xpGainedPerWord[card.id] = 0;
    }
    
    // Update mastery tracking
    _wordMastery[card.id] = card.learningMastery;
  }

  void _trackAllCardsFromChallenge(List<FlashCard> cards, bool wasCorrect) {
    // Only the primary (first) card should be counted as studied and have HP/XP adjusted.
    if (cards.isEmpty) return;
    final FlashCard primary = cards.first;

    if (!_studiedWords.any((w) => w.id == primary.id)) {
      _studiedWords.add(primary);
    }

    // Apply correctness to primary card only
    if (wasCorrect) {
      primary.markCorrect(GameDifficulty.medium);
    } else {
      primary.markIncorrect(GameDifficulty.medium);
    }

    // Track XP for primary card
    if (wasCorrect) {
      final xpService = XpService();
      xpService.addXPToWord(primary.learningMastery, "shuffleCards", 1);
      final actualXPGained = primary.learningMastery.exerciseHistory.isNotEmpty
          ? primary.learningMastery.exerciseHistory.last['xpGained'] as int
          : 0;
      _xpGainedPerWord[primary.id] = actualXPGained;
    } else {
      _xpGainedPerWord[primary.id] = 0;
    }

    // Update mastery tracking map for primary only
    _wordMastery[primary.id] = primary.learningMastery;

    // Ensure distractor cards are not mistakenly counted as studied
    for (final distractor in cards.skip(1)) {
      _xpGainedPerWord[distractor.id] = 0; // explicitly zero XP for display purposes
    }

    // Track overall XP toward streaks/session
    XpService.recordAnswer(_gameSession, wasCorrect);
  }

  void _nextChallenge() {
    if (!_isGameActive) return;

    final provider = context.read<FlashcardProvider>();
    final dutchProvider = context.read<DutchWordExerciseProvider>();
    // Get all available cards and exercises
    final allCards = provider.cards;
    final allExercises = dutchProvider.wordExercises;
    
    // Debug logging
    print('🔍 ShuffleCardsView: Available cards: ${allCards.length}');
    print('🔍 ShuffleCardsView: Available exercises: ${allExercises.length}');
    
    if (allCards.isEmpty && allExercises.isEmpty) {
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
      if (_enabledModes[ShuffleMode.popYourCards] == true) {
        availableModes.add(ShuffleMode.popYourCards);
      }
      if (_enabledModes[ShuffleMode.pickYourCards] == true) {
        availableModes.add(ShuffleMode.pickYourCards);
      }
    }
    
    if (allExercises.isNotEmpty && _enabledModes[ShuffleMode.dutchExercise] == true) {
      availableModes.add(ShuffleMode.dutchExercise);
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
      case ShuffleMode.popYourCards:
      case ShuffleMode.pickYourCards:
        // Filter cards that can be studied today (have HP remaining)
        final availableCards = allCards.where((card) => card.canBeStudiedToday).toList();
        
        // Debug logging
        print('🔍 ShuffleCardsView: Pick Your Card - Total cards: ${allCards.length}');
        print('🔍 ShuffleCardsView: Pick Your Card - Available cards: ${availableCards.length}');
        for (int i = 0; i < allCards.length && i < 5; i++) {
          final card = allCards[i];
          print('🔍 ShuffleCardsView: Card ${i + 1}: "${card.word}" - HP: ${card.currentHP}/${card.maxHP}, canBeStudied: ${card.canBeStudiedToday}');
        }
        
        if (availableCards.isEmpty) {
          print('🔍 ShuffleCardsView: Pick Your Card - No available cards, showing game over');
          
          // Create detailed error message
          final totalCards = allCards.length;
          final defeatedCards = allCards.where((card) => card.isDefeated).length;
          final healthyCards = allCards.where((card) => !card.isDefeated).length;
          
          String errorMessage = 'No cards available for this game.\n\n';
          errorMessage += 'Total cards: $totalCards\n';
          errorMessage += 'Healthy cards: $healthyCards\n';
          errorMessage += 'Defeated cards: $defeatedCards\n\n';
          
          if (defeatedCards == totalCards) {
            errorMessage += 'All cards are defeated (0 HP). They need to rest until tomorrow to regain health.';
          } else if (healthyCards < 5) {
            errorMessage += 'You need at least 5 healthy cards to play this game. Currently you have $healthyCards healthy cards.';
          } else {
            errorMessage += 'There seems to be an issue with card availability. Please try again or contact support.';
          }
          
          _showGameOver(errorMessage);
          return;
        }
        
        _currentCard = availableCards[_random.nextInt(availableCards.length)];
        print('🔍 ShuffleCardsView: Pick Your Card - Selected card: "${_currentCard!.word}" with HP: ${_currentCard!.currentHP}/${_currentCard!.maxHP}');
        _launchCardMode(selectedMode);
        break;
      case ShuffleMode.dutchExercise:
        _currentExercise = allExercises[_random.nextInt(allExercises.length)];
        _launchDutchExercise();
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
        
        // Check if current card can be studied today
        if (!_currentCard!.canBeStudiedToday) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This card is defeated (0 HP). It needs to rest until tomorrow to regain health.'),
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
        
        // Add the current card first
        multipleChoiceCards.add(_currentCard!);
        
        // Add 4 more random cards (avoiding duplicates and daily limits)
        final otherCards = allCards.where((card) => 
          card.id != _currentCard!.id && card.canBeStudiedToday).toList();
        final random = Random();
        
        for (int i = 0; i < 4 && i < otherCards.length; i++) {
          final randomCard = otherCards[random.nextInt(otherCards.length)];
          if (!multipleChoiceCards.any((card) => card.id == randomCard.id)) {
            multipleChoiceCards.add(randomCard);
          }
        }
        
        // Store cards for tracking
        _currentChallengeCards = multipleChoiceCards;
        
        targetView = MultipleChoiceView(
          cards: multipleChoiceCards,
          title: 'Multiple Choice',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
        );
        break;
      case ShuffleMode.trueFalse:
        // Check if current card can be studied today
        if (!_currentCard!.canBeStudiedToday) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This card is defeated (0 HP). It needs to rest until tomorrow to regain health.'),
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
        
        // For true/false, we need multiple cards to create false questions
        // Get 5 random cards for variety
        final allCards = context.read<FlashcardProvider>().cards;
        final trueFalseCards = <FlashCard>[];
        
        // Add the current card first
        trueFalseCards.add(_currentCard!);
        
        // Add 4 more random cards (avoiding duplicates and daily limits)
        final otherCards = allCards.where((card) => 
          card.id != _currentCard!.id && card.canBeStudiedToday).toList();
        final random = Random();
        
        for (int i = 0; i < 4 && i < otherCards.length; i++) {
          final randomCard = otherCards[random.nextInt(otherCards.length)];
          if (!trueFalseCards.any((card) => card.id == randomCard.id)) {
            trueFalseCards.add(randomCard);
          }
        }
        
        // Store cards for tracking
        _currentChallengeCards = trueFalseCards;
        
        targetView = TrueFalseView(
          cards: trueFalseCards,
          title: 'True or False',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
        );
        break;
      case ShuffleMode.memoryGame:
        // Check if current card can be studied today
        if (!_currentCard!.canBeStudiedToday) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This card is defeated (0 HP). It needs to rest until tomorrow to regain health.'),
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
        
        // For memory game, we need multiple cards to create pairs
        // Get 5 random cards for the memory game
        final allCards = context.read<FlashcardProvider>().cards;
        final memoryCards = <FlashCard>[];
        
        // Add the current card first
        memoryCards.add(_currentCard!);
        
        // Add 4 more random cards (avoiding duplicates and daily limits)
        final otherCards = allCards.where((card) => 
          card.id != _currentCard!.id && card.canBeStudiedToday).toList();
        final random = Random();
        
        for (int i = 0; i < 4 && i < otherCards.length; i++) {
          final randomCard = otherCards[random.nextInt(otherCards.length)];
          if (!memoryCards.any((card) => card.id == randomCard.id)) {
            memoryCards.add(randomCard);
          }
        }
        
        // Store cards for tracking
        _currentChallengeCards = memoryCards;
        
        targetView = MemoryGameView(
          cards: memoryCards,
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
        );
        break;
      case ShuffleMode.wordScramble:
        // Clear challenge cards for single-card games
        _currentChallengeCards.clear();
        
        targetView = WordScrambleView(
          cards: [_currentCard!],
          title: 'Word Scramble',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
        );
        break;
      case ShuffleMode.writing:
        // Clear challenge cards for single-card games
        _currentChallengeCards.clear();
        
        targetView = WritingView(
          cards: [_currentCard!],
          title: 'Write Your Card',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
          autoProgress: true, // Enable auto progress for shuffle mode
        );
        break;
      case ShuffleMode.popYourCards:
        // Clear challenge cards for single-card games
        _currentChallengeCards.clear();
        
        targetView = PopYourCardView(
          cards: [_currentCard!],
          title: 'Pop Your Card',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
        );
        break;
      case ShuffleMode.pickYourCards:
        // Clear challenge cards for single-card games
        _currentChallengeCards.clear();
        
        targetView = PickYourCardView(
          cards: [_currentCard!],
          title: 'Pick Your Card',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
          autoProgress: true, // Enable auto progress for shuffle mode
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
    ).then((result) {
      // If we return from a child view while game is still active
      // and we're NOT transitioning to the next challenge,
      // it means the user ended the test early - reset game state
      if (_isGameActive && !_isTransitioningToNextChallenge && mounted) {
        setState(() {
          _isGameActive = false;
          _currentScore = 0;
          _currentMode = null;
          _currentCard = null;
          _currentExercise = null;
          _currentChallengeCards.clear();
        });
      }
      // Reset the flag after handling the return
      _isTransitioningToNextChallenge = false;
    });
    // Reset the flag immediately after pushing, as we've successfully started the next challenge
    _isTransitioningToNextChallenge = false;
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
    ).then((result) {
      // If we return from a child view while game is still active
      // and we're NOT transitioning to the next challenge,
      // it means the user ended the test early - reset game state
      if (_isGameActive && !_isTransitioningToNextChallenge && mounted) {
        setState(() {
          _isGameActive = false;
          _currentScore = 0;
          _currentMode = null;
          _currentCard = null;
          _currentExercise = null;
          _currentChallengeCards.clear();
        });
      }
      // Reset the flag after handling the return
      _isTransitioningToNextChallenge = false;
    });
    // Reset the flag immediately after pushing, as we've successfully started the next challenge
    _isTransitioningToNextChallenge = false;
  }


  void _handleCardModeComplete(bool wasCorrect) {
    // Track all cards from the challenge
    if (_currentChallengeCards.isNotEmpty) {
      _trackAllCardsFromChallenge(_currentChallengeCards, wasCorrect);
    } else if (_currentCard != null) {
      // Fallback to single card tracking
      _trackCardStudy(_currentCard!, wasCorrect);
    }
    _handleChallengeComplete(wasCorrect);
  }

  void _handleDutchExerciseComplete(bool wasCorrect) {
    // Track the exercise completion (Dutch exercises don't have cards, so no card tracking)
    _handleChallengeComplete(wasCorrect);
  }


  // For Dutch exercises, we need to track individual question results
  void _handleDutchExerciseQuestionComplete(bool wasCorrect) {
    if (!wasCorrect) {
      if (mounted) {
        Navigator.pop(context);
        // Use a small delay to ensure the pop completes
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _showGameOver('Game Over! You got one wrong.');
          }
        });
      }
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
      if (_isGameActive && mounted) {
        _isTransitioningToNextChallenge = true;
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
      
      // Pop the current game view and show end screen with XP/card tally
      if (mounted) {
        Navigator.pop(context);
        // Use a small delay to ensure the pop completes before showing end screen
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _showShuffleEndScreen('Game Over! You got one wrong.', false);
          }
        });
      }
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
        // Set flag before popping to indicate we're transitioning
        _isTransitioningToNextChallenge = true;
        // Pop the current game view first, then launch next challenge
        Navigator.pop(context);
        // Use a small delay to ensure the pop completes before launching next challenge
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_isGameActive && mounted) {
            _nextChallenge();
          }
        });
      }
    });
  }

  void _showShuffleEndScreen(String message, bool wasSuccessful) {
    final int correct = _currentScore; // number answered correctly
    final int total = wasSuccessful ? _currentScore : _currentScore + 1; // include the wrong one if failed
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UnifiedEndScreen(
          studiedWords: _studiedWords,
          xpGainedPerWord: _xpGainedPerWord,
          wordMastery: _wordMastery,
          title: 'Shuffle Cards Complete',
          showSwipeToReview: false,
          correctAnswers: correct,
          totalQuestions: total,
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close end screen
            _startGame(); // Restart the game
          },
          onDone: () {
            Navigator.of(context).pop(); // Close end screen
            // Stay in shuffle cards view (don't pop again)
          },
        ),
      ),
    );
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
          backgroundColor: Colors.transparent,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
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
        color: Theme.of(context).colorScheme.surface,
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
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Icon(
                    Icons.shuffle,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Shuffle Your Cards',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Description
                Text(
                  'Test your knowledge with a mix of all exercise types!\n'
                  'Get as far as you can without making a mistake.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                      backgroundColor: Colors.grey[600],
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
                    _buildModeToggle('Memory Game', ShuffleMode.memoryGame, Icons.psychology, Colors.grey),
                    _buildModeToggle('Word Scramble', ShuffleMode.wordScramble, Icons.text_fields, Colors.blue),
                    _buildModeToggle('Write Your Card', ShuffleMode.writing, Icons.edit, Colors.blue),
                    _buildModeToggle('Pop Your Card', ShuffleMode.popYourCards, Icons.bubble_chart, Colors.purple),
                    _buildModeToggle('Pick Your Card', ShuffleMode.pickYourCards, Icons.touch_app, Colors.pink),
                    _buildModeToggle('Words', ShuffleMode.dutchExercise, Icons.school, Colors.green),
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
