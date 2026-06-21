import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:async';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../services/sound_manager.dart';
import '../services/haptic_service.dart';
import '../providers/flashcard_provider.dart';

import '../utils/game_end_screen.dart';
import '../utils/card_color_utils.dart';
import '../services/xp_service.dart';
import '../components/main_header.dart';
import '../components/game_view_widgets.dart';
import 'add_card_view.dart';

class WritingView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final Function(bool)? onComplete;
  final bool shuffleMode;
  final bool startFlipped;
  final bool useLivesMode;
  final int? customLives;
  final bool useTimedMode;
  final int? timePerQuestion;
  final bool autoProgress;
  final int? shuffleQuestionOffset; // Offset for cumulative question count in shuffle mode
  final bool enableHints;
  final bool oneAnswerMode;

  const WritingView({
    super.key,
    required this.cards,
    required this.title,
    this.onComplete,
    this.shuffleMode = false,
    this.startFlipped = false,
    this.useLivesMode = false,
    this.customLives,
    this.useTimedMode = false,
    this.timePerQuestion,
    this.autoProgress = false,
    this.shuffleQuestionOffset,
    this.enableHints = true,
    this.oneAnswerMode = false,
  });

  @override
  State<WritingView> createState() => _WritingViewState();
}

class _WritingViewState extends State<WritingView> {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAttempts = 0;
  bool _showingResults = false;
  bool _hasShownResults = false; // Prevent multiple end screens
  bool _answered = false;
  String _correctAnswer = '';
  String _displayWord = '';
  bool _isQuestionMode = true; // true = definition to word, false = word to definition
  int _lives = 5;
  int _maxLives = 5;
  bool _useLivesMode = false;
  String _userAnswer = '';
  final TextEditingController _textController = TextEditingController();
  Map<String, int> _wrongAttemptsPerWord = {};
  Set<String> _guessedLetters = {};
  Set<String> _revealedLetters = {};
  Set<String> _hpDeductedWordIds = {};
  Set<int> _maxMistakeRevealQuestions = {};
  
  // Timer system
  Timer? _timer;
  int _timeRemaining = 0;
  int _totalTime = 0;
  bool _useTimedMode = false;
  
  // Auto progress system
  Timer? _autoProgressTimer;
  Set<int> _autoProgressedQuestions = {};
  
  // Track answered questions and their answers
  Map<int, String> _answeredQuestions = {}; // question index -> user answer
  Map<int, bool> _correctAnswersMap = {}; // question index -> is correct
  Map<int, String> _correctAnswersText = {}; // question index -> correct answer
  Map<int, bool> _questionModes = {}; // question index -> is question mode
  
  // Maintain our own copy of cards that can be updated
  late List<FlashCard> _currentCards;
  
  // RPG word progress tracking
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  Map<String, int> _initialHPPerWord = {}; // Track initial HP when word is first encountered
  List<FlashCard> _studiedWords = [];

  // Custom keyboard letters
  List<String> _keyboardLetters = [];

  // Hint and review tracking
  Map<int, int> _hintCount = {}; // question index -> number of hints used
  Map<int, String> _hintRevealed = {}; // question index -> revealed letters
  Set<String> _reviewCards = {}; // card IDs marked for review
  String? _hintStatusMessage;
  Timer? _hintStatusTimer;
  String? _reviewStatusMessage;
  Timer? _reviewStatusTimer;

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
      print('🔍 WritingView: Initialized with $_lives lives (max: $_maxLives)');
    } else {
      // Even if not using lives mode, initialize with default in case it's needed
      _maxLives = _getDefaultLives();
      _lives = _maxLives;
    }
    
    // Initialize timer if using timed mode
    _useTimedMode = widget.useTimedMode;
    if (_useTimedMode) {
      _totalTime = widget.timePerQuestion ?? _getDefaultTimePerQuestion();
      _timeRemaining = _totalTime;
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
    _textController.dispose();
    _timer?.cancel();
    _autoProgressTimer?.cancel();
    _hintStatusTimer?.cancel();
    _reviewStatusTimer?.cancel();
    
    // Remove listener when disposing
    final provider = context.read<FlashcardProvider>();
    provider.removeListener(_onProviderChanged);
    
    super.dispose();
  }

  int _getDefaultLives() {
    return 5; // Default 5 lives
  }
  
  int _getDefaultTimePerQuestion() {
    return 30; // Default 30 seconds per question
  }
  
  void _startTimer() {
    if (!_useTimedMode) return;
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeRemaining > 0) {
            _timeRemaining--;
          } else {
            _timer?.cancel();
            _handleTimeUp();
          }
        });
      }
    });
  }
  
  void _handleTimeUp() {
    if (_answered) return;
    
    final cardId = _currentCards[_currentIndex].id;
    _wrongAttemptsPerWord[cardId] = (_wrongAttemptsPerWord[cardId] ?? 0) + 1;
    
    if (widget.shuffleMode) {
      _finalizeIncorrectAnswer(revealAnswer: false, allowAutoProgress: false);
      if (mounted && widget.onComplete != null) {
        widget.onComplete!(false);
      }
      return;
    }
    
    _finalizeIncorrectAnswer();
    
    if (_useLivesMode) {
      _lives--;
      print('🔍 WritingView: Lost a life due to time up! Lives remaining: $_lives');
      
      if (_lives <= 0) {
        print('🔍 WritingView: Game over! No lives remaining');
        _showGameOverScreen();
      }
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
    
    // Update our current cards list
    setState(() {
      _currentCards = updatedCards;
      
      // If we're currently viewing a card that was updated, regenerate the question
      if (_currentIndex < _currentCards.length && !_showingResults) {
        _generateQuestion();
      }
    });
    
    print('🔍 WritingView: Refreshed cards from provider');
  }
  
  void _generateKeyboardLetters() {
    // Get unique letters from the correct answer
    final Set<String> answerLetters = {};
    for (int i = 0; i < _correctAnswer.length; i++) {
      final char = _correctAnswer[i];
      if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        answerLetters.add(char.toUpperCase());
      }
    }
    
    // Add some extra common letters to make the keyboard more useful
    final extraLetters = ['A', 'E', 'I', 'O', 'U', 'R', 'S', 'T', 'N', 'L', 'C', 'D', 'P', 'M', 'H', 'G', 'B', 'F', 'K', 'W', 'V', 'X', 'Y', 'Z', 'J', 'Q'];
    
    // Combine answer letters with some extra letters
    final Set<String> allLetters = {...answerLetters};
    
    // Add extra letters (but not too many to keep the keyboard manageable)
    final random = Random();
    final targetSize = answerLetters.length + 8; // Aim for answer letters + 8 extra
    
    while (allLetters.length < targetSize && extraLetters.isNotEmpty) {
      final randomIndex = random.nextInt(extraLetters.length);
      allLetters.add(extraLetters[randomIndex]);
      extraLetters.removeAt(randomIndex);
    }
    
    // Convert to list and shuffle
    _keyboardLetters = allLetters.toList()..shuffle(random);
  }
  
  void _generateQuestion() {
    if (_currentIndex >= _currentCards.length) {
      // Calculate success rate
      final successRate = _totalAttempts > 0 ? (_correctAnswers / _totalAttempts) : 0.0;
      final wasSuccessful = successRate >= 0.6; // 60% or higher is considered successful
      
      // In shuffle mode, call onComplete callback instead of showing results
      if (widget.shuffleMode && widget.onComplete != null) {
        widget.onComplete!(wasSuccessful);
        return;
      }
      
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

    // Reset hint and review state for new question
    _hintCount[_currentIndex] = 0;
    _hintRevealed[_currentIndex] = '';
  _hintStatusTimer?.cancel();
  _hintStatusMessage = null;
  _reviewStatusTimer?.cancel();
  _reviewStatusMessage = null;

    // Check if this question has already been answered
    if (_answeredQuestions.containsKey(_currentIndex)) {
      // Load existing question data
      _isQuestionMode = _questionModes[_currentIndex]!;
      _correctAnswer = _correctAnswersText[_currentIndex]!;
      _userAnswer = _answeredQuestions[_currentIndex]!;
      _answered = true;
      _textController.text = _userAnswer;
      
      // Regenerate keyboard letters for this question
      _generateKeyboardLetters();
      
      // Reconstruct the letter tracking sets based on the stored answer
      _guessedLetters.clear();
      _revealedLetters.clear();
      
      // If the question was answered correctly, all letters should be revealed
      if (_correctAnswersMap[_currentIndex] == true) {
        for (int i = 0; i < _correctAnswer.length; i++) {
          final char = _correctAnswer[i];
          if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
            _revealedLetters.add(char.toUpperCase());
          }
        }
      } else {
        // If answered incorrectly, we need to determine which letters were guessed
        // For now, we'll show the complete answer since we don't track individual guesses
        for (int i = 0; i < _correctAnswer.length; i++) {
          final char = _correctAnswer[i];
          if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
            _revealedLetters.add(char.toUpperCase());
          }
        }
      }
      
      // Show the complete answer
      _displayWord = _correctAnswer;
      
      return;
    }

    final currentCard = _currentCards[_currentIndex];
    final random = Random();
    
    // Choose question mode based on flipped mode settings
    _isQuestionMode = !widget.startFlipped; // Use flipped mode setting
    
    // Get correct answer
    _correctAnswer = _isQuestionMode ? currentCard.word : currentCard.definition;
    
    // Clear letter tracking sets FIRST to prevent any prefilling
    _guessedLetters.clear();
    _revealedLetters.clear();
    
    // Generate custom keyboard letters
    _generateKeyboardLetters();
    
    // Initialize display word with underscores
    _updateDisplayWord();
    
    // Store question data for future reference
    _correctAnswersText[_currentIndex] = _correctAnswer;
    _questionModes[_currentIndex] = _isQuestionMode;
    
    setState(() {
      _answered = false;
      _userAnswer = '';
      _textController.clear();
    });
    
    // Start timer if using timed mode
    if (_useTimedMode) {
      _timeRemaining = _totalTime;
      _startTimer();
    }
  }

  Color _getCardBorderColor(FlashCard card) {
    return CardColorUtils.getBorderColor(card);
  }

  void _applyHpLoss(FlashCard card, bool wasCorrect) {
    if (_hpDeductedWordIds.contains(card.id)) return;
    _hpDeductedWordIds.add(card.id);
    if (wasCorrect) {
      card.markCorrect(GameDifficulty.medium);
    } else {
      card.markIncorrect(GameDifficulty.medium);
    }
    _updateCardInProvider(card);
  }

  void _finalizeIncorrectAnswer({bool revealAnswer = true, bool allowAutoProgress = true}) {
    if (_answered) return;
    final card = _currentCards[_currentIndex];

    setState(() {
      _answered = true;
      _totalAttempts++;
      _correctAnswersMap[_currentIndex] = false;
      _answeredQuestions[_currentIndex] = revealAnswer ? _correctAnswer : _displayWord;
      _correctAnswersText[_currentIndex] = _correctAnswer;
      _questionModes[_currentIndex] = _isQuestionMode;

      if (revealAnswer) {
        _displayWord = _correctAnswer;
        // Reveal every alphabetical character
        for (int i = 0; i < _correctAnswer.length; i++) {
          final char = _correctAnswer[i];
          if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
            _revealedLetters.add(char.toUpperCase());
          }
        }
      }
    });

    if (!widget.shuffleMode) {
      _awardXPToWord(card, false);
    }
    _applyHpLoss(card, false);

    if (_useTimedMode) {
      _timer?.cancel();
    }

    if (allowAutoProgress && widget.autoProgress && !widget.shuffleMode) {
      _autoProgressTimer?.cancel();
      _autoProgressTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted && _currentIndex < _currentCards.length - 1) {
          _autoProgressedQuestions.add(_currentIndex);
          _goToNextQuestion();
        }
      });
    }
  }

  void _guessLetter(String letter) {
    if (_answered) return;
    
    final cardId = _currentCards[_currentIndex].id;
    final wrongAttempts = _wrongAttemptsPerWord[cardId] ?? 0;
    if (wrongAttempts >= 5) return;
    
    final upperLetter = letter.toUpperCase();
    final lowerLetter = letter.toLowerCase();
    
    // Check if letter was already guessed
    if (_guessedLetters.contains(upperLetter) || _revealedLetters.contains(upperLetter)) {
      return;
    }
    
    setState(() {
      _guessedLetters.add(upperLetter);
      
      // Check if letter is in the word
      if (_correctAnswer.toLowerCase().contains(lowerLetter)) {
        // Correct guess - reveal all instances of this letter
        _revealedLetters.add(upperLetter);
        HapticService().successFeedback();
        
        // Update display word
        _updateDisplayWord();
        
        // Check if word is complete
        if (_isWordComplete()) {
          _answered = true;
          _correctAnswers++;
          _totalAttempts++;
          _correctAnswersMap[_currentIndex] = true;
          _answeredQuestions[_currentIndex] = _displayWord;
          _correctAnswersText[_currentIndex] = _correctAnswer;
          _questionModes[_currentIndex] = _isQuestionMode;
          
          // Sound for word completion as requested
          SoundManager().playCorrectSound();
          
          // In shuffle mode, reduce HP immediately for every answer attempt
          // (XP tracking is handled by shuffle view at completion)
          if (widget.shuffleMode) {
            _applyHpLoss(_currentCards[_currentIndex], true);
          } else {
            // In standalone mode, handle full tracking
            _awardXPToWord(_currentCards[_currentIndex], true);
            _applyHpLoss(_currentCards[_currentIndex], true);
          }
          
          // Stop timer if using timed mode
          if (_useTimedMode) {
            _timer?.cancel();
          }
          
          // Auto progress logic
          if (widget.autoProgress && !widget.shuffleMode) {
            _autoProgressTimer?.cancel();
            _autoProgressTimer = Timer(const Duration(milliseconds: 800), () {
              if (mounted && _currentIndex < _currentCards.length - 1) {
                _autoProgressedQuestions.add(_currentIndex);
                _goToNextQuestion();
              }
            });
          }
          
          // In shuffle mode, don't auto-continue - let user click next/finish button
          // The button will call onComplete when clicked
        }
      } else {
        // Wrong guess
        if (_useLivesMode) {
          _lives--;
          print('🔍 WritingView: Lost a life! Lives remaining: $_lives');
        }
        HapticService().errorFeedback();
        
        final updatedAttempts = (_wrongAttemptsPerWord[cardId] ?? 0) + 1;
        _wrongAttemptsPerWord[cardId] = updatedAttempts;
        
        // In standalone mode, if oneAnswerMode is enabled, any wrong letter ends the question
        if (widget.oneAnswerMode) {
          // Force wrong attempts to 5 for XP penalty consistency
          _wrongAttemptsPerWord[cardId] = 5;
          
          // Sound for 1-click failure
          SoundManager().playWrongSound();
          _finalizeIncorrectAnswer();
          
          // In shuffle mode, complete immediately on failure if oneAnswerMode is ON
          if (widget.shuffleMode && mounted && widget.onComplete != null) {
            widget.onComplete!(false);
          }
          return;
        }

        // Multiple attempts mode (1-click answer OFF)
        if (updatedAttempts >= 5) {
          _maxMistakeRevealQuestions.add(_currentIndex);
          
          // Sound for max attempts exhausted
          SoundManager().playWrongSound();
          _finalizeIncorrectAnswer();
          
          // In shuffle mode, only complete after the 5th wrong attempt
          if (widget.shuffleMode && mounted && widget.onComplete != null) {
            widget.onComplete!(false);
          }
          return;
        }
        
        // Check if game over (only if using lives mode in standalone)
        if (_useLivesMode && _lives <= 0) {
          // Sound for game over (runs on final mistake)
          SoundManager().playWrongSound();
          _finalizeIncorrectAnswer(allowAutoProgress: false);
          print('🔍 WritingView: Game over! No lives remaining');
          
          // In shuffle mode, complete immediately on life depletion
          if (widget.shuffleMode && mounted && widget.onComplete != null) {
            widget.onComplete!(false);
            return;
          }
          
          _showGameOverScreen();
          return;
        }
      }
    });
  }
  
  void _updateDisplayWord() {
    String newDisplay = '';
    for (int i = 0; i < _correctAnswer.length; i++) {
      final char = _correctAnswer[i];
      if (char == ' ') {
        newDisplay += ' '; // Keep spaces as spaces
      } else {
        final upperChar = char.toUpperCase();
        if (_revealedLetters.contains(upperChar) || _guessedLetters.contains(upperChar)) {
          newDisplay += char; // Show revealed/guessed letters
        } else if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
          newDisplay += '_'; // Show underscore for unguessed letters
        } else {
          newDisplay += char; // Keep punctuation and other characters
        }
      }
    }
    _displayWord = newDisplay;
  }
  
  bool _isWordComplete() {
    for (int i = 0; i < _correctAnswer.length; i++) {
      final char = _correctAnswer[i];
      if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        final upperChar = char.toUpperCase();
        if (!_revealedLetters.contains(upperChar) && !_guessedLetters.contains(upperChar)) {
          return false; // Found an unguessed letter
        }
      }
    }
    return true; // All letters have been guessed
  }

  Future<void> _updateCardInProvider(FlashCard card) async {
    try {
      final provider = context.read<FlashcardProvider>();
      
      // Update the card in the provider to save the XP changes
      await provider.updateCard(card);
      print('🔍 WritingView: Updated card "${card.word}" in provider - current XP: ${card.learningMastery.currentXP}');
      
    } catch (e) {
      print('🔍 WritingView: Error updating card in provider: $e');
    }
  }


  void _goToPreviousQuestion() {
    // Only allow navigation if the question is answered
    if (!_answered) return;
    
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _generateQuestion();
    }
  }

  void _goToNextQuestion() {
    // Only allow navigation if the question is answered
    if (!_answered) return;
    
    // In shuffle mode, we only have one question, so call the callback immediately
    if (widget.shuffleMode) {
      final successRate = _totalAttempts > 0 ? (_correctAnswers / _totalAttempts) : 0.0;
      final wasSuccessful = successRate >= 0.6; // 60% or higher is considered successful
      if (widget.onComplete != null) {
        widget.onComplete!(wasSuccessful);
      }
      return;
    }
    
    if (_currentIndex < _currentCards.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _generateQuestion();
    } else {
      // On last question, show results
      setState(() {
        _showingResults = true;
      });
      // Play completion sound when test is finished
      SoundManager().playCompleteSound();
    }
  }

  void _finishGame() {
    // Only allow finishing if the question is answered
    if (!_answered) return;
    
    // Check if in shuffle mode
    final successRate = _totalAttempts > 0 ? (_correctAnswers / _totalAttempts) : 0.0;
    final wasSuccessful = successRate >= 0.6; // 60% or higher is considered successful
    
    if (widget.shuffleMode && widget.onComplete != null) {
      widget.onComplete!(wasSuccessful);
      return;
    }
    
    // Play completion sound when test is finished
    SoundManager().playCompleteSound();
    
    // Go directly to word progress
    _showWordProgress();
  }





  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('No cards available for writing'),
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
            title: 'Write',
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
          
          // Scrollable play area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Question text above card
                  Text(
                    'Write the translation for',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Card with white background and colored outline
                  // Card display with hint and review icons
                  Stack(
                    children: [
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
                            _isQuestionMode ? currentCard.definition : currentCard.word,
                            style: TextStyle(
                              fontSize: 32,
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
                  
                  const SizedBox(height: 16),
                  
                  // Navigation buttons (always visible, greyed out when not available)
                  const SizedBox(height: 16),
                  
                // Display word with interactive letter trays
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _displayWord.split('').asMap().entries.map((entry) {
                          final idx = entry.key;
                          final char = entry.value;
                          final isFilled = char != '_' && char != ' ';
                          final isCorrect = _correctAnswer.isNotEmpty && idx < _correctAnswer.length && 
                                          char.toLowerCase() == _correctAnswer[idx].toLowerCase();

                          return AnimatedScale(
                            scale: isFilled ? 1.05 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 30,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isFilled 
                                    ? (isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1))
                                    : Theme.of(context).colorScheme.surface,
                                border: Border.all(
                                  color: isFilled 
                                      ? (isCorrect ? Colors.green : Colors.red)
                                      : Colors.grey.shade400,
                                  width: isFilled ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: isFilled ? [
                                  BoxShadow(
                                    color: (isCorrect ? Colors.green : Colors.red).withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ] : [],
                              ),
                              child: Center(
                                child: Text(
                                  char,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isFilled 
                                        ? (isCorrect ? Colors.green.shade700 : Colors.red.shade700)
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                  
                if (_answered && (_correctAnswersMap[_currentIndex] ?? false)) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Correct! The answer is: ${_correctAnswer.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else if (_maxMistakeRevealQuestions.contains(_currentIndex) || (_answered && !(_correctAnswersMap[_currentIndex] ?? false))) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'The answer is: ${_correctAnswer.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else if (!_answered) ...[
                  // Show attempts remaining UI
                  Builder(
                    builder: (context) {
                      final cardId = _currentCards[_currentIndex].id;
                      final wrongAttempts = _wrongAttemptsPerWord[cardId] ?? 0;
                      
                      // In Single Attempt mode, we only show it after the first mistake (which fails it)
                      // In Multiple Attempt mode, we show the countdown
                      if (widget.oneAnswerMode) {
                        return const SizedBox.shrink();
                      } else {
                        return Column(
                          children: [
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                wrongAttempts == 0 
                                    ? 'Enter letters (5 attempts allowed)'
                                    : 'Incorrect, try again ($wrongAttempts/5 attempts)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: wrongAttempts == 0 ? Colors.grey : Colors.red,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
                
                  const SizedBox(height: 20),
                  
                  // Letter keyboard placed HERE (above footer) when not answered
                  if (!_answered) _buildCustomKeyboard(),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildUnifiedFooter(),
    );
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
                onPressed: (_answered && _currentIndex > 0) ? _goToPreviousQuestion : null,
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                label: const Text('Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_answered && _currentIndex > 0) ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                  foregroundColor: (_answered && _currentIndex > 0) 
                      ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87) 
                      : Colors.grey,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: (_answered && _currentIndex > 0) ? Colors.grey[300]! : Colors.transparent),
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
                onPressed: _answered ? (_currentIndex == _currentCards.length - 1 ? _finishGame : _goToNextQuestion) : null,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(_currentIndex == _currentCards.length - 1 ? 'Finish' : 'Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _answered ? Colors.green : Colors.grey.withValues(alpha: 0.1),
                  foregroundColor: _answered ? Colors.white : Colors.grey,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _answered ? Colors.transparent : Colors.grey[300]!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _currentIndex / _currentCards.length;
    
    // In shuffle mode, show cumulative question count (e.g., 1/1, 2/2, 3/3...)
    final String questionCountText;
    if (widget.shuffleMode && widget.shuffleQuestionOffset != null) {
      final currentQuestionNum = (widget.shuffleQuestionOffset ?? 0) + _currentIndex + 1;
      questionCountText = '$currentQuestionNum/$currentQuestionNum';
    } else {
      questionCountText = '${_currentIndex + 1}/${_currentCards.length}';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              // Left: Card count
              Expanded(
                child: Text(
                  questionCountText,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              
              // Middle: Status indicators
              if (_useLivesMode || _useTimedMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_useLivesMode) ...[
                        GameLivesIndicator(lives: _lives, maxLives: _maxLives),
                        if (_useTimedMode) const SizedBox(width: 8),
                      ],
                      if (_useTimedMode) GameTimerIndicator(timeRemaining: _timeRemaining, totalTime: _totalTime),
                    ],
                  ),
                ),
              
              // Right side: Accuracy
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

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Writing Test'),
        content: const Text('Are you sure you want to exit? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Exit'),
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
        content: const Text('Are you sure you want to return to the home screen? This will end your current writing test.'),
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
  
  void _awardXPToWord(FlashCard card, bool isCorrect) {
    final xpService = XpService();
    
    // Track studied words and initial HP BEFORE processing (so we capture HP before it's reduced)
    if (!_studiedWords.any((word) => word.id == card.id)) {
      _studiedWords.add(card);
      // Store initial HP when word is first encountered (BEFORE HP is reduced)
      _initialHPPerWord[card.id] = card.currentHP;
    }
    
    print('🔍 WritingView: About to process word "${card.word}" - daily attempts before: ${card.learningMastery.dailyAttemptsDebug}');
    
    if (isCorrect) {
      // Award XP for correct answers (this also records the attempt)
      xpService.addXPToWord(card.learningMastery, "writing", 1);
      
      // Get the actual XP gained (after diminishing returns)
      final actualXPGained = card.learningMastery.exerciseHistory.isNotEmpty 
          ? card.learningMastery.exerciseHistory.last['xpGained'] as int 
          : 0;
      
      // Reduce XP based on number of hints used (50% per hint, minimum 10% of original)
      final hintCount = _hintCount[_currentIndex] ?? 0;
      final hintPenalty = hintCount > 0 ? (0.5 * hintCount).clamp(0.0, 0.9) : 0.0;
      int finalXPGained = hintCount > 0 
          ? (actualXPGained * (1.0 - hintPenalty)).round().clamp(1, actualXPGained)
          : actualXPGained;
      
      // Apply -1 XP for each incorrect letter attempt (up to the available XP)
      final wrongAttempts = _wrongAttemptsPerWord[card.id] ?? 0;
      if (wrongAttempts > 0) {
        finalXPGained = (finalXPGained - wrongAttempts).clamp(0, finalXPGained).toInt();
      }
      
      if (card.learningMastery.exerciseHistory.isNotEmpty) {
        final entry = card.learningMastery.exerciseHistory.last;
        final recordedXp = entry['xpGained'] as int? ?? 0;
        if (recordedXp != finalXPGained) {
          card.learningMastery.currentXP += finalXPGained - recordedXp;
          entry['xpGained'] = finalXPGained;
        }
      }
      
      // Track XP gained for this word in this session (add for multiple appearances in same session)
      _xpGainedPerWord[card.id] = finalXPGained;
      
      final hintText = hintCount > 0 ? " (with ${hintCount} hint(s), penalty applied)" : "";
      final wrongText = wrongAttempts > 0 ? ", $wrongAttempts wrong letter${wrongAttempts == 1 ? '' : 's'}" : "";
      print('🔍 WritingView: Awarded $finalXPGained XP to word "${card.word}" (base: $actualXPGained$hintText$wrongText) - daily attempts after: ${card.learningMastery.dailyAttemptsDebug}');
    } else {
      _xpGainedPerWord[card.id] = 0;
      _wordMastery[card.id] = card.learningMastery;
      return;
    }
    
    // Hint Penalty: usage also affects the overall session accuracy
    final hintCount = _hintCount[_currentIndex] ?? 0;
    if (hintCount > 0) {
      // simulate extra "attempts" so the final session summary % is lowered
      _totalAttempts += (hintCount * 0.5).ceil().toInt();
    }

    // Store the word mastery for display (for both correct and incorrect)
    _wordMastery[card.id] = card.learningMastery;
    
    // Track studied words (regardless of correctness)
    if (!_studiedWords.any((word) => word.id == card.id)) {
      _studiedWords.add(card);
    }
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
      _totalAttempts = 0;
      _showingResults = false;
      _hasShownResults = false;
      _answered = false;
      _lives = 5;
      _userAnswer = '';
      _textController.clear();
      _guessedLetters.clear();
      _revealedLetters.clear();
      
      // Reset all navigation state
      _answeredQuestions.clear();
      _correctAnswersMap.clear();
      _correctAnswersText.clear();
      _questionModes.clear();
      
      // Reset RPG tracking
      _xpGainedPerWord.clear();
      _wordMastery.clear();
      _studiedWords.clear();
      _initialHPPerWord.clear();
      _wrongAttemptsPerWord.clear();
      _hpDeductedWordIds.clear();
      _maxMistakeRevealQuestions.clear();
      _maxMistakeRevealQuestions.clear();
      _initialHPPerWord.clear();
      _wrongAttemptsPerWord.clear();
      _hpDeductedWordIds.clear();
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
        title: 'Write',
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
            _lives = 5;
            _userAnswer = '';
            _textController.clear();
            _guessedLetters.clear();
            _revealedLetters.clear();
            _answeredQuestions.clear();
            _correctAnswersMap.clear();
            _correctAnswersText.clear();
            _questionModes.clear();
            _xpGainedPerWord.clear();
            _wordMastery.clear();
            _studiedWords.clear();
            _initialHPPerWord.clear();
            _wrongAttemptsPerWord.clear();
            _hpDeductedWordIds.clear();
          });
          _generateQuestion();
        },
        onShuffle: (available) {
          Navigator.of(context).pop();
          setState(() {
            _currentCards = List.from(available)..shuffle();
          });
          _shuffleAndRestart();
        },
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }
  
  Widget _buildCustomKeyboard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Keyboard title
          Text(
            _answered ? 'Final answer' : 'Tap letters to guess',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          
          // Keyboard grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _keyboardLetters.map((letter) {
              final isGuessed = _guessedLetters.contains(letter);
              final isRevealed = _revealedLetters.contains(letter);
              final isInAnswer = _correctAnswer.toUpperCase().contains(letter);
              
              Color buttonColor;
              Color textColor;
              
              if (_answered) {
                // Question is answered - show final state
                if (isInAnswer) {
                  // Letter is in the answer - green
                  buttonColor = Colors.green;
                  textColor = Colors.white;
                } else {
                  // Letter is not in the answer - grey
                  buttonColor = Colors.grey.withValues(alpha: 0.3);
                  textColor = Colors.grey.shade600;
                }
              } else if (isRevealed) {
                // Correct guess - green
                buttonColor = Colors.green;
                textColor = Colors.white;
              } else if (isGuessed) {
                // Wrong guess - red
                buttonColor = Colors.red;
                textColor = Colors.white;
              } else {
                // Not guessed yet - default
                buttonColor = Theme.of(context).colorScheme.surfaceVariant;
                textColor = Theme.of(context).colorScheme.onSurface;
              }
              
              return GestureDetector(
                onTap: () {
                  if (!isGuessed && !isRevealed && !_answered) {
                    _guessLetter(letter);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
    final canUseHint = _canUseHint();
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
        GestureDetector(
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
      ],
    );
  }

  bool _canUseHint() {
    if (_answered) return false;
    
    final correctAnswer = _correctAnswer;
    if (correctAnswer.isEmpty) return false;
    
    // Count how many letters are already revealed
    int revealedCount = 0;
    for (int i = 0; i < correctAnswer.length; i++) {
      final char = correctAnswer[i];
      if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        final upperChar = char.toUpperCase();
        if (_revealedLetters.contains(upperChar)) {
          revealedCount++;
        }
      }
    }
    
    // Can use hint if not all letters are revealed (except the last one)
    final totalLetters = correctAnswer.split('').where((char) => RegExp(r'[a-zA-Z]').hasMatch(char)).length;
    return revealedCount < totalLetters - 1;
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
          setState(() => _reviewStatusMessage = null);
        }
      });
    } catch (e) {
      print('🔍 WritingView: Error toggling review card: $e');
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
    if (!_canUseHint()) return;
    
    final correctAnswer = _correctAnswer;
    
    if (correctAnswer.isEmpty) return;
    
    // Find all unrevealed letters
    List<String> unrevealedLetters = [];
    for (int i = 0; i < correctAnswer.length; i++) {
      final char = correctAnswer[i];
      if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        final upperChar = char.toUpperCase();
        if (!_revealedLetters.contains(upperChar) && !_guessedLetters.contains(upperChar)) {
          if (!unrevealedLetters.contains(upperChar)) {
            unrevealedLetters.add(upperChar);
          }
        }
      }
    }
    
    if (unrevealedLetters.isNotEmpty) {
      final nextLetter = unrevealedLetters[Random().nextInt(unrevealedLetters.length)];
      
      setState(() {
        // Increment hint count
        _totalAttempts++;
        _hintCount[_currentIndex] = (_hintCount[_currentIndex] ?? 0) + 1;
        
        // Add the letter to revealed letters
        _revealedLetters.add(nextLetter);
        
        // Update the display word to show the revealed letter
        _updateDisplayWord();
        
        // Check if word is complete after hint
        if (_isWordComplete()) {
          _answered = true;
          _correctAnswers++;
          _totalAttempts++;
          _correctAnswersMap[_currentIndex] = true;
          _answeredQuestions[_currentIndex] = _displayWord;
          
          // In shuffle mode, reduce HP immediately for every answer attempt
          // (XP tracking is handled by shuffle view at completion)
          if (widget.shuffleMode) {
            _currentCards[_currentIndex].markCorrect(GameDifficulty.medium);
            // markCorrect already adds to exerciseHistory, reducing HP
            _updateCardInProvider(_currentCards[_currentIndex]);
          } else {
            // In standalone mode, handle full tracking
            _awardXPToWord(_currentCards[_currentIndex], true);
            _updateCardInProvider(_currentCards[_currentIndex]);
          }
          
          // In shuffle mode, don't auto-continue - let user click next/finish button
          // The button will call onComplete when clicked
        }
      });
      
      // Show feedback near hint button
      _hintStatusTimer?.cancel();
      setState(() {
        _hintStatusMessage = 'Hint used';
      });
      _hintStatusTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _hintStatusMessage = null);
        }
      });
    }
  }

  void _showGameOverScreen() {
    // Show results when game is over
    setState(() {
      _showingResults = true;
    });
    // Play completion sound when game is over
    SoundManager().playCompleteSound();
  }

}