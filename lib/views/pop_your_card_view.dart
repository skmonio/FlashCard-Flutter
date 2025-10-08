import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/scheduler.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../components/word_progress_display.dart';
import '../services/xp_service.dart';
import '../services/sound_manager.dart';
import '../services/haptic_service.dart';
import 'package:provider/provider.dart';

class PopYourCardView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final bool shuffleMode;
  final Function(bool)? onComplete;
  final bool useLivesMode;
  final int? customLives;
  final bool useTimedMode;
  final int? timePerQuestion;

  const PopYourCardView({
    super.key,
    required this.cards,
    required this.title,
    this.shuffleMode = false,
    this.onComplete,
    this.useLivesMode = false,
    this.customLives,
    this.useTimedMode = false,
    this.timePerQuestion,
  });

  @override
  State<PopYourCardView> createState() => _PopYourCardViewState();
}

class _PopYourCardViewState extends State<PopYourCardView>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalQuestions = 0;
  DateTime? _sessionStartTime;
  int _sessionXP = 0;
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  List<FlashCard> _studiedWords = [];

  // Lives and timer system
  bool _useLivesMode = false;
  bool _useTimedMode = false;
  int _lives = 0;
  int _maxLives = 0;
  int _timeRemaining = 0;
  int _totalTime = 0;
  Timer? _timer;
  bool _timeUp = false;

  List<Bubble> bubbles = [];
  final Random random = Random();

  late Ticker _ticker;
  double _screenWidth = 0;
  double _screenHeight = 0;
  double _lastPhysicsUpdate = 0;

  static const double _bubbleBaseSpeed = 100.0;
  double _bubbleHeight = 60.0; // Made responsive
  double _minBubbleWidth = 80.0; // Made responsive
  double _maxBubbleWidth = 300.0; // Made responsive

  final List<Color> outlineColors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.brown,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_updatePhysics)..start();
    _sessionStartTime = DateTime.now();
    _totalQuestions = widget.cards.length;
    
    // Initialize lives system
    _useLivesMode = widget.useLivesMode;
    if (_useLivesMode) {
      _maxLives = widget.customLives ?? _getDefaultLives();
      _lives = _maxLives;
    }
    
    // Initialize timer if using timed mode
    _useTimedMode = widget.useTimedMode;
    if (_useTimedMode) {
      _totalTime = widget.timePerQuestion ?? _getDefaultTimePerQuestion();
      _timeRemaining = _totalTime;
    }
    
    _loadCurrentCard();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _timer?.cancel();
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
            _timeUp = true;
            _timer?.cancel();
            _handleTimeUp();
          }
        });
      }
    });
  }
  
  void _handleTimeUp() {
    // Time's up - mark as incorrect and move to next question
    _nextCard();
  }

  void _showGameOverScreen() {
    // Show results when game is over
    _showFinalXPSummary();
  }

  void _loadCurrentCard() {
    if (_currentIndex >= widget.cards.length) {
      // Don't show results here - _nextCard() will handle completion
      return;
    }

    if (widget.cards.isEmpty) {
      print('❌ PopYourCardView: No cards available');
      return;
    }

    // Reset timer and time up flag for new card
    _timeUp = false;
    if (_useTimedMode) {
      _timeRemaining = _totalTime;
      _startTimer();
    }

    bubbles.clear();
    final currentCard = widget.cards[_currentIndex];
    final String correctDutchWord = currentCard.word;

    final List<String> bubbleTexts = <String>[correctDutchWord];
    while (bubbleTexts.length < 6) {
      String decoy = _generateDecoy(correctDutchWord);
      if (!bubbleTexts.contains(decoy)) bubbleTexts.add(decoy);
    }
    bubbleTexts.shuffle();

    _lastPhysicsUpdate = 0;

    if (_screenWidth > 0 && _screenHeight > 0) {
      _initializeBubblePositionsAndVelocities(bubbleTexts);
    } else {
      // Create bubbles with default positions that will be updated when screen dimensions are available
      bubbles = bubbleTexts.map<Bubble>((text) {
        double width = _calculateBubbleWidth(text);
        return Bubble(
          text: text,
          initialX: 50, // Default position
          initialY: 50, // Default position
          vx: 0,
          vy: 0,
          outlineColor: outlineColors[random.nextInt(outlineColors.length)],
          width: width,
          height: _bubbleHeight,
        );
      }).toList();
    }
    setState(() {});
  }

  double _calculateBubbleWidth(String word) {
    // Calculate width based on character count with more generous spacing
    double calculatedWidth = word.length * 28.0 + 50.0; // Increased for better text fit
    
    // Safety check for screen width
    if (_screenWidth <= 0) {
      return calculatedWidth.clamp(100.0, 400.0); // Increased fallback values
    }
    
    // Use responsive max width based on screen size
    double maxWidth = _screenWidth * 0.7; // Increased to 70% for larger devices
    return calculatedWidth.clamp(_minBubbleWidth, maxWidth);
  }

  void _initializeBubblePositionsAndVelocities(List<String> texts) {
    bubbles.clear();
    
    // Safety check for screen dimensions
    if (_screenWidth <= 0 || _screenHeight <= 0) {
      print('🔍 PopYourCardView: Screen dimensions not ready, skipping bubble initialization');
      return;
    }
    
    for (final text in texts) {
      double speedMagnitude = _bubbleBaseSpeed + random.nextDouble() * 50.0;
      double angle = random.nextDouble() * 2 * pi;

      double width = _calculateBubbleWidth(text);

      // Additional safety checks for positioning
      double availableWidth = _screenWidth - width;
      double availableHeight = _screenHeight - _bubbleHeight;
      
      if (availableWidth <= 0 || availableHeight <= 0) {
        print('🔍 PopYourCardView: Insufficient space for bubble, skipping');
        continue;
      }

      double initialX = random.nextDouble() * availableWidth;
      double initialY = random.nextDouble() * availableHeight;

      bubbles.add(Bubble(
        text: text,
        initialX: initialX,
        initialY: initialY,
        vx: cos(angle) * speedMagnitude,
        vy: sin(angle) * speedMagnitude,
        outlineColor: outlineColors[random.nextInt(outlineColors.length)],
        width: width,
        height: _bubbleHeight,
      ));
    }
  }

  String _generateDecoy(String word) {
    if (word.length < 3) return '${word}x';
    int i = random.nextInt(word.length);
    String letter = word[i];
    int charCode = letter.codeUnitAt(0);
    int newCharCode;
    do {
      int offset = random.nextBool() ? 1 : -1;
      newCharCode = charCode + offset;
    } while (newCharCode < 97 || newCharCode > 122);
    return word.substring(0, i) + String.fromCharCode(newCharCode) + word.substring(i + 1);
  }

  void _onBubbleTap(Bubble tappedBubble) {
    if (_currentIndex >= widget.cards.length) {
      print('❌ PopYourCardView: Invalid card index: $_currentIndex');
      return;
    }

    final currentCard = widget.cards[_currentIndex];
    final correct = currentCard.word;
    bool isCorrect = tappedBubble.text == correct;

    // Stop timer if using timed mode
    if (_useTimedMode) {
      _timer?.cancel();
    }

    // Play pop sound when bubble is tapped
    SoundManager().playPopSound();

    _ticker.stop();

    // Track the studied word
    if (!_studiedWords.contains(currentCard)) {
      _studiedWords.add(currentCard);
    }

    if (isCorrect) {
      _correctAnswers++;
      _awardXP(currentCard);
      // Mark the card as correct to properly record the attempt and reduce HP
      currentCard.markCorrect(GameDifficulty.medium);
      HapticService().successFeedback();
    } else {
      // Track incorrect answers with 0 XP
      _xpGainedPerWord[currentCard.id] = 0;
      // Mark the card as incorrect to properly record the attempt and reduce HP
      currentCard.markIncorrect(GameDifficulty.medium);
      HapticService().errorFeedback();
      
      // Handle lives mode
      if (_useLivesMode) {
        _lives--;
        print('🔍 PopYourCardView: Lost a life! Lives remaining: $_lives');
        
        // Check if game over
        if (_lives <= 0) {
          print('🔍 PopYourCardView: Game over! No lives remaining');
          _showGameOverScreen();
          return;
        }
      }
    }

    // Update mastery tracking for both correct and incorrect answers
    _wordMastery[currentCard.id] = currentCard.learningMastery;

    setState(() {});

    // Show simple XP feedback and proceed to next card
    _showCardXPFeedback(currentCard, isCorrect, correct);
  }

  void _nextCard() {
    _currentIndex++;
    if (_currentIndex < widget.cards.length) {
      _loadCurrentCard();
    } else {
      // In shuffle mode, call onComplete callback instead of showing end screen
      if (widget.shuffleMode && widget.onComplete != null) {
        final wasCorrect = _correctAnswers > 0; // Consider it successful if at least one correct
        widget.onComplete!(wasCorrect);
        return;
      }
      
      // Skip results screen and show final XP summary
      _showFinalXPSummary();
    }
  }

  void _awardXP(FlashCard card) {
    final provider = context.read<FlashcardProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();
    final xpService = XpService();
    
    print('🔍 PopYourCardView: About to award XP to word "${card.word}" - daily attempts before: ${card.learningMastery.dailyAttemptsDebug}');
    
    // Add XP to the word's learning mastery (this handles daily diminishing returns)
    xpService.addXPToWord(card.learningMastery, "popYourCard", 1);
    
    // Get the actual XP gained (after diminishing returns)
    final actualXPGained = card.learningMastery.exerciseHistory.isNotEmpty 
        ? card.learningMastery.exerciseHistory.last['xpGained'] as int 
        : 0;
    
    // Track XP gained for this word in this session
    _xpGainedPerWord[card.id] = actualXPGained;
    _sessionXP += actualXPGained;
    
    // Award XP to user profile (async but we don't await it)
    userProfileProvider.addXp(actualXPGained);
    
    // Update the card in the provider
    provider.updateCard(card);
    
    print('🔍 PopYourCardView: Awarded $actualXPGained XP to word "${card.word}" - daily attempts after: ${card.learningMastery.dailyAttemptsDebug}');
  }

  void _showCardXPFeedback(FlashCard card, bool isCorrect, String correctAnswer) {
    final xpGained = isCorrect ? _xpGainedPerWord[card.id] ?? 0 : 0;
    
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          isCorrect ? "Correct!" : "Wrong!",
          style: TextStyle(
            color: isCorrect ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("The correct answer was: $correctAnswer"),
            if (isCorrect && xpGained > 0) ...[
              const SizedBox(height: 8),
              Text(
                "+$xpGained XP",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Add a small delay to prevent rapid state changes
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  _nextCard();
                  // Only restart ticker if we're still on the same screen (not navigating away)
                  if (mounted && _currentIndex < widget.cards.length) {
                    _ticker.start();
                  }
                }
              });
            },
            child: const Text("Next"),
          ),
        ],
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
    
    // Navigate to new Pop Your Card game with new cards
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PopYourCardView(
          cards: newCards,
          title: widget.title,
        ),
      ),
    );
  }

  void _showFinalXPSummary() {
    final totalXPGained = _xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp);
    final accuracy = _totalQuestions > 0 ? (_correctAnswers / _totalQuestions) : 0.0;
    final isPerfect = _correctAnswers == _totalQuestions && _totalQuestions > 0;

    // Update user profile with session stats
    context.read<UserProfileProvider>().updateSessionStats(
      cardsStudied: _totalQuestions,
      sessionAccuracy: accuracy,
      isPerfect: isPerfect,
    );

    // Update streak
    context.read<UserProfileProvider>().updateStreakFromStudyActivity();

    // Show the proper card XP screen like other games
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordProgressDisplay(
          studiedWords: _studiedWords,
          xpGainedPerWord: _xpGainedPerWord,
          wordMastery: _wordMastery,
          hideNavigation: false,
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close word progress screen
            Navigator.of(context).pop(); // Go back to study type screen
            // Restart the game with the same cards
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PopYourCardView(
                  cards: widget.cards,
                  title: widget.title,
                ),
              ),
            );
          },
          onShuffle: () {
            Navigator.of(context).pop(); // Close word progress screen
            Navigator.of(context).pop(); // Go back to study type screen
            _shuffleAndRestart();
          },
          onDone: () {
            Navigator.of(context).pop(); // Close word progress screen
            Navigator.of(context).pop(); // Go back to study type screen
          },
        ),
      ),
    );
  }


  void _updatePhysics(Duration elapsed) {
    if (_screenWidth <= 0 || _screenHeight <= 0) return;
    
    // Re-initialize bubbles if they haven't been properly positioned yet
    if (bubbles.any((b) => b.vx == 0 && b.vy == 0)) {
      _initializeBubblePositionsAndVelocities(
          bubbles.map((b) => b.text).toList());
    }

    final double currentTime = elapsed.inMicroseconds.toDouble();
    double dt =
        (currentTime - _lastPhysicsUpdate) / Duration.microsecondsPerSecond;
    _lastPhysicsUpdate = currentTime;
    if (dt > 0.1) dt = 1 / 60.0;

    setState(() {
      for (final b in bubbles) {
        b.centerX += b.vx * dt;
        b.centerY += b.vy * dt;

        // Wall collisions
        if (b.left < 0) {
          b.centerX = b.width / 2;
          b.vx = -b.vx;
        } else if (b.right > _screenWidth) {
          b.centerX = _screenWidth - b.width / 2;
          b.vx = -b.vx;
        }
        if (b.top < 0) {
          b.centerY = b.height / 2;
          b.vy = -b.vy;
        } else if (b.bottom > _screenHeight) {
          b.centerY = _screenHeight - b.height / 2;
          b.vy = -b.vy;
        }
      }

      // Bubble-bubble collisions (AABB)
      for (int i = 0; i < bubbles.length; i++) {
        for (int j = i + 1; j < bubbles.length; j++) {
          final Bubble b1 = bubbles[i];
          final Bubble b2 = bubbles[j];

          bool collision = b1.left < b2.right &&
              b1.right > b2.left &&
              b1.top < b2.bottom &&
              b1.bottom > b2.top;

          if (collision) {
            double overlapX = min(b1.right, b2.right) - max(b1.left, b2.left);
            double overlapY = min(b1.bottom, b2.bottom) - max(b1.top, b2.top);

            if (overlapX < overlapY) {
              if (b1.centerX < b2.centerX) {
                b1.centerX -= overlapX / 2;
                b2.centerX += overlapX / 2;
              } else {
                b1.centerX += overlapX / 2;
                b2.centerX -= overlapX / 2;
              }
              double temp = b1.vx;
              b1.vx = b2.vx;
              b2.vx = temp;
            } else {
              if (b1.centerY < b2.centerY) {
                b1.centerY -= overlapY / 2;
                b2.centerY += overlapY / 2;
              } else {
                b1.centerY += overlapY / 2;
                b2.centerY -= overlapY / 2;
              }
              double temp = b1.vy;
              b1.vy = b2.vy;
              b2.vy = temp;
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('No cards available for this game'),
        ),
      );
    }

    if (_currentIndex >= widget.cards.length) {
      // This should not happen since _nextCard() handles completion
      return const Scaffold(
        body: Center(
          child: Text('Game Complete'),
        ),
      );
    }

    final currentCard = widget.cards[_currentIndex];
    final progress = _currentIndex / widget.cards.length;

    return WillPopScope(
      onWillPop: () async {
        return await _showCloseConfirmation();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldExit = await _showCloseConfirmation();
              if (shouldExit) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () => _showHomeConfirmation(),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            _screenWidth = constraints.maxWidth;
            _screenHeight = constraints.maxHeight;
            
            // Make bubbles responsive to screen size
            _bubbleHeight = _screenHeight * 0.12; // 12% of screen height for better text display
            _minBubbleWidth = _screenWidth * 0.2; // 20% of screen width (increased for better text fit)
            _maxBubbleWidth = _screenWidth * 0.7; // 70% of screen width (increased for larger devices)
            if (bubbles.any((b) => b.vx == 0 && b.vy == 0)) {
              _initializeBubblePositionsAndVelocities(
                  bubbles.map((b) => b.text).toList());
            }
            return Column(
              children: [
                // Progress section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${_currentIndex + 1}/${widget.cards.length}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          // Show lives or timer in the middle if active
                          if (_useLivesMode) _buildLivesIndicator(),
                          if (_useTimedMode) _buildTimerIndicator(),
                          Text(
                            "${(progress * 100).round()}%",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Question text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Translate '${currentCard.definition}'",
                    style: TextStyle(
                      fontSize: _getAdaptiveQuestionFontSize(context),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                // Bubbles area
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, bubbleConstraints) {
                      // Update screen dimensions to match the actual bubble area
                      _screenWidth = bubbleConstraints.maxWidth;
                      _screenHeight = bubbleConstraints.maxHeight;
                      
                      return Stack(
                        children: [
                          ...bubbles.map((bubble) {
                            return AnimatedBubble(
                              key: ValueKey(bubble.text),
                              bubble: bubble,
                              onTap: () => _onBubbleTap(bubble),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }


  Future<bool> _showCloseConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit Game?"),
        content: const Text("Are you sure you want to exit? Your progress will be lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Exit"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showHomeConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Return Home?"),
        content: const Text("Are you sure you want to return home? Your progress will be lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Home"),
          ),
        ],
      ),
    );
    if (result == true) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  double _getAdaptiveBubbleFontSize(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // For very small screens (height < 600), use smaller font
    if (screenHeight < 600) {
      return 14.0; // Smaller font for small screens
    }
    // For medium screens (height 600-800), use medium font
    else if (screenHeight < 800) {
      return 16.0; // Medium font for medium screens
    }
    // For large screens (height 800-1000), use larger font
    else if (screenHeight < 1000) {
      return 18.0; // Larger font for large screens
    }
    // For very large screens (tablets, iPads), use even larger font
    else {
      return 20.0; // Extra large font for tablets
    }
  }

  double _getAdaptiveQuestionFontSize(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // For very small screens (height < 600), use smaller font
    if (screenHeight < 600) {
      return 18.0; // Smaller font for small screens
    }
    // For medium screens (height 600-800), use medium font
    else if (screenHeight < 800) {
      return 20.0; // Medium font for medium screens
    }
    // For large screens (height 800-1000), use larger font
    else if (screenHeight < 1000) {
      return 24.0; // Larger font for large screens
    }
    // For very large screens (tablets, iPads), use even larger font
    else {
      return 28.0; // Extra large font for tablets
    }
  }

  Widget _buildLivesIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.favorite,
          color: Colors.red,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$_lives/$_maxLives',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
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
}

/// Bubble data model
class Bubble {
  String text;
  double centerX, centerY;
  double vx, vy;
  double width, height;
  final Color outlineColor;

  Bubble({
    required this.text,
    required double initialX,
    required double initialY,
    required this.vx,
    required this.vy,
    required this.outlineColor,
    required this.width,
    required this.height,
  })  : centerX = initialX + width / 2,
        centerY = initialY + height / 2;

  double get left => centerX - width / 2;
  double get right => centerX + width / 2;
  double get top => centerY - height / 2;
  double get bottom => centerY + height / 2;
}

/// Bubble widget (transparent fill, colored outline, black text)
class AnimatedBubble extends StatelessWidget {
  final Bubble bubble;
  final VoidCallback onTap;

  const AnimatedBubble({super.key, required this.bubble, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: bubble.centerX - bubble.width / 2,
      top: bubble.centerY - bubble.height / 2,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: bubble.width,
          height: bubble.height,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(
              color: bubble.outlineColor,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              bubble.text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: _getAdaptiveBubbleFontSize(context),
              ),
              textAlign: TextAlign.center,
              maxLines: 2, // Allow up to 2 lines
              overflow: TextOverflow.visible, // Show full text
            ),
          ),
        ),
      ),
    );
  }

  /// Get adaptive font size for bubble text based on screen height
  double _getAdaptiveBubbleFontSize(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight < 600) {
      return 14.0;
    } else if (screenHeight < 800) {
      return 16.0;
    } else if (screenHeight < 1000) {
      return 18.0;
    } else {
      return 20.0;
    }
  }
}
