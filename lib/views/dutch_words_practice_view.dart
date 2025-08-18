import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dutch_word_exercise.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/flashcard_provider.dart';
import '../models/flash_card.dart';


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

  @override
  void initState() {
    super.initState();
    _initializePractice();
  }

  void _initializePractice() {
    // Collect all exercises from all words in the deck with their word exercise IDs
    final List<MapEntry<WordExercise, String>> exerciseEntries = [];
    
    for (final wordExercise in widget.exercises) {
      for (final exercise in wordExercise.exercises) {
        exerciseEntries.add(MapEntry(exercise, wordExercise.id));
      }
    }
    
    // Shuffle the entries
    exerciseEntries.shuffle();
    
    // Extract the shuffled exercises and their corresponding word exercise IDs
    _allExercises = exerciseEntries.map((entry) => entry.key).toList();
    _shuffledExercises = List<WordExercise>.from(_allExercises);
    _exerciseToWordExerciseId = exerciseEntries.map((entry) => entry.value).toList();
    
    // Initialize first exercise
    if (_shuffledExercises.isNotEmpty) {
      _initializeShuffledOptions(0, _shuffledExercises[0]);
    }
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
      appBar: AppBar(
        title: Text('Practice: ${widget.deckName}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Exercise content
          Expanded(
            child: _buildExerciseContent(currentExercise),
          ),
          
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Exercise ${_currentExerciseIndex + 1} of ${_shuffledExercises.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Score: $_correctAnswers/$_totalAnswered',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentExerciseIndex + 1) / _shuffledExercises.length,
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
      children: options.map((option) {
        final isSelected = _selectedAnswer == option;
        final isCorrect = option == exercise.correctAnswer;
        final showCorrect = _showAnswer && isCorrect;
        final showIncorrect = _showAnswer && isSelected && !isCorrect;
        
        Color backgroundColor = Colors.white;
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
                      child: SelectableText(
                        option,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.left,
                        enableInteractiveSelection: true,
                        showCursor: false,
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
          'Arrange the words to form the correct sentence:',
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
            children: _buildAnswerWords(_answerWords),
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

  List<Widget> _buildAnswerWords(List<String> words) {
    return words.map((word) {
      return GestureDetector(
        onTap: () => _moveWordToAvailable(word),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.5)),
          ),
          child: Text(
            word,
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
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
      if (exercise.type == ExerciseType.multipleChoice || exercise.type == ExerciseType.fillInBlank) {
        final shuffledOptions = List<String>.from(exercise.options);
        shuffledOptions.shuffle();
        _shuffledOptions[questionIndex] = shuffledOptions;
      } else {
        _shuffledOptions[questionIndex] = exercise.options;
      }
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      'Correct answer: ${exercise.correctAnswer}',
                      style: TextStyle(
                        fontSize: 14,
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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentExerciseIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentExerciseIndex--;
                    _loadExerciseState();
                  });
                },
                child: const Text('Previous'),
              ),
            ),
          
          if (_currentExerciseIndex > 0) const SizedBox(width: 12),
          
          Expanded(
            child: ElevatedButton(
              onPressed: _canCheckAnswer() ? () {
                if (!_showAnswer) {
                  _checkAnswer();
                } else {
                  _nextExercise();
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(_showAnswer ? 'Next' : 'Check Answer'),
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
      // For sentence building, check if the answer words form the correct sentence
      final userAnswer = _answerWords.join(' ');
      isCorrect = userAnswer == currentExercise.correctAnswer;
    } else {
      // For other exercise types, check the selected answer
      isCorrect = _selectedAnswer == currentExercise.correctAnswer;
    }
    
    // Update learning progress for the word exercise
    final wordExerciseId = _exerciseToWordExerciseId[_currentExerciseIndex];
    final dutchProvider = context.read<DutchWordExerciseProvider>();
    final flashcardProvider = context.read<FlashcardProvider>();
    print('🔍 Updating learning progress for word exercise ID: $wordExerciseId, wasCorrect: $isCorrect');
    await dutchProvider.updateLearningProgress(wordExerciseId, isCorrect);
    print('🔍 Learning progress updated successfully');
    
    // Sync progress to main FlashCard
    await _syncProgressToFlashCard(wordExerciseId, isCorrect);
    
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

  Future<void> _syncProgressToFlashCard(String wordExerciseId, bool wasCorrect) async {
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
        return;
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
        return;
      }
      
      // Update the FlashCard's learning progress
      final updatedCard = FlashCard(
        id: flashCard.id,
        word: flashCard.word,
        definition: flashCard.definition,
        example: flashCard.example,
        deckIds: flashCard.deckIds,
        successCount: flashCard.successCount,
        dateCreated: flashCard.dateCreated,
        lastModified: DateTime.now(),
        cloudKitRecordName: flashCard.cloudKitRecordName,
        timesShown: flashCard.timesShown + 1,
        timesCorrect: flashCard.timesCorrect + (wasCorrect ? 1 : 0),
        srsLevel: flashCard.srsLevel,
        nextReviewDate: flashCard.nextReviewDate,
        consecutiveCorrect: wasCorrect ? flashCard.consecutiveCorrect + 1 : 0,
        consecutiveIncorrect: wasCorrect ? 0 : flashCard.consecutiveIncorrect + 1,
        easeFactor: flashCard.easeFactor,
        lastReviewDate: DateTime.now(),
        totalReviews: flashCard.totalReviews + 1,
        article: flashCard.article,
        plural: flashCard.plural,
        pastTense: flashCard.pastTense,
        futureTense: flashCard.futureTense,
        pastParticiple: flashCard.pastParticiple,
      );
      
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
    } catch (e) {
      print('🔍 Error syncing progress to FlashCard: $e');
    }
  }

  void _showCompletionDialog() {
    final percentage = (_correctAnswers / _totalAnswered * 100).round();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Practice Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You got $_correctAnswers out of $_totalAnswered correct'),
            const SizedBox(height: 8),
            Text('Score: $percentage%'),
            const SizedBox(height: 16),
            if (percentage >= 80)
              const Text(
                'Excellent! You know this deck well!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              )
            else if (percentage >= 60)
              const Text(
                'Good job! Keep practicing!',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              )
            else
              const Text(
                'Keep studying this deck!',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
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
          ElevatedButton(
            onPressed: () {
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
                _initializePractice();
              });
            },
            child: const Text('Practice Again'),
          ),
        ],
      ),
    );
  }


} 