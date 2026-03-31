import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import '../components/main_header.dart';
import '../models/flash_card.dart';
import '../models/game_session.dart';
import '../models/learning_mastery.dart';
import '../models/study_config.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/dutch_word_exercise.dart';
import '../services/xp_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_manager.dart';

import '../utils/game_end_screen.dart';
import 'add_card_view.dart';

enum SwipeDirection {
  none,
  left,   // Don't Know
  right,  // Known
  up,     // Review
  down,   // Skip
}

class AdvancedStudyView extends StatefulWidget {
  final List<FlashCard> cards;
  final bool startFlipped;
  final String title;
  final StudyConfig? studyConfig;

  const AdvancedStudyView({
    super.key,
    required this.cards,
    this.startFlipped = false,
    required this.title,
    this.studyConfig,
  });

  @override
  State<AdvancedStudyView> createState() => _AdvancedStudyViewState();
}

class _AdvancedStudyViewState extends State<AdvancedStudyView> 
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  Set<String> _knownCards = {};
  Set<String> _unknownCards = {};
  Set<String> _skippedCards = {};
  bool _isShowingFront = true;
  Offset _dragOffset = Offset.zero;
  bool _nextCardActive = false;
  bool _showingResults = false;
  // Completion guard to prevent double end screens
  bool _hasShownResults = false;
  SwipeDirection _swipeDirection = SwipeDirection.none;
  double _swipeIntensity = 0;
  final GameSession _gameSession = GameSession();
  
  // Stacked card mode
  bool _useStackedMode = true; // Default to stacked mode
  int _topIndex = 0; // Track which card is currently on top in stacked mode
  
  // Animation controllers
  late AnimationController _flipController;
  late AnimationController _dealController;
  late AnimationController _exitController;
  late Animation<double> _flipAnimation;
  late Animation<Offset> _dealAnimation;
  late Animation<Offset> _exitAnimation;
  
  // Session tracking
  DateTime _sessionStartTime = DateTime.now();
  int _sessionXP = 0;
  int _combo = 0;
  int _maxCombo = 0;
  
  // Card history for back functionality
  List<int> _cardHistory = [];
  Map<int, bool> _knownHistory = {};
  Map<int, bool> _unknownHistory = {};
  Map<int, bool> _skippedHistory = {};
  
  // Edit functionality
  FlashCard? _selectedCardForEdit;
  
  // Maintain our own copy of cards that can be updated
  late List<FlashCard> _sessionCards;
  late List<FlashCard> _currentCards;
  
  // RPG tracking
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  Map<String, int> _initialHPPerWord = {}; // Track initial HP when word is first encountered
  List<FlashCard> _studiedWords = [];

  @override
  void initState() {
    super.initState();
    _isShowingFront = !widget.startFlipped;
    
    // Set mode based on startFlipped parameter
    // Both flipped and normal modes should use stacked mode
    // The difference is just which side of the card is shown initially
    _useStackedMode = true;
    
    // Initialize our copy of cards
    _sessionCards = List<FlashCard>.from(widget.cards);
    _currentCards = List<FlashCard>.from(_sessionCards);
    
    // Track initial HP for all cards at the start of the session
    for (final card in _currentCards) {
      _initialHPPerWord[card.id] = card.currentHP;
    }
    
    // Add listener to refresh cards when provider updates
    final provider = context.read<FlashcardProvider>();
    provider.addListener(_onProviderChanged);
    
    // Initialize flip animation - slower duration
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
    )    );
    
    // Set initial position based on startFlipped
    // When startFlipped is true, we want to show the definition (back) initially
    // When startFlipped is false, we want to show the word (front) initially
    if (widget.startFlipped) {
      _flipController.value = 1.0; // Show back (definition) initially
    } else {
      _flipController.value = 0.0; // Show front (word) initially
    }
    
    // Initialize deal animation
    _dealController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _dealAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right side
      end: Offset.zero, // End at center
    ).animate(CurvedAnimation(
      parent: _dealController,
      curve: Curves.easeOutCubic,
    ));
    
    // Initialize exit animation
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _exitAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero, // Will be set dynamically based on swipe direction
    ).animate(CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start initial deal animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dealController.forward();
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _dealController.dispose();
    _exitController.dispose();
    
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
    for (final originalCard in _currentCards) {
      final updatedCard = provider.getCard(originalCard.id);
      if (updatedCard != null) {
        updatedCards.add(updatedCard);
      } else {
        // If card was deleted, keep the original
        updatedCards.add(originalCard);
      }
    }
    
    // Update our current cards list
    setState(() {
      _currentCards = updatedCards;
      _sessionCards = List<FlashCard>.from(updatedCards);
    });
    
    print('🔍 AdvancedStudyView: Refreshed cards from provider');
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Your Cards')),
        body: const Center(
          child: Text('No cards available for study'),
        ),
      );
    }

    if (_showingResults) {
      // Go directly to word progress instead of showing completion screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hasShownResults) {
          _hasShownResults = true;
          _showWordProgress();
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          MainHeader(
            title: 'Study',
            leftAction: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () => _showCloseConfirmation(),
            ),
            rightAction: IconButton(
              icon: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () => _showHomeConfirmation(),
            ),
          ),
          // Progress bar
          _buildProgressBar(),
          
          // Main card area with background color based on swipe direction
          Expanded(
            child: _buildCardAreaWithLabels(),
          ),
          
          // Footer with buttons
          _buildPremiumFooter(),
        ],
      ),
    );
  }

  Widget _buildPremiumFooter() {
    final bool hasHistory = _topIndex > 0;
    
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Undo/Back button
            ElevatedButton.icon(
              onPressed: () {
                if (hasHistory) {
                  _goToPreviousCard();
                } else {
                  _showCloseConfirmation();
                }
              },
              icon: Icon(hasHistory ? Icons.undo : Icons.arrow_back_ios, size: 18),
              label: Text(hasHistory ? 'Undo' : 'Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasHistory ? Colors.orange.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                foregroundColor: hasHistory ? Colors.orange[800] : Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: (hasHistory ? Colors.orange[300] : Colors.grey[300])!,
                    width: 1,
                  ),
                ),
              ),
            ),
            
            // Edit button
            ElevatedButton.icon(
              onPressed: () => _editCurrentCard(),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).colorScheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final currentCardIndex = _topIndex;
    final progress = _currentCards.isEmpty ? 0.0 : currentCardIndex / _currentCards.length;
    
    // Calculate current accuracy - start at 100%
    final totalSwiped = _knownCards.length + _unknownCards.length;
    final accuracy = totalSwiped > 0 ? (_knownCards.length / totalSwiped * 100).toInt() : 100;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Card ${currentCardIndex + 1}/${_currentCards.length}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'Acc: $accuracy%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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

  Widget _buildCardArea() {
    if (_useStackedMode) {
      return _buildStackedCardArea();
    } else {
      return _buildSingleCardArea();
    }
  }
  
  Widget _buildSingleCardArea() {
    // Ensure we have cards and current index is within bounds
    if (_currentCards.isEmpty) {
      return const Center(
        child: Text('No cards available'),
      );
    }
    
    if (_currentIndex >= _currentCards.length) {
      return const Center(
        child: Text('No more cards available'),
      );
    }
    
    final currentCard = _currentCards[_currentIndex];
    
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SlideTransition(
            position: _dealAnimation,
            child: SlideTransition(
              position: _exitAnimation,
              child: Transform.translate(
                offset: _dragOffset,
                child: Transform.rotate(
                  angle: _swipeIntensity * 0.1,
                  child: _buildCard(currentCard),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStackedCardArea() {
    // Ensure we have cards and top index is within bounds
    if (_currentCards.isEmpty) {
      return const Center(
        child: Text('No cards available'),
      );
    }
    
    if (_topIndex >= _currentCards.length) {
      return const Center(
        child: Text('No more cards available'),
      );
    }
    
    final size = MediaQuery.of(context).size;
    final visibleCards = math.min(3, _currentCards.length - _topIndex);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: size.width * 0.85,
          height: size.height * 0.4,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Stacked cards
              for (int i = visibleCards - 1; i >= 0; i--)
                TaalTrekStackCard(
                  key: ValueKey(_currentCards[_topIndex + i].id),
                  card: _currentCards[_topIndex + i],
                  isTop: i == 0,
                  offset: Offset(20.0 * i, -20.0 * i),
                  scale: 1 - 0.05 * i,
                  width: size.width * 0.85,
                  height: size.height * 0.4,
                  onDismissed: i == 0 ? _removeTopCard : null,
                  onAnswer: _markAnswer,
                  startFlipped: widget.startFlipped,
                  onSwipeUpdate: _handleSwipeUpdate,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardAreaWithLabels() {
    return Container(
      decoration: BoxDecoration(
        color: _getSwipeBackgroundColor(),
      ),
      child: Column(
        children: [
          // Card area
          Expanded(
            child: _buildCardArea(),
          ),
          
          // Directional label below the card
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: (_swipeDirection != SwipeDirection.none && _swipeIntensity >= 1.0)
                  ? _buildDirectionalLabelForDirection(_swipeDirection)
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDirectionalLabel() {
    return _buildDirectionalLabelForDirection(_swipeDirection);
  }

  Widget _buildDirectionalLabelForDirection(SwipeDirection direction) {
    final double opacity = (_swipeIntensity * 2).clamp(0.0, 1.0);
    
    switch (direction) {
      case SwipeDirection.left:
        return Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: -0.2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, color: Colors.red, size: 32),
                  SizedBox(width: 8),
                  Text(
                    "FORGOT",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        
      case SwipeDirection.right:
        return Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: 0.2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, color: Colors.green, size: 32),
                  SizedBox(width: 8),
                  Text(
                    "KNOW",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        
      case SwipeDirection.up:
      case SwipeDirection.down:
      default:
        return const SizedBox.shrink();
    }
  }



  Widget _buildNavigationButtons() {
    print('🔍 AdvancedStudyView: Building navigation buttons, topIndex: $_topIndex, canGoBack: ${_topIndex > 0}');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button - always enabled
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                if (_topIndex > 0) {
                  print('🔍 AdvancedStudyView: Back button pressed (previous card), topIndex: $_topIndex');
                  _goToPreviousCard();
                } else {
                  print('🔍 AdvancedStudyView: Back button pressed (first card), going to previous screen');
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              label: const Text('Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Always blue now
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Edit button in center
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _editCurrentCard(),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(FlashCard card) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        // Use _isShowingFront to determine the initial state, then apply flip animation
        final isFlipped = _isShowingFront ? (_flipAnimation.value >= 0.5) : (_flipAnimation.value < 0.5);
        
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_flipAnimation.value * math.pi),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateY(isFlipped ? math.pi : 0),
            child: isFlipped ? _buildCardBack(card) : _buildCardFront(card),
          ),
        );
      },
    );
  }

  Widget _buildCardFront(FlashCard card) {
    final borderColor = _getCardBorderColor(card);
    
    return Container(
      width: double.infinity,
      height: 450,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
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
          width: 5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            card.word,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack(FlashCard card) {
    final borderColor = _getCardBorderColor(card);
    
    return Container(
      width: double.infinity,
      height: 450,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
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
          width: 5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            card.definition,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    if (_nextCardActive) return;
    
    // Start continuous long vibration when user starts touching the card
    HapticService().startContinuousVibration();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_nextCardActive) return;
    
    final previousDirection = _swipeDirection;
    
    setState(() {
      _dragOffset += details.delta;
      _swipeIntensity = (_dragOffset.distance / 150).clamp(0.0, 1.0);
      
      // Determine swipe direction - easier diagonal support, horizontal priority
      if (_dragOffset.dx.abs() > 10) {
        _swipeDirection = _dragOffset.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
      } else {
        _swipeDirection = SwipeDirection.none;
      }
    });
    
    // Continuous haptic feedback is handled in _handlePanStart
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_nextCardActive) return;
    
    // Stop continuous vibration when pan ends
    HapticService().stopContinuousVibration();
    
    final velocity = details.velocity.pixelsPerSecond;
    final distance = _dragOffset.distance;
    
    print('🔍 Advanced Study: Pan ended - direction: $_swipeDirection, distance: $distance, velocity: ${velocity.distance}');
    
    // Only process swipe if we have a valid direction and sufficient distance/velocity
    if (_swipeDirection != SwipeDirection.none && (distance > 50 || velocity.distance > 200)) {
      print('🎯 Advanced Study: Swipe completed - direction: $_swipeDirection, distance: $distance, velocity: ${velocity.distance}');
      // Provide haptic feedback for successful swipe
      HapticService().mediumImpact();
      // Play swipe sound for successful swipe
      SoundManager().playSwipeSound();
      _handleSwipe(_swipeDirection);
    } else {
      // Reset card position if swipe wasn't valid
      setState(() {
        _dragOffset = Offset.zero;
        _swipeDirection = SwipeDirection.none;
        _swipeIntensity = 0;
      });
    }
  }


  void _goToPreviousCard() {
    print('🔍 AdvancedStudyView: _goToPreviousCard called, topIndex: $_topIndex');
    if (_topIndex > 0) {
      // Get the previous card index
      final previousIndex = _topIndex - 1;
      print('🔍 AdvancedStudyView: Going back to index: $previousIndex');
      
      // Remove the previously swiped card from tracking sets
      final swipedCard = _currentCards[previousIndex];
      _knownCards.remove(swipedCard.id);
      _unknownCards.remove(swipedCard.id);
      _skippedCards.remove(swipedCard.id);
      
      // Remove from history tracking
      _knownHistory.remove(previousIndex);
      _unknownHistory.remove(previousIndex);
      _skippedHistory.remove(previousIndex);
      
      setState(() {
        _topIndex = previousIndex;
        _dragOffset = Offset.zero;
        _swipeDirection = SwipeDirection.none;
        _swipeIntensity = 0;
        _isShowingFront = !widget.startFlipped;
        _flipController.reset();
        if (widget.startFlipped) {
          _flipController.value = 1.0; // Show back (definition) initially
        } else {
          _flipController.value = 0.0; // Show front (word) initially
        }
        // Reset exit animation for previous card
        _exitController.reset();
        // Start deal animation for previous card
        _dealController.reset();
        _dealController.forward();
      });
      
      // Restore the previous card's state based on its history
      final previousCard = _currentCards[previousIndex];
      if (_knownHistory.containsKey(previousIndex)) {
        _knownCards.add(previousCard.id);
        print('🔍 AdvancedStudyView: Restored previous card as known');
      } else if (_unknownHistory.containsKey(previousIndex)) {
        _unknownCards.add(previousCard.id);
        print('🔍 AdvancedStudyView: Restored previous card as unknown');
      } else if (_skippedHistory.containsKey(previousIndex)) {
        _skippedCards.add(previousCard.id);
        print('🔍 AdvancedStudyView: Restored previous card as skipped');
      } else {
        print('🔍 AdvancedStudyView: Previous card had no history, treating as new');
      }
    } else {
      print('🔍 AdvancedStudyView: Cannot go back, already at first card');
    }
  }

  void _editCurrentCard() {
    _selectedCardForEdit = _currentCards[_topIndex];
    final card = _selectedCardForEdit!;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCardView(
          cardToEdit: card,
        ),
      ),
    );
  }

  // Generate consistent color based on card content
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



  Color _getSwipeBackgroundColor() {
    // Only show background when swiped enough to register
    if (_swipeDirection == SwipeDirection.none || _swipeIntensity < 1.0) {
      return Colors.transparent;
    }
    
    final baseColor = _getSwipeColor();
    final intensity = (_swipeIntensity * 0.35).clamp(0.0, 0.4);
    return baseColor.withValues(alpha: intensity);
  }



  void _setupExitAnimation() {
    Offset exitOffset;
    switch (_swipeDirection) {
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

  void _handleSwipe(SwipeDirection direction) {
    if (_nextCardActive) return;
    
    final currentCard = _currentCards[_currentIndex];
    
    // Remove any previous state for this card
    _knownCards.remove(currentCard.id);
    _unknownCards.remove(currentCard.id);
    _skippedCards.remove(currentCard.id);
    _knownHistory.remove(_currentIndex);
    _unknownHistory.remove(_currentIndex);
    _skippedHistory.remove(_currentIndex);
    
    // Save to history
    _cardHistory.add(_currentIndex);
    
    // Track initial HP BEFORE processing
    if (!_studiedWords.any((word) => word.id == currentCard.id)) {
      _studiedWords.add(currentCard);
      _initialHPPerWord[currentCard.id] = currentCard.currentHP;
    }
    
    switch (direction) {
      case SwipeDirection.left: // Don't Know
        _unknownCards.add(currentCard.id);
        _unknownHistory[_currentIndex] = true;
        _combo = 0;
        // Track XP for incorrect answer (0 XP)
        XpService.recordAnswer(_gameSession, false);
        // Explicitly set 0 XP for unknown cards
        _xpGainedPerWord[currentCard.id] = 0;
        
        // Mark card as incorrect (decrements HP and increments attempts)
        currentCard.markIncorrect(GameDifficulty.medium);
        
        // Update learning progress - marked as incorrect
        _updateCardLearningProgress(currentCard, false);
        break;
      case SwipeDirection.right: // Known
        _knownCards.add(currentCard.id);
        _knownHistory[_currentIndex] = true;
        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
        
        // Multi-level tracking
        XpService.recordAnswer(_gameSession, true);
        
        // Mark card as correct (decrements HP, awards diminishing XP, and increments consecutiveCorrect)
        currentCard.markCorrect(GameDifficulty.medium);
        
        // Update learning progress - marked as correct
        _updateCardLearningProgress(currentCard, true);
        break;
      case SwipeDirection.up: // Review
        // Add card to review deck
        _addCardToReview(currentCard);
        // No XP for review actions - these are cards that need more study
        // But still track them for end screen display
        if (!_studiedWords.any((word) => word.id == currentCard.id)) {
          _studiedWords.add(currentCard);
          _initialHPPerWord[currentCard.id] = currentCard.currentHP;
        }
        break;
      case SwipeDirection.down: // Skip
        _skippedCards.add(currentCard.id);
        _skippedHistory[_currentIndex] = true;
        _combo = 0;
        // Don't update learning progress for skipped cards
        // But still track them for end screen display
        if (!_studiedWords.any((word) => word.id == currentCard.id)) {
          _studiedWords.add(currentCard);
        }
        break;
      default:
        return;
    }
    
    _nextCard();
  }

  Future<void> _updateCardLearningProgress(FlashCard card, bool wasCorrect) async {
    try {
      // Award XP to the word for RPG system (only for correct answers)
      if (wasCorrect) {
        _awardXPToWord(card);
      }
      
      // Track all studied words (known, unknown, and skipped) for end screen display
      if (!_studiedWords.any((word) => word.id == card.id)) {
        _studiedWords.add(card);
        _initialHPPerWord[card.id] = card.currentHP;
      }
      
      // Update the card in the provider to save the XP changes
      final provider = context.read<FlashcardProvider>();
      await provider.updateCard(card);
      print('🔍 AdvancedStudyView: Updated card "${card.word}" in provider - wasCorrect: $wasCorrect, current XP: ${card.learningMastery.currentXP}');
      
      // Also sync to Dutch words if this card exists there
      await _syncToDutchWords(card, wasCorrect);
      
    } catch (e) {
      print('🔍 AdvancedStudyView: Error updating card in provider: $e');
    }
  }

  void _awardXPToWord(FlashCard card) {
    // Get the actual XP gained (after diminishing returns) from the last entry
    final actualXPGained = card.learningMastery.exerciseHistory.isNotEmpty 
        ? card.learningMastery.exerciseHistory.last['xpGained'] as int 
        : 0;
    
    // Track XP gained for this word in this session (accumulate for multiple appearances)
    _xpGainedPerWord[card.id] = (_xpGainedPerWord[card.id] ?? 0) + actualXPGained;
    
    // Store the mastery for display
    _wordMastery[card.id] = card.learningMastery;
    
    print('🔍 AdvancedStudyView: Awarded $actualXPGained XP to word "${card.word}" (${card.learningMastery.currentXP} total XP)');
  }

  Future<void> _addCardToReview(FlashCard card) async {
    try {
      final provider = context.read<FlashcardProvider>();
      await provider.addCardToReview(card);
      print('🔍 AdvancedStudyView: Added "${card.word}" to review deck');
    } catch (e) {
      print('🔍 AdvancedStudyView: Error adding card to review: $e');
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
        print('🔍 AdvancedStudyView: Synced progress to Dutch word exercise "${wordExercise.targetWord}"');
      }
    } catch (e) {
      print('🔍 AdvancedStudyView: Error syncing to Dutch words: $e');
    }
  }

  void _nextCard() {
    if (_useStackedMode) {
      _removeTopCard();
    } else {
      setState(() {
        _nextCardActive = true;
        // Keep the current swipe direction and intensity for the exit animation
      });
      
      // Set up exit animation based on swipe direction
      _setupExitAnimation();
      
      // Start exit animation
      _exitController.forward();
      
      // Animate card off-screen in the swipe direction
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _currentIndex++;
            _nextCardActive = false;
            _dragOffset = Offset.zero;
            _swipeDirection = SwipeDirection.none;
            _swipeIntensity = 0;
            
            if (_currentIndex >= _currentCards.length && !_hasShownResults) {
              // Award XP for the session
              _awardXp();
              _showingResults = true;
              print('🔍 AdvancedStudyView: Study complete, showing results');
            } else {
              _isShowingFront = !widget.startFlipped;
              _flipController.reset();
              // Reset exit animation for next card
              _exitController.reset();
              // Start deal animation for next card
              _dealController.reset();
              _dealController.forward();
            }
          });
        }
      });
    }
  }
  
  void _removeTopCard() {
    if (_topIndex < _currentCards.length) {
      setState(() {
        _topIndex++;
        _swipeDirection = SwipeDirection.none;
        _swipeIntensity = 0;
        
        // In mixed mode, randomly choose which side to show for the next card
        _isShowingFront = !widget.startFlipped;
      });
      
      // Check if we've gone through all cards
      if (_topIndex >= _currentCards.length && !_hasShownResults) {
        // Award XP for the session
        _awardXp();
        _showingResults = true;
        print('🔍 AdvancedStudyView: Study complete (stacked mode), showing results');
      }
    }
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Study Session?'),
        content: const Text('Are you sure you want to end this study session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to study type selection
            },
            child: const Text('End Session'),
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
        content: const Text('Are you sure you want to return to the home screen? This will end your current study session.'),
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

  void _showWordProgress() {
    // Include all cards in the end screen for both modes to show "not known" cards consistently
    List<FlashCard> sessionStudiedWords;
    Map<String, int> sessionXpGainedPerWord;
    Map<String, LearningMastery> sessionWordMastery;
    
    // Always include all cards for both flipped and stacked modes
    sessionStudiedWords = List<FlashCard>.from(_currentCards);
    sessionXpGainedPerWord = Map<String, int>.from(_xpGainedPerWord);
    sessionWordMastery = Map<String, LearningMastery>.from(_wordMastery);
    
    // Ensure all cards have entries in the maps (0 XP and current mastery for unanswered cards)
    for (final card in _currentCards) {
      if (!sessionXpGainedPerWord.containsKey(card.id)) {
        sessionXpGainedPerWord[card.id] = 0; // 0 XP for unanswered cards
      }
      if (!sessionWordMastery.containsKey(card.id)) {
        sessionWordMastery[card.id] = card.learningMastery; // Current mastery for unanswered cards
      }
    }
    
    GameEndScreen.show(
      context,
      GameEndResult(
        title: 'Word Progress',
        studiedWords: sessionStudiedWords,
        xpGainedPerWord: sessionXpGainedPerWord,
        wordMastery: sessionWordMastery,
        initialHPPerWord: Map<String, int>.from(_initialHPPerWord),
        correctAnswers: _knownCards.length,
        totalQuestions: sessionStudiedWords.isNotEmpty ? sessionStudiedWords.length : _currentCards.length,
        onStudyAgain: (available) {
          Navigator.of(context).pop();
          _resetStudySession(shuffleCards: false, filteredCards: available);
        },
        onShuffle: widget.studyConfig != null
            ? (available) {
                Navigator.of(context).pop();
                _resetStudySession(shuffleCards: true, filteredCards: available);
              }
            : null,
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _resetStudySession({bool shuffleCards = true, List<FlashCard>? filteredCards}) {
    setState(() {
      // Reset all card state
      _currentIndex = 0;
      _topIndex = 0;
      // Use filtered cards if provided, otherwise use all session cards
      _currentCards = filteredCards != null
          ? List<FlashCard>.from(filteredCards)
          : List<FlashCard>.from(_sessionCards);
      if (shuffleCards) {
        _currentCards.shuffle(math.Random());
      }
      _knownCards.clear();
      _unknownCards.clear();
      _skippedCards.clear();
      _studiedWords.clear();
      _xpGainedPerWord.clear();
      _wordMastery.clear();
      _initialHPPerWord.clear();
      // Track initial HP for all cards at the start of the new session
      for (final card in _currentCards) {
        _initialHPPerWord[card.id] = card.currentHP;
      }
      _combo = 0;
      _maxCombo = 0;
      
      // Reset history tracking
      _cardHistory.clear();
      _knownHistory.clear();
      _unknownHistory.clear();
      _skippedHistory.clear();
      
      // Reset swipe/drag state
      _dragOffset = Offset.zero;
      _swipeDirection = SwipeDirection.none;
      _swipeIntensity = 0;
      _nextCardActive = false;
      
      // Reset session tracking
      _gameSession.reset();
      _sessionStartTime = DateTime.now();
      _sessionXP = 0;
      
      // Reset UI state
      _showingResults = false;
      _hasShownResults = false;
      _isShowingFront = !widget.startFlipped;
      _selectedCardForEdit = null;
      
      // Reset all animation controllers
      _flipController.reset();
      _dealController.reset();
      _exitController.reset();
      
      if (widget.startFlipped) {
        _flipController.value = 1.0;
      } else {
        _flipController.value = 0.0;
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _dealController.forward();
      }
    });
  }

  void _shuffleAndRestart() {
    if (widget.studyConfig == null) return;
    
    final provider = context.read<FlashcardProvider>();
    
    List<FlashCard> allDeckCards = [];
    final seenCardIds = <String>{};
    
    if (widget.studyConfig!.deckIds.isEmpty) {
      allDeckCards = List<FlashCard>.from(provider.cards);
    } else {
      for (final deckId in widget.studyConfig!.deckIds) {
        final deckCards = provider.getCardsForDeckWithSubDecks(deckId);
        for (final card in deckCards) {
          if (seenCardIds.add(card.id)) {
            allDeckCards.add(card);
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
    
    List<FlashCard> filteredCards;
    if (widget.studyConfig!.useSRSFiltering) {
      final dueCards = allDeckCards.where((card) => card.isDueForReview).toList();
      final notDueCards = allDeckCards.where((card) => !card.isDueForReview).toList();
      filteredCards = [...dueCards, ...notDueCards];
    } else {
      filteredCards = allDeckCards;
    }
    
    final availableCards = filteredCards.where((card) => card.canBeStudiedToday).toList();
    
    if (availableCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available for study today.')),
      );
      return;
    }
    
    availableCards.shuffle(math.Random());
    final desiredCount = widget.studyConfig!.cardCount >= 50
        ? availableCards.length
        : widget.studyConfig!.cardCount;
    final clampedDesired = desiredCount.clamp(1, availableCards.length);
    final cardCount = clampedDesired is int ? clampedDesired : clampedDesired.toInt();
    final refreshedCards = availableCards.take(cardCount).toList();
    
    setState(() {
      _sessionCards = List<FlashCard>.from(refreshedCards);
    });
    
    _resetStudySession();
  }

  void _awardXp() {
    // Calculate total XP from actual word XP gained
    final totalXPGained = _xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp);
    
    if (totalXPGained > 0) {
      final userProfileProvider = context.read<UserProfileProvider>();
      userProfileProvider.addXp(totalXPGained);
    }
    
    // Update session statistics
    final totalCards = _knownCards.length + _unknownCards.length + _skippedCards.length;
    final accuracy = totalCards > 0 ? (_knownCards.length / totalCards) : 0.0;
    final isPerfect = _unknownCards.isEmpty && _skippedCards.isEmpty && totalCards > 0;
    
    context.read<UserProfileProvider>().updateSessionStats(
      cardsStudied: totalCards,
      sessionAccuracy: accuracy,
      isPerfect: isPerfect,
    );
    
    // Update streak based on study activity (Duolingo-style)
    context.read<UserProfileProvider>().updateStreakFromStudyActivity();
  }

  void _handleSwipeUpdate(SwipeDirection direction, double intensity) {
    setState(() {
      _swipeDirection = direction;
      _swipeIntensity = intensity;
    });
  }

  void _markAnswer(SwipeDirection direction) {
    final currentCard = _currentCards[_topIndex];
    
    // Remove any previous state for this card
    _knownCards.remove(currentCard.id);
    _unknownCards.remove(currentCard.id);
    _skippedCards.remove(currentCard.id);
    
    // Track the studied word before we modify it
    if (!_studiedWords.any((word) => word.id == currentCard.id)) {
      _studiedWords.add(currentCard);
    }
    
    switch (direction) {
      case SwipeDirection.left: // Don't Know
        _unknownCards.add(currentCard.id);
        _combo = 0;
        // Track XP for incorrect answer (0 XP)
        XpService.recordAnswer(_gameSession, false);
        // Explicitly set 0 XP for unknown cards
        _xpGainedPerWord[currentCard.id] = 0;
        // Mark card as incorrect (this records the attempt via recordGameAttempt)
        currentCard.markIncorrect(GameDifficulty.medium);
        // markIncorrect now adds to exerciseHistory automatically
        // Update learning progress - marked as incorrect
        _updateCardLearningProgress(currentCard, false);
        break;
      case SwipeDirection.right: // Known
        _knownCards.add(currentCard.id);
        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
        // Track XP for correct answer (5 XP)
        XpService.recordAnswer(_gameSession, true);
        // Update learning progress - marked as correct
        _updateCardLearningProgress(currentCard, true);
        break;
      case SwipeDirection.up: // Review - removed
      case SwipeDirection.down: // Skip - removed
      default:
        break;
    }
  }
}

class TaalTrekStackCard extends StatefulWidget {
  final FlashCard card;
  final bool isTop;
  final Offset offset;
  final double scale;
  final double width, height;
  final VoidCallback? onDismissed;
  final Function(SwipeDirection) onAnswer;
  final bool startFlipped;
  final Function(SwipeDirection, double)? onSwipeUpdate;

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
      case SwipeDirection.down:
        exitOffset = const Offset(0.0, -2.0); // Exit top as fallback
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

  void _handleCardDoubleTap() {
    // Toggle the flip state
    showBack = !showBack;
    
    if (showBack) {
      // Going to back (definition) - animate to 1.0
      _flipController.forward();
    } else {
      // Going to front (word) - animate to 0.0
      _flipController.reverse();
    }
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
    double tiltAngle = (position.dx / screenWidth) * 0.8;

    // Gesture handling with smooth movement
    return GestureDetector(
      onPanStart: (details) {
        // Continuous vibration removed for a cleaner experience
      },
      onPanUpdate: (details) {
        final previousReached = position.distance > 100;
        
        setState(() {
          position += details.delta;
          
          // Calculate swipe intensity - mapping 0 to 100 distance to 0 to 1.0 intensity
          final intensity = (position.distance / 100).clamp(0.0, 1.2);
          
          // Call the swipe update callback
          widget.onSwipeUpdate?.call(swipeDirection, intensity);
          
          // Determine reached state for single haptic click
          final currentReached = position.distance > 100;
          if (currentReached && !previousReached) {
            HapticService().selectionFeedback(); // Precise haptic click when reached enough distance
          }
          
          // Determine swipe direction - easier diagonal support, horizontal priority
          if (position.dx.abs() > 10) {
            if (position.dx > 0) {
              userAnswer = true; // Swiping right = know
              swipeDirection = SwipeDirection.right;
            } else {
              userAnswer = false; // Swiping left = don't know
              swipeDirection = SwipeDirection.left;
            }
          } else {
            userAnswer = null;
            swipeDirection = SwipeDirection.none;
          }
        });
        
        // Threshold check happens below in onPanEnd
      },
      onPanEnd: (details) {
        // Stop any remaining vibration if needed
        HapticService().stopContinuousVibration();
        final velocity = details.velocity.pixelsPerSecond;
        final speed = velocity.distance;
        
        print('🔍 TaalTrekStackCard: Pan ended - direction: $swipeDirection, distance: ${position.distance}, speed: $speed');
        
        // Increased threshold to 100 (from 60) for better control as requested
        if (position.distance > 100 || speed > 450) {
          print('🎯 TaalTrekStackCard: Swipe completed - direction: $swipeDirection, distance: ${position.distance}, speed: $speed');
          // Play swipe sound for successful swipe
          SoundManager().playSwipeSound();
          // Mark answer immediately
          widget.onAnswer(swipeDirection);
          
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
          widget.onSwipeUpdate?.call(SwipeDirection.none, 0.0);
        }
      },
      onDoubleTap: _handleCardDoubleTap,
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

  const TaalTrekFlashCard({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    required this.flipAnimation,
    required this.startFlipped,
    this.userAnswer,
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
        ..rotateY(flipAnimation.value * math.pi),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateY(isFlipped ? math.pi : 0),
        child: isFlipped ? _buildCardBack(context) : _buildCardFront(context),
      ),
    );
  }

  Widget _buildCardFront(BuildContext context) {
    final borderColor = _getCardBorderColor();
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
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.word,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: responsiveFontSize,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
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
    final borderColor = _getCardBorderColor();
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
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.definition,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: responsiveFontSize,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // Copy the exact border color logic from Quick Study (AdvancedStudyView)
  Color _getCardBorderColor() {
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