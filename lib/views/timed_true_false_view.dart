import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import '../models/flash_card.dart';
import '../models/game_session.dart';
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

class TimedTrueFalseView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final TimedDifficulty difficulty;

  const TimedTrueFalseView({
    super.key,
    required this.cards,
    required this.title,
    required this.difficulty,
  });

  @override
  State<TimedTrueFalseView> createState() => _TimedTrueFalseViewState();
}

class _TimedTrueFalseViewState extends State<TimedTrueFalseView> {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  bool _showingResults = false;
  bool _answered = false;
  bool? _selectedAnswer;
  bool? _correctAnswer;
  String _question = '';
  String _currentTranslation = '';
  bool _isQuestionMode = true;
  final GameSession _gameSession = GameSession();
  
  // Timer variables
  Timer? _timer;
  int _timeRemaining = 0;
  int _totalTime = 0;
  bool _timeUp = false;
  
  // Track answered questions and their answers
  Map<int, bool> _answeredQuestions = {};
  Map<int, bool> _correctAnswersMap = {};
  Map<int, String> _questionTexts = {};
  Map<int, bool> _questionModes = {};
  Map<int, String> _translations = {};
  
  // Maintain our own copy of cards that can be updated
  late List<FlashCard> _currentCards;

  @override
  void initState() {
    super.initState();
    
    // Initialize our copy of cards
    _currentCards = List<FlashCard>.from(widget.cards);
    
    // Set timer based on difficulty
    switch (widget.difficulty) {
      case TimedDifficulty.easy:
        _timeRemaining = 10;
        _totalTime = 10;
        break;
      case TimedDifficulty.medium:
        _timeRemaining = 7;
        _totalTime = 7;
        break;
      case TimedDifficulty.hard:
        _timeRemaining = 5;
        _totalTime = 5;
        break;
    }
    
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
    // Remove listener when disposing
    final provider = context.read<FlashcardProvider>();
    provider.removeListener(_onProviderChanged);
    
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
    for (final originalCard in widget.cards) {
      final updatedCard = provider.getCard(originalCard.id);
      if (updatedCard != null) {
        updatedCards.add(updatedCard);
      } else {
        updatedCards.add(originalCard);
      }
    }
    
    setState(() {
      _currentCards = updatedCards;
    });
  }

  void _startTimer() {
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
    if (_answered) return; // Already answered
    
    setState(() {
      _answered = true;
      _timeUp = true;
      _correctAnswersMap[_currentIndex] = false; // Time out = incorrect
    });
    
    // Auto progress after showing the answer
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _goToNextQuestion();
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _timeRemaining = _totalTime;
    _timeUp = false;
    _startTimer();
  }

  void _generateQuestion() {
    if (_currentCards.isEmpty) return;
    
    final card = _currentCards[_currentIndex];
    final random = math.Random();
    
    // Randomly choose question mode
    _isQuestionMode = random.nextBool();
    
    if (_isQuestionMode) {
      // Word to definition
      _question = card.word;
      _currentTranslation = card.definition;
    } else {
      // Definition to word
      _question = card.definition;
      _currentTranslation = card.word;
    }
    
    // Randomly decide if the answer should be true or false
    _correctAnswer = random.nextBool();
    
    // Store question data
    _questionTexts[_currentIndex] = _question;
    _questionModes[_currentIndex] = _isQuestionMode;
    _translations[_currentIndex] = _currentTranslation;
    
    setState(() {
      _answered = false;
      _selectedAnswer = null;
    });
    
    _resetTimer();
  }

  void _selectAnswer(bool answer) {
    if (_answered) return;
    
    _timer?.cancel(); // Stop the timer
    
    setState(() {
      _answered = true;
      _selectedAnswer = answer;
      _totalAnswered++;
      
      final isCorrect = answer == _correctAnswer;
      if (isCorrect) {
        _correctAnswers++;
      }
      
      _correctAnswersMap[_currentIndex] = isCorrect;
      _answeredQuestions[_currentIndex] = answer;
    });
    
    // Provide feedback
    if (_selectedAnswer == _correctAnswer) {
      HapticService().lightImpact();
      SoundManager().playCorrectSound();
    } else {
      HapticService().mediumImpact();
      SoundManager().playWrongSound();
    }
    
    // Award XP
    if (_selectedAnswer == _correctAnswer) {
      _gameSession.recordAnswer(true);
    } else {
      _gameSession.recordAnswer(false);
    }
    
    // Auto progress after showing the answer
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        _goToNextQuestion();
      }
    });
  }

  void _goToNextQuestion() {
    if (_currentIndex < _currentCards.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _generateQuestion();
    } else {
      // Last question completed
      _awardXp();
      setState(() {
        _showingResults = true;
      });
      SoundManager().playCompleteSound();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showingResults) {
      return _buildResultsView();
    }
    
    if (_currentCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: const Center(
          child: Text('No cards available for testing.'),
        ),
      );
    }
    
    final card = _currentCards[_currentIndex];
    
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
                // Timer bar
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
                    'Does the following',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Card with theme-adaptive background and colored outline
                  Container(
                    width: double.infinity,
                    height: 200,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Theme.of(context).colorScheme.surface 
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getCardBorderColor(card),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getCardBorderColor(card).withValues(alpha: 0.3),
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
                        _question,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.onSurface 
                              : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
                          _currentTranslation,
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

  Widget _buildTimerBar() {
    final progress = _timeRemaining / _totalTime;
    Color timerColor = Colors.green;
    if (progress < 0.3) {
      timerColor = Colors.red;
    } else if (progress < 0.6) {
      timerColor = Colors.orange;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: timerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: timerColor),
            ),
            child: Text(
              '$_timeRemaining',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: timerColor,
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

  Color _getTrueButtonColor() {
    if (!_answered) {
      return Colors.blue.withValues(alpha: 0.1);
    }
    
    if (_selectedAnswer == true) {
      return _selectedAnswer == _correctAnswer ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2);
    }
    
    if (_correctAnswer == true) {
      return Colors.green.withValues(alpha: 0.2);
    }
    
    return Colors.grey.withValues(alpha: 0.1);
  }

  Color _getFalseButtonColor() {
    if (!_answered) {
      return Colors.orange.withValues(alpha: 0.1);
    }
    
    if (_selectedAnswer == false) {
      return _selectedAnswer == _correctAnswer ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2);
    }
    
    if (_correctAnswer == false) {
      return Colors.green.withValues(alpha: 0.2);
    }
    
    return Colors.grey.withValues(alpha: 0.1);
  }

  Color _getTrueButtonBorderColor() {
    if (!_answered) {
      return Colors.blue;
    }
    
    if (_selectedAnswer == true) {
      return _selectedAnswer == _correctAnswer ? Colors.green : Colors.red;
    }
    
    if (_correctAnswer == true) {
      return Colors.green;
    }
    
    return Colors.grey;
  }

  Color _getFalseButtonBorderColor() {
    if (!_answered) {
      return Colors.orange;
    }
    
    if (_selectedAnswer == false) {
      return _selectedAnswer == _correctAnswer ? Colors.green : Colors.red;
    }
    
    if (_correctAnswer == false) {
      return Colors.green;
    }
    
    return Colors.grey;
  }

  Widget _buildAnswerButton(bool isTrue) {
    return Container(
      width: double.infinity,
      height: 60,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _answered ? null : () => _selectAnswer(isTrue),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getButtonColor(isTrue),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getButtonBorderColor(isTrue),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getButtonBorderColor(isTrue).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      isTrue ? 'T' : 'F',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getButtonBorderColor(isTrue),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isTrue ? 'TRUE' : 'FALSE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getButtonBorderColor(isTrue),
                  ),
                ),
                const SizedBox(width: 12),
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

  Color _getButtonColor(bool isTrue) {
    if (!_answered) {
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
      return isTrue ? Colors.blue : Colors.orange;
    }
    
    if (isTrue == _correctAnswer) {
      return Colors.green;
    } else if (isTrue == _selectedAnswer && isTrue != _correctAnswer) {
      return Colors.red;
    }
    
    return Colors.grey;
  }

  Widget _buildAnswerFeedback() {
    final card = _currentCards[_currentIndex];
    final isCorrectAnswer = _selectedAnswer == _correctAnswer;
    
    // Determine color and message based on correctness
    Color textColor;
    String message;
    
    if (isCorrectAnswer && _selectedAnswer == false) {
      // User correctly answered FALSE - show green positive feedback
      textColor = Colors.green;
      message = 'Correct! The answer is: ${card.definition}';
    } else {
      // User answered incorrectly - show red feedback
      textColor = Colors.red;
      message = 'The correct answer is: ${card.definition}';
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
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
                              _questionTexts.clear();
                              _questionModes.clear();
                              _translations.clear();
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
                          onPressed: () => Navigator.of(context).pop(),
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

  void _awardXp() {
    if (_gameSession.xpGained > 0) {
      final userProfileProvider = context.read<UserProfileProvider>();
      XpService.awardSessionXp(userProfileProvider, _gameSession, isShuffleMode: false);
    }
    
    // Update session statistics
    final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered) : 0.0;
    final isPerfect = _correctAnswers == _totalAnswered && _totalAnswered > 0;
    
    print('🔍 TimedTrueFalseView: Test completed - Accuracy: ${(accuracy * 100).toInt()}%, Perfect: $isPerfect');
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
}
