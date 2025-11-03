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
import '../components/unified_end_screen.dart';
import '../utils/game_difficulty_helper.dart';
import 'add_card_view.dart';

class MultipleChoiceView extends StatefulWidget {
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

  const MultipleChoiceView({
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
  });

  @override
  State<MultipleChoiceView> createState() => _MultipleChoiceViewState();
}

class _MultipleChoiceViewState extends State<MultipleChoiceView> {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  bool _showingResults = false;
  bool _answered = false;
  int? _selectedAnswer;
  int? _correctAnswerIndex;
  List<String> _options = [];
  bool _isQuestionMode = true; // true = word to definition, false = definition to word
  final GameSession _gameSession = GameSession();
  
  // Lives system
  int _lives = 0;
  int _maxLives = 0;
  bool _useLivesMode = false;
  
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
  
  // RPG word progress tracking
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  List<FlashCard> _studiedWords = [];

  // Hint and review tracking
  Map<int, int> _hintCount = {}; // question index -> number of hints used (0, 1, 2, or 3)
  Map<int, Set<int>> _blockedOptions = {}; // question index -> set of blocked option indices
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
    
    // Update our current cards list
    setState(() {
      _currentCards = updatedCards;
      
      // If we're currently viewing a card that was updated, regenerate the question
      if (_currentIndex < _currentCards.length && !_showingResults) {
        _generateQuestion();
      }
    });
    
    print('🔍 MultipleChoiceView: Refreshed cards from provider');
  }

  void _generateQuestion() {
    if (_currentIndex >= _currentCards.length) {
      // Calculate success rate
      final successRate = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered) : 0.0;
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

    // Reset hint and review state for new question
    _hintCount[_currentIndex] = 0;
    _blockedOptions[_currentIndex] = <int>{};

    // Check if this question has already been generated
    if (_questionOptions.containsKey(_currentIndex)) {
      // Load existing question data
      _isQuestionMode = _questionModes[_currentIndex]!;
      _options = _questionOptions[_currentIndex]!;
      _correctAnswerIndex = _correctAnswerIndices[_currentIndex]!;
      _selectedAnswer = _answeredQuestions[_currentIndex];
      _answered = _answeredQuestions.containsKey(_currentIndex);
      return;
    }

    final currentCard = _currentCards[_currentIndex];
    final random = Random();
    
    // Choose question mode based on flipped mode settings
    _isQuestionMode = !widget.startFlipped; // Use flipped mode setting
    
    // Get correct answer
    final correctAnswer = _isQuestionMode ? currentCard.definition : currentCard.word;
    
    // Get wrong options from ALL available cards (not just selected deck) for better difficulty
    final allCards = context.read<FlashcardProvider>().cards;
    final otherCards = allCards.where((card) => card.id != currentCard.id).toList();
    final wrongOptions = <String>[];
    
    // Shuffle all other cards to get variety from any deck
    final shuffledOtherCards = List.from(otherCards)..shuffle(random);
    
    for (final card in shuffledOtherCards) {
      if (wrongOptions.length >= 3) break;
      
      final wrongOption = _isQuestionMode ? card.definition : card.word;
      if (!wrongOptions.contains(wrongOption) && wrongOption != correctAnswer) {
        wrongOptions.add(wrongOption);
      }
    }
    
    // Only use generic options as absolute last resort
    if (wrongOptions.length < 3) {
      final genericOptions = _isQuestionMode
          ? ['Not applicable', 'Different meaning', 'Other definition']
          : ['Unknown word', 'Different word', 'Other term'];
      
      while (wrongOptions.length < 3) {
        final generic = genericOptions[wrongOptions.length];
        if (!wrongOptions.contains(generic)) {
          wrongOptions.add(generic);
        }
      }
    }
    
    // Create options list with correct answer first
    _options = [correctAnswer, ...wrongOptions];
    
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
    });
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    
    final isCorrect = (index == _correctAnswerIndex);
    final currentCard = _currentCards[_currentIndex];
    
    // Provide haptic feedback based on answer correctness
    if (isCorrect) {
      HapticService().successFeedback();
    } else {
      HapticService().errorFeedback();
    }
    
    // Track XP for the answer
    XpService.recordAnswer(_gameSession, isCorrect);
    
    // In shuffle mode, reduce HP immediately for every answer attempt
    // (XP tracking is handled by shuffle view at completion)
    if (widget.shuffleMode) {
      if (isCorrect) {
        currentCard.markCorrect(GameDifficulty.medium);
        // markCorrect already adds to exerciseHistory, reducing HP
      } else {
        currentCard.markIncorrect(GameDifficulty.medium);
        // markIncorrect doesn't add to exerciseHistory, so we need to record the attempt
        final xpService = XpService();
        xpService.recordAttemptToWord(currentCard.learningMastery, "multiple_choice");
      }
      // Update the card immediately to save HP changes
      _updateCardInProvider(currentCard);
    } else {
      // In standalone mode, handle full tracking
      _awardXPToWord(currentCard, isCorrect);
      _updateCardInProvider(currentCard);
    }
    
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      _totalAnswered++;
      
      // Store the answer
      _answeredQuestions[_currentIndex] = index;
      _correctAnswersMap[_currentIndex] = isCorrect;
      
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
          print('🔍 MultipleChoiceView: Lost a life! Lives remaining: $_lives');
          
          // Check if game over
          if (_lives <= 0) {
            print('🔍 MultipleChoiceView: Game over! No lives remaining');
            _showGameOverScreen();
            return;
          }
        }
      }
    });
    
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

  Future<void> _updateCardInProvider(FlashCard card) async {
    try {
      final provider = context.read<FlashcardProvider>();
      
      // Update the card in the provider to save the XP changes
      await provider.updateCard(card);
      print('🔍 MultipleChoiceView: Updated card "${card.word}" in provider - current XP: ${card.learningMastery.currentXP}');
      
    } catch (e) {
      print('🔍 MultipleChoiceView: Error updating card in provider: $e');
    }
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
        print('🔍 MultipleChoiceView: Synced progress to Dutch word exercise "${wordExercise.targetWord}"');
      }
    } catch (e) {
      print('🔍 MultipleChoiceView: Error syncing to Dutch words: $e');
    }
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
    final vibrantColors = [
      const Color(0xFFFF6B35), // Coral/Orange-Red
      const Color(0xFFFF9900), // Bright Orange
      const Color(0xFFFFCC00), // Golden Yellow
      const Color(0xFF33CC99), // Teal/Turquoise
      const Color(0xFF00B3CC), // Cyan Blue
      const Color(0xFF9966FF), // Purple
      const Color(0xFFFF4D94), // Pink
      const Color(0xFF66E64D), // Lime Green
    ];
    
    if (card.word.isEmpty || card.definition.isEmpty) {
      return vibrantColors[0];
    }
    
    final hash = (card.word.hashCode + card.definition.hashCode).abs();
    final index = hash % vibrantColors.length;
    return vibrantColors[index];
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
          // Small header with progress bar
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _showCloseConfirmation(),
                        icon: const Icon(Icons.arrow_back_ios),
                        iconSize: 20,
                      ),
                      const Spacer(),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _showHomeConfirmation(),
                        icon: const Icon(Icons.home),
                        iconSize: 20,
                      ),
                    ],
                  ),
                ),
                // Progress bar
                _buildProgressBar(),
              ],
            ),
          ),
          
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
                      if (!_answered)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: _buildHintIcon(),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16), // Reduced spacing
                  
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
                          label: Text(_currentIndex == _currentCards.length - 1 ? 'Finish' : 'Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canUseNextButton() ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20), // Reduced spacing
                  
                  // Options
                  Expanded(
                    child: Column(
                      children: _options.asMap().entries.map((entry) {
                        final index = entry.key;
                        final option = entry.value;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8), // Reduced spacing between options
                          child: _buildOptionButton(index, option),
                        );
                      }).toList(),
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

  Widget _buildProgressBar() {
    final progress = _currentIndex / _currentCards.length;
    final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered * 100).toInt() : 0;
    
    // In shuffle mode, show cumulative question count (e.g., 1/1, 2/2, 3/3...)
    final String questionCountText;
    if (widget.shuffleMode && widget.shuffleQuestionOffset != null) {
      final currentQuestionNum = (widget.shuffleQuestionOffset ?? 0) + _currentIndex + 1;
      questionCountText = '$currentQuestionNum/$currentQuestionNum';
    } else {
      questionCountText = '${_currentIndex + 1}/${_currentCards.length}';
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
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite,
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Lives: $_lives/$_maxLives',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 16,
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
      children: [
        Icon(
          Icons.favorite,
          color: Colors.red,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$_lives/$_maxLives',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
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
    final isBlocked = _blockedOptions[_currentIndex]?.contains(index) ?? false;
    
    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBlocked ? null : () => _selectAnswer(index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12), // Reduced padding
            decoration: BoxDecoration(
              color: isBlocked ? Colors.grey.withValues(alpha: 0.3) : _getOptionColor(index),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isBlocked ? Colors.grey : _getOptionBorderColor(index),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28, // Smaller circle
                  height: 28, // Smaller circle
                  decoration: BoxDecoration(
                    color: isBlocked ? Colors.grey.withValues(alpha: 0.1) : _getOptionBorderColor(index).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isBlocked 
                      ? const Icon(Icons.block, color: Colors.grey, size: 16)
                      : Text(
                          String.fromCharCode(65 + index), // A, B, C, D
                          style: TextStyle(
                            fontSize: 14, // Smaller font
                            fontWeight: FontWeight.bold,
                            color: _getOptionBorderColor(index),
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 12), // Reduced spacing
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 14, // Smaller font
                      fontWeight: FontWeight.w500,
                      color: isBlocked ? Colors.grey : null,
                    ),
                  ),
                ),
                if (_answered && index == _correctAnswerIndex)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20), // Smaller icon
                if (_answered && index == _selectedAnswer && index != _correctAnswerIndex)
                  const Icon(Icons.cancel, color: Colors.red, size: 20), // Smaller icon
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered * 100).toInt() : 0;
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
                        print('🔍 MultipleChoiceView: Test Again button pressed');
                        
                        setState(() {
                          _currentIndex = 0;
                          _correctAnswers = 0;
                          _totalAnswered = 0;
                          _showingResults = false;
                          _answered = false;
                          _selectedAnswer = null;
                          _gameSession.reset(); // Reset XP tracking
                          
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
                          
                          // Reset RPG tracking
                          _xpGainedPerWord.clear();
                          _wordMastery.clear();
                          _studiedWords.clear();
                          
                          // Reset hint and review tracking
                          _hintCount.clear();
                          _blockedOptions.clear();
                          _reviewCards.clear();
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

  void _awardXp() {
    // Calculate total XP from actual word XP gained
    final totalXPGained = _xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp);
    
    if (totalXPGained > 0) {
      final userProfileProvider = context.read<UserProfileProvider>();
      userProfileProvider.addXp(totalXPGained);
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
    final xpService = XpService();
    
    print('🔍 MultipleChoiceView: About to process word "${card.word}" - daily attempts before: ${card.learningMastery.dailyAttemptsDebug}');
    
    if (isCorrect) {
      // Award XP for correct answers (this also records the attempt)
      xpService.addXPToWord(card.learningMastery, "test", 1);
      
      // Get the actual XP gained (after diminishing returns)
      final actualXPGained = card.learningMastery.exerciseHistory.isNotEmpty 
          ? card.learningMastery.exerciseHistory.last['xpGained'] as int 
          : 0;
      
      // Reduce XP based on number of hints used (50% for 1 hint, 25% for 2 hints, 0% for 3 hints)
      final hintCount = _hintCount[_currentIndex] ?? 0;
      final finalXPGained = hintCount == 1 
          ? (actualXPGained * 0.5).round() 
          : hintCount == 2 
              ? (actualXPGained * 0.25).round()
              : hintCount == 3
                  ? 0
                  : actualXPGained;
      
      // Track XP gained for this word in this session (add for multiple appearances in same session)
      _xpGainedPerWord[card.id] = finalXPGained;
      
      print('🔍 MultipleChoiceView: Awarded $actualXPGained XP to word "${card.word}" (Correct: $isCorrect) - daily attempts after: ${card.learningMastery.dailyAttemptsDebug}');
    } else {
      // Record attempt for incorrect answers (reduces HP but no XP)
      xpService.recordAttemptToWord(card.learningMastery, "test");
      
      // Explicitly set 0 XP for incorrect answers
      _xpGainedPerWord[card.id] = 0;
      
      print('🔍 MultipleChoiceView: No XP awarded to word "${card.word}" (Incorrect: $isCorrect) - daily attempts after: ${card.learningMastery.dailyAttemptsDebug}');
    }
    
    // Store the word mastery for display (for both correct and incorrect)
    _wordMastery[card.id] = card.learningMastery;
    
    // Track studied words (regardless of correctness)
    if (!_studiedWords.any((word) => word.id == card.id)) {
      _studiedWords.add(card);
    }
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
      _questionOptions.clear();
      _correctAnswerIndices.clear();
      _questionModes.clear();
      
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
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UnifiedEndScreen(
          xpGainedPerWord: sessionXpGainedPerWord,
          wordMastery: sessionWordMastery,
          studiedWords: sessionStudiedWords,
          title: 'Multiple Choice Complete',
          showSwipeToReview: false, // Disable review functionality
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close end screen
            // Reset and restart test
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
              
              // Reset RPG tracking
              _xpGainedPerWord.clear();
              _wordMastery.clear();
              _studiedWords.clear();
            });
            _generateQuestion();
            
            // Session data has been reset, ready for new game
          },
          onShuffle: widget.studyConfig != null ? () {
            Navigator.of(context).pop(); // Close end screen
            _shuffleAndRestart();
          } : null,
          onDone: () {
            Navigator.of(context).pop(); // Close end screen
            Navigator.of(context).pop(); // Go back to study type screen
          },
        ),
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
    final canUseHint = hintCount < 3; // Allow up to 3 hints
    
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
    
    setState(() {
      _hintCount[_currentIndex] = currentHintCount + 1;
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