import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:async';
import '../models/flash_card.dart';
import '../models/game_session.dart';
import '../models/learning_mastery.dart';
import '../services/sound_manager.dart';
import '../services/xp_service.dart';
import '../services/haptic_service.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/dutch_word_exercise.dart';
import '../components/xp_progress_widget.dart';
import '../components/animated_xp_counter.dart';
import '../components/word_progress_display.dart';
import '../utils/game_difficulty_helper.dart';
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
  final bool useMixedMode;

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
    this.useMixedMode = false,
  });

  @override
  State<TrueFalseView> createState() => _TrueFalseViewState();
}

class _TrueFalseViewState extends State<TrueFalseView> {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  bool _showingResults = false;
  bool _answered = false;
  bool? _selectedAnswer;
  bool? _correctAnswer;
  String _question = '';
  String _currentTranslation = ''; // Store the translation being tested
  bool _isQuestionMode = true; // true = word to definition, false = definition to word
  final GameSession _gameSession = GameSession();
  
  // Track answered questions and their answers
  Map<int, bool> _answeredQuestions = {}; // question index -> selected answer
  Map<int, bool> _correctAnswersMap = {}; // question index -> is correct
  Map<int, String> _questionTexts = {}; // question index -> question text
  Map<int, bool> _questionModes = {}; // question index -> is question mode
  Map<int, String> _translations = {}; // question index -> translation being tested
  
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
  List<FlashCard> _studiedWords = [];

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
    if (widget.useMixedMode) {
      _isQuestionMode = Random().nextBool(); // Randomly choose question mode
    } else {
      _isQuestionMode = !widget.startFlipped; // Use flipped mode setting
    }
    
    // Get correct answer based on question mode
    final correctAnswer = _isQuestionMode ? currentCard.definition : currentCard.word;
    
    // Get other cards for wrong options
    final otherCards = widget.cards.where((card) => card.id != currentCard.id).toList();
    
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
      final isCorrect = _selectedAnswer == _correctAnswer;
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
    
    // Update learning progress in the provider
    _updateCardLearningProgress(currentCard, isCorrect);
    
    // Award XP to word for RPG system
    _awardXPToWord(currentCard, isCorrect);
    
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      _totalAnswered++;
      
      // Store the answer
      _answeredQuestions[_currentIndex] = answer;
      
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
    
    // Auto progress logic
    if (widget.autoProgress) {
      _autoProgressTimer?.cancel();
      _autoProgressTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted && _currentIndex < _currentCards.length - 1) {
          _goToNextQuestion();
        }
      });
    }
  }

  Future<void> _updateCardLearningProgress(FlashCard card, bool wasCorrect) async {
    try {
      final provider = context.read<FlashcardProvider>();
      
      // Get game difficulty for true/false
      final difficulty = GameDifficultyHelper.getDifficultyForGameMode('true false');
      
      // Create updated card with new learning mastery
      final updatedCard = card.copyWith(
        learningMastery: card.learningMastery.copyWith(),
      );
      
      // Update learning mastery based on difficulty
      if (wasCorrect) {
        updatedCard.markCorrect(difficulty);
      } else {
        updatedCard.markIncorrect(difficulty);
      }
      
      await provider.updateCard(updatedCard);
      print('🔍 TrueFalseView: Updated learning progress for "${card.word}" - wasCorrect: $wasCorrect, difficulty: ${difficulty.name}, new percentage: ${updatedCard.learningPercentage}%');
      
      // Also sync to Dutch words if this card exists there
      await _syncToDutchWords(card, wasCorrect);
      
    } catch (e) {
      print('🔍 TrueFalseView: Error updating learning progress: $e');
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
      return _buildResultsView();
    }

    final currentCard = _currentCards[_currentIndex];

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
                // Lives display (if using lives mode)
                if (_useLivesMode) 
                  _buildLivesDisplay(),
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
                    'Does the following',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16), // Reduced spacing
                  
                  // Card with theme-adaptive background and colored outline
                  Container(
                    width: double.infinity,
                    height: 200, // Reduced height
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
                        _isQuestionMode ? currentCard.word : currentCard.definition,
                        style: TextStyle(
                          fontSize: 32, // Smaller font size
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.onSurface 
                              : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16), // Reduced spacing
                  
                  // Navigation and Edit buttons row
                  Row(
                    children: [
                      // Back button (always show, greyed out when not available)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _currentIndex > 0 ? _goToPreviousQuestion : null,
                          icon: const Icon(Icons.arrow_back, size: 16),
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
                          onPressed: _answered ? _goToNextQuestion : null,
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text(_currentIndex == widget.cards.length - 1 ? 'Finish' : 'Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _answered ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20), // Reduced spacing
                  
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
                  
                  // True/False buttons side by side
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${_currentIndex + 1} of ${widget.cards.length}'),
              Text('${(progress * 100).toInt()}%'),
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
    
    if (isCorrectAnswer && _selectedAnswer == false) {
      // User correctly answered FALSE - show green positive feedback
      textColor = Colors.green;
      message = 'Correct! The answer is: ${currentCard.definition}';
    } else {
      // User answered incorrectly - show red feedback
      textColor = Colors.red;
      message = 'The correct answer is: ${currentCard.definition}';
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
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right to show word progress
          if (details.primaryVelocity! < 0 && _xpGainedPerWord.values.isNotEmpty) {
            _showWordProgress();
          }
        },
        child: Column(
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
                    const SizedBox(width: 48), // Balance the layout
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
                      AnimatedXpCounter(xpGained: _gameSession.xpGained)),
                    
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
                          // Reset all navigation state
                          _answeredQuestions.clear();
                          _correctAnswersMap.clear();
                          _questionTexts.clear();
                          _questionModes.clear();
                          _translations.clear();
                          
                          // Reset RPG tracking
                          _xpGainedPerWord.clear();
                          _wordMastery.clear();
                          _studiedWords.clear();
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
    print('🔍 TrueFalse: _awardXp called - shuffleMode: ${widget.shuffleMode}, xpGained: ${_gameSession.xpGained}');
    if (!widget.shuffleMode && _gameSession.xpGained > 0) {
      print('🔍 TrueFalse: Calling XpService.awardSessionXp');
      final userProfileProvider = context.read<UserProfileProvider>();
      XpService.awardSessionXp(userProfileProvider, _gameSession, isShuffleMode: widget.shuffleMode);
    } else {
      print('🔍 TrueFalse: Skipping XP award - shuffleMode: ${widget.shuffleMode}, xpGained: ${_gameSession.xpGained}');
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
    // Only award XP for correct answers
    if (isCorrect) {
      final xpService = XpService();
      final xpGained = xpService.calculateWordXP("true_false", 1);
      
      // Add XP to the word's learning mastery
      xpService.addXPToWord(card.learningMastery, "true_false", 1);
      
      // Track XP gained for this word in this session
      _xpGainedPerWord[card.id] = (_xpGainedPerWord[card.id] ?? 0) + xpGained;
      
      // Store the word mastery for display
      _wordMastery[card.id] = card.learningMastery;
      
      print('🔍 TrueFalseView: Awarded $xpGained XP to word "${card.word}" (Correct: $isCorrect)');
    } else {
      print('🔍 TrueFalseView: No XP awarded to word "${card.word}" (Incorrect: $isCorrect)');
    }
    
    // Track studied words (regardless of correctness)
    if (!_studiedWords.any((word) => word.id == card.id)) {
      _studiedWords.add(card);
    }
  }
  
  void _showWordProgress() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordProgressDisplay(
          xpGainedPerWord: _xpGainedPerWord,
          wordMastery: _wordMastery,
          studiedWords: _studiedWords,
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close word progress screen
            // Reset and restart test
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
              _questionTexts.clear();
              _questionModes.clear();
              _translations.clear();
              
              // Reset RPG tracking
              _xpGainedPerWord.clear();
              _wordMastery.clear();
              _studiedWords.clear();
            });
            _generateQuestion();
          },
          onDone: () {
            Navigator.of(context).pop(); // Close word progress screen
            Navigator.of(context).popUntil((route) => route.isFirst); // Go to home
          },
        ),
      ),
    );
  }
} 