import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
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
import '../utils/game_end_screen.dart';
import '../components/main_header.dart';

class SoManyCardsView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final bool useLivesMode;
  final int? customLives;
  final bool useTimedMode;
  final TimedDifficulty? timedDifficulty;
  final StudyConfig? studyConfig;

  const SoManyCardsView({
    super.key,
    required this.cards,
    required this.title,
    this.useLivesMode = false,
    this.customLives,
    this.useTimedMode = false,
    this.timedDifficulty,
    this.studyConfig,
  });

  @override
  State<SoManyCardsView> createState() => _SoManyCardsViewState();
}

class _SoManyCardsViewState extends State<SoManyCardsView> with TickerProviderStateMixin {
  late List<FlashCard> _currentCards;
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAttempts = 0;
  bool _showingResults = false;
  bool _answered = false;
  String? _selectedOption;
  String? _correctPlural;
  List<String> _options = [];

  final GameSession _gameSession = GameSession();
  Map<int, String> _answeredQuestions = {}; 
  Map<int, bool> _isCorrectMap = {};
  Map<int, List<String>> _questionOptions = {};

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

  // Auto-progress timer
  Timer? _autoProgressTimer;

  @override
  void initState() {
    super.initState();

    // Only keep cards that have a valid plural
    _currentCards = widget.cards
        .where((c) => c.plural.isNotEmpty)
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

  int _getSecondsForDifficulty(TimedDifficulty? difficulty) {
    switch (difficulty) {
      case TimedDifficulty.easy:
        return 10;
      case TimedDifficulty.hard:
        return 5;
      default:
        return 7;
    }
  }

  Color _getCardBorderColor(FlashCard card) {
    final vibrantColors = [
      const Color(0xFFFF6B35),
      const Color(0xFFFF9900),
      const Color(0xFFFFCC00),
      const Color(0xFF33CC99),
      const Color(0xFF00B3CC),
      const Color(0xFF9966FF),
      const Color(0xFFFF4D94),
      const Color(0xFF66E64D),
    ];
    final hash = (card.word.hashCode + card.definition.hashCode).abs();
    return vibrantColors[hash % vibrantColors.length];
  }

  void _loadQuestion() {
    if (_currentIndex >= _currentCards.length) {
      _finishSession();
      return;
    }

    if (_answeredQuestions.containsKey(_currentIndex)) {
      setState(() {
        _selectedOption = _answeredQuestions[_currentIndex];
        _options = _questionOptions[_currentIndex]!;
        _correctPlural = _currentCards[_currentIndex].plural;
        _answered = true;
      });
      return;
    }

    final card = _currentCards[_currentIndex];
    final plural = card.plural;
    
    // Generate decoys
    List<String> options = _generatePluralOptions(card.word, plural);

    setState(() {
      _answered = false;
      _selectedOption = null;
      _correctPlural = plural;
      _options = options;
      _questionOptions[_currentIndex] = options;
      _timeUp = false;
    });

    _scaleController.forward(from: 0);
    if (_useTimedMode) _startTimer();
  }

  List<String> _generatePluralOptions(String word, String correct) {
    Set<String> options = {correct};
    
    // Common Dutch plural patterns
    List<String> patterns = [
      word + "en",
      word + "s",
      word + "'s",
      word + "eren",
      word.endsWith('s') ? word + "es" : word + "jes",
    ];

    patterns.shuffle();
    for (var p in patterns) {
      if (options.length < 4 && p != correct) {
        options.add(p);
      }
    }

    // Fallback if needed
    while (options.length < 4) {
      options.add(word + Random().nextInt(100).toString());
    }

    List<String> result = options.toList();
    result.shuffle();
    return result;
  }

  void _startTimer() {
    _questionTimer?.cancel();
    setState(() => _timeRemaining = _totalTime);
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _answered) {
        t.cancel();
        return;
      }
      setState(() => _timeRemaining--);
      if (_timeRemaining <= 0) {
        t.cancel();
        _onTimeUp();
      }
    });
  }

  void _onTimeUp() {
    if (_answered) return;
    setState(() => _timeUp = true);
    HapticService().errorFeedback();
    SoundManager().playWrongSound();
    _resolveAnswer(null);
  }

  void _selectOption(String option) {
    if (_answered) return;
    _questionTimer?.cancel();
    _resolveAnswer(option);
  }

  void _resolveAnswer(String? chosen) {
    final card = _currentCards[_currentIndex];
    final isCorrect = chosen != null && chosen == _correctPlural;

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

    setState(() {
      _selectedOption = chosen;
      _answered = true;
      _totalAttempts++;
      _answeredQuestions[_currentIndex] = chosen ?? '__timeout__';
      _isCorrectMap[_currentIndex] = isCorrect;

      if (isCorrect) {
        _correctAnswers++;
      } else if (_useLivesMode) {
        _lives--;
        if (_lives <= 0) _finishSession();
      }
    });

    _autoProgressTimer?.cancel();
    _autoProgressTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_showingResults) _goNext();
    });
  }

  void _goNext() {
    if (_currentIndex < _currentCards.length - 1) {
      setState(() => _currentIndex++);
      _loadQuestion();
    } else {
      _finishSession();
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadQuestion();
    }
  }

  void _finishSession() {
    _questionTimer?.cancel();
    _awardXp();
    setState(() => _showingResults = true);
  }

  void _ensureCardTracked(FlashCard card) {
    if (_studiedWords.any((w) => w.id == card.id)) return;
    _studiedWords.add(card);
    _initialHPPerWord[card.id] = card.currentHP;
  }

  void _applyHp(FlashCard card, {required bool wasCorrect}) {
    if (_hpDeductedIds.contains(card.id)) return;
    _hpDeductedIds.add(card.id);
    if (wasCorrect) {
      card.markCorrectAs('so_many_cards', GameDifficulty.medium);
    } else {
      card.markIncorrectAs('so_many_cards', GameDifficulty.medium);
    }
  }

  void _awardXPToWord(FlashCard card, bool isCorrect) {
    _ensureCardTracked(card);
    if (isCorrect) {
      final latest = card.learningMastery.exerciseHistory.isNotEmpty
          ? card.learningMastery.exerciseHistory.last
          : null;
      _xpGainedPerWord[card.id] = latest != null ? (latest['xpGained'] as int? ?? 0) : 0;
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

  void _showEndScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameEndScreen.view(
            GameEndResult(
              title: widget.title,
              correctAnswers: _correctAnswers,
              totalQuestions: _currentCards.length,
              xpGainedPerWord: _xpGainedPerWord,
              wordMastery: _wordMastery,
              studiedWords: _studiedWords,
              initialHPPerWord: _initialHPPerWord,
              onStudyAgain: (available) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => SoManyCardsView(
                      cards: available,
                      title: widget.title,
                      useLivesMode: widget.useLivesMode,
                      customLives: widget.customLives,
                      useTimedMode: widget.useTimedMode,
                      timedDifficulty: widget.timedDifficulty,
                    ),
                  ),
                );
              },
              onDone: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showingResults) _showEndScreen();

    if (_currentCards.isEmpty) {
      return Scaffold(
        body: Column(
          children: [
            MainHeader(title: widget.title, leftAction: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => Navigator.of(context).pop())),
            const Expanded(child: Center(child: Text('No cards with plurals found.'))),
          ],
        ),
      );
    }

    final card = _currentCards[_currentIndex];
    final accentColor = _getCardBorderColor(card);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          MainHeader(
            title: widget.title,
            leftAction: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => Navigator.of(context).pop()),
            rightAction: IconButton(icon: const Icon(Icons.home), onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
          ),
          _buildProgressBar(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildCard(card, accentColor),
                    const SizedBox(height: 32),
                    _buildOptionsGrid(accentColor),
                  ],
                ),
              ),
            ),
          ),
          _buildNavigationFooter(),
        ],
      ),
    );
  }

  Widget _buildCard(FlashCard card, Color accentColor) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _answered ? (_isCorrectMap[_currentIndex] == true ? Colors.green : Colors.red) : accentColor, width: 3),
          boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.1), blurRadius: 20)],
        ),
        child: Column(
          children: [
            Text('What is the plural of:', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            Text(card.word, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: accentColor)),
            if (_answered) ...[
              const SizedBox(height: 24),
              Text(
                _isCorrectMap[_currentIndex] == true ? 'Correct!' : 'It is "${_correctPlural}"',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isCorrectMap[_currentIndex] == true ? Colors.green : Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsGrid(Color accentColor) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final option = _options[index];
        final isSelected = _selectedOption == option;
        final isCorrect = option == _correctPlural;
        final showResult = _answered;

        Color btnColor = Colors.white;
        Color borderColor = Colors.grey.shade300;
        
        if (showResult) {
          if (isCorrect) {
            btnColor = Colors.green.shade50;
            borderColor = Colors.green;
          } else if (isSelected) {
            btnColor = Colors.red.shade50;
            borderColor = Colors.red;
          }
        }

        return InkWell(
          onTap: () => _selectOption(option),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: btnColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Center(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: showResult && isCorrect ? Colors.green.shade800 : (showResult && isSelected ? Colors.red.shade800 : Colors.black87),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    final progress = _currentCards.isEmpty ? 0.0 : _currentIndex / _currentCards.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Text('Card ${_currentIndex + 1}/${_currentCards.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_useLivesMode) _buildLivesIndicator(),
              if (_useTimedMode) ...[const SizedBox(width: 12), _buildTimerIndicator()],
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }

  Widget _buildLivesIndicator() {
    return Row(children: List.generate(_maxLives, (i) => Icon(i < _lives ? Icons.favorite : Icons.favorite_border, color: Colors.red, size: 20)));
  }

  Widget _buildTimerIndicator() {
    return Row(children: [const Icon(Icons.timer, size: 20), const SizedBox(width: 4), Text('$_timeRemaining', style: const TextStyle(fontWeight: FontWeight.bold))]);
  }

  Widget _buildNavigationFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Row(
        children: [
          OutlinedButton(onPressed: _currentIndex > 0 ? _goPrev : null, child: const Text('Prev')),
          const Spacer(),
          FilledButton(onPressed: _answered ? _goNext : null, child: Text(_currentIndex < _currentCards.length - 1 ? 'Next' : 'Finish')),
        ],
      ),
    );
  }
}
