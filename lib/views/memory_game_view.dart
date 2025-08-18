import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/flash_card.dart';
import '../models/dutch_word_exercise.dart';
import '../models/game_session.dart';
import '../services/sound_manager.dart';
import '../services/xp_service.dart';
import '../services/haptic_service.dart';

import '../components/animated_xp_counter.dart';

class MemoryGameView extends StatefulWidget {
  final List<FlashCard> cards;
  final bool startFlipped;
  final Function(bool)? onComplete;
  final bool shuffleMode;

  const MemoryGameView({
    super.key,
    required this.cards,
    this.startFlipped = false,
    this.onComplete,
    this.shuffleMode = false,
  });

  @override
  State<MemoryGameView> createState() => _MemoryGameViewState();
}

class _MemoryGameViewState extends State<MemoryGameView> 
    with TickerProviderStateMixin {
  List<MemoryCard> _memoryCards = [];
  List<FlashCard> _remainingCards = [];
  MemoryCard? _firstCard;
  MemoryCard? _secondCard;
  bool _canSelect = true;
  int _moves = 0;
  int _matches = 0;
  bool _gameComplete = false;
  int _totalPairs = 5; // Always show 5 pairs at a time
  int _totalCardsProcessed = 0; // Track how many cards have been used
  List<AnimationController> _floatingControllers = [];
  List<Animation<Offset>> _floatingAnimations = [];
  final GameSession _gameSession = GameSession();
  List<_ReplacementRequest> _replacementQueue = []; // Queue for replacement requests
  bool _isProcessingReplacements = false; // Track if we're currently processing replacements

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    for (var controller in _floatingControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeGame() {
    // Initialize remaining cards list (all cards except the first 5 which we'll use immediately)
    _remainingCards = List.from(widget.cards);
    _totalCardsProcessed = 0;
    _matches = 0;
    _moves = 0;
    _replacementQueue.clear();
    _isProcessingReplacements = false;
    
    // If we have 5 or fewer cards, use all of them and the game ends when all are matched
    if (widget.cards.length <= 5) {
      _totalPairs = widget.cards.length;
      _createMemoryCards(widget.cards);
      _remainingCards.clear();
      print('🔍 MemoryGameView: Small deck mode - ${widget.cards.length} cards, no replacement');
    } else {
      // If we have more than 5 cards, start with first 5 and keep the rest for replacement
      _totalPairs = 5;
      final initialCards = _remainingCards.take(5).toList();
      _remainingCards.removeRange(0, 5);
      // Start with 0 processed - cards are only "processed" when they're matched/completed
      _totalCardsProcessed = 0;
      _createMemoryCards(initialCards);
      print('🔍 MemoryGameView: Large deck mode - ${widget.cards.length} total cards, ${_remainingCards.length} remaining for replacement');
      print('🔍 MemoryGameView: Starting with 0/${widget.cards.length} cards processed');
    }
  }
  
  void _createMemoryCards(List<FlashCard> cardsToUse) {
    _memoryCards = [];
    
    // Clear existing animations
    for (var controller in _floatingControllers) {
      controller.dispose();
    }
    _floatingControllers.clear();
    _floatingAnimations.clear();
    
    for (final card in cardsToUse) {
      // Add word card
      _memoryCards.add(MemoryCard(
        id: '${card.id}_word',
        content: card.word,
        type: MemoryCardType.word,
        originalCard: card,
        isMatched: false,
        isSelected: false,
        isWrong: false,
        isFadingOut: false,
        isFadingIn: false,
      ));
      
      // Add definition card
      _memoryCards.add(MemoryCard(
        id: '${card.id}_def',
        content: card.definition,
        type: MemoryCardType.definition,
        originalCard: card,
        isMatched: false,
        isSelected: false,
        isWrong: false,
        isFadingOut: false,
        isFadingIn: false,
      ));
    }
    
    // Shuffle the cards
    _memoryCards.shuffle();
    
    // Create floating animations for each card
    _createFloatingAnimations();
  }
  
  void _createFloatingAnimations() {
    final random = Random();
    
    for (int i = 0; i < _memoryCards.length; i++) {
      // Create unique animation controller for each card
      final controller = AnimationController(
        duration: Duration(
          milliseconds: 3000 + random.nextInt(2000), // 3-5 seconds
        ),
        vsync: this,
      );
      
      // Create random floating movement within bounds (increased range for visibility)
      final beginOffset = Offset(
        (random.nextDouble() - 0.5) * 60, // -30 to 30 pixels
        (random.nextDouble() - 0.5) * 40, // -20 to 20 pixels
      );
      final endOffset = Offset(
        (random.nextDouble() - 0.5) * 60,
        (random.nextDouble() - 0.5) * 40,
      );
      
      final animation = Tween<Offset>(
        begin: beginOffset,
        end: endOffset,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));
      
      print('🔍 MemoryGameView: Created floating animation $i - Begin: $beginOffset, End: $endOffset');
      
      _floatingControllers.add(controller);
      _floatingAnimations.add(animation);
      
      // Start the animation with random delay
      Future.delayed(Duration(milliseconds: random.nextInt(1000)), () {
        if (mounted) {
          controller.repeat(reverse: true);
        }
      });
    }
  }
  
  void _updateFloatingAnimation(int index) {
    if (index >= _floatingControllers.length) return;
    
    final random = Random();
    
    // Reset the controller
    _floatingControllers[index].reset();
    
    // Create new random floating movement (increased range for visibility)
    final beginOffset = Offset(
      (random.nextDouble() - 0.5) * 60, // -30 to 30 pixels
      (random.nextDouble() - 0.5) * 40, // -20 to 20 pixels
    );
    final endOffset = Offset(
      (random.nextDouble() - 0.5) * 60,
      (random.nextDouble() - 0.5) * 40,
    );
    
    final newAnimation = Tween<Offset>(
      begin: beginOffset,
      end: endOffset,
    ).animate(CurvedAnimation(
      parent: _floatingControllers[index],
      curve: Curves.easeInOut,
    ));
    
    print('🔍 MemoryGameView: Updated floating animation $index - Begin: $beginOffset, End: $endOffset');
    
    _floatingAnimations[index] = newAnimation;
    
    // Start the animation with random delay
    Future.delayed(Duration(milliseconds: random.nextInt(500)), () {
      if (mounted) {
        _floatingControllers[index].repeat(reverse: true);
      }
    });
  }
  
  // Removed pause/resume functions since we want continuous smooth movement

  @override
  Widget build(BuildContext context) {
    if (_gameComplete) {
      return _buildResultsView();
    }

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
                        onPressed: () => _showCloseConfirmation(),
                        icon: const Icon(Icons.arrow_back_ios),
                        iconSize: 20,
                      ),
                      const Spacer(),
                      Text(
                        'Memory Game',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _showHomeConfirmation(),
                        icon: const Icon(Icons.home),
                        iconSize: 20,
                      ),
                    ],
                  ),
                ),
                _buildProgressBar(),
              ],
            ),
          ),
          
          // Game board
          Expanded(
            child: _buildGameBoard(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final totalCards = widget.cards.length;
    final progress = _totalCardsProcessed / totalCards;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cards processed: $_totalCardsProcessed of $totalCards'),
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



  Widget _buildGameBoard() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First row of cards
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: _memoryCards.take(5).map((card) {
                  final index = _memoryCards.indexOf(card);
                  return SizedBox(
                    width: 140,
                    height: 70,
                    child: _buildFloatingCard(card, index),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // Second row of cards
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: _memoryCards.skip(5).map((card) {
                  final index = _memoryCards.indexOf(card);
                  return SizedBox(
                    width: 140,
                    height: 70,
                    child: _buildFloatingCard(card, index),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCard(MemoryCard card, int index) {
    // Ensure we have a valid animation for this card
    if (index >= _floatingAnimations.length) {
      print('🔍 MemoryGameView: No animation for card $index, using static card');
      return _buildMemoryCard(card);
    }

    return AnimatedBuilder(
      animation: _floatingAnimations[index],
      builder: (context, child) {
        final offset = _floatingAnimations[index].value;
        return Transform.translate(
          offset: offset,
          child: _buildMemoryCard(card),
        );
      },
    );
  }

  Widget _buildMemoryCard(MemoryCard card) {
    Color borderColor;
    Color backgroundColor;
    List<BoxShadow> shadows;
    
    if (card.isMatched) {
      borderColor = Colors.green;
      backgroundColor = Colors.white;
      shadows = [
        BoxShadow(
          color: Colors.green.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (card.isWrong) {
      borderColor = Colors.red;
      backgroundColor = Colors.red.withValues(alpha: 0.1);
      shadows = [
        BoxShadow(
          color: Colors.red.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (card.isSelected) {
      borderColor = Colors.blue;
      backgroundColor = Colors.blue.withValues(alpha: 0.1);
      shadows = [
        BoxShadow(
          color: Colors.blue.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
    } else {
      borderColor = _getMemoryCardBorderColor(card);
      backgroundColor = Colors.white;
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];
    }
    
    return GestureDetector(
      onTap: () => _selectCard(card),
      child: AnimatedOpacity(
        opacity: _calculateCardOpacity(card),
        duration: Duration(milliseconds: card.isFadingOut || card.isFadingIn ? 500 : 200),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 70,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: card.isSelected || card.isMatched || card.isWrong ? 3 : 2,
            ),
            boxShadow: shadows,
          ),
          child: _buildCardContent(card),
        ),
      ),
    );
  }

  Widget _buildCardContent(MemoryCard card) {
    return Center(
      child: Text(
        card.content,
        style: TextStyle(
          fontSize: _calculateFontSize(card.content),
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  double _calculateFontSize(String text) {
    // Base font size
    double baseSize = 16.0;
    
    // Reduce font size for longer text
    if (text.length > 20) {
      baseSize = 14.0;
    }
    if (text.length > 30) {
      baseSize = 12.0;
    }
    if (text.length > 40) {
      baseSize = 10.0;
    }
    
    return baseSize;
  }

  double _calculateCardOpacity(MemoryCard card) {
    // If card is fading out, keep it invisible
    if (card.isFadingOut) {
      return 0.0;
    }
    
    // If card is fading in, show it
    if (card.isFadingIn) {
      return 1.0;
    }
    
    // If card is matched, hide it
    if (card.isMatched) {
      return 0.0;
    }
    
    // Check if this card is in the replacement queue (waiting to be replaced)
    if (_isCardInReplacementQueue(card.id)) {
      return 0.0; // Keep it invisible while waiting
    }
    
    // Otherwise, show the card normally
    return 1.0;
  }

  bool _isCardInReplacementQueue(String cardId) {
    return _replacementQueue.any((request) => 
      request.firstCardId == cardId || request.secondCardId == cardId
    );
  }

  Color _getMemoryCardBorderColor(MemoryCard card) {
    // Generate random vibrant colors to prevent color-based matching
    final vibrantColors = [
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF673AB7), // Deep Purple
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFF2196F3), // Blue
      const Color(0xFF03A9F4), // Light Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF009688), // Teal
      const Color(0xFF4CAF50), // Green
      const Color(0xFF8BC34A), // Light Green
      const Color(0xFFCDDC39), // Lime
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFFFFC107), // Amber
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF795548), // Brown
    ];
    
    // Use the MemoryCard's unique ID to generate random colors
    // This ensures each individual card (word/definition) gets a different color
    final random = Random(card.id.hashCode);
    final index = random.nextInt(vibrantColors.length);
    return vibrantColors[index];
  }



  void _selectCard(MemoryCard card) {
    if (!_canSelect || card.isMatched) return;
    
    // Provide haptic feedback for card selection
    HapticService().memoryGameFeedback();
    
    // If clicking the same card that's already selected, deselect it
    if (_firstCard != null && _firstCard!.id == card.id) {
      print('🔍 MemoryGameView: Deselecting first card');
      setState(() {
        _firstCard!.isSelected = false;
        _firstCard = null;
      });
      return;
    }

    setState(() {
      card.isSelected = true;
    });

    if (_firstCard == null) {
      _firstCard = card;
    } else {
      _secondCard = card;
      _moves++;
      _checkMatch();
    }
  }

  void _checkMatch() {
    if (_firstCard == null || _secondCard == null) return;

    final isMatch = _firstCard!.originalCard.id == _secondCard!.originalCard.id;

    if (isMatch) {
      // Play correct sound and provide haptic feedback
      SoundManager().playCorrectSound();
      HapticService().successFeedback();
      
      // Track XP for correct match
      XpService.recordAnswer(_gameSession, true);
      
      // Update learning progress for the matched card
      _updateCardLearningProgress(_firstCard!.originalCard, true).catchError((e) {
        print('🔍 MemoryGameView: Error in background update: $e');
      });

      setState(() {
        _matches++;
        _firstCard!.isSelected = false;
        _secondCard!.isSelected = false;
      });

      // Count each matched pair as one card processed
      _totalCardsProcessed++;
      
      // Check if we should replace the matched pair with new cards
      if (_remainingCards.isNotEmpty) {
        final newCard = _remainingCards.removeAt(0);
        
        print('🔍 MemoryGameView: Processed card ${_totalCardsProcessed}/${widget.cards.length}');
        print('🔍 MemoryGameView: Queueing replacement for "${newCard.word}" - "${newCard.definition}"');
        print('🔍 MemoryGameView: Remaining cards: ${_remainingCards.length}');
        
        // Find the indices of the matched cards to replace them in the same positions
        final firstCardIndex = _memoryCards.indexWhere((card) => card.id == _firstCard!.id);
        final secondCardIndex = _memoryCards.indexWhere((card) => card.id == _secondCard!.id);
        
        print('🔍 MemoryGameView: First card index: $firstCardIndex, Second card index: $secondCardIndex');
        
        // Add replacement request to queue
        _replacementQueue.add(_ReplacementRequest(
          newCard: newCard,
          firstCardIndex: firstCardIndex,
          secondCardIndex: secondCardIndex,
          firstCardId: _firstCard!.id,
          secondCardId: _secondCard!.id,
        ));
        
        // Start gentle fade out animation for matched cards only
        setState(() {
          _firstCard!.isFadingOut = true;
          _secondCard!.isFadingOut = true;
        });
        
        // Process the replacement queue if not already processing
        if (!_isProcessingReplacements) {
          _processReplacementQueue();
        }
        
        print('🔍 MemoryGameView: Queued replacement, queue length: ${_replacementQueue.length}');
      } else {
        // No more cards to replace with, mark as matched
        setState(() {
          _firstCard!.isMatched = true;
          _secondCard!.isMatched = true;
        });
      }

      // Check if game is complete
      bool gameComplete = false;
      
      if (_remainingCards.isEmpty) {
        // For small decks (≤5 cards): game ends when all current cards are matched
        // For large decks: game ends when all cards processed and no more replacements
        if (widget.cards.length <= 5) {
          gameComplete = _memoryCards.every((card) => card.isMatched);
        } else {
          gameComplete = _totalCardsProcessed >= widget.cards.length;
        }
      }
      
      if (gameComplete) {
        // In shuffle mode, completing the memory game is always considered successful
        // because the challenge is to match pairs, not to do it efficiently
        final wasSuccessful = widget.shuffleMode ? true : 
                             (_totalCardsProcessed > 0 ? _totalCardsProcessed / _moves >= 0.5 : false);
        
        print('🔍 MemoryGameView: Game complete! Shuffle mode: ${widget.shuffleMode}, Success: $wasSuccessful');
        print('🔍 MemoryGameView: XP gained this session: ${_gameSession.xpGained}');
        
        // Award XP to user profile if not in shuffle mode (shuffle mode handles XP separately)
        _awardXp();
        
        // Call the onComplete callback if provided
        if (widget.onComplete != null) {
          widget.onComplete!(wasSuccessful);
          return;
        }
        
        setState(() {
          _gameComplete = true;
        });
        // Play completion sound when game is finished
        SoundManager().playCompleteSound();
      }

      // Reset selection state
      setState(() {
        _firstCard = null;
        _secondCard = null;
        _canSelect = true;
      });
    } else {
      // Track XP for incorrect match (0 XP)
      XpService.recordAnswer(_gameSession, false);
      
      // Update learning progress for the mismatched cards (as incorrect attempts)
      _updateCardLearningProgress(_firstCard!.originalCard, false).catchError((e) {
        print('🔍 MemoryGameView: Error in background update: $e');
      });
      _updateCardLearningProgress(_secondCard!.originalCard, false).catchError((e) {
        print('🔍 MemoryGameView: Error in background update: $e');
      });
      
      // In shuffle mode, end the game immediately on incorrect match
      if (widget.shuffleMode && widget.onComplete != null) {
        widget.onComplete!(false);
        return;
      }
      
      setState(() {
        _firstCard!.isWrong = true;
        _secondCard!.isWrong = true;
        _firstCard!.isSelected = false;
        _secondCard!.isSelected = false;
      });

      // Play wrong sound and provide haptic feedback
      SoundManager().playWrongSound();
      HapticService().errorFeedback();

      // Reset wrong cards after a delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _firstCard!.isWrong = false;
            _secondCard!.isWrong = false;
            _firstCard = null;
            _secondCard = null;
            _canSelect = true;
          });
        }
      });
    }
  }

  void _processReplacementQueue() {
    if (_replacementQueue.isEmpty || _isProcessingReplacements) {
      return;
    }

    _isProcessingReplacements = true;
    print('🔍 MemoryGameView: Processing replacement queue, length: ${_replacementQueue.length}');

    // Process the first replacement in the queue
    final request = _replacementQueue.removeAt(0);
    
    // Wait for fade out to complete, then replace cards
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          // Replace the first matched card with new word card
          if (request.firstCardIndex != -1) {
            _memoryCards[request.firstCardIndex] = MemoryCard(
              id: '${request.newCard.id}_word',
              content: request.newCard.word,
              type: MemoryCardType.word,
              originalCard: request.newCard,
              isMatched: false,
              isSelected: false,
              isWrong: false,
              isFadingOut: false,
              isFadingIn: true,
            );
            // Update animation for this position
            _updateFloatingAnimation(request.firstCardIndex);
          }
          
          // Replace the second matched card with new definition card
          if (request.secondCardIndex != -1) {
            _memoryCards[request.secondCardIndex] = MemoryCard(
              id: '${request.newCard.id}_def',
              content: request.newCard.definition,
              type: MemoryCardType.definition,
              originalCard: request.newCard,
              isMatched: false,
              isSelected: false,
              isWrong: false,
              isFadingOut: false,
              isFadingIn: true,
            );
            // Update animation for this position
            _updateFloatingAnimation(request.secondCardIndex);
          }
        });
        
        print('🔍 MemoryGameView: Replaced cards for "${request.newCard.word}", queue remaining: ${_replacementQueue.length}');
        
        // After fade in completes, reset states only for the replaced cards and process next replacement
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              // Only reset states for the cards that were actually replaced
              if (request.firstCardIndex != -1 && request.firstCardIndex < _memoryCards.length) {
                _memoryCards[request.firstCardIndex].isFadingIn = false;
                _memoryCards[request.firstCardIndex].isFadingOut = false;
              }
              if (request.secondCardIndex != -1 && request.secondCardIndex < _memoryCards.length) {
                _memoryCards[request.secondCardIndex].isFadingIn = false;
                _memoryCards[request.secondCardIndex].isFadingOut = false;
              }
            });
            
            // Process next replacement in queue if any
            _isProcessingReplacements = false;
            if (_replacementQueue.isNotEmpty) {
              _processReplacementQueue();
            }
          }
        });
      }
    });
  }

  Future<void> _updateCardLearningProgress(FlashCard card, bool wasCorrect) async {
    try {
      final provider = context.read<FlashcardProvider>();
      
      // Update the card's learning progress
      final updatedCard = FlashCard(
        id: card.id,
        word: card.word,
        definition: card.definition,
        example: card.example,
        deckIds: card.deckIds,
        successCount: card.successCount,
        dateCreated: card.dateCreated,
        lastModified: DateTime.now(),
        cloudKitRecordName: card.cloudKitRecordName,
        timesShown: card.timesShown + 1,
        timesCorrect: card.timesCorrect + (wasCorrect ? 1 : 0),
        srsLevel: card.srsLevel,
        nextReviewDate: card.nextReviewDate,
        consecutiveCorrect: wasCorrect ? card.consecutiveCorrect + 1 : 0,
        consecutiveIncorrect: wasCorrect ? 0 : card.consecutiveIncorrect + 1,
        easeFactor: card.easeFactor,
        lastReviewDate: DateTime.now(),
        totalReviews: card.totalReviews + 1,
        article: card.article,
        plural: card.plural,
        pastTense: card.pastTense,
        futureTense: card.futureTense,
        pastParticiple: card.pastParticiple,
      );
      
      await provider.updateCard(updatedCard);
      print('🔍 MemoryGameView: Updated learning progress for "${card.word}" - wasCorrect: $wasCorrect, new percentage: ${updatedCard.learningPercentage}%');
      
      // Also sync to Dutch words if this card exists there
      await _syncToDutchWords(card, wasCorrect);
      
    } catch (e) {
      print('🔍 MemoryGameView: Error updating learning progress: $e');
    }
  }

  Future<void> _syncToDutchWords(FlashCard card, bool wasCorrect) async {
    try {
      // Import the DutchWordExerciseProvider
      final dutchProvider = context.read<DutchWordExerciseProvider>();
      
      // Find the corresponding Dutch word exercise
      final wordExercise = dutchProvider.wordExercises.firstWhere(
        (exercise) => exercise.targetWord.toLowerCase() == card.word.toLowerCase(),
        orElse: () => DutchWordExercise(
          id: '',
          targetWord: '',
          wordTranslation: '',
          deckId: '',
          deckName: '',
          category: WordCategory.common,
          difficulty: ExerciseDifficulty.beginner,
          exercises: [],
          createdAt: DateTime.now(),
          isUserCreated: true,
        ),
      );
      
      if (wordExercise.id.isNotEmpty) {
        // Update the Dutch word exercise learning progress
        await dutchProvider.updateLearningProgress(wordExercise.id, wasCorrect);
        print('🔍 MemoryGameView: Synced progress to Dutch word exercise "${wordExercise.targetWord}"');
      }
    } catch (e) {
      print('🔍 MemoryGameView: Error syncing to Dutch words: $e');
    }
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Memory Game?'),
        content: const Text('Are you sure you want to leave? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showHomeConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return to Home?'),
        content: const Text('Are you sure you want to return to the home screen? This will end your current memory game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      _memoryCards.clear();
      _firstCard = null;
      _secondCard = null;
      _canSelect = true;
      _moves = 0;
      _matches = 0;
      _gameComplete = false;
      _gameSession.reset(); // Reset XP tracking
      _initializeGame();
    });
  }

  void _awardXp() {
    if (!widget.shuffleMode && _gameSession.xpGained > 0) {
      final userProfileProvider = context.read<UserProfileProvider>();
      XpService.awardSessionXp(userProfileProvider, _gameSession, isShuffleMode: widget.shuffleMode);
    }
    
    // Update session statistics
    final totalPairs = _totalPairs;
    final accuracy = totalPairs > 0 ? (_matches / totalPairs) : 0.0;
    final isPerfect = _matches == totalPairs && totalPairs > 0;
    
    context.read<UserProfileProvider>().updateSessionStats(
      cardsStudied: totalPairs * 2, // Each pair has 2 cards
      sessionAccuracy: accuracy,
      isPerfect: isPerfect,
    );
    
    // Update streak based on study activity (Duolingo-style)
    context.read<UserProfileProvider>().updateStreakFromStudyActivity();
  }

  Widget _buildResultsView() {
    final efficiency = _totalCardsProcessed > 0 ? ((_totalCardsProcessed / _moves) * 100).toInt() : 0;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
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
                    'Memory Game Complete',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance the layout
                ],
              ),
            ),
          ),
          
          // Results content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Celebration icon
                  const Icon(
                    Icons.celebration,
                    size: 64,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 24),
                  
                  // Session stats
                  _buildStatCard('Cards Processed', '$_totalCardsProcessed', Icons.check_circle, Colors.green),
                  const SizedBox(height: 16),
                  _buildStatCard('Total Moves', '$_moves', Icons.touch_app, Colors.blue),
                  const SizedBox(height: 16),
                  _buildStatCard('Efficiency', '$efficiency%', Icons.analytics, Colors.orange),
                  const SizedBox(height: 16),
                  _buildStatCard('XP Earned', '', Icons.star, Colors.amber,
                    AnimatedXpCounter(xpGained: _gameSession.xpGained)),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _gameComplete = false;
                              _resetGame();
                            });
                          },
                          child: const Text('Play Again'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, [Color? color, Widget? child]) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color ?? Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          child ?? Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }


}

class MemoryCard {
  final String id;
  final String content;
  final MemoryCardType type;
  final FlashCard originalCard;
  bool isMatched;
  bool isSelected;
  bool isWrong;
  bool isFadingOut;
  bool isFadingIn;

  MemoryCard({
    required this.id,
    required this.content,
    required this.type,
    required this.originalCard,
    this.isMatched = false,
    this.isSelected = false,
    this.isWrong = false,
    this.isFadingOut = false,
    this.isFadingIn = false,
  });
}

enum MemoryCardType {
  word,
  definition,
}

class _ReplacementRequest {
  final FlashCard newCard;
  final int firstCardIndex;
  final int secondCardIndex;
  final String firstCardId;
  final String secondCardId;

  _ReplacementRequest({
    required this.newCard,
    required this.firstCardIndex,
    required this.secondCardIndex,
    required this.firstCardId,
    required this.secondCardId,
  });
} 