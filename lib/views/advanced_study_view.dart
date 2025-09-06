import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../models/flash_card.dart';
import '../models/game_session.dart';
import '../models/learning_mastery.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/dutch_word_exercise.dart';
import '../services/xp_service.dart';

import '../components/word_progress_display.dart';
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

  const AdvancedStudyView({
    super.key,
    required this.cards,
    this.startFlipped = false,
    required this.title,
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
  late List<FlashCard> _currentCards;
  
  // RPG tracking
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  List<FlashCard> _studiedWords = [];

  @override
  void initState() {
    super.initState();
    _isShowingFront = !widget.startFlipped;
    
    // Initialize our copy of cards
    _currentCards = List<FlashCard>.from(widget.cards);
    
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
    ));
    
    // Set initial position based on startFlipped
    if (widget.startFlipped) {
      _flipController.value = 1.0;
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
    });
    
    print('🔍 AdvancedStudyView: Refreshed cards from provider');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
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
        _showWordProgress();
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
                      const Text(
                        'Study Your Cards',
                        style: TextStyle(
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
                // Progress bar
                _buildProgressBar(),
              ],
            ),
          ),
          
          // Main card area with background color based on swipe direction
          Expanded(
            child: Container(
              child: Column(
                children: [
                  // Card area with directional labels behind
                  Expanded(
                    child: _buildCardAreaWithLabels(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Navigation buttons under the card
                  _buildNavigationButtons(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final currentCardIndex = _useStackedMode ? _topIndex : _currentIndex;
    final progress = currentCardIndex / _currentCards.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Card ${currentCardIndex + 1} of ${_currentCards.length}'),
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

  Widget _buildCardArea() {
    if (_useStackedMode) {
      return _buildStackedCardArea();
    } else {
      return _buildSingleCardArea();
    }
  }
  
  Widget _buildSingleCardArea() {
    final currentCard = _currentCards[_currentIndex];
    
    return GestureDetector(
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onDoubleTap: _handleCardDoubleTap,
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Directional label behind the card (only show relevant one)
          if (_swipeDirection != SwipeDirection.none && _swipeIntensity > 0.3)
            _buildDirectionalLabel(),
          
          // Card area
          _buildCardArea(),
        ],
      ),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _currentIndex > 0 ? _goToPreviousCard : null,
              icon: const Icon(Icons.arrow_back_ios, size: 16),
              label: const Text('Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentIndex > 0 ? Colors.blue : Colors.grey,
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
        final isFlipped = _flipAnimation.value >= 0.5;
        
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

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_nextCardActive) return;
    
    setState(() {
      _dragOffset += details.delta;
      _swipeIntensity = (_dragOffset.distance / 150).clamp(0.0, 1.0);
      
      // Determine swipe direction - strict cardinal directions only
      final horizontalDistance = _dragOffset.dx.abs();
      final verticalDistance = _dragOffset.dy.abs();
      
      // Only allow pure horizontal or vertical swipes (no diagonal)
      if (horizontalDistance > verticalDistance * 2.0) {
        // Horizontal swipe - left or right
        _swipeDirection = _dragOffset.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
      } else if (verticalDistance > horizontalDistance * 2.0) {
        // Vertical swipe - up or down
        _swipeDirection = _dragOffset.dy > 0 ? SwipeDirection.down : SwipeDirection.up;
      } else {
        // Diagonal swipe - reset to none and don't allow movement
        _swipeDirection = SwipeDirection.none;
        _swipeIntensity = 0;
        _dragOffset = Offset.zero;
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_nextCardActive) return;
    
    final velocity = details.velocity.pixelsPerSecond;
    final distance = _dragOffset.distance;
    
    // Only process swipe if we have a valid direction and sufficient distance/velocity
    if (_swipeDirection != SwipeDirection.none && (distance > 100 || velocity.distance > 500)) {
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

  void _handleCardDoubleTap() {
    if (_nextCardActive) return;
    
    // Toggle the flip state
    _isShowingFront = !_isShowingFront;
    
    if (_isShowingFront) {
      // Going to front (word) - animate to 0.0
      _flipController.reverse();
    } else {
      // Going to back (definition) - animate to 1.0
      _flipController.forward();
    }
  }

  void _goToPreviousCard() {
    if (_currentIndex > 0) {
      // Get the previous card index
      final previousIndex = _currentIndex - 1;
      
      // Remove the current card from tracking sets since we're going back
      final currentCard = _currentCards[_currentIndex];
      _knownCards.remove(currentCard.id);
      _unknownCards.remove(currentCard.id);
      _skippedCards.remove(currentCard.id);
      
      // Remove from history tracking
      _knownHistory.remove(_currentIndex);
      _unknownHistory.remove(_currentIndex);
      _skippedHistory.remove(_currentIndex);
      
      setState(() {
        _currentIndex = previousIndex;
        _dragOffset = Offset.zero;
        _swipeDirection = SwipeDirection.none;
        _swipeIntensity = 0;
        _isShowingFront = !widget.startFlipped;
        _flipController.reset();
        if (widget.startFlipped) {
          _flipController.value = 1.0;
        }
        // Reset exit animation for previous card
        _exitController.reset();
        // Start deal animation for previous card
        _dealController.reset();
        _dealController.forward();
      });
      
      // Update the previous card's state based on its last action
      // This will be handled when the user swipes again on this card
    }
  }

  void _editCurrentCard() {
    _selectedCardForEdit = _currentCards[_currentIndex];
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
    if (_swipeDirection == SwipeDirection.none || _swipeIntensity < 0.3) {
      return Colors.transparent;
    }
    
    final baseColor = _getSwipeColor();
    final intensity = (_swipeIntensity * 0.3).clamp(0.0, 0.3);
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
    
    switch (direction) {
      case SwipeDirection.left: // Don't Know
        _unknownCards.add(currentCard.id);
        _unknownHistory[_currentIndex] = true;
        _combo = 0;
        // Track XP for incorrect answer (0 XP)
        XpService.recordAnswer(_gameSession, false);
        // Update learning progress - marked as incorrect
        _updateCardLearningProgress(currentCard, false);
        break;
      case SwipeDirection.right: // Known
        _knownCards.add(currentCard.id);
        _knownHistory[_currentIndex] = true;
        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
        // Track XP for correct answer (5 XP)
        XpService.recordAnswer(_gameSession, true);
        // Update learning progress - marked as correct
        _updateCardLearningProgress(currentCard, true);
        break;
      case SwipeDirection.up: // Review
        // Add card to review deck
        _addCardToReview(currentCard);
        // No XP for review actions - these are cards that need more study
        break;
      case SwipeDirection.down: // Skip
        _skippedCards.add(currentCard.id);
        _skippedHistory[_currentIndex] = true;
        _combo = 0;
        // Don't update learning progress for skipped cards
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
      
      // Track studied words
      if (!_studiedWords.any((word) => word.id == card.id)) {
        _studiedWords.add(card);
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
    final xpService = XpService();
    
    // For advanced study, we'll use a generic "study" exercise type
    // Award XP to the word's learning mastery (this handles daily diminishing returns)
    xpService.addXPToWord(card.learningMastery, 'study', _combo);
    
    // Get the actual XP gained (after diminishing returns)
    final actualXPGained = card.learningMastery.exerciseHistory.isNotEmpty 
        ? card.learningMastery.exerciseHistory.last['xpGained'] as int 
        : 0;
    
    // Track XP gained for this word in this session (add for multiple appearances in same session)
          _xpGainedPerWord[card.id] = actualXPGained;
    
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
            
            if (_currentIndex >= _currentCards.length) {
              // Award XP for the session
              _awardXp();
              _showingResults = true;
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
      });
      
      // Check if we've gone through all cards
      if (_topIndex >= _currentCards.length) {
        // Award XP for the session
        _awardXp();
        _showingResults = true;
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
              Navigator.of(context).pop();
              Navigator.of(context).pop();
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
    // Create copies of the current session data for the display
    final sessionStudiedWords = List<FlashCard>.from(_studiedWords);
    final sessionXpGainedPerWord = Map<String, int>.from(_xpGainedPerWord);
    final sessionWordMastery = Map<String, LearningMastery>.from(_wordMastery);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordProgressDisplay(
          studiedWords: sessionStudiedWords,
          xpGainedPerWord: sessionXpGainedPerWord,
          wordMastery: sessionWordMastery,
          hideNavigation: true, // Hide back button and swipe for advanced study
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close word progress screen
            // Reset and restart study session
            setState(() {
              // Reset all card state
              _currentIndex = 0;
              _knownCards.clear();
              _unknownCards.clear();
              _skippedCards.clear();
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
              _isShowingFront = !widget.startFlipped;
              _selectedCardForEdit = null;
              
              // Reset all animation controllers
              _flipController.reset();
              _dealController.reset();
              _exitController.reset();
              
              if (widget.startFlipped) {
                _flipController.value = 1.0;
              }
            });
            
            // Start initial deal animation for first card
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _dealController.forward();
              }
            });
            
            // Session data has been reset, ready for new game
          },
          onDone: () {
            Navigator.of(context).pop(); // Close word progress screen
            Navigator.of(context).pop(); // Go back to study type screen
          },
        ),
      ),
    );
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
    
    switch (direction) {
      case SwipeDirection.left: // Don't Know
        _unknownCards.add(currentCard.id);
        _combo = 0;
        // Track XP for incorrect answer (0 XP)
        XpService.recordAnswer(_gameSession, false);
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
      case SwipeDirection.up: // Review
        // Add card to review deck
        _addCardToReview(currentCard);
        // No XP for review actions - these are cards that need more study
        break;
      case SwipeDirection.down: // Skip
        _skippedCards.add(currentCard.id);
        _combo = 0;
        // Don't update learning progress for skipped cards
        break;
      default:
        return;
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
    double tiltAngle = (position.dx / screenWidth) * 0.5;

    // Gesture handling with smooth movement
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          position += details.delta;
          
          // Calculate swipe intensity
          final intensity = (position.distance / 150).clamp(0.0, 1.0);
          
          // Call the swipe update callback
          widget.onSwipeUpdate?.call(swipeDirection, intensity);
          
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
        final velocity = details.velocity.pixelsPerSecond;
        final speed = velocity.distance;
        
        // Use the exact logic from your working code
        if (position.distance > 120 || speed > 600) {
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
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24), // Match Quick Study exactly
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
          width: 5, // Match Quick Study exactly
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32), // Match Quick Study exactly
        child: Center(
          child: Text(
            card.word,
            style: const TextStyle(
              fontSize: 42, // Match Quick Study font sizes
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack(BuildContext context) {
    final borderColor = _getCardBorderColor();
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24), // Match Quick Study exactly
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
          width: 5, // Match Quick Study exactly
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32), // Match Quick Study exactly
        child: Center(
          child: Text(
            card.definition,
            style: const TextStyle(
              fontSize: 36, // Match Quick Study font sizes
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
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