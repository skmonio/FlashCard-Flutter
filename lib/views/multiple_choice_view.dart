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

class MultipleChoiceView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final Function(bool)? onComplete;
  final bool shuffleMode;
  final bool autoProgress;
  final bool useLivesMode;
  final int? customLives;
  final bool startFlipped;
  final bool useMixedMode;

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
    this.useMixedMode = false,
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
  
  // Maintain our own copy of cards that can be updated
  late List<FlashCard> _currentCards;
  
  // Auto progress timer
  Timer? _autoProgressTimer;
  
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
      _options = _questionOptions[_currentIndex]!;
      _correctAnswerIndex = _correctAnswerIndices[_currentIndex]!;
      _selectedAnswer = _answeredQuestions[_currentIndex]!;
      _answered = true;
      return;
    }

    final currentCard = _currentCards[_currentIndex];
    final random = Random();
    
    // Choose question mode based on flipped mode settings
    if (widget.useMixedMode) {
      _isQuestionMode = random.nextBool(); // Randomly choose question mode
    } else {
      _isQuestionMode = !widget.startFlipped; // Use flipped mode setting
    }
    
    // Get correct answer
    final correctAnswer = _isQuestionMode ? currentCard.definition : currentCard.word;
    
    // Get other cards for wrong options
    final otherCards = _currentCards.where((card) => card.id != currentCard.id).toList();
    final wrongOptions = <String>[];
    
        // Get 3 wrong options from other cards
    final shuffledOtherCards = List.from(otherCards)..shuffle(random);
    
    for (final card in shuffledOtherCards) {
      if (wrongOptions.length >= 3) break;
      
      final wrongOption = _isQuestionMode ? card.definition : card.word;
      if (!wrongOptions.contains(wrongOption) && wrongOption != correctAnswer) {
        wrongOptions.add(wrongOption);
      }
    }
    
    // If we still don't have enough wrong options from cards, generate more cards
    if (wrongOptions.length < 3) {
      // Get all available cards and try again with more variety
      final allCards = context.read<FlashcardProvider>().cards;
      final moreCards = allCards.where((card) => 
        card.id != currentCard.id && 
        !otherCards.any((oc) => oc.id == card.id)
      ).toList();
      
      for (final card in moreCards) {
        if (wrongOptions.length >= 3) break;
        
        final wrongOption = _isQuestionMode ? card.definition : card.word;
        if (!wrongOptions.contains(wrongOption) && wrongOption != correctAnswer) {
          wrongOptions.add(wrongOption);
        }
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
    
    // Create options list with correct answer
    _options = [...wrongOptions, correctAnswer];
    _options.shuffle(random);
    
    // Find correct answer index
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
    
    // Award XP to word for RPG system
    _awardXPToWord(currentCard, isCorrect);
    
    // Update the card in the provider to save the XP changes
    _updateCardInProvider(currentCard);
    
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
    
    // Auto progress logic (only if not game over)
    if (widget.autoProgress && !(_useLivesMode && _lives <= 0)) {
      _autoProgressTimer?.cancel();
      _autoProgressTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted && _currentIndex < _currentCards.length - 1) {
          _goToNextQuestion();
        }
      });
    }
  }
  
  /// Show game over screen when all lives are lost
  void _showGameOverScreen() {
    setState(() {
      _showingResults = true;
    });
    
    // Play game over sound
    SoundManager().playWrongSound();
    
    // Call onComplete with false (unsuccessful)
    if (widget.onComplete != null) {
      widget.onComplete!(false);
    }
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

  void _goToNextQuestion() {
    // In shuffle mode, we only have one question, so call the callback immediately
    if (widget.shuffleMode) {
      final isCorrect = _selectedAnswer == _correctAnswerIndex;
      if (widget.onComplete != null) {
        widget.onComplete!(isCorrect);
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
                    'Choose the correct definition',
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
                        question,
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
                          label: Text(_currentIndex == _currentCards.length - 1 ? 'Finish' : 'Next'),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${_currentIndex + 1} of ${_currentCards.length}'),
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
    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectAnswer(index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12), // Reduced padding
            decoration: BoxDecoration(
              color: _getOptionColor(index),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getOptionBorderColor(index),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28, // Smaller circle
                  height: 28, // Smaller circle
                  decoration: BoxDecoration(
                    color: _getOptionBorderColor(index).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
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
                    style: const TextStyle(
                      fontSize: 14, // Smaller font
                      fontWeight: FontWeight.w500,
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
    // Only award XP for correct answers
    if (isCorrect) {
      final xpService = XpService();
      
      print('🔍 MultipleChoiceView: About to award XP to word "${card.word}" - daily attempts before: ${card.learningMastery.dailyAttemptsDebug}');
      
      // Add XP to the word's learning mastery (this handles daily diminishing returns)
      xpService.addXPToWord(card.learningMastery, "test", 1);
      
      // Get the actual XP gained (after diminishing returns)
      final actualXPGained = card.learningMastery.exerciseHistory.isNotEmpty 
          ? card.learningMastery.exerciseHistory.last['xpGained'] as int 
          : 0;
      
      // Track XP gained for this word in this session (add for multiple appearances in same session)
      _xpGainedPerWord[card.id] = actualXPGained;
      
      // Store the word mastery for display
      _wordMastery[card.id] = card.learningMastery;
      
      print('🔍 MultipleChoiceView: Awarded $actualXPGained XP to word "${card.word}" (Correct: $isCorrect) - daily attempts after: ${card.learningMastery.dailyAttemptsDebug}');
    } else {
      print('🔍 MultipleChoiceView: No XP awarded to word "${card.word}" (Incorrect: $isCorrect)');
    }
    
    // Track studied words (regardless of correctness)
    if (!_studiedWords.any((word) => word.id == card.id)) {
      _studiedWords.add(card);
    }
  }
  
  void _showWordProgress() {
    // Create copies of the current session data for the display
    final sessionStudiedWords = List<FlashCard>.from(_studiedWords);
    final sessionXpGainedPerWord = Map<String, int>.from(_xpGainedPerWord);
    final sessionWordMastery = Map<String, LearningMastery>.from(_wordMastery);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordProgressDisplay(
          xpGainedPerWord: sessionXpGainedPerWord,
          wordMastery: sessionWordMastery,
          studiedWords: sessionStudiedWords,
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
          onDone: () {
            Navigator.of(context).pop(); // Close word progress screen
            Navigator.of(context).popUntil((route) => route.isFirst); // Go to home
          },
        ),
      ),
    );
  }
  

} 