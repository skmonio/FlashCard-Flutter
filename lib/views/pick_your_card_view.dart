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
import '../utils/enhanced_snackbar.dart';

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
  final int? shuffleQuestionOffset; // Offset for cumulative question count in shuffle mode

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
    this.shuffleQuestionOffset,
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
  
  // Hint system
  Map<int, int> _hintCount = {}; // Track hints used per card
  Map<int, Set<int>> _hintedWheels = {}; // Track which wheels have been hinted per card
  Map<int, List<String>> _correctParts = {}; // Store correct parts for each card
  int _hintsUsed = 0;
  bool _isApplyingHint = false; // Flag to prevent onChanged during hint application
  
  // Store user answers and results for each card
  Map<int, String> _userAnswers = {}; // Store user's final answer for each card
  Map<int, bool> _cardResults = {}; // Store whether each card was answered correctly
  Map<int, List<String>> _userSelections = {}; // Store user's individual wheel selections for each card
  
  // Debounce mechanism for wheel changes
  Timer? _wheelChangeTimer;
  
  void _onWheelChanged(int wheelIndex, String value) {
    // Don't update if we're currently applying a hint
    if (_isApplyingHint) {
      print('🔍 PickYourCardView: Ignoring wheel change during hint application - wheel $wheelIndex to $value');
      return;
    }
    
    // Don't update if this wheel has been hinted (locked)
    final hintedWheels = _hintedWheels[currentCardIndex] ?? <int>{};
    if (hintedWheels.contains(wheelIndex)) {
      print('🔍 PickYourCardView: Ignoring wheel change - wheel $wheelIndex is locked (hinted)');
      return;
    }
    
    // Cancel any existing timer
    _wheelChangeTimer?.cancel();
    
    // Set a new timer to debounce the change
    _wheelChangeTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          switch (wheelIndex) {
            case 0:
              selectedPart1 = value;
              break;
            case 1:
              selectedPart2 = value;
              break;
            case 2:
              selectedPart3 = value;
              break;
          }
        });
      }
    });
  }

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
    _wheelChangeTimer?.cancel();
    super.dispose();
  }

  void _loadCurrentCard() {
    if (currentCardIndex >= widget.cards.length) return;
    
    final FlashCard currentCard = widget.cards[currentCardIndex];
    final String dutch = currentCard.word;
    
    // Start timer if using timed mode
    if (widget.useTimedMode) {
      _resetTimer();
    }
    
    // Split word into equal-length pieces
    final List<String> parts = _splitWordIntoEqualParts(dutch);
    
    // Store the correct parts for this card
    _correctParts[currentCardIndex] = List<String>.from(parts);
    
    print('🔍 PickYourCardView: Setup - Word: "$dutch", Length: ${dutch.length}, Parts: $parts');
    print('🔍 PickYourCardView: Part lengths: ${parts.map((p) => p.length).toList()}');
    
    // Debug: Test word splitting for common words
    if (dutch.toLowerCase() == 'house') {
      print('🔍 PickYourCardView: DEBUG - House splitting test:');
      print('🔍 PickYourCardView: Card word: "${currentCard.word}"');
      print('🔍 PickYourCardView: Card definition: "${currentCard.definition}"');
      print('🔍 PickYourCardView: Expected: huisje (6 chars) -> [hui, sje] or [huis, je]');
      print('🔍 PickYourCardView: Actual: $dutch (${dutch.length} chars) -> $parts');
    }
    
    if (parts.length == 2) {
      hasThirdWheel = false;
      wheel1Items = _generateWheelItems(parts[0], 1);
      wheel2Items = _generateWheelItems(parts[1], 2);
      wheel3Items = [];
      
      print('🔍 PickYourCardView: After generation - Wheel1: $wheel1Items, Wheel2: $wheel2Items, Wheel3: $wheel3Items');
      
      // Set initial values to random selections (not correct parts)
      final random = Random();
      selectedPart1 = wheel1Items[random.nextInt(wheel1Items.length)];
      selectedPart2 = wheel2Items[random.nextInt(wheel2Items.length)];
      selectedPart3 = "";
      
      print('🔍 PickYourCardView: Initial selections set - Part1: "$selectedPart1", Part2: "$selectedPart2"');
      
      // Synchronize wheels with initial selections after a short delay to ensure wheels are built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        wheel1Key.currentState?.setSelection(selectedPart1);
        wheel2Key.currentState?.setSelection(selectedPart2);
      });
    } else if (parts.length == 3) {
      hasThirdWheel = true;
      wheel1Items = _generateWheelItems(parts[0], 1);
      wheel2Items = _generateWheelItems(parts[1], 2);
      wheel3Items = _generateWheelItems(parts[2], 3);
      
      print('🔍 PickYourCardView: After generation - Wheel1: $wheel1Items, Wheel2: $wheel2Items, Wheel3: $wheel3Items');
      
      // Set initial values to random selections (not correct parts)
      final random = Random();
      selectedPart1 = wheel1Items[random.nextInt(wheel1Items.length)];
      selectedPart2 = wheel2Items[random.nextInt(wheel2Items.length)];
      selectedPart3 = wheel3Items[random.nextInt(wheel3Items.length)];
      
      print('🔍 PickYourCardView: Initial selections set - Part1: "$selectedPart1", Part2: "$selectedPart2", Part3: "$selectedPart3"');
      
      // Synchronize wheels with initial selections after a short delay to ensure wheels are built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        wheel1Key.currentState?.setSelection(selectedPart1);
        wheel2Key.currentState?.setSelection(selectedPart2);
        wheel3Key.currentState?.setSelection(selectedPart3);
      });
    } else {
      // For words with more than 3 parts, combine some parts
      hasThirdWheel = false;
      final String part1 = parts[0];
      final String part2 = parts.sublist(1).join('');
      
      // Update the correct parts with the actual parts used in wheels
      _correctParts[currentCardIndex] = [part1, part2];
      
      wheel1Items = _generateWheelItems(part1, 1);
      wheel2Items = _generateWheelItems(part2, 2);
      wheel3Items = [];
      
      print('🔍 PickYourCardView: After generation - Wheel1: $wheel1Items, Wheel2: $wheel2Items, Wheel3: $wheel3Items');
      
      // Set initial values to random selections (not correct parts)
      final random = Random();
      selectedPart1 = wheel1Items[random.nextInt(wheel1Items.length)];
      selectedPart2 = wheel2Items[random.nextInt(wheel2Items.length)];
      selectedPart3 = "";
      
      print('🔍 PickYourCardView: Initial selections set - Part1: "$selectedPart1", Part2: "$selectedPart2"');
      
      // Synchronize wheels with initial selections after a short delay to ensure wheels are built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        wheel1Key.currentState?.setSelection(selectedPart1);
        wheel2Key.currentState?.setSelection(selectedPart2);
      });
    }
    
    // If this card was already answered, restore the user's previous selections
    if (_userSelections.containsKey(currentCardIndex)) {
      final userSelections = _userSelections[currentCardIndex]!;
      
      if (userSelections.length >= 2) {
        final restoredPart1 = userSelections[0];
        final restoredPart2 = userSelections[1];
        final restoredPart3 = userSelections.length > 2 ? userSelections[2] : '';
        
        // Only restore if the parts exist in the current wheel items
        if (wheel1Items.contains(restoredPart1) && wheel2Items.contains(restoredPart2) && 
            (!hasThirdWheel || wheel3Items.contains(restoredPart3))) {
          selectedPart1 = restoredPart1;
          selectedPart2 = restoredPart2;
          if (hasThirdWheel) {
            selectedPart3 = restoredPart3;
          }
          
          print('🔍 PickYourCardView: Restoring previous selections - Part1: "$selectedPart1", Part2: "$selectedPart2", Part3: "$selectedPart3"');
          
          // Update wheel selections to match the stored selections
          wheel1Key.currentState?.setSelection(selectedPart1);
          wheel2Key.currentState?.setSelection(selectedPart2);
          if (hasThirdWheel) {
            wheel3Key.currentState?.setSelection(selectedPart3);
          }
        } else {
          print('🔍 PickYourCardView: Cannot restore previous selections - parts not found in current wheels');
          print('🔍 PickYourCardView: Attempted to restore: Part1: "$restoredPart1", Part2: "$restoredPart2", Part3: "$restoredPart3"');
          print('🔍 PickYourCardView: Available in wheels: Wheel1: $wheel1Items, Wheel2: $wheel2Items, Wheel3: $wheel3Items');
        }
      }
    }
  }

  List<String> _splitWordIntoEqualParts(String word) {
    if (word.length <= 5) {
      // Short words: split into 2 parts
      final int mid = (word.length / 2).ceil();
      return [word.substring(0, mid), word.substring(mid)];
    } else if (word.length <= 8) {
      // Medium words: split into 3 parts with better distribution
      // Ensure no part is shorter than 2 characters
      final int partLength = (word.length / 3).ceil();
      final int remainder = word.length - (partLength * 2);
      
      if (remainder >= 2) {
        // Can make 3 parts of reasonable length
        return [
          word.substring(0, partLength),
          word.substring(partLength, partLength * 2),
          word.substring(partLength * 2),
        ];
      } else {
        // Make 2 parts instead to avoid very short parts
        final int mid = (word.length / 2).ceil();
        return [word.substring(0, mid), word.substring(mid)];
      }
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
    print('🔍 PickYourCardView: Generating wheel $wheelIndex items for correct part: "$correctPart"');
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
      } else {
        print('🔍 PickYourCardView: No similar letters found for character "$char" in part "$correctPart"');
      }
    }
    
    print('🔍 PickYourCardView: After similar letter generation: $uniqueOptions');
    
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
    print('🔍 PickYourCardView: Final wheel $wheelIndex items: $items');
    return items;
  }

  void _useHint() {
    if (currentCardIndex >= widget.cards.length) return;
    
    final currentCard = widget.cards[currentCardIndex];
    final correctAnswer = currentCard.word.toLowerCase();
    
    // Use stored correct parts instead of recalculating
    final correctParts = _correctParts[currentCardIndex] ?? _splitWordIntoEqualParts(correctAnswer);
    
    print('🔍 PickYourCardView: Hint - Word: "$correctAnswer", Length: ${correctAnswer.length}');
    print('🔍 PickYourCardView: Stored correct parts: $correctParts');
    print('🔍 PickYourCardView: Recalculated parts: ${_splitWordIntoEqualParts(correctAnswer)}');
    print('🔍 PickYourCardView: Current selections - Part1: "$selectedPart1", Part2: "$selectedPart2", Part3: "$selectedPart3"');
    
    // Initialize hinted wheels set for this card if not exists
    if (!_hintedWheels.containsKey(currentCardIndex)) {
      _hintedWheels[currentCardIndex] = <int>{};
    }
    
    // Find the first wheel that has a wrong selection
    // Don't allow hints on the last wheel (would give away the answer)
    int wheelToHint = -1;
    final totalDials = hasThirdWheel ? 3 : 2;
    
    // First, lock all correct wheels before the hint
    // This ensures that correct wheels cannot be changed after using a hint
    for (int i = 0; i < totalDials - 1; i++) { // Don't lock the last wheel
      String currentSelection = '';
      String correctPart = '';
      
      switch (i) {
        case 0:
          currentSelection = selectedPart1.toLowerCase();
          correctPart = correctParts[0].toLowerCase();
          break;
        case 1:
          currentSelection = selectedPart2.toLowerCase();
          correctPart = correctParts[1].toLowerCase();
          break;
        case 2:
          currentSelection = selectedPart3.toLowerCase();
          correctPart = correctParts[2].toLowerCase();
          break;
      }
      
      // If this wheel is correct and not already locked, lock it
      if (currentSelection == correctPart && !_hintedWheels[currentCardIndex]!.contains(i)) {
        _hintedWheels[currentCardIndex]!.add(i);
        print('🔍 PickYourCardView: Locking correct wheel ${i + 1} with value "$currentSelection"');
      }
    }
    
    // Now find the first wheel that can be hinted (even if it's correct)
    // For 2-wheel system: can hint wheel 0, not wheel 1 (last)
    // For 3-wheel system: can hint wheel 0 and 1, not wheel 2 (last)
    if (totalDials > 1 && !_hintedWheels[currentCardIndex]!.contains(0)) {
      // First wheel is not locked - hint it
      wheelToHint = 0;
    } else if (totalDials > 2 && !_hintedWheels[currentCardIndex]!.contains(1)) {
      // Second wheel is not locked - hint it (only for 3-wheel system)
      wheelToHint = 1;
    }
    // Never hint the last wheel (wheel 2 in 3-wheel system, wheel 1 in 2-wheel system)
    
    // Don't allow hints if all available wheels are already locked
    if (wheelToHint == -1) {
      print('🔍 PickYourCardView: No wheel to hint - all available wheels are locked');
      return;
    }
    
    print('🔍 PickYourCardView: Will hint wheel $wheelToHint to: ${correctParts[wheelToHint]}');
    
    if (mounted) {
      setState(() {
        _hintsUsed++;
        _hintCount[currentCardIndex] = (_hintCount[currentCardIndex] ?? 0) + 1;
        _hintedWheels[currentCardIndex]!.add(wheelToHint);
      });
    }
    
    // Set flag to prevent onChanged callback during hint application
    _isApplyingHint = true;
    
    // Animate the selected wheel to the correct value
    switch (wheelToHint) {
      case 0:
        print('🔍 PickYourCardView: Hinting wheel 1 from "$selectedPart1" to: ${correctParts[0]}');
        // Update the selectedPart immediately to match the hint
        selectedPart1 = correctParts[0];
        wheel1Key.currentState?.setSelection(correctParts[0]);
        break;
      case 1:
        print('🔍 PickYourCardView: Hinting wheel 2 from "$selectedPart2" to: ${correctParts[1]}');
        // Update the selectedPart immediately to match the hint
        selectedPart2 = correctParts[1];
        wheel2Key.currentState?.setSelection(correctParts[1]);
        break;
      case 2:
        print('🔍 PickYourCardView: Hinting wheel 3 from "$selectedPart3" to: ${correctParts[2]}');
        // Update the selectedPart immediately to match the hint
        selectedPart3 = correctParts[2];
        wheel3Key.currentState?.setSelection(correctParts[2]);
        break;
    }
    
    // Reset flag after a shorter delay to allow wheel animation to complete
    Timer(const Duration(milliseconds: 500), () {
      _isApplyingHint = false;
      print('🔍 PickYourCardView: Hint application flag reset - wheel $wheelToHint should now be locked');
    });
    
    print('🔍 PickYourCardView: After hint - Part1: "$selectedPart1", Part2: "$selectedPart2", Part3: "$selectedPart3"');
    
    // Show hint message
    EnhancedSnackBar.showWarning(
      context,
      message: 'Hint: Fixed wrong selection to "${correctParts[wheelToHint]}" (locked)',
      duration: const Duration(seconds: 2),
    );
  }

  Widget _buildWheelWithLock(int wheelIndex, GlobalKey<_DialWheelState> wheelKey, List<String> items) {
    final hintedWheels = _hintedWheels[currentCardIndex] ?? <int>{};
    final isLocked = hintedWheels.contains(wheelIndex);
    
    print('🔍 PickYourCardView: Building wheel ${wheelIndex + 1} - isLocked: $isLocked, hintedWheels: $hintedWheels');
    print('🔍 PickYourCardView: Building wheel ${wheelIndex + 1} with items: $items');
    print('🔍 PickYourCardView: Current selections - Part1: "$selectedPart1", Part2: "$selectedPart2", Part3: "$selectedPart3"');
    
    return DialWheel(
      key: wheelKey,
      items: items,
      onChanged: (value) {
        print('🔍 PickYourCardView: Wheel${wheelIndex + 1} changed to: $value');
        _onWheelChanged(wheelIndex, value);
      },
      enabled: (!_showResult || !widget.autoProgress) && !isLocked,
      showHintOutline: isLocked,
    );
  }

  Widget _buildAnswerPieces() {
    String combinedWord;
    
    if (hasThirdWheel) {
      combinedWord = selectedPart1 + selectedPart2 + selectedPart3;
    } else {
      combinedWord = selectedPart1 + selectedPart2;
    }
    
    return Text(
      combinedWord,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey,
      ),
    );
  }

  Widget _buildHintIcon() {
    final hintsUsed = _hintCount[currentCardIndex] ?? 0;
    final currentCard = widget.cards[currentCardIndex];
    final correctAnswer = currentCard.word.toLowerCase();
    
    // Use stored correct parts instead of recalculating
    final correctParts = _correctParts[currentCardIndex] ?? _splitWordIntoEqualParts(correctAnswer);
    
    // Initialize hinted wheels set for this card if not exists
    if (!_hintedWheels.containsKey(currentCardIndex)) {
      _hintedWheels[currentCardIndex] = <int>{};
    }
    
    // Check if there are any wheels that can still be hinted
    // Don't allow hints on the last wheel (would give away the answer)
    bool canUseHint = false;
    final totalDials = hasThirdWheel ? 3 : 2;
    final maxHints = totalDials - 1; // Can't hint the last wheel
    
    // Allow hints if we haven't used all available hints yet
    if (hintsUsed < maxHints) {
      // Check if there are any wheels that can still be hinted
      // For 2-wheel system: can hint wheel 0, not wheel 1 (last)
      // For 3-wheel system: can hint wheel 0 and 1, not wheel 2 (last)
      if (totalDials > 1 && !_hintedWheels[currentCardIndex]!.contains(0)) {
        // First wheel is not locked - can hint it
        canUseHint = true;
      } else if (totalDials > 2 && !_hintedWheels[currentCardIndex]!.contains(1)) {
        // Second wheel is not locked - can hint it (only for 3-wheel system)
        canUseHint = true;
      }
    }
    // Never hint the last wheel (wheel 2 in 3-wheel system, wheel 1 in 2-wheel system)
    
    return Tooltip(
      message: canUseHint 
          ? 'Use hint (${hintsUsed} used)'
          : 'No more hints available',
      child: GestureDetector(
        onTap: canUseHint ? _useHint : null,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: canUseHint ? Colors.orange : Colors.orange.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.lightbulb_outline,
            color: canUseHint ? Colors.white : Colors.white.withValues(alpha: 0.5),
            size: 20,
          ),
        ),
      ),
    );
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
    
    print('🔍 PickYourCardView: Answer check - User: "$userAnswer", Correct: "$correctAnswer", Parts: "$selectedPart1" + "$selectedPart2"${hasThirdWheel ? ' + "$selectedPart3"' : ''}');
    
    final bool isCorrect = userAnswer.toLowerCase() == correctAnswer.toLowerCase();
    final provider = context.read<FlashcardProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();
    
    // Store the user's answer and result for this card
    _userAnswers[currentCardIndex] = userAnswer;
    _cardResults[currentCardIndex] = isCorrect;
    
    // Store the user's individual wheel selections
    if (hasThirdWheel) {
      _userSelections[currentCardIndex] = [selectedPart1, selectedPart2, selectedPart3];
    } else {
      _userSelections[currentCardIndex] = [selectedPart1, selectedPart2];
    }
    
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
      
      // Apply hint penalty based on number of hints used
      final hintsUsed = _hintCount[currentCardIndex] ?? 0;
      final totalDials = hasThirdWheel ? 3 : 2;
      final maxHints = totalDials - 1; // Can't hint the last wheel
      
      // If all available hints were used, give 0 XP
      final finalXPGained = hintsUsed >= maxHints 
          ? 0 
          : hintsUsed > 0 
              ? (actualXPGained * (1.0 - (0.25 * hintsUsed).clamp(0.0, 0.9))).round().clamp(1, actualXPGained)
              : actualXPGained;
      
      // Track XP gained for this word in this session
      _xpGainedPerWord[currentCard.id] = finalXPGained;
      
      // Update user profile with final XP (after hint penalty)
      userProfileProvider.addXp(finalXPGained);
      
      final hintText = hintsUsed > 0 ? " (with ${hintsUsed} hint(s), penalty applied)" : "";
      print('🔍 PickYourCardView: Awarded $finalXPGained XP to word "${currentCard.word}" (Correct: $isCorrect)$hintText - daily attempts after: ${currentCard.learningMastery.dailyAttemptsDebug}');
      
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
    if (mounted) {
      setState(() {
        _showResult = true;
        _isLastAnswerCorrect = isCorrect;
        _lastUserAnswer = userAnswer;
        _lastCorrectAnswer = correctAnswer;
      });
    }
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
      if (mounted) {
        setState(() {
          currentCardIndex++;
          _showResult = false; // Reset result display
          _hintsUsed = 0; // Reset hint count for new card
          _loadCurrentCard();
        });
      }
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
      // Update the widget's cards with new cards
      // Note: We can't directly modify widget.cards, so we'll need to work with the new cards
      currentCardIndex = 0;
      _studiedWords.clear();
      _xpGainedPerWord.clear();
      _wordMastery.clear();
      _consecutiveCorrect = 0;
      _totalAnswers = 0;
      _correctAnswers = 0;
      
      // Reset hint system
      _hintCount.clear();
      _hintedWheels.clear();
      _correctParts.clear();
      _hintsUsed = 0;
      
      // Reset stored answers
      _userAnswers.clear();
      _cardResults.clear();
      _userSelections.clear();
      
      // Reset result display
      _showResult = false;
      _isLastAnswerCorrect = false;
      _lastUserAnswer = "";
      _lastCorrectAnswer = "";
      
      // Reset lives if using lives mode
      if (_useLivesMode) {
        _lives = _maxLives;
      }
      
      // Reset timer if using timed mode
      if (widget.useTimedMode) {
        _timeRemaining = _totalTime;
        _resetTimer();
      }
    });
    
    // For Pick Your Card, we need to update the cards list
    // Since we can't modify widget.cards directly, we'll need to recreate the widget
    // For now, we'll work with the new cards in the current state
    _loadCurrentCard();
  }

  void _showResults() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UnifiedEndScreen(
          studiedWords: _studiedWords,
          xpGainedPerWord: _xpGainedPerWord,
          wordMastery: _wordMastery,
          title: 'Pick Your Card Complete',
          showSwipeToReview: false,
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close end screen first
            
            if (mounted) {
              setState(() {
                // Reset all game state
                currentCardIndex = 0;
                _studiedWords.clear();
                _xpGainedPerWord.clear();
                _wordMastery.clear();
                _consecutiveCorrect = 0;
                _totalAnswers = 0;
                _correctAnswers = 0;
                
                // Reset hint system
                _hintCount.clear();
                _hintedWheels.clear();
                _correctParts.clear();
                _hintsUsed = 0;
                
                // Reset stored answers
                _userAnswers.clear();
                _cardResults.clear();
                _userSelections.clear();
                
                // Reset result display
                _showResult = false;
                _isLastAnswerCorrect = false;
                _lastUserAnswer = "";
                _lastCorrectAnswer = "";
                
                // Reset lives if using lives mode
                if (_useLivesMode) {
                  _lives = _maxLives;
                }
                
                // Reset timer if using timed mode
                if (widget.useTimedMode) {
                  _timeRemaining = _totalTime;
                  _resetTimer();
                }
              });
            }
            
            // Reload the current card after state reset
            _loadCurrentCard();
          },
          onShuffle: () {
            Navigator.of(context).pop(); // Close end screen
            _shuffleAndRestart();
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
            onPressed: () => _showCloseConfirmation(),
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
    final accuracy = _totalAnswers > 0 ? (_correctAnswers / _totalAnswers * 100).toInt() : 0;
    
    // In shuffle mode, show cumulative question count (e.g., 1/1, 2/2, 3/3...)
    final String questionCountText;
    if (widget.shuffleMode && widget.shuffleQuestionOffset != null) {
      final currentQuestionNum = (widget.shuffleQuestionOffset ?? 0) + currentCardIndex + 1;
      questionCountText = '$currentQuestionNum/$currentQuestionNum';
    } else {
      questionCountText = '${currentCardIndex + 1}/${widget.cards.length}';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(questionCountText),
              // Show lives or timer in the middle if active
              if (_useLivesMode) _buildLivesIndicator(),
              if (widget.useTimedMode) _buildTimerIndicator(),
              Text('$accuracy%'),
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
              _buildWheelWithLock(0, wheel1Key, wheel1Items),
              const SizedBox(width: 20),
              _buildWheelWithLock(1, wheel2Key, wheel2Items),
              if (hasThirdWheel) ...[
                const SizedBox(width: 20),
                _buildWheelWithLock(2, wheel3Key, wheel3Items),
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
                    if (mounted) {
                      setState(() {
                        currentCardIndex--;
                        // If this card was already answered, show the result
                        if (_cardResults.containsKey(currentCardIndex)) {
                          _showResult = true;
                          _isLastAnswerCorrect = _cardResults[currentCardIndex]!;
                          _lastUserAnswer = _userAnswers[currentCardIndex]!;
                          _lastCorrectAnswer = widget.cards[currentCardIndex].word;
                        } else {
                          _showResult = false;
                        }
                      });
                      _loadCurrentCard();
                    }
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
          
          // Current selection display with individual pieces
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueGrey.shade300),
            ),
            child: _buildAnswerPieces(),
          ),
          
          const SizedBox(height: 30),
          
          // Hint button and Check Answer button row (only show if not showing result)
          if (!_showResult)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Hint button
                _buildHintIcon(),
                
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

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Game?'),
        content: const Text('Are you sure you want to exit? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to study type selection
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

}

class DialWheel extends StatefulWidget {
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool showHintOutline;

  const DialWheel({super.key, required this.items, required this.onChanged, this.enabled = true, this.showHintOutline = false});

  @override
  State<DialWheel> createState() => _DialWheelState();
}

// Global key to access the wheel state
final GlobalKey<_DialWheelState> wheel1Key = GlobalKey<_DialWheelState>();
final GlobalKey<_DialWheelState> wheel2Key = GlobalKey<_DialWheelState>();
final GlobalKey<_DialWheelState> wheel3Key = GlobalKey<_DialWheelState>();

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

  void setSelection(String value) {
    final index = widget.items.indexOf(value);
    if (index == -1) {
      print('🔍 DialWheel: setSelection failed - value "$value" not found in items: ${widget.items}');
      return;
    }
    
    final targetAngle = -index * _itemAngle;
    print('🔍 DialWheel: setSelection - value: "$value", index: $index, currentAngle: $_currentAngle, targetAngle: $targetAngle');
    
    // If the target is the same as current, don't animate
    if ((targetAngle - _currentAngle).abs() < 0.01) {
      print('🔍 DialWheel: setSelection - already at target position, skipping animation');
      return;
    }
    
    // Stop any existing animation
    _controller.stop();
    
    _animation = Tween<double>(begin: _currentAngle, end: targetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _controller
      ..duration = const Duration(milliseconds: 500)
      ..reset()
      ..addListener(() {
        setState(() => _currentAngle = _animation.value);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _currentAngle = targetAngle; // Ensure exact position
          print('🔍 DialWheel: Animation completed - final angle: $_currentAngle, selected item: ${_getSelectedItem()}');
          _reportSelection();
        }
      })
      ..forward();
  }

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
            
            // Debug logging for hint outline issues
            if (widget.showHintOutline && isCenter) {
              print('🔍 DialWheel: Hint outline applied to item "$item" at index $index (normalizedCenter: $normalizedCenter, diff: $diff)');
            }

            return Transform.scale(
              scale: scale,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCenter ? (widget.showHintOutline ? Colors.orange.withValues(alpha: 0.2) : Colors.lightBlue.shade50) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCenter ? (widget.showHintOutline ? Colors.orange : Colors.blue.shade600) : Colors.grey.shade400,
                        width: isCenter ? (widget.showHintOutline ? 3 : 2.5) : 1.5,
                      ),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: isCenter ? 26 : 20,
                        fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
                        color: isCenter ? (widget.showHintOutline ? Colors.orange : Colors.blue.shade900) : Colors.black87,
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
