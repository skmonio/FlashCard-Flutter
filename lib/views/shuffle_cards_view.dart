import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/deck.dart';
import '../models/flash_card.dart';
import 'multiple_choice_view.dart';
import 'true_false_view.dart';
import 'memory_game_view.dart';
import 'word_scramble_view.dart';
import 'writing_view.dart';
import 'pop_your_card_view.dart';
import 'pick_your_card_view.dart';
import 'so_many_cards_view.dart';
import 'sentence_building_view.dart';
import 'de_het_view.dart';
import '../utils/game_end_screen.dart';
import '../models/learning_mastery.dart';
import '../models/game_session.dart';
import '../services/xp_service.dart';
import '../components/main_header.dart';

enum ShuffleMode {
  multipleChoice,
  trueFalse,
  memoryGame,
  wordScramble,
  writing,
  popYourCards,
  pickYourCards,
  soManyCards,
  sentenceBuilding,
  deHet,
}

class ShuffleCardsView extends StatefulWidget {
  const ShuffleCardsView({super.key});

  @override
  State<ShuffleCardsView> createState() => _ShuffleCardsViewState();
}

class _ShuffleCardsViewState extends State<ShuffleCardsView> {
  int _currentScore = 0;
  int _highScore = 0;
  int _totalQuestionsAsked = 0; // Track total questions asked across all challenges
  bool _isGameActive = false;
  bool _isTransitioningToNextChallenge = false; // Track if we're transitioning between challenges
  bool _isShowingEndScreen = false; // Track if we're showing/hiding the end screen
  ShuffleMode? _currentMode;
  FlashCard? _currentCard;
  final Random _random = Random();
  
  // XP and card tracking for end screen
  List<FlashCard> _studiedWords = [];
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  Map<String, int> _initialHPPerWord = {}; // Track initial HP when word is first encountered
  final GameSession _gameSession = GameSession();
  
  // Track cards used in current challenge
  List<FlashCard> _currentChallengeCards = [];
  
  // Track challenge sequence for "Study Again" retry
  List<Map<String, dynamic>> _challengeSequence = []; // Stores mode, card ID, and exercise ID for each challenge
  int _currentSequenceIndex = 0;
  bool _isRetryingSameSequence = false;
  
  // Exercise type customization
  Map<ShuffleMode, bool> _enabledModes = {
    ShuffleMode.multipleChoice: true,
    ShuffleMode.trueFalse: true,
    ShuffleMode.memoryGame: true,
    ShuffleMode.wordScramble: true,
    ShuffleMode.writing: true,
    ShuffleMode.popYourCards: true,
    ShuffleMode.pickYourCards: true,
    ShuffleMode.soManyCards: true,
    ShuffleMode.sentenceBuilding: true,
    ShuffleMode.deHet: true,
  };

  bool _oneAnswerMode = false; // Use 1-click answer mode across shuffle challenges (disabled by default)
  Set<String> _selectedDeckIds = {}; // Track selected decks for shuffle mode

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
        ShuffleMode.soManyCards: prefs.getBool('shuffle_mode_so_many_cards') ?? true,
        ShuffleMode.sentenceBuilding: prefs.getBool('shuffle_mode_sentence_building') ?? true,
        ShuffleMode.deHet: prefs.getBool('shuffle_mode_de_het') ?? true,
      };
      _oneAnswerMode = prefs.getBool('shuffle_one_answer_mode') ?? true;
    });
  }
 
  void _saveEnabledModes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shuffle_one_answer_mode', _oneAnswerMode);
    await prefs.setBool('shuffle_mode_multiple_choice', _enabledModes[ShuffleMode.multipleChoice] ?? true);
    await prefs.setBool('shuffle_mode_true_false', _enabledModes[ShuffleMode.trueFalse] ?? true);
    await prefs.setBool('shuffle_mode_memory_game', _enabledModes[ShuffleMode.memoryGame] ?? true);
    await prefs.setBool('shuffle_mode_word_scramble', _enabledModes[ShuffleMode.wordScramble] ?? true);
    await prefs.setBool('shuffle_mode_writing', _enabledModes[ShuffleMode.writing] ?? true);
    await prefs.setBool('shuffle_mode_pop_your_cards', _enabledModes[ShuffleMode.popYourCards] ?? true);
    await prefs.setBool('shuffle_mode_pick_your_cards', _enabledModes[ShuffleMode.pickYourCards] ?? true);
    await prefs.setBool('shuffle_mode_so_many_cards', _enabledModes[ShuffleMode.soManyCards] ?? true);
    await prefs.setBool('shuffle_mode_sentence_building', _enabledModes[ShuffleMode.sentenceBuilding] ?? true);
    await prefs.setBool('shuffle_mode_de_het', _enabledModes[ShuffleMode.deHet] ?? true);
  }

  List<FlashCard> _getAnswerPoolCards(FlashCard primaryCard) {
    final provider = context.read<FlashcardProvider>();
    return _selectedDeckIds.isEmpty
        ? provider.cards
        : _selectedDeckIds.expand((id) => provider.getCardsForDeckWithSubDecks(id)).toSet().toList();
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

  void _startGame({bool useSameSequence = false, List<FlashCard>? filteredCards}) {
    setState(() {
      _currentScore = 0;
      _totalQuestionsAsked = 0;
      _isGameActive = true;
      _isTransitioningToNextChallenge = false;
      // Reset tracking data
      _studiedWords.clear();
      _xpGainedPerWord.clear();
      _wordMastery.clear();
      _initialHPPerWord.clear();
      _gameSession.reset();
      _currentChallengeCards.clear();
      
      // If filtered cards were provided (from the end screen), use only those
      if (filteredCards != null) {
        _challengeSequence.clear();
        _isRetryingSameSequence = false;
        _currentSequenceIndex = 0;
      } else if (useSameSequence && _challengeSequence.isNotEmpty) {
        // For "Study Again" - retry the same sequence
        _isRetryingSameSequence = true;
        _currentSequenceIndex = 0;
      } else {
        // For "Shuffle" - start a new random sequence
        _challengeSequence.clear();
        _isRetryingSameSequence = false;
        _currentSequenceIndex = 0;
      }
    });
    _nextChallenge();
  }

  FlashCard _resolveCardForTracking(FlashCard card) {
    if (card.id.isEmpty) {
      return card;
    }
    final provider = context.read<FlashcardProvider>();
    return provider.getCard(card.id) ?? card;
  }

  void _trackCardStudy(FlashCard card, bool wasCorrect) {
    final trackedCard = _resolveCardForTracking(card);
    
    // Track the studied word
    if (!_studiedWords.any((w) => w.id == trackedCard.id)) {
      _studiedWords.add(trackedCard);
    }
    
    if (!_initialHPPerWord.containsKey(trackedCard.id)) {
      final assumedInitialHp = min(trackedCard.maxHP, trackedCard.currentHP + 1);
      _initialHPPerWord[trackedCard.id] = assumedInitialHp;
    }
    
    // In shuffle mode, HP was already reduced by child views when answer was given
    // We just need to track XP for the summary (don't reduce HP again)
    if (wasCorrect) {
      // HP was already reduced by child view calling markCorrect
      // Get the XP that was already awarded
      final actualXPGained = trackedCard.learningMastery.exerciseHistory.isNotEmpty 
          ? trackedCard.learningMastery.exerciseHistory.last['xpGained'] as int 
          : 0;
      
      _xpGainedPerWord[trackedCard.id] = actualXPGained;
    } else {
      // HP was already reduced by child view calling markIncorrect + recordAttemptToWord
      _xpGainedPerWord[trackedCard.id] = 0;
    }
    
    // Track XP for session stats
    XpService.recordAnswer(_gameSession, wasCorrect);
    
    // Update mastery tracking
    _wordMastery[trackedCard.id] = trackedCard.learningMastery;
  }

  void _trackAllCardsFromChallenge(List<FlashCard> cards, bool wasCorrect) {
    if (cards.isEmpty) return;
    final FlashCard primary = cards.first;
    _trackCardStudy(primary, wasCorrect);

    // Ensure distractor cards are not mistakenly counted as studied
    for (final distractor in cards.skip(1)) {
      if (!_xpGainedPerWord.containsKey(distractor.id)) {
        _xpGainedPerWord[distractor.id] = 0;
      }
    }
  }

  Future<void> _nextChallenge() async {
    if (!_isGameActive) return;

    // If retrying same sequence, use the saved challenge
    if (_isRetryingSameSequence && _currentSequenceIndex < _challengeSequence.length) {
      final savedChallenge = _challengeSequence[_currentSequenceIndex];
      _currentSequenceIndex++;
      
      setState(() {
        _currentMode = ShuffleMode.values[savedChallenge['mode'] as int];
      });
      
      if (savedChallenge['cardId'] != null) {
        final provider = context.read<FlashcardProvider>();
        final cardId = savedChallenge['cardId'] as String;
        
        // Try to find the original card
        final originalCard = provider.cards.firstWhere(
          (card) => card.id == cardId,
          orElse: () => FlashCard(
            id: '',
            word: '',
            definition: '',
            example: '',
            deckIds: {},
            dateCreated: DateTime.now(),
            learningMastery: LearningMastery(),
            article: '',
            plural: '',
            presentTense: '',
            pastTense: '',
            perfectTense: '',
          ),
        );
        
        // Check if original card exists and has HP
        if (originalCard.id.isNotEmpty && originalCard.canBeStudiedToday) {
          _currentCard = originalCard;
          _launchCardMode(_currentMode!);
        } else {
          // Original card has 0 HP or doesn't exist, try to find a replacement
          final baseCards = _selectedDeckIds.isEmpty
              ? provider.cards
              : _selectedDeckIds.expand((id) => provider.getCardsForDeckWithSubDecks(id)).toSet().toList();
          final availableCards = baseCards.where((card) => card.canBeStudiedToday).toList();
          
          if (availableCards.isEmpty) {
            // No cards with HP available - show message and end game
            setState(() {
              _isGameActive = false;
            });
            _showSetupRequiredDialog('All cards in this sequence have 0 HP and need to rest until tomorrow to regain health.');
            return;
          } else {
            // Use a replacement card with HP
            _currentCard = availableCards[_random.nextInt(availableCards.length)];
            // Show message that some cards couldn't be used
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Some cards in this sequence have 0 HP and were skipped. Using a replacement card.'),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.orange,
              ),
            );
            _launchCardMode(_currentMode!);
          }
        }
      }
      return;
    }

    final provider = context.read<FlashcardProvider>();

    // Get all available cards (respecting deck filter)
    final allCards = _selectedDeckIds.isEmpty
        ? provider.cards
        : _selectedDeckIds.expand((id) => provider.getCardsForDeckWithSubDecks(id)).toSet().toList();

    // Debug logging
    print('🔍 ShuffleCardsView: Available cards: ${allCards.length}');

    if (allCards.isEmpty) {
      _showSetupRequiredDialog('No cards available. Please add some cards to play.');
      return;
    }

    // Select a card that can be studied today
    final studyableCards = allCards.where((card) => card.canBeStudiedToday).toList();
    if (studyableCards.isEmpty) {
      _showSetupRequiredDialog('All cards have 0 HP and need to rest until tomorrow to regain health.');
      return;
    }
    _currentCard = studyableCards[_random.nextInt(studyableCards.length)];

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
      if (_enabledModes[ShuffleMode.soManyCards] == true) {
        availableModes.add(ShuffleMode.soManyCards);
      }
      if (_enabledModes[ShuffleMode.sentenceBuilding] == true) {
        availableModes.add(ShuffleMode.sentenceBuilding);
      }
      if (_enabledModes[ShuffleMode.deHet] == true) {
        availableModes.add(ShuffleMode.deHet);
      }
    }


    if (availableModes.isEmpty) {
      _showSetupRequiredDialog('All game modes are disabled or no content is available. Please enable some game modes in settings or add cards/exercises.');
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
      case ShuffleMode.soManyCards:
      case ShuffleMode.sentenceBuilding:
      case ShuffleMode.deHet:
        _launchCardMode(selectedMode);
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
        final answerPool = _getAnswerPoolCards(_currentCard!);
        final multipleChoiceCards = <FlashCard>[];
        
        // Check if current card can be studied today (safety check)
        if (!_currentCard!.canBeStudiedToday) {
          // This shouldn't happen since we filter cards before selecting, but handle it gracefully
          setState(() {
            _isGameActive = false;
          });
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
        
        // Add 3 more random cards for 4 total options (1 correct + 3 wrong)
        final otherCards = answerPool.where((card) => 
          card.id != _currentCard!.id && card.canBeStudiedToday).toList();
        final random = Random();
        
        for (int i = 0; i < 3 && i < otherCards.length; i++) {
          final randomCard = otherCards[random.nextInt(otherCards.length)];
          if (!multipleChoiceCards.any((card) => card.id == randomCard.id)) {
            multipleChoiceCards.add(randomCard);
          }
        }
        
        // Store cards for tracking
        _currentChallengeCards = multipleChoiceCards;
        
        setState(() {
          _totalQuestionsAsked++;
        });
        targetView = MultipleChoiceView(
          cards: multipleChoiceCards,
          title: 'Multiple Choice',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
          shuffleQuestionOffset: _totalQuestionsAsked - 1,
          oneAnswerMode: _oneAnswerMode,
          enableHints: false,
        );
        break;
      case ShuffleMode.trueFalse:
        // Check if current card can be studied today (safety check)
        if (!_currentCard!.canBeStudiedToday) {
          // This shouldn't happen since we filter cards before selecting, but handle it gracefully
          setState(() {
            _isGameActive = false;
          });
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
        final answerPool = _getAnswerPoolCards(_currentCard!);
        final trueFalseCards = <FlashCard>[];
        
        // Add the current card first
        trueFalseCards.add(_currentCard!);
        
        // Add 4 more random cards (avoiding duplicates and daily limits)
        final otherCards = answerPool.where((card) => 
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
        
        setState(() {
          _totalQuestionsAsked++;
        });
        targetView = TrueFalseView(
          cards: trueFalseCards,
          title: 'True or False',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
          shuffleQuestionOffset: _totalQuestionsAsked - 1,
          oneAnswerMode: _oneAnswerMode,
          enableHints: false,
        );
        break;
      case ShuffleMode.memoryGame:
        // Check if current card can be studied today (safety check)
        if (!_currentCard!.canBeStudiedToday) {
          // This shouldn't happen since we filter cards before selecting, but handle it gracefully
          setState(() {
            _isGameActive = false;
          });
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
        final answerPool = _getAnswerPoolCards(_currentCard!);
        final memoryCards = <FlashCard>[];
        
        // Add the current card first
        memoryCards.add(_currentCard!);
        
        // Add 4 more random cards (avoiding duplicates and daily limits)
        final otherCards = answerPool.where((card) => 
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
        
        setState(() {
          _totalQuestionsAsked++;
        });
        targetView = MemoryGameView(
          cards: memoryCards,
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
          shuffleQuestionOffset: _totalQuestionsAsked - 1,
        );
        break;
      case ShuffleMode.wordScramble:
        // Clear challenge cards for single-card games
        _currentChallengeCards.clear();
        
        setState(() {
          _totalQuestionsAsked++;
        });
        targetView = WordScrambleView(
          cards: [_currentCard!],
          title: 'Word Scramble',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
          shuffleQuestionOffset: _totalQuestionsAsked - 1,
          oneAnswerMode: _oneAnswerMode,
          enableHints: false,
        );
        break;
      case ShuffleMode.writing:
        // Clear challenge cards for single-card games
        _currentChallengeCards.clear();
        
        setState(() {
          _totalQuestionsAsked++;
        });
        targetView = WritingView(
          cards: [_currentCard!],
          title: 'Write Your Card',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
          autoProgress: true, // Enable auto progress for shuffle mode
          useLivesMode: false, // No lives in shuffle mode - one wrong letter ends the game
          shuffleQuestionOffset: _totalQuestionsAsked - 1,
          oneAnswerMode: _oneAnswerMode,
          enableHints: false,
        );
        break;
      case ShuffleMode.popYourCards:
        // Clear challenge cards for single-card games
        _currentChallengeCards.clear();
        
        setState(() {
          _totalQuestionsAsked++;
        });
        targetView = PopYourCardView(
          cards: [_currentCard!],
          title: 'Pop Your Card',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
          shuffleQuestionOffset: _totalQuestionsAsked - 1,
          oneAnswerMode: _oneAnswerMode,
        );
        break;
      case ShuffleMode.pickYourCards:
        // Clear challenge cards for single-card games
        _currentChallengeCards.clear();

        setState(() {
          _totalQuestionsAsked++;
        });
        targetView = PickYourCardView(
          cards: [_currentCard!],
          title: 'Pick Your Card',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
          autoProgress: true, // Enable auto progress for shuffle mode
          shuffleQuestionOffset: _totalQuestionsAsked - 1,
          oneAnswerMode: _oneAnswerMode,
          enableHints: false,
        );
        break;
      case ShuffleMode.soManyCards:
        _currentChallengeCards.clear();
        setState(() { _totalQuestionsAsked++; });
        targetView = SoManyCardsView(
          cards: [_currentCard!],
          title: 'So Many Cards',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
          oneAnswerMode: _oneAnswerMode,
        );
        break;
      case ShuffleMode.sentenceBuilding:
        _currentChallengeCards.clear();
        // Only proceed if card has example sentence
        if (_currentCard!.example.isEmpty) {
          _nextChallenge();
          return;
        }
        setState(() { _totalQuestionsAsked++; });
        targetView = SentenceBuildingView(
          cards: [_currentCard!],
          title: 'Sentence Builder',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
          autoProgress: true,
          oneAnswerMode: _oneAnswerMode,
          enableHints: false,
        );
        break;
      case ShuffleMode.deHet:
        _currentChallengeCards.clear();
        // Only proceed if card has de/het article
        if (_currentCard!.article != 'de' && _currentCard!.article != 'het') {
          _nextChallenge();
          return;
        }
        setState(() { _totalQuestionsAsked++; });
        targetView = DeHetView(
          cards: [_currentCard!],
          title: 'De or Het?',
          onComplete: _handleCardModeComplete,
          shuffleMode: true,
        );
        break;
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
    print('🔍 ShuffleCardsView: _handleCardModeComplete called with wasCorrect: $wasCorrect');
    // Track all cards from the challenge
    if (_currentChallengeCards.isNotEmpty) {
      _trackAllCardsFromChallenge(_currentChallengeCards, wasCorrect);
    } else if (_currentCard != null) {
      // Fallback to single card tracking
      _trackCardStudy(_currentCard!, wasCorrect);
    }
    _handleChallengeComplete(wasCorrect);
  }

  void _handleChallengeComplete(bool wasCorrect) {
    print('🔍 ShuffleCardsView: _handleChallengeComplete called with wasCorrect: $wasCorrect, _isGameActive: $_isGameActive');
    if (!wasCorrect) {
      // Set game inactive and save high score first
      setState(() {
        _isGameActive = false;
      });
      _saveHighScore();
      
      // Pop the current game view and show end screen with XP/card tally
      if (mounted) {
        print('🔍 ShuffleCardsView: Popping view for incorrect answer');
        // Set flag to hide body during transition
        setState(() {
          _isShowingEndScreen = true;
        });
        // Pop the current game view and immediately push end screen to avoid showing shuffle screen
        Navigator.pop(context);
        // Use a minimal delay to ensure pop completes, then immediately show end screen
        Future.delayed(const Duration(milliseconds: 50), () async {
          if (mounted) {
            await _finalizeSession();
            _showShuffleEndScreen('Game Over! You got one wrong.', false);
          }
        });
      }
      return;
    }

    setState(() {
      _currentScore++;
    });

    print('🔍 ShuffleCardsView: Correct answer - Score: $_currentScore, preparing to navigate to next challenge');

    // Show success message briefly before next challenge
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Correct! Score: $_currentScore'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 400), // Even faster duration
      ),
    );

    // Set flag immediately to prevent .then() callback from resetting game state
    _isTransitioningToNextChallenge = true;
    
    // Much faster transition to next challenge
    Future.delayed(const Duration(milliseconds: 500), () {
      print('🔍 ShuffleCardsView: Delay completed - _isGameActive: $_isGameActive, mounted: $mounted');
      if (_isGameActive && mounted) {
        print('🔍 ShuffleCardsView: Popping current view and preparing next challenge');
        // Pop the current game view first, then launch next challenge
        Navigator.pop(context);
        // Use a delay to ensure the pop completes before launching next challenge
        Future.delayed(const Duration(milliseconds: 100), () {
          print('🔍 ShuffleCardsView: About to call _nextChallenge - _isGameActive: $_isGameActive, mounted: $mounted');
          if (_isGameActive && mounted) {
            _nextChallenge();
          } else {
            print('⚠️ ShuffleCardsView: Cannot call _nextChallenge - _isGameActive: $_isGameActive, mounted: $mounted');
          }
        });
      } else {
        print('⚠️ ShuffleCardsView: Cannot proceed - _isGameActive: $_isGameActive, mounted: $mounted');
        _isTransitioningToNextChallenge = false;
      }
    });
  }

  Future<void> _finalizeSession() async {
    if (!mounted) return;
    final userProvider = context.read<UserProfileProvider>();
    final totalXP = _xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp);
    if (totalXP > 0) await userProvider.addXp(totalXP);
    final accuracy = _gameSession.totalAnswers > 0
        ? _gameSession.correctAnswers / _gameSession.totalAnswers
        : 0.0;
    await userProvider.updateSessionStats(
      cardsStudied: _gameSession.totalAnswers,
      sessionAccuracy: accuracy,
      isPerfect: _gameSession.correctAnswers == _gameSession.totalAnswers &&
          _gameSession.totalAnswers > 0,
    );
    await userProvider.updateStreakFromStudyActivity();
  }

  void _showShuffleEndScreen(String message, bool wasSuccessful) {
    final int correct = _currentScore; // number answered correctly
    final int total = wasSuccessful ? _currentScore : _currentScore + 1; // include the wrong one if failed
    // Push end screen (don't use pushReplacement to keep ShuffleCardsView in stack)
    GameEndScreen.show(
      context,
      GameEndResult(
        title: 'Shuffle',
        studiedWords: _studiedWords,
        xpGainedPerWord: _xpGainedPerWord,
        wordMastery: _wordMastery,
        initialHPPerWord: _initialHPPerWord,
        correctAnswers: correct,
        totalQuestions: total,
        onStudyAgain: (available) {
          Navigator.of(context).pop();
          if (mounted) {
            setState(() {
              _isShowingEndScreen = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _startGame(useSameSequence: true, filteredCards: available);
              }
            });
          }
        },
        onShuffle: (available) {
          Navigator.of(context).pop();
          if (mounted) {
            setState(() {
              _isShowingEndScreen = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _startGame(useSameSequence: false, filteredCards: available);
              }
            });
          }
        },
        onDone: () {
          Navigator.of(context).pop();
          if (mounted) {
            setState(() {
              _isShowingEndScreen = false;
            });
          }
        },
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

  void _showSetupRequiredDialog(String message) {
    // Set game inactive when showing setup required dialog
    setState(() {
      _isGameActive = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Setup Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'To play Shuffle Your Cards:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Add flashcards or exercises'),
            const Text('• Enable game modes in settings'),
            const Text('• Make sure cards have HP remaining'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Just close the dialog, allow user to make changes
            },
            child: const Text('Back'),
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
          });
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            MainHeader(
              title: 'Shuffle',
              leftAction: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () {
                  if (_isGameActive) {
                    setState(() {
                      _isGameActive = false;
                      _currentScore = 0;
                      _currentMode = null;
                      _currentCard = null;
                    });
                  }
                  Navigator.of(context).pop();
                },
              ),
              rightAction: IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.green, size: 32),
                onPressed: _isGameActive ? null : _startGame,
                tooltip: 'Start Shuffle',
              ),
            ),
            Expanded(
              child: _isShowingEndScreen ? const SizedBox.shrink() : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Large Shuffle Icon with Animation
                        Hero(
                          tag: 'shuffle_icon',
                          child: Icon(
                            Icons.shuffle,
                            size: 100,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Title
                        Text(
                          'Shuffle Mode',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ) ??
                          TextStyle(
                            fontSize: 24,
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
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 24),

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

                        // Deck Selection
                        _buildDeckSelection(),
                        const SizedBox(height: 24),
                        
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
                                    const Spacer(),
                                    TextButton(
                                      onPressed: _showCustomizationDialog,
                                      child: const Text('Customize'),
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
          ],
        ),
      ),
    );
  }

  Widget _buildDeckSelection() {
    final provider = context.read<FlashcardProvider>();
    
    // Get selected deck names for display
    String selectedDecksText;
    if (_selectedDeckIds.isEmpty) {
      selectedDecksText = 'Any (All Decks)';
    } else if (_selectedDeckIds.length == 1) {
      final deck = provider.getDeck(_selectedDeckIds.first);
      selectedDecksText = deck?.name ?? 'Unknown Deck';
    } else {
      selectedDecksText = '${_selectedDeckIds.length} decks selected';
    }
    
    return Card(
      child: InkWell(
        onTap: () => _showDeckSelectionDialog(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.folder, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select your deck(s)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedDecksText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeckSelectionDialog() {
    final provider = context.read<FlashcardProvider>();
    final allDecks = provider.getAllDecksHierarchical();
    
    showDialog(
      context: context,
      builder: (context) => _ShuffleDeckSelectionDialog(
        decks: allDecks,
        provider: provider,
        selectedDeckIds: _selectedDeckIds,
        onSelectionChanged: (newSelection) {
          setState(() {
            _selectedDeckIds = newSelection;
          });
        },
      ),
    );
  }

  void _showCustomizationDialog() {
    final availableModes = _getAvailableModesForDialog();
    showDialog(
      context: context,
      builder: (context) => ShuffleCustomizationDialog(
        enabledModes: Map.from(_enabledModes),
        oneAnswerMode: _oneAnswerMode,
        availableModes: availableModes,
        onSettingsChanged: (newEnabledModes, newOneAnswerMode) {
          setState(() {
            _enabledModes = newEnabledModes;
            _oneAnswerMode = newOneAnswerMode;
          });
          _saveEnabledModes();
        },
      ),
    );
  }

  Set<ShuffleMode> _getAvailableModesForDialog() {
    return ShuffleMode.values.toSet();
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

class _ShuffleDeckSelectionDialog extends StatefulWidget {
  final List<Deck> decks;
  final FlashcardProvider provider;
  final Set<String> selectedDeckIds;
  final Function(Set<String>) onSelectionChanged;

  const _ShuffleDeckSelectionDialog({
    required this.decks,
    required this.provider,
    required this.selectedDeckIds,
    required this.onSelectionChanged,
  });

  @override
  State<_ShuffleDeckSelectionDialog> createState() => _ShuffleDeckSelectionDialogState();
}

class _ShuffleDeckSelectionDialogState extends State<_ShuffleDeckSelectionDialog> {
  late Set<String> _localSelectedDeckIds;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _localSelectedDeckIds = Set.from(widget.selectedDeckIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDecks = _searchText.isEmpty
        ? widget.decks
        : widget.decks.where((d) => d.name.toLowerCase().contains(_searchText.toLowerCase())).toList();

    int totalSelectedCards = 0;
    for (final deckId in _localSelectedDeckIds) {
      totalSelectedCards += widget.provider.getCardsForDeckWithSubDecks(deckId).length;
    }

    return AlertDialog(
      title: Text('Select Decks${_localSelectedDeckIds.isNotEmpty ? " (${_localSelectedDeckIds.length})" : ""}'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search decks...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchText = '';
                            });
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_localSelectedDeckIds.isNotEmpty && _searchText.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_localSelectedDeckIds.length} deck${_localSelectedDeckIds.length == 1 ? '' : 's'} selected • $totalSelectedCards cards',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_localSelectedDeckIds.isNotEmpty && _searchText.isEmpty) const SizedBox(height: 16),
                    if (_searchText.isEmpty)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: CheckboxListTile(
                          title: const Text('Any (All Decks)'),
                          subtitle: const Text('Use cards from all available decks'),
                          value: _localSelectedDeckIds.isEmpty,
                          onChanged: (bool? value) {
                            if (value == true) {
                              setState(() {
                                _localSelectedDeckIds.clear();
                              });
                              widget.onSelectionChanged(_localSelectedDeckIds);
                              Navigator.of(context).pop();
                            }
                          },
                          secondary: Icon(
                            _localSelectedDeckIds.isEmpty ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: _localSelectedDeckIds.isEmpty ? Theme.of(context).colorScheme.primary : Colors.grey,
                          ),
                        ),
                      ),
                    if (_searchText.isEmpty) const Divider(),
                    if (filteredDecks.isEmpty) ...[
                      const SizedBox(height: 32),
                      Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No decks found matching "$_searchText"',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ] else ...[
                      ...filteredDecks.map((deck) {
                        final deckCards = widget.provider.getCardsForDeckWithSubDecks(deck.id);
                        final isSelected = _localSelectedDeckIds.contains(deck.id);
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: CheckboxListTile(
                            title: Text(deck.name),
                            subtitle: Text('${deckCards.length} cards'),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (isSelected) {
                                  _localSelectedDeckIds.remove(deck.id);
                                } else {
                                  _localSelectedDeckIds.add(deck.id);
                                }
                              });
                              widget.onSelectionChanged(_localSelectedDeckIds);
                            },
                            secondary: Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_localSelectedDeckIds.isNotEmpty)
          TextButton(
            onPressed: () {
              setState(() {
                _localSelectedDeckIds.clear();
              });
              widget.onSelectionChanged(_localSelectedDeckIds);
            },
            child: Text(
              'Clear',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class ShuffleCustomizationDialog extends StatefulWidget {
  final Map<ShuffleMode, bool> enabledModes;
  final bool oneAnswerMode;
  final Function(Map<ShuffleMode, bool>, bool) onSettingsChanged;
  final Set<ShuffleMode> availableModes;

  const ShuffleCustomizationDialog({
    super.key,
    required this.enabledModes,
    required this.oneAnswerMode,
    required this.onSettingsChanged,
    required this.availableModes,
  });

  @override
  State<ShuffleCustomizationDialog> createState() => _ShuffleCustomizationDialogState();
}

class _ShuffleCustomizationDialogState extends State<ShuffleCustomizationDialog> {
  late Map<ShuffleMode, bool> _localEnabledModes;
  late bool _localOneAnswerMode;

  @override
  void initState() {
    super.initState();
    _localEnabledModes = Map.from(widget.enabledModes);
    _localOneAnswerMode = widget.oneAnswerMode;
  }

  void _updateMode(ShuffleMode mode, bool value) {
    setState(() {
      _localEnabledModes[mode] = value;
    });
    widget.onSettingsChanged(_localEnabledModes, _localOneAnswerMode);
  }

  void _updateOneAnswerMode(bool value) {
    setState(() {
      _localOneAnswerMode = value;
    });
    widget.onSettingsChanged(_localEnabledModes, _localOneAnswerMode);
  }

  @override
  Widget build(BuildContext context) {
    final modeConfigs = [
      {'title': 'Test Your Cards', 'mode': ShuffleMode.multipleChoice, 'icon': Icons.check_circle, 'color': Colors.teal},
      {'title': 'True or False', 'mode': ShuffleMode.trueFalse, 'icon': Icons.help_outline, 'color': Colors.orange},
      {'title': 'Remember Your Cards', 'mode': ShuffleMode.memoryGame, 'icon': Icons.psychology, 'color': Colors.grey},
      {'title': 'Jumble Your Cards', 'mode': ShuffleMode.wordScramble, 'icon': Icons.text_fields, 'color': Colors.blue},
      {'title': 'Write Your Cards', 'mode': ShuffleMode.writing, 'icon': Icons.edit, 'color': Colors.blue},
      {'title': 'Pop Your Card', 'mode': ShuffleMode.popYourCards, 'icon': Icons.bubble_chart, 'color': Colors.purple},
      {'title': 'Pick Your Card', 'mode': ShuffleMode.pickYourCards, 'icon': Icons.touch_app, 'color': Colors.pink},
      {'title': 'So Many Cards', 'mode': ShuffleMode.soManyCards, 'icon': Icons.grid_view, 'color': Colors.cyan},
      {'title': 'Sentence Builder', 'mode': ShuffleMode.sentenceBuilding, 'icon': Icons.format_align_left, 'color': Colors.green},
      {'title': 'De or Het?', 'mode': ShuffleMode.deHet, 'icon': Icons.translate, 'color': Colors.deepOrange},
    ];

    final visibleModeTiles = modeConfigs
        .where((config) => widget.availableModes.contains(config['mode']))
        .map((config) => _buildModeToggle(config['title'] as String, config['mode'] as ShuffleMode, config['icon'] as IconData, config['color'] as Color))
        .toList();

    return AlertDialog(
      title: const Text('Customize Exercise Types'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select which exercise types to include in shuffle mode:', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 16),
              if (visibleModeTiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Add cards or exercises to unlock game modes.', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                )
              else
                ...visibleModeTiles,
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }

  Widget _buildModeToggle(String title, ShuffleMode mode, IconData icon, Color color) {
    return SwitchListTile(
      dense: true, 
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        ],
      ),
      value: _localEnabledModes[mode] ?? true,
      onChanged: (value) => _updateMode(mode, value),
    );
  }
}

