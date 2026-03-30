import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:async';
import '../models/flash_card.dart';
import '../models/game_session.dart';
import '../models/learning_mastery.dart';
import '../components/unified_header.dart';
import '../components/main_header.dart';
import '../components/xp_progress_widget.dart';
import '../components/animated_xp_counter.dart';
import '../services/sound_manager.dart';
import '../services/xp_service.dart';
import '../services/haptic_service.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/dutch_word_exercise.dart';
import '../services/haptic_service.dart';
import '../utils/game_difficulty_helper.dart';
import '../utils/game_end_screen.dart';
import 'add_card_view.dart';

class WordScrambleView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final Function(bool)? onComplete;
  final bool shuffleMode;
  final bool startFlipped;
  final bool autoProgress;
  final bool useLivesMode;
  final int? customLives;
  final int? shuffleQuestionOffset; // Offset for cumulative question count in shuffle mode
  final bool oneAnswerMode;
  final bool enableHints;

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
    this.shuffleQuestionOffset,
    this.oneAnswerMode = true,
    this.enableHints = true,
  });

  @override
  State<WordScrambleView> createState() => _WordScrambleViewState();
}

class _WordScrambleViewState extends State<WordScrambleView> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  bool _showingResults = false;
  bool _hasShownResults = false; // Prevent multiple end screens
  bool _answered = false;
  String _correctWord = '';
  List<String> _scrambledLetters = [];
  List<String> _userAnswer = [];
  List<String> _originalLetters = [];
  bool _isQuestionMode = true; // true = definition to word, false = word to definition
  bool _isCardFlipped = false;
  final GameSession _gameSession = GameSession();
  
  // Local copy of cards for shuffling
  late List<FlashCard> _currentCards;
  
  // Track answered questions and their answers
  Map<int, List<String>> _answeredQuestions = {}; // question index -> user answer
  Map<int, bool> _correctAnswersMap = {}; // question index -> is correct
  Map<int, String> _correctWords = {}; // question index -> correct word
  Map<int, List<String>> _scrambledLettersMap = {}; // question index -> scrambled letters
  Map<int, bool> _questionModes = {}; // question index -> is question mode
  Set<int> _autoProgressedQuestions = {}; // Track which questions have been auto-progressed
  int _activeQuestionIndex = 0; // Track the furthest question that auto progress has reached
  
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
  Set<String> _hpPenaltyAppliedWordIds = {};
  
  // Hint system
  Map<int, int> _hintCount = {}; // Track how many hints used per question
  Map<int, List<String>> _hintRevealed = {}; // Track what pieces were revealed by hints
  Map<int, List<String>> _correctPieceOrder = {}; // Track correct piece order for each question
  Map<int, Set<int>> _lockedPositions = {}; // Track which positions in user answer are locked (hinted)
  String? _hintStatusMessage;
  
  // Animation controllers for feedback
  late AnimationController _shakeController;
  late AnimationController _successController;
  late AnimationController _dealController;
  int _consecutiveCorrect = 0; // Streak tracking
  Timer? _hintStatusTimer;
  
  // Review system
  Set<String> _reviewCards = {}; // Track which cards are in review deck
  String? _reviewStatusMessage;
  Timer? _reviewStatusTimer;
  
  // Wrong attempts tracking
  Map<int, int> _wrongAttempts = {}; // question index -> number of wrong attempts
  
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;
  bool _isShowingWrongAnswer = false; // Track if we're showing wrong answer state

  @override
  void initState() {
    super.initState();
    
    // Initialize cards list
    _currentCards = List<FlashCard>.from(widget.cards);
    
    // Initialize lives system
    _useLivesMode = widget.useLivesMode;
    if (_useLivesMode) {
      _maxLives = widget.customLives ?? _getDefaultLives();
      _lives = _maxLives;
    }
    
    // Initialize animations
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

    _dealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _generateQuestion();
    _dealController.forward();
    
    // Listen for card updates from the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FlashcardProvider>();
      provider.addListener(_onProviderChanged);
    });
  }

  void _editCurrentCard() {
    final currentCard = _currentCards[_currentIndex];
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCardView(
          cardToEdit: currentCard,
        ),
      ),
    ).then((_) {
      // Refresh only WordScrambleView after editing card
      setState(() {});
    });
  }

  @override
  void dispose() {
    // Remove listener when disposing
    final provider = context.read<FlashcardProvider>();
    provider.removeListener(_onProviderChanged);
    
    // Cancel auto progress timer
    _autoProgressTimer?.cancel();
    _hintStatusTimer?.cancel();
    _reviewStatusTimer?.cancel();
    
    // Dispose animation controller
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

  void _ensureCardTracked(FlashCard card) {
    if (_studiedWords.any((word) => word.id == card.id)) return;
    _studiedWords.add(card);
    _initialHPPerWord[card.id] = card.currentHP;
  }

  void _applyHpPenalty(FlashCard card, {required bool wasCorrect}) {
    if (_hpPenaltyAppliedWordIds.contains(card.id)) return;
    _hpPenaltyAppliedWordIds.add(card.id);
    _ensureCardTracked(card);
    if (wasCorrect) {
      card.markCorrect(GameDifficulty.medium);
    } else {
      card.markIncorrect(GameDifficulty.medium);
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
    
    // Update cards WITHOUT regenerating question
    // Regenerating would reset wrong answer state, attempts, and question progress
    // CRITICAL: Don't call _generateQuestion() as it resets _isShowingWrongAnswer, _userAnswer, _wrongAttempts
    // Just update the card references, preserve all question state
    // Note: _currentCards is read-only in this widget (it's from widget.cards), so we don't update it
    // The provider update just ensures we have the latest card data
    
    print('🔍 WordScrambleView: Refreshed cards from provider (preserving wrong answer state and attempts, NOT regenerating question)');
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

    final currentCard = _currentCards[_currentIndex];
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
    
    // Create pieces (2-3 letters each, handling multi-word phrases)
    // First, create the pieces without shuffling to get the correct order
    final correctPieces = _createPiecesFromWords(_correctWord, Random(42), shuffle: false); // Use fixed seed for consistent order, no shuffle
    _correctPieceOrder[_currentIndex] = correctPieces;
    
    // Then create the scrambled version by shuffling the correct pieces
    _scrambledLetters = List<String>.from(correctPieces);
    _scrambledLetters.shuffle(random);
    
    print('🔍 WordScrambleView: Correct piece order: $correctPieces');
    print('🔍 WordScrambleView: Scrambled pieces: $_scrambledLetters');
    
    // Store original letters for comparison (all letters without spaces)
    _originalLetters = _correctWord.split('').where((char) => char != ' ').toList();
    
    // Store question data for future reference
    _correctWords[_currentIndex] = _correctWord;
    _scrambledLettersMap[_currentIndex] = List<String>.from(_scrambledLetters);
    _questionModes[_currentIndex] = _isQuestionMode;
    
    setState(() {
      _answered = false;
      _userAnswer = [];
      _isShowingWrongAnswer = false;
      _isCardFlipped = false;
      _hintStatusTimer?.cancel();
      _hintStatusMessage = null;
      _reviewStatusTimer?.cancel();
      _reviewStatusMessage = null;
      // Reset wrong attempts only if this is a new question (not already attempted)
      if (!_answeredQuestions.containsKey(_currentIndex)) {
        _wrongAttempts[_currentIndex] = 0;
      } else {
        // Preserve wrong attempts for already attempted questions
        _wrongAttempts[_currentIndex] ??= 0;
      }
      // Reset hint tracking for new question (hint tracking is per question)
      _lockedPositions[_currentIndex] = <int>{}; // Reset locked positions for new question
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
    
    // Check if this position is locked (hinted)
    final lockedPositions = _lockedPositions[_currentIndex] ?? <int>{};
    if (lockedPositions.contains(index)) return;
    
    setState(() {
      final removedPiece = _userAnswer.removeAt(index);
      // Add the piece back to available pieces
      _scrambledLetters.add(removedPiece);
      
      // Update locked positions - shift down indices after removed position
      final newLockedPositions = <int>{};
      for (final lockedIndex in lockedPositions) {
        if (lockedIndex > index) {
          newLockedPositions.add(lockedIndex - 1);
        } else if (lockedIndex < index) {
          newLockedPositions.add(lockedIndex);
        }
        // Skip the removed position itself
      }
      _lockedPositions[_currentIndex] = newLockedPositions;
    });
  }

  void _checkAnswer() {
    if (_answered || _userAnswer.isEmpty || _isShowingWrongAnswer) return;
    
    final userWord = _userAnswer.join('');
    final correctWordWithoutSpaces = _correctWord.replaceAll(' ', '').toLowerCase();
    final isCorrect = userWord.toLowerCase() == correctWordWithoutSpaces;
    final currentCard = _currentCards[_currentIndex];
    final wrongAttempts = _wrongAttempts[_currentIndex] ?? 0;
    
    if (isCorrect) {
      // Correct answer - proceed normally
      // Track XP for this answer
      XpService.recordAnswer(_gameSession, isCorrect);
      
      // Award XP to word for RPG system (with wrong attempts penalty)
      _applyHpPenalty(currentCard, wasCorrect: true);
      _awardXPToWord(currentCard, true, wrongAttempts);
      
      // Update the card in the provider to save the XP changes
      _updateCardInProvider(currentCard);
      
      setState(() {
        _answered = true;
        _totalAnswered++;
        _correctAnswers++;
        _correctAnswersMap[_currentIndex] = true;
        _consecutiveCorrect++;
        _successController.forward(from: 0);
      });
      
      HapticService().successFeedback();
      SoundManager().playCorrectSound();
      
      // Store the answer for navigation
      _answeredQuestions[_currentIndex] = List<String>.from(_userAnswer);
      
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
    } else {
      // Wrong answer - shake, turn red, reset, and apply XP penalty
      final newWrongAttempts = widget.oneAnswerMode ? 5 : (wrongAttempts + 1);
      _wrongAttempts[_currentIndex] = newWrongAttempts;
      
      // Track XP for wrong attempt
      XpService.recordAnswer(_gameSession, false);
      
      // Handle lives system (already handles life loss correctly)
      if (_useLivesMode) {
        setState(() {
          _lives--;
        });
        print('🔍 WordScrambleView: Lost a life! Lives remaining: $_lives');
        
        if (_lives <= 0) {
          print('🔍 WordScrambleView: Game over! No lives remaining');
          _applyHpPenalty(currentCard, wasCorrect: false);
          _awardXPToWord(currentCard, false, newWrongAttempts);
          _updateCardInProvider(currentCard);
          
          // In shuffle mode, complete with failure
          if (widget.shuffleMode && mounted && widget.onComplete != null) {
            widget.onComplete!(false);
            return;
          }
          
          _showGameOverScreen();
          return;
        }
      }
      
      // If 1-Click Answer is enabled or 5 wrong attempts reached, auto-complete
      if (widget.oneAnswerMode || newWrongAttempts >= 5) {
        print('🔍 WordScrambleView: ${widget.oneAnswerMode ? '1-Click Answer mode' : '5 wrong attempts'} reached! Auto-completing.');
        
        // Award 0 XP since they failed
        _applyHpPenalty(currentCard, wasCorrect: false);
        _awardXPToWord(currentCard, false, 5); // Force penalty for XP calculation
        _updateCardInProvider(currentCard);
        
        // Get the correct piece order and set it as the user answer
        final correctPieces = _correctPieceOrder[_currentIndex] ?? [];
        
        setState(() {
          // Clear any current showing of wrong state
          _isShowingWrongAnswer = false;
          // Set user answer to the correct order of pieces
          _userAnswer = List<String>.from(correctPieces);
          _answered = true;
          _totalAnswered++;
          _correctAnswersMap[_currentIndex] = false;
          _consecutiveCorrect = 0; // Reset streak
          _shakeController.forward(from: 0);
          
          _answeredQuestions[_currentIndex] = List<String>.from(correctPieces);
        });
        
        HapticService().errorFeedback();
        
        // In shuffle mode, complete with failure after the attempts are used up
        if (widget.shuffleMode && mounted && widget.onComplete != null) {
          widget.onComplete!(false);
        }
        
        return;
      }
      
      // Show wrong answer state (red) and shake
      // Keep the pieces in the answer position - don't clear them yet
      print('🔍 WordScrambleView: Showing wrong answer. Wrong attempts: $newWrongAttempts/5, userAnswer: $_userAnswer');
      
      setState(() {
        _isShowingWrongAnswer = true;
        // IMPORTANT: Keep userAnswer visible so pieces stay in place
      });
      
      SoundManager().playWrongSound();
      
      // Start shake animation
      _shakeController.forward(from: 0);
      
      // After shake animation completes, reset and allow retry
      // Wait for feedback to be visible
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && !_answered) {
          // Only reset if not already answered (e.g. by auto-complete after penalty)
          final piecesToReturn = List<String>.from(_userAnswer);
          
          setState(() {
            _isShowingWrongAnswer = false;
            _scrambledLetters.addAll(piecesToReturn);
            _userAnswer.clear();
          });
        }
      });
    }
  }

  Future<void> _updateCardInProvider(FlashCard card) async {
    try {
      final provider = context.read<FlashcardProvider>();
      
      // Update the card in the provider to save the XP changes
      await provider.updateCard(card);
      print('🔍 WordScrambleView: Updated card "${card.word}" in provider - current XP: ${card.learningMastery.currentXP}');
      
    } catch (e) {
      print('🔍 WordScrambleView: Error updating card in provider: $e');
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
  
  List<String> _createPiecesFromWords(String phrase, Random random, {bool shuffle = true}) {
    final pieces = <String>[];
    
    // Split the phrase into words
    final words = phrase.split(' ');
    
    for (final word in words) {
      if (word.isEmpty) continue;
      
      final letters = word.split('');
      final wordPieces = _createPieces(letters, random);
      pieces.addAll(wordPieces);
    }
    
    // Only shuffle if requested (for scrambled version)
    if (shuffle) {
      pieces.shuffle(random);
    }
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
    final question = _isQuestionMode ? currentCard.definition : currentCard.word;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          MainHeader(
            title: 'Jumble',
            leftAction: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => _showCloseConfirmation(),
            ),
            rightAction: IconButton(
              icon: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
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
                    child: Stack(
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
                              _isCardFlipped 
                                  ? (_isQuestionMode ? currentCard.word : currentCard.definition)
                                  : question,
                              style: TextStyle(
                                fontSize: _getAdaptiveFontSize(context), // Adaptive font size
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Theme.of(context).colorScheme.onSurface 
                                    : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              softWrap: true,
                              overflow: TextOverflow.visible,
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
                        if (!_answered && widget.enableHints)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: _buildHintIcon(),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16), // Reduced spacing
                  
                  const SizedBox(height: 20), // Reduced spacing
                  
                  // Answer box
                  DragTarget<String>(
                    onWillAcceptWithDetails: (details) => !_answered,
                    onAcceptWithDetails: (details) {
                      _addPiece(details.data);
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: candidateData.isNotEmpty 
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: candidateData.isNotEmpty
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                            width: candidateData.isNotEmpty ? 2 : 1,
                          ),
                        ),
                        child: SizedBox(
                          height: 80,
                          child: _userAnswer.isEmpty
                              ? Center(
                                  child: Text(
                                    'Drag or tap pieces to build the word',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : _buildUserAnswerDisplay(),
                        ),
                      );
                    },
                  ),
                  
                  // Feedback should appear below the answer box
                  if (_isShowingWrongAnswer || _answered) ...[
                    const SizedBox(height: 12),
                    _buildAnswerFeedback(),
                  ],
                  
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Card ${widget.shuffleMode && widget.shuffleQuestionOffset != null ? (widget.shuffleQuestionOffset! + _currentIndex + 1) : (_currentIndex + 1)}/${widget.cards.length}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              // Show lives and/or streak in the middle
              if (_useLivesMode || _consecutiveCorrect >= 3) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_useLivesMode) ...[
                      _buildLivesIndicator(),
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
              ],
              Text(
                'Acc: ${_totalAnswered > 0 ? (_correctAnswers / _totalAnswered * 100).toInt() : 100}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
                  foregroundColor: _currentIndex > 0 ? Colors.black87 : Colors.grey,
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
  

  Widget _buildUserAnswerDisplay() {
    return AnimatedBuilder(
      animation: Listenable.merge([_shakeController, _successController]),
      builder: (context, child) {
        // Create a more visible shake effect when wrong answer is shown
        double shakeOffset = 0;
        if (_isShowingWrongAnswer && _shakeController.isAnimating) {
          // Create a more pronounced shake by using sine waves
          shakeOffset = _shakeAnimation.value * (2 * (1 - _shakeAnimation.value / 10)) * 
                       ((_shakeAnimation.value * 10).round() % 2 == 0 ? 1 : -1);
        }
        
        double scale = 1.0;
        if (_answered && (_userAnswer.join('').toLowerCase() == _correctWord.replaceAll(' ', '').toLowerCase())) {
          scale = _pulseAnimation.value;
        }
        
        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Note: "Incorrect, try again" text is now shown in the main feedback area below
              Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_userAnswer.isEmpty && !_isShowingWrongAnswer)
                      Text(
                        'Drag or tap pieces to build your answer',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      )
                  else if (_userAnswer.isNotEmpty)
                ..._userAnswer.asMap().entries.map((entry) {
                  final index = entry.key;
                  final piece = entry.value;
                  final lockedPositions = _lockedPositions[_currentIndex] ?? <int>{};
                  final isLocked = lockedPositions.contains(index);
                  
                  if (isLocked) {
                    print('🔍 WordScrambleView: Piece "$piece" at position $index is LOCKED (orange border)');
                  } else {
                    print('🔍 WordScrambleView: Piece "$piece" at position $index is UNLOCKED (blue border)');
                  }
                  
                  return Draggable<int>(
                    data: index,
                    maxSimultaneousDrags: _answered || isLocked || _isShowingWrongAnswer ? 0 : 1,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: piece.length > 2 ? 50 : 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            piece,
                            style: TextStyle(
                              fontSize: piece.length > 2 ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: piece.length > 2 ? 50 : 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          border: Border.all(color: Colors.grey, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    child: DragTarget<int>(
                      onWillAcceptWithDetails: (details) => !_answered && !isLocked && !_isShowingWrongAnswer,
                      onAcceptWithDetails: (details) {
                        final fromIndex = details.data;
                        if (fromIndex != index) {
                          setState(() {
                            final temp = _userAnswer[index];
                            _userAnswer[index] = _userAnswer[fromIndex];
                            _userAnswer[fromIndex] = temp;
                          });
                          HapticService().selectionFeedback();
                        }
                      },
                      builder: (context, candidateData, rejectedData) {
                        return GestureDetector(
                          onTap: _answered || isLocked || _isShowingWrongAnswer ? null : () => _removeLetterAt(index),
                          child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: piece.length > 2 ? 50 : 40, // Wider for longer pieces
                      height: 40,
                      decoration: BoxDecoration(
                        color: _answered 
                            ? (_userAnswer.join('').toLowerCase() == _correctWord.replaceAll(' ', '').toLowerCase() 
                                ? Colors.green.withValues(alpha: 0.2) 
                                : Colors.red.withValues(alpha: 0.2))
                            : _isShowingWrongAnswer
                                ? Colors.red.withValues(alpha: 0.4) // More visible red background when wrong
                                : isLocked 
                                    ? Colors.orange.withValues(alpha: 0.2) // Locked pieces have orange background
                                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        border: Border.all(
                          color: _answered 
                              ? (_userAnswer.join('').toLowerCase() == _correctWord.replaceAll(' ', '').toLowerCase() 
                                  ? Colors.green 
                                  : Colors.red)
                              : _isShowingWrongAnswer
                                  ? Colors.red.withValues(alpha: 1.0) // Bright red border when wrong
                                  : isLocked 
                                      ? Colors.orange // Locked pieces have orange border
                                      : Theme.of(context).colorScheme.primary,
                          width: _isShowingWrongAnswer ? 3 : (isLocked ? 3 : 1), // Thicker border when showing wrong answer
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
                                : _isShowingWrongAnswer
                                    ? Colors.red.withValues(alpha: 1.0) // Bright red text when wrong
                                    : isLocked 
                                        ? Colors.orange // Locked pieces have orange text
                                        : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
            ],
              ),
            ),
          ],
        ),
      );
      },
    );
  }

  Widget _buildAnswerFeedback() {
    print('🔍 WordScrambleView: Building feedback - _isShowingWrongAnswer: $_isShowingWrongAnswer, _answered: $_answered, userAnswer: $_userAnswer');
    
    if (_isShowingWrongAnswer && !_answered) {
      final wrongAttempts = _wrongAttempts[_currentIndex] ?? 0;
      return Text(
        'Incorrect, try again ($wrongAttempts/5 attempts)',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
        textAlign: TextAlign.center,
      );
    }
    
    if (_answered) {
      final isMarkedCorrect = _correctAnswersMap[_currentIndex] ?? false;
      
      if (isMarkedCorrect) {
        return Text(
          'Correct!',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.green,
          ),
          textAlign: TextAlign.center,
        );
      }
      
      return Text(
        'The correct answer is: $_correctWord',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.red,
        ),
        textAlign: TextAlign.center,
      );
    }
    
    return const SizedBox.shrink();
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
        
        Widget pieceWidget = Container(
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
        );

        return Draggable<String>(
          data: piece,
          maxSimultaneousDrags: _answered || isUsed || piece.isEmpty ? 0 : 1,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.8,
              child: pieceWidget,
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: pieceWidget),
          child: GestureDetector(
            onTap: _answered || isUsed || piece.isEmpty ? null : () => _addPiece(piece),
            child: pieceWidget,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultsView() {
    final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered * 100).toInt() : 0;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
          children: [
            // Fixed Header - matching Taal Trek header height
            SafeArea(
              child: Container(
                height: kToolbarHeight,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: _buildCustomHeaderResults(context),
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
                    _buildStatCard('Questions', _totalAnswered.toString(), Icons.text_fields),
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
                          _hasShownResults = false;
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
    _initialHPPerWord.clear();
    _hpPenaltyAppliedWordIds.clear();
    _initialHPPerWord.clear();
    _hpPenaltyAppliedWordIds.clear();
                          _initialHPPerWord.clear();
                          _hpPenaltyAppliedWordIds.clear();
                        });
                        _generateQuestion();
                      },
                      child: const Text('Scramble Again'),
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
              Navigator.of(context).pop();
            },
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewFlag(FlashCard card) {
    final isInReview = _reviewCards.contains(card.id);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _toggleReviewCard(card),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isInReview ? Colors.yellow : Colors.yellow.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.7),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.flag,
              color: isInReview ? Colors.orange.shade700 : Colors.orange.shade400,
              size: 18,
            ),
          ),
        ),
        if (_reviewStatusMessage != null)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Text(
              _reviewStatusMessage!,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHintIcon() {
    final hintsUsed = _hintCount[_currentIndex] ?? 0;
    final remainingPieces = _scrambledLetters.where((p) => p.isNotEmpty).length;
    // Block hints when only 1 piece remains - it would trivially solve the puzzle
    final canUseHint = remainingPieces > 1 && !_answered;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hintStatusMessage != null)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Text(
              _hintStatusMessage!,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Tooltip(
          message: canUseHint 
              ? 'Use hint (${hintsUsed} used)'
              : 'No more hints available',
          child: GestureDetector(
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
          ),
        ),
      ],
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
        _reviewStatusTimer?.cancel();
        setState(() {
          _reviewStatusMessage = 'Added to review';
        });
      } else {
        await provider.removeCardFromReview(card);
        _reviewStatusTimer?.cancel();
        setState(() {
          _reviewStatusMessage = 'Removed from review';
        });
      }
      _reviewStatusTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _reviewStatusMessage = null;
          });
        }
      });
    } catch (e) {
      print('🔍 WordScrambleView: Error toggling review card: $e');
      _reviewStatusTimer?.cancel();
      setState(() {
        _reviewStatusMessage = 'Action failed';
      });
      _reviewStatusTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _reviewStatusMessage = null);
        }
      });
    }
  }

  void _useHint() {
    if (_answered) return;
    
    final currentHintCount = _hintCount[_currentIndex] ?? 0;
    final revealedPieces = _hintRevealed[_currentIndex] ?? [];
    final remainingPieces = _scrambledLetters.length;
    
    final correctWord = _correctWords[_currentIndex] ?? '';
    final correctPieces = _correctPieceOrder[_currentIndex] ?? [];
    
    print('🔍 WordScrambleView: Using hint for word: "$correctWord"');
    print('🔍 WordScrambleView: Available pieces: $_scrambledLetters');
    print('🔍 WordScrambleView: Already revealed: $revealedPieces');
    print('🔍 WordScrambleView: Correct piece order: $correctPieces');
    print('🔍 WordScrambleView: Current user answer: $_userAnswer');
    print('🔍 WordScrambleView: Remaining pieces: $remainingPieces');
    
    // IMPROVED HINT LOGIC:
    // When only 1 piece remains, place pieces in correct order sequentially
    // 1. Find the first position where user's piece is wrong or missing
    // 2. Find the correct piece for that position
    // 3. If that piece is available, use it to replace/add the piece
    // 4. If not available, swap pieces as needed to get the correct one in place
    
    String? hintPiece;
    int positionToFix = -1;
    
    // Find the first wrong position that's not locked
    final lockedPositions = _lockedPositions[_currentIndex] ?? <int>{};
    
    for (int i = 0; i < _userAnswer.length && i < correctPieces.length; i++) {
      if (!lockedPositions.contains(i) && _userAnswer[i] != correctPieces[i]) {
        positionToFix = i;
        print('🔍 WordScrambleView: Found wrong piece at position $i: user="${_userAnswer[i]}" vs correct="${correctPieces[i]}"');
        break;
      }
    }
    
    // If no wrong positions found, find the next missing piece
    if (positionToFix == -1 && _userAnswer.length < correctPieces.length) {
      positionToFix = _userAnswer.length;
      print('🔍 WordScrambleView: No wrong pieces found, need to add piece at position $positionToFix');
    }
    
    if (positionToFix >= 0 && positionToFix < correctPieces.length) {
      final correctPieceForPosition = correctPieces[positionToFix];
      print('🔍 WordScrambleView: Looking for correct piece "$correctPieceForPosition" for position $positionToFix');
      
      // Check if the correct piece is available in scrambled letters
      if (_scrambledLetters.contains(correctPieceForPosition)) {
        hintPiece = correctPieceForPosition;
        print('🔍 WordScrambleView: Found correct piece "$hintPiece" in available pieces');
      } else {
        print('🔍 WordScrambleView: Correct piece "$correctPieceForPosition" not available in: $_scrambledLetters');
        
        // If the correct piece is not available, check if it's already in user answer at wrong position
        // If so, swap it to the correct position
        int wrongPosition = -1;
        for (int i = 0; i < _userAnswer.length; i++) {
          if (!lockedPositions.contains(i) && _userAnswer[i] == correctPieceForPosition) {
            wrongPosition = i;
            break;
          }
        }
        
        if (wrongPosition >= 0) {
          // The correct piece is in the wrong position - we'll swap it
          print('🔍 WordScrambleView: Correct piece "$correctPieceForPosition" is at wrong position $wrongPosition, will swap');
          hintPiece = correctPieceForPosition;
        } else {
          // If the correct piece is not available and not in user answer, use any available piece
          // This handles cases where pieces are already used incorrectly
          for (final piece in _scrambledLetters) {
            if (!revealedPieces.contains(piece)) {
              hintPiece = piece;
              print('🔍 WordScrambleView: Using available piece "$piece" as hint (correct piece not available)');
              break;
            }
          }
        }
      }
    }
    
    if (hintPiece == null) {
      print('🔍 WordScrambleView: No suitable hint piece found');
    }
    
    if (hintPiece != null) {
      setState(() {
        // Increment hint count for this question
        _hintCount[_currentIndex] = currentHintCount + 1;
        
        // Track this piece as revealed by hint
        if (_hintRevealed[_currentIndex] == null) {
          _hintRevealed[_currentIndex] = [];
        }
        _hintRevealed[_currentIndex]!.add(hintPiece!);
        
        // Use the improved hint logic with positionToFix
        print('🔍 WordScrambleView: Hint piece to place: "$hintPiece" at position $positionToFix');
        
        if (positionToFix >= 0) {
          // Check if the correct piece is already in user answer at wrong position
          int wrongPosition = -1;
          final lockedPositions = _lockedPositions[_currentIndex] ?? <int>{};
          for (int i = 0; i < _userAnswer.length; i++) {
            if (!lockedPositions.contains(i) && _userAnswer[i] == hintPiece) {
              wrongPosition = i;
              break;
            }
          }
          
          if (wrongPosition >= 0 && wrongPosition != positionToFix) {
            // Swap pieces: move the correct piece from wrong position to correct position
            // Simple swap: exchange the values at the two positions
            if (positionToFix < _userAnswer.length) {
              // There's a piece at the correct position - swap them
              final pieceAtCorrectPosition = _userAnswer[positionToFix];
              _userAnswer[positionToFix] = hintPiece!; // Put correct piece at correct position
              _userAnswer[wrongPosition] = pieceAtCorrectPosition; // Put wrong piece at wrong position
              print('🔍 WordScrambleView: Swapped piece "$hintPiece" from position $wrongPosition to position $positionToFix, moved "$pieceAtCorrectPosition" to position $wrongPosition');
            } else {
              // No piece at correct position yet - just move the correct piece there
              _userAnswer.removeAt(wrongPosition);
              _userAnswer.add(hintPiece!);
              print('🔍 WordScrambleView: Moved piece "$hintPiece" from position $wrongPosition to end (position ${_userAnswer.length - 1})');
            }
          } else {
            // Normal case: piece is in scrambled letters, add/replace it
            // Remove the hint piece from available pieces
            _scrambledLetters.remove(hintPiece!);
            
            if (positionToFix < _userAnswer.length) {
              // Replace an existing wrong piece
              final oldPiece = _userAnswer[positionToFix];
              _userAnswer[positionToFix] = hintPiece!;
              
              // Add the old piece back to available pieces if it's not empty
              if (oldPiece.isNotEmpty) {
                _scrambledLetters.add(oldPiece);
              }
              
              print('🔍 WordScrambleView: Replaced wrong piece at position $positionToFix: "$oldPiece" -> "$hintPiece"');
            } else {
              // Add a new piece at the end
              _userAnswer.add(hintPiece!);
              print('🔍 WordScrambleView: Added hint piece at end position ${_userAnswer.length - 1}: "$hintPiece"');
            }
          }
          
          // Lock all positions from the start up to and including the hinted position
          // This ensures that all correctly placed pieces (including user-placed ones) are locked
          if (_lockedPositions[_currentIndex] == null) {
            _lockedPositions[_currentIndex] = <int>{};
          }
          
          // Lock all positions from 0 to the hinted position (inclusive)
          for (int i = 0; i <= positionToFix; i++) {
            _lockedPositions[_currentIndex]!.add(i);
          }
          
          print('🔍 WordScrambleView: Locked all positions from 0 to $positionToFix: ${_lockedPositions[_currentIndex]}');
          
          // Auto-check answer if all pieces are used
          final nonEmptyPieces = _scrambledLetters.where((p) => p.isNotEmpty).length;
          if (nonEmptyPieces == 0) {
            // Small delay to allow UI to update before checking
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _checkAnswer();
              }
            });
          }
        }
      });
      
      _hintStatusTimer?.cancel();
      setState(() {
        _hintStatusMessage = 'Hint used';
      });
      _hintStatusTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _hintStatusMessage = null);
        }
      });
    } else {
      print('🔍 WordScrambleView: No hint piece found!');
      _hintStatusTimer?.cancel();
      setState(() {
        _hintStatusMessage = 'No hint available';
      });
      _hintStatusTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _hintStatusMessage = null);
        }
      });
    }
  }

  void _awardXp() {
    // Calculate total XP from actual word XP gained
    final totalXPGained = _xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp);
    
    if (!widget.shuffleMode && totalXPGained > 0) {
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
  
  void _awardXPToWord(FlashCard card, bool isCorrect, [int wrongAttempts = 0]) {
    _ensureCardTracked(card);
    
    print('🔍 WordScrambleView: Logging word "${card.word}" (isCorrect: $isCorrect, wrongAttempts: $wrongAttempts) - daily attempts: ${card.learningMastery.dailyAttemptsDebug}');
    
    if (isCorrect) {
      final latestEntry = card.learningMastery.exerciseHistory.isNotEmpty
          ? card.learningMastery.exerciseHistory.last
          : null;
      final actualXPGained = latestEntry != null
          ? (latestEntry['xpGained'] as int? ?? 0)
          : 0;
      
      final hintsUsed = _hintCount[_currentIndex] ?? 0;
      final hintPenalty = hintsUsed > 0 ? (0.25 * hintsUsed).clamp(0.0, 0.9) : 0.0;
      var finalXPGained = hintsUsed > 0
          ? (actualXPGained * (1.0 - hintPenalty)).round().clamp(1, actualXPGained)
          : actualXPGained;
      
      // Wrong attempts reduce XP by 1 each (up to 5 where it's already 0)
      if (wrongAttempts > 0 && wrongAttempts < 5) {
        finalXPGained = (finalXPGained - wrongAttempts).clamp(0, actualXPGained);
      }
      
      if (latestEntry != null) {
        card.learningMastery.currentXP += finalXPGained - actualXPGained;
        latestEntry['xpGained'] = finalXPGained;
      }
      
      _xpGainedPerWord[card.id] = finalXPGained;
      
      final hintText = hintsUsed > 0 ? " (with ${hintsUsed} hint(s), penalty applied)" : "";
      print('🔍 WordScrambleView: Awarded $finalXPGained XP to word "${card.word}"$hintText');
    } else {
      _xpGainedPerWord[card.id] = 0;
      print('🔍 WordScrambleView: 0 XP awarded to word "${card.word}" (Incorrect after $wrongAttempts attempts)');
    }
    
    _wordMastery[card.id] = card.learningMastery;
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
        title: 'Jumble',
        studiedWords: sessionStudiedWords,
        xpGainedPerWord: sessionXpGainedPerWord,
        wordMastery: sessionWordMastery,
        initialHPPerWord: sessionInitialHPPerWord,
        correctAnswers: _correctAnswers,
        totalQuestions: _totalAnswered,
        onStudyAgain: () {
          setState(() {
            _currentIndex = 0;
            _correctAnswers = 0;
            _totalAnswered = 0;
            _showingResults = false;
            _hasShownResults = false;
            _answered = false;
            _correctWord = '';
            _scrambledLetters.clear();
            _userAnswer.clear();
            _originalLetters.clear();
            _isCardFlipped = false;
            _gameSession.reset();
            _currentCards.shuffle(Random());
            if (_useLivesMode) {
              _lives = _maxLives;
            }
            _answeredQuestions.clear();
            _correctAnswersMap.clear();
            _correctWords.clear();
            _scrambledLettersMap.clear();
            _questionModes.clear();
            _xpGainedPerWord.clear();
            _wordMastery.clear();
            _studiedWords.clear();
            _initialHPPerWord.clear();
            _hpPenaltyAppliedWordIds.clear();
            _hintCount.clear();
            _hintRevealed.clear();
            _reviewCards.clear();
          });
          _generateQuestion();
          Navigator.of(context).pop();
        },
        onShuffle: () {
          Navigator.of(context).pop();
          _shuffleAndRestart();
        },
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
    }

  void _shuffleAndRestart() {
    final provider = context.read<FlashcardProvider>();
    
    // Get all cards from the same decks as the original cards
    Set<String> originalDeckIds = {};
    for (final card in widget.cards) {
      originalDeckIds.addAll(card.deckIds);
    }
    
    List<FlashCard> allDeckCards = [];
    Set<String> seenCardIds = {};
    
    if (originalDeckIds.isEmpty) {
      // If no specific decks, get all cards
      allDeckCards = provider.cards;
    } else {
      for (final deckId in originalDeckIds) {
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
    
    // Filter cards that can be studied today (have HP remaining)
    final availableCards = allDeckCards.where((card) => card.canBeStudiedToday).toList();
    
    if (availableCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available for study today.')),
      );
      return;
    }
    
    // Shuffle and take a reasonable number of cards (similar to original)
    availableCards.shuffle();
    final cardCount = availableCards.length >= 10 ? 10 : availableCards.length;
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
      
      // Reset hint tracking
      _hintCount.clear();
      _hintRevealed.clear();
      
      // Reset review tracking
      _reviewCards.clear();
    });
    
    _generateQuestion();
  }

  void _showReviewScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _WordScrambleReviewScreen(
          cards: widget.cards,
          answeredQuestions: _answeredQuestions,
          correctAnswersMap: _correctAnswersMap,
          correctWords: _correctWords,
          scrambledLettersMap: _scrambledLettersMap,
          questionModes: _questionModes,
          hintUsed: _hintCount.map((key, value) => MapEntry(key, value > 0)),
          hintRevealed: _hintRevealed.map((key, value) => MapEntry(key, value.join(', '))),
          xpGainedPerWord: _xpGainedPerWord,
        ),
      ),
    );
  }

  Widget _buildCustomHeaderResults(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            'Scramble Complete',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        
        // Left side - Back button with proper padding
        Positioned(
          left: 16, // Add proper padding from left edge
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
        ),
      ],
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
}

class _WordScrambleReviewScreen extends StatefulWidget {
  final List<FlashCard> cards;
  final Map<int, List<String>> answeredQuestions;
  final Map<int, bool> correctAnswersMap;
  final Map<int, String> correctWords;
  final Map<int, List<String>> scrambledLettersMap;
  final Map<int, bool> questionModes;
  final Map<int, bool> hintUsed;
  final Map<int, String> hintRevealed;
  final Map<String, int> xpGainedPerWord;

  const _WordScrambleReviewScreen({
    required this.cards,
    required this.answeredQuestions,
    required this.correctAnswersMap,
    required this.correctWords,
    required this.scrambledLettersMap,
    required this.questionModes,
    required this.hintUsed,
    required this.hintRevealed,
    required this.xpGainedPerWord,
  });

  @override
  State<_WordScrambleReviewScreen> createState() => _WordScrambleReviewScreenState();
}

class _WordScrambleReviewScreenState extends State<_WordScrambleReviewScreen> {
  int _currentReviewIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(
          child: Text('No questions to review'),
        ),
      );
    }

    final currentCard = widget.cards[_currentReviewIndex];
    final userAnswer = widget.answeredQuestions[_currentReviewIndex] ?? [];
    final isCorrect = widget.correctAnswersMap[_currentReviewIndex] ?? false;
    final correctWord = widget.correctWords[_currentReviewIndex] ?? '';
    final scrambledLetters = widget.scrambledLettersMap[_currentReviewIndex] ?? [];
    final isQuestionMode = widget.questionModes[_currentReviewIndex] ?? true;
    final hintWasUsed = widget.hintUsed[_currentReviewIndex] ?? false;
    final xpGained = widget.xpGainedPerWord[currentCard.id] ?? 0;

    final question = isQuestionMode ? currentCard.definition : currentCard.word;
    final answer = isQuestionMode ? currentCard.word : currentCard.definition;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Review (${_currentReviewIndex + 1}/${widget.cards.length})'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: LinearProgressIndicator(
              value: (_currentReviewIndex + 1) / widget.cards.length,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCorrect ? Colors.green : Colors.red,
              ),
            ),
          ),
          
          // Question and answer display
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Question card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Theme.of(context).colorScheme.surface 
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCorrect ? Colors.green : Colors.red,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Question:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          question,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Answer section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCorrect ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: isCorrect ? Colors.green : Colors.red,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isCorrect ? 'Correct!' : 'Incorrect',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isCorrect ? Colors.green : Colors.red,
                              ),
                            ),
                            const Spacer(),
                            if (hintWasUsed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'HINT USED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your answer:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userAnswer.join(''),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Correct answer:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          correctWord,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'XP Gained: $xpGained',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                ],
              ),
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _currentReviewIndex > 0 ? _previousQuestion : null,
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    label: const Text('Previous'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentReviewIndex > 0 ? Colors.blue : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _currentReviewIndex < widget.cards.length - 1 ? _nextQuestion : null,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentReviewIndex < widget.cards.length - 1 ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _previousQuestion() {
    if (_currentReviewIndex > 0) {
      setState(() {
        _currentReviewIndex--;
      });
    }
  }

  void _nextQuestion() {
    if (_currentReviewIndex < widget.cards.length - 1) {
      setState(() {
        _currentReviewIndex++;
      });
    }
  }
}