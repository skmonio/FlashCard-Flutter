import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:async';
import '../components/main_header.dart';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../utils/game_end_screen.dart';
import '../services/xp_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_manager.dart';
import 'add_card_view.dart';

enum SwipeDirection {
  none,
  left,   // Don't Know
  right,  // Known
  up,     // Review
  down,   // Skip
}

class StackedCardStudyView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final bool startFlipped;

  const StackedCardStudyView({
    super.key,
    required this.cards,
    required this.title,
    this.startFlipped = false,
  });

  @override
  State<StackedCardStudyView> createState() => _StackedCardStudyViewState();
}

class _StackedCardStudyViewState extends State<StackedCardStudyView>
    with TickerProviderStateMixin {
  int topIndex = 0; // Track which card is currently on top
  List<FlashCard> _currentCards = [];
  
  // RPG tracking
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  Map<String, int> _initialHPPerWord = {}; // Track initial HP when word is first encountered
  List<FlashCard> _studiedWords = [];
  
  // Track card states for back navigation
  Map<int, bool> _cardStates = {}; // true = known, false = unknown, null = not answered
  int _consecutiveCorrect = 0;
  int _totalAnswers = 0;
  int _correctAnswers = 0;
  
  // Swipe direction tracking
  SwipeDirection _swipeDirection = SwipeDirection.none;
  double _swipeIntensity = 0;
  
  // Completion guard to prevent double end screens
  bool _hasShownResults = false;
  int _furthestIndex = 0; // Track furthest reached for Next button logic
  
  // Review and navigation tracking
  Set<String> _reviewCards = {}; // card IDs marked for review

  @override
  void initState() {
    super.initState();
    _currentCards = List.from(widget.cards);
    print('🔍 StackedCardStudyView: initState - topIndex: $topIndex, totalCards: ${_currentCards.length}');
    
    // Add listener to refresh cards when provider updates
    final provider = context.read<FlashcardProvider>();
    provider.addListener(_onProviderChanged);
  }

  @override
  void dispose() {
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
    
    // Get updated cards from provider
    List<FlashCard> updatedCards = [];
    for (final originalCard in widget.cards) {
      final updatedCard = provider.getCard(originalCard.id);
      if (updatedCard != null) {
        updatedCards.add(updatedCard);
      } else {
        // If card was deleted, keep the original
        updatedCards.add(originalCard);
      }
    }
    
    setState(() {
      _currentCards = updatedCards;
    });
  }

  void _toggleFlag(FlashCard card) async {
    setState(() {
      if (_reviewCards.contains(card.id)) {
        _reviewCards.remove(card.id);
      } else {
        _reviewCards.add(card.id);
      }
    });
    
    // Add or remove from review deck in provider
    try {
      final provider = context.read<FlashcardProvider>();
      if (_reviewCards.contains(card.id)) {
        await provider.addCardToReview(card);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${card.word}" to review deck'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.yellow.shade700,
          ),
        );
      } else {
        await provider.removeCardFromReview(card);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${card.word}" from review deck'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.grey.shade600,
          ),
        );
      }
    } catch (e) {
      print('🔍 StackedCardStudyView: Error toggling review card: $e');
    }
  }

  void _removeTopCard() {
    if (topIndex < _currentCards.length) {
      setState(() {
        topIndex++;
        if (topIndex > _furthestIndex) {
          _furthestIndex = topIndex;
        }
      });
    }
  }

  void _handleSwipeUpdate(Offset delta, double intensity) {
    setState(() {
      // If intensity is 0, reset swipe state (like Quick Study does)
      if (intensity == 0.0) {
        _swipeDirection = SwipeDirection.none;
        _swipeIntensity = 0;
        return;
      }
      
      // Determine swipe direction based on delta
      if (delta.dx.abs() > delta.dy.abs()) {
        // Horizontal swipe
        if (delta.dx > 0) {
          _swipeDirection = SwipeDirection.right; // Known
        } else {
          _swipeDirection = SwipeDirection.left; // Don't Know
        }
      } else {
        // Vertical swipe
        if (delta.dy < 0) {
          _swipeDirection = SwipeDirection.up; // Review
        } else {
          _swipeDirection = SwipeDirection.down; // Skip
        }
      }
      
      _swipeIntensity = intensity;
    });
  }

  void _markAnswer(bool isCorrect, SwipeDirection direction) {
    print('🔍 StackedCardStudyView: _markAnswer called, topIndex: $topIndex, isCorrect: $isCorrect, direction: $direction');
    if (topIndex >= _currentCards.length) return;
    
    final currentCard = _currentCards[topIndex];
    final provider = context.read<FlashcardProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();
    
    // Track the card state for back navigation
    _cardStates[topIndex] = isCorrect;
    print('🔍 StackedCardStudyView: Card state tracked for index $topIndex: $isCorrect');
    
    // Track the studied word and initial HP BEFORE processing (so we capture HP before it's reduced)
    if (!_studiedWords.contains(currentCard)) {
      _studiedWords.add(currentCard);
      _initialHPPerWord[currentCard.id] = currentCard.currentHP;
    }
    
    // Handle different swipe directions like Quick Study
    switch (direction) {
      case SwipeDirection.left: // Don't Know
        currentCard.markIncorrect(GameDifficulty.medium);
        _consecutiveCorrect = 0;
        _xpGainedPerWord[currentCard.id] = 0;
        break;
      case SwipeDirection.right: // Known
        currentCard.markCorrect(GameDifficulty.medium);
        _correctAnswers++;
        _consecutiveCorrect++;
        
        // Calculate XP gained (simplified for stacked cards)
        final xpGained = 10 + (_consecutiveCorrect * 2);
        _xpGainedPerWord[currentCard.id] = xpGained;
        
        // Update user profile
        userProfileProvider.addXp(xpGained);
        break;
      case SwipeDirection.up: // Review
        // Add card to review deck (similar to Quick Study)
        // For now, just mark as incorrect to add to review
        currentCard.markIncorrect(GameDifficulty.medium);
        _consecutiveCorrect = 0;
        _xpGainedPerWord[currentCard.id] = 0;
        break;
      case SwipeDirection.down: // Skip
        // Don't update learning progress for skipped cards
        _consecutiveCorrect = 0;
        _xpGainedPerWord[currentCard.id] = 0;
        break;
      default:
        // Fallback to original logic
        if (isCorrect) {
          currentCard.markCorrect(GameDifficulty.medium);
          _correctAnswers++;
          _consecutiveCorrect++;
          
          final xpGained = 10 + (_consecutiveCorrect * 2);
          _xpGainedPerWord[currentCard.id] = xpGained;
          userProfileProvider.addXp(xpGained);
        } else {
          currentCard.markIncorrect(GameDifficulty.medium);
          _consecutiveCorrect = 0;
          _xpGainedPerWord[currentCard.id] = 0;
        }
    }
    
    // Update mastery tracking
    _wordMastery[currentCard.id] = currentCard.learningMastery;
    
    // Save to provider
    provider.updateCard(currentCard);
    _totalAnswers++;
    
    // Reset swipe state
    setState(() {
      _swipeDirection = SwipeDirection.none;
      _swipeIntensity = 0;
    });
    
    // Remove the top card
    _removeTopCard();
    
    // Check if study is complete and show results immediately
    if (topIndex >= _currentCards.length && !_hasShownResults) {
      print('🔍 StackedCardStudyView: Study complete, showing results');
      _showResults();
    }
  }

  void _goToPreviousCard() {
    if (topIndex > 0) {
      setState(() {
        topIndex--;
      });
    }
  }

  void _goToNextCard() {
    if (topIndex < _furthestIndex) {
      setState(() {
        topIndex++;
      });
    }
  }

  void _editCurrentCard() {
    if (topIndex >= _currentCards.length) return;
    
    final currentCard = _currentCards[topIndex];
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCardView(
          cardToEdit: currentCard,
        ),
      ),
    );
  }

  void _showResults() {
    // Prevent multiple end screens from being shown
    if (_hasShownResults) {
      print('🔍 StackedCardStudyView: Results already shown, skipping duplicate');
      return;
    }
    
    _hasShownResults = true;
    print('🔍 StackedCardStudyView: Showing results screen');
    
    // For flipped mode, include all cards in the end screen, not just studied ones
    List<FlashCard> sessionStudiedWords;
    Map<String, int> sessionXpGainedPerWord;
    Map<String, LearningMastery> sessionWordMastery;
    
    if (widget.startFlipped) {
      // Include all cards for flipped mode
      sessionStudiedWords = List<FlashCard>.from(widget.cards);
      sessionXpGainedPerWord = Map<String, int>.from(_xpGainedPerWord);
      sessionWordMastery = Map<String, LearningMastery>.from(_wordMastery);
      
      // Ensure all cards have entries in the maps (0 XP and current mastery for unanswered cards)
      for (final card in widget.cards) {
        if (!sessionXpGainedPerWord.containsKey(card.id)) {
          sessionXpGainedPerWord[card.id] = 0; // 0 XP for unanswered cards
        }
        if (!sessionWordMastery.containsKey(card.id)) {
          sessionWordMastery[card.id] = card.learningMastery; // Current mastery for unanswered cards
        }
      }
    } else {
      // Normal mode - only show studied cards
      sessionStudiedWords = List<FlashCard>.from(_studiedWords);
      sessionXpGainedPerWord = Map<String, int>.from(_xpGainedPerWord);
      sessionWordMastery = Map<String, LearningMastery>.from(_wordMastery);
    }
    
    GameEndScreen.show(
      context,
      GameEndResult(
        title: 'Word Progress',
        studiedWords: sessionStudiedWords,
        xpGainedPerWord: sessionXpGainedPerWord,
        wordMastery: sessionWordMastery,
        initialHPPerWord: _initialHPPerWord,
        correctAnswers: _correctAnswers,
        totalQuestions: _totalAnswers,
        onStudyAgain: (available) {
          Navigator.of(context).pop();
          setState(() {
            _currentCards = List.from(available);
            topIndex = 0;
            _studiedWords.clear();
            _xpGainedPerWord.clear();
            _wordMastery.clear();
            _consecutiveCorrect = 0;
            _totalAnswers = 0;
            _correctAnswers = 0;
            _hasShownResults = false;
            _cardStates.clear();
          });
        },
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('No cards available for study'),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final visibleCards = min(_currentCards.length - topIndex, 3);
    final progress = _totalAnswers / _currentCards.length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          MainHeader(
            title: widget.title,
            leftAction: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
            rightAction: IconButton(
              icon: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
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
                    Text('${min(topIndex + 1, _currentCards.length)}/${_currentCards.length}'),
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
          ),
          
          // Stacked cards area with background color and directional labels
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _getSwipeBackgroundColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Directional label behind the card (only show when enough distance reached)
                      if (_swipeDirection != SwipeDirection.none && _swipeIntensity >= 1.0)
                        _buildDirectionalLabel(),
                      
                      // Stacked cards
                      for (int i = visibleCards - 1; i >= 0; i--)
                        TaalTrekStackCard(
                          key: ValueKey(_currentCards[topIndex + i].id),
                          card: _currentCards[topIndex + i],
                          isTop: i == 0,
                          offset: Offset(20.0 * i, -20.0 * i),
                          scale: 1 - 0.05 * i,
                          width: size.width * 0.9,
                          height: size.height * 0.5,
                          onDismissed: i == 0 ? _removeTopCard : null,
                          onAnswer: _markAnswer,
                          startFlipped: widget.startFlipped,
                          onSwipeUpdate: _handleSwipeUpdate,
                          onToggleFlag: () => _toggleFlag(_currentCards[topIndex + i]),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  // Background color based on swipe direction
  Color _getSwipeBackgroundColor() {
    // Only show background when swiped enough to register
    if (_swipeDirection == SwipeDirection.none || _swipeIntensity < 1.0) {
      return Colors.transparent;
    }
    
    final baseColor = _getSwipeColor();
    final intensity = (_swipeIntensity * 0.35).clamp(0.0, 0.4);
    return baseColor.withValues(alpha: intensity);
  }

  Color _getSwipeColor() {
    switch (_swipeDirection) {
      case SwipeDirection.left: // Don't Know
        return Colors.red;
      case SwipeDirection.right: // Known
        return Colors.green;
      case SwipeDirection.up: // Review
        return Colors.yellow;
      case SwipeDirection.down: // Skip
        return Colors.blue;
      default:
        return Colors.transparent;
    }
  }

  Widget _buildDirectionalLabel() {
    return Positioned.fill(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: _buildDirectionalLabelForDirection(_swipeDirection),
        ),
      ),
    );
  }

  Widget _buildDirectionalLabelForDirection(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.left:
        return Transform.rotate(
          angle: -0.3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Don't\nKnow",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
        
      case SwipeDirection.right:
        return Transform.rotate(
          angle: 0.3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Known",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
        
      case SwipeDirection.up:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.yellow.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "Review",
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        );
        
      case SwipeDirection.down:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "Skip",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        );
        
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavigationButtons() {
    final canGoBack = topIndex > 0;
    final canGoNext = topIndex < _furthestIndex;
    final isLastCard = topIndex == _currentCards.length - 1;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Back button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canGoBack ? _goToPreviousCard : null,
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                label: const Text('Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canGoBack ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                  foregroundColor: canGoBack 
                      ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87) 
                      : Colors.grey,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: canGoBack ? Colors.grey[300]! : Colors.transparent),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Edit button in center
            IconButton(
              onPressed: _editCurrentCard,
              icon: const Icon(Icons.edit),
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Next/Finish button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canGoNext ? _goToNextCard : null,
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                label: Text(isLastCard ? 'Finish' : 'Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canGoNext ? Theme.of(context).colorScheme.primary : Colors.grey,
                  foregroundColor: Colors.white,
                  elevation: canGoNext ? 2 : 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaalTrekStackCard extends StatefulWidget {
  final FlashCard card;
  final bool isTop;
  final Offset offset;
  final double scale;
  final double width, height;
  final VoidCallback? onDismissed;
  final Function(bool, SwipeDirection) onAnswer;
  final bool startFlipped;
  final Function(Offset, double)? onSwipeUpdate;
  final VoidCallback? onToggleFlag;

  const TaalTrekStackCard({
    super.key,
    required this.card,
    required this.isTop,
    required this.offset,
    required this.scale,
    required this.width,
    required this.height,
    this.onDismissed,
    required this.onAnswer,
    this.startFlipped = false,
    this.onSwipeUpdate,
    this.onToggleFlag,
  });

  @override
  State<TaalTrekStackCard> createState() => _TaalTrekStackCardState();
}

class _TaalTrekStackCardState extends State<TaalTrekStackCard>
    with TickerProviderStateMixin {
  // Position tracking for smooth movement
  Offset position = Offset.zero;
  bool showBack = false;
  bool? userAnswer; // null = not answered, true = know, false = don't know
  SwipeDirection swipeDirection = SwipeDirection.none;

  // Animation controllers
  late AnimationController _flipController;
  late AnimationController _exitController;
  late Animation<double> _flipAnimation;
  late Animation<Offset> _exitAnimation;

  @override
  void initState() {
    super.initState();
    showBack = widget.startFlipped;
    
    // Initialize flip animation controller
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize exit animation controller
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _exitAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeOutCubic,
    ));
    
    // Set initial position based on startFlipped
    if (widget.startFlipped) {
      _flipController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  // Set up exit animation based on swipe direction
  void _setupExitAnimation() {
    Offset exitOffset;
    switch (swipeDirection) {
      case SwipeDirection.left:
        exitOffset = const Offset(-2.0, 0.0); // Exit left
        break;
      case SwipeDirection.right:
        exitOffset = const Offset(2.0, 0.0); // Exit right
        break;
      case SwipeDirection.up:
        exitOffset = const Offset(0.0, -2.0); // Exit up
        break;
      case SwipeDirection.down:
        exitOffset = const Offset(0.0, 2.0); // Exit down
        break;
      default:
        exitOffset = const Offset(2.0, 0.0); // Default to right
    }
    
    _exitAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: exitOffset,
    ).animate(CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeOutCubic,
    ));
  }


  @override
  Widget build(BuildContext context) {
    Widget card = AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        return TaalTrekFlashCard(
          card: widget.card,
          width: widget.width,
          height: widget.height,
          flipAnimation: _flipAnimation,
          startFlipped: widget.startFlipped,
          userAnswer: userAnswer,
          onToggleFlag: widget.onToggleFlag,
        );
      },
    );

    if (!widget.isTop) {
      return TweenAnimationBuilder<Offset>(
        tween: Tween(begin: Offset.zero, end: widget.offset),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (_, value, child) {
          return Transform.translate(
            offset: value,
            child: Transform.scale(
              scale: widget.scale,
              child: child,
            ),
          );
        },
        child: card,
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    double tiltAngle = (position.dx / screenWidth) * 0.5;

    // Gesture handling with smooth movement
    return GestureDetector(
      onPanStart: (details) {
        // Continuous vibration removed as requested for a better experience
      },
      onPanUpdate: (details) {
        final previousReached = position.distance > 150;
        
        setState(() {
          position += details.delta;
          
          // Calculate swipe intensity - mapping 0 to 150 distance to 0 to 1.0 intensity
          // This way 1.0 means background color and haptic should trigger
          final intensity = (position.distance / 150).clamp(0.0, 1.2);
          
          // Call the swipe update callback
          widget.onSwipeUpdate?.call(details.delta, intensity);
          
          // Determine reached state for single haptic click
          final currentReached = position.distance > 150;
          if (currentReached && !previousReached) {
            HapticService().selectionFeedback(); // Precise haptic click when reached enough distance
          }
          
          // Determine swipe direction - strict cardinal directions only (like Quick Study)
          final horizontalDistance = position.dx.abs();
          final verticalDistance = position.dy.abs();
          
          // Only allow pure horizontal or vertical swipes (no diagonal)
          if (horizontalDistance > verticalDistance * 2.0) {
            // Horizontal swipe - left or right
            if (position.dx > 0) {
              userAnswer = true; // Swiping right = know
              swipeDirection = SwipeDirection.right;
            } else {
              userAnswer = false; // Swiping left = don't know
              swipeDirection = SwipeDirection.left;
            }
          } else if (verticalDistance > horizontalDistance * 2.0) {
            // Vertical swipe - up or down
            if (position.dy < 0) {
              userAnswer = true; // Swiping up = review (use true as placeholder)
              swipeDirection = SwipeDirection.up;
            } else {
              userAnswer = false; // Swiping down = skip (use false as placeholder)
              swipeDirection = SwipeDirection.down;
            }
          } else {
            // Diagonal swipe - reset to none and don't allow movement
            position = Offset.zero;
            userAnswer = null;
            swipeDirection = SwipeDirection.none;
          }
        });
      },
      onPanEnd: (details) {
        // Stop any remaining vibration if needed (optional)
        HapticService().stopContinuousVibration();
        
        final velocity = details.velocity.pixelsPerSecond;
        final speed = velocity.distance;
        
        print('🔍 Stacked Study: Pan ended - direction: $swipeDirection, distance: ${position.distance}, speed: $speed');
        
        // Increased threshold to 150 for better control as requested
        if (position.distance > 150 || (position.distance > 80 && speed > 500)) {
          print('🎯 Stacked Study: Swipe completed - direction: $swipeDirection, distance: ${position.distance}, speed: $speed');
          // Provide haptic feedback for successful swipe
          HapticService().mediumImpact();
          // Play swipe sound for successful swipe
          SoundManager().playSwipeSound();
          
          // Mark answer immediately
          widget.onAnswer(userAnswer ?? false, swipeDirection);
          
          // Set up and start exit animation
          _setupExitAnimation();
          _exitController.forward();
          
          // Call onDismissed after animation completes
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              widget.onDismissed?.call();
            }
          });
        } else {
          // Snap back
          setState(() {
            position = Offset.zero;
            userAnswer = null;
            swipeDirection = SwipeDirection.none;
          });
          
          // Reset swipe state in parent
          widget.onSwipeUpdate?.call(Offset.zero, 0.0);
        }
      },
      child: SlideTransition(
        position: _exitAnimation,
        child: Transform.translate(
          offset: position,
          child: Transform.rotate(angle: tiltAngle, child: card),
        ),
      ),
    );
  }
}

class TaalTrekFlashCard extends StatelessWidget {
  final FlashCard card;
  final double width, height;
  final Animation<double> flipAnimation;
  final bool startFlipped;
  final bool? userAnswer; // null = not answered, true = know, false = don't know
  final VoidCallback? onToggleFlag;

  const TaalTrekFlashCard({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    required this.flipAnimation,
    required this.startFlipped,
    this.userAnswer,
    this.onToggleFlag,
  });

  @override
  Widget build(BuildContext context) {
    // Simple logic: when flipAnimation.value >= 0.5, show the back (definition)
    // When flipAnimation.value < 0.5, show the front (word)
    final isFlipped = flipAnimation.value >= 0.5;
    
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(flipAnimation.value * pi),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateY(isFlipped ? pi : 0),
        child: isFlipped ? _buildCardBack(context) : _buildCardFront(context),
      ),
    );
  }

  Widget _buildCardFront(BuildContext context) {
    final borderColor = _getCardBorderColor(card);
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive sizing based on screen dimensions
    final responsivePadding = screenHeight * 0.04; // 4% of screen height
    final responsiveFontSize = _getAdaptiveFontSize(context);
    final responsiveBorderRadius = screenHeight * 0.03; // 3% of screen height
    final responsiveBorderWidth = screenHeight * 0.006; // 0.6% of screen height
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: borderColor,
          width: responsiveBorderWidth,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(responsivePadding),
        child: Stack(
          children: [
            Positioned(
              top: 8, left: 8,
              child: GestureDetector(
                onTap: onToggleFlag,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (card.isReview ?? false) ? Colors.yellow : Colors.yellow.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.orange,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.flag,
                    size: 16,
                    color: (card.isReview ?? false) ? Colors.orange : Colors.orange.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                card.word,
                style: TextStyle(fontSize: responsiveFontSize, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getAdaptiveFontSize(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // For very small screens (height < 600), use smaller font
    if (screenHeight < 600) {
      return 28.0; // Smaller font for small screens
    }
    // For medium screens (height 600-800), use medium font
    else if (screenHeight < 800) {
      return 36.0; // Medium font for medium screens
    }
    // For large screens (height 800-1000), use larger font
    else if (screenHeight < 1000) {
      return 42.0; // Larger font for large screens
    }
    // For very large screens (tablets, iPads), use even larger font
    else {
      return 48.0; // Extra large font for tablets
    }
  }

  Widget _buildCardBack(BuildContext context) {
    final borderColor = _getCardBorderColor(card);
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive sizing based on screen dimensions
    final responsivePadding = screenHeight * 0.04; // 4% of screen height
    final responsiveFontSize = _getAdaptiveFontSize(context) * 0.85; // Slightly smaller for definition
    final responsiveBorderRadius = screenHeight * 0.03; // 3% of screen height
    final responsiveBorderWidth = screenHeight * 0.006; // 0.6% of screen height
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: borderColor,
          width: responsiveBorderWidth,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(responsivePadding),
        child: Stack(
          children: [
            Positioned(
              top: 8, left: 8,
              child: GestureDetector(
                onTap: onToggleFlag,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (card.isReview ?? false) ? Colors.yellow : Colors.yellow.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.orange,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.flag,
                    size: 16,
                    color: (card.isReview ?? false) ? Colors.orange : Colors.orange.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                card.definition,
                style: TextStyle(fontSize: responsiveFontSize, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Copy the exact border color logic from Quick Study (AdvancedStudyView)
  Color _getCardBorderColor(FlashCard card) {
    final vibrantColors = [
      const Color(0xFFFF6B35), // Coral/Orange-Red
      const Color(0xFFFF9900), // Bright Orange
      const Color(0xFFFFCC00), // Golden Yellow
      const Color(0xFF33CC99), // Teal/Turquoise
      const Color(0xFF00B3CC), // Cyan Blue
      const Color(0xFF9966FF), // Purple
      const Color(0xFFFF4D94), // Pink
      const Color(0xFF66E64D), // Lime Green
    ];
    
    if (card.word.isEmpty || card.definition.isEmpty) {
      return vibrantColors[0];
    }
    
    final hash = (card.word.hashCode + card.definition.hashCode).abs();
    final index = hash % vibrantColors.length;
    return vibrantColors[index];
  }
}