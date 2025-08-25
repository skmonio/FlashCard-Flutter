import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:async';
import '../models/flash_card.dart';
import '../models/game_session.dart';
import '../models/learning_mastery.dart';
import '../components/unified_header.dart';
import '../components/xp_progress_widget.dart';
import '../components/animated_xp_counter.dart';
import '../services/sound_manager.dart';
import '../services/xp_service.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/dutch_word_exercise.dart';
import '../utils/game_difficulty_helper.dart';
import '../components/word_progress_display.dart';

class WordScrambleView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final Function(bool)? onComplete;
  final bool shuffleMode;
  final bool startFlipped;
  final bool autoProgress;
  final bool useLivesMode;
  final int? customLives;

  const WordScrambleView({
    super.key,
    required this.cards,
    required this.title,
    this.onComplete,
    this.shuffleMode = false,
    this.startFlipped = false,
    this.autoProgress = false,
    this.useLivesMode = false,
    this.customLives,
  });

  @override
  State<WordScrambleView> createState() => _WordScrambleViewState();
}

class _WordScrambleViewState extends State<WordScrambleView> {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  bool _showingResults = false;
  bool _answered = false;
  String _correctWord = '';
  List<String> _scrambledLetters = [];
  List<String> _userAnswer = [];
  List<String> _originalLetters = [];
  bool _isQuestionMode = true; // true = definition to word, false = word to definition
  bool _isCardFlipped = false;
  final GameSession _gameSession = GameSession();
  
  // Track answered questions and their answers
  Map<int, List<String>> _answeredQuestions = {}; // question index -> user answer
  Map<int, bool> _correctAnswersMap = {}; // question index -> is correct
  Map<int, String> _correctWords = {}; // question index -> correct word
  Map<int, List<String>> _scrambledLettersMap = {}; // question index -> scrambled letters
  Map<int, bool> _questionModes = {}; // question index -> is question mode
  
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
    for (final originalCard in widget.cards) {
      final updatedCard = provider.getCard(originalCard.id);
      if (updatedCard != null) {
        updatedCards.add(updatedCard);
      } else {
        // If card was deleted, keep the original
        updatedCards.add(originalCard);
      }
    }
    
    // Update the current question if it's using an updated card
    if (_currentIndex < updatedCards.length) {
      final currentCard = updatedCards[_currentIndex];
      if (currentCard.id == widget.cards[_currentIndex].id) {
        // Regenerate question with updated card data
        _generateQuestion();
      }
    }
    
    print('🔍 WordScrambleView: Refreshed cards from provider');
  }

  void _generateQuestion() {
    if (_currentIndex >= widget.cards.length) {
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
      return;
    }

    // Check if this question has already been answered
    if (_answeredQuestions.containsKey(_currentIndex)) {
      // Load existing question data
      _isQuestionMode = _questionModes[_currentIndex]!;
      _correctWord = _correctWords[_currentIndex]!;
      _scrambledLetters = List<String>.from(_scrambledLettersMap[_currentIndex]!);
      _userAnswer = List<String>.from(_answeredQuestions[_currentIndex]!);
      _answered = true;
      return;
    }

    final currentCard = widget.cards[_currentIndex];
    final random = Random();
    
    // Respect the startFlipped parameter to determine question orientation
    _isQuestionMode = !widget.startFlipped; // true = definition to word, false = word to definition
    
    // Get correct answer based on orientation
    if (_isQuestionMode) {
      // Show definition, ask for word
      _correctWord = currentCard.word.toLowerCase();
    } else {
      // Show word, ask for definition
      _correctWord = currentCard.definition.toLowerCase();
    }
    
    // Create scrambled pieces (2-3 letters each, handling multi-word phrases)
    _scrambledLetters = _createPiecesFromWords(_correctWord, random);
    
    // Store original letters for comparison (all letters without spaces)
    _originalLetters = _correctWord.split('').where((char) => char != ' ').toList();
    
    // Store question data for future reference
    _correctWords[_currentIndex] = _correctWord;
    _scrambledLettersMap[_currentIndex] = List<String>.from(_scrambledLetters);
    _questionModes[_currentIndex] = _isQuestionMode;
    
    setState(() {
      _answered = false;
      _userAnswer = [];
      _isCardFlipped = false;
    });
  }

  void _addPiece(String piece) {
    if (_answered || piece.isEmpty) return;
    
    setState(() {
      _userAnswer.add(piece);
      // Remove the piece from available pieces
      _scrambledLetters.remove(piece);
    });
    
    // Auto-check answer if we have used all non-empty pieces
    final nonEmptyPieces = _scrambledLetters.where((p) => p.isNotEmpty).length;
    if (nonEmptyPieces == 0) {
      _checkAnswer();
    }
  }

  void _removeLetterAt(int index) {
    if (_answered || index < 0 || index >= _userAnswer.length) return;
    
    setState(() {
      final removedPiece = _userAnswer.removeAt(index);
      // Add the piece back to available pieces
      _scrambledLetters.add(removedPiece);
    });
  }

  void _checkAnswer() {
    if (_answered || _userAnswer.isEmpty) return;
    
    final userWord = _userAnswer.join('');
    final correctWordWithoutSpaces = _correctWord.replaceAll(' ', '').toLowerCase();
    final isCorrect = userWord.toLowerCase() == correctWordWithoutSpaces;
    final currentCard = widget.cards[_currentIndex];
    
    // Track XP for this answer
    XpService.recordAnswer(_gameSession, isCorrect);
    
    // Update learning progress in the provider
    _updateCardLearningProgress(currentCard, isCorrect);
    
    // Award XP to word for RPG system
    _awardXPToWord(currentCard, isCorrect);
    
    setState(() {
      _answered = true;
      _totalAnswered++;
      
      if (isCorrect) {
        _correctAnswers++;
        _correctAnswersMap[_currentIndex] = true;
        SoundManager().playCorrectSound();
      } else {
        _correctAnswersMap[_currentIndex] = false;
        SoundManager().playWrongSound();
        
        // Handle lives system
        if (_useLivesMode) {
          _lives--;
          print('🔍 WordScrambleView: Lost a life! Lives remaining: $_lives');
          
          if (_lives <= 0) {
            print('🔍 WordScrambleView: Game over! No lives remaining');
            _showGameOverScreen();
            return;
          }
        }
      }
      
      // Store the answer for navigation
      _answeredQuestions[_currentIndex] = List<String>.from(_userAnswer);
    });
    
    // Auto progress logic
    if (widget.autoProgress) {
      _autoProgressTimer?.cancel();
      _autoProgressTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted && _currentIndex < widget.cards.length - 1) {
          _goToNextQuestion();
        }
      });
    }
  }

  Future<void> _updateCardLearningProgress(FlashCard card, bool wasCorrect) async {
    try {
      final provider = context.read<FlashcardProvider>();
      
      // Get game difficulty for word scramble
      final difficulty = GameDifficultyHelper.getDifficultyForGameMode('word scramble');
      
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
      print('🔍 WordScrambleView: Updated learning progress for "${card.word}" - wasCorrect: $wasCorrect, difficulty: ${difficulty.name}, new percentage: ${updatedCard.learningPercentage}%');
      
      // Also sync to Dutch words if this card exists there
      await _syncToDutchWords(card, wasCorrect);
      
    } catch (e) {
      print('🔍 WordScrambleView: Error updating learning progress: $e');
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
        print('🔍 WordScrambleView: Synced progress to Dutch word exercise "${wordExercise.targetWord}"');
      }
    } catch (e) {
      print('🔍 WordScrambleView: Error syncing to Dutch words: $e');
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

  void _goToNextQuestion() {
    // In shuffle mode, we only have one question, so call the callback immediately
    if (widget.shuffleMode) {
      // Check if the answer is correct by comparing user answer with correct word
      final userWord = _userAnswer.join('');
      final correctWordWithoutSpaces = _correctWord.replaceAll(' ', '').toLowerCase();
      final isCorrect = userWord.toLowerCase() == correctWordWithoutSpaces;
      
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
  
  void _flipCard() {
    setState(() {
      _isCardFlipped = !_isCardFlipped;
    });
  }
  
  List<String> _createPiecesFromWords(String phrase, Random random) {
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
  
  List<String> _createPieces(List<String> letters, Random random) {
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

  bool _isPieceUsed(String piece, int index) {
    // Empty pieces are always considered "used"
    if (piece.isEmpty) return true;
    
    // If the piece is not in the scrambled letters list, it's been used
    return !_scrambledLetters.contains(piece);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('No cards available for word scramble'),
        ),
      );
    }

    if (_showingResults) {
      return _buildResultsView();
    }

    final currentCard = widget.cards[_currentIndex];
    final question = _isQuestionMode ? currentCard.definition : currentCard.word;

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
                    'Arrange the pieces to translate:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16), // Reduced spacing
                  
                  // Card with white background and colored outline
                  GestureDetector(
                    onDoubleTap: _flipCard,
                    child: Container(
                      width: double.infinity,
                      height: 200, // Reduced height
                      padding: const EdgeInsets.all(24), // Reduced padding
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _isCardFlipped 
                              ? (_isQuestionMode ? currentCard.word : currentCard.definition)
                              : question,
                          style: const TextStyle(
                            fontSize: 32, // Smaller font size
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16), // Reduced spacing
                  
                  // Navigation buttons (always show, greyed out when not available)
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
                width: piece.length > 2 ? 50 : 40, // Wider for longer pieces
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
                      fontSize: piece.length > 2 ? 14 : 16, // Smaller font for longer pieces
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
          onTap: _answered || isUsed || piece.isEmpty ? null : () => _addPiece(piece),
          child: Container(
            width: piece.length > 2 ? 70 : 60, // Wider for longer pieces
            height: 50,
            decoration: BoxDecoration(
              color: isUsed || piece.isEmpty
                  ? Colors.grey.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: isUsed || piece.isEmpty
                    ? Colors.grey.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                piece.isEmpty ? '•' : piece, // Show dot for empty pieces
                style: TextStyle(
                  fontSize: piece.length > 2 ? 16 : 18, // Smaller font for longer pieces
                  fontWeight: FontWeight.bold,
                  color: isUsed || piece.isEmpty
                      ? Colors.grey.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
            // Header
            UnifiedHeader(
              title: 'Scramble Complete',
              onBack: () => Navigator.of(context).pop(),
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
                    _buildStatCard('Questions', _totalAnswered.toString(), Icons.text_fields),
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
                          _userAnswer = [];
                          _gameSession.reset(); // Reset XP tracking
                          // Reset all navigation state
                          _answeredQuestions.clear();
                          _correctAnswersMap.clear();
                          _correctWords.clear();
                          _scrambledLettersMap.clear();
                          _questionModes.clear();
                          
                          // Reset RPG tracking
                          _xpGainedPerWord.clear();
                          _wordMastery.clear();
                          _studiedWords.clear();
                        });
                        _generateQuestion();
                      },
                      child: const Text('Scramble Again'),
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

  Color _getCardBorderColor(FlashCard card) {
    // Generate a consistent color based on the card's ID
    final hash = card.id.hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[hash.abs() % colors.length];
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Scramble?'),
        content: const Text('Are you sure you want to end this word scramble session?'),
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
            child: const Text('End Session'),
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
        content: const Text('Are you sure you want to return to the home screen? This will end your current word scramble session.'),
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
    if (!widget.shuffleMode && _gameSession.xpGained > 0) {
      final userProfileProvider = context.read<UserProfileProvider>();
      XpService.awardSessionXp(userProfileProvider, _gameSession, isShuffleMode: widget.shuffleMode);
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
      final xpGained = xpService.calculateWordXP("word_scramble", 1);
      
      // Add XP to the word's learning mastery
      xpService.addXPToWord(card.learningMastery, "word_scramble", 1);
      
      // Track XP gained for this word in this session
      _xpGainedPerWord[card.id] = (_xpGainedPerWord[card.id] ?? 0) + xpGained;
      
      // Store the word mastery for display
      _wordMastery[card.id] = card.learningMastery;
      
      print('🔍 WordScrambleView: Awarded $xpGained XP to word "${card.word}" (Correct: $isCorrect)');
    } else {
      print('🔍 WordScrambleView: No XP awarded to word "${card.word}" (Incorrect: $isCorrect)');
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
              _correctWord = '';
              _scrambledLetters.clear();
              _userAnswer.clear();
              _originalLetters.clear();
              _isCardFlipped = false;
              _gameSession.reset();
              
              // Reset lives if using lives mode
              if (_useLivesMode) {
                _lives = _maxLives;
              }
              
              // Reset all navigation state
              _answeredQuestions.clear();
              _correctAnswersMap.clear();
              _correctWords.clear();
              _scrambledLettersMap.clear();
              _questionModes.clear();
              
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