import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
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
import '../models/timed_difficulty.dart';
import '../utils/game_difficulty_helper.dart';
import 'add_card_view.dart';

class TimedMultipleChoiceView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final Function(bool)? onComplete;
  final TimedDifficulty difficulty;
  final bool startFlipped;

  const TimedMultipleChoiceView({
    super.key,
    required this.cards,
    required this.title,
    this.onComplete,
    required this.difficulty,
    this.startFlipped = false,
  });

  @override
  State<TimedMultipleChoiceView> createState() => _TimedMultipleChoiceViewState();
}

class _TimedMultipleChoiceViewState extends State<TimedMultipleChoiceView> {
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
  
  // Timer variables
  Timer? _timer;
  int _timeRemaining = 0;
  int _totalTime = 0;
  bool _timeUp = false;
  
  // Track answered questions and their answers
  Map<int, int> _answeredQuestions = {}; // question index -> selected answer index
  Map<int, bool> _correctAnswersMap = {}; // question index -> is correct
  Map<int, List<String>> _questionOptions = {}; // question index -> options
  Map<int, int> _correctAnswerIndices = {}; // question index -> correct answer index
  Map<int, bool> _questionModes = {}; // question index -> is question mode
  
  // Maintain our own copy of cards that can be updated
  late List<FlashCard> _currentCards;
  
  // Flag to track if view is disposed
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize our copy of cards
    _currentCards = List<FlashCard>.from(widget.cards);
    
    // Set time based on difficulty
    switch (widget.difficulty) {
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
    
    _generateQuestion();
    _startTimer();
    
    // Listen for card updates from the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FlashcardProvider>();
      provider.addListener(_onProviderChanged);
    });
  }

  @override
  void dispose() {
    // Mark as disposed
    _isDisposed = true;
    
    // Remove listener when disposing
    final provider = context.read<FlashcardProvider>();
    provider.removeListener(_onProviderChanged);
    
    // Cancel timer
    _timer?.cancel();
    
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeRemaining > 0) {
            _timeRemaining--;
          }
        });
        
        if (_timeRemaining <= 0) {
          _timeUp = true;
          timer.cancel();
          _handleTimeUp();
        }
      }
    });
  }

  void _handleTimeUp() {
    if (!_answered) {
      // Show correct answer and auto-progress
      setState(() {
        _answered = true;
        _totalAnswered++;
        _correctAnswersMap[_currentIndex] = false; // Wrong answer due to time up
      });
      
      // Auto progress after showing the answer
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted && !_isDisposed) {
          if (_currentIndex < _currentCards.length - 1) {
            _goToNextQuestion();
          } else {
            // Last question - go to results
            _awardXp();
            setState(() {
              _showingResults = true;
            });
            if (!_isDisposed) {
              SoundManager().playCompleteSound();
            }
          }
        }
      });
    }
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
    
    setState(() {
      _currentCards = updatedCards;
    });
    
    print('🔍 TimedMultipleChoiceView: Refreshed cards from provider');
  }

  void _generateQuestion() {
    // Check if this question has already been answered
    if (_answeredQuestions.containsKey(_currentIndex)) {
      // Load existing question data
      _isQuestionMode = _questionModes[_currentIndex]!;
      _options = List<String>.from(_questionOptions[_currentIndex]!);
      _correctAnswerIndex = _correctAnswerIndices[_currentIndex]!;
      _selectedAnswer = _answeredQuestions[_currentIndex]!;
      _answered = true;
      return;
    }

    final currentCard = _currentCards[_currentIndex];
    final random = math.Random();
    
    // Respect the startFlipped parameter to determine question orientation
    _isQuestionMode = !widget.startFlipped; // true = word to definition, false = definition to word
    
    // Get correct answer based on orientation
    String correctAnswer;
    if (_isQuestionMode) {
      // Show word, ask for definition
      correctAnswer = currentCard.definition;
    } else {
      // Show definition, ask for word
      correctAnswer = currentCard.word;
    }
    
    // Generate options
    _options = _generateOptions(currentCard, correctAnswer, random);
    _correctAnswerIndex = _options.indexOf(correctAnswer);
    
    // Store question data for future reference
    _questionOptions[_currentIndex] = List<String>.from(_options);
    _correctAnswerIndices[_currentIndex] = _correctAnswerIndex!;
    _questionModes[_currentIndex] = _isQuestionMode;
    
    setState(() {
      _answered = false;
      _selectedAnswer = null;
      _timeUp = false;
    });
  }

  List<String> _generateOptions(FlashCard currentCard, String correctAnswer, math.Random random) {
    List<String> options = [correctAnswer];
    
    // Get other cards for wrong options
    List<FlashCard> otherCards = _currentCards.where((card) => card.id != currentCard.id).toList();
    
    // Shuffle other cards and take up to 3 for wrong options
    otherCards.shuffle();
    for (int i = 0; i < math.min(3, otherCards.length); i++) {
      String wrongOption;
      if (_isQuestionMode) {
        wrongOption = otherCards[i].definition;
      } else {
        wrongOption = otherCards[i].word;
      }
      
      if (!options.contains(wrongOption)) {
        options.add(wrongOption);
      }
    }
    
    // If we don't have enough options, add some generic ones
    while (options.length < 4) {
      String genericOption;
      if (_isQuestionMode) {
        genericOption = "Option ${options.length}";
      } else {
        genericOption = "word${options.length}";
      }
      options.add(genericOption);
    }
    
    // Shuffle options
    options.shuffle();
    return options;
  }

  void _selectAnswer(int index) {
    if (_answered || _timeUp) return;
    
    final isCorrect = index == _correctAnswerIndex;
    final currentCard = _currentCards[_currentIndex];
    
    // Stop the timer
    _timer?.cancel();
    
    // Track XP for this answer
    XpService.recordAnswer(_gameSession, isCorrect);
    
    // Update learning progress in the provider
    _updateCardLearningProgress(currentCard, isCorrect);
    
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
      }
    });
    
    // Auto progress after a short delay
    Timer(const Duration(milliseconds: 800), () {
      if (mounted && !_isDisposed) {
        if (_currentIndex < _currentCards.length - 1) {
          _goToNextQuestion();
        } else {
          // Last question - go to results
          _awardXp();
          setState(() {
            _showingResults = true;
          });
          if (!_isDisposed) {
            SoundManager().playCompleteSound();
          }
        }
      }
    });
  }

  Future<void> _updateCardLearningProgress(FlashCard card, bool wasCorrect) async {
    try {
      final provider = context.read<FlashcardProvider>();
      
      // Get game difficulty for timed multiple choice (expert)
      final difficulty = GameDifficultyHelper.getDifficultyForGameMode('timed test');
      
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
      print('🔍 TimedMultipleChoiceView: Updated learning progress for "${card.word}" - wasCorrect: $wasCorrect, difficulty: ${difficulty.name}, new percentage: ${updatedCard.learningPercentage}%');
      
      // Also sync to Dutch words if this card exists there
      await _syncToDutchWords(card, wasCorrect);
      
    } catch (e) {
      print('🔍 TimedMultipleChoiceView: Error updating learning progress: $e');
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
        print('🔍 TimedMultipleChoiceView: Synced progress to Dutch word exercise "${wordExercise.targetWord}"');
      }
    } catch (e) {
      print('🔍 TimedMultipleChoiceView: Error syncing to Dutch words: $e');
    }
  }

  void _goToPreviousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _generateQuestion();
      _resetTimer();
    }
  }

  void _goToNextQuestion() {
    if (_currentIndex < _currentCards.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _generateQuestion();
      _resetTimer();
    } else {
      // Award XP for the session
      _awardXp();
      // Show results when on last question and clicking next
      setState(() {
        _showingResults = true;
      });
      // Play completion sound when test is finished
      if (!_isDisposed) {
        SoundManager().playCompleteSound();
      }
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _timeRemaining = _totalTime;
      _timeUp = false;
    });
    _startTimer();
  }

  void _awardXp() {
    if (_gameSession.xpGained > 0) {
      final userProfileProvider = context.read<UserProfileProvider>();
      XpService.awardSessionXp(userProfileProvider, _gameSession, isShuffleMode: false);
    }
    
    // Update session statistics
    final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered) : 0.0;
    final isPerfect = _correctAnswers == _totalAnswered && _totalAnswered > 0;
    
    print('🔍 TimedMultipleChoiceView: Test completed - Accuracy: ${(accuracy * 100).toInt()}%, Perfect: $isPerfect');
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

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Timed Test?'),
        content: const Text('Are you sure you want to leave? Your progress will be lost.'),
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
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showHomeConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go Home?'),
        content: const Text('Are you sure you want to go home? Your progress will be lost.'),
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

  Widget _buildProgressBar() {
    return Container(
      width: double.infinity,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: LinearProgressIndicator(
        value: (_currentIndex + 1) / _currentCards.length,
        backgroundColor: Colors.grey.withValues(alpha: 0.3),
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
    );
  }

  Widget _buildTimerBar() {
    final progress = _timeRemaining / _totalTime;
    Color timerColor;
    
    if (progress > 0.6) {
      timerColor = Colors.green;
    } else if (progress > 0.3) {
      timerColor = Colors.orange;
    } else {
      timerColor = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: timerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: timerColor),
            ),
            child: Text(
              '$_timeRemaining',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: timerColor,
              ),
            ),
          ),
        ],
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
                  const SizedBox(width: 48), // Balance the layout
                ],
              ),
            ),
          ),
          
          // Results content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  const SizedBox(height: 48),
                  
                  // Action buttons
                  Row(
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
                              _questionOptions.clear();
                              _correctAnswerIndices.clear();
                              _questionModes.clear();
                            });
                            _generateQuestion();
                            _resetTimer();
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
                ],
              ),
            ),
          ),
        ],
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
          // Small header with progress bar and timer
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
                // Simple timer in center
                _buildTimerBar(),
              ],
            ),
          ),
          
          // Question area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                  
                  const SizedBox(height: 32),
                  
                  // Options
                  Expanded(
                    child: Column(
                      children: _options.asMap().entries.map((entry) {
                        final index = entry.key;
                        final option = entry.value;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: _answered ? null : () => _selectAnswer(index),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _getOptionColor(index),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getOptionBorderColor(index),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _getOptionBorderColor(index),
                                    ),
                                    child: Center(
                                      child: Text(
                                        String.fromCharCode(65 + index), // A, B, C, D
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: _getOptionTextColor(index),
                                      ),
                                    ),
                                  ),
                                  if (_answered && index == _correctAnswerIndex)
                                    const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                  if (_answered && index == _selectedAnswer && index != _correctAnswerIndex)
                                    const Icon(Icons.cancel, color: Colors.red, size: 24),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  // No navigation buttons - auto progress only
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

  Color _getOptionTextColor(int index) {
    if (!_answered) return Theme.of(context).colorScheme.onSurface;
    
    if (index == _correctAnswerIndex) {
      return Colors.green[700]!;
    } else if (index == _selectedAnswer && index != _correctAnswerIndex) {
      return Colors.red[700]!;
    }
    
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
  }

  Color _getCardBorderColor(FlashCard card) {
    final percentage = card.learningPercentage;
    if (percentage >= 80) {
      return Colors.green;
    } else if (percentage >= 60) {
      return Colors.orange;
    } else if (percentage >= 40) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
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
}
