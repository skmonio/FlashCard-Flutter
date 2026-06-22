import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../providers/user_profile_provider.dart';
import '../utils/game_difficulty_helper.dart';
import '../utils/card_color_utils.dart';
import '../utils/game_end_screen.dart';
import '../utils/sentence_utils.dart';
import 'add_card_view.dart';

class SentenceBuildingView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final Function(bool)? onComplete;
  final bool shuffleMode;
  final bool startFlipped;
  final bool autoProgress;
  final bool useLivesMode;
  final int? customLives;
  final bool oneAnswerMode;
  final bool enableHints;
  final bool useTimedMode;
  final dynamic timedDifficulty; // Using dynamic to avoid import if needed, or import TimedDifficulty

  const SentenceBuildingView({
    super.key,
    required this.cards,
    required this.title,
    this.onComplete,
    this.shuffleMode = false,
    this.startFlipped = false,
    this.autoProgress = false,
    this.useLivesMode = false,
    this.customLives,
    this.oneAnswerMode = true,
    this.enableHints = true,
    this.useTimedMode = false,
    this.timedDifficulty,
  });

  @override
  State<SentenceBuildingView> createState() => _SentenceBuildingViewState();
}

class _SentenceBuildingViewState extends State<SentenceBuildingView> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAttempts = 0;
  bool _showingResults = false;
  bool _hasShownResults = false;
  bool _answered = false;
  String _correctSentence = '';
  List<String> _availableWords = [];
  List<String> _userAnswer = [];
  bool _isQuestionMode = true; // true = original to translation, false = translation to original
  final GameSession _gameSession = GameSession();
  
  late List<FlashCard> _currentCards;
  
  // Track answered questions
  Map<int, List<String>> _answeredQuestions = {};
  Map<int, bool> _correctAnswersMap = {};
  Map<int, String> _correctSentences = {};
  Map<int, List<String>> _availableWordsMap = {};
  Map<int, bool> _questionModes = {};
  Set<int> _autoProgressedQuestions = {};
  int _activeQuestionIndex = 0;
  
  Timer? _autoProgressTimer;
  int _lives = 0;
  int _maxLives = 0;
  bool _useLivesMode = false;
  
  // Timed mode
  Timer? _timer;
  int _timeRemaining = 0;
  int _totalTime = 0;
  bool _useTimedMode = false;
  bool _timeUp = false;
  
  // XP & Progress
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  Map<String, int> _initialHPPerWord = {};
  List<FlashCard> _studiedWords = [];
  Set<String> _hpPenaltyAppliedWordIds = {};
  
  // Hint system
  Map<int, int> _hintCount = {};
  Map<int, Set<int>> _lockedPositions = {};
  String? _hintStatusMessage;
  Timer? _hintStatusTimer;
  
  // Animations
  late AnimationController _shakeController;
  late AnimationController _successController;
  late AnimationController _dealController;
  int _consecutiveCorrect = 0;
  
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;
  bool _isShowingWrongAnswer = false;
  Map<int, int> _wrongAttempts = {};

  @override
  void initState() {
    super.initState();
    _currentCards = List<FlashCard>.from(widget.cards);
    _useLivesMode = widget.useLivesMode;
    if (_useLivesMode) {
      _maxLives = widget.customLives ?? 2;
      _lives = _maxLives;
    }
    
    _useTimedMode = widget.useTimedMode;
    if (_useTimedMode && widget.timedDifficulty != null) {
      _timeRemaining = GameDifficultyHelper.getTimeForDifficulty(widget.timedDifficulty);
      _totalTime = _timeRemaining;
      _startTimer();
    }
    
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
  }

  @override
  void dispose() {
    _autoProgressTimer?.cancel();
    _hintStatusTimer?.cancel();
    _timer?.cancel();
    _shakeController.dispose();
    _successController.dispose();
    _dealController.dispose();
    super.dispose();
  }

  void _generateQuestion() {
    if (_currentIndex >= _currentCards.length) {
      _awardXp();
      if (widget.onComplete != null) {
        final successRate = _totalAttempts > 0 ? (_correctAnswers / _totalAttempts) : 0.0;
        widget.onComplete!(successRate >= 0.6);
        return;
      }
      setState(() {
        _showingResults = true;
      });
      return;
    }

    if (_answeredQuestions.containsKey(_currentIndex)) {
      _isQuestionMode = _questionModes[_currentIndex]!;
      _correctSentence = _correctSentences[_currentIndex]!;
      _availableWords = List<String>.from(_availableWordsMap[_currentIndex]!);
      _userAnswer = List<String>.from(_answeredQuestions[_currentIndex]!);
      _answered = true;
      return;
    }

    final currentCard = _currentCards[_currentIndex];
    
    // Flipped mode: true = Show English example translation, build Dutch example
    //               false = Show Dutch example, build English example translation
    _isQuestionMode = widget.startFlipped; 
    
    if (_isQuestionMode) {
      // Build Dutch sentence
      _correctSentence = currentCard.example;
    } else {
      // Build English translation
      _correctSentence = currentCard.exampleTranslation;
    }
    
    // Normalize words: lowercase and remove trailing punctuation from each word
    final rawWords = _correctSentence.split(' ').where((w) => w.trim().isNotEmpty).toList();
    final words = rawWords.map((w) => w.toLowerCase().replaceAll(RegExp(r'[.!?]$'), '')).toList();
    _availableWords = List<String>.from(words)..shuffle();
    
    _correctSentence = words.join(' '); // Store joined normalized version for hint matching
    _correctSentences[_currentIndex] = _correctSentence;
    _availableWordsMap[_currentIndex] = List<String>.from(_availableWords);
    _questionModes[_currentIndex] = _isQuestionMode;
    
    setState(() {
      _answered = false;
      _userAnswer = [];
      _isShowingWrongAnswer = false;
      _hintStatusMessage = null;
      if (!_answeredQuestions.containsKey(_currentIndex)) {
        _wrongAttempts[_currentIndex] = 0;
      }
      _lockedPositions[_currentIndex] = <int>{};
    });
    
    if (_useTimedMode) {
      _startTimer();
    }
  }

  void _addWord(String word) {
    if (_answered || word.isEmpty) return;
    
    setState(() {
      _userAnswer.add(word);
      _availableWords.remove(word);
    });
    
    if (_availableWords.isEmpty) {
      _checkAnswer();
    }
  }

  void _removeWordAt(int index) {
    if (_answered || index < 0 || index >= _userAnswer.length) return;
    
    final lockedPositions = _lockedPositions[_currentIndex] ?? <int>{};
    if (lockedPositions.contains(index)) return;
    
    setState(() {
      final removedWord = _userAnswer.removeAt(index);
      _availableWords.add(removedWord);
      
      final newLockedPositions = <int>{};
      for (final lockedIndex in lockedPositions) {
        if (lockedIndex > index) {
          newLockedPositions.add(lockedIndex - 1);
        } else if (lockedIndex < index) {
          newLockedPositions.add(lockedIndex);
        }
      }
      _lockedPositions[_currentIndex] = newLockedPositions;
    });
  }

  void _checkAnswer() {
    if (_answered || _userAnswer.isEmpty || _isShowingWrongAnswer) return;
    
    _timer?.cancel();
    
    final correctWords = _correctSentence.split(' ').where((w) => w.trim().isNotEmpty).toList();
    final isCorrect = listEquals(_userAnswer, correctWords);
    final currentCard = _currentCards[_currentIndex];
    
    if (isCorrect) {
      _handleCorrectAnswer(currentCard);
    } else {
      _handleWrongAnswer(currentCard);
    }
  }

  void _handleCorrectAnswer(FlashCard card) {
    XpService.recordAnswer(_gameSession, true);
    _applyHpPenalty(card, wasCorrect: true);
    _awardXPToWord(card, true, _wrongAttempts[_currentIndex] ?? 0);
    _updateCardInProvider(card);
    
    setState(() {
      _answered = true;
      _totalAttempts++;
      _correctAnswers++;
      _correctAnswersMap[_currentIndex] = true;
      _consecutiveCorrect++;
      _successController.forward(from: 0);
      // Auto-populate user answer if not already full (useful for hints or single-word cases)
      if (_userAnswer.length < _correctSentences[_currentIndex]!.split(' ').length) {
         _userAnswer = _correctSentences[_currentIndex]!.split(' ');
      }
    });
    
    HapticService().successFeedback();
    SoundManager().playCorrectSound();
    _answeredQuestions[_currentIndex] = List<String>.from(_userAnswer);
    
    if (widget.autoProgress && !widget.shuffleMode) {
      _autoProgressTimer?.cancel();
      _autoProgressTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted && _currentIndex < _currentCards.length - 1) {
          _autoProgressedQuestions.add(_currentIndex);
          _activeQuestionIndex = _currentIndex + 1;
          _goToNextQuestion();
        }
      });
    }
  }

  void _handleWrongAnswer(FlashCard card) {
    final currentWrongAttempts = _wrongAttempts[_currentIndex] ?? 0;
    final newWrongAttempts = widget.oneAnswerMode ? 5 : (currentWrongAttempts + 1);
    _wrongAttempts[_currentIndex] = newWrongAttempts;
    
    XpService.recordAnswer(_gameSession, false);
    
    if (_useLivesMode) {
      setState(() {
        _lives--;
      });
      if (_lives <= 0) {
        _applyHpPenalty(card, wasCorrect: false);
        _awardXPToWord(card, false, newWrongAttempts);
        _updateCardInProvider(card);
        _showGameOverScreen();
        return;
      }
    }
    
    if (widget.oneAnswerMode || newWrongAttempts >= 5) {
      _applyHpPenalty(card, wasCorrect: false);
      _awardXPToWord(card, false, 5);
      _updateCardInProvider(card);
      
      final correctWords = _correctSentence.split(' ').where((w) => w.trim().isNotEmpty).toList();
      setState(() {
        _isShowingWrongAnswer = false;
        _userAnswer = List<String>.from(correctWords);
        _answered = true;
        _totalAttempts++;
        _correctAnswersMap[_currentIndex] = false;
        _consecutiveCorrect = 0;
        _shakeController.forward(from: 0);
        _answeredQuestions[_currentIndex] = List<String>.from(correctWords);
      });
      HapticService().errorFeedback();
      return;
    }
    
    setState(() {
      _isShowingWrongAnswer = true;
      _totalAttempts++;
    });
    SoundManager().playWrongSound();
    _shakeController.forward(from: 0);
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && !_answered) {
        final wordsToReturn = List<String>.from(_userAnswer);
        setState(() {
          _isShowingWrongAnswer = false;
          _availableWords.addAll(wordsToReturn);
          _userAnswer.clear();
        });
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timeUp = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeRemaining > 0) {
            _timeRemaining--;
          }
        });
        
        if (_timeRemaining <= 0) {
          _handleTimeUp();
          _timer?.cancel();
        }
      }
    });
  }

  void _handleTimeUp() {
    if (_answered) return;
    
    final correctWords = _correctSentence.split(' ').where((w) => w.trim().isNotEmpty).toList();
    setState(() {
      _answered = true;
      _timeUp = true;
      _totalAttempts++;
      _correctAnswersMap[_currentIndex] = false;
      _userAnswer = List<String>.from(correctWords);
      _availableWords.clear();
      _answeredQuestions[_currentIndex] = List<String>.from(correctWords);
    });
    
    HapticService().errorFeedback();
    SoundManager().playWrongSound();
    
    _gameSession.recordAnswer(false);
    
    if (widget.autoProgress && !widget.shuffleMode) {
      _autoProgressTimer?.cancel();
      _autoProgressTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _currentIndex < _currentCards.length - 1) {
          _activeQuestionIndex = _currentIndex + 1;
          _goToNextQuestion();
        }
      });
    }
  }

  Widget _buildTimerIndicator() {
    if (_totalTime == 0) return const SizedBox.shrink();
    final progress = _timeRemaining / _totalTime;
    Color timerColor = Colors.green;
    if (progress < 0.3) {
      timerColor = Colors.red;
    } else if (progress < 0.6) {
      timerColor = Colors.orange;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer,
          color: timerColor,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$_timeRemaining',
          style: TextStyle(
            color: timerColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _useHint() {
    if (_answered || !widget.enableHints) return;
    
    // Use the normalized version of correct words to match user answer
    final correctWords = _correctSentence.split(' ').where((w) => w.trim().isNotEmpty).toList();
    
    // Find the first position that is either empty or incorrect
    int nextHintIndex = -1;
    for (int i = 0; i < correctWords.length; i++) {
        if (i >= _userAnswer.length || _userAnswer[i] != correctWords[i]) {
            nextHintIndex = i;
            break;
        } else {
            // Already correct, ensure it's locked if not already
            (_lockedPositions[_currentIndex] ??= {}).add(i);
        }
    }
    
    if (nextHintIndex == -1 || nextHintIndex >= correctWords.length - 1) {
      _showHintMessage(nextHintIndex == correctWords.length - 1 
          ? "You must figure out the last word yourself!" 
          : "Sentence is already correct!");
      return;
    }
    
    final correctWord = correctWords[nextHintIndex];
    
    setState(() {
      // 1. Find if the correct word is in the pool or in the answer (at a later position)
      bool found = false;
      int sourceIndex = -1;
      bool fromPool = false;
      
      // Look in pool first
      sourceIndex = _availableWords.indexOf(correctWord);
      if (sourceIndex != -1) {
          _availableWords.removeAt(sourceIndex);
          found = true;
          fromPool = true;
      } else {
          // Look in user answer (later positions only)
          for (int i = nextHintIndex + 1; i < _userAnswer.length; i++) {
              if (_userAnswer[i] == correctWord) {
                  sourceIndex = i;
                  _userAnswer.removeAt(i);
                  found = true;
                  break;
              }
          }
      }
      
      if (found) {
        // 2. If there's already a word at this position that is wrong, return it to the pool
        if (nextHintIndex < _userAnswer.length) {
            final wrongWord = _userAnswer[nextHintIndex];
            _userAnswer[nextHintIndex] = correctWord; // Replace directly
            _availableWords.add(wrongWord); // Return wrong word to pool
        } else {
            // Just add it to the end
            _userAnswer.add(correctWord);
        }
        
        // 3. Mark as locked and increment hint count
        (_lockedPositions[_currentIndex] ??= {}).add(nextHintIndex);
        _hintCount[_currentIndex] = (_hintCount[_currentIndex] ?? 0) + 1;
      }
    });
    
    HapticService().lightImpact();
    setState(() {
      _totalAttempts++; // Hint usage counts as an attempt for accuracy calculation
    });
    
    if (_availableWords.isEmpty && _userAnswer.length == correctWords.length) {
      _checkAnswer();
    }
  }

  void _showHintMessage(String message) {
    setState(() {
      _hintStatusMessage = message;
    });
    _hintStatusTimer?.cancel();
    _hintStatusTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hintStatusMessage = null);
    });
  }

  void _goToNextQuestion() {
    if (_currentIndex < _currentCards.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _generateQuestion();
    } else {
      setState(() {
        _showingResults = true;
      });
      SoundManager().playCompleteSound();
    }
  }

  void _showGameOverScreen() {
    setState(() {
      _showingResults = true;
    });
    _awardXp();
    SoundManager().playCompleteSound();
  }

  void _applyHpPenalty(FlashCard card, {required bool wasCorrect}) {
    if (_hpPenaltyAppliedWordIds.contains(card.id)) return;
    _hpPenaltyAppliedWordIds.add(card.id);
    _ensureCardTracked(card);
    if (wasCorrect) {
      card.markCorrectAs('sentence', GameDifficulty.hard);
    } else {
      card.markIncorrectAs('sentence', GameDifficulty.hard);
    }
  }

  void _ensureCardTracked(FlashCard card) {
    if (_studiedWords.any((word) => word.id == card.id)) return;
    _studiedWords.add(card);
    _initialHPPerWord[card.id] = card.currentHP;
  }

  void _awardXPToWord(FlashCard card, bool isCorrect, [int wrongAttempts = 0]) {
    _ensureCardTracked(card);
    
    if (isCorrect) {
      final latestEntry = card.learningMastery.exerciseHistory.isNotEmpty
          ? card.learningMastery.exerciseHistory.last
          : null;
      final actualXPGained = latestEntry != null
          ? (latestEntry['xpGained'] as int? ?? 0)
          : 0;
      
      final hintsUsed = _hintCount[_currentIndex] ?? 0;
      final hintPenalty = hintsUsed > 0 ? (0.2 * hintsUsed).clamp(0.0, 0.8) : 0.0;
      var finalXPGained = hintsUsed > 0
          ? (actualXPGained * (1.0 - hintPenalty)).round().clamp(1, actualXPGained)
          : actualXPGained;
      
      if (wrongAttempts > 0 && wrongAttempts < 5) {
        finalXPGained = (finalXPGained - wrongAttempts).clamp(0, actualXPGained);
      }
      
      if (latestEntry != null) {
        card.learningMastery.currentXP += finalXPGained - actualXPGained;
        latestEntry['xpGained'] = finalXPGained;
      }
      
      _xpGainedPerWord[card.id] = finalXPGained;
    } else {
      _xpGainedPerWord[card.id] = 0;
    }
    
    _wordMastery[card.id] = card.learningMastery;
  }

  void _awardXp() {
    final provider = context.read<UserProfileProvider>();
    XpService.awardSessionXp(provider, _gameSession);
  }

  Future<void> _updateCardInProvider(FlashCard card) async {
    final provider = context.read<FlashcardProvider>();
    await provider.updateCard(card);
  }

  void _showWordProgress() {
    final sessionStudiedWords = List<FlashCard>.from(_studiedWords);
    final sessionXpGainedPerWord = Map<String, int>.from(_xpGainedPerWord);
    final sessionWordMastery = Map<String, LearningMastery>.from(_wordMastery);
    final sessionInitialHPPerWord = Map<String, int>.from(_initialHPPerWord);
    
    GameEndScreen.show(
      context,
      GameEndResult(
        title: 'Sentence',
        studiedWords: sessionStudiedWords,
        xpGainedPerWord: sessionXpGainedPerWord,
        wordMastery: sessionWordMastery,
        initialHPPerWord: sessionInitialHPPerWord,
        correctAnswers: _correctAnswers,
        totalQuestions: _totalAttempts,
        onDone: () {
          // Go back reaching the StudyTypeSelectionView
          Navigator.of(context).popUntil((route) => route.settings.name == '/options' || route.isFirst);
        },
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
            _userAnswer = [];
            _gameSession.reset();
            _answeredQuestions.clear();
            _correctAnswersMap.clear();
            _availableWordsMap.clear();
            _questionModes.clear();
            _xpGainedPerWord.clear();
            _wordMastery.clear();
            _studiedWords.clear();
            _initialHPPerWord.clear();
            _hpPenaltyAppliedWordIds.clear();
            _hintCount.clear();
            _lockedPositions.clear();
          });
          _generateQuestion();
        },
        onShuffle: (available) {
          Navigator.of(context).pop();
          setState(() {
            _currentCards = List.from(available)..shuffle();
            _currentIndex = 0;
            _correctAnswers = 0;
            _totalAttempts = 0;
            _showingResults = false;
            _hasShownResults = false;
            _answered = false;
            _userAnswer = [];
            _gameSession.reset();
            _answeredQuestions.clear();
            _correctAnswersMap.clear();
            _availableWordsMap.clear();
            _questionModes.clear();
            _xpGainedPerWord.clear();
            _wordMastery.clear();
            _studiedWords.clear();
            _initialHPPerWord.clear();
            _hpPenaltyAppliedWordIds.clear();
            _hintCount.clear();
            _lockedPositions.clear();
          });
          _generateQuestion();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('No cards available')),
      );
    }

    if (_showingResults) {
      if (!_hasShownResults) {
        _hasShownResults = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showWordProgress());
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentCard = _currentCards[_currentIndex];
    final prompt = _isQuestionMode ? currentCard.exampleTranslation : currentCard.example;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          _buildHeader(),
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. The Word Card (Top)
                  _buildWordCard(currentCard),
                  
                  const SizedBox(height: 32),
                  
                  // 2. The Instruction Text
                  Text(
                    _isQuestionMode 
                      ? 'Build the correct Dutch sentence: $prompt' 
                      : 'Build the correct English translation: $prompt',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 3. The Answer Section (Empty box or building area)
                  _buildAnswerArea(),
                  
                  const SizedBox(height: 24),

                  // Correct Answer display if failed
                  if (_answered && _correctAnswersMap[_currentIndex] == false)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Correct Answer:",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _correctSentences[_currentIndex] ?? "",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // 4. The Pool Section (Available words)
                  _buildWordPool(),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildWordCard(FlashCard card) {
    final borderColor = _getCardBorderColor(card);
    
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 140,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Theme.of(context).colorScheme.surface 
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              card.word,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        
        // Hint button (bottom right)
        if (widget.enableHints && !_answered)
          Positioned(
            bottom: 12,
            right: 12,
            child: _buildHintIcon(),
          ),
      ],
    );
  }

  Color _getCardBorderColor(FlashCard card) {
    return CardColorUtils.getBorderColor(card);
  }

  Widget _buildHeader() {
    return MainHeader(
      title: 'Sentence Builder',
      leftAction: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
        onPressed: () => _showCloseConfirmation(),
      ),
      rightAction: IconButton(
        icon: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
        onPressed: () => _showHomeConfirmation(),
      ),
    );
  }

  Widget _buildHintIcon() {
    final canUseHint = !_answered && widget.enableHints;

    return GestureDetector(
      onTap: canUseHint ? _useHint : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: canUseHint ? Colors.orange.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: canUseHint ? Colors.orange : Colors.grey.shade400,
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.lightbulb,
          size: 16,
          color: canUseHint ? Colors.orange : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _currentCards.isEmpty ? 0.0 : _currentIndex / _currentCards.length;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              // Left: Card count
              Expanded(
                child: Text(
                  'Card ${_currentIndex + 1}/${_currentCards.length}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              
              // Middle: Timer and/or Lives
              if (_useLivesMode || _useTimedMode || _consecutiveCorrect >= 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_useLivesMode) ...[
                        _buildLivesIndicator(),
                        if (_useTimedMode || _consecutiveCorrect >= 3) const SizedBox(width: 8),
                      ],
                      if (_useTimedMode) ...[
                        _buildTimerIndicator(),
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
                ),
                
              // Right: Accuracy
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


  Widget _buildAnswerArea() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_isShowingWrongAnswer ? _shakeAnimation.value * sin(DateTime.now().millisecondsSinceEpoch * 0.1) : 0, 0),
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isShowingWrongAnswer 
              ? Colors.red.withValues(alpha: 0.05) 
              : (_answered ? Colors.green.withValues(alpha: 0.05) : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isShowingWrongAnswer 
              ? Colors.red.withValues(alpha: 0.3) 
              : (_answered ? Colors.green.withValues(alpha: 0.3) : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
            width: 2,
          ),
        ),
        child: DragTarget<String>(
          onAcceptWithDetails: (details) => _addWord(details.data),
          builder: (context, candidateData, rejectedData) => Container(
            constraints: const BoxConstraints(minHeight: 120),
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 14,
              alignment: WrapAlignment.start,
              children: _userAnswer.map((word) {
                final index = _userAnswer.indexOf(word);
                final isLocked = _lockedPositions[_currentIndex]?.contains(index) ?? false;
                
                return GestureDetector(
                  onTap: () => _removeWordAt(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isLocked ? Colors.orange.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLocked ? Colors.orange : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          word,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isLocked ? Colors.orange[800] : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (isLocked) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.lock, size: 14, color: Colors.orange),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordPool() {
    if (_answered) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Words:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 18,
            children: _availableWords.map((word) {
              return Draggable<String>(
                data: word,
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      word,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      word,
                      style: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 16),
                    ),
                  ),
                ),
                child: GestureDetector(
                  onTap: () => _addWord(word),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      word,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
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

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _currentIndex > 0 ? () {
                  setState(() => _currentIndex--);
                  _generateQuestion();
                } : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: _currentIndex > 0 
                      ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87) 
                      : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: (_answered || _userAnswer.isNotEmpty) ? () {
                  if (!_answered) {
                    _checkAnswer();
                  } else {
                    _goToNextQuestion();
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _answered ? Colors.green : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(_answered ? 'Next' : 'Check Answer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit Game?'),
        content: const Text('Are you sure you want to quit? Your progress for this session will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Quit', style: TextStyle(color: Colors.red)),
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
        content: const Text('Are you sure you want to return to the home screen? Your progress for this session will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Home', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
