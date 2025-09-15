import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../components/word_progress_display.dart';
import '../services/xp_service.dart';
import '../services/sound_manager.dart';
import 'package:provider/provider.dart';

class PopYourCardView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final bool shuffleMode;
  final Function(bool)? onComplete;

  const PopYourCardView({
    super.key,
    required this.cards,
    required this.title,
    this.shuffleMode = false,
    this.onComplete,
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
    _loadCurrentCard();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
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

    if (_screenWidth != 0 && _screenHeight != 0) {
      _initializeBubblePositionsAndVelocities(bubbleTexts);
    } else {
      bubbles = bubbleTexts.map<Bubble>((text) {
        double width = _calculateBubbleWidth(text);
        return Bubble(
          text: text,
          initialX: 0,
          initialY: 0,
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
    double calculatedWidth = word.length * 20.0 + 20.0;
    return calculatedWidth.clamp(_minBubbleWidth, _maxBubbleWidth);
  }

  void _initializeBubblePositionsAndVelocities(List<String> texts) {
    bubbles.clear();
    for (final text in texts) {
      double speedMagnitude = _bubbleBaseSpeed + random.nextDouble() * 50.0;
      double angle = random.nextDouble() * 2 * pi;

      double width = _calculateBubbleWidth(text);

      double initialX = random.nextDouble() * (_screenWidth - width);
      double initialY = random.nextDouble() * (_screenHeight - _bubbleHeight);

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
    } else {
      // Track incorrect answers with 0 XP
      _xpGainedPerWord[currentCard.id] = 0;
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
          hideNavigation: true,
          onDone: () {
            Navigator.of(context).pop(); // Close word progress screen
            Navigator.of(context).pop(); // Go back to study type screen
          },
        ),
      ),
    );
  }


  void _updatePhysics(Duration elapsed) {
    if (_screenWidth == 0 || _screenHeight == 0) return;
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
            _bubbleHeight = _screenHeight * 0.08; // 8% of screen height
            _minBubbleWidth = _screenWidth * 0.15; // 15% of screen width
            _maxBubbleWidth = _screenWidth * 0.4; // 40% of screen width
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
                            "Question ${_currentIndex + 1} of ${widget.cards.length}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
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
                      fontSize: 20,
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
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Text(
              bubble.text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
