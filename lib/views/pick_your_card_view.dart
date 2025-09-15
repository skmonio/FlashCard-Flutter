import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:async';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../components/unified_end_screen.dart';
import '../services/xp_service.dart';
import '../services/sound_manager.dart';

class PickYourCardView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final bool shuffleMode;
  final Function(bool)? onComplete;
  final bool useTimedMode;
  final int? timePerQuestion;
  final bool autoProgress;
  final bool useLivesMode;
  final int? customLives;

  const PickYourCardView({
    super.key,
    required this.cards,
    required this.title,
    this.shuffleMode = false,
    this.onComplete,
    this.useTimedMode = false,
    this.timePerQuestion,
    this.autoProgress = false,
    this.useLivesMode = false,
    this.customLives,
  });

  @override
  State<PickYourCardView> createState() => _PickYourCardViewState();
}

class _PickYourCardViewState extends State<PickYourCardView>
    with TickerProviderStateMixin {
  int currentCardIndex = 0;
  String selectedPart1 = "";
  String selectedPart2 = "";
  String selectedPart3 = "";
  
  // RPG tracking
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  List<FlashCard> _studiedWords = [];
  int _consecutiveCorrect = 0;
  int _totalAnswers = 0;
  int _correctAnswers = 0;
  
  // Timer variables
  Timer? _timer;
  int _timeRemaining = 0;
  int _totalTime = 0;
  bool _timeUp = false;
  
  // Auto progress timer
  Timer? _autoProgressTimer;
  
  // Lives system
  int _lives = 0;
  int _maxLives = 0;
  bool _useLivesMode = false;

  List<String> wheel1Items = [];
  List<String> wheel2Items = [];
  List<String> wheel3Items = [];
  bool hasThirdWheel = false;
  
  // Result display state
  bool _showResult = false;
  bool _isLastAnswerCorrect = false;
  String _lastUserAnswer = "";
  String _lastCorrectAnswer = "";

  // Decoy letter patterns for generating similar letters
  final Map<String, List<String>> _similarLetters = {
    'a': ['e', 'i', 'o', 'u', 'aa', 'ae'],
    'e': ['a', 'i', 'o', 'u', 'ee', 'ei'],
    'i': ['a', 'e', 'o', 'u', 'ii', 'ie'],
    'o': ['a', 'e', 'i', 'u', 'oo', 'oe'],
    'u': ['a', 'e', 'i', 'o', 'uu', 'ue'],
    'k': ['c', 'g', 'q', 'ck', 'ch'],
    'c': ['k', 'g', 'q', 'ck', 'ch'],
    'g': ['k', 'c', 'q', 'gg', 'gh'],
    'h': ['g', 'j', 'ch', 'gh', 'hh'],
    'j': ['g', 'h', 'y', 'jj', 'dj'],
    'p': ['b', 'f', 'pp', 'ph'],
    'b': ['p', 'd', 'bb', 'bh'],
    'd': ['b', 't', 'dd', 'dh'],
    't': ['d', 's', 'tt', 'th'],
    's': ['t', 'z', 'ss', 'sh'],
    'z': ['s', 'x', 'zz', 'zh'],
    'f': ['p', 'v', 'ff', 'ph'],
    'v': ['f', 'w', 'vv', 'vh'],
    'w': ['v', 'u', 'ww', 'wh'],
    'm': ['n', 'mm', 'mb'],
    'n': ['m', 'ng', 'nn', 'nd'],
    'l': ['r', 'll', 'lh'],
    'r': ['l', 'rr', 'rh'],
    'y': ['j', 'i', 'yy', 'yh'],
    'x': ['z', 'ks', 'xx'],
  };

  @override
  void initState() {
    super.initState();
    
    // Initialize lives system
    _useLivesMode = widget.useLivesMode;
    if (_useLivesMode) {
      _maxLives = widget.customLives ?? _getDefaultLives();
      _lives = _maxLives;
    }
    
    // Initialize timer if using timed mode
    if (widget.useTimedMode) {
      _totalTime = widget.timePerQuestion ?? _getDefaultTimePerQuestion();
      _timeRemaining = _totalTime;
    }
    
    _loadCurrentCard();
  }
  
  int _getDefaultLives() {
    return 5; // Default 5 lives
  }
  
  int _getDefaultTimePerQuestion() {
    return 30; // Default 30 seconds per question
  }
  
  void _startTimer() {
    if (!widget.useTimedMode) return;
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeRemaining > 0) {
            _timeRemaining--;
          } else {
            _timeUp = true;
            _timer?.cancel();
            _handleTimeUp();
          }
        });
      }
    });
  }
  
  void _handleTimeUp() {
    // Auto-submit current answer when time runs out
    _checkAnswer();
  }
  
  void _resetTimer() {
    if (!widget.useTimedMode) return;
    
    _timer?.cancel();
    _timeRemaining = _totalTime;
    _timeUp = false;
    _startTimer();
  }

  @override
  void dispose() {
    // Cancel timers
    _timer?.cancel();
    _autoProgressTimer?.cancel();
    super.dispose();
  }

  void _loadCurrentCard() {
    if (currentCardIndex >= widget.cards.length) return;
    
    final FlashCard card = widget.cards[currentCardIndex];
    final String dutch = card.word;
    
    // Start timer if using timed mode
    if (widget.useTimedMode) {
      _resetTimer();
    }
    
    // Split word into equal-length pieces
    final List<String> parts = _splitWordIntoEqualParts(dutch);
    
    if (parts.length == 2) {
      hasThirdWheel = false;
      wheel1Items = _generateWheelItems(parts[0], 1);
      wheel2Items = _generateWheelItems(parts[1], 2);
      wheel3Items = [];
      
      selectedPart1 = wheel1Items.first;
      selectedPart2 = wheel2Items.first;
      selectedPart3 = "";
    } else if (parts.length == 3) {
      hasThirdWheel = true;
      wheel1Items = _generateWheelItems(parts[0], 1);
      wheel2Items = _generateWheelItems(parts[1], 2);
      wheel3Items = _generateWheelItems(parts[2], 3);
      
      selectedPart1 = wheel1Items.first;
      selectedPart2 = wheel2Items.first;
      selectedPart3 = wheel3Items.first;
    } else {
      // For words with more than 3 parts, combine some parts
      hasThirdWheel = false;
      final String part1 = parts[0];
      final String part2 = parts.sublist(1).join('');
      
      wheel1Items = _generateWheelItems(part1, 1);
      wheel2Items = _generateWheelItems(part2, 2);
      wheel3Items = [];
      
      selectedPart1 = wheel1Items.first;
      selectedPart2 = wheel2Items.first;
      selectedPart3 = "";
    }
  }

  List<String> _splitWordIntoEqualParts(String word) {
    if (word.length <= 4) {
      // Short words: split into 2 parts
      final int mid = (word.length / 2).ceil();
      return [word.substring(0, mid), word.substring(mid)];
    } else if (word.length <= 9) {
      // Medium words: split into 3 parts
      final int partLength = (word.length / 3).ceil();
      final List<String> parts = [];
      for (int i = 0; i < word.length; i += partLength) {
        parts.add(word.substring(i, min(i + partLength, word.length)));
      }
      return parts;
    } else {
      // Long words: split into 3 parts with more equal distribution
      final int partLength = (word.length / 3).ceil();
      return [
        word.substring(0, partLength),
        word.substring(partLength, partLength * 2),
        word.substring(partLength * 2),
      ];
    }
  }

  List<String> _generateWheelItems(String correctPart, int wheelIndex) {
    final Set<String> uniqueOptions = {correctPart};
    
    // Generate similar decoy letters based on the correct part
    for (int i = 0; i < correctPart.length; i++) {
      final String char = correctPart[i].toLowerCase();
      if (_similarLetters.containsKey(char)) {
        final List<String> similar = _similarLetters[char]!;
        for (final similarChar in similar) {
          if (similarChar.length == 1) {
            // Single character replacement
            final String decoy = correctPart.substring(0, i) + 
                               similarChar + 
                               correctPart.substring(i + 1);
            if (decoy != correctPart) {
              uniqueOptions.add(decoy);
            }
          }
        }
      }
    }
    
    // Add some random combinations if we don't have enough
    final Random random = Random();
    while (uniqueOptions.length < 5) {
      String decoy = "";
      for (int i = 0; i < correctPart.length; i++) {
        final List<String> consonants = ['b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'p', 'q', 'r', 's', 't', 'v', 'w', 'x', 'y', 'z'];
        final List<String> vowels = ['a', 'e', 'i', 'o', 'u'];
        final List<String> letters = random.nextBool() ? consonants : vowels;
        decoy += letters[random.nextInt(letters.length)];
      }
      if (decoy != correctPart) {
        uniqueOptions.add(decoy);
      }
    }
    
    final List<String> items = uniqueOptions.toList();
    items.shuffle();
    return items;
  }

  void _checkAnswer() {
    if (currentCardIndex >= widget.cards.length) return;
    
    // Stop timer if using timed mode
    if (widget.useTimedMode) {
      _timer?.cancel();
    }
    
    final FlashCard currentCard = widget.cards[currentCardIndex];
    final String correctAnswer = currentCard.word;
    
    String userAnswer;
    if (hasThirdWheel) {
      userAnswer = selectedPart1 + selectedPart2 + selectedPart3;
    } else {
      userAnswer = selectedPart1 + selectedPart2;
    }
    
    final bool isCorrect = userAnswer.toLowerCase() == correctAnswer.toLowerCase();
    final provider = context.read<FlashcardProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();
    
    // Track the studied word
    if (!_studiedWords.contains(currentCard)) {
      _studiedWords.add(currentCard);
    }
    
    if (isCorrect) {
      currentCard.markCorrect(GameDifficulty.medium);
      _correctAnswers++;
      _consecutiveCorrect++;
      
      // Award XP using standard system
      final xpService = XpService();
      
      print('🔍 PickYourCardView: About to award XP to word "${currentCard.word}" - daily attempts before: ${currentCard.learningMastery.dailyAttemptsDebug}');
      
      // Add XP to the word's learning mastery (this handles daily diminishing returns)
      xpService.addXPToWord(currentCard.learningMastery, "pickYourCard", 1);
      
      // Get the actual XP gained (after diminishing returns)
      final actualXPGained = currentCard.learningMastery.exerciseHistory.isNotEmpty 
          ? currentCard.learningMastery.exerciseHistory.last['xpGained'] as int 
          : 0;
      
      // Track XP gained for this word in this session
      _xpGainedPerWord[currentCard.id] = actualXPGained;
      
      // Update user profile
      userProfileProvider.addXp(actualXPGained);
      
      print('🔍 PickYourCardView: Awarded $actualXPGained XP to word "${currentCard.word}" - daily attempts after: ${currentCard.learningMastery.dailyAttemptsDebug}');
      
      // Play correct sound
      SoundManager().playCorrectSound();
      
      _showResultDialog(true, userAnswer, correctAnswer);
    } else {
      currentCard.markIncorrect(GameDifficulty.medium);
      _consecutiveCorrect = 0;
      _xpGainedPerWord[currentCard.id] = 0;
      
      // Handle lives system
      if (_useLivesMode) {
        _lives--;
        print('🔍 PickYourCardView: Lost a life! Lives remaining: $_lives');
        
        if (_lives <= 0) {
          print('🔍 PickYourCardView: Game over! No lives remaining');
          _showGameOverScreen();
          return;
        }
      }
      
      print('🔍 PickYourCardView: No XP awarded to word "${currentCard.word}" (Incorrect)');
      
      // Play wrong sound
      SoundManager().playWrongSound();
      
      _showResultDialog(false, userAnswer, correctAnswer);
    }
    
    // Update mastery tracking
    _wordMastery[currentCard.id] = currentCard.learningMastery;
    
    // Save to provider
    provider.updateCard(currentCard);
    _totalAnswers++;
    
    // Auto progress logic
    if (widget.autoProgress) {
      _autoProgressTimer?.cancel();
      _autoProgressTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && currentCardIndex < widget.cards.length - 1) {
          _nextCard();
        }
      });
    }
  }

  void _showResultDialog(bool isCorrect, String userAnswer, String correctAnswer) {
    // Show result without dialog - just update the UI state
    setState(() {
      _showResult = true;
      _isLastAnswerCorrect = isCorrect;
      _lastUserAnswer = userAnswer;
      _lastCorrectAnswer = correctAnswer;
    });
  }
  
  void _showGameOverScreen() {
    // Show game over screen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Text('You ran out of lives! You got $_correctAnswers out of $_totalAnswers correct.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showResults();
            },
            child: const Text('View Results'),
          ),
          TextButton(
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

  void _nextCard() {
    if (currentCardIndex + 1 < widget.cards.length) {
      setState(() {
        currentCardIndex++;
        _showResult = false; // Reset result display
        _loadCurrentCard();
      });
    } else {
      // In shuffle mode, call onComplete callback instead of showing end screen
      if (widget.shuffleMode && widget.onComplete != null) {
        final wasCorrect = _correctAnswers > 0; // Consider it successful if at least one correct
        widget.onComplete!(wasCorrect);
        return;
      }
      
      _showResults();
    }
  }

  void _showResults() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => UnifiedEndScreen(
          studiedWords: _studiedWords,
          xpGainedPerWord: _xpGainedPerWord,
          wordMastery: _wordMastery,
          title: 'Pick Your Card Complete',
          showSwipeToReview: false,
          onStudyAgain: () {
            setState(() {
              currentCardIndex = 0;
              _studiedWords.clear();
              _xpGainedPerWord.clear();
              _wordMastery.clear();
              _consecutiveCorrect = 0;
              _totalAnswers = 0;
              _correctAnswers = 0;
              _loadCurrentCard();
            });
            Navigator.of(context).pop();
          },
          onDone: () {
            Navigator.of(context).pop(); // Close end screen
            Navigator.of(context).pop(); // Go back to study type screen
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('No cards available for study'),
        ),
      );
    }

    if (currentCardIndex >= widget.cards.length) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('All cards completed!'),
        ),
      );
    }

    final FlashCard currentCard = widget.cards[currentCardIndex];
    final progress = _totalAnswers / widget.cards.length;

    return WillPopScope(
      onWillPop: () async {
        // Show exit confirmation dialog
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Game'),
            content: const Text('Are you sure you want to exit? Your progress will be saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        return shouldExit ?? false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            // Fixed Header - matching standard header
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
                child: _buildCustomHeader(context),
              ),
            ),
            
            // Progress bar
            _buildProgressBar(),
            
            // Timer display (if using timed mode)
            if (widget.useTimedMode) _buildTimerDisplay(),
            
            // Lives display (if using lives mode)
            if (_useLivesMode) _buildLivesDisplay(),
            
            // Main content
            Expanded(
              child: _buildMainContent(currentCard),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Container(
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
            'Pick Your Card',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = currentCardIndex / widget.cards.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${currentCardIndex + 1} of ${widget.cards.length}'),
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
  
  Widget _buildTimerDisplay() {
    if (!widget.useTimedMode) return const SizedBox.shrink();
    
    final progress = _timeRemaining / _totalTime;
    Color timerColor = Colors.green;
    if (progress < 0.3) {
      timerColor = Colors.red;
    } else if (progress < 0.6) {
      timerColor = Colors.orange;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer,
                color: timerColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$_timeRemaining seconds',
                style: TextStyle(
                  color: timerColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(timerColor),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
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

  Widget _buildMainContent(FlashCard currentCard) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // English word to translate (simple text, no bubble)
          Text(
            "Translate '${currentCard.definition}'",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 40),
          
          // Wheels
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DialWheel(
                key: ValueKey<int>(currentCardIndex * 3),
                items: wheel1Items,
                onChanged: (value) => setState(() => selectedPart1 = value),
                enabled: !_showResult || !widget.autoProgress,
              ),
              const SizedBox(width: 20),
              DialWheel(
                key: ValueKey<int>(currentCardIndex * 3 + 1),
                items: wheel2Items,
                onChanged: (value) => setState(() => selectedPart2 = value),
                enabled: !_showResult || !widget.autoProgress,
              ),
              if (hasThirdWheel) ...[
                const SizedBox(width: 20),
                DialWheel(
                  key: ValueKey<int>(currentCardIndex * 3 + 2),
                  items: wheel3Items,
                  onChanged: (value) => setState(() => selectedPart3 = value),
                  enabled: !_showResult || !widget.autoProgress,
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 40),
          
          // Navigation buttons (always visible, greyed out when not available)
          Row(
            children: [
              // Back button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: currentCardIndex > 0 ? () {
                    setState(() {
                      currentCardIndex--;
                      _showResult = false;
                      _loadCurrentCard();
                    });
                  } : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  label: const Text('Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentCardIndex > 0 ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Next/Finish button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showResult ? _nextCard : null,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(currentCardIndex == widget.cards.length - 1 ? 'Finish' : 'Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showResult ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Current selection display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueGrey.shade300),
            ),
            child: Text(
              hasThirdWheel 
                ? '$selectedPart1$selectedPart2$selectedPart3'
                : '$selectedPart1$selectedPart2',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Check Answer button (only show if not showing result)
          if (!_showResult)
            ElevatedButton(
              onPressed: _checkAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Check Answer",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          
          // Result display (if showing result) - simple red text
          if (_showResult) ...[
            const SizedBox(height: 20),
            Text(
              _isLastAnswerCorrect 
                ? "Correct!"
                : "Correct answer is: $_lastCorrectAnswer",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isLastAnswerCorrect ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

}

class DialWheel extends StatefulWidget {
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const DialWheel({super.key, required this.items, required this.onChanged, this.enabled = true});

  @override
  State<DialWheel> createState() => _DialWheelState();
}

class _DialWheelState extends State<DialWheel> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  double _currentAngle = 0.0;
  late double _itemAngle;

  double _startDragDy = 0.0;
  double _startDragAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _itemAngle = 2 * pi / widget.items.length;
    _controller = AnimationController(vsync: this);

    // Report the initial visible item immediately
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportSelection());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getSelectedItem() {
    int index = ((-_currentAngle / _itemAngle).round() % widget.items.length + widget.items.length) % widget.items.length;
    return widget.items[index];
  }

  void _reportSelection() => widget.onChanged(_getSelectedItem());

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    _controller.stop();
    _startDragDy = details.localPosition.dy;
    _startDragAngle = _currentAngle;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _currentAngle = _startDragAngle + (details.localPosition.dy - _startDragDy) / 60.0;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    final double velocity = details.primaryVelocity ?? 0.0;
    double spinDistance = velocity / 200;
    double rawTargetAngle = _currentAngle + spinDistance;
    double snappedTargetAngle = (rawTargetAngle / _itemAngle).round() * _itemAngle;

    _animation = Tween<double>(begin: _currentAngle, end: snappedTargetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.decelerate),
    );

    _controller
      ..duration = const Duration(milliseconds: 400)
      ..reset()
      ..addListener(() {
        setState(() => _currentAngle = _animation.value);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _currentAngle = snappedTargetAngle;
          _reportSelection();
        }
      })
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final double centerIndex = -_currentAngle / _itemAngle;
    final double normalizedCenter = (centerIndex % widget.items.length + widget.items.length) % widget.items.length;

    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Container(
        width: 100,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.shade400, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          alignment: Alignment.center,
          children: widget.items.asMap().entries.map<Widget>((entry) {
            int index = entry.key;
            String item = entry.value;

            double diff = index - normalizedCenter;
            if (diff > widget.items.length / 2) diff -= widget.items.length;
            if (diff < -widget.items.length / 2) diff += widget.items.length;

            double dy = diff * 60;
            double t = (dy.abs() / 120).clamp(0.0, 1.0);
            double opacity = lerp(1.0, 0.4, t);
            double scale = lerp(1.0, 0.7, t);
            bool isCenter = diff.abs() < 0.5;

            return Transform.scale(
              scale: scale,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCenter ? Colors.lightBlue.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCenter ? Colors.blue.shade600 : Colors.grey.shade400,
                        width: isCenter ? 2.5 : 1.5,
                      ),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: isCenter ? 26 : 20,
                        fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
                        color: isCenter ? Colors.blue.shade900 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  double lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);
}
