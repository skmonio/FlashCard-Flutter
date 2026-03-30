import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dutch_word_exercise.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';

import '../utils/game_end_screen.dart';
import '../services/xp_service.dart';
import '../utils/sentence_utils.dart';
import '../components/main_header.dart';

class DutchWordsPracticeView extends StatefulWidget {
  final String deckId;
  final String deckName;
  final List<DutchWordExercise> exercises;

  const DutchWordsPracticeView({
    super.key,
    required this.deckId,
    required this.deckName,
    required this.exercises,
  });

  @override
  State<DutchWordsPracticeView> createState() => _DutchWordsPracticeViewState();
}

class _DutchWordsPracticeViewState extends State<DutchWordsPracticeView> {
  late List<WordExercise> _allExercises;
  late List<WordExercise> _shuffledExercises;
  late List<String> _exerciseToWordExerciseId; // Maps exercise index to DutchWordExercise ID
  // Store current session order for "Study Again" functionality
  // This preserves the order that was actually used in the current session
  List<WordExercise> _currentSessionOrderExercises = [];
  List<String> _currentSessionOrderExerciseIds = [];
  int _currentExerciseIndex = 0;
  String? _selectedAnswer;
  bool _showAnswer = false;
  bool _isCorrect = false;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  
  // Shuffled options for multiple choice questions
  Map<int, List<String>> _shuffledOptions = {};
  
  // Sentence building state
  List<String> _answerWords = [];
  List<String> _availableWords = [];
  
  // State preservation maps
  Map<int, bool> _answeredQuestions = {};
  Map<int, String?> _selectedAnswers = {};
  Map<int, List<String>> _sentenceAnswers = {};
  Map<int, List<String>> _sentenceAvailable = {};
  
  // RPG word progress tracking
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  Map<String, int> _initialHPPerWord = {}; // Track initial HP when word is first encountered
  List<FlashCard> _studiedWords = [];
  final Set<String> _hpPenaltyAppliedWordIds = {};
  bool _lastSyncAppliedHpPenalty = false;
  String? _lastSyncedCardId;

  @override
  void initState() {
    super.initState();
    _initializePractice();
  }

  void _initializePractice({bool shuffle = true}) {
    // Collect all exercises from all words in the deck with their word exercise IDs
    final List<MapEntry<WordExercise, String>> exerciseEntries = [];
    
    for (final wordExercise in widget.exercises) {
      for (final exercise in wordExercise.exercises) {
        exerciseEntries.add(MapEntry(exercise, wordExercise.id));
      }
    }
    
    if (shuffle) {
      // Shuffle the entries
      exerciseEntries.shuffle();
    } else {
      // Use current session order (preserve the order from the previous session)
      if (_currentSessionOrderExercises.isNotEmpty) {
        exerciseEntries.clear();
        for (int i = 0; i < _currentSessionOrderExercises.length; i++) {
          exerciseEntries.add(MapEntry(_currentSessionOrderExercises[i], _currentSessionOrderExerciseIds[i]));
        }
      }
      // If no current session order exists, use the order as-is (first time, no shuffle)
    }
    
    // Store the current session order (the order we're actually using)
    _currentSessionOrderExercises = exerciseEntries.map((entry) => entry.key).toList();
    _currentSessionOrderExerciseIds = exerciseEntries.map((entry) => entry.value).toList();
    
    // Extract the exercises and their corresponding word exercise IDs
    _allExercises = exerciseEntries.map((entry) => entry.key).toList();
    _shuffledExercises = List<WordExercise>.from(_allExercises);
    _exerciseToWordExerciseId = exerciseEntries.map((entry) => entry.value).toList();
    
    // Initialize first exercise
    if (_shuffledExercises.isNotEmpty) {
      _initializeShuffledOptions(0, _shuffledExercises[0]);
    }
  }
  
  void _shuffleAndRestart() {
    setState(() {
      _currentExerciseIndex = 0;
      _selectedAnswer = null;
      _showAnswer = false;
      _correctAnswers = 0;
      _totalAnswered = 0;
      _answerWords = [];
      _availableWords = [];
      _shuffledOptions.clear();
      _answeredQuestions.clear();
      _selectedAnswers.clear();
      _sentenceAnswers.clear();
      _sentenceAvailable.clear();
      
      // Reset RPG tracking for this session only
      _xpGainedPerWord.clear();
      _wordMastery.clear();
      _initialHPPerWord.clear();
      _studiedWords.clear();
      _hpPenaltyAppliedWordIds.clear();
      _lastSyncedCardId = null;
      _lastSyncAppliedHpPenalty = false;
      
      // Shuffle and restart
      _initializePractice(shuffle: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shuffledExercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Practice: ${widget.deckName}'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No exercises available in this deck.'),
        ),
      );
    }

    final currentExercise = _shuffledExercises[_currentExerciseIndex];
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: MainHeader(
          title: 'Exercise',
          leftAction: IconButton(
            onPressed: () => _showCloseConfirmation(),
            icon: const Icon(Icons.arrow_back_ios),
            tooltip: 'Back',
          ),
          rightAction: IconButton(
            onPressed: () => _showHomeConfirmation(),
            icon: const Icon(Icons.home),
            tooltip: 'Go Home',
          ),
        ),
      ),
      body: Column(
        children: [
          // Progress Bar
          _buildProgressBar(),
          
          // Exercise Content
          Expanded(
            child: _buildExerciseContent(currentExercise),
          ),
          
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final percentage = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered * 100).toInt() : 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentExerciseIndex + 1}/${_shuffledExercises.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _currentExerciseIndex / _shuffledExercises.length,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseContent(WordExercise exercise) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise prompt
          SelectableText(
            exercise.prompt,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.left,
            enableInteractiveSelection: true,
            showCursor: false,
          ),
          
          const SizedBox(height: 24),
          
          // Exercise options based on type
          if (exercise.type == ExerciseType.multipleChoice || exercise.type == ExerciseType.fillInBlank)
            _buildMultipleChoiceOptions(exercise)
          else if (exercise.type == ExerciseType.sentenceBuilding)
            _buildSentenceBuildingOptions(exercise),
          
          const SizedBox(height: 24),
          
          // Answer feedback
          if (_showAnswer) _buildAnswerFeedback(exercise),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceOptions(WordExercise exercise) {
    final options = _shuffledOptions[_currentExerciseIndex] ?? exercise.options;
    
    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = _selectedAnswer == option;
        // Find the correct answer in the shuffled options
        final originalCorrectIndex = int.tryParse(exercise.correctAnswer) ?? 0;
        final originalCorrectAnswer = exercise.options[originalCorrectIndex];
        final shuffledCorrectIndex = options.indexOf(originalCorrectAnswer);
        final isCorrect = index == shuffledCorrectIndex;
        final showCorrect = _showAnswer && isCorrect;
        final showIncorrect = _showAnswer && isSelected && !isCorrect;
        
        Color backgroundColor = Theme.of(context).colorScheme.surface;
        Color borderColor = Colors.grey.withOpacity(0.3);
        
        if (showCorrect) {
          backgroundColor = Colors.green.withOpacity(0.1);
          borderColor = Colors.green;
        } else if (showIncorrect) {
          backgroundColor = Colors.red.withOpacity(0.1);
          borderColor = Colors.red;
        } else if (isSelected) {
          backgroundColor = Colors.blue.withOpacity(0.1);
          borderColor = Colors.blue;
        }
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showAnswer ? null : () {
                setState(() {
                  _selectedAnswer = option;
                });
                // Immediately check the answer
                _checkAnswer();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      showCorrect ? Icons.check_circle : 
                      showIncorrect ? Icons.cancel : 
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: showCorrect ? Colors.green : 
                             showIncorrect ? Colors.red : 
                             isSelected ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSentenceBuildingOptions(WordExercise exercise) {
    // Initialize sentence building state if not already done
    if (_answeredQuestions[_currentExerciseIndex] == true) {
      // Load saved state
      _answerWords = List<String>.from(_sentenceAnswers[_currentExerciseIndex] ?? []);
      _availableWords = List<String>.from(_sentenceAvailable[_currentExerciseIndex] ?? []);
      _showAnswer = true;
      _selectedAnswer = _selectedAnswers[_currentExerciseIndex];
    } else if (_answerWords.isEmpty && _availableWords.isEmpty) {
      // Use stored shuffled options for sentence building
      List<String> wordsToShuffle;
      if (exercise.type == ExerciseType.sentenceBuilding) {
        // For sentence building, use the options (individual words)
        wordsToShuffle = List<String>.from(exercise.options);
      } else {
        // For other exercise types, split the correct answer
        wordsToShuffle = exercise.correctAnswer.split(' ');
      }
      
      if (!_shuffledOptions.containsKey(_currentExerciseIndex)) {
        _shuffledOptions[_currentExerciseIndex] = List<String>.from(wordsToShuffle)..shuffle();
      }
      _availableWords = List<String>.from(_shuffledOptions[_currentExerciseIndex]!);
      _answerWords = [];
    }
    
    return Column(
      children: [
        Text(
          '',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Answer area (where user builds the sentence)
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildAnswerWords(_answerWords, _currentExerciseIndex),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Available words area (only show if there are available words)
        if (_availableWords.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Words:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildAvailableWords(_availableWords),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  List<Widget> _buildAnswerWords(List<String> words, int exerciseIndex) {
    // Get correct order for this exercise
    final currentExercise = _shuffledExercises[exerciseIndex];
    List<String> correctOrder = [];
    if (currentExercise.type == ExerciseType.sentenceBuilding) {
      // For sentence building, the correct order comes from splitting the correctAnswer string
      // This ensures we use the actual correct sentence order, not the shuffled options
      correctOrder = currentExercise.correctAnswer.split(' ').map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
    } else {
      // For other types, split the correct answer
      correctOrder = currentExercise.correctAnswer.split(' ');
    }
    
    // Check per-word positions if answer is shown
    List<bool>? positionCorrect;
    if (_showAnswer) {
      positionCorrect = SentenceUtils.checkWordPositions(words, correctOrder);
    }
    
    return words.asMap().entries.map((entry) {
      final wordIndex = entry.key;
      final word = entry.value;
      final isPositionCorrect = positionCorrect != null && wordIndex < positionCorrect.length 
          ? positionCorrect[wordIndex] 
          : null;
      
      // Determine colors based on position correctness
      Color backgroundColor;
      Color borderColor;
      Color textColor;
      
      if (_showAnswer && isPositionCorrect != null) {
        if (isPositionCorrect) {
          backgroundColor = Colors.green.withOpacity(0.2);
          borderColor = Colors.green;
          textColor = Colors.green[700]!;
        } else {
          backgroundColor = Colors.red.withOpacity(0.2);
          borderColor = Colors.red;
          textColor = Colors.red[700]!;
        }
      } else {
        backgroundColor = Colors.green.withOpacity(0.2);
        borderColor = Colors.green.withOpacity(0.5);
        textColor = Colors.green[700]!;
      }
      
      return GestureDetector(
        onTap: _showAnswer ? null : () => _moveWordToAvailable(word),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                word,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_showAnswer && isPositionCorrect != null) ...[
                const SizedBox(width: 4),
                Icon(
                  isPositionCorrect ? Icons.check_circle : Icons.cancel,
                  color: isPositionCorrect ? Colors.green : Colors.red,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildAvailableWords(List<String> words) {
    return words.map((word) {
      return GestureDetector(
        onTap: () => _moveWordToAnswer(word),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.withOpacity(0.5)),
          ),
          child: Text(
            word,
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }).toList();
  }

  void _moveWordToAnswer(String word) {
    if (_showAnswer) return; // Don't allow changes after answering
    
    setState(() {
      _availableWords.remove(word);
      _answerWords.add(word);
    });
  }

  void _moveWordToAvailable(String word) {
    if (_showAnswer) return; // Don't allow changes after answering
    
    setState(() {
      _answerWords.remove(word);
      _availableWords.add(word);
    });
  }

  void _initializeShuffledOptions(int questionIndex, WordExercise exercise) {
    if (!_shuffledOptions.containsKey(questionIndex)) {
      // Shuffle options in study mode so correct answer isn't always first
      _shuffledOptions[questionIndex] = List<String>.from(exercise.options)..shuffle();
    }
  }

  bool _canCheckAnswer() {
    final currentExercise = _shuffledExercises[_currentExerciseIndex];
    
    if (currentExercise.type == ExerciseType.sentenceBuilding) {
      // For sentence building, check if all words are used
      // Use the options length since that's what we're shuffling and using
      return _answerWords.length == currentExercise.options.length;
    } else {
      // For other exercise types, check if an answer is selected
      return _selectedAnswer != null;
    }
  }

  void _loadExerciseState() {
    if (_answeredQuestions[_currentExerciseIndex] == true) {
      // Load saved state
      _selectedAnswer = _selectedAnswers[_currentExerciseIndex];
      _showAnswer = true;
      _answerWords = List<String>.from(_sentenceAnswers[_currentExerciseIndex] ?? []);
      _availableWords = List<String>.from(_sentenceAvailable[_currentExerciseIndex] ?? []);
    } else {
      // Reset for new question
      _selectedAnswer = null;
      _showAnswer = false;
      _answerWords = [];
      _availableWords = [];
    }
  }

  Widget _buildAnswerFeedback(WordExercise exercise) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isCorrect ? Colors.green : Colors.red,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCorrect ? Icons.check_circle : Icons.cancel,
                color: _isCorrect ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                _isCorrect ? 'Correct!' : 'Incorrect',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isCorrect ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            exercise.explanation,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.left,
            enableInteractiveSelection: true,
            showCursor: false,
          ),
          if (!_isCorrect && exercise.type == ExerciseType.sentenceBuilding) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'The correct answer is: ${exercise.correctAnswer}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.left,
                    enableInteractiveSelection: true,
                    showCursor: false,
                  ),
                ),
              ],
            ),
          ],
          if (exercise.hint != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              'Hint: ${exercise.hint}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.left,
              enableInteractiveSelection: true,
              showCursor: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final currentExercise = _shuffledExercises[_currentExerciseIndex];
    final isSentenceBuilding = currentExercise.type == ExerciseType.sentenceBuilding;
    
    // Determine button state based on answer status
    final bool canCheckAnswer = _canCheckAnswer();
    final bool canGoNext = _showAnswer; // Can go next only after answer is checked
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _currentExerciseIndex > 0 ? () {
                setState(() {
                  _currentExerciseIndex--;
                  _loadExerciseState();
                });
              } : null,
              child: const Text('Previous'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: canGoNext ? () {
                _nextExercise();
              } : (canCheckAnswer ? () {
                _checkAnswer();
              } : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: canGoNext ? Colors.blue : (canCheckAnswer ? Colors.blue : Colors.grey),
                foregroundColor: Colors.white,
              ),
              child: Text(
                canGoNext 
                  ? (_currentExerciseIndex == _shuffledExercises.length - 1 ? 'Finish' : 'Next')
                  : 'Check Answer'
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAnswer() async {
    final currentExercise = _shuffledExercises[_currentExerciseIndex];
    bool isCorrect;
    
    if (currentExercise.type == ExerciseType.sentenceBuilding) {
      // Allow flexible placement for duplicate function words
      final correctWords = currentExercise.correctAnswer.split(' ');
      isCorrect = SentenceUtils.equalsWithFlexibleDuplicates(_answerWords, correctWords);
    } else {
      // For other exercise types, check if the selected answer is the correct one
      // Find the correct answer in the shuffled options
      final options = _shuffledOptions[_currentExerciseIndex] ?? currentExercise.options;
      final originalCorrectIndex = int.tryParse(currentExercise.correctAnswer) ?? 0;
      final originalCorrectAnswer = currentExercise.options[originalCorrectIndex];
      isCorrect = _selectedAnswer == originalCorrectAnswer;
    }
    
    // Update learning progress for the word exercise
    final wordExerciseId = _exerciseToWordExerciseId[_currentExerciseIndex];
    final dutchProvider = context.read<DutchWordExerciseProvider>();
    final flashcardProvider = context.read<FlashcardProvider>();
    print('🔍 Updating learning progress for word exercise ID: $wordExerciseId, wasCorrect: $isCorrect');
    await dutchProvider.updateLearningProgress(wordExerciseId, isCorrect);
    print('🔍 Learning progress updated successfully');
    
    // Get the card BEFORE syncing to capture initial HP before it's reduced
    final wordExercise = dutchProvider.wordExercises.firstWhere(
      (exercise) => exercise.id == wordExerciseId,
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
    
    FlashCard? cardBeforeSync;
    if (wordExercise.id.isNotEmpty) {
      cardBeforeSync = flashcardProvider.cards.firstWhere(
        (card) => card.word.toLowerCase() == wordExercise.targetWord.toLowerCase(),
        orElse: () => FlashCard(id: '', word: '', definition: '', example: ''),
      );
      
      // Track initial HP BEFORE syncing (so we capture HP before it's reduced)
      if (cardBeforeSync.id.isNotEmpty && !_studiedWords.any((word) => word.id == cardBeforeSync!.id)) {
        _studiedWords.add(cardBeforeSync);
        _initialHPPerWord[cardBeforeSync.id] = cardBeforeSync.currentHP;
      }
    }
    
    // Sync progress to main FlashCard and get updated card
    final updatedCard = await _syncProgressToFlashCard(wordExerciseId, isCorrect);
    
    // Award XP to word for RPG system and track progress
    if (isCorrect && updatedCard != null) {
      await _awardXPToWord(updatedCard, wordExerciseId);
    } else if (updatedCard != null) {
      // Track incorrect answers too
      _trackWordProgress(updatedCard, isCorrect);
    }
    
    // Force refresh of providers to ensure UI updates
    dutchProvider.notifyListeners();
    flashcardProvider.notifyListeners();
    
    setState(() {
      _showAnswer = true;
      _isCorrect = isCorrect;
      if (isCorrect) {
        _correctAnswers++;
      }
      _totalAnswered++;
      
      // Save the answer state
      _answeredQuestions[_currentExerciseIndex] = true;
      _selectedAnswers[_currentExerciseIndex] = _selectedAnswer;
      _sentenceAnswers[_currentExerciseIndex] = List<String>.from(_answerWords);
      _sentenceAvailable[_currentExerciseIndex] = List<String>.from(_availableWords);
    });
  }

  void _nextExercise() {
    if (_currentExerciseIndex < _shuffledExercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _loadExerciseState();
        _initializeShuffledOptions(_currentExerciseIndex, _shuffledExercises[_currentExerciseIndex]);
      });
    } else {
      _showCompletionDialog();
    }
  }

  Future<FlashCard?> _syncProgressToFlashCard(String wordExerciseId, bool wasCorrect) async {
    try {
      final dutchProvider = context.read<DutchWordExerciseProvider>();
      final flashcardProvider = context.read<FlashcardProvider>();
      
      // Find the word exercise
      final wordExercise = dutchProvider.wordExercises.firstWhere(
        (exercise) => exercise.id == wordExerciseId,
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
      
      if (wordExercise.id.isEmpty) {
        print('🔍 Word exercise not found for ID: $wordExerciseId');
        _lastSyncedCardId = null;
        _lastSyncAppliedHpPenalty = false;
        return null;
      }
      
      // Find the corresponding FlashCard
      final flashCard = flashcardProvider.cards.firstWhere(
        (card) => card.word.toLowerCase() == wordExercise.targetWord.toLowerCase(),
        orElse: () => FlashCard(
          id: '',
          word: '',
          definition: '',
          example: '',
        ),
      );
      
      if (flashCard.id.isEmpty) {
        print('🔍 FlashCard not found for word: ${wordExercise.targetWord}');
        _lastSyncedCardId = null;
        _lastSyncAppliedHpPenalty = false;
        return null;
      }
      
      // Update the FlashCard's learning progress
      final updatedCard = flashCard.copyWith(
        learningMastery: flashCard.learningMastery.copyWith(),
      );
      
      final xpService = XpService();
      bool shouldApplyHpPenalty = false;
      if (flashCard.id.isNotEmpty && !_hpPenaltyAppliedWordIds.contains(flashCard.id)) {
        _hpPenaltyAppliedWordIds.add(flashCard.id);
        shouldApplyHpPenalty = true;
      }
      
      _lastSyncedCardId = flashCard.id;
      _lastSyncAppliedHpPenalty = shouldApplyHpPenalty;
      
      if (wasCorrect) {
        if (shouldApplyHpPenalty) {
          updatedCard.markCorrect(GameDifficulty.medium);
        }
        // When HP already applied earlier, still grant XP without extra attempts
        if (!shouldApplyHpPenalty) {
          xpService.addXPToWordWithoutRecordingAttempt(
            updatedCard.learningMastery,
            'dutch_word_exercise',
            1,
          );
        }
      } else {
        if (shouldApplyHpPenalty) {
          updatedCard.markIncorrect(GameDifficulty.medium);
        } else {
          // Skip additional attempt records to avoid duplicate HP loss
        }
      }
      
      await flashcardProvider.updateCard(updatedCard);
      print('🔍 Progress synced to FlashCard: ${flashCard.word} - timesShown: ${updatedCard.timesShown}, timesCorrect: ${updatedCard.timesCorrect}');
      print('🔍 FlashCard learning percentage: ${updatedCard.learningPercentage}%');
      
      // Also check the DutchWordExercise percentage for comparison
      final dutchExercise = dutchProvider.wordExercises.firstWhere(
        (exercise) => exercise.id == wordExerciseId,
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
      if (dutchExercise.id.isNotEmpty) {
        print('🔍 DutchWordExercise learning percentage: ${dutchExercise.learningProgress.learningPercentage}%');
      }
      
      return updatedCard;
    } catch (e) {
      print('🔍 Error syncing progress to FlashCard: $e');
      return null;
    }
  }

  void _showCompletionDialog() {
    final percentage = (_correctAnswers / _totalAnswered * 100).round();
    final totalXPGained = _xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp);
    
    // Award profile XP based on actual word XP gained
    if (totalXPGained > 0) {
      final userProfileProvider = context.read<UserProfileProvider>();
      userProfileProvider.addXp(totalXPGained);
    }
    
    // Go directly to word XP end screen instead of showing dialog
    _showWordProgress();
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Practice?'),
        content: const Text('Are you sure you want to end this practice session?'),
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
            child: const Text('End Practice'),
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
        content: const Text('Are you sure you want to return to the home screen? This will end your current practice session.'),
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
  
  Future<void> _awardXPToWord(FlashCard card, String wordExerciseId) async {
    try {
      // Get the current exercise to determine the exercise type (for logging only)
      final currentExercise = _shuffledExercises[_currentExerciseIndex];
      final exerciseType = _getExerciseTypeString(currentExercise.type);
      
      print('🔍 DutchWordsPracticeView: Exercise type: $exerciseType');
      print('🔍 DutchWordsPracticeView: Daily attempts (post-sync): ${card.learningMastery.dailyGameAttempts}');
      
      // Get the actual XP gained (after diminishing returns)
      final actualXPGained = card.learningMastery.exerciseHistory.isNotEmpty 
          ? card.learningMastery.exerciseHistory.last['xpGained'] as int 
          : 0;
      
      // Track XP gained for this word in this session (replace for multiple appearances in same session)
      _xpGainedPerWord[card.id] = actualXPGained;
      
      // Track word progress (mastery tracking)
      _trackWordProgress(card, true);
      
      print('🔍 DutchWordsPracticeView: Recorded $actualXPGained XP for word "${card.word}"');
      
      // Update the card in the provider to persist XP changes
      final flashcardProvider = context.read<FlashcardProvider>();
      await flashcardProvider.updateCard(card);
      
    } catch (e) {
      print('🔍 DutchWordsPracticeView: Error awarding XP: $e');
    }
  }
  
  void _trackWordProgress(FlashCard card, bool isCorrect) {
    // Store the word mastery for display (use the card's current mastery which has latest HP)
    _wordMastery[card.id] = card.learningMastery;
    
    // For incorrect answers, explicitly set 0 XP
    if (!isCorrect) {
      _xpGainedPerWord[card.id] = 0;
    }
  }
  
  void _showWordProgress() {
    // Create copies of the current session data for the display
    final sessionStudiedWords = List<FlashCard>.from(_studiedWords);
    final sessionXpGainedPerWord = Map<String, int>.from(_xpGainedPerWord);
    final sessionWordMastery = Map<String, LearningMastery>.from(_wordMastery);
    final sessionInitialHPPerWord = Map<String, int>.from(_initialHPPerWord);
    
    GameEndScreen.show(
      context,
      GameEndResult(
        title: 'Word Progress',
        studiedWords: sessionStudiedWords,
        xpGainedPerWord: sessionXpGainedPerWord,
        wordMastery: sessionWordMastery,
        initialHPPerWord: sessionInitialHPPerWord,
        correctAnswers: _correctAnswers,
        totalQuestions: _totalAnswered,
        onStudyAgain: () async {
          Navigator.of(context).pop();
          setState(() {
            _currentExerciseIndex = 0;
            _selectedAnswer = null;
            _showAnswer = false;
            _correctAnswers = 0;
            _totalAnswered = 0;
            _answerWords = [];
            _availableWords = [];
            _shuffledOptions.clear();
            _answeredQuestions.clear();
            _selectedAnswers.clear();
            _sentenceAnswers.clear();
            _sentenceAvailable.clear();
            
            _xpGainedPerWord.clear();
            _wordMastery.clear();
            _initialHPPerWord.clear();
            _studiedWords.clear();
            _hpPenaltyAppliedWordIds.clear();
            _lastSyncedCardId = null;
            _lastSyncAppliedHpPenalty = false;
            
            _initializePractice(shuffle: false);
          });
        },
        onShuffle: () {
          Navigator.of(context).pop();
          _shuffleAndRestart();
        },
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }
  
  /// Convert ExerciseType enum to string for XP service
  String _getExerciseTypeString(ExerciseType type) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return 'multiple_choice';
      case ExerciseType.fillInBlank:
        return 'fill_in_blank';
      case ExerciseType.sentenceBuilding:
        return 'sentence_building';
    }
  }
}