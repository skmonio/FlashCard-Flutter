import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../models/flash_card.dart';
import '../models/game_session.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/dutch_word_exercise.dart';
import '../services/xp_service.dart';
import '../components/xp_progress_widget.dart';
import '../components/animated_xp_counter.dart';
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
                      const Text(
                        'Study Your Cards',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        onSelected: _handleMenuAction,
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'info',
                            child: Row(
                              children: [
                                Icon(Icons.info),
                                SizedBox(width: 8),
                                Text('Info'),
                              ],
                            ),
                          ),
                        ],
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
    final progress = _currentIndex / _currentCards.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Card ${_currentIndex + 1} of ${_currentCards.length}'),
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

  Widget _buildCardAreaWithLabels() {
    return Stack(
      children: [
        // Directional label behind the card (only show relevant one)
        if (_swipeDirection != SwipeDirection.none && _swipeIntensity > 0.3)
          _buildDirectionalLabel(),
        
        // Card area
        _buildCardArea(),
      ],
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
              icon: const Icon(Icons.arrow_back, size: 16),
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
            ..rotateY(_flipAnimation.value * pi),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateY(isFlipped ? pi : 0),
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
      setState(() {
        _currentIndex--;
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
      print('🔍 AdvancedStudyView: Updated learning progress for "${card.word}" - wasCorrect: $wasCorrect, new percentage: ${updatedCard.learningPercentage}%');
      
      // Also sync to Dutch words if this card exists there
      await _syncToDutchWords(card, wasCorrect);
      
    } catch (e) {
      print('🔍 AdvancedStudyView: Error updating learning progress: $e');
    }
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

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _editCurrentCard();
        break;
      case 'delete':
        _deleteCurrentCard();
        break;
      case 'info':
        _showCardInfo();
        break;
    }
  }

  void _deleteCurrentCard() {
    final currentCard = _currentCards[_currentIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text('Are you sure you want to delete "${currentCard.word}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final provider = context.read<FlashcardProvider>();
              await provider.deleteCard(currentCard.id);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted card: ${currentCard.word}')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCardInfo() {
    final currentCard = _currentCards[_currentIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentCard.word),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Definition: ${currentCard.definition}'),
            if (currentCard.example != null) ...[
              const SizedBox(height: 8),
              Text('Example: ${currentCard.example}'),
            ],
            const SizedBox(height: 8),
            Text('SRS Level: ${currentCard.srsLevel}'),
            Text('Times Shown: ${currentCard.timesShown}'),
            Text('Times Correct: ${currentCard.timesCorrect}'),
            Text('Success Rate: ${currentCard.timesShown > 0 ? ((currentCard.timesCorrect / currentCard.timesShown) * 100).toStringAsFixed(1) : '0'}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
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

  Widget _buildResultsView() {
    final totalCards = _knownCards.length + _unknownCards.length + _skippedCards.length;
    final accuracy = totalCards > 0 ? (_knownCards.length / totalCards * 100).toInt() : 0;
    final sessionDuration = DateTime.now().difference(_sessionStartTime);
    
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
                    'Study Complete',
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
                  // Score circle
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: accuracy >= 80 ? Colors.green.withValues(alpha: 0.1) : 
                             accuracy >= 60 ? Colors.orange.withValues(alpha: 0.1) : 
                             Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$accuracy%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: accuracy >= 80 ? Colors.green : 
                                 accuracy >= 60 ? Colors.orange : 
                                 Colors.red,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Session stats
                  _buildStatCard('Cards Studied', totalCards.toString(), Icons.school),
                  const SizedBox(height: 16),
                  _buildStatCard('Known', _knownCards.length.toString(), Icons.check_circle, Colors.green),
                  const SizedBox(height: 16),
                  _buildStatCard('XP Earned', '', Icons.star, Colors.amber,
                    AnimatedXpCounter(xpGained: _gameSession.xpGained)),
                  const SizedBox(height: 16),
                  _buildStatCard('Unknown', _unknownCards.length.toString(), Icons.cancel, Colors.red),
                  const SizedBox(height: 16),
                  _buildStatCard('Skipped', _skippedCards.length.toString(), Icons.skip_next, Colors.orange),
                  const SizedBox(height: 48),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
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
                          },
                          child: const Text('Study Again'),
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

  void _awardXp() {
    if (_gameSession.xpGained > 0) {
      final userProfileProvider = context.read<UserProfileProvider>();
      XpService.awardSessionXp(userProfileProvider, _gameSession, isShuffleMode: false);
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
} 