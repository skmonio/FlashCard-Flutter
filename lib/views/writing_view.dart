import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../services/sound_manager.dart';
import '../services/haptic_service.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../models/dutch_word_exercise.dart';

import '../components/word_progress_display.dart';
import '../services/xp_service.dart';

class WritingView extends StatefulWidget {
  final List<FlashCard> cards;
  final String title;
  final Function(bool)? onComplete;
  final bool shuffleMode;
  final bool startFlipped;
  final bool useMixedMode;

  const WritingView({
    super.key,
    required this.cards,
    required this.title,
    this.onComplete,
    this.shuffleMode = false,
    this.startFlipped = false,
    this.useMixedMode = false,
  });

  @override
  State<WritingView> createState() => _WritingViewState();
}

class _WritingViewState extends State<WritingView> {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  bool _showingResults = false;
  bool _answered = false;
  String _correctAnswer = '';
  String _displayWord = '';
  bool _isQuestionMode = true; // true = definition to word, false = word to definition
  int _lives = 5;
  String _userAnswer = '';
  final TextEditingController _textController = TextEditingController();
  Set<String> _guessedLetters = {};
  Set<String> _revealedLetters = {};
  
  // Track answered questions and their answers
  Map<int, String> _answeredQuestions = {}; // question index -> user answer
  Map<int, bool> _correctAnswersMap = {}; // question index -> is correct
  Map<int, String> _correctAnswersText = {}; // question index -> correct answer
  Map<int, bool> _questionModes = {}; // question index -> is question mode
  
  // Maintain our own copy of cards that can be updated
  late List<FlashCard> _currentCards;
  
  // RPG word progress tracking
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  List<FlashCard> _studiedWords = [];

  // Custom keyboard letters
  List<String> _keyboardLetters = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize our copy of cards
    _currentCards = List<FlashCard>.from(widget.cards);
    
    _generateQuestion();
    
    // Listen for card updates from the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FlashcardProvider>();
      provider.addListener(_onProviderChanged);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    
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
      
      // If we're currently viewing a card that was updated, regenerate the question
      if (_currentIndex < _currentCards.length && !_showingResults) {
        _generateQuestion();
      }
    });
    
    print('🔍 WritingView: Refreshed cards from provider');
  }
  
  void _generateKeyboardLetters() {
    // Get unique letters from the correct answer
    final Set<String> answerLetters = {};
    for (int i = 0; i < _correctAnswer.length; i++) {
      final char = _correctAnswer[i];
      if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        answerLetters.add(char.toUpperCase());
      }
    }
    
    // Add some extra common letters to make the keyboard more useful
    final extraLetters = ['A', 'E', 'I', 'O', 'U', 'R', 'S', 'T', 'N', 'L', 'C', 'D', 'P', 'M', 'H', 'G', 'B', 'F', 'K', 'W', 'V', 'X', 'Y', 'Z', 'J', 'Q'];
    
    // Combine answer letters with some extra letters
    final Set<String> allLetters = {...answerLetters};
    
    // Add extra letters (but not too many to keep the keyboard manageable)
    final random = Random();
    final targetSize = answerLetters.length + 8; // Aim for answer letters + 8 extra
    
    while (allLetters.length < targetSize && extraLetters.isNotEmpty) {
      final randomIndex = random.nextInt(extraLetters.length);
      allLetters.add(extraLetters[randomIndex]);
      extraLetters.removeAt(randomIndex);
    }
    
    // Convert to list and shuffle
    _keyboardLetters = allLetters.toList()..shuffle(random);
  }
  
  void _generateQuestion() {
    if (_currentIndex >= _currentCards.length) {
      // Calculate success rate
      final successRate = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered) : 0.0;
      final wasSuccessful = successRate >= 0.6; // 60% or higher is considered successful
      
      // Call the onComplete callback if provided
      if (widget.onComplete != null) {
        widget.onComplete!(wasSuccessful);
        return;
      }
      
      setState(() {
        _showingResults = true;
      });
      // Play completion sound when test is finished
      SoundManager().playCompleteSound();
      return;
    }

    // Check if this question has already been answered
    if (_answeredQuestions.containsKey(_currentIndex)) {
      // Load existing question data
      _isQuestionMode = _questionModes[_currentIndex]!;
      _correctAnswer = _correctAnswersText[_currentIndex]!;
      _userAnswer = _answeredQuestions[_currentIndex]!;
      _answered = true;
      _textController.text = _userAnswer;
      
      // Regenerate keyboard letters for this question
      _generateKeyboardLetters();
      
      // Reconstruct the letter tracking sets based on the stored answer
      _guessedLetters.clear();
      _revealedLetters.clear();
      
      // If the question was answered correctly, all letters should be revealed
      if (_correctAnswersMap[_currentIndex] == true) {
        for (int i = 0; i < _correctAnswer.length; i++) {
          final char = _correctAnswer[i];
          if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
            _revealedLetters.add(char.toUpperCase());
          }
        }
      } else {
        // If answered incorrectly, we need to determine which letters were guessed
        // For now, we'll show the complete answer since we don't track individual guesses
        for (int i = 0; i < _correctAnswer.length; i++) {
          final char = _correctAnswer[i];
          if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
            _revealedLetters.add(char.toUpperCase());
          }
        }
      }
      
      // Show the complete answer
      _displayWord = _correctAnswer;
      
      return;
    }

    final currentCard = _currentCards[_currentIndex];
    final random = Random();
    
    // Choose question mode based on flipped mode settings
    if (widget.useMixedMode) {
      _isQuestionMode = random.nextBool(); // Randomly choose question mode
    } else {
      _isQuestionMode = !widget.startFlipped; // Use flipped mode setting
    }
    
    // Get correct answer
    _correctAnswer = _isQuestionMode ? currentCard.word : currentCard.definition;
    
    // Clear letter tracking sets FIRST to prevent any prefilling
    _guessedLetters.clear();
    _revealedLetters.clear();
    
    // Generate custom keyboard letters
    _generateKeyboardLetters();
    
    // Initialize display word with underscores
    _updateDisplayWord();
    
    // Store question data for future reference
    _correctAnswersText[_currentIndex] = _correctAnswer;
    _questionModes[_currentIndex] = _isQuestionMode;
    
    setState(() {
      _answered = false;
      _lives = 5;
      _userAnswer = '';
      _textController.clear();
    });
  }

  Color _getCardBorderColor(FlashCard card) {
    // Generate consistent vibrant colors based on card content
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
    
    // Use card content to generate consistent index
    final hash = card.word.hashCode + card.definition.hashCode;
    final index = hash.abs() % vibrantColors.length;
    return vibrantColors[index];
  }

  void _guessLetter(String letter) {
    if (_answered) return;
    
    final upperLetter = letter.toUpperCase();
    final lowerLetter = letter.toLowerCase();
    
    // Check if letter was already guessed
    if (_guessedLetters.contains(upperLetter) || _revealedLetters.contains(upperLetter)) {
      return;
    }
    
    setState(() {
      _guessedLetters.add(upperLetter);
      
      // Check if letter is in the word
      if (_correctAnswer.toLowerCase().contains(lowerLetter)) {
        // Correct guess - reveal all instances of this letter
        _revealedLetters.add(upperLetter);
        SoundManager().playCorrectSound();
        HapticService().successFeedback();
        
        // Update display word
        _updateDisplayWord();
        
        // Check if word is complete
        if (_isWordComplete()) {
          _answered = true;
          _correctAnswers++;
          _totalAnswered++;
          _correctAnswersMap[_currentIndex] = true;
          _answeredQuestions[_currentIndex] = _displayWord;
          
                // Award XP to word for RPG system
          _awardXPToWord(_currentCards[_currentIndex], true);
          
          // Update the card in the provider to save the XP changes
          _updateCardInProvider(_currentCards[_currentIndex]);
        }
      } else {
        // Wrong guess
        _lives--;
        SoundManager().playWrongSound();
        HapticService().errorFeedback();
        
        // Check if game over
        if (_lives <= 0) {
          _answered = true;
          _totalAnswered++;
          // Show the complete correct answer
          _displayWord = _correctAnswer;
          _correctAnswersMap[_currentIndex] = false;
          _answeredQuestions[_currentIndex] = _displayWord;
          
          // Award XP to word for RPG system
          _awardXPToWord(_currentCards[_currentIndex], false);
          
          // Update the card in the provider to save the XP changes
          _updateCardInProvider(_currentCards[_currentIndex]);
        }
      }
    });
  }
  
  void _updateDisplayWord() {
    String newDisplay = '';
    for (int i = 0; i < _correctAnswer.length; i++) {
      final char = _correctAnswer[i];
      if (char == ' ') {
        newDisplay += ' '; // Keep spaces as spaces
      } else {
        final upperChar = char.toUpperCase();
        if (_revealedLetters.contains(upperChar) || _guessedLetters.contains(upperChar)) {
          newDisplay += char; // Show revealed/guessed letters
        } else if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
          newDisplay += '_'; // Show underscore for unguessed letters
        } else {
          newDisplay += char; // Keep punctuation and other characters
        }
      }
    }
    _displayWord = newDisplay;
  }
  
  bool _isWordComplete() {
    for (int i = 0; i < _correctAnswer.length; i++) {
      final char = _correctAnswer[i];
      if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        final upperChar = char.toUpperCase();
        if (!_revealedLetters.contains(upperChar) && !_guessedLetters.contains(upperChar)) {
          return false; // Found an unguessed letter
        }
      }
    }
    return true; // All letters have been guessed
  }

  Future<void> _updateCardInProvider(FlashCard card) async {
    try {
      final provider = context.read<FlashcardProvider>();
      
      // Update the card in the provider to save the XP changes
      await provider.updateCard(card);
      print('🔍 WritingView: Updated card "${card.word}" in provider - current XP: ${card.learningMastery.currentXP}');
      
    } catch (e) {
      print('🔍 WritingView: Error updating card in provider: $e');
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
        print('🔍 WritingView: Synced progress to Dutch word exercise "${wordExercise.targetWord}"');
      }
    } catch (e) {
      print('🔍 WritingView: Error syncing to Dutch words: $e');
    }
  }

  void _goToPreviousQuestion() {
    // Only allow navigation if the question is answered
    if (!_answered) return;
    
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _generateQuestion();
    }
  }

  void _goToNextQuestion() {
    // Only allow navigation if the question is answered
    if (!_answered) return;
    
    if (_currentIndex < _currentCards.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _generateQuestion();
    } else {
      // Show results when on last question and clicking next
      setState(() {
        _showingResults = true;
      });
      // Play completion sound when test is finished
      SoundManager().playCompleteSound();
    }
  }





  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('No cards available for writing'),
        ),
      );
    }

    if (_showingResults) {
      return _buildResultsView();
    }

    final currentCard = _currentCards[_currentIndex];

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
                        widget.title,
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
                // Progress bar
                _buildProgressBar(),
              ],
            ),
          ),
          
          // Scrollable play area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Question text above card
                  Text(
                    'Write the translation for',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Card with white background and colored outline
                  Container(
                    width: double.infinity,
                    height: 200,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getCardBorderColor(currentCard),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getCardBorderColor(currentCard).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _isQuestionMode ? currentCard.definition : currentCard.word,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Navigation buttons (always visible, greyed out when not available)
                  Row(
                    children: [
                      // Back button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_answered && _currentIndex > 0) ? _goToPreviousQuestion : null,
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_answered && _currentIndex > 0) ? Colors.blue : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Next/Finish button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_answered && _currentIndex < _currentCards.length - 1) ? _goToNextQuestion : null,
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text(_currentIndex == _currentCards.length - 1 ? 'Finish' : 'Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_answered && _currentIndex < _currentCards.length - 1) ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Display word with underscores
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _displayWord.split('').map((char) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 25,
                          height: 35,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              char,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Add some bottom padding to ensure content doesn't get hidden behind keyboard
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Custom keyboard (fixed at bottom) - only show when not answered
          if (!_answered) _buildCustomKeyboard(),
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
              Text('Question ${_currentIndex + 1} of ${_currentCards.length}'),
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

  Widget _buildResultsView() {
    final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered * 100).toInt() : 0;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right to show word progress
          if (details.primaryVelocity! < 0 && _xpGainedPerWord.values.isNotEmpty) {
            _showWordProgress();
          }
        },
        child: Column(
          children: [
            // Small header - matching study view
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
                      'Writing Complete',
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
              ),
            ),
            
            // Results content - Make it scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Score
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
                    _buildStatCard('Questions', _totalAnswered.toString(), Icons.edit),
                    const SizedBox(height: 16),
                    _buildStatCard('Correct', _correctAnswers.toString(), Icons.check_circle, Colors.green),
                    const SizedBox(height: 16),
                    _buildStatCard('Incorrect', (_totalAnswered - _correctAnswers).toString(), Icons.cancel, Colors.red),
                    
                    // Swipe hint if XP was gained
                    if (_xpGainedPerWord.values.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swipe_right,
                              color: Colors.amber,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Swipe right to view word progress',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ),
              ),
            ),
            
            // Fixed footer with action buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        
                        setState(() {
                          _currentIndex = 0;
                          _correctAnswers = 0;
                          _totalAnswered = 0;
                          _showingResults = false;
                          _answered = false;
                          _displayWord = '';
                          _lives = 5;
                          _userAnswer = '';
                          _textController.clear();
                          _guessedLetters.clear();
                          _revealedLetters.clear();
                          // Reset all navigation state
                          _answeredQuestions.clear();
                          _correctAnswersMap.clear();
                          _correctAnswersText.clear();
                          _questionModes.clear();
                          
                          // Reset RPG tracking
                          _xpGainedPerWord.clear();
                          _wordMastery.clear();
                          _studiedWords.clear();
                        });
                        _generateQuestion();
                      },
                      child: const Text('Write Again'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, [Color? color]) {
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Writing Test'),
        content: const Text('Are you sure you want to exit? Your progress will be lost.'),
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
            child: const Text('Exit'),
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
        content: const Text('Are you sure you want to return to the home screen? This will end your current writing test.'),
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
  
  void _awardXPToWord(FlashCard card, bool isCorrect) {
    // Only award XP for correct answers
    if (isCorrect) {
      final xpService = XpService();
      final xpGained = xpService.calculateWordXP("writing", 1);
      
      // Add XP to the word's learning mastery
      xpService.addXPToWord(card.learningMastery, "writing", 1);
      
      // Track XP gained for this word in this session (add for multiple appearances in same session)
      _xpGainedPerWord[card.id] = xpGained;
      
      // Store the word mastery for display
      _wordMastery[card.id] = card.learningMastery;
      
      print('🔍 WritingView: Awarded $xpGained XP to word "${card.word}" (Correct: $isCorrect)');
    } else {
      print('🔍 WritingView: No XP awarded to word "${card.word}" (Incorrect: $isCorrect)');
    }
    
    // Track studied words (regardless of correctness)
    if (!_studiedWords.any((word) => word.id == card.id)) {
      _studiedWords.add(card);
    }
  }
  
  void _showWordProgress() {
    // Create copies of the current session data for the display
    final sessionStudiedWords = List<FlashCard>.from(_studiedWords);
    final sessionXpGainedPerWord = Map<String, int>.from(_xpGainedPerWord);
    final sessionWordMastery = Map<String, LearningMastery>.from(_wordMastery);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordProgressDisplay(
          xpGainedPerWord: sessionXpGainedPerWord,
          wordMastery: sessionWordMastery,
          studiedWords: sessionStudiedWords,
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close word progress screen
            // Reset and restart test
            setState(() {
              _currentIndex = 0;
              _correctAnswers = 0;
              _totalAnswered = 0;
              _showingResults = false;
              _answered = false;
              _lives = 5;
              _userAnswer = '';
              _textController.clear();
              _guessedLetters.clear();
              _revealedLetters.clear();
              
              // Reset all navigation state
              _answeredQuestions.clear();
              _correctAnswersMap.clear();
              _correctAnswersText.clear();
              _questionModes.clear();
              
              // Reset RPG tracking
              _xpGainedPerWord.clear();
              _wordMastery.clear();
              _studiedWords.clear();
            });
            _generateQuestion();
            
            // Session data has been reset, ready for new game
          },
          onDone: () {
            Navigator.of(context).pop(); // Close word progress screen
            Navigator.of(context).popUntil((route) => route.isFirst); // Go to home
          },
        ),
      ),
    );
  }
  
  Widget _buildCustomKeyboard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), // Added bottom padding for gap
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Keyboard title
          Text(
            _answered ? 'Final answer' : 'Tap letters to guess',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          
          // Keyboard grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _keyboardLetters.map((letter) {
              final isGuessed = _guessedLetters.contains(letter);
              final isRevealed = _revealedLetters.contains(letter);
              final isInAnswer = _correctAnswer.toUpperCase().contains(letter);
              
              Color buttonColor;
              Color textColor;
              
              if (_answered) {
                // Question is answered - show final state
                if (isInAnswer) {
                  // Letter is in the answer - green
                  buttonColor = Colors.green;
                  textColor = Colors.white;
                } else {
                  // Letter is not in the answer - grey
                  buttonColor = Colors.grey.withValues(alpha: 0.3);
                  textColor = Colors.grey.shade600;
                }
              } else if (isRevealed) {
                // Correct guess - green
                buttonColor = Colors.green;
                textColor = Colors.white;
              } else if (isGuessed) {
                // Wrong guess - red
                buttonColor = Colors.red;
                textColor = Colors.white;
              } else {
                // Not guessed yet - default
                buttonColor = Theme.of(context).colorScheme.surfaceVariant;
                textColor = Theme.of(context).colorScheme.onSurface;
              }
              
              return GestureDetector(
                onTap: () {
                  if (!isGuessed && !isRevealed && !_answered) {
                    _guessLetter(letter);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

}