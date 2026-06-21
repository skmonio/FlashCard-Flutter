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
import '../components/main_header.dart';
import 'add_card_view.dart';
import '../models/timed_difficulty.dart';
import '../utils/game_session_controller.dart';

class TrueFalseView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final Function(bool)? onComplete;
  final bool shuffleMode;
  final bool autoProgress;
  final bool useLivesMode;
  final int? customLives;
  final bool startFlipped;
  final bool useTimedMode;
  final TimedDifficulty? timedDifficulty;
  final StudyConfig? studyConfig;
  final int? shuffleQuestionOffset; // Offset for cumulative question count in shuffle mode
  final List<FlashCard>? answerPoolCards;
  final bool oneAnswerMode;
  final bool enableHints;

  const TrueFalseView({
    super.key,
    required this.cards,
    required this.title,
    this.onComplete,
    this.shuffleMode = false,
    this.autoProgress = false,
    this.useLivesMode = false,
    this.customLives,
    this.startFlipped = false,
    this.useTimedMode = false,
    this.timedDifficulty,
    this.studyConfig,
    this.shuffleQuestionOffset,
    this.answerPoolCards,
    this.oneAnswerMode = true,
    this.enableHints = true,
  });

  @override
  State<TrueFalseView> createState() => _TrueFalseViewState();
}

class _TrueFalseViewState extends State<TrueFalseView> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAttempts = 0;
  bool _showingResults = false;
  bool _hasShownResults = false; // Prevent multiple end screens
  bool _answered = false;
  bool? _selectedAnswer;
  bool? _correctAnswer;
  String _question = '';
  String _currentTranslation = ''; // Store the translation being tested
  bool _isQuestionMode = true; // true = word to definition, false = definition to word
  late GameSessionController _sessionController;
  
  // Track answered questions and their answers
  Map<int, bool> _answeredQuestions = {}; // question index -> selected answer
  Map<int, bool> _correctAnswersMap = {}; // question index -> correct answer value (true/false)
  Map<int, bool> _isCorrectMap = {}; // question index -> whether user's answer was correct
  Map<int, String> _questionTexts = {}; // question index -> question text
  Map<int, bool> _questionModes = {}; // question index -> is question mode
  Map<int, String> _translations = {}; // question index -> translation being tested
  Set<int> _autoProgressedQuestions = {}; // Track which questions have been auto-progressed
  int _activeQuestionIndex = 0; // Track the furthest question that auto progress has reached
  
  // Timer variables for timed mode
  Timer? _timer;
  int _timeRemaining = 0;
  int _totalTime = 0;
  bool _timeUp = false;
  bool _useTimedMode = false;
  
  // Maintain our own copy of cards that can be updated
  late List<FlashCard> _currentCards;
  
  // Auto progress timer
  Timer? _autoProgressTimer;
  
  // Lives system
  int _lives = 0;
  int _maxLives = 0;
  bool _useLivesMode = false;
  
  Map<int, Set<int>> _disabledOptions = {}; // question index -> set of disabled wrong option indices
  
  // Animation controllers for feedback
  late AnimationController _shakeController;
  late AnimationController _successController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;
  int _consecutiveCorrect = 0; // Streak tracking
  
  // Review tracking
  Set<String> _reviewCards = {}; // card IDs marked for review
  String? _reviewStatusMessage;
  Timer? _reviewStatusTimer;

  // Consecutive-answer tracking to prevent mindless tapping
  bool? _lastTrueOrFalse;
  int _consecutiveSameCount = 0;

  @override
  void initState() {
    super.initState();
    
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

    _useTimedMode = widget.useTimedMode;
    if (_useTimedMode) {
      _timeRemaining = GameDifficultyHelper.getTimeForDifficulty(widget.timedDifficulty);
      _totalTime = _timeRemaining;
    }

    // Initialize animation controllers
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_shakeController);

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.05).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_successController);
    
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

  @override
  void dispose() {
    // Remove listener when disposing
    final provider = context.read<FlashcardProvider>();
    provider.removeListener(_onProviderChanged);
    
    // Cancel timers
    _autoProgressTimer?.cancel();
    _timer?.cancel();
    
    // Dispose animation controllers
    _shakeController.dispose();
    _successController.dispose();
    
    super.dispose();
  }


  void _onProviderChanged() {
    // Refresh cards from the provider when cards are updated
    if (mounted) {
      _refreshCardsFromProvider();
    }
  }
  
  /// Get default lives based on difficulty (assuming medium difficulty for now)
  int _getDefaultLives() {
    return 2;
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
    
    // Update our current cards list
    setState(() {
      _currentCards = updatedCards;
      
      // If we're currently viewing a card that was updated, regenerate the question
      if (_currentIndex < _currentCards.length && !_showingResults) {
        _generateQuestion();
      }
    });
  }

  void _generateQuestion() {
    if (_currentIndex >= _currentCards.length) {
      // Calculate success rate
      final successRate = _totalAttempts > 0 ? (_correctAnswers / _totalAttempts) : 0.0;
      final wasSuccessful = successRate >= 0.6; // 60% or higher is considered successful
      
      // Award XP for the session if not in shuffle mode
      _awardXp();
      
      // Stop timer on completion
      _timer?.cancel();

      // Call the onComplete callback if provided
      if (widget.onComplete != null) {
        widget.onComplete!(wasSuccessful);
        return;
      }
      
      setState(() {
        _showingResults = true;
      });
      // Play completion sound when test is finished
      SoundManager().playCompleteSound();
      return;
    }

    // Check if this question has already been answered
    if (_answeredQuestions.containsKey(_currentIndex)) {
      // Load existing question data
      _isQuestionMode = _questionModes[_currentIndex]!;
      _question = _questionTexts[_currentIndex]!;
      _correctAnswer = _correctAnswersMap[_currentIndex]!;
      _currentTranslation = _translations[_currentIndex]!;
      _selectedAnswer = _answeredQuestions[_currentIndex]!;
      _answered = true;
      return;
    }

    final currentCard = _currentCards[_currentIndex];
    final random = Random();
    
    // Reset question state for new question
    _question = '';
    _correctAnswer = null;
    _currentTranslation = '';
    
    // Choose question mode based on flipped mode settings
    _isQuestionMode = !widget.startFlipped; // Use flipped mode setting
    
    // Get correct answer based on question mode
    final correctAnswer = _isQuestionMode ? currentCard.definition : currentCard.word;
    
    // Get other cards for wrong options
    final answerPool = _getAnswerPoolForCard(currentCard);
    final otherCards = answerPool.where((card) => card.id != currentCard.id).toList();
    
    // 50% chance of true, 50% chance of false — but cap runs at 2 consecutive same answers
    bool isTrue;
    if (_lastTrueOrFalse != null && _consecutiveSameCount >= 2) {
      // Force the opposite after 2 in a row
      isTrue = !_lastTrueOrFalse!;
    } else {
      isTrue = random.nextBool();
    }
    // Track for next question
    if (_lastTrueOrFalse == isTrue) {
      _consecutiveSameCount++;
    } else {
      _consecutiveSameCount = 1;
    }
    _lastTrueOrFalse = isTrue;
    
    if (isTrue) {
      // True question - use correct answer
      if (_isQuestionMode) {
        _question = 'Does the following word "${currentCard.word}" mean "${correctAnswer}"?';
      } else {
        _question = 'Does the following definition "${currentCard.definition}" mean "${correctAnswer}"?';
      }
      _currentTranslation = correctAnswer;
      _correctAnswer = true;
    } else {
      // False question - use wrong answer from another card
      if (otherCards.isNotEmpty) {
        // Shuffle other cards to get more variety
        otherCards.shuffle();
        
        String wrongAnswer = '';
        bool foundDifferentAnswer = false;
        
        // Try each card until we find one with a truly different answer
        for (final otherCard in otherCards) {
          final otherAnswer = _isQuestionMode ? otherCard.definition : otherCard.word;
          if (otherAnswer.toLowerCase().trim() != correctAnswer.toLowerCase().trim()) {
            wrongAnswer = otherAnswer;
            foundDifferentAnswer = true;
            break;
          }
        }
        
        if (foundDifferentAnswer) {
          if (_isQuestionMode) {
            _question = 'Does the following word "${currentCard.word}" mean "${wrongAnswer}"?';
          } else {
            _question = 'Does the following definition "${currentCard.definition}" mean "${wrongAnswer}"?';
          }
          _currentTranslation = wrongAnswer;
          _correctAnswer = false;
        } else {
          // If all answers are somehow the same, try a different approach
          // Use a completely wrong answer by combining words or using a generic wrong answer
          final generatedWrongAnswer = _generateWrongAnswer(currentCard, otherCards);
          if (_isQuestionMode) {
            _question = 'Does the following word "${currentCard.word}" mean "${generatedWrongAnswer}"?';
          } else {
            _question = 'Does the following definition "${currentCard.definition}" mean "${generatedWrongAnswer}"?';
          }
          _currentTranslation = generatedWrongAnswer;
          _correctAnswer = false;
        }
      } else {
        // If no other cards available, generate a wrong answer
        final generatedWrongAnswer = _generateWrongAnswer(currentCard, []);
        if (_isQuestionMode) {
          _question = 'Does the following word "${currentCard.word}" mean "${generatedWrongAnswer}"?';
        } else {
          _question = 'Does the following definition "${currentCard.definition}" mean "${generatedWrongAnswer}"?';
        }
        _currentTranslation = generatedWrongAnswer;
        _correctAnswer = false;
      }
    }
    
    // Store question data for future reference
    _questionTexts[_currentIndex] = _question;
    _correctAnswersMap[_currentIndex] = _correctAnswer!;
    _questionModes[_currentIndex] = _isQuestionMode;
    _translations[_currentIndex] = _currentTranslation;
    
    setState(() {
      _answered = false;
      _selectedAnswer = null;
    });

    // Reset timer for new question
    if (_useTimedMode) {
      _resetTimer();
    }
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
    if (_answered || _timeUp) return;
    
    final currentCard = _currentCards[_currentIndex];
    
    setState(() {
      _answered = true;
      _timeUp = true;
      _totalAttempts++;
      _correctAnswersMap[_currentIndex] = false;
      _answeredQuestions[_currentIndex] = false; // Mark as answered (incorrect)
    });
    
    _sessionController.recordIncorrect(
      currentCard,
      exerciseType: 'True/False',
      difficulty: GameDifficulty.medium,
      isTimeout: true,
    );
    
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

  void _goToPreviousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _generateQuestion();
    }
  }

  bool _canUseNextButton() {
    if (!_answered) return false;
    
    // In shuffle mode, always allow next button after answering
    if (widget.shuffleMode) {
      return true;
    }
    
    // Always allow finish button on the last question
    if (_currentIndex == widget.cards.length - 1) {
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

  String _getTranslationForQuestion() {
    // Use the stored translation that was generated for this question
    return _currentTranslation;
  }

  String _generateWrongAnswer(FlashCard card, List<FlashCard> otherCards) {
    // Create plausible but wrong answers based on question mode
    final random = Random();
    
    if (_isQuestionMode) {
      // For word to definition mode, generate wrong definitions
      final wrongDefinitions = [
        'a type of food',
        'an animal',
        'a color',
        'a number',
        'a place',
        'an object',
        'an action',
        'a feeling',
        'a time period',
        'a weather condition',
      ];
      
      // If we have other cards, try to use one of their definitions
      if (otherCards.isNotEmpty) {
        final randomCard = otherCards[random.nextInt(otherCards.length)];
        return randomCard.definition;
      }
      
      // Otherwise use a generic wrong definition
      return wrongDefinitions[random.nextInt(wrongDefinitions.length)];
    } else {
      // For definition to word mode, generate wrong words
      final wrongWords = [
        'huis',
        'auto',
        'boek',
        'hond',
        'kat',
        'man',
        'vrouw',
        'kind',
        'water',
        'brood',
      ];
      
      // If we have other cards, try to use one of their words
      if (otherCards.isNotEmpty) {
        final randomCard = otherCards[random.nextInt(otherCards.length)];
        return randomCard.word;
      }
      
      // Otherwise use a generic wrong word
      return wrongWords[random.nextInt(wrongWords.length)];
    }
  }

  void _goToNextQuestion() {
    // In shuffle mode, we only have one question, so call the callback immediately
    if (widget.shuffleMode) {
      // Use the stored isCorrect value from when the answer was selected
      final isCorrect = _isCorrectMap[_currentIndex] ?? false;
      
      if (widget.onComplete != null) {
        widget.onComplete!(isCorrect);
      }
      return;
    }
    
    if (_currentIndex < widget.cards.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _generateQuestion();
    } else {
      // Show results when on last question and clicking next
      setState(() {
        _showingResults = true;
      });
      // Play completion sound when test is finished
      SoundManager().playCompleteSound();
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

  Color _getCardBorderColor(FlashCard card) {
    return CardColorUtils.getBorderColor(card);
  }

  void _selectAnswer(bool answer) {
    if (_answered) return;
    
    final isCorrect = (answer == _correctAnswer);
    final currentCard = _currentCards[_currentIndex];
    
    // Stop the timer when an answer is selected
    _timer?.cancel();
    
    // Provide haptic feedback and animations based on answer correctness
    if (isCorrect) {
      _successController.forward(from: 0);
      _consecutiveCorrect++;
      _sessionController.recordCorrect(
        currentCard,
        exerciseType: 'True/False',
        difficulty: GameDifficulty.medium,
      );
    } else {
      _shakeController.forward(from: 0);
      _consecutiveCorrect = 0; // Reset streak
      _sessionController.recordIncorrect(
        currentCard,
        exerciseType: 'True/False',
        difficulty: GameDifficulty.medium,
      );
    }

    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      _totalAttempts++;
      
      // Store the answer and whether it was correct
      _answeredQuestions[_currentIndex] = answer;
      _isCorrectMap[_currentIndex] = isCorrect;
      
      if (isCorrect) {
        _correctAnswers++;
      } else {
        // Handle lives system
        if (_useLivesMode) {
          _lives--;
          
          if (_lives <= 0) {
            _showGameOverScreen();
            return;
          }
        }
      }
    });
    
    // Auto progress logic (disabled in shuffle mode to allow manual control)
    if (widget.autoProgress && !widget.shuffleMode) {
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
  }

  Future<void> _updateCardInProvider(FlashCard card) async {
    try {
      final provider = context.read<FlashcardProvider>();
      
      // Update the card in the provider to save the XP changes
      await provider.updateCard(card);
      
    } catch (e) {
      // Handle error
    }
  }

  void _showGameOverScreen() {
    setState(() {
      _showingResults = true;
    });
    
    // Award XP for the session
    _awardXp();
    
    // Play game over sound
    SoundManager().playCompleteSound();
  }
  
  Color _getButtonColor(bool isTrue) {
    if (!_answered) {
      // Use vibrant colors when not answered
      return isTrue ? Colors.blue.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1);
    }
    
    if (isTrue == _correctAnswer) {
      return Colors.green.withValues(alpha: 0.2);
    } else if (isTrue == _selectedAnswer && isTrue != _correctAnswer) {
      return Colors.red.withValues(alpha: 0.2);
    }
    
    return Colors.grey.withValues(alpha: 0.1);
  }

  Color _getButtonBorderColor(bool isTrue) {
    if (!_answered) {
      // Use vibrant colors when not answered
      return isTrue ? Colors.blue : Colors.orange;
    }
    
    if (isTrue == _correctAnswer) {
      return Colors.green;
    } else if (isTrue == _selectedAnswer && isTrue != _correctAnswer) {
      return Colors.red;
    }
    
    return Colors.grey.withValues(alpha: 0.3);
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

    if (_showingResults) {
      // Go directly to word progress instead of showing completion screen
      if (!_hasShownResults) {
        _hasShownResults = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showWordProgress();
        });
      }
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final currentCard = _currentCards[_currentIndex];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          MainHeader(
            title: 'True/False',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Question text above card
                  Text(
                    'Does the following',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Card with theme-adaptive background and colored outline
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: _getAdaptiveCardHeight(context),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.surface 
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getCardBorderColor(currentCard),
                            width: 4,
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
                            _isQuestionMode ? currentCard.word : currentCard.definition,
                            style: TextStyle(
                              fontSize: _getAdaptiveFontSize(context),
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
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // "Translates to" text
                  Text(
                    'Translates to',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Translation box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _getTranslationForQuestion(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // True/False buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildAnswerButton(true),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildAnswerButton(false),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Answer feedback (show when incorrect OR when correctly answered FALSE)
                  if (_answered && (_selectedAnswer != _correctAnswer || (_selectedAnswer == false && _correctAnswer == false)))
                    _buildAnswerFeedback(),

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
    final progress = widget.cards.isEmpty ? 0.0 : _currentIndex / widget.cards.length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              // Left side: Card count
              Expanded(
                child: Text(
                  'Card ${widget.shuffleMode && widget.shuffleQuestionOffset != null ? (widget.shuffleQuestionOffset! + _currentIndex + 1) : (_currentIndex + 1)}/${widget.cards.length}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              
              // Middle side: Lives and/or streak and/or timer
              if (widget.useLivesMode || _useTimedMode || _consecutiveCorrect >= 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.useLivesMode) ...[
                        _buildLivesIndicator(),
                        if (_useTimedMode || _consecutiveCorrect >= 3) const SizedBox(width: 8),
                      ],
                      if (_useTimedMode) ...[
                        _buildTimerIndicator(),
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

  Widget _buildTimerIndicator() {
    if (_totalTime == 0) return const SizedBox.shrink();
    final progress = _timeRemaining / _totalTime;
    Color timerColor = Colors.green;
    if (progress < 0.3) {
      timerColor = Colors.red;
    } else if (progress < 0.6) {
      timerColor = Colors.orange;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer,
          color: timerColor,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$_timeRemaining',
          style: TextStyle(
            color: timerColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
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
                label: Text(_currentIndex == widget.cards.length - 1 ? 'Finish' : 'Next'),
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
  
  Widget _buildLivesIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_maxLives, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            index < _lives ? Icons.favorite : Icons.favorite_border,
            color: Colors.red,
            size: 18,
          ),
        );
      }),
    );
  }
  

  Widget _buildAnswerButton(bool isTrue) {
    return AnimatedBuilder(
      animation: Listenable.merge([_shakeController, _successController]),
      builder: (context, child) {
        // Shake offset calculation
        double shakeOffset = 0;
        if (_shakeController.isAnimating && _selectedAnswer == isTrue && isTrue != _correctAnswer) {
          shakeOffset = sin(_shakeController.value * pi * 4) * 8;
        }
        
        // Success scale calculation
        double successScale = 1.0;
        if (_successController.isAnimating && isTrue == _correctAnswer && _answered) {
          successScale = 1.0 + sin(_successController.value * pi) * 0.1;
        }

        final isCorrectOption = (isTrue == _correctAnswer);
        final isSelectedWrong = (_selectedAnswer == isTrue && !isCorrectOption);
        
        Color buttonColor = Colors.white;
        Color borderColor = Colors.grey.withValues(alpha: 0.3);
        Color textColor = Colors.black87;
        
        if (_answered) {
          if (isCorrectOption) {
            buttonColor = Colors.green.withValues(alpha: 0.1);
            borderColor = Colors.green;
            textColor = Colors.green;
          } else if (isSelectedWrong) {
            buttonColor = Colors.red.withValues(alpha: 0.1);
            borderColor = Colors.red;
            textColor = Colors.red;
          } else {
            buttonColor = Colors.grey.withValues(alpha: 0.05);
            borderColor = Colors.grey.withValues(alpha: 0.2);
            textColor = Colors.grey;
          }
        }

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Transform.scale(
            scale: successScale,
            child: Container(
              width: double.infinity,
              height: 60,
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _answered ? null : () => _selectAnswer(isTrue),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: buttonColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: isCorrectOption && _answered ? 3 : 2,
                      ),
                      boxShadow: isCorrectOption && _answered ? [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ] : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: borderColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: _answered && isCorrectOption
                              ? const Icon(Icons.check, color: Colors.green, size: 18)
                              : _answered && isSelectedWrong
                                ? const Icon(Icons.close, color: Colors.red, size: 18)
                                : Text(
                                    isTrue ? 'T' : 'F',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: borderColor,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isTrue ? 'TRUE' : 'FALSE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        if (_answered && isCorrectOption)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                          ),
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

  Widget _buildAnswerFeedback() {
    final currentCard = _currentCards[_currentIndex];
    final isCorrectAnswer = _selectedAnswer == _correctAnswer;
    
    // Determine color and message based on correctness
    Color textColor;
    String message;
    
    // Get the correct answer based on flipped state
    String correctAnswer;
    if (_isQuestionMode) {
      // Normal mode: showing word, asking about definition
      correctAnswer = currentCard.definition;
    } else {
      // Flipped mode: showing definition, asking about word
      correctAnswer = currentCard.word;
    }
    
    if (isCorrectAnswer) {
      // User answered correctly - show green positive feedback
      textColor = Colors.green;
      // If the correct answer was FALSE, also show the true translation/word
      if (_correctAnswer == false) {
        message = 'Correct – the answer is: $correctAnswer';
      } else {
        message = 'Correct!';
      }
    } else {
      // User answered incorrectly - show red feedback
      textColor = Colors.red;
      message = 'The correct answer is: $correctAnswer';
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
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
        title: 'True/False',
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
            _hasShownResults = false;
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
            _isCorrectMap.clear();
            _questionTexts.clear();
            _questionModes.clear();
            _translations.clear();
            _lastTrueOrFalse = null;
            _consecutiveSameCount = 0;
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
    return Semantics(
      label: isInReview ? 'Remove from review deck' : 'Add to review deck',
      button: true,
      child: GestureDetector(
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
      ),
    );
  }

  Future<void> _toggleReviewCard(FlashCard card) async {
    setState(() {
      if (_reviewCards.contains(card.id)) {
        _reviewCards.remove(card.id);
      } else {
        _reviewCards.add(card.id);
      }
    });

    try {
      final provider = context.read<FlashcardProvider>();
      if (_reviewCards.contains(card.id)) {
        await provider.addCardToReview(card);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "${card.word}" to review deck'),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.yellow.shade700,
            ),
          );
        }
      } else {
        await provider.removeCardFromReview(card);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${card.word}" from review deck'),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.grey.shade600,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating review deck: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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



  void _shuffleAndRestart() {
    // Reset game state after shuffling
    setState(() {
      _currentIndex = 0;
      _correctAnswers = 0;
      _totalAttempts = 0;
      _answered = false;
      _selectedAnswer = null;
      _correctAnswer = null;
      _question = '';
      _currentTranslation = '';
      _isQuestionMode = true;
      _answeredQuestions.clear();
      _correctAnswersMap.clear();
      _isCorrectMap.clear();
      _questionTexts.clear();
      _questionModes.clear();
      _translations.clear();
      _autoProgressedQuestions.clear();
      _activeQuestionIndex = 0;
      _showingResults = false;
      _hasShownResults = false;
      _consecutiveCorrect = 0;
      _reviewCards.clear();
      _reviewStatusMessage = null;
      _lastTrueOrFalse = null;
      _consecutiveSameCount = 0;

      _sessionController = GameSessionController(
        flashcardProvider: context.read<FlashcardProvider>(),
        userProfileProvider: context.read<UserProfileProvider>(),
      );
      
      _disabledOptions.clear();
      
      // Reset lives if in lives mode
      if (_useLivesMode) {
        _lives = _maxLives;
      }
      
      // Reset timer
      _timer?.cancel();
      if (_useTimedMode) {
        _timeRemaining = _totalTime;
        _timeUp = false;
      }
    });
    
    _generateQuestion();
    
    // Restart timer if in timed mode
    if (_useTimedMode) {
      _startTimer();
    }
  }

  Future<void> _awardXp() async {
    await _sessionController.finalizeSession();
  }


  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit Session?'),
        content: const Text('Are you sure you want to quit? Your progress for this session will not be saved.'),
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
            child: const Text('Quit'),
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
        content: const Text('Are you sure you want to return to the home screen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }
}