import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../components/word_progress_display.dart';
import 'package:provider/provider.dart';

class PopYourCardView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;

  const PopYourCardView({
    super.key,
    required this.cards,
    required this.title,
  });

  @override
  State<PopYourCardView> createState() => _PopYourCardViewState();
}

class _PopYourCardViewState extends State<PopYourCardView>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalQuestions = 0;
  bool _showingResults = false;
  DateTime? _sessionStartTime;
  int _sessionXP = 0;
  Map<String, int> _xpGainedPerWord = {};

  List<Bubble> bubbles = [];
  final Random random = Random();

  late Ticker _ticker;
  double _screenWidth = 0;
  double _screenHeight = 0;
  double _lastPhysicsUpdate = 0;

  static const double _bubbleBaseSpeed = 100.0;
  static const double _bubbleHeight = 60.0;
  static const double _minBubbleWidth = 80.0;
  static const double _maxBubbleWidth = 300.0;

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
      _showResults();
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
    final currentCard = widget.cards[_currentIndex];
    final correct = currentCard.word;
    bool isCorrect = tappedBubble.text == correct;

    _ticker.stop();

    if (isCorrect) {
      _correctAnswers++;
      _awardXP(currentCard);
    }

    setState(() {});

    // Show simple XP feedback and proceed to next card
    _showCardXPFeedback(currentCard, isCorrect, correct);
  }

  void _nextCard() {
    _currentIndex++;
    if (_currentIndex < widget.cards.length) {
      _loadCurrentCard();
    } else {
      // Skip results screen and show final XP summary
      _showFinalXPSummary();
    }
  }

  void _awardXP(FlashCard card) {
    final provider = context.read<FlashcardProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();
    
    // Get XP for this game type
    final xpGained = card.learningMastery.getXPForGame('popYourCard');
    
    // Award XP to the card
    card.learningMastery.addXP(xpGained, 'popYourCard');
    _xpGainedPerWord[card.word] = xpGained;
    _sessionXP += xpGained;
    
    // Award XP to user profile (async but we don't await it)
    userProfileProvider.addXp(xpGained);
    
    // Update the card in the provider
    provider.updateCard(card);
  }

  void _showCardXPFeedback(FlashCard card, bool isCorrect, String correctAnswer) {
    final xpGained = isCorrect ? _xpGainedPerWord[card.word] ?? 0 : 0;
    
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
              _nextCard();
              _ticker.start();
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
          studiedWords: widget.cards,
          xpGainedPerWord: _xpGainedPerWord,
          wordMastery: widget.cards.fold<Map<String, LearningMastery>>(
            {},
            (map, card) {
              map[card.word] = card.learningMastery;
              return map;
            },
          ),
          hideNavigation: true,
          onDone: () {
            Navigator.of(context).pop(); // Return to previous screen
          },
        ),
      ),
    );
  }

  void _showResults() {
    _ticker.stop();
    _showingResults = true;
    
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

    setState(() {});
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
    if (_showingResults) {
      return _buildResultsScreen();
    }

    if (_currentIndex >= widget.cards.length) {
      return _buildResultsScreen();
    }

    final currentCard = widget.cards[_currentIndex];
    final progress = _currentIndex / widget.cards.length;

    return WillPopScope(
      onWillPop: () async {
        return await _showCloseConfirmation();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _showCloseConfirmation(),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "${(progress * 100).round()}%",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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

  Widget _buildResultsScreen() {
    final accuracy = _totalQuestions > 0 ? (_correctAnswers / _totalQuestions) : 0.0;
    final isPerfect = _correctAnswers == _totalQuestions && _totalQuestions > 0;
    final totalXPGained = _xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Results"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPerfect ? Icons.star : Icons.check_circle,
                size: 80,
                color: isPerfect ? Colors.amber : Colors.green,
              ),
              const SizedBox(height: 20),
              Text(
                isPerfect ? "Perfect Score!" : "Study Complete!",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%",
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                "Correct: $_correctAnswers / $_totalQuestions",
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                "XP Gained: $totalXPGained",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text("Return Home"),
              ),
            ],
          ),
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
              style: const TextStyle(
                color: Colors.black,
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
