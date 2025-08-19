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
  // Old replacement queue system removed
  // Old processing replacements flag removed

  @override
  void initState() {
    super.initState();
    _initializeGame();
    
    // Listen for card updates from the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FlashcardProvider>();
      provider.addListener(_onProviderChanged);
    });
  }

  @override
  void dispose() {
    for (var controller in _floatingControllers) {
      controller.dispose();
    }
    
    // Remove listener when disposing
    final provider = context.read<FlashcardProvider>();
    provider.removeListener(_onProviderChanged);
    
    super.dispose();
  }

  void _onProviderChanged() {
    // Refresh cards from the provider when cards are updated
    if (mounted) {
      _refreshCardsFromProvider();
    }
  }

  void _refreshCardsFromProvider() {
    final provider = context.read<FlashcardProvider>();
    
    // Only update the content of memory cards if they've been edited, don't replace the entire structure
    for (int i = 0; i < _memoryCards.length; i++) {
      final memoryCard = _memoryCards[i];
      final updatedCard = provider.getCard(memoryCard.originalCard.id);
      
      if (updatedCard != null) {
        // Update the content but preserve all game state
        _memoryCards[i] = MemoryCard(
          id: memoryCard.id,
          content: memoryCard.type == MemoryCardType.word ? updatedCard.word : updatedCard.definition,
          type: memoryCard.type,
          originalCard: updatedCard,
          state: memoryCard.state,
          isFlipped: memoryCard.isFlipped,
        );
      }
    }
    
    // Update remaining cards carefully - only update cards that are actually in the remaining list
    for (int i = 0; i < _remainingCards.length; i++) {
      final remainingCard = _remainingCards[i];
      final updatedCard = provider.getCard(remainingCard.id);
      if (updatedCard != null) {
        _remainingCards[i] = updatedCard;
      }
    }
    
    print('🔍 MemoryGameView: Refreshed cards from provider without disrupting game state');
  }

  void _initializeGame() {
    // Initialize remaining cards list (all cards except the first 5 which we'll use immediately)
    _remainingCards = List.from(widget.cards);
    _totalCardsProcessed = 0;
    _matches = 0;
    _moves = 0;
    // Old replacement queue cleared
    // Old processing flag cleared
    
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
    
    if (widget.startFlipped) {
      // In startFlipped mode, show only definition cards that flip to reveal words
      for (final card in cardsToUse) {
        _memoryCards.add(MemoryCard(
          id: '${card.id}_flippable',
          content: card.definition, // Start with definition
          type: MemoryCardType.definition,
          originalCard: card,
          state: CardState.normal,
          isFlipped: false, // Not flipped initially
        ));
      }
    } else {
      // Normal matching mode - show both word and definition cards
      for (final card in cardsToUse) {
        // Add word card
        _memoryCards.add(MemoryCard(
          id: '${card.id}_word',
          content: card.word,
          type: MemoryCardType.word,
          originalCard: card,
          state: CardState.normal,
        ));
        
        // Add definition card
        _memoryCards.add(MemoryCard(
          id: '${card.id}_def',
          content: card.definition,
          type: MemoryCardType.definition,
          originalCard: card,
          state: CardState.normal,
        ));
      }
      
      // Shuffle the cards only in normal mode
      _memoryCards.shuffle();
    }
    
    // Create floating animations for each card
    _createFloatingAnimations();
  }
  
  void _createFloatingAnimations() {
    final random = Random();
    
    for (int i = 0; i < _memoryCards.length; i++) {
      // Create unique animation controller for each card
      final controller = AnimationController(
        duration: Duration(
          milliseconds: 4000 + random.nextInt(2000), // Increased from 3000 to 4000 for battery optimization
        ),
        vsync: this,
      );
      
      // Create random floating movement within bounds (reduced range for battery optimization)
      final beginOffset = Offset(
        (random.nextDouble() - 0.5) * 40, // Reduced from 60 to 40 pixels
        (random.nextDouble() - 0.5) * 30, // Reduced from 40 to 30 pixels
      );
      final endOffset = Offset(
        (random.nextDouble() - 0.5) * 40, // Reduced from 60 to 40 pixels
        (random.nextDouble() - 0.5) * 30, // Reduced from 40 to 30 pixels
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
      
      // Start the animation with random delay (increased delay for battery optimization)
      Future.delayed(Duration(milliseconds: 1500 + random.nextInt(1000)), () {
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
    
    // Create new random floating movement (reduced range for battery optimization)
    final beginOffset = Offset(
      (random.nextDouble() - 0.5) * 40, // Reduced from 60 to 40 pixels
      (random.nextDouble() - 0.5) * 30, // Reduced from 40 to 30 pixels
    );
    final endOffset = Offset(
      (random.nextDouble() - 0.5) * 40, // Reduced from 60 to 40 pixels
      (random.nextDouble() - 0.5) * 30, // Reduced from 40 to 30 pixels
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
    
    // Start the animation with random delay (increased delay for battery optimization)
    Future.delayed(Duration(milliseconds: 1000 + random.nextInt(500)), () {
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
                        widget.startFlipped ? 'Study Cards' : 'Memory Game',
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
    
    switch (card.state) {
      case CardState.matched:
        borderColor = Colors.green;
        backgroundColor = Colors.green.withValues(alpha: 0.8); // Strong green background
        shadows = [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ];
        break;
      case CardState.wrong:
        borderColor = Colors.red;
        backgroundColor = Colors.red.withValues(alpha: 0.8); // Strong red background
        shadows = [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ];
        break;
      case CardState.selected:
        borderColor = Colors.blue;
        backgroundColor = Colors.blue.withValues(alpha: 0.8); // Strong blue background
        shadows = [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ];
        break;
      case CardState.normal:
      case CardState.fadingIn:
        borderColor = _getMemoryCardBorderColor(card);
        // Add a subtle background color for light mode, keep surface color for dark mode
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        backgroundColor = isDarkMode 
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surfaceVariant;
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
        break;
    }
    
    return GestureDetector(
      onTap: () => _selectCard(card),
      child: AnimatedOpacity(
        opacity: _calculateCardOpacity(card),
        duration: Duration(milliseconds: card.state == CardState.matched ? 300 : card.state == CardState.fadingIn ? 400 : 200),
        curve: card.state == CardState.fadingIn ? Curves.easeOutBack : Curves.easeInOut,
        child: AnimatedScale(
          scale: card.state == CardState.fadingIn ? 1.0 : (card.state == CardState.matched ? 0.9 : 1.0),
          duration: Duration(milliseconds: card.state == CardState.fadingIn ? 400 : 300),
          curve: card.state == CardState.fadingIn ? Curves.easeOutBack : Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 70,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: card.state == CardState.normal || card.state == CardState.fadingIn ? 2 : 3,
            ),
            boxShadow: shadows,
          ),
          child: _buildCardContent(card),
          ),
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
          color: Theme.of(context).colorScheme.onSurface,
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
    switch (card.state) {
      case CardState.matched:
        return 0.0; // Fade out matched cards completely
      case CardState.fadingIn:
        return 1.0; // New cards fade in
      case CardState.normal:
      case CardState.selected:
      case CardState.wrong:
        return 1.0; // All other states are fully visible
    }
  }

  // Old _isCardInReplacementQueue method removed

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
    // Only allow selection of normal cards
    if (!_canSelect || card.state != CardState.normal) {
      print('🔍 MemoryGameView: Card selection blocked - canSelect: $_canSelect, state: ${card.state}');
      return;
    }
    
    // Provide haptic feedback for card selection
    HapticService().memoryGameFeedback();
    
    // In startFlipped mode, handle card flipping behavior
    if (widget.startFlipped) {
      setState(() {
        if (!card.isFlipped) {
          // Flip card to show word
          card.isFlipped = true;
          card.content = card.originalCard.word;
          card.state = CardState.selected;
          print('🔍 MemoryGameView: Flipped card to show word: ${card.content}');
        } else {
          // Flip card back to show definition
          card.isFlipped = false;
          card.content = card.originalCard.definition;
          card.state = CardState.normal;
          print('🔍 MemoryGameView: Flipped card back to show definition: ${card.content}');
        }
      });
      return;
    }
    
    // Normal matching game behavior
    // If clicking the same card that's already selected, deselect it
    if (_firstCard != null && _firstCard!.id == card.id) {
      print('🔍 MemoryGameView: Deselecting first card');
      setState(() {
        _firstCard!.state = CardState.normal;
        _firstCard = null;
      });
      return;
    }

    setState(() {
      // Clear any existing wrong states on all cards when making a new selection
      for (final memoryCard in _memoryCards) {
        if (memoryCard.state == CardState.wrong) {
          memoryCard.state = CardState.normal;
        }
      }
      
      // Set this card as selected
      card.state = CardState.selected;
    });

    if (_firstCard == null) {
      _firstCard = card;
      print('🔍 MemoryGameView: Selected first card: ${card.content}');
    } else {
      _secondCard = card;
      _moves++;
      print('🔍 MemoryGameView: Selected second card: ${card.content}, checking match...');
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

      // Store references to the matched cards
      final matchedFirstCard = _firstCard!;
      final matchedSecondCard = _secondCard!;

      setState(() {
        _matches++;
        // Set cards to matched state (green background + will fade out)
        matchedFirstCard.state = CardState.matched;
        matchedSecondCard.state = CardState.matched;
      });

      // Count each matched pair as one card processed
      _totalCardsProcessed++;
      
      // Reset selection state immediately and re-enable selection
      _firstCard = null;
      _secondCard = null;
      _canSelect = true; // Allow immediate next selection
      
      print('🔍 MemoryGameView: Match found! Cards fading out...');

      // Schedule replacement/removal after fade out
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _replaceMatchedCards(matchedFirstCard, matchedSecondCard);
        }
      });

      // Check if game is complete
      bool gameComplete = false;
      
      _checkGameCompletion();
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
      
      // Store references to the wrong cards
      final wrongFirstCard = _firstCard!;
      final wrongSecondCard = _secondCard!;
      
      setState(() {
        wrongFirstCard.state = CardState.wrong;
        wrongSecondCard.state = CardState.wrong;
      });

      // Play wrong sound and provide haptic feedback
      SoundManager().playWrongSound();
      HapticService().errorFeedback();

      // Reset selection state immediately but allow new selections
      _firstCard = null;
      _secondCard = null;
      _canSelect = true;
      
      print('🔍 MemoryGameView: Wrong match! Cards will reset to normal...');
      
      // Reset wrong cards after showing the red state briefly
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            wrongFirstCard.state = CardState.normal;
            wrongSecondCard.state = CardState.normal;
          });
        }
      });
    }
  }

  void _replaceMatchedCards(MemoryCard firstCard, MemoryCard secondCard) {
    if (_remainingCards.isEmpty) {
      print('🔍 MemoryGameView: No more cards to replace with - removing matched cards completely');
      setState(() {
        // Remove matched cards completely from the grid
        _memoryCards.removeWhere((card) => card.id == firstCard.id || card.id == secondCard.id);
      });
      _checkGameCompletion();
      return;
    }
    
    final newCard = _remainingCards.removeAt(0);
    print('🔍 MemoryGameView: Replacing matched cards with "${newCard.word}" - "${newCard.definition}"');
    
    setState(() {
      // Find and replace the matched cards
      final firstIndex = _memoryCards.indexWhere((card) => card.id == firstCard.id);
      final secondIndex = _memoryCards.indexWhere((card) => card.id == secondCard.id);
      
      if (firstIndex != -1) {
        _memoryCards[firstIndex] = MemoryCard(
          id: '${newCard.id}_word',
          content: newCard.word,
          type: MemoryCardType.word,
          originalCard: newCard,
          state: CardState.fadingIn,
          isFlipped: false,
        );
        _updateFloatingAnimation(firstIndex);
      }
      
      if (secondIndex != -1) {
        _memoryCards[secondIndex] = MemoryCard(
          id: '${newCard.id}_def',
          content: newCard.definition,
          type: MemoryCardType.definition,
          originalCard: newCard,
          state: CardState.fadingIn,
          isFlipped: false,
        );
        _updateFloatingAnimation(secondIndex);
      }
    });
    
    // Don't shuffle - keep cards in their original positions
    
    // After fade in completes, set cards to normal state
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          for (final card in _memoryCards) {
            if (card.state == CardState.fadingIn) {
              card.state = CardState.normal;
            }
          }
        });
        _checkGameCompletion();
      }
    });
  }
  
  void _checkGameCompletion() {
    bool gameComplete = false;
    
    // In startFlipped mode, game completion is different (study mode)
    if (widget.startFlipped) {
      // In study mode, user can continue flipping cards - no automatic completion
      return;
    }
    
    // For small decks (≤5 cards): game ends when all cards are removed from grid
    if (widget.cards.length <= 5) {
      gameComplete = _memoryCards.isEmpty;
    } else {
      // For large decks: game ends when all cards processed and no more replacements
      gameComplete = _remainingCards.isEmpty && _totalCardsProcessed >= widget.cards.length;
    }
    
    if (gameComplete) {
      // In shuffle mode, completing the memory game is always considered successful
      final wasSuccessful = widget.shuffleMode ? true : 
                           (_totalCardsProcessed > 0 ? _totalCardsProcessed / _moves >= 0.5 : false);
      
      print('🔍 MemoryGameView: Game complete! Shuffle mode: ${widget.shuffleMode}, Success: $wasSuccessful');
      
      // Award XP to user profile if not in shuffle mode
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
  }

  // Old _processReplacementQueue method removed - using simplified _replaceMatchedCards instead

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
        title: Text(widget.startFlipped ? 'Leave Study Session?' : 'Leave Memory Game?'),
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
        content: Text(widget.startFlipped 
          ? 'Are you sure you want to return to the home screen? This will end your current study session.'
          : 'Are you sure you want to return to the home screen? This will end your current memory game.'),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Efficiency percentage circle
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: efficiency >= 80 ? Colors.green.withValues(alpha: 0.1) : 
                             efficiency >= 60 ? Colors.orange.withValues(alpha: 0.1) : 
                             Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$efficiency%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: efficiency >= 80 ? Colors.green : 
                                 efficiency >= 60 ? Colors.orange : 
                                 Colors.red,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Session stats
                  _buildStatCard('Cards Processed', '$_totalCardsProcessed', Icons.check_circle, Colors.green),
                  const SizedBox(height: 16),
                  _buildStatCard('Total Moves', '$_moves', Icons.touch_app, Colors.blue),
                  const SizedBox(height: 16),
                  _buildStatCard('Correct Matches', '$_matches', Icons.check_circle, Colors.green),
                  const SizedBox(height: 16),
                  _buildStatCard('Incorrect Matches', '${_moves - _matches}', Icons.cancel, Colors.red),
                  const SizedBox(height: 16),
                  _buildStatCard('Efficiency', '$efficiency%', Icons.analytics, Colors.orange),
                  const SizedBox(height: 16),
                  _buildStatCard('XP Earned', '', Icons.star, Colors.amber,
                    AnimatedXpCounter(xpGained: _gameSession.xpGained)),
                  const SizedBox(height: 48),
                  
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
  String content;
  final MemoryCardType type;
  final FlashCard originalCard;
  CardState state;
  bool isFlipped;

  MemoryCard({
    required this.id,
    required this.content,
    required this.type,
    required this.originalCard,
    this.state = CardState.normal,
    this.isFlipped = false,
  });
}

enum MemoryCardType {
  word,
  definition,
}

enum CardState {
  normal,
  selected,
  wrong,
  matched,   // Green background + fading out
  fadingIn,  // New cards appearing
}

// _ReplacementRequest class removed - using simplified replacement system 