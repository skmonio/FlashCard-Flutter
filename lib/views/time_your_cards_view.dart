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
import '../utils/card_color_utils.dart';
import '../components/main_header.dart';

class TimeYourCardsView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final bool useLivesMode;
  final int? customLives;
  final bool useTimedMode;
  final TimedDifficulty? timedDifficulty;
  final StudyConfig? studyConfig;

  const TimeYourCardsView({
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
  State<TimeYourCardsView> createState() => _TimeYourCardsViewState();
}

class _TimeYourCardsViewState extends State<TimeYourCardsView> with TickerProviderStateMixin {
  late List<FlashCard> _currentCards;
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAttempts = 0;
  bool _showingResults = false;
  bool _endScreenShown = false;
  bool _answered = false;
  String? _selectedOption;
  String? _correctTenseValue;
  String? _currentTenseLabel;
  List<String> _options = [];

  final GameSession _gameSession = GameSession();
  Map<int, String> _answeredQuestions = {}; 
  Map<int, bool> _isCorrectMap = {};
  Map<int, List<String>> _questionOptions = {};
  Map<int, String> _questionTenseLabels = {};

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

    // Only keep cards that have at least one verb form
    _currentCards = widget.cards
        .where((c) => c.presentTense.isNotEmpty || c.pastTense.isNotEmpty || c.perfectTense.isNotEmpty)
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
        return 12;
      case TimedDifficulty.hard:
        return 6;
      default:
        return 8;
    }
  }

  Color _getCardBorderColor(FlashCard card) {
    return CardColorUtils.getBorderColor(card);
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
        _currentTenseLabel = _questionTenseLabels[_currentIndex];
        final card = _currentCards[_currentIndex];
        if (_currentTenseLabel!.contains('Present')) _correctTenseValue = card.presentTense;
        else if (_currentTenseLabel!.contains('Past')) _correctTenseValue = card.pastTense;
        else _correctTenseValue = card.perfectTense;
        _answered = true;
      });
      return;
    }

    final card = _currentCards[_currentIndex];
    
    // Pick a tense randomly from what the card has
    List<MapEntry<String, String>> availableTenses = [];
    if (card.presentTense.isNotEmpty) availableTenses.add(const MapEntry('Present Tense - Tegenwoordige Tijd', 'present'));
    if (card.pastTense.isNotEmpty) availableTenses.add(const MapEntry('Past Tense - Verleden Tijd', 'past'));
    if (card.perfectTense.isNotEmpty) availableTenses.add(const MapEntry('Perfect Tense - Voltooide Tijd', 'perfect'));

    final tenseToAsk = availableTenses[Random().nextInt(availableTenses.length)];
    final correctValue = tenseToAsk.value == 'present' 
        ? card.presentTense 
        : (tenseToAsk.value == 'past' ? card.pastTense : card.perfectTense);
    
    // Generate decoys
    List<String> options = _generateTenseOptions(card, correctValue, tenseToAsk.key);

    setState(() {
      _answered = false;
      _selectedOption = null;
      _correctTenseValue = correctValue;
      _currentTenseLabel = tenseToAsk.key;
      _options = options;
      _questionOptions[_currentIndex] = options;
      _questionTenseLabels[_currentIndex] = tenseToAsk.key;
      _timeUp = false;
    });

    _scaleController.forward(from: 0);
    if (_useTimedMode) _startTimer();
  }

  List<String> _generateTenseOptions(FlashCard card, String correct, String tenseLabel) {
    Set<String> options = {correct};
    
    // 1. Decoy: Other tenses of the same card
    if (card.presentTense.isNotEmpty && card.presentTense != correct) options.add(card.presentTense);
    if (card.pastTense.isNotEmpty && card.pastTense != correct) options.add(card.pastTense);
    if (card.perfectTense.isNotEmpty && card.perfectTense != correct) options.add(card.perfectTense);
    
    // 2. Decoy: Word itself (infinitive)
    if (card.word != correct) options.add(card.word);

    // 3. Decoy: Common Dutch verb variations if still need more
    if (options.length < 4) {
      if (!options.contains(card.word + "t")) options.add(card.word + "t");
      if (options.length < 4 && !options.contains("ge" + card.word)) options.add("ge" + card.word);
    }

    // 4. Fallback from other cards' tenses if needed
    if (options.length < 4) {
      final allCards = context.read<FlashcardProvider>().cards;
      final shuffledCards = List<FlashCard>.from(allCards)..shuffle();
      for (var other in shuffledCards) {
        if (options.length >= 4) break;
        if (other.id == card.id) continue;
        
        List<String> otherValues = [other.presentTense, other.pastTense, other.perfectTense]
            .where((s) => s.isNotEmpty && s != correct).toList();
        if (otherValues.isNotEmpty) {
          options.add(otherValues[Random().nextInt(otherValues.length)]);
        }
      }
    }

    List<String> result = options.toList();
    result.shuffle();
    return result.take(4).toList();
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
    final isCorrect = chosen != null && chosen == _correctTenseValue;

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
      _selectedOption = chosen;
      _answered = true;
      _totalAttempts++;
      _answeredQuestions[_currentIndex] = chosen ?? '__timeout__';
      _isCorrectMap[_currentIndex] = isCorrect;

      if (isCorrect) {
        _correctAnswers++;
      } else if (_useLivesMode) {
        _lives--;
        if (_lives <= 0) livesRanOut = true;
      }
    });
    if (livesRanOut) {
      _finishSession();
      return;
    }

    _autoProgressTimer?.cancel();
    _autoProgressTimer = Timer(const Duration(milliseconds: 1400), () {
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
    setState(() => _showingResults = true);
    await _finalizeSession();
    if (mounted && !_endScreenShown) {
      _endScreenShown = true;
      _showEndScreen();
    }
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
      card.markCorrectAs('time_your_cards', GameDifficulty.medium);
    } else {
      card.markIncorrectAs('time_your_cards', GameDifficulty.medium);
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
                    builder: (context) => TimeYourCardsView(
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
    if (_currentCards.isEmpty) {
      return Scaffold(
        body: Column(
          children: [
            MainHeader(title: widget.title, leftAction: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => Navigator.of(context).pop())),
            const Expanded(child: Center(child: Text('No cards with verb forms found.'))),
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
                    _buildQuestionCard(card, accentColor),
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

  Widget _buildQuestionCard(FlashCard card, Color accentColor) {
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
            Text('What is the:', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            const SizedBox(height: 8),
            Text(_currentTenseLabel ?? '', 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor)),
            const SizedBox(height: 16),
            Text('for', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Text(card.word, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            if (_answered) ...[
              const SizedBox(height: 24),
              Text(
                _isCorrectMap[_currentIndex] == true ? 'Correct!' : 'It is "${_correctTenseValue}"',
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
        childAspectRatio: 2.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final option = _options[index];
        final isSelected = _selectedOption == option;
        final isCorrect = option == _correctTenseValue;
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  option,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: showResult && isCorrect ? Colors.green.shade800 : (showResult && isSelected ? Colors.red.shade800 : Colors.black87),
                  ),
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
