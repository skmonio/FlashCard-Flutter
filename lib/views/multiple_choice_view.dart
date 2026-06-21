import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:async';
import '../models/flash_card.dart';
import '../models/game_session.dart';
import '../models/learning_mastery.dart';
import '../models/study_config.dart';
import '../services/sound_manager.dart';
import '../services/xp_service.dart';
import '../services/haptic_service.dart';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../components/xp_progress_widget.dart';
import '../components/animated_xp_counter.dart';
import '../utils/game_end_screen.dart';
import '../utils/card_color_utils.dart';
import '../utils/game_difficulty_helper.dart';
import '../models/timed_difficulty.dart';
import '../components/main_header.dart';
import '../components/game_view_widgets.dart';
import 'add_card_view.dart';
import '../utils/game_session_controller.dart';

class MultipleChoiceView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final Function(bool)? onComplete;
  final bool shuffleMode;
  final bool autoProgress;
  final bool useLivesMode;
  final int? customLives;
  final bool useTimedMode;
  final TimedDifficulty? timedDifficulty;
  final bool startFlipped;
  final StudyConfig? studyConfig;
  final int? shuffleQuestionOffset; // Offset for cumulative question count in shuffle mode
  final List<FlashCard>? answerPoolCards;
  final bool oneAnswerMode;
  final bool enableHints;

  const MultipleChoiceView({
    super.key,
    required this.cards,
    required this.title,
    this.onComplete,
    this.shuffleMode = false,
    this.autoProgress = false,
    this.useLivesMode = false,
    this.customLives,
    this.useTimedMode = false,
    this.timedDifficulty,
    this.startFlipped = false,
    this.studyConfig,
    this.shuffleQuestionOffset,
    this.answerPoolCards,
    this.oneAnswerMode = true,
    this.enableHints = true,
  });

  @override
  State<MultipleChoiceView> createState() => _MultipleChoiceViewState();
}

class _MultipleChoiceViewState extends State<MultipleChoiceView> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAttempts = 0;
  bool _showingResults = false;
  bool _answered = false;
  int? _selectedAnswer;
  int? _correctAnswerIndex;
  List<String> _options = [];
  bool _isQuestionMode = true; // true = word to definition, false = definition to word
  late GameSessionController _sessionController;
  
  // Lives system
  int _lives = 0;
  int _maxLives = 0;
  bool _useLivesMode = false;
  
  // Timer variables for timed mode
  Timer? _timer;
  int _timeRemaining = 0;
  int _totalTime = 0;
  bool _timeUp = false;
  bool _useTimedMode = false;
  
  // Track answered questions and their answers
  Map<int, int> _answeredQuestions = {}; // question index -> selected answer index
  Map<int, bool> _correctAnswersMap = {}; // question index -> is correct
  Map<int, List<String>> _questionOptions = {}; // question index -> options
  Map<int, int> _correctAnswerIndices = {}; // question index -> correct answer index
  Map<int, bool> _questionModes = {}; // question index -> is question mode
  Set<int> _autoProgressedQuestions = {}; // Track which questions have been auto-progressed
  int _activeQuestionIndex = 0; // Track the furthest question that auto progress has reached
  
  // Maintain our own copy of cards that can be updated
  late List<FlashCard> _currentCards;
  
  // Auto progress timer
  Timer? _autoProgressTimer;
  
  // Hint and review tracking
  Map<int, int> _hintCount = {}; // question index -> number of hints used (0, 1, 2, or 3)
  Map<int, Set<int>> _blockedOptions = {}; // question index -> set of blocked option indices
  Set<String> _reviewCards = {}; // card IDs marked for review
  
  // Wrong attempts tracking for Test Your Cards mode
  Map<int, int> _wrongAttempts = {}; // question index -> number of wrong attempts (0-5)
  Map<int, Set<int>> _disabledOptions = {}; // question index -> set of disabled wrong option indices

  // Animation controllers for feedback
  late AnimationController _shakeController;
  late AnimationController _successController;
  int _consecutiveCorrect = 0; // Streak tracking

  @override
  void initState() {
    super.initState();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _sessionController = GameSessionController(
      flashcardProvider: context.read<FlashcardProvider>(),
      userProfileProvider: context.read<UserProfileProvider>(),
    );
    
    // Initialize our copy of cards
    _currentCards = List<FlashCard>.from(widget.cards);
    
    // Initialize lives system
    _useLivesMode = widget.useLivesMode;
    if (_useLivesMode) {
      _maxLives = widget.customLives ?? _getDefaultLives();
      _lives = _maxLives;
    }
    
    // Initialize timed mode
    _useTimedMode = widget.useTimedMode;
    if (_useTimedMode && widget.timedDifficulty != null) {
      switch (widget.timedDifficulty!) {
        case TimedDifficulty.easy:
          _timeRemaining = 7;
          break;
        case TimedDifficulty.medium:
          _timeRemaining = 5;
          break;
        case TimedDifficulty.hard:
          _timeRemaining = 3;
          break;
      }
      _totalTime = _timeRemaining;
    }
    
    _generateQuestion();
    
    // Start timer if in timed mode
    if (_useTimedMode) {
      _startTimer();
    }
    
    // Listen for card updates from the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FlashcardProvider>();
      provider.addListener(_onProviderChanged);
    });
  }
  
  /// Get default lives based on difficulty (assuming medium difficulty for now)
  int _getDefaultLives() {
    // For now, return medium difficulty lives
    // In the future, this could be based on actual difficulty detection
    return 2; // Medium difficulty = 2 lives
  }

  @override
  void dispose() {
    // Remove listener when disposing
    final provider = context.read<FlashcardProvider>();
    provider.removeListener(_onProviderChanged);
    
    // Cancel auto progress timer
    _autoProgressTimer?.cancel();
    
    // Cancel timer
    _timer?.cancel();
    
    super.dispose();
  }

  void _onProviderChanged() {
    // Refresh cards from the provider when cards are updated
    if (mounted) {
      _refreshCardsFromProvider();
    }
  }

  void _refreshCardsFromProvider() {
    final provider = context.read<FlashcardProvider>();
    
    // Get updated cards from provider
    List<FlashCard> updatedCards = [];
    for (final originalCard in _currentCards) {
      final updatedCard = provider.getCard(originalCard.id);
      if (updatedCard != null) {
        updatedCards.add(updatedCard);
      } else {
        // If card was deleted, keep the original
        updatedCards.add(originalCard);
      }
    }
    
    // Update our current cards list WITHOUT regenerating the question
    // Regenerating would reset blocked options and question state
    setState(() {
      _currentCards = updatedCards;
      // DO NOT call _generateQuestion() here as it resets blocked options!
      // Just update the card references, preserve all question state
    });
    
    print('🔍 MultipleChoiceView: Refreshed cards from provider (preserving blocked options and question state)');
  }

  void _startTimer() {
    if (!_useTimedMode) return;
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeRemaining > 0) {
            _timeRemaining--;
          }
        });
        
        if (_timeRemaining <= 0) {
          _handleTimeUp();
        }
      }
    });
  }

  void _handleTimeUp() {
    if (_answered || _timeUp) return; // Already answered or time already up
    
    final currentCard = _currentCards[_currentIndex];
    
    // Mark as incorrect (timeout = incorrect)
    setState(() {
      _answered = true;
      _timeUp = true;
      _totalAttempts++;
      _correctAnswersMap[_currentIndex] = false; // Time out = incorrect answer
      _selectedAnswer = null; // No answer selected
    });
    
    // Apply HP penalty and record answer via controller
    _sessionController.recordIncorrect(
      currentCard,
      exerciseType: 'Multiple Choice',
      difficulty: GameDifficulty.medium,
      isTimeout: true,
    );
    
    // Auto progress after showing the answer
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _goToNextQuestion();
      }
    });
  }

  void _resetTimer() {
    if (!_useTimedMode) return;
    
    _timer?.cancel();
    _timeRemaining = _totalTime;
    _timeUp = false;
    _startTimer();
  }

  void _generateQuestion() {
    if (_currentIndex >= _currentCards.length) {
      // Calculate success rate
      final successRate = _totalAttempts > 0 ? (_correctAnswers / _totalAttempts) : 0.0;
      final wasSuccessful = successRate >= 0.6; // 60% or higher is considered successful
      
      // Call the onComplete callback if provided
      if (widget.onComplete != null) {
        widget.onComplete!(wasSuccessful);
        return;
      }
      
      // Play completion sound when test is finished
      SoundManager().playCompleteSound();
      // Show comprehensive completion screen directly (skip old results screen)
      _showWordProgress();
      return;
    }

    // Reset hint and review state for new question (only if not already attempted)
    if (!_answeredQuestions.containsKey(_currentIndex)) {
      _hintCount[_currentIndex] = 0;
      _blockedOptions[_currentIndex] = <int>{};
      _wrongAttempts[_currentIndex] = 0;
      _disabledOptions[_currentIndex] = <int>{};
    } else {
      // Preserve blocked and disabled options for already attempted questions
      _blockedOptions[_currentIndex] ??= <int>{};
      _disabledOptions[_currentIndex] ??= <int>{};
      _wrongAttempts[_currentIndex] ??= 0;
    }

    // Check if this question has already been generated
    if (_questionOptions.containsKey(_currentIndex)) {
      // Load existing question data
      _isQuestionMode = _questionModes[_currentIndex]!;
      _options = _questionOptions[_currentIndex]!;
      _correctAnswerIndex = _correctAnswerIndices[_currentIndex]!;
      _selectedAnswer = _answeredQuestions[_currentIndex];
      _answered = _answeredQuestions.containsKey(_currentIndex);
      // Preserve blocked and disabled options - don't reset them
      _blockedOptions[_currentIndex] ??= <int>{};
      _disabledOptions[_currentIndex] ??= <int>{};
      _wrongAttempts[_currentIndex] ??= 0;
      return;
    }

    final currentCard = _currentCards[_currentIndex];
    final random = Random();
    
    // Choose question mode based on flipped mode settings
    _isQuestionMode = !widget.startFlipped; // Use flipped mode setting
    
    // Get correct answer
    final correctAnswer = _isQuestionMode ? currentCard.definition : currentCard.word;
    
    // Get wrong options from configured answer pool
    final answerPool = _getAnswerPoolForCard(currentCard);
    final otherCards = answerPool.where((card) => card.id != currentCard.id).toList();
    // Test Your Cards mode and shuffle mode should have 4 options, other modes have 6
    final int desiredTotalOptions = (widget.title.toLowerCase().contains('test') || widget.shuffleMode) ? 4 : 6;
    final int desiredWrongOptions = desiredTotalOptions - 1;
    final wrongOptions = <String>[];
    
    // Shuffle all other cards to get variety from any deck
    final shuffledOtherCards = List.from(otherCards)..shuffle(random);
    
    for (final card in shuffledOtherCards) {
      if (wrongOptions.length >= desiredWrongOptions) break;
      
      final wrongOption = _isQuestionMode ? card.definition : card.word;
      if (!wrongOptions.contains(wrongOption) && wrongOption != correctAnswer) {
        wrongOptions.add(wrongOption);
      }
    }
    
    // Only use generic options as absolute last resort
    if (wrongOptions.length < desiredWrongOptions) {
      final genericOptions = _isQuestionMode
          ? [
              'Not applicable',
              'Different meaning',
              'Other definition',
              'Alternative translation',
              'Similar phrase',
            ]
          : [
              'Unknown word',
              'Different word',
              'Other term',
              'Similar spelling',
              'Random choice',
            ];
      
      int fallbackIndex = 0;
      while (wrongOptions.length < desiredWrongOptions && fallbackIndex < genericOptions.length) {
        final generic = genericOptions[fallbackIndex];
        if (!wrongOptions.contains(generic)) {
          wrongOptions.add(generic);
        }
        fallbackIndex++;
      }
    }
    
    // Create options list with correct answer first
    _options = [correctAnswer, ...wrongOptions];
    
    if (_options.length > desiredTotalOptions) {
      _options = _options.take(desiredTotalOptions).toList();
    }
    
    // Shuffle options in study mode (but keep correct answer first in edit mode)
    // Check if this is edit mode by looking for the edit button in the UI
    // For now, always shuffle since this is used for study mode
    _options.shuffle(random);
    
    // Find correct answer index after shuffling
    _correctAnswerIndex = _options.indexOf(correctAnswer);
    
    // Store question data for future reference
    _questionOptions[_currentIndex] = List.from(_options);
    _correctAnswerIndices[_currentIndex] = _correctAnswerIndex!;
    _questionModes[_currentIndex] = _isQuestionMode;
    
    setState(() {
      _answered = false;
      _selectedAnswer = null;
      _timeUp = false;
    });
    
    // Reset timer for new question
    if (_useTimedMode) {
      _resetTimer();
    }
  }

  List<FlashCard> _getAnswerPoolForCard(FlashCard currentCard) {
    if (widget.answerPoolCards != null && widget.answerPoolCards!.isNotEmpty) {
      return widget.answerPoolCards!;
    }

    final provider = context.read<FlashcardProvider>();

    if (widget.studyConfig == null || widget.studyConfig!.useAllCardsForAnswers) {
      return provider.cards;
    }

    if (widget.studyConfig!.deckIds.isEmpty) {
      return provider.cards;
    }

    final Set<String> seenIds = {};
    final List<FlashCard> deckCards = [];

    for (final deckId in widget.studyConfig!.deckIds) {
      final cards = provider.getCardsForDeckWithSubDecks(deckId);
      for (final card in cards) {
        if (seenIds.add(card.id)) {
          deckCards.add(card);
        }
      }
    }

    return deckCards.isEmpty ? provider.cards : deckCards;
  }

  void _selectAnswer(int index) {
    // Don't allow selecting if already answered (correct answer selected or 5 wrong attempts)
    if (_answered) {
      print('🔍 MultipleChoiceView: Answer already selected, ignoring tap on option $index');
      return;
    }
    
    // Don't allow selecting blocked options (wrong answers that were already clicked or hints)
    // Use same logic as hints - check _blockedOptions
    _blockedOptions[_currentIndex] ??= <int>{};
    if (_blockedOptions[_currentIndex]!.contains(index)) {
      print('🔍 MultipleChoiceView: Option $index is blocked for question $_currentIndex, ignoring tap. Blocked set: ${_blockedOptions[_currentIndex]}');
      return;
    }
    
    final isCorrect = (index == _correctAnswerIndex);
    final currentCard = _currentCards[_currentIndex];
    final wrongAttempts = _wrongAttempts[_currentIndex] ?? 0;
    
    // Provide haptic feedback and animations based on answer correctness
    if (isCorrect) {
      _successController.forward(from: 0);
      _consecutiveCorrect++;
    } else {
      _shakeController.forward(from: 0);
      _consecutiveCorrect = 0; // Reset streak
    }
    
    // Stop timer if in timed mode
    if (_useTimedMode) {
      _timer?.cancel();
    }
    
    setState(() {
      _selectedAnswer = index;
      _totalAttempts++;

      if (isCorrect) {
        _answered = true;
        _correctAnswers++;
        
        // Store the answer
        _answeredQuestions[_currentIndex] = index;
        _correctAnswersMap[_currentIndex] = true;
        
        // Record correct answer via controller (handles HP, XP, sounds, haptics, provider)
        _sessionController.recordCorrect(
          currentCard,
          exerciseType: 'Multiple Choice',
          difficulty: GameDifficulty.medium,
          hintsUsed: _hintCount[_currentIndex] ?? 0,
          wrongAttempts: wrongAttempts,
        );
        
        // Auto progress logic (only if not game over and not in shuffle mode)
        if (widget.autoProgress && !widget.shuffleMode && !(_useLivesMode && _lives <= 0)) {
          _autoProgressTimer?.cancel();
          _autoProgressTimer = Timer(const Duration(milliseconds: 800), () {
            if (mounted && _currentIndex < _currentCards.length - 1) {
              // Mark this question as auto-progressed before moving to next
              _autoProgressedQuestions.add(_currentIndex);
              // Update the active question index to the next question
              _activeQuestionIndex = _currentIndex + 1;
              _goToNextQuestion();
            }
          });
        }
      } else {
        // Check if "1 answer mode" is enabled
        bool oneAnswerMode = widget.studyConfig?.oneAnswerMode ?? false;
        
        if (oneAnswerMode) {
          // Wrong answer in 1 answer mode - mark as answered immediately
          _answered = true;
          _totalAttempts++;
          _answeredQuestions[_currentIndex] = index;
          _correctAnswersMap[_currentIndex] = false;
          
          _sessionController.recordIncorrect(
            currentCard,
            exerciseType: 'Multiple Choice',
            difficulty: GameDifficulty.medium,
          );
          
          if (_useLivesMode) {
            _lives--;
            if (_lives <= 0) {
              _showGameOverScreen();
            }
          }
          
          // Auto progress logic for wrong answer in 1 answer mode
          if (widget.autoProgress && !widget.shuffleMode && !(_useLivesMode && _lives <= 0)) {
            _autoProgressTimer?.cancel();
            _autoProgressTimer = Timer(const Duration(milliseconds: 1500), () {
              if (mounted && _currentIndex < _currentCards.length - 1) {
                _autoProgressedQuestions.add(_currentIndex);
                _activeQuestionIndex = _currentIndex + 1;
                _goToNextQuestion();
              }
            });
          }
          return;
        }

        // Wrong answer - disable this option, increment wrong attempts
        final newWrongAttempts = wrongAttempts + 1;
        
        // Initialize sets if needed
        _disabledOptions[_currentIndex] ??= <int>{};
        _blockedOptions[_currentIndex] ??= <int>{};
        
        _blockedOptions[_currentIndex]!.add(index);
        _disabledOptions[_currentIndex]!.add(index);
        
        _wrongAttempts[_currentIndex] = newWrongAttempts;
        
        // Trigger manual sounds & haptics for intermediate wrong attempt
        HapticService().errorFeedback();
        SoundManager().playWrongSound();
        
        // Handle lives system 
        if (_useLivesMode) {
          _lives--;
          if (_lives <= 0) {
            _sessionController.recordIncorrect(
              currentCard,
              exerciseType: 'Multiple Choice',
              difficulty: GameDifficulty.medium,
            );
            _showGameOverScreen();
            return;
          }
        }
        
        // If 5 wrong attempts, show the answer automatically
        if (newWrongAttempts >= 5) {
          _answered = true;
          _totalAttempts++;
          _correctAnswersMap[_currentIndex] = false;
          _answeredQuestions[_currentIndex] = index;
          
          _sessionController.recordIncorrect(
            currentCard,
            exerciseType: 'Multiple Choice',
            difficulty: GameDifficulty.medium,
          );
        }
      }
    });
  }

  /// Show game over screen when all lives are lost
  void _showGameOverScreen() {
    // Play game over sound
    SoundManager().playWrongSound();
    
    // Call onComplete with false (unsuccessful)
    if (widget.onComplete != null) {
      widget.onComplete!(false);
    }
    
    // Show comprehensive completion screen directly (skip old results screen)
    _showWordProgress();
  }



  Color _getOptionColor(int index) {
    if (!_answered) return Colors.transparent;
    
    if (index == _correctAnswerIndex) {
      return Colors.green.withValues(alpha: 0.2);
    } else if (index == _selectedAnswer && index != _correctAnswerIndex) {
      return Colors.red.withValues(alpha: 0.2);
    }
    
    return Colors.transparent;
  }

  Color _getOptionBorderColor(int index) {
    if (!_answered) return Colors.grey.withValues(alpha: 0.3);
    
    if (index == _correctAnswerIndex) {
      return Colors.green;
    } else if (index == _selectedAnswer && index != _correctAnswerIndex) {
      return Colors.red;
    }
    
    return Colors.grey.withValues(alpha: 0.3);
  }

  // Generate consistent color based on card content (same as study view)
  Color _getCardBorderColor(FlashCard card) {
    return CardColorUtils.getBorderColor(card);
  }

  void _goToPreviousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _generateQuestion();
    }
  }

  bool _isOnCurrentQuestion() {
    // Find the highest index that has been answered
    int highestAnsweredIndex = -1;
    for (int index in _answeredQuestions.keys) {
      if (index > highestAnsweredIndex) {
        highestAnsweredIndex = index;
      }
    }
    // If no questions have been answered, current question is 0
    // Otherwise, current question is the next unanswered question after the highest answered
    int currentQuestion = highestAnsweredIndex == -1 ? 0 : highestAnsweredIndex + 1;
    return _currentIndex == currentQuestion;
  }

  bool _canUseNextButton() {
    print('🔍 MultipleChoiceView: _canUseNextButton called - _answered: $_answered, shuffleMode: ${widget.shuffleMode}');
    if (!_answered) {
      print('🔍 MultipleChoiceView: Button disabled - question not answered');
      return false;
    }
    
    // In shuffle mode, always allow next button after answering
    if (widget.shuffleMode) {
      print('🔍 MultipleChoiceView: Button enabled - shuffle mode');
      return true;
    }
    
    // Always allow finish button on the last question
    if (_currentIndex == _currentCards.length - 1) {
      return true;
    }
    
    if (!widget.autoProgress) {
      // If auto progress is disabled, allow next button on any answered question
      return true;
    }
    
    // If auto progress is enabled:
    // 1. Allow next button if we're on a previous question (not the active one)
    // 2. Allow next button if we're on the active question but auto progress has already happened
    if (_currentIndex < _activeQuestionIndex) {
      return true; // We're on a previous question
    }
    
    // We're on the active question - only allow if auto progress has already happened
    // This prevents clicking next immediately after answering, before auto progress kicks in
    return _autoProgressedQuestions.contains(_currentIndex);
  }

  void _goToNextQuestion() {
    print('🔍 MultipleChoiceView: _goToNextQuestion called, shuffleMode: ${widget.shuffleMode}');
    // In shuffle mode, we only have one question, so call the callback immediately
    if (widget.shuffleMode) {
      // Use the stored correctness value from when the answer was selected
      // This ensures consistency with what the user saw when they answered
      final isCorrect = _correctAnswersMap[_currentIndex] ?? false;
      print('🔍 MultipleChoiceView: Shuffle mode - calling onComplete with isCorrect: $isCorrect');
      if (widget.onComplete != null) {
        widget.onComplete!(isCorrect);
        print('🔍 MultipleChoiceView: onComplete callback executed');
      } else {
        print('⚠️ MultipleChoiceView: onComplete is null!');
      }
      return;
    }
    
    if (_currentIndex < _currentCards.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _generateQuestion();
    } else {
      // Award XP for the session
      _awardXp();
      // Play completion sound when test is finished
      SoundManager().playCompleteSound();
      // Show comprehensive completion screen directly (skip old results screen)
      _showWordProgress();
    }
  }

  void _editCurrentCard() {
    final currentCard = _currentCards[_currentIndex];
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCardView(
          cardToEdit: currentCard,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('No cards available for testing'),
        ),
      );
    }



    final currentCard = _currentCards[_currentIndex];
    final question = _isQuestionMode ? currentCard.word : currentCard.definition;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          MainHeader(
            title: 'Test',
            leftAction: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () => _showCloseConfirmation(),
            ),
            rightAction: IconButton(
              icon: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () => _showHomeConfirmation(),
            ),
          ),
          // Progress bar
          _buildProgressBar(),
          
          // Question area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Reduced top padding
              child: Column(
                children: [
                  // Question text above card
                  Text(
                    'Choose the correct definition',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16), // Reduced spacing
                  
                  // Card with theme-adaptive background and colored outline
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: _getAdaptiveCardHeight(context), // Adaptive height based on screen size
                        padding: const EdgeInsets.all(24), // Reduced padding
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.surface 
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20), // Slightly smaller radius
                          border: Border.all(
                            color: _getCardBorderColor(currentCard),
                            width: 4, // Slightly thinner border
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _getCardBorderColor(currentCard).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            question,
                            style: TextStyle(
                              fontSize: _getAdaptiveFontSize(context), // Adaptive font size
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Theme.of(context).colorScheme.onSurface 
                                  : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      
                      // Review flag (top left)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildReviewFlag(currentCard),
                      ),
                      
                      // Hint button (bottom right)
                      if (!_answered && (widget.studyConfig?.enableHints ?? true))
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: _buildHintIcon(),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16), // Reduced spacing
                  
                  const SizedBox(height: 20), // Reduced spacing
                  
                  // Options - 2 answers on one line, flexible on devices
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisExtent: 80,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: _options.length,
                        itemBuilder: (context, index) {
                          return _buildOptionButton(index, _options[index]);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildUnifiedFooter(),
    );
  }

  Widget _buildProgressBar() {
    final progress = _currentCards.isEmpty ? 0.0 : _currentIndex / _currentCards.length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              // Left side: Card count
              Expanded(
                child: Text(
                  'Card ${widget.shuffleMode && widget.shuffleQuestionOffset != null ? (widget.shuffleQuestionOffset! + _currentIndex + 1) : (_currentIndex + 1)}/${_currentCards.length}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              
              // Middle: Lives and/or timer
              if (_useLivesMode || _useTimedMode || _consecutiveCorrect >= 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_useLivesMode) ...[
                        GameLivesIndicator(lives: _lives, maxLives: _maxLives),
                        if (_useTimedMode || _consecutiveCorrect >= 3) const SizedBox(width: 8),
                      ],
                      if (_useTimedMode) ...[
                        GameTimerIndicator(timeRemaining: _timeRemaining, totalTime: _totalTime),
                        if (_consecutiveCorrect >= 3) const SizedBox(width: 8),
                      ],
                      if (_consecutiveCorrect >= 3)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$_consecutiveCorrect',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              
              // Right side: Accuracy (or empty expanded to maintain center)
              Expanded(
                child: Text(
                  'Acc: ${_totalAttempts > 0 ? (_correctAnswers / _totalAttempts * 100).toInt() : 0}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUnifiedFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Back button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _currentIndex > 0 ? _goToPreviousQuestion : null,
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                label: const Text('Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentIndex > 0 ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                  foregroundColor: _currentIndex > 0 
                      ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87) 
                      : Colors.grey,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _currentIndex > 0 ? Colors.grey[300]! : Colors.transparent),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Edit button in center
            IconButton(
              onPressed: () => _editCurrentCard(),
              icon: const Icon(Icons.edit),
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Next/Finish button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _canUseNextButton() ? _goToNextQuestion : null,
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                label: Text(_currentIndex == _currentCards.length - 1 ? 'Finish' : 'Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canUseNextButton() ? Theme.of(context).colorScheme.primary : Colors.grey,
                  foregroundColor: Colors.white,
                  elevation: _canUseNextButton() ? 2 : 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivesDisplay() {
    if (!_useLivesMode) return const SizedBox.shrink();
    
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: GameLivesIndicator(lives: _lives, maxLives: _maxLives),
      ),
    );
  }
  
  Color _getDifficultyColor() {
    if (_maxLives == 3) return Colors.green; // Easy
    if (_maxLives == 2) return Colors.orange; // Medium
    if (_maxLives == 1) return Colors.red; // Hard
    return Colors.grey; // Default
  }
  
  String _getDifficultyText() {
    if (_maxLives == 3) return 'Easy';
    if (_maxLives == 2) return 'Medium';
    if (_maxLives == 1) return 'Hard';
    return 'Custom';
  }

  Widget _buildOptionButton(int index, String option) {
    // Initialize sets if they don't exist
    _blockedOptions[_currentIndex] ??= <int>{};
    _disabledOptions[_currentIndex] ??= <int>{};
    
    final isBlocked = _blockedOptions[_currentIndex]!.contains(index);
    final isDisabled = _disabledOptions[_currentIndex]!.contains(index);
    final wrongAttempts = _wrongAttempts[_currentIndex] ?? 0;
    
    // Block interactions: if answered, wrong answers are not selectable
    // If answered correctly on first try (wrongAttempts == 0), wrong answers still aren't selectable but look normal
    final isNotSelectable = isBlocked || isDisabled || (_answered && index != _correctAnswerIndex);
    
    // Visual appearance: only show as blocked if there were wrong attempts or if it's actually blocked/disabled
    // If answered correctly on first try, wrong answers look normal (not greyed out)
    final shouldShowAsBlocked = (isBlocked || isDisabled) || (_answered && index != _correctAnswerIndex && wrongAttempts > 0);
    
    // Debug: ALWAYS print to see what's happening
    print('🔍 MultipleChoiceView: Building button for option $index (Q$_currentIndex) - isBlocked: $isBlocked, isDisabled: $isDisabled, wrongAttempts: $wrongAttempts, isNotSelectable: $isNotSelectable, shouldShowAsBlocked: $shouldShowAsBlocked');
    
    // Build the button content
    // Wrap in AnimatedBuilder for feedback animations
    return AnimatedBuilder(
      animation: Listenable.merge([_shakeController, _successController]),
      builder: (context, child) {
        // Shake offset calculation
        double shakeOffset = 0;
        if (_shakeController.isAnimating && _selectedAnswer == index && index != _correctAnswerIndex) {
          shakeOffset = sin(_shakeController.value * pi * 4) * 8;
        }
        
        // Success scale calculation
        double successScale = 1.0;
        if (_successController.isAnimating && index == _correctAnswerIndex && _answered) {
          successScale = 1.0 + sin(_successController.value * pi) * 0.1;
        }

        final isCorrectOption = (index == _correctAnswerIndex);
        final isSelectedWrong = (_selectedAnswer == index && !isCorrectOption);
        
        // Updated colors for the premium reveal flow
        Color statusColor = _getOptionColor(index);
        Color borderStatusColor = _getOptionBorderColor(index);
        
        if (_answered) {
          if (isCorrectOption) {
            statusColor = Colors.green.withValues(alpha: 0.1);
            borderStatusColor = Colors.green;
          } else if (isSelectedWrong) {
            statusColor = Colors.red.withValues(alpha: 0.1);
            borderStatusColor = Colors.red;
          } else {
            statusColor = Colors.grey.withValues(alpha: 0.05);
            borderStatusColor = Colors.grey.withValues(alpha: 0.3);
          }
        }

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Transform.scale(
            scale: successScale,
            child: SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isNotSelectable ? null : () => _selectAnswer(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderStatusColor,
                        width: isCorrectOption && _answered ? 3 : 2,
                      ),
                      boxShadow: isCorrectOption && _answered ? [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ] : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: borderStatusColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _answered && isCorrectOption
                              ? const Icon(Icons.check, color: Colors.green, size: 18)
                              : _answered && isSelectedWrong
                                ? const Icon(Icons.close, color: Colors.red, size: 18)
                                : Text(
                                    String.fromCharCode(65 + index),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: borderStatusColor,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _answered && !isCorrectOption && !isSelectedWrong ? Colors.grey : null,
                            ),
                          ),
                        ),
                        if (_answered && isCorrectOption)
                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsView() {
    final accuracy = _totalAttempts > 0 ? (_correctAnswers / _totalAttempts * 100).toInt() : 0;
    final isGameOver = _useLivesMode && _lives <= 0;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
          children: [
            // Small header - matching study view
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      iconSize: 20,
                    ),
                    const Spacer(),
                    const Text(
                      'Test Complete',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      icon: const Icon(Icons.home),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
            ),
            
            // Results content - Make it scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Score
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: accuracy >= 80 ? Colors.green.withValues(alpha: 0.1) : 
                               accuracy >= 60 ? Colors.orange.withValues(alpha: 0.1) : 
                               Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$accuracy%',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: accuracy >= 80 ? Colors.green : 
                                   accuracy >= 60 ? Colors.orange : 
                                   Colors.red,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Stats
                    _buildStatCard('Questions', _totalAttempts.toString(), Icons.quiz),
                    const SizedBox(height: 16),
                    _buildStatCard('Correct', _correctAnswers.toString(), Icons.check_circle, Colors.green),
                    const SizedBox(height: 16),
                    _buildStatCard('Incorrect', (_totalAttempts - _correctAnswers).toString(), Icons.cancel, Colors.red),
                    const SizedBox(height: 16),
                    _buildStatCard('XP Earned', '', Icons.star, Colors.amber,
                      AnimatedXpCounter(xpGained: _sessionController.xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp))),
                    
                    // Swipe hint if XP was gained
                    if (_sessionController.xpGainedPerWord.values.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swipe_right,
                              color: Colors.amber,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Swipe right to view word progress',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ),
              ),
            ),
            
            // Fixed footer with action buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        print('🔍 MultipleChoiceView: Test Again button pressed');
                        
                        setState(() {
                          _currentIndex = 0;
                          _correctAnswers = 0;
                          _totalAttempts = 0;
                          _showingResults = false;
                          _answered = false;
                          _selectedAnswer = null;
                          
                          _sessionController = GameSessionController(
                            flashcardProvider: context.read<FlashcardProvider>(),
                            userProfileProvider: context.read<UserProfileProvider>(),
                          );
                          
                          // Reset lives if using lives mode
                          if (_useLivesMode) {
                            _lives = _maxLives;
                          }
                          
                          // Reset all navigation state
                          _answeredQuestions.clear();
                          _correctAnswersMap.clear();
                          _questionOptions.clear();
                          _correctAnswerIndices.clear();
                          _questionModes.clear();
                          
                          // Reset hint and review tracking
                          _hintCount.clear();
                          _blockedOptions.clear();
                          _reviewCards.clear();
                          
                          // Reset wrong attempts tracking
                          _wrongAttempts.clear();
                          _disabledOptions.clear();
                        });
                        _generateQuestion();
                      },
                      child: const Text('Test Again'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, [Color? color, Widget? child]) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color ?? Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          child ?? Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Test?'),
        content: const Text('Are you sure you want to end this test?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('End Test'),
          ),
        ],
      ),
    );
  }

  void _showHomeConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return to Home?'),
        content: const Text('Are you sure you want to return to the home screen? This will end your current test.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  Future<void> _awardXp() async {
    await _sessionController.finalizeSession();
  }
  
  void _shuffleAndRestart() {
    if (widget.studyConfig == null) return;
    
    final provider = context.read<FlashcardProvider>();
    
    // Get all cards from the same deck configuration
    List<FlashCard> allDeckCards = [];
    Set<String> seenCardIds = {};
    
    if (widget.studyConfig!.deckIds.isEmpty) {
      // Empty deckIds means all decks
      allDeckCards = provider.cards;
    } else {
      for (final deckId in widget.studyConfig!.deckIds) {
        final deckCards = provider.getCardsForDeckWithSubDecks(deckId);
        for (final card in deckCards) {
          if (!seenCardIds.contains(card.id)) {
            allDeckCards.add(card);
            seenCardIds.add(card.id);
          }
        }
      }
    }
    
    if (allDeckCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available in selected decks.')),
      );
      return;
    }
    
    // Apply SRS filtering if enabled
    List<FlashCard> filteredCards;
    if (widget.studyConfig!.useSRSFiltering) {
      final dueCards = allDeckCards.where((card) => card.isDueForReview).toList();
      final notDueCards = allDeckCards.where((card) => !card.isDueForReview).toList();
      filteredCards = [...dueCards, ...notDueCards];
    } else {
      filteredCards = allDeckCards;
    }
    
    // Apply daily study limit filtering
    final availableCards = filteredCards.where((card) => card.canBeStudiedToday).toList();
    
    if (availableCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available for study today.')),
      );
      return;
    }
    
    // Shuffle and take the specified number of cards
    availableCards.shuffle();
    final cardCount = widget.studyConfig!.cardCount >= 50 ? availableCards.length : widget.studyConfig!.cardCount;
    final newCards = availableCards.take(cardCount).toList();
    
    // Reset the view with new cards
    setState(() {
      _currentCards = newCards;
      _currentIndex = 0;
      _correctAnswers = 0;
      _totalAttempts = 0;
      _showingResults = false;
      _answered = false;
      _selectedAnswer = null;
      
      _sessionController = GameSessionController(
        flashcardProvider: context.read<FlashcardProvider>(),
        userProfileProvider: context.read<UserProfileProvider>(),
      );
      
      // Reset lives if using lives mode
      if (_useLivesMode) {
        _lives = _maxLives;
      }
      
      // Reset all navigation state
      _answeredQuestions.clear();
      _correctAnswersMap.clear();
      _questionOptions.clear();
      _correctAnswerIndices.clear();
      _questionModes.clear();
      
      // Reset wrong attempts tracking
      _wrongAttempts.clear();
      _disabledOptions.clear();
    });
    
    _generateQuestion();
  }

  void _showWordProgress() {
    // Create copies of the current session data for the display
    final sessionStudiedWords = List<FlashCard>.from(_sessionController.studiedWords);
    final sessionXpGainedPerWord = Map<String, int>.from(_sessionController.xpGainedPerWord);
    final sessionWordMastery = Map<String, LearningMastery>.from(_sessionController.wordMastery);
    final sessionInitialHPPerWord = Map<String, int>.from(_sessionController.initialHPPerWord);
    
    GameEndScreen.show(
      context,
      GameEndResult(
        title: 'Test',
        studiedWords: sessionStudiedWords,
        xpGainedPerWord: sessionXpGainedPerWord,
        wordMastery: sessionWordMastery,
        initialHPPerWord: sessionInitialHPPerWord,
        correctAnswers: _correctAnswers,
        totalQuestions: _totalAttempts,
        onStudyAgain: (available) {
          Navigator.of(context).pop();
          setState(() {
            _currentCards = List.from(available);
            _currentIndex = 0;
            _correctAnswers = 0;
            _totalAttempts = 0;
            _showingResults = false;
            _answered = false;
            _selectedAnswer = null;
            _sessionController = GameSessionController(
              flashcardProvider: context.read<FlashcardProvider>(),
              userProfileProvider: context.read<UserProfileProvider>(),
            );
            if (_useLivesMode) {
              _lives = _maxLives;
            }
            _answeredQuestions.clear();
            _correctAnswersMap.clear();
            _questionOptions.clear();
            _correctAnswerIndices.clear();
            _questionModes.clear();
            _wrongAttempts.clear();
            _disabledOptions.clear();
          });
          _generateQuestion();
        },
        onShuffle: widget.studyConfig != null
            ? (available) {
                Navigator.of(context).pop();
                setState(() {
                  _currentCards = List.from(available)..shuffle();
                });
                _shuffleAndRestart();
              }
            : null,
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  double _getAdaptiveCardHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate available height after accounting for header, progress bar, and buttons
    final availableHeight = screenHeight - 200; // Reserve space for UI elements
    
    // For very small screens (height < 600), use much smaller percentage
    if (screenHeight < 600) {
      return (availableHeight * 0.2).clamp(120.0, 150.0); // 20% of available, min 120px, max 150px
    }
    // For medium screens (height 600-800), use medium percentage
    else if (screenHeight < 800) {
      return (availableHeight * 0.25).clamp(150.0, 200.0); // 25% of available, min 150px, max 200px
    }
    // For large screens, use larger percentage
    else {
      return (availableHeight * 0.3).clamp(200.0, 250.0); // 30% of available, min 200px, max 250px
    }
  }

  double _getAdaptiveFontSize(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // For very small screens, use smaller font
    if (screenHeight < 600) {
      return 20.0; // Smaller font for small screens
    }
    // For medium screens, use medium font
    else if (screenHeight < 800) {
      return 24.0; // Medium font for medium screens
    }
    // For large screens, use larger font
    else {
      return 28.0; // Larger font for large screens
    }
  }

  Widget _buildReviewFlag(FlashCard card) {
    final isInReview = _reviewCards.contains(card.id);
    return GestureDetector(
      onTap: () => _toggleReviewCard(card),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isInReview ? Colors.yellow : Colors.yellow.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.orange,
            width: 2,
          ),
        ),
        child: Icon(
          Icons.flag,
          size: 16,
          color: isInReview ? Colors.orange : Colors.orange.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildHintIcon() {
    final hintCount = _hintCount[_currentIndex] ?? 0;
    
    // Count remaining wrong options that aren't already blocked
    final currentBlocked = _blockedOptions[_currentIndex] ?? {};
    final wrongOptionsRemaining = _options.length - 1 - currentBlocked.length;
    
    // Can use hint if:
    // 1. We haven't used all 3 hints AND
    // 2. Either it's the 3rd hint (auto-complete) OR there's more than 1 wrong option left
    // This prevents a "giveaway" hint when only 1 wrong and 1 correct answer are left
    final canUseHint = hintCount < 3 && (hintCount == 2 || wrongOptionsRemaining > 1);
    
    return GestureDetector(
      onTap: canUseHint ? _useHint : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: canUseHint ? Colors.orange.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: canUseHint ? Colors.orange : Colors.grey,
            width: 2,
          ),
        ),
        child: Icon(
          Icons.lightbulb,
          size: 16,
          color: canUseHint ? Colors.orange : Colors.grey,
        ),
      ),
    );
  }

  void _toggleReviewCard(FlashCard card) async {
    setState(() {
      if (_reviewCards.contains(card.id)) {
        _reviewCards.remove(card.id);
      } else {
        _reviewCards.add(card.id);
      }
    });
    
    // Add or remove from review deck in provider
    try {
      final provider = context.read<FlashcardProvider>();
      if (_reviewCards.contains(card.id)) {
        await provider.addCardToReview(card);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${card.word}" to review deck'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.yellow.shade700,
          ),
        );
      } else {
        await provider.removeCardFromReview(card);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${card.word}" from review deck'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.grey.shade600,
          ),
        );
      }
    } catch (e) {
      print('🔍 MultipleChoiceView: Error toggling review card: $e');
    }
  }

  void _useHint() {
    final currentHintCount = _hintCount[_currentIndex] ?? 0;
    if (_answered || currentHintCount >= 3) return;
    
    // Check if we should allow this specific hint (same logic as in buildHintIcon)
    final currentBlocked = _blockedOptions[_currentIndex] ?? {};
    final wrongOptionsRemaining = _options.length - 1 - currentBlocked.length;
    if (currentHintCount < 2 && wrongOptionsRemaining <= 1) return;
    
    setState(() {
      _hintCount[_currentIndex] = currentHintCount + 1;
      _totalAttempts++; // Hint usage counts as an attempt for accuracy calculation
    });
    
    // Third hint: Complete the question automatically
    if (currentHintCount == 2) {
      // Auto-select the correct answer
      _selectAnswer(_correctAnswerIndex!);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Final hint: Question completed automatically (0 XP awarded)'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // First and second hints: Block wrong options
    final wrongOptions = <int>[];
    for (int i = 0; i < _options.length; i++) {
      if (i != _correctAnswerIndex && !_blockedOptions[_currentIndex]!.contains(i)) {
        wrongOptions.add(i);
      }
    }
    
    if (wrongOptions.isNotEmpty) {
      final random = Random();
      final optionToBlock = wrongOptions[random.nextInt(wrongOptions.length)];
      
      setState(() {
        _blockedOptions[_currentIndex]!.add(optionToBlock);
      });
      
      // Show feedback based on hint count
      final remainingOptions = _options.length - _blockedOptions[_currentIndex]!.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint ${currentHintCount + 1}: Blocked one wrong answer ($remainingOptions options left)'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

} 