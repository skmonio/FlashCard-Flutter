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
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/dutch_word_exercise.dart';
import '../components/xp_progress_widget.dart';
import '../components/animated_xp_counter.dart';
import '../utils/game_end_screen.dart';
import '../utils/game_difficulty_helper.dart';
import '../components/main_header.dart';
import 'add_card_view.dart';

class TrueFalseView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final Function(bool)? onComplete;
  final bool shuffleMode;
  final bool autoProgress;
  final bool useLivesMode;
  final int? customLives;
  final bool startFlipped;
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
    this.studyConfig,
    this.shuffleQuestionOffset,
    this.answerPoolCards,
    this.oneAnswerMode = true,
    this.enableHints = true,
  });

  @override
  State<TrueFalseView> createState() => _TrueFalseViewState();
}

class _TrueFalseViewState extends State<TrueFalseView> {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  bool _showingResults = false;
  bool _hasShownResults = false; // Prevent multiple end screens
  bool _answered = false;
  bool? _selectedAnswer;
  bool? _correctAnswer;
  String _question = '';
  String _currentTranslation = ''; // Store the translation being tested
  bool _isQuestionMode = true; // true = word to definition, false = definition to word
  final GameSession _gameSession = GameSession();
  
  // Track answered questions and their answers
  Map<int, bool> _answeredQuestions = {}; // question index -> selected answer
  Map<int, bool> _correctAnswersMap = {}; // question index -> correct answer value (true/false)
  Map<int, bool> _isCorrectMap = {}; // question index -> whether user's answer was correct
  Map<int, String> _questionTexts = {}; // question index -> question text
  Map<int, bool> _questionModes = {}; // question index -> is question mode
  Map<int, String> _translations = {}; // question index -> translation being tested
  Set<int> _autoProgressedQuestions = {}; // Track which questions have been auto-progressed
  int _activeQuestionIndex = 0; // Track the furthest question that auto progress has reached
  
  // Maintain our own copy of cards that can be updated
  late List<FlashCard> _currentCards;
  
  // Auto progress timer
  Timer? _autoProgressTimer;
  
  // Lives system
  int _lives = 0;
  int _maxLives = 0;
  bool _useLivesMode = false;
  
  // RPG word progress tracking
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  Map<String, int> _initialHPPerWord = {}; // Track initial HP when word is first encountered
  List<FlashCard> _studiedWords = [];
  Map<int, Set<int>> _disabledOptions = {}; // question index -> set of disabled wrong option indices
  
  // Review tracking
  Set<String> _reviewCards = {}; // card IDs marked for review

  @override
  void initState() {
    super.initState();
    
    // Initialize our copy of cards
    _currentCards = List<FlashCard>.from(widget.cards);
    
    // Initialize lives system
    _useLivesMode = widget.useLivesMode;
    if (_useLivesMode) {
      _maxLives = widget.customLives ?? _getDefaultLives();
      _lives = _maxLives;
    }
    
    _generateQuestion();
    
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
    
    // Cancel auto progress timer
    _autoProgressTimer?.cancel();
    
    super.dispose();
  }

  void _ensureCardTracked(FlashCard card) {
    if (_studiedWords.any((word) => word.id == card.id)) return;
    _studiedWords.add(card);
    _initialHPPerWord[card.id] = card.currentHP;
  }

  void _applyHpPenalty(FlashCard card, {required bool wasCorrect}) {
    if (wasCorrect) {
      card.markCorrect(GameDifficulty.medium);
    } else {
      card.markIncorrect(GameDifficulty.medium);
    }
  }

  void _onProviderChanged() {
    // Refresh cards from the provider when cards are updated
    if (mounted) {
      _refreshCardsFromProvider();
    }
  }
  
  /// Get default lives based on difficulty (assuming medium difficulty for now)
  int _getDefaultLives() {
    // For now, return medium difficulty lives
    // In the future, this could be based on actual difficulty detection
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
    
    print('🔍 TrueFalseView: Refreshed cards from provider');
  }

  void _generateQuestion() {
    if (_currentIndex >= _currentCards.length) {
      // Calculate success rate
      final successRate = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered) : 0.0;
      final wasSuccessful = successRate >= 0.6; // 60% or higher is considered successful
      
      // Award XP for the session if not in shuffle mode
      _awardXp();
      
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
    
    // 50% chance of true, 50% chance of false
    final isTrue = random.nextBool();
    
    if (isTrue) {
      // True question - use correct answer
      if (_isQuestionMode) {
        _question = 'Does the following word "${currentCard.word}" mean "${correctAnswer}"?';
      } else {
        _question = 'Does the following definition "${currentCard.definition}" mean "${correctAnswer}"?';
      }
      _currentTranslation = correctAnswer;
      _correctAnswer = true;
      print('🔍 TrueFalse: TRUE question - "${currentCard.word}" means "${correctAnswer}" = TRUE');
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
            print('🔍 TrueFalse: Found different answer: "${wrongAnswer}" vs correct "${correctAnswer}"');
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
          print('🔍 TrueFalse: FALSE question - "${currentCard.word}" does NOT mean "${wrongAnswer}" = FALSE');
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
          print('🔍 TrueFalse: Generated wrong answer: "${generatedWrongAnswer}" for FALSE question');
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
        print('🔍 TrueFalse: Generated wrong definition: "${generatedWrongAnswer}" for FALSE question (no other cards)');
      }
    }
    
    // Store question data for future reference
    _questionTexts[_currentIndex] = _question;
    _correctAnswersMap[_currentIndex] = _correctAnswer!;
    _questionModes[_currentIndex] = _isQuestionMode;
    _translations[_currentIndex] = _currentTranslation;
    
    // Debug logging
    print('🔍 TrueFalseView: Generated question for "${currentCard.word}"');
    print('🔍 TrueFalseView: Question: "$_question"');
    print('🔍 TrueFalseView: Correct answer: $_correctAnswer');
    print('🔍 TrueFalseView: Question mode: ${_isQuestionMode ? "word to definition" : "definition to word"}');
    
    setState(() {
      _answered = false;
      _selectedAnswer = null;
    });
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
      // This ensures we use the exact same correctness check that was used when the answer was submitted
      final isCorrect = _isCorrectMap[_currentIndex] ?? false;
      
      // Fallback: if for some reason isCorrect wasn't stored, calculate it from stored values
      if (!_isCorrectMap.containsKey(_currentIndex)) {
        final storedCorrectAnswer = _correctAnswersMap[_currentIndex];
        final userAnswer = _selectedAnswer ?? _answeredQuestions[_currentIndex];
        final calculatedIsCorrect = userAnswer != null && storedCorrectAnswer != null && userAnswer == storedCorrectAnswer;
        print('⚠️ TrueFalseView: isCorrect not found in map, calculated: $calculatedIsCorrect (user: $userAnswer, correct: $storedCorrectAnswer)');
        if (widget.onComplete != null) {
          widget.onComplete!(calculatedIsCorrect);
        }
      } else {
        print('🔍 TrueFalseView: Using stored isCorrect value: $isCorrect');
        if (widget.onComplete != null) {
          widget.onComplete!(isCorrect);
        }
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
    // Generate consistent vibrant colors based on card content
    final vibrantColors = [
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF673AB7), // Deep Purple
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFF2196F3), // Blue
      const Color(0xFF03A9F4), // Light Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF009688), // Teal
      const Color(0xFF4CAF50), // Green
      const Color(0xFF8BC34A), // Light Green
      const Color(0xFFCDDC39), // Lime
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFFFFC107), // Amber
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF795548), // Brown
    ];
    
    // Use card content to generate consistent index
    final hash = card.word.hashCode + card.definition.hashCode;
    final index = hash.abs() % vibrantColors.length;
    return vibrantColors[index];
  }

  void _selectAnswer(bool answer) {
    if (_answered) return;
    
    // Ensure _correctAnswer is not null before comparing
    if (_correctAnswer == null) {
      print('⚠️ TrueFalseView: _correctAnswer is null! Attempting to use stored value from map.');
      _correctAnswer = _correctAnswersMap[_currentIndex];
      if (_correctAnswer == null) {
        print('❌ TrueFalseView: Cannot determine correct answer! Question may not have been generated properly.');
        return;
      }
    }
    
    final isCorrect = (answer == _correctAnswer);
    final currentCard = _currentCards[_currentIndex];
    
    // Provide haptic feedback based on answer correctness
    if (isCorrect) {
      HapticService().successFeedback();
    } else {
      HapticService().errorFeedback();
    }
    
    print('🔍 TrueFalse: Answer selected - User chose: ${answer ? "TRUE" : "FALSE"}, Correct answer: ${_correctAnswer! ? "TRUE" : "FALSE"}, Is correct: $isCorrect');
    print('🔍 TrueFalse: Question was: $_question');
    
    // Track XP for this answer
    XpService.recordAnswer(_gameSession, isCorrect);
    
    // Track this card the first time it appears so the end screen has HP baselines
    _ensureCardTracked(currentCard);
    
    // Apply HP penalty exactly once per card per session
    _applyHpPenalty(currentCard, wasCorrect: isCorrect);
    
    if (widget.shuffleMode) {
      // Shuffle mode handles XP externally but we still persist mastery updates
      _wordMastery[currentCard.id] = currentCard.learningMastery;
      _updateCardInProvider(currentCard);
    } else {
      // In standalone mode, handle full tracking
      _awardXPToWord(currentCard, isCorrect);
      _updateCardInProvider(currentCard);
    }
    
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      _totalAnswered++;
      
      // Store the answer and whether it was correct
      _answeredQuestions[_currentIndex] = answer;
      _isCorrectMap[_currentIndex] = isCorrect;
      
      if (isCorrect) {
        _correctAnswers++;
        // Play correct sound
        SoundManager().playCorrectSound();
      } else {
        // Play wrong sound
        SoundManager().playWrongSound();
        
        // Handle lives system
        if (_useLivesMode) {
          _lives--;
          print('🔍 TrueFalseView: Lost a life! Lives remaining: $_lives');
          
          if (_lives <= 0) {
            print('🔍 TrueFalseView: Game over! No lives remaining');
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
      print('🔍 TrueFalseView: Updated card "${card.word}" in provider - current XP: ${card.learningMastery.currentXP}');
      
    } catch (e) {
      print('🔍 TrueFalseView: Error updating card in provider: $e');
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
  
  Future<void> _syncToDutchWords(FlashCard card, bool wasCorrect) async {
    try {
      // Import the DutchWordExerciseProvider
      final dutchProvider = context.read<DutchWordExerciseProvider>();
      
      // Find the corresponding Dutch word exercise
      final wordExercise = dutchProvider.wordExercises.firstWhere(
        (exercise) => exercise.targetWord.toLowerCase() == card.word.toLowerCase(),
        orElse: () => DutchWordExercise(
          id: '',
          targetWord: '',
          wordTranslation: '',
          deckId: '',
          deckName: '',
          category: WordCategory.common,
          difficulty: ExerciseDifficulty.beginner,
          exercises: [],
          createdAt: DateTime.now(),
          isUserCreated: true,
        ),
      );
      
      if (wordExercise.id.isNotEmpty) {
        // Update the Dutch word exercise learning progress
        await dutchProvider.updateLearningProgress(wordExercise.id, wasCorrect);
        print('🔍 TrueFalseView: Synced progress to Dutch word exercise "${wordExercise.targetWord}"');
      }
    } catch (e) {
      print('🔍 TrueFalseView: Error syncing to Dutch words: $e');
    }
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
                  
                  // Navigation and Edit buttons row
                  Row(
                    children: [
                      // Back button (always show, greyed out when not available)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _currentIndex > 0 ? _goToPreviousQuestion : null,
                          icon: const Icon(Icons.arrow_back_ios, size: 16),
                          label: const Text('Back'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentIndex > 0 ? Colors.blue : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Edit button in center
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editCurrentCard(),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Next/Finish button (always show, greyed out when not available)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _canUseNextButton() ? _goToNextQuestion : null,
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text(_currentIndex == widget.cards.length - 1 ? 'Finish' : 'Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canUseNextButton() ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
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
    );
  }

  Widget _buildProgressBar() {
    final progress = _currentIndex / widget.cards.length;
    final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered * 100).toInt() : 0;
    
    // In shuffle mode, show cumulative question count (e.g., 1/1, 2/2, 3/3...)
    final String questionCountText;
    if (widget.shuffleMode && widget.shuffleQuestionOffset != null) {
      final currentQuestionNum = (widget.shuffleQuestionOffset ?? 0) + _currentIndex + 1;
      questionCountText = '$currentQuestionNum/$currentQuestionNum';
    } else {
      questionCountText = '${_currentIndex + 1}/${widget.cards.length}';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(questionCountText),
              // Show lives in the middle if active
              if (_useLivesMode) _buildLivesIndicator(),
              Text('$accuracy%'),
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
        child: _buildLivesIndicator(),
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
    return Container(
      width: double.infinity,
      height: 60, // Reduced height
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectAnswer(isTrue),
          borderRadius: BorderRadius.circular(12), // Smaller radius
          child: Container(
            padding: const EdgeInsets.all(12), // Reduced padding
            decoration: BoxDecoration(
              color: _getButtonColor(isTrue),
              borderRadius: BorderRadius.circular(12), // Smaller radius
              border: Border.all(
                color: _getButtonBorderColor(isTrue),
                width: 2, // Thinner border
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36, // Smaller circle
                  height: 36, // Smaller circle
                  decoration: BoxDecoration(
                    color: _getButtonBorderColor(isTrue).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      isTrue ? 'T' : 'F',
                      style: TextStyle(
                        fontSize: 18, // Smaller font
                        fontWeight: FontWeight.bold,
                        color: _getButtonBorderColor(isTrue),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12), // Reduced spacing
                Text(
                  isTrue ? 'TRUE' : 'FALSE',
                  style: TextStyle(
                    fontSize: 16, // Smaller font
                    fontWeight: FontWeight.bold,
                    color: _getButtonBorderColor(isTrue),
                  ),
                ),
                const SizedBox(width: 12), // Reduced spacing
                // Only show check/cross when answered and this button is the correct answer or wrong selected answer
                if (_answered && isTrue == _correctAnswer)
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                if (_answered && isTrue == _selectedAnswer && isTrue != _correctAnswer)
                  const Icon(Icons.cancel, color: Colors.red, size: 24),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildResultsView() {
    final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered * 100).toInt() : 0;
    
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.home),
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
                    _buildStatCard('Questions', _totalAnswered.toString(), Icons.quiz),
                    const SizedBox(height: 16),
                    _buildStatCard('Correct', _correctAnswers.toString(), Icons.check_circle, Colors.green),
                    const SizedBox(height: 16),
                    _buildStatCard('Incorrect', (_totalAnswered - _correctAnswers).toString(), Icons.cancel, Colors.red),
                    const SizedBox(height: 16),
                    _buildStatCard('XP Earned', '', Icons.star, Colors.amber,
                      AnimatedXpCounter(xpGained: _xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp))),
                    
                    // Swipe hint if XP was gained
                    if (_xpGainedPerWord.values.isNotEmpty) ...[
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
                        
                        setState(() {
                          _currentIndex = 0;
                          _correctAnswers = 0;
                          _totalAnswered = 0;
                          _showingResults = false;
                          _answered = false;
                          _selectedAnswer = null;
                          _gameSession.reset(); // Reset XP tracking
                          
                          // Shuffle the cards for a different order
                          _currentCards.shuffle(Random());
                          
                          // Reset all navigation state
                          _answeredQuestions.clear();
                          _correctAnswersMap.clear();
                          _isCorrectMap.clear();
                          _questionTexts.clear();
                          _questionModes.clear();
                          _translations.clear();
                          
                          // Reset RPG tracking
                          _xpGainedPerWord.clear();
                          _wordMastery.clear();
                          _studiedWords.clear();
                          _reviewCards.clear();
 
                          // Reset wrong attempts tracking
                        });
                        _generateQuestion();
                      },
                      child: const Text('Test Again'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
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
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  void _awardXp() {
    // Calculate total XP from actual word XP gained
    final totalXPGained = _xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp);
    
    if (!widget.shuffleMode && totalXPGained > 0) {
      print('🔍 TrueFalse: Awarding $totalXPGained XP to profile');
      final userProfileProvider = context.read<UserProfileProvider>();
      userProfileProvider.addXp(totalXPGained);
    } else {
      print('🔍 TrueFalse: Skipping XP award - shuffleMode: ${widget.shuffleMode}, xpGained: $totalXPGained');
    }
    
    // Update session statistics
    final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered) : 0.0;
    final isPerfect = _correctAnswers == _totalAnswered && _totalAnswered > 0;
    
    context.read<UserProfileProvider>().updateSessionStats(
      cardsStudied: _totalAnswered,
      sessionAccuracy: accuracy,
      isPerfect: isPerfect,
    );
    
    // Update streak based on study activity (Duolingo-style)
    context.read<UserProfileProvider>().updateStreakFromStudyActivity();
  }
  
  void _awardXPToWord(FlashCard card, bool isCorrect) {
    // Track studied words and initial HP BEFORE processing (so we capture HP before it's reduced)
    _ensureCardTracked(card);
    
    print('🔍 TrueFalseView: Logging result for "${card.word}" - daily attempts: ${card.learningMastery.dailyAttemptsDebug}');
    
    final latestEntry = card.learningMastery.exerciseHistory.isNotEmpty
        ? card.learningMastery.exerciseHistory.last
        : null;
    final actualXPGained = latestEntry != null
        ? (latestEntry['xpGained'] as int? ?? 0)
        : 0;
    
    if (isCorrect) {
      _xpGainedPerWord[card.id] = actualXPGained;
    } else {
      _xpGainedPerWord[card.id] = 0;
    }
    
    // Store the word mastery for display (for both correct and incorrect)
    _wordMastery[card.id] = card.learningMastery;
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
      _totalAnswered = 0;
      _showingResults = false;
      _hasShownResults = false;
      _answered = false;
      _selectedAnswer = null;
      _gameSession.reset();
      
      // Reset lives if using lives mode
      if (_useLivesMode) {
        _lives = _maxLives;
      }
      
      // Reset all navigation state
      _answeredQuestions.clear();
      _correctAnswersMap.clear();
      _isCorrectMap.clear();
      _questionTexts.clear();
      _questionModes.clear();
      _translations.clear();
      
      // Reset RPG tracking
      _xpGainedPerWord.clear();
      _wordMastery.clear();
      _studiedWords.clear();
    });
    
    _generateQuestion();
  }

  void _showWordProgress() {
    // Create copies of the current session data for the display
    final sessionStudiedWords = List<FlashCard>.from(_studiedWords);
    final sessionXpGainedPerWord = Map<String, int>.from(_xpGainedPerWord);
    final sessionWordMastery = Map<String, LearningMastery>.from(_wordMastery);
    final sessionInitialHPPerWord = Map<String, int>.from(_initialHPPerWord);
    
    GameEndScreen.show(
      context,
      GameEndResult(
        title: 'True/False',
        studiedWords: sessionStudiedWords,
        xpGainedPerWord: sessionXpGainedPerWord,
        wordMastery: sessionWordMastery,
        initialHPPerWord: sessionInitialHPPerWord,
        correctAnswers: _correctAnswers,
        totalQuestions: _totalAnswered,
        onStudyAgain: () {
          Navigator.of(context).pop();
          setState(() {
            _currentIndex = 0;
            _correctAnswers = 0;
            _totalAnswered = 0;
            _showingResults = false;
            _hasShownResults = false;
            _answered = false;
            _selectedAnswer = null;
            _gameSession.reset();
            if (_useLivesMode) {
              _lives = _maxLives;
            }
            _answeredQuestions.clear();
            _correctAnswersMap.clear();
            _isCorrectMap.clear();
            _questionTexts.clear();
            _questionModes.clear();
            _translations.clear();
            _xpGainedPerWord.clear();
            _wordMastery.clear();
            _initialHPPerWord.clear();
            _studiedWords.clear();
          });
          _generateQuestion();
        },
        onShuffle: widget.studyConfig != null
            ? () {
                Navigator.of(context).pop();
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


} 