import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/flash_card.dart';
import '../models/game_session.dart';
import '../models/learning_mastery.dart';
import '../models/study_config.dart';
import '../models/timed_difficulty.dart';
import '../services/sound_manager.dart';
import '../services/xp_service.dart';
import '../services/haptic_service.dart';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../utils/card_color_utils.dart';
import '../utils/game_end_screen.dart';
import '../components/main_header.dart';

class DeHetView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final bool useLivesMode;
  final int? customLives;
  final bool useTimedMode;
  final TimedDifficulty? timedDifficulty;
  final StudyConfig? studyConfig;
  final Function(bool)? onComplete;
  final bool shuffleMode;

  const DeHetView({
    super.key,
    required this.cards,
    required this.title,
    this.useLivesMode = false,
    this.customLives,
    this.useTimedMode = false,
    this.timedDifficulty,
    this.studyConfig,
    this.onComplete,
    this.shuffleMode = false,
  });

  @override
  State<DeHetView> createState() => _DeHetViewState();
}

class _DeHetViewState extends State<DeHetView> with TickerProviderStateMixin {
  // Filter to only cards with a valid article
  late List<FlashCard> _currentCards;

  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAttempts = 0;
  bool _showingResults = false;
  bool _answered = false;
  String? _selectedArticle; // 'de' or 'het'
  String? _correctArticle;  // 'de' or 'het' — from card.article

  final GameSession _gameSession = GameSession();

  // Per-question storage for navigation
  Map<int, String> _answeredQuestions = {};  // index → chosen article
  Map<int, bool> _isCorrectMap = {};         // index → was correct

  // XP / HP tracking
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  Map<String, int> _initialHPPerWord = {};
  List<FlashCard> _studiedWords = [];
  Set<String> _hpDeductedIds = {};

  // Lives
  int _lives = 0;
  int _maxLives = 0;
  bool _useLivesMode = false;

  // Timer
  Timer? _questionTimer;
  int _timeRemaining = 0;
  int _totalTime = 0;
  bool _timeUp = false;
  bool _useTimedMode = false;

  // Animations
  late AnimationController _shakeController;
  late AnimationController _successController;
  late AnimationController _scaleController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  int _consecutiveCorrect = 0;
  bool _endScreenShown = false;

  // Auto-progress timer
  Timer? _autoProgressTimer;

  @override
  void initState() {
    super.initState();

    // Only keep cards that have a valid article
    _currentCards = widget.cards
        .where((c) => c.article == 'de' || c.article == 'het')
        .toList();

    _useLivesMode = widget.useLivesMode;
    if (_useLivesMode) {
      _maxLives = widget.customLives ?? 3;
      _lives = _maxLives;
    }

    _useTimedMode = widget.useTimedMode;
    if (_useTimedMode) {
      _totalTime = _getSecondsForDifficulty(widget.timedDifficulty);
      _timeRemaining = _totalTime;
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
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.06)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.06, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 50),
    ]).animate(_successController);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
    _scaleController.forward();

    _loadQuestion();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _autoProgressTimer?.cancel();
    _shakeController.dispose();
    _successController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  int _getSecondsForDifficulty(TimedDifficulty? difficulty) {
    switch (difficulty) {
      case TimedDifficulty.easy:
        return 7;
      case TimedDifficulty.hard:
        return 3;
      default:
        return 5;
    }
  }

  Color _getCardBorderColor(FlashCard card) {
    return CardColorUtils.getBorderColor(card);
  }

  // ─── Question logic ────────────────────────────────────────────────────────

  void _loadQuestion() {
    if (_currentIndex >= _currentCards.length) {
      _finishSession();
      return;
    }

    // Restore previously answered state
    if (_answeredQuestions.containsKey(_currentIndex)) {
      setState(() {
        _selectedArticle = _answeredQuestions[_currentIndex];
        _correctArticle = _currentCards[_currentIndex].article;
        _answered = true;
      });
      return;
    }

    setState(() {
      _answered = false;
      _selectedArticle = null;
      _correctArticle = _currentCards[_currentIndex].article;
      _timeUp = false;
    });

    _scaleController.forward(from: 0);

    if (_useTimedMode) {
      _startTimer();
    }
  }

  void _startTimer() {
    _questionTimer?.cancel();
    setState(() {
      _timeRemaining = _totalTime;
    });
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_answered) {
        t.cancel();
        return;
      }
      setState(() {
        _timeRemaining--;
      });
      if (_timeRemaining <= 0) {
        t.cancel();
        _onTimeUp();
      }
    });
  }

  void _onTimeUp() {
    if (_answered) return;
    setState(() {
      _timeUp = true;
    });
    HapticService().errorFeedback();
    SoundManager().playWrongSound();
    _resolveAnswer(null); // null = timed out = wrong
  }

  void _selectArticle(String article) {
    if (_answered) return;
    _questionTimer?.cancel();
    _resolveAnswer(article);
  }

  void _resolveAnswer(String? chosen) {
    final card = _currentCards[_currentIndex];
    final correct = card.article; // 'de' or 'het'
    final isCorrect = chosen != null && chosen == correct;

    if (isCorrect) {
      HapticService().successFeedback();
      _successController.forward(from: 0);
      _consecutiveCorrect++;
      SoundManager().playCorrectSound();
    } else {
      HapticService().errorFeedback();
      _shakeController.forward(from: 0);
      _consecutiveCorrect = 0;
      SoundManager().playWrongSound();
    }

    XpService.recordAnswer(_gameSession, isCorrect);
    _ensureCardTracked(card);
    _applyHp(card, wasCorrect: isCorrect);
    _awardXPToWord(card, isCorrect);
    _updateCardInProvider(card);

    bool livesRanOut = false;
    setState(() {
      _selectedArticle = chosen;
      _correctArticle = correct;
      _answered = true;
      _totalAttempts++;
      _answeredQuestions[_currentIndex] = chosen ?? '__timeout__';
      _isCorrectMap[_currentIndex] = isCorrect;

      if (isCorrect) {
        _correctAnswers++;
      } else {
        if (_useLivesMode) {
          _lives--;
          if (_lives <= 0) {
            livesRanOut = true;
          }
        }
      }
    });
    if (livesRanOut) {
      _finishSession();
      return;
    }

    // Auto-advance after short delay
    _autoProgressTimer?.cancel();
    _autoProgressTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted && !_showingResults) {
        _goNext();
      }
    });
  }

  Future<void> _goNext() async {
    if (_currentIndex < _currentCards.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadQuestion();
    } else {
      await _finishSession();
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadQuestion();
    }
  }

  Future<void> _finalizeSession() async {
    if (!mounted) return;
    final userProvider = context.read<UserProfileProvider>();
    final totalXP = _xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp);
    if (totalXP > 0) await userProvider.addXp(totalXP);
    final accuracy = _totalAttempts > 0 ? _correctAnswers / _totalAttempts : 0.0;
    await userProvider.updateSessionStats(
      cardsStudied: _totalAttempts,
      sessionAccuracy: accuracy,
      isPerfect: _correctAnswers == _totalAttempts && _totalAttempts > 0,
    );
    await userProvider.updateStreakFromStudyActivity();
  }

  Future<void> _finishSession() async {
    _questionTimer?.cancel();
    setState(() {
      _showingResults = true;
    });
    await _finalizeSession();
    if (mounted && !_endScreenShown) {
      _endScreenShown = true;
      if (widget.onComplete != null) {
        final successRate = _totalAttempts > 0 ? _correctAnswers / _totalAttempts : 0.0;
        widget.onComplete!(successRate >= 0.6);
        return;
      }
      _showEndScreen();
    }
  }

  // ─── XP / HP helpers ──────────────────────────────────────────────────────

  void _ensureCardTracked(FlashCard card) {
    if (_studiedWords.any((w) => w.id == card.id)) return;
    _studiedWords.add(card);
    _initialHPPerWord[card.id] = card.currentHP;
  }

  void _applyHp(FlashCard card, {required bool wasCorrect}) {
    if (_hpDeductedIds.contains(card.id)) return;
    _hpDeductedIds.add(card.id);
    if (wasCorrect) {
      card.markCorrectAs('de_het', GameDifficulty.medium);
    } else {
      card.markIncorrectAs('de_het', GameDifficulty.medium);
    }
  }

  void _awardXPToWord(FlashCard card, bool isCorrect) {
    _ensureCardTracked(card);
    if (isCorrect) {
      final latest = card.learningMastery.exerciseHistory.isNotEmpty
          ? card.learningMastery.exerciseHistory.last
          : null;
      final xp = latest != null ? (latest['xpGained'] as int? ?? 0) : 0;
      _xpGainedPerWord[card.id] = xp;
    } else {
      _xpGainedPerWord[card.id] = 0;
    }
    _wordMastery[card.id] = card.learningMastery;
  }

  Future<void> _updateCardInProvider(FlashCard card) async {
    final provider = context.read<FlashcardProvider>();
    await provider.updateCard(card);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_currentCards.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            MainHeader(
              title: widget.title,
              leftAction: IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: Theme.of(context).colorScheme.onSurface),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_outlined,
                          size: 72,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 24),
                      Text(
                        'No articles found',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'None of the selected cards have "de" or "het" set.\n\nOpen a card and add the article in the edit screen to play this game.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final card = _currentCards[_currentIndex];
    final accentColor = _getCardBorderColor(card);
    final progress = (_currentIndex + 1) / _currentCards.length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          MainHeader(
            title: widget.title,
            leftAction: IconButton(
              icon: Icon(Icons.arrow_back_ios,
                  color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
            rightAction: IconButton(
              icon: Icon(Icons.home,
                  color: Theme.of(context).colorScheme.onSurface),
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ),

          // ── Progress bar ──────────────────────────────────────────────────
          _buildProgressBar(),

          // ── Card display ─────────────────────────────────────────────────
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeController.isAnimating
                          ? _shakeAnimation.value *
                              (0.5 - _shakeController.value).sign
                          : 0.0, 0),
                      child: child,
                    );
                  },
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _answered
                              ? (_isCorrectMap[_currentIndex] == true
                                  ? Colors.green
                                  : Colors.red)
                              : accentColor.withValues(alpha: 0.8),
                          width: _answered ? 4 : 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Article prompt
                            Text(
                              'De of Het?',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                            const SizedBox(height: 24),
                            // Article accent chip
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '___  ${card.word}',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),

                            // ── Answer reveal ──────────────────────────────
                            if (_answered) ...[
                              const SizedBox(height: 28),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isCorrectMap[_currentIndex] == true
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isCorrectMap[_currentIndex] == true
                                          ? Icons.check_circle_rounded
                                          : Icons.cancel_rounded,
                                      color:
                                          _isCorrectMap[_currentIndex] == true
                                              ? Colors.green
                                              : Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isCorrectMap[_currentIndex] == true
                                          ? 'It\'s "${_correctArticle} ${card.word}"'
                                          : _timeUp
                                              ? 'Time\'s up! "${_correctArticle}"'
                                              : 'Wrong! "${_correctArticle}"',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _isCorrectMap[_currentIndex] == true
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Answer buttons ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(child: _buildArticleButton('de', accentColor)),
                const SizedBox(width: 16),
                Expanded(child: _buildArticleButton('het', accentColor)),
              ],
            ),
          ),

          // ── Navigation footer ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _currentIndex > 0 ? _goPrev : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  label: const Text('Prev'),
                ),
                const Spacer(),
                if (_currentIndex < _currentCards.length - 1)
                  FilledButton.icon(
                    onPressed: _answered ? _goNext : null,
                    icon: const Icon(Icons.arrow_forward_ios, size: 14),
                    label: const Text('Next'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _answered ? _finishSession : null,
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Finish'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _currentCards.isEmpty ? 0.0 : _currentIndex / _currentCards.length;
    final card = _currentCards[_currentIndex];
    final accentColor = _getCardBorderColor(card);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              // Left side: Card count
              Expanded(
                child: Text(
                  'Card ${_currentIndex + 1}/${_currentCards.length}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              
              // Middle: Lives and/or timer
              if (_useLivesMode || _useTimedMode || _consecutiveCorrect >= 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_useLivesMode) ...[
                        _buildLivesIndicator(),
                        if (_useTimedMode || _consecutiveCorrect >= 3) const SizedBox(width: 12),
                      ],
                      if (_useTimedMode) ...[
                        _buildTimerIndicator(),
                        if (_consecutiveCorrect >= 3) const SizedBox(width: 12),
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
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
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

  Widget _buildTimerIndicator() {
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
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          '$_timeRemaining',
          style: TextStyle(
            color: timerColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildArticleButton(String article, Color accentColor) {
    // ... use current build article button logic
    final isSelected = _selectedArticle == article;
    final isCorrect = _correctArticle == article;
    final wasAnswered = _answered;

    Color bgColor;
    Color borderColor;
    Color textColor;

    if (!wasAnswered) {
      bgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      borderColor = accentColor.withValues(alpha: 0.3);
      textColor = Theme.of(context).colorScheme.onSurface;
    } else if (isCorrect) {
      bgColor = Colors.green.withValues(alpha: 0.15);
      borderColor = Colors.green;
      textColor = Colors.green[700]!;
    } else if (isSelected && !isCorrect) {
      bgColor = Colors.red.withValues(alpha: 0.15);
      borderColor = Colors.red;
      textColor = Colors.red[700]!;
    } else {
      bgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      borderColor = Theme.of(context)
          .colorScheme
          .onSurface
          .withValues(alpha: 0.15);
      textColor = Theme.of(context)
          .colorScheme
          .onSurface
          .withValues(alpha: 0.4);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: wasAnswered ? null : () => _selectArticle(article),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: !wasAnswered
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.08),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (wasAnswered && isCorrect)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child:
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                  )
                else if (wasAnswered && isSelected && !isCorrect)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.cancel, color: Colors.red[700], size: 20),
                  ),
                Text(
                  article,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEndScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameEndScreen.show(
        context,
        GameEndResult(
          title: 'De of Het',
          studiedWords: List.from(_studiedWords),
          xpGainedPerWord: Map.from(_xpGainedPerWord),
          wordMastery: Map.from(_wordMastery),
          initialHPPerWord: Map.from(_initialHPPerWord),
          correctAnswers: _correctAnswers,
          totalQuestions: _totalAttempts,
          onDone: () {
            Navigator.of(context)
                .popUntil((r) => r.settings.name == '/options' || r.isFirst);
          },
          onStudyAgain: (available) {
            Navigator.of(context).pop();
            setState(() {
              _currentCards =
                  available.where((c) => c.article == 'de' || c.article == 'het').toList();
              _currentIndex = 0;
              _correctAnswers = 0;
              _totalAttempts = 0;
              _showingResults = false;
              _answered = false;
              _selectedArticle = null;
              _endScreenShown = false;
              _gameSession.reset();
              _answeredQuestions.clear();
              _isCorrectMap.clear();
              _xpGainedPerWord.clear();
              _wordMastery.clear();
              _studiedWords.clear();
              _initialHPPerWord.clear();
              _hpDeductedIds.clear();
              if (_useLivesMode) _lives = _maxLives;
            });
            _loadQuestion();
          },
          onShuffle: (available) {
            Navigator.of(context).pop();
            setState(() {
              _currentCards = (available
                      .where((c) => c.article == 'de' || c.article == 'het')
                      .toList())
                  ..shuffle();
              _currentIndex = 0;
              _correctAnswers = 0;
              _totalAttempts = 0;
              _showingResults = false;
              _answered = false;
              _selectedArticle = null;
              _endScreenShown = false;
              _gameSession.reset();
              _answeredQuestions.clear();
              _isCorrectMap.clear();
              _xpGainedPerWord.clear();
              _wordMastery.clear();
              _studiedWords.clear();
              _initialHPPerWord.clear();
              _hpDeductedIds.clear();
              if (_useLivesMode) _lives = _maxLives;
            });
            _loadQuestion();
          },
        ),
      );
    });
  }
}
