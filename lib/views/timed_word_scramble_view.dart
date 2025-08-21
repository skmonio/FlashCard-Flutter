import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import '../models/flash_card.dart';
import '../models/game_session.dart';
import '../components/unified_header.dart';
import '../components/xp_progress_widget.dart';
import '../components/animated_xp_counter.dart';
import '../services/sound_manager.dart';
import '../services/xp_service.dart';
import '../services/haptic_service.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/dutch_word_exercise.dart';
import '../models/timed_difficulty.dart';

class TimedWordScrambleView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final TimedDifficulty difficulty;

  const TimedWordScrambleView({
    super.key,
    required this.cards,
    required this.title,
    required this.difficulty,
  });

  @override
  State<TimedWordScrambleView> createState() => _TimedWordScrambleViewState();
}

class _TimedWordScrambleViewState extends State<TimedWordScrambleView> {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  bool _showingResults = false;
  bool _answered = false;
  String _correctWord = '';
  List<String> _scrambledLetters = [];
  List<String> _userAnswer = [];
  List<String> _originalLetters = [];
  bool _isQuestionMode = true;
  bool _isCardFlipped = false;
  final GameSession _gameSession = GameSession();
  
  // Timer variables
  Timer? _timer;
  int _timeRemaining = 0;
  int _totalTime = 0;
  bool _timeUp = false;
  
  // Track answered questions and their answers
  Map<int, List<String>> _answeredQuestions = {};
  Map<int, bool> _correctAnswersMap = {};
  Map<int, String> _correctWords = {};
  Map<int, List<String>> _scrambledLettersMap = {};
  Map<int, bool> _questionModes = {};
  
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
      // Definition to word
      _correctWord = card.word;
    } else {
      // Word to definition
      _correctWord = card.definition;
    }
    
    // Store question data
    _correctWords[_currentIndex] = _correctWord;
    _questionModes[_currentIndex] = _isQuestionMode;
    
    // Create scrambled pieces using the same logic as original word scramble
    _scrambledLetters = _createPiecesFromWords(_correctWord, random);
    _scrambledLettersMap[_currentIndex] = List<String>.from(_scrambledLetters);
    
    setState(() {
      _userAnswer = [];
      _answered = false;
    });
    
    _resetTimer();
  }

  List<String> _createPiecesFromWords(String phrase, math.Random random) {
    final pieces = <String>[];
    
    // Split the phrase into words
    final words = phrase.split(' ');
    
    for (final word in words) {
      if (word.isEmpty) continue;
      
      final letters = word.split('');
      final wordPieces = _createPieces(letters, random);
      pieces.addAll(wordPieces);
    }
    
    // Shuffle all pieces together
    pieces.shuffle(random);
    return pieces;
  }
  
  List<String> _createPieces(List<String> letters, math.Random random) {
    final pieces = <String>[];
    
    // Ensure we always have at least 2 pieces for any word
    if (letters.length <= 3) {
      // For short words (3 letters or less), split into 2 pieces
      if (letters.length == 3) {
        // "dog" -> ["do", "g"] or ["d", "og"]
        if (random.nextBool()) {
          pieces.add(letters.sublist(0, 2).join('')); // "do"
          pieces.add(letters[2]); // "g"
        } else {
          pieces.add(letters[0]); // "d"
          pieces.add(letters.sublist(1, 3).join('')); // "og"
        }
      } else if (letters.length == 2) {
        // "hi" -> ["h", "i"]
        pieces.add(letters[0]);
        pieces.add(letters[1]);
      } else if (letters.length == 1) {
        // Single letter, create two pieces with one empty (edge case)
        pieces.add(letters[0]);
        pieces.add('');
      }
    } else {
      // For longer words (4+ letters), ensure at least 2 pieces
      if (letters.length == 4) {
        // "hond" -> ["ho", "nd"] or ["hon", "d"] or ["h", "ond"]
        final options = [
          [letters.sublist(0, 2).join(''), letters.sublist(2, 4).join('')], // "ho", "nd"
          [letters.sublist(0, 3).join(''), letters[3]], // "hon", "d"
          [letters[0], letters.sublist(1, 4).join('')], // "h", "ond"
        ];
        pieces.addAll(options[random.nextInt(options.length)]);
      } else {
        // For 5+ letters, create pieces of 2-3 letters but ensure at least 2 pieces
        int index = 0;
        while (index < letters.length) {
          // Determine piece size (2-3 letters)
          int pieceSize;
          if (index + 3 <= letters.length) {
            // Can make a piece of 2 or 3 letters
            pieceSize = random.nextBool() ? 2 : 3;
          } else if (index + 2 <= letters.length) {
            // Can make a piece of 2 letters
            pieceSize = 2;
          } else {
            // Only 1 letter left, add it to the last piece
            if (pieces.isNotEmpty) {
              pieces[pieces.length - 1] += letters[index];
            } else {
              // This shouldn't happen with the minimum 2 pieces rule
              pieces.add(letters[index]);
            }
            break;
          }
          
          // Create the piece
          final piece = letters.sublist(index, index + pieceSize).join('');
          pieces.add(piece);
          index += pieceSize;
        }
      }
    }
    
    return pieces;
  }

  void _addLetter(String letter) {
    if (_answered) return;
    
    setState(() {
      _userAnswer.add(letter);
      _scrambledLetters.remove(letter);
    });
    
    // Auto-progress when all pieces are added (in timed mode)
    if (_userAnswer.length == _scrambledLettersMap[_currentIndex]!.length) {
      // All pieces have been added, auto-check answer
      Timer(const Duration(milliseconds: 500), () {
        if (mounted && !_answered) {
          _checkAnswer();
        }
      });
    }
  }

  void _removeLetter(String letter) {
    if (_answered) return;
    
    setState(() {
      _userAnswer.remove(letter);
      _scrambledLetters.add(letter);
    });
  }

  void _checkAnswer() {
    if (_answered) return;
    
    _timer?.cancel(); // Stop the timer
    
    final userAnswerString = _userAnswer.join('');
    final isCorrect = userAnswerString.toLowerCase() == _correctWord.toLowerCase();
    
    setState(() {
      _answered = true;
      _totalAnswered++;
      
      if (isCorrect) {
        _correctAnswers++;
      }
      
      _correctAnswersMap[_currentIndex] = isCorrect;
      _answeredQuestions[_currentIndex] = List<String>.from(_userAnswer);
    });
    
    // Provide feedback
    if (isCorrect) {
      HapticService().lightImpact();
      SoundManager().playCorrectSound();
    } else {
      HapticService().mediumImpact();
      SoundManager().playWrongSound();
    }
    
    // Award XP
    if (isCorrect) {
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

  void _goToPreviousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _generateQuestion();
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
                    'Arrange the pieces to translate:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Card with white background and colored outline
                  Container(
                    width: double.infinity,
                    height: 200,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _isQuestionMode ? card.definition : card.word,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Answer box
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
                        // User answer display
                        SizedBox(
                          height: 80,
                          child: _userAnswer.isEmpty
                              ? Center(
                                  child: Text(
                                    'Tap pieces to build the word',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : _buildUserAnswerDisplay(),
                        ),
                        // Show correct answer if user answered incorrectly
                        if (_answered && _userAnswer.join('').toLowerCase() != _correctWord.replaceAll(' ', '').toLowerCase()) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'The correct answer is: $_correctWord',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Scrambled letters (only show if question is not answered)
                  if (!_answered)
                    _buildScrambledLetters(),
                  
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAnswerDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_userAnswer.isEmpty)
          Text(
            'Tap pieces to build your answer',
            style: TextStyle(
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ..._userAnswer.asMap().entries.map((entry) {
            final index = entry.key;
            final piece = entry.value;
            
            return GestureDetector(
              onTap: _answered ? null : () => _removeLetterAt(index),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: piece.length > 2 ? 50 : 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _answered 
                      ? (_userAnswer.join('').toLowerCase() == _correctWord.replaceAll(' ', '').toLowerCase() 
                          ? Colors.green.withValues(alpha: 0.2) 
                          : Colors.red.withValues(alpha: 0.2))
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: _answered 
                        ? (_userAnswer.join('').toLowerCase() == _correctWord.replaceAll(' ', '').toLowerCase() 
                            ? Colors.green 
                            : Colors.red)
                        : Theme.of(context).colorScheme.primary,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    piece,
                    style: TextStyle(
                      fontSize: piece.length > 2 ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: _answered 
                          ? (_userAnswer.join('').toLowerCase() == _correctWord.replaceAll(' ', '').toLowerCase() 
                              ? Colors.green 
                              : Colors.red)
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  void _removeLetterAt(int index) {
    if (_answered) return;
    
    setState(() {
      final removedLetter = _userAnswer[index];
      _userAnswer.removeAt(index);
      _scrambledLetters.add(removedLetter);
    });
  }

  Widget _buildScrambledLetters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _scrambledLetters.asMap().entries.map((entry) {
        final index = entry.key;
        final piece = entry.value;
        final isUsed = _isPieceUsed(piece, index);
        
        return GestureDetector(
          onTap: _answered || isUsed || piece.isEmpty ? null : () => _addLetter(piece),
          child: Container(
            width: piece.length > 2 ? 70 : 60,
            height: 50,
            decoration: BoxDecoration(
              color: isUsed || piece.isEmpty
                  ? Colors.grey.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: isUsed || piece.isEmpty
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                piece,
                style: TextStyle(
                  fontSize: piece.length > 2 ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: isUsed || piece.isEmpty
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _isPieceUsed(String piece, int index) {
    // Check if this piece has been used in the user answer
    final usedPieces = <String>[];
    for (int i = 0; i < _scrambledLetters.length; i++) {
      if (i != index) {
        usedPieces.add(_scrambledLetters[i]);
      }
    }
    
    // If the piece is not in the remaining scrambled letters, it's been used
    return !_scrambledLetters.contains(piece) || _userAnswer.contains(piece);
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
                              _userAnswer = [];
                              _gameSession.reset(); // Reset XP tracking
                              // Reset all navigation state
                              _answeredQuestions.clear();
                              _correctAnswersMap.clear();
                              _correctWords.clear();
                              _scrambledLettersMap.clear();
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
    
    print('🔍 TimedWordScrambleView: Test completed - Accuracy: ${(accuracy * 100).toInt()}%, Perfect: $isPerfect');
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
