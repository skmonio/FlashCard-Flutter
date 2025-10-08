import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:async';
import '../providers/flashcard_provider.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../services/sound_manager.dart';
import '../services/haptic_service.dart';
import '../components/unified_end_screen.dart';

class GridPainter extends CustomPainter {
  final List<String> letters;
  final int gridSize;
  final List<int> selectedIndexes;
  final List<int> wrongIndexes;
  final List<int> hintIndexes;
  final bool answeredWords;
  final int? pressedIndex; // Add pressed state
  final Offset? dragPosition; // Add drag trail position

  GridPainter({
    required this.letters,
    required this.gridSize,
    required this.selectedIndexes,
    required this.wrongIndexes,
    required this.hintIndexes,
    required this.answeredWords,
    this.pressedIndex, // Add pressed state
    this.dragPosition, // Add drag trail position
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    double cellSize = size.width / gridSize;

    for (int i = 0; i < letters.length; i++) {
      int row = i ~/ gridSize;
      int col = i % gridSize;
      
      double x = col * cellSize;
      double y = row * cellSize;

      // Determine colors
      Color backgroundColor = Colors.grey[200]!;
      Color textColor = Colors.black87;
      
      bool isSelected = selectedIndexes.contains(i);
      bool isWrong = wrongIndexes.contains(i);
      bool isHintLetter = hintIndexes.contains(i);
      bool isPressed = pressedIndex == i;

      if (answeredWords) {
        if (isSelected) {
          backgroundColor = Colors.blue;
          textColor = Colors.white;
        }
      } else {
        if (isWrong) {
          backgroundColor = Colors.red;
          textColor = Colors.white;
        } else if (isHintLetter) {
          backgroundColor = Colors.green;
          textColor = Colors.white;
        } else if (isSelected) {
          backgroundColor = Colors.blue;
          textColor = Colors.white;
        } else if (isPressed) {
          // Show pressed state with darker background
          backgroundColor = Colors.grey[400]!;
          textColor = Colors.black;
        }
      }

      // Draw cell background
      paint.color = backgroundColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 2, y + 2, cellSize - 4, cellSize - 4),
          const Radius.circular(8),
        ),
        paint,
      );

      // Draw letter with larger font size for better mobile visibility
      double fontSize = cellSize * 0.4; // Scale font size with cell size
      fontSize = fontSize.clamp(20.0, 32.0); // Keep within reasonable bounds
      
      textPainter.text = TextSpan(
        text: letters[i],
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      );
      textPainter.layout();
      
      final textOffset = Offset(
        x + (cellSize - textPainter.width) / 2,
        y + (cellSize - textPainter.height) / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
    
    // Draw drag trail if dragging
    if (dragPosition != null) {
      paint.color = Colors.orange.withOpacity(0.8);
      canvas.drawCircle(dragPosition!, 8, paint);
      
      // Draw a smaller inner circle
      paint.color = Colors.white;
      canvas.drawCircle(dragPosition!, 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class ConnectCardsView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final bool autoProgress;
  final bool useLivesMode;
  final int? customLives;
  final bool useTimedMode;
  final int? timePerQuestion;
  
  const ConnectCardsView({
    super.key,
    required this.cards,
    required this.title,
    this.autoProgress = true,
    this.useLivesMode = false,
    this.customLives,
    this.useTimedMode = false,
    this.timePerQuestion,
  });

  @override
  State<ConnectCardsView> createState() => _ConnectCardsViewState();
}

class _ConnectCardsViewState extends State<ConnectCardsView>
    with TickerProviderStateMixin {
  late List<FlashCard> _availableCards;
  int _currentCardIndex = 0;
  int _hintLevel = 0;
  
  // End screen tracking
  List<FlashCard> _studiedWords = [];
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  Map<String, int> _hintsUsedPerWord = {}; // Track hints used per word for XP penalty
  Map<String, List<int>> _answeredWords = {}; // Track selected letters for answered words
  Map<String, int> _answeredHintLevels = {}; // Track hint levels for answered words
  Map<String, List<int>> _answeredHintIndexes = {}; // Track hint letters for answered words
  Map<String, bool> _answeredShowFeedback = {}; // Track feedback state for answered words
  Map<String, List<String>> _savedGridLetters = {}; // Track grid letters for each word
  Map<String, List<int>> _savedCorrectPaths = {}; // Track correct paths for each word
  Map<String, int> _savedGridSizes = {}; // Track grid sizes for each word
  int _currentUnansweredIndex = 0; // Track the current unanswered question index
  bool _hasNavigatedBack = false; // Track if user has pressed Back button
  
  late List<String> _letters;
  late int _gridSize;
  Map<int, bool> _pathIndexes = {};
  List<int> _correctPath = []; // Track the correct path order
  List<int> _selectedIndexes = [];
  List<int> _wrongIndexes = [];
  List<int> _hintIndexes = []; // Track permanently highlighted hint letters
  int? _startIndex;
  bool _isShowingHint = false;
  bool _isDragging = false;
  bool _gameCompleted = false;
  int? _pressedIndex; // Track which letter is currently being pressed
  Offset? _dragPosition; // Track drag position for visual trail
  // Auto-progress option from widget parameter
  bool _showFeedback = false; // Show feedback message
  String _feedbackMessage = ''; // Feedback message text
  
  // Timed mode variables
  Timer? _timer;
  int _timeRemaining = 0;
  bool _isTimedMode = false;
  
  // Lives mode variables
  int _livesRemaining = 0;
  int _maxLives = 0;
  bool _isLivesMode = false;
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _setupAnimations();
    _initializeTimedMode();
  }

  void _initializeGame() {
    // Filter cards: only words with 3-10 characters, no spaces, and have definitions
    _availableCards = widget.cards.where((card) {
      final word = card.word.trim();
      return word.length >= 3 && 
             word.length <= 10 && 
             !word.contains(' ') && 
             card.definition.isNotEmpty &&
             word.length == word.replaceAll(RegExp(r'[^a-zA-Z]'), '').length; // Only letters
    }).toList();
    
    if (_availableCards.isEmpty) {
      _availableCards = [
        FlashCard(
          word: 'HUIS',
          definition: 'house',
          example: '',
          deckIds: {},
          dateCreated: DateTime.now(),
          learningMastery: LearningMastery(),
          article: '',
          plural: '',
          pastTense: '',
          futureTense: '',
          pastParticiple: '',
        ),
        FlashCard(
          word: 'BOEK',
          definition: 'book',
          example: '',
          deckIds: {},
          dateCreated: DateTime.now(),
          learningMastery: LearningMastery(),
          article: '',
          plural: '',
          pastTense: '',
          futureTense: '',
          pastParticiple: '',
        ),
      ];
    }
    
    _shuffleCards();
    _setupGrid();
  }

  void _setupAnimations() {
    _shakeController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 400)
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
    
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600)
    );
    _successAnimation = Tween<double>(begin: 0, end: 1)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_successController);
  }
  
  void _initializeTimedMode() {
    _isTimedMode = widget.useTimedMode;
    if (_isTimedMode && widget.timePerQuestion != null) {
      _timeRemaining = widget.timePerQuestion!;
      _startTimer();
    }
    
    _isLivesMode = widget.useLivesMode;
    if (_isLivesMode) {
      _maxLives = widget.customLives ?? 3; // Default to 3 lives
      _livesRemaining = _maxLives;
    }
  }
  
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining--;
        if (_timeRemaining <= 0) {
          _timer?.cancel();
          _handleTimeUp();
        }
      });
    });
  }
  
  void _handleTimeUp() {
    // Time is up - mark as incorrect and move to next word
    _availableCards[_currentCardIndex].markIncorrect(GameDifficulty.medium);
    _nextWord();
  }
  
  Widget _buildTimerIndicator() {
    if (!_isTimedMode || widget.timePerQuestion == null) {
      return const SizedBox.shrink();
    }
    
    final progress = _timeRemaining / widget.timePerQuestion!;
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
          '$_livesRemaining/$_maxLives',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _shuffleCards() {
    if (_availableCards.length > 1) {
      // Create a new list to ensure proper shuffling
      final shuffledCards = List<FlashCard>.from(_availableCards);
      shuffledCards.shuffle(_random);
      _availableCards = shuffledCards;
      
      // Reset current index to start from beginning
      _currentCardIndex = 0;
      _currentUnansweredIndex = 0;
    }
  }

  void _getNewCardsFromDeck() {
    // Get new cards from the same deck configuration as the original widget.cards
    // This ensures we get fresh cards that can be studied today
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
      // Fallback to original cards if no new cards found
      return;
    }
    
    // Filter cards that can be studied today (have HP remaining)
    final availableCards = allDeckCards.where((card) => card.canBeStudiedToday).toList();
    
    if (availableCards.isEmpty) {
      // If no cards available today, use all cards (they'll be at 0 HP but still playable)
      _availableCards = allDeckCards.where((card) {
        final word = card.word.trim();
        return word.length >= 3 && 
               word.length <= 10 && 
               !word.contains(' ') && 
               card.definition.isNotEmpty &&
               word.length == word.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
      }).toList();
    } else {
      // Use available cards that can be studied today
      _availableCards = availableCards.where((card) {
        final word = card.word.trim();
        return word.length >= 3 && 
               word.length <= 10 && 
               !word.contains(' ') && 
               card.definition.isNotEmpty &&
               word.length == word.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
      }).toList();
    }
    
    // If still no cards, use fallback cards
    if (_availableCards.isEmpty) {
      _availableCards = [
        FlashCard(
          word: 'HUIS',
          definition: 'house',
          example: '',
          deckIds: {},
          dateCreated: DateTime.now(),
          learningMastery: LearningMastery(),
          article: '',
          plural: '',
          pastTense: '',
          futureTense: '',
          pastParticiple: '',
        ),
        FlashCard(
          word: 'BOEK',
          definition: 'book',
          example: '',
          deckIds: {},
          dateCreated: DateTime.now(),
          learningMastery: LearningMastery(),
          article: '',
          plural: '',
          pastTense: '',
          futureTense: '',
          pastParticiple: '',
        ),
      ];
    }
  }

  void _setupGrid() {
    if (_currentCardIndex >= _availableCards.length) {
      _gameCompleted = true;
      return;
    }
    
    String currentWordId = _availableCards[_currentCardIndex].id;
    
    // Check if we have a saved grid for this word
    if (_savedGridLetters.containsKey(currentWordId)) {
      // Restore the saved grid
      _letters = List.from(_savedGridLetters[currentWordId]!);
      _correctPath = List.from(_savedCorrectPaths[currentWordId]!);
      _gridSize = _savedGridSizes[currentWordId]!;
      
      // Restore path indexes
      _pathIndexes.clear();
      for (int i = 0; i < _correctPath.length; i++) {
        _pathIndexes[_correctPath[i]] = true;
      }
      _startIndex = _correctPath.isNotEmpty ? _correctPath[0] : null;
      return;
    }
    
    // Don't reset grid for completed words - they should show their final state
    if (_answeredWords.containsKey(currentWordId)) {
      // For completed words, we should have saved grid data
      if (_savedGridLetters.containsKey(currentWordId)) {
        // Restore the saved grid for completed words
        _letters = List.from(_savedGridLetters[currentWordId]!);
        _correctPath = List.from(_savedCorrectPaths[currentWordId]!);
        _gridSize = _savedGridSizes[currentWordId]!;
        
        // Restore path indexes
        _pathIndexes.clear();
        for (int i = 0; i < _correctPath.length; i++) {
          _pathIndexes[_correctPath[i]] = true;
        }
        _startIndex = _correctPath.isNotEmpty ? _correctPath[0] : null;
      }
      return; // Keep the existing grid state for completed words
    }
    
    final word = _availableCards[_currentCardIndex].word.toUpperCase();
    // Standardized 5x5 grid for all words - optimal mobile touch experience
    _gridSize = 5; // 5x5 = 25 cells for all words
    
    _letters = List<String>.filled(_gridSize * _gridSize, '');
    _pathIndexes.clear();
    _correctPath.clear();
    _startIndex = null;
    _hintLevel = 0;
    
    // Debug logging for grid optimization
    print('🔍 Word: $word (${word.length} letters)');
    print('🔍 Grid size: ${_gridSize}x$_gridSize (${_gridSize * _gridSize} total cells)');
    
    // Generate a more complex path for the word
    int attempts = 0;
    while (true) {
      attempts++;
      if (attempts > 1000) break; // fail-safe
      
      List<int> tempPath = [];
      int start = _random.nextInt(_gridSize * _gridSize);
      tempPath.add(start);
      
      bool success = true;
      for (int i = 1; i < word.length; i++) {
        List<int> neighbors = _getNeighbors(tempPath.last)
            .where((n) => !tempPath.contains(n))
            .toList();
        if (neighbors.isEmpty) {
          success = false;
          break;
        }
        
        // Add some complexity by sometimes choosing neighbors that create turns
        List<int> availableNeighbors = neighbors;
        if (availableNeighbors.length > 1 && i > 1) {
          // 30% chance to create a turn (choose a neighbor that's not in the same direction)
          if (_random.nextDouble() < 0.3) {
            int lastDirection = _getDirection(tempPath[i-2], tempPath[i-1]);
            availableNeighbors = neighbors.where((n) => _getDirection(tempPath[i-1], n) != lastDirection).toList();
            if (availableNeighbors.isEmpty) {
              availableNeighbors = neighbors;
            }
          }
        }
        
        tempPath.add(availableNeighbors[_random.nextInt(availableNeighbors.length)]);
      }
      
      if (success) {
        _correctPath = List.from(tempPath);
        for (int i = 0; i < word.length; i++) {
          _letters[tempPath[i]] = word[i];
          _pathIndexes[tempPath[i]] = true;
        }
        _startIndex = tempPath[0];
        break;
      }
    }
    
    // Fill remaining cells with random letters
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    for (int i = 0; i < _letters.length; i++) {
      if (_letters[i] == '') {
        _letters[i] = alphabet[_random.nextInt(alphabet.length)];
      }
    }
    
    _selectedIndexes.clear();
    _wrongIndexes.clear();
    _hintIndexes.clear();
    _isShowingHint = false;
    _pressedIndex = null;
    _dragPosition = null;
    
    // Save the grid state for this word
    _savedGridLetters[currentWordId] = List.from(_letters);
    _savedCorrectPaths[currentWordId] = List.from(_correctPath);
    _savedGridSizes[currentWordId] = _gridSize;
  }

  bool _isValidNextLetter(int index) {
    // Check if this is the correct next letter in the path
    int currentPathLength = _selectedIndexes.length;
    
    // If we have more letters selected than the correct path, it's invalid
    if (currentPathLength >= _correctPath.length) {
      return false;
    }
    
    // Check if the selected index matches the next letter in the correct path
    int expectedNextIndex = _correctPath[currentPathLength];
    return index == expectedNextIndex;
  }
  
  List<int> _getNeighbors(int index) {
    int row = index ~/ _gridSize;
    int col = index % _gridSize;
    List<int> neighbors = [];
    
    // Check only 4 directions (no diagonals)
    if (row > 0) neighbors.add((row - 1) * _gridSize + col); // up
    if (row < _gridSize - 1) neighbors.add((row + 1) * _gridSize + col); // down
    if (col > 0) neighbors.add(row * _gridSize + col - 1); // left
    if (col < _gridSize - 1) neighbors.add(row * _gridSize + col + 1); // right
    
    return neighbors;
  }

  int _getDirection(int from, int to) {
    int fromRow = from ~/ _gridSize;
    int fromCol = from % _gridSize;
    int toRow = to ~/ _gridSize;
    int toCol = to % _gridSize;
    
    if (toRow < fromRow) return 0; // up
    if (toRow > fromRow) return 1; // down
    if (toCol < fromCol) return 2; // left
    if (toCol > fromCol) return 3; // right
    return -1; // same position
  }

  void _onPointerDown(PointerDownEvent details, BoxConstraints constraints) {
    if (_gameCompleted) return;
    
    // Don't allow interaction with answered words
    String currentWordId = _availableCards[_currentCardIndex].id;
    if (_answeredWords.containsKey(currentWordId)) return;
    
    print('🔍 Pointer down at: ${details.localPosition}');
    
    setState(() {
      // Don't clear selected indexes - keep hint letters selected
      _wrongIndexes.clear();
      _isDragging = true;
      _dragPosition = details.localPosition; // Set initial drag position
    });
    
    // If we're starting a new drag and have a single letter selected, clear it
    // This handles the case where user taps a letter and then tries to drag
    if (_selectedIndexes.length == 1 && _hintIndexes.isEmpty) {
      print('🔍 Clearing single letter selection to start new drag');
      setState(() {
        _selectedIndexes.clear();
      });
    }
    
    // Add haptic feedback for touch start
    HapticService().lightImpact();
    
    _handleTouch(details.localPosition, constraints);
  }

  void _onPointerMove(PointerMoveEvent details, BoxConstraints constraints) {
    if (_isDragging && !_gameCompleted) {
      setState(() {
        _dragPosition = details.localPosition; // Update drag position
      });
      _handleTouch(details.localPosition, constraints);
    }
  }

  void _onPointerUp(PointerUpEvent details) {
    print('🔍 Pointer up - selected indexes: $_selectedIndexes');
    setState(() {
      _isDragging = false;
      _dragPosition = null; // Clear drag trail
    });
    
    // Clear pressed state after a short delay for visual feedback
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _pressedIndex = null;
        });
      }
    });
    
    // Check if the current selection is correct
    if (_selectedIndexes.isNotEmpty) {
      final word = _availableCards[_currentCardIndex].word.toUpperCase();
      String formedWord = _selectedIndexes.map((i) => _letters[i]).join('');
      
      print('🔍 Checking word: "$formedWord" vs "$word"');
      
      // Check if the formed word matches the target word
      if (formedWord == word) {
        // Correct word - this should trigger completion
        print('✅ Word is correct!');
        _checkWordCompletion();
      } else {
        // Incorrect word, show error
        print('❌ Word is incorrect');
        
        // Mark the card as incorrect to properly record the attempt and reduce HP
        _availableCards[_currentCardIndex].markIncorrect(GameDifficulty.medium);
        
        setState(() {
          _wrongIndexes = List.from(_selectedIndexes);
          
          // Handle lives mode
          if (_isLivesMode) {
            _livesRemaining--;
            if (_livesRemaining <= 0) {
              // Game over - show end screen
              _showGameCompleteDialog();
              return;
            }
          }
        });
        
        SoundManager().playWrongSound();
        _shakeController.forward(from: 0);
        
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            // Clear selection but keep hint letters
            _selectedIndexes.clear();
            _wrongIndexes.clear();
            // Restore hint letters to selected indexes
            _selectedIndexes.addAll(_hintIndexes);
          });
        });
      }
    } else {
      print('🔍 No letters selected - clearing selection');
      // If no letters selected, clear any existing selection
      setState(() {
        _selectedIndexes.clear();
        _wrongIndexes.clear();
        // Restore hint letters to selected indexes
        _selectedIndexes.addAll(_hintIndexes);
      });
    }
  }

  void _onPointerCancel(PointerCancelEvent details) {
    print('🔍 Pointer cancel - selected indexes: $_selectedIndexes');
    setState(() {
      _isDragging = false;
      _dragPosition = null; // Clear drag trail
      _pressedIndex = null; // Clear pressed state immediately
    });
    
    // Don't check word completion on cancel - just clear selection
    setState(() {
      _selectedIndexes.clear();
      _wrongIndexes.clear();
      // Restore hint letters to selected indexes
      _selectedIndexes.addAll(_hintIndexes);
    });
  }

  void _handleTouch(Offset position, BoxConstraints constraints) {
    // Debug logging for mobile touch issues
    print('🔍 Touch at position: ${position.dx}, ${position.dy}');
    print('🔍 Constraints: ${constraints.maxWidth} x ${constraints.maxHeight}');
    
    // Calculate cell size based on the actual grid size
    double cellSize = (constraints.maxWidth - 32) / _gridSize; // 32 for padding
    
    print('🔍 Cell size: ${cellSize.toStringAsFixed(1)}px (${(cellSize * 0.4).clamp(20.0, 32.0).toStringAsFixed(1)}px font)');
    
    // Calculate which cell was touched
    int col = (position.dx ~/ cellSize);
    int row = (position.dy ~/ cellSize);
    
    print('🔍 Calculated row: $row, col: $col');
    
    // Ensure we're within bounds
    if (row >= 0 && row < _gridSize && col >= 0 && col < _gridSize) {
      int index = row * _gridSize + col;
      print('🔍 Selected index: $index, letter: ${_letters[index]}');
      
      // Set pressed index for visual feedback
      setState(() {
        _pressedIndex = index;
      });
      
      // Don't allow selecting letters that are already selected (including hint letters)
      if (_selectedIndexes.contains(index)) {
        return;
      }
      
      // Allow selecting hint letters if they're not already in the selection
      if (_hintIndexes.contains(index) && _selectedIndexes.contains(index)) {
        print('🔍 Hint letter already selected: ${_letters[index]}');
        return;
      }
      
      // If this is the first touch and no letters are selected yet
      if (_selectedIndexes.isEmpty) {
        // If we have hint letters, only allow starting from the first hint letter
        if (_hintIndexes.isNotEmpty) {
          if (index == _hintIndexes[0]) {
            setState(() {
              _selectedIndexes.add(index);
            });
            HapticService().buttonTapFeedback();
            print('🔍 Started selection from hint letter: ${_letters[index]}');
          }
          // If trying to start from wrong letter when hints exist, ignore the touch
          else {
            print('🔍 Ignoring touch - must start from hint letter');
            return;
          }
        } else {
          // No hints, allow starting from any letter
          setState(() {
            _selectedIndexes.add(index);
          });
          HapticService().buttonTapFeedback();
          print('🔍 Started selection from letter: ${_letters[index]}');
        }
      }
      // If we already have selected letters, allow building the selection
      else {
        int lastSelectedIndex = _selectedIndexes.last;
        List<int> neighbors = _getNeighbors(lastSelectedIndex);
        print('🔍 Last selected: ${_letters[lastSelectedIndex]} (index: $lastSelectedIndex)');
        print('🔍 Neighbors: ${neighbors.map((i) => '${_letters[i]}($i)').join(', ')}');
        print('🔍 Trying to select: ${_letters[index]} (index: $index)');
        
        // Check if this letter is adjacent to the last selected letter
        if (neighbors.contains(index)) {
          if (!_selectedIndexes.contains(index)) {
            setState(() {
              _selectedIndexes.add(index);
            });
            HapticService().buttonTapFeedback();
            print('✅ Added adjacent letter: ${_letters[index]}');
          } else {
            print('⚠️ Letter already selected: ${_letters[index]}');
          }
        } else {
          print('❌ Letter not adjacent to last selected: ${_letters[index]}');
          print('🔍 Available neighbors: ${neighbors.map((i) => _letters[i]).join(', ')}');
          // Don't return here - let the user continue dragging
        }
      }
    }
  }

  void _checkWordCompletion() {
    final word = _availableCards[_currentCardIndex].word.toUpperCase();
    
    // Check if we have all the letters needed (including hints)
    if (_selectedIndexes.length == word.length) {
      // Complete the word regardless of how it was achieved
      _completeWord();
    }
  }
  
  void _completeWord() {
    final word = _availableCards[_currentCardIndex].word.toUpperCase();
    
    setState(() {
      _hintLevel = 0;
    });
    
    // Track the studied word
    _studiedWords.add(_availableCards[_currentCardIndex]);
    
    // Mark the card as correct to properly record the attempt and reduce HP
    _availableCards[_currentCardIndex].markCorrect(GameDifficulty.medium);
    
    // Advance the current unanswered index if this was the current question
    if (_currentCardIndex == _currentUnansweredIndex) {
      _currentUnansweredIndex++;
    }
    
    // Calculate XP with hint penalty (-1 XP per hint used)
    String currentWordId = _availableCards[_currentCardIndex].id;
    int baseXP = 10;
    int hintPenalty = _hintsUsedPerWord[currentWordId] ?? 0;
    int finalXP = (baseXP - hintPenalty).clamp(0, baseXP); // Don't go below 0
    _xpGainedPerWord[currentWordId] = finalXP;
    _wordMastery[currentWordId] = _availableCards[_currentCardIndex].learningMastery;
    
    SoundManager().playCorrectSound();
    _successController.forward(from: 0);
    
    // Show feedback message
    setState(() {
      _showFeedback = true;
      _feedbackMessage = 'Correct! The answer is ${_availableCards[_currentCardIndex].word.toUpperCase()}';
    });
    
    // Save the answer state for this word (after feedback is set)
    _answeredWords[currentWordId] = List.from(_selectedIndexes);
    _answeredHintLevels[currentWordId] = _hintLevel;
    _answeredHintIndexes[currentWordId] = List.from(_hintIndexes);
    _answeredShowFeedback[currentWordId] = _showFeedback;
    
    // Auto-progress if enabled, otherwise wait for user to click Next
    if (widget.autoProgress) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _nextWord();
      });
    }
  }
  
  void _checkWord() {
    final word = _availableCards[_currentCardIndex].word.toUpperCase();
    String formedWord = _selectedIndexes.map((i) => _letters[i]).join("");
    
    if (formedWord == word) {
      // Correct word!
      _completeWord();
    }
    // Note: We don't reset selection for wrong words anymore - let user continue building
  }

  void _nextWord() {
    setState(() {
      _currentCardIndex++;
      // Clear hint state for new exercise
      _hintLevel = 0;
      _hintIndexes.clear();
      _selectedIndexes.clear();
      _wrongIndexes.clear();
      _isShowingHint = false;
      _showFeedback = false; // Clear feedback message
      _feedbackMessage = '';
    });
    
    if (_currentCardIndex >= _availableCards.length) {
      _gameCompleted = true;
      _showGameCompleteDialog();
    } else {
      _setupGrid();
      // Restart timer for timed mode
      if (_isTimedMode && widget.timePerQuestion != null) {
        _timeRemaining = widget.timePerQuestion!;
        _startTimer();
      }
    }
  }
  
  void _proceedToNext() {
    if (_showFeedback) {
      _nextWord();
    }
  }
  
  VoidCallback? _getNextButtonAction() {
    // If there are unanswered questions ahead, go to next word
    if (_hasNextUnansweredQuestion()) {
      return _goToNextWord;
    }
    
    // If showing feedback and auto-progress is off, proceed to next
    if (_showFeedback && !widget.autoProgress) {
      return _proceedToNext;
    }
    
    // If we're on the last exercise and it's completed, proceed to end screen
    if (_currentCardIndex == _availableCards.length - 1 && 
        _answeredWords.containsKey(_availableCards[_currentCardIndex].id)) {
      return _proceedToNext;
    }
    
    // Otherwise, button is disabled
    return null;
  }

  int _getHintIndex(int index) {
    return _correctPath.indexOf(index);
  }

  void _showHint() {
    if (_hintLevel >= _availableCards[_currentCardIndex].word.length) return;
    
    setState(() {
      _hintLevel++;
      
      // Track hints used for this word
      String currentWordId = _availableCards[_currentCardIndex].id;
      _hintsUsedPerWord[currentWordId] = (_hintsUsedPerWord[currentWordId] ?? 0) + 1;
      
      // Add the hinted letter to hint indexes (permanently highlight it)
      if (_hintLevel <= _correctPath.length) {
        int hintIndex = _correctPath[_hintLevel - 1];
        if (!_hintIndexes.contains(hintIndex)) {
          _hintIndexes.add(hintIndex);
        }
        // Also add to selected indexes so it's part of the current selection
        if (!_selectedIndexes.contains(hintIndex)) {
          _selectedIndexes.add(hintIndex);
        }
      }
      
      // Check if word is now complete after adding hint
      _checkWordCompletion();
      
      // If all hints are used, force completion
      if (_hintLevel >= _availableCards[_currentCardIndex].word.length) {
        _completeWord();
      }
    });
    
    HapticService().buttonTapFeedback();
  }


  void _showGameCompleteDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UnifiedEndScreen(
          studiedWords: _studiedWords,
          xpGainedPerWord: _xpGainedPerWord,
          wordMastery: _wordMastery,
          title: 'Connect Cards Complete',
          showSwipeToReview: false,
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close end screen
            _restartGame();
          },
          onShuffle: () {
            Navigator.of(context).pop(); // Close end screen
            _restartGameWithShuffle();
          },
          onDone: () {
            Navigator.of(context).pop(); // Close end screen
            Navigator.of(context).pop(); // Exit game
          },
        ),
      ),
    );
  }

  void _restartGame() {
    setState(() {
      _currentCardIndex = 0;
      _hintLevel = 0;
      _gameCompleted = false;
      
      // Reset tracking variables
      _studiedWords.clear();
      _xpGainedPerWord.clear();
      _wordMastery.clear();
      _hintsUsedPerWord.clear();
      _answeredWords.clear();
      _answeredHintLevels.clear();
      _answeredHintIndexes.clear();
      _answeredShowFeedback.clear();
      _savedGridLetters.clear();
      _savedCorrectPaths.clear();
      _savedGridSizes.clear();
      _currentUnansweredIndex = 0;
      _hasNavigatedBack = false;
      
      // Reset lives if in lives mode
      if (_isLivesMode) {
        _maxLives = widget.customLives ?? 3;
        _livesRemaining = _maxLives;
      }
    });
    _shuffleCards();
    _setupGrid();
  }

  void _restartGameWithShuffle() {
    // Get new cards from the same deck configuration
    _getNewCardsFromDeck();
    
    setState(() {
      _currentCardIndex = 0;
      _hintLevel = 0;
      _gameCompleted = false;
      
      // Reset tracking variables
      _studiedWords.clear();
      _xpGainedPerWord.clear();
      _wordMastery.clear();
      _hintsUsedPerWord.clear();
      _answeredWords.clear();
      _answeredHintLevels.clear();
      _answeredHintIndexes.clear();
      _answeredShowFeedback.clear();
      _savedGridLetters.clear();
      _savedCorrectPaths.clear();
      _savedGridSizes.clear();
      _currentUnansweredIndex = 0;
      _hasNavigatedBack = false;
      
      // Reset lives if in lives mode
      if (_isLivesMode) {
        _maxLives = widget.customLives ?? 3;
        _livesRemaining = _maxLives;
      }
    });
    _shuffleCards();
    _setupGrid();
  }

  void _goToPreviousWord() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _wrongIndexes.clear();
        _isShowingHint = false;
        _hasNavigatedBack = true; // Mark that user has pressed Back
        
        // Check if this word was already answered
        String wordId = _availableCards[_currentCardIndex].id;
        if (_answeredWords.containsKey(wordId)) {
          // Restore the answered state
          _selectedIndexes = List.from(_answeredWords[wordId]!);
          _hintLevel = _answeredHintLevels[wordId] ?? 0;
          _hintIndexes = List.from(_answeredHintIndexes[wordId] ?? []);
          _showFeedback = _answeredShowFeedback[wordId] ?? false;
          if (_showFeedback) {
            _feedbackMessage = 'Correct! The answer is ${_availableCards[_currentCardIndex].word.toUpperCase()}';
          }
        } else {
          // Reset for unanswered word
          _selectedIndexes.clear();
          _hintLevel = 0;
          _hintIndexes.clear();
          _showFeedback = false;
          _feedbackMessage = '';
        }
      });
      // Always call _setupGrid() to restore the correct grid state
      _setupGrid();
    }
  }

  bool _hasNextUnansweredQuestion() {
    // Only allow going to the current unanswered question (next in sequence)
    // AND only if the user has previously pressed Back
    return _currentCardIndex < _currentUnansweredIndex && _hasNavigatedBack;
  }

  void _goToNextWord() {
    // Only go to the current unanswered question (next in sequence)
    if (_currentCardIndex < _currentUnansweredIndex) {
      setState(() {
        _currentCardIndex++;
        _wrongIndexes.clear();
        _isShowingHint = false;
        
        // Check if this word was already answered
        String wordId = _availableCards[_currentCardIndex].id;
        if (_answeredWords.containsKey(wordId)) {
          // Restore the answered state
          _selectedIndexes = List.from(_answeredWords[wordId]!);
          _hintLevel = _answeredHintLevels[wordId] ?? 0;
          _hintIndexes = List.from(_answeredHintIndexes[wordId] ?? []);
          _showFeedback = _answeredShowFeedback[wordId] ?? false;
          if (_showFeedback) {
            _feedbackMessage = 'Correct! The answer is ${_availableCards[_currentCardIndex].word.toUpperCase()}';
          }
        } else {
          // Reset for unanswered word - clear all hint state for new exercise
          _selectedIndexes.clear();
          _hintLevel = 0;
          _hintIndexes.clear();
          _showFeedback = false;
          _feedbackMessage = '';
        }
      });
      _setupGrid();
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Game'),
        content: const Text('Are you sure you want to exit? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Exit game
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameCompleted) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            // Small header
            SafeArea(
              child: Container(
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
                      'Connect',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.home),
                      iconSize: 20,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
            // Game complete message
            const Expanded(
              child: Center(
                child: Text(
                  'Game Complete!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    final currentCard = _availableCards[_currentCardIndex];
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Small header with progress bar
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _showExitConfirmation(),
                        icon: const Icon(Icons.arrow_back_ios),
                        iconSize: 20,
                      ),
                      const Spacer(),
                      const Text(
                        'Connect',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.home),
                        iconSize: 20,
                        onPressed: () => _showExitConfirmation(),
                      ),
                    ],
                  ),
                ),
                // Progress bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_currentCardIndex + 1}/${_availableCards.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          // Show lives or timer in the middle if active
                          if (_isLivesMode) _buildLivesIndicator(),
                          if (_isTimedMode && !_isLivesMode) _buildTimerIndicator(),
                          Text(
                            '${((_currentCardIndex + 1) / _availableCards.length * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_currentCardIndex + 1) / _availableCards.length,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Main content area with swipe navigation
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                // Swipe left to go to next word - only when not interacting with grid
                if (details.primaryVelocity! > 0 && _hasNextUnansweredQuestion()) {
                  _goToNextWord();
                }
                // Swipe right disabled - only allow swipe left for next word
              },
              child: Column(
                children: [
          // Word to translate
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              "Translate: ${currentCard.definition}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Game grid with fixed height - increased for larger cells
          SizedBox(
            height: 420, // Increased height for larger, more touch-friendly cells
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Listener(
                  onPointerDown: (details) {
                    print('🔍 Pointer down at: ${details.localPosition}');
                    _onPointerDown(details, constraints);
                  },
                  onPointerMove: (details) {
                    if (_isDragging) {
                      print('🔍 Pointer move at: ${details.localPosition}');
                      _onPointerMove(details, constraints);
                    }
                  },
                  onPointerUp: (details) {
                    print('🔍 Pointer up');
                    _onPointerUp(details);
                  },
                  onPointerCancel: (details) {
                    print('🔍 Pointer cancel');
                    _onPointerCancel(details);
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: CustomPaint(
                      painter: GridPainter(
                        letters: _letters,
                        gridSize: _gridSize,
                        selectedIndexes: _selectedIndexes,
                        wrongIndexes: _wrongIndexes,
                        hintIndexes: _hintIndexes,
                        answeredWords: _answeredWords.containsKey(_availableCards[_currentCardIndex].id),
                        pressedIndex: _pressedIndex,
                        dragPosition: _dragPosition,
                      ),
                      child: Container(
                        width: constraints.maxWidth - 32,
                        height: constraints.maxWidth - 32,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Back, Hint, and Next buttons - directly under grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentCardIndex > 0 ? _goToPreviousWord : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.lightbulb),
                  iconSize: 24,
                  onPressed: _answeredWords.containsKey(currentCard.id) ? null : _showHint,
                  tooltip: _answeredWords.containsKey(currentCard.id) 
                      ? "Word already answered" 
                      : "Show hint (${_hintLevel}/${currentCard.word.length})",
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.orange[100],
                    foregroundColor: Colors.orange[800],
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _getNextButtonAction(),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          
          // Feedback message - moved below navigation buttons
          if (_showFeedback)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _feedbackMessage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
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
