import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';

import '../utils/game_end_screen.dart';
import '../components/main_header.dart';
import 'add_card_view.dart';

enum StudyMode {
  multipleChoice,
  wordScramble,
  writing,
  trueFalse,
  lookCoverCheck,
}

class StudyView extends StatefulWidget {
  final List<FlashCard> cards;
  final StudyMode studyMode;
  final bool startFlipped;
  final String title;

  const StudyView({
    super.key,
    required this.cards,
    required this.studyMode,
    this.startFlipped = false,
    required this.title,
  });

  @override
  State<StudyView> createState() => _StudyViewState();
}

class _StudyViewState extends State<StudyView> {
  int _currentCardIndex = 0;
  int _correctAnswers = 0;
  int _totalAnswers = 0;
  bool _showAnswer = false;
  bool _isFlipped = false;
  List<String> _multipleChoiceOptions = [];
  String _scrambledWord = '';
  String _userAnswer = '';
  bool _isCorrect = false;
  bool _showResult = false;
  List<FlashCard> _currentCards = [];
  
  // RPG tracking
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  Map<String, int> _initialHPPerWord = {}; // Track initial HP when word is first encountered
  List<FlashCard> _studiedWords = [];
  int _consecutiveCorrect = 0;
  Set<String> _hpPenaltyAppliedWordIds = {};
  
  // Review and navigation tracking
  Set<String> _reviewCards = {}; // card IDs marked for review
  Set<int> _answeredQuestions = {}; // indices of answered questions

  @override
  void initState() {
    super.initState();
    _isFlipped = widget.startFlipped;
    _currentCards = List.from(widget.cards);
    _generateMultipleChoiceOptions();
    _generateScrambledWord();
    
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
    
    print('🔍 StudyView: Refreshed cards from provider');
  }

  void _ensureCardTracked(FlashCard card) {
    if (_studiedWords.any((word) => word.id == card.id)) return;
    _studiedWords.add(card);
    _initialHPPerWord[card.id] = card.currentHP;
  }

  GameDifficulty _getDifficultyForCurrentMode() {
    switch (widget.studyMode) {
      case StudyMode.multipleChoice:
      case StudyMode.trueFalse:
        return GameDifficulty.easy;
      case StudyMode.wordScramble:
      case StudyMode.lookCoverCheck:
        return GameDifficulty.medium;
      case StudyMode.writing:
        return GameDifficulty.hard;
    }
  }

  void _applyHpPenalty(FlashCard card, {required bool wasCorrect}) {
    _ensureCardTracked(card);
    // Only apply HP penalty once per game session per word
    // This ensures -1hp is deducted per game, not per exercise
    if (_hpPenaltyAppliedWordIds.contains(card.id)) {
      return; // Already applied HP penalty for this word in this game session
    }
    _hpPenaltyAppliedWordIds.add(card.id);
    
    final difficulty = _getDifficultyForCurrentMode();
    if (wasCorrect) {
      card.markCorrect(difficulty);
    } else {
      card.markIncorrect(difficulty);
    }
  }

  void _goToPreviousQuestion() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
      });
    }
  }

  void _goToNextQuestion() {
    if (_currentCardIndex < _currentCards.length - 1) {
      setState(() {
        _currentCardIndex++;
      });
    } else {
      // Last card - show completion screen
      _showWordProgress();
    }
  }

  void _editCurrentCard() {
    final currentCard = _currentCards[_currentCardIndex];
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCardView(
          cardToEdit: currentCard,
        ),
      ),
    );
  }

  Widget _buildReviewFlag(FlashCard card) {
    final isInReview = _reviewCards.contains(card.id);
    return GestureDetector(
      onTap: () => _toggleReviewCard(card),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isInReview ? Colors.yellow : Colors.yellow.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.orange,
            width: 2,
          ),
        ),
        child: Icon(
          Icons.flag,
          size: 16,
          color: isInReview ? Colors.orange : Colors.orange.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  void _toggleReviewCard(FlashCard card) async {
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
      print('🔍 StudyView: Error toggling review card: $e');
    }
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          MainHeader(
            title: 'Study',
            leftAction: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          
          // Progress bar
          _buildProgressBar(),
          
          // Main content
          Expanded(
            child: _buildStudyContent(),
          ),
          
          // Footer
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _totalAnswers / _currentCards.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
                      Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_currentCardIndex + 1}/${_currentCards.length}'),
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

  Widget _buildStudyContent() {
    final currentCard = _currentCards[_currentCardIndex];
    
    switch (widget.studyMode) {
      case StudyMode.multipleChoice:
        return _buildMultipleChoiceView(currentCard);
      case StudyMode.wordScramble:
        return _buildWordScrambleView(currentCard);
      case StudyMode.writing:
        return _buildWritingView(currentCard);
      case StudyMode.trueFalse:
        return _buildTrueFalseView(currentCard);
      case StudyMode.lookCoverCheck:
        return _buildLookCoverCheckView(currentCard);
    }
  }

  Widget _buildMultipleChoiceView(FlashCard card) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Question card with flag
          Stack(
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _isFlipped ? 'Translate to Dutch:' : 'What does this mean?',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        _isFlipped ? card.definition : card.word,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        enableInteractiveSelection: true,
                        showCursor: false,
                      ),
                      if (card.article.isNotEmpty && !_isFlipped) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Article: ${card.article}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Flag button (top-left)
              Positioned(
                top: 8,
                left: 8,
                child: _buildReviewFlag(card),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Multiple choice options
          ..._multipleChoiceOptions.map((option) => _buildChoiceButton(option)),
          
          // Flip button
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _toggleFlip,
            icon: const Icon(Icons.flip),
            label: const Text('Flip Card'),
          ),
        ],
      ),
    );
  }

  Widget _buildWordScrambleView(FlashCard card) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Scrambled word with flag
          Stack(
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Unscramble the word:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        _scrambledWord,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                        enableInteractiveSelection: true,
                        showCursor: false,
                        contextMenuBuilder: (context, editableTextState) {
                          return const SizedBox.shrink(); // Hide context menu
                        },
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        'Hint: ${card.definition}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                        enableInteractiveSelection: true,
                        showCursor: false,
                        contextMenuBuilder: (context, editableTextState) {
                          return const SizedBox.shrink(); // Hide context menu
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // Flag button (top-left)
              Positioned(
                top: 8,
                left: 8,
                child: _buildReviewFlag(card),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Answer input
          TextField(
            decoration: const InputDecoration(
              labelText: 'Your answer',
              border: OutlineInputBorder(),
              hintText: 'Type the unscrambled word...',
            ),
            onChanged: (value) {
              setState(() {
                _userAnswer = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Submit button
          ElevatedButton(
            onPressed: _userAnswer.isNotEmpty ? _checkScrambleAnswer : null,
            child: const Text('Submit Answer'),
          ),
          
          // Result
          if (_showResult) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCorrect ? Icons.check_circle : Icons.cancel,
                    color: _isCorrect ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isCorrect ? 'Correct!' : 'Incorrect. The answer is: ${card.word}',
                      style: TextStyle(
                        color: _isCorrect ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWritingView(FlashCard card) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Question with flag
          Stack(
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _isFlipped ? 'Write the Dutch word:' : 'Write the translation:',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isFlipped ? card.definition : card.word,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ],
                  ),
                ),
              ),
              // Flag button (top-left)
              Positioned(
                top: 8,
                left: 8,
                child: _buildReviewFlag(card),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Answer input
          TextField(
            decoration: const InputDecoration(
              labelText: 'Your answer',
              border: OutlineInputBorder(),
              hintText: 'Type your answer...',
            ),
            onChanged: (value) {
              setState(() {
                _userAnswer = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Submit button
          ElevatedButton(
            onPressed: _userAnswer.isNotEmpty ? _checkWritingAnswer : null,
            child: const Text('Submit Answer'),
          ),
          
          // Result
          if (_showResult) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCorrect ? Icons.check_circle : Icons.cancel,
                    color: _isCorrect ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isCorrect ? 'Correct!' : 'Incorrect. The answer is: ${_isFlipped ? card.word : card.definition}',
                      style: TextStyle(
                        color: _isCorrect ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrueFalseView(FlashCard card) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Question card with flag
          Stack(
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'True or False:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${card.word} means ${card.definition}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              // Flag button (top-left)
              Positioned(
                top: 8,
                left: 8,
                child: _buildReviewFlag(card),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // True/False buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _checkTrueFalseAnswer(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(20),
                  ),
                  child: const Text('TRUE'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _checkTrueFalseAnswer(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(20),
                  ),
                  child: const Text('FALSE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLookCoverCheckView(FlashCard card) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Card display with flag
          Stack(
            children: [
              Card(
                elevation: 4,
                child: InkWell(
                  onTap: _toggleShowAnswer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          _showAnswer ? (_isFlipped ? card.word : card.definition) : (_isFlipped ? card.definition : card.word),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _showAnswer ? 'Tap to hide' : 'Tap to reveal',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Flag button (top-left)
              Positioned(
                top: 8,
                left: 8,
                child: _buildReviewFlag(card),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Answer buttons
          if (_showAnswer) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _markAnswer(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('I Knew It'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _markAnswer(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text('I Didn\'t Know'),
                  ),
                ),
              ],
            ),
          ],
          
          // Flip button
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _toggleFlip,
            icon: const Icon(Icons.flip),
            label: const Text('Flip Card'),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton(String option) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: () => _checkMultipleChoiceAnswer(option),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.centerLeft,
        ),
        child: SelectableText(
          option,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.left,
          enableInteractiveSelection: true,
          showCursor: false,
          contextMenuBuilder: (context, editableTextState) {
            return const SizedBox.shrink(); // Hide context menu
          },
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final canGoBack = _currentCardIndex > 0;
    final canGoNext = _answeredQuestions.contains(_currentCardIndex) || _currentCardIndex > 0 && !_answeredQuestions.contains(_currentCardIndex);
    final isLastCard = _currentCardIndex == _currentCards.length - 1;
    
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
                onPressed: canGoBack ? _goToPreviousQuestion : null,
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
                onPressed: canGoNext ? _goToNextQuestion : null,
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

  void _generateMultipleChoiceOptions() {
    if (widget.cards.isEmpty) return;
    
    final currentCard = widget.cards[_currentCardIndex];
    final correctAnswer = _isFlipped ? currentCard.word : currentCard.definition;
    
    // Get other cards for wrong options
    final otherCards = widget.cards.where((card) => card.id != currentCard.id).toList();
    final wrongOptions = otherCards.take(3).map((card) => 
      _isFlipped ? card.word : card.definition
    ).toList();
    
    // Create options list with correct answer first
    _multipleChoiceOptions = [correctAnswer, ...wrongOptions];
    
    // Shuffle options in study mode so correct answer isn't always first
    _multipleChoiceOptions.shuffle();
  }

  void _generateScrambledWord() {
    if (widget.cards.isEmpty) return;
    
    final word = widget.cards[_currentCardIndex].word.toLowerCase();
    final letters = word.split('');
    letters.shuffle();
    _scrambledWord = letters.join('');
  }

  void _toggleFlip() {
    setState(() {
      _isFlipped = !_isFlipped;
      _generateMultipleChoiceOptions();
    });
  }

  void _toggleShowAnswer() {
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  void _checkMultipleChoiceAnswer(String selectedAnswer) {
    final currentCard = widget.cards[_currentCardIndex];
    final correctAnswer = _isFlipped ? currentCard.word : currentCard.definition;
    final isCorrect = selectedAnswer == correctAnswer;
    
    _handleAnswer(isCorrect);
  }

  void _checkScrambleAnswer() {
    final currentCard = widget.cards[_currentCardIndex];
    final isCorrect = _userAnswer.toLowerCase() == currentCard.word.toLowerCase();
    
    setState(() {
      _isCorrect = isCorrect;
      _showResult = true;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showResult = false;
          _userAnswer = '';
        });
        _handleAnswer(isCorrect);
      }
    });
  }

  void _checkWritingAnswer() {
    final currentCard = _currentCards[_currentCardIndex];
    final correctAnswer = _isFlipped ? currentCard.word : currentCard.definition;
    final isCorrect = _userAnswer.toLowerCase() == correctAnswer.toLowerCase();
    
    setState(() {
      _isCorrect = isCorrect;
      _showResult = true;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showResult = false;
          _userAnswer = '';
        });
        _handleAnswer(isCorrect);
      }
    });
  }

  void _checkTrueFalseAnswer(bool answer) {
    // For true/false, we'll always mark as correct for now
    // In a real implementation, you'd have predefined true/false questions
    _handleAnswer(true);
  }

  void _markAnswer(bool knewIt) {
    _handleAnswer(knewIt);
  }

  void _handleAnswer(bool isCorrect) {
    setState(() {
      if (isCorrect) _correctAnswers++;
      _totalAnswers++;
      
      // Track that this question has been answered
      _answeredQuestions.add(_currentCardIndex);
    });

    // Update consecutive correct count for streak bonuses
    if (isCorrect) {
      _consecutiveCorrect++;
    } else {
      _consecutiveCorrect = 0;
    }

    final currentCard = _currentCards[_currentCardIndex];
    
    _applyHpPenalty(currentCard, wasCorrect: isCorrect);
    
    if (isCorrect) {
      _awardXPToWord(currentCard);
    } else {
      _xpGainedPerWord[currentCard.id] = 0;
      
      // Store the mastery for display (even for incorrect answers)
      _wordMastery[currentCard.id] = currentCard.learningMastery;
    }

    // Track studied words
    if (!_studiedWords.any((word) => word.id == currentCard.id)) {
      _studiedWords.add(currentCard);
    }

    // Save the updated card
    context.read<FlashcardProvider>().updateCard(currentCard);
  }

  void _awardXPToWord(FlashCard card) {
    _ensureCardTracked(card);
    
    final latestEntry = card.learningMastery.exerciseHistory.isNotEmpty
        ? card.learningMastery.exerciseHistory.last
        : null;
    final actualXPGained = latestEntry != null
        ? (latestEntry['xpGained'] as int? ?? 0)
        : 0;
    
    _xpGainedPerWord[card.id] = actualXPGained;
    _wordMastery[card.id] = card.learningMastery;
    
    print('🔍 StudyView: Logged $actualXPGained XP for word "${card.word}" (${card.learningMastery.currentXP} total XP)');
  }



  void _showWordProgress() {
    // Award profile XP based on actual word XP gained
    final totalXPGained = _xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp);
    if (totalXPGained > 0) {
      final userProfileProvider = context.read<UserProfileProvider>();
      userProfileProvider.addXp(totalXPGained);
    }
    
    // For flipped mode, include all cards in the end screen, not just studied ones
    List<FlashCard> sessionStudiedWords;
    Map<String, int> sessionXpGainedPerWord;
    Map<String, LearningMastery> sessionWordMastery;
    
    if (widget.startFlipped) {
      // Include all cards for flipped mode
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
            _currentCardIndex = 0;
            _correctAnswers = 0;
            _totalAnswers = 0;
            _showAnswer = false;
            _isFlipped = widget.startFlipped;
            _consecutiveCorrect = 0;
            _xpGainedPerWord.clear();
            _wordMastery.clear();
            _studiedWords.clear();
            _initialHPPerWord.clear();
            _hpPenaltyAppliedWordIds.clear();
          });
          
          _generateMultipleChoiceOptions();
          _generateScrambledWord();
        },
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

} 