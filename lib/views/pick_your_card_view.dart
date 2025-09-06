import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../components/word_progress_display.dart';
import '../services/xp_service.dart';

class PickYourCardView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;

  const PickYourCardView({
    super.key,
    required this.cards,
    required this.title,
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

  List<String> wheel1Items = [];
  List<String> wheel2Items = [];
  List<String> wheel3Items = [];
  bool hasThirdWheel = false;

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
    _loadCurrentCard();
  }

  void _loadCurrentCard() {
    if (currentCardIndex >= widget.cards.length) return;
    
    final FlashCard card = widget.cards[currentCardIndex];
    final String dutch = card.word;
    
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
      
      // Calculate XP gained
      final xpGained = 15 + (_consecutiveCorrect * 3);
      _xpGainedPerWord[currentCard.id] = xpGained;
      
      // Update user profile
      userProfileProvider.addXp(xpGained);
      
      _showResultDialog(true, userAnswer, correctAnswer);
    } else {
      currentCard.markIncorrect(GameDifficulty.medium);
      _consecutiveCorrect = 0;
      _xpGainedPerWord[currentCard.id] = 0;
      
      _showResultDialog(false, userAnswer, correctAnswer);
    }
    
    // Update mastery tracking
    _wordMastery[currentCard.id] = currentCard.learningMastery;
    
    // Save to provider
    provider.updateCard(currentCard);
    _totalAnswers++;
  }

  void _showResultDialog(bool isCorrect, String userAnswer, String correctAnswer) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          isCorrect ? "Correct!" : "Incorrect",
          style: TextStyle(
            color: isCorrect ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isCorrect 
                ? "Great job! You got: $correctAnswer"
                : "Your answer: $userAnswer\nCorrect answer: $correctAnswer",
              textAlign: TextAlign.center,
            ),
            if (isCorrect) ...[
              const SizedBox(height: 8),
              Text(
                "+${_xpGainedPerWord[widget.cards[currentCardIndex].id] ?? 0} XP",
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _nextCard();
            },
            child: Text(isCorrect ? "Next" : "Continue"),
          ),
        ],
      ),
    );
  }

  void _nextCard() {
    if (currentCardIndex + 1 < widget.cards.length) {
      setState(() {
        currentCardIndex++;
        _loadCurrentCard();
      });
    } else {
      _showResults();
    }
  }

  void _showResults() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => WordProgressDisplay(
          studiedWords: _studiedWords,
          xpGainedPerWord: _xpGainedPerWord,
          wordMastery: _wordMastery,
          onStudyAgain: () {
            Navigator.of(context).pop();
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
          },
          onDone: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
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
    final progress = (currentCardIndex + 1) / widget.cards.length;

    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blueGrey.shade700,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '${currentCardIndex + 1}/${widget.cards.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toInt()}% Complete',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          // Main content
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // English word to translate
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      "Translate '${currentCard.definition}'",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
                      ),
                      const SizedBox(width: 20),
                      DialWheel(
                        key: ValueKey<int>(currentCardIndex * 3 + 1),
                        items: wheel2Items,
                        onChanged: (value) => setState(() => selectedPart2 = value),
                      ),
                      if (hasThirdWheel) ...[
                        const SizedBox(width: 20),
                        DialWheel(
                          key: ValueKey<int>(currentCardIndex * 3 + 2),
                          items: wheel3Items,
                          onChanged: (value) => setState(() => selectedPart3 = value),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
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
                  
                  // Check Answer button
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DialWheel extends StatefulWidget {
  final List<String> items;
  final ValueChanged<String> onChanged;

  const DialWheel({super.key, required this.items, required this.onChanged});

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
    _controller.stop();
    _startDragDy = details.localPosition.dy;
    _startDragAngle = _currentAngle;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _currentAngle = _startDragAngle + (details.localPosition.dy - _startDragDy) / 60.0;
    });
  }

  void _onDragEnd(DragEndDetails details) {
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
