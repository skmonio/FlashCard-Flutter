import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/flashcard_provider.dart';
import '../models/flash_card.dart';
import '../components/unified_header.dart';

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
          // Header
          UnifiedHeader(
            title: widget.title,
            onBack: () => Navigator.of(context).pop(),
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
                Text('Card ${_currentCardIndex + 1} of ${_currentCards.length}'),
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
          // Question card
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
                    contextMenuBuilder: (context, editableTextState) {
                      return const SizedBox.shrink(); // Hide context menu
                    },
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
          // Scrambled word
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
          // Question
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
                  ),
                ],
              ),
            ),
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
          // Question card
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
          // Card display
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Correct: $_correctAnswers / $_totalAnswers'),
          Text('Accuracy: ${_totalAnswers > 0 ? ((_correctAnswers / _totalAnswers) * 100).toInt() : 0}%'),
        ],
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
    
    // Add correct answer and shuffle
    _multipleChoiceOptions = [correctAnswer, ...wrongOptions];
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
    });

    // Update the card's SRS data
    final currentCard = _currentCards[_currentCardIndex];
    if (isCorrect) {
      currentCard.markCorrect();
    } else {
      currentCard.markIncorrect();
    }

    // Save the updated card
    context.read<FlashcardProvider>().updateCard(currentCard);

    // Move to next card or finish
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        if (_currentCardIndex < _currentCards.length - 1) {
          setState(() {
            _currentCardIndex++;
            _showAnswer = false;
            _generateMultipleChoiceOptions();
            _generateScrambledWord();
          });
        } else {
          _showResults();
        }
      }
    });
  }

  void _showResults() {
    final accuracy = _currentCards.isNotEmpty ? (_correctAnswers / _currentCards.length * 100).toInt() : 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Study Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
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
            
            // Stats
            _buildStatCard('Cards Studied', _currentCards.length.toString(), Icons.school),
            const SizedBox(height: 8),
            _buildStatCard('Known', _correctAnswers.toString(), Icons.check_circle, Colors.green),
            const SizedBox(height: 8),
            _buildStatCard('Unknown', (_currentCards.length - _correctAnswers).toString(), Icons.cancel, Colors.red),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, [Color? color]) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color ?? Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
} 