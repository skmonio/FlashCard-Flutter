import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dutch_word_exercise.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/flashcard_provider.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../services/xp_service.dart';

import '../utils/sentence_utils.dart';

import 'create_word_exercise_view.dart';
import '../components/word_progress_display.dart';

class DutchWordExerciseDetailView extends StatefulWidget {
  final DutchWordExercise wordExercise;
  final bool showEditDeleteButtons;
  final Function(bool)? onComplete;
  final bool singleQuestionMode;
  final int? shuffleQuestionOffset; // Offset for cumulative question count in shuffle mode

  const DutchWordExerciseDetailView({
    super.key,
    required this.wordExercise,
    this.showEditDeleteButtons = true,
    this.onComplete,
    this.singleQuestionMode = false,
    this.shuffleQuestionOffset,
  });

  @override
  State<DutchWordExerciseDetailView> createState() => _DutchWordExerciseDetailViewState();
}

class _DutchWordExerciseDetailViewState extends State<DutchWordExerciseDetailView> {
  int _currentExerciseIndex = 0;
  String? _selectedAnswer;
  bool _showAnswer = false;
  bool _isCorrect = false;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  
  // Current word exercise (updated from provider)
  late DutchWordExercise _wordExercise;
  
  // Track if exercise data has changed to reset state
  String _lastExerciseDataHash = '';
  
  // Shuffled options for multiple choice questions
  Map<int, List<String>> _shuffledOptions = {};
  
  // Sentence building state
  List<String> _answerWords = [];
  List<String> _availableWords = [];
  
  // Track answered questions
  Map<int, bool> _answeredQuestions = {};
  Map<int, String?> _selectedAnswers = {};
  Map<int, List<String>> _sentenceAnswers = {};
  Map<int, List<String>> _sentenceAvailable = {};
  Map<int, bool> _correctAnswersMap = {}; // Track correctness for each question
  
  // RPG tracking for comprehensive completion screen
  Map<String, int> _xpGainedPerWord = {};
  Map<String, LearningMastery> _wordMastery = {};
  List<FlashCard> _studiedWords = [];

  @override
  Widget build(BuildContext context) {
    // Get the latest word exercise from provider using word name instead of ID
    final provider = context.watch<DutchWordExerciseProvider>();
    _wordExercise = provider.getWordExerciseByWord(widget.wordExercise.targetWord) ?? widget.wordExercise;
    
    // Debug logging
    print('🔍 DutchWordExerciseDetailView: Displaying word "${_wordExercise.targetWord}" with ${_wordExercise.exercises.length} exercises');
    for (int i = 0; i < _wordExercise.exercises.length; i++) {
      final exercise = _wordExercise.exercises[i];
      print('🔍 DutchWordExerciseDetailView: Exercise $i - Type: ${exercise.type}, Prompt: "${exercise.prompt}", Correct: "${exercise.correctAnswer}"');
    }
    
    // Check if exercise data has changed and reset state if needed
    _checkAndResetStateIfNeeded();
    
    final currentExercise = _wordExercise.exercises[_currentExerciseIndex];
    
    // Initialize shuffled options for this question if not already done
    _initializeShuffledOptions(_currentExerciseIndex, currentExercise);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Fixed Header - matching Taal Trek header height
          SafeArea(
            child: Container(
              height: kToolbarHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: _buildCustomHeader(context),
            ),
          ),
          
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
    
    // In shuffle mode (singleQuestionMode), show cumulative question count (e.g., 1/1, 2/2, 3/3...)
    final String questionCountText;
    if (widget.singleQuestionMode && widget.shuffleQuestionOffset != null) {
      final currentQuestionNum = (widget.shuffleQuestionOffset ?? 0) + 1;
      questionCountText = '$currentQuestionNum/$currentQuestionNum';
    } else {
      questionCountText = '${_currentExerciseIndex + 1}/${_wordExercise.exercises.length}';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                questionCountText,
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
            value: _currentExerciseIndex / _wordExercise.exercises.length,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildWordHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Colors.green.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.green,
            child: Text(
              _wordExercise.targetWord[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _wordExercise.targetWord,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _wordExercise.wordTranslation,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildChip(
                      _wordExercise.category.toString().split('.').last,
                      _getCategoryColor(_wordExercise.category),
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      _wordExercise.difficulty.toString().split('.').last,
                      _getDifficultyColor(_wordExercise.difficulty),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseContent(WordExercise exercise) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          
          // Exercise prompt
          SelectableText(
            exercise.prompt,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.left,
            enableInteractiveSelection: true,
            showCursor: false,
          ),
          
          const SizedBox(height: 24),
          
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Answer options
                  _buildAnswerOptions(exercise),
                  
                  // Answer feedback
                  if (_showAnswer) _buildAnswerFeedback(exercise),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerOptions(WordExercise exercise) {
    if (exercise.type == ExerciseType.fillInBlank) {
      return _buildFillInBlankOptions(exercise);
    } else if (exercise.type == ExerciseType.sentenceBuilding) {
      return _buildSentenceBuildingOptions(exercise);
    } else {
      return _buildMultipleChoiceOptions(exercise);
    }
  }

  Widget _buildFillInBlankOptions(WordExercise exercise) {
    return Column(
      children: exercise.options.map((option) {
        final isSelected = _selectedAnswer == option;
        final isCorrect = option == exercise.correctAnswer;
        final showCorrect = _showAnswer && isCorrect;
        final showIncorrect = _showAnswer && isSelected && !isCorrect;
        
        Color backgroundColor = Theme.of(context).colorScheme.surface;
        Color borderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
        
        if (showCorrect) {
          backgroundColor = Colors.green.withValues(alpha: 0.1);
          borderColor = Colors.green;
        } else if (showIncorrect) {
          backgroundColor = Colors.red.withValues(alpha: 0.1);
          borderColor = Colors.red;
        } else if (isSelected) {
          backgroundColor = Colors.blue.withValues(alpha: 0.1);
          borderColor = Colors.blue;
        }
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showAnswer ? null : () => _selectAnswer(option, exercise),
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
        Color borderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
        
        if (showCorrect) {
          backgroundColor = Colors.green.withValues(alpha: 0.1);
          borderColor = Colors.green;
        } else if (showIncorrect) {
          backgroundColor = Colors.red.withValues(alpha: 0.1);
          borderColor = Colors.red;
        } else if (isSelected) {
          backgroundColor = Colors.blue.withValues(alpha: 0.1);
          borderColor = Colors.blue;
        }
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showAnswer ? null : () => _selectAnswer(option, exercise),
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
    } else if (_availableWords.isEmpty && _answerWords.isEmpty) {
      // Initialize fresh state for sentence building only if not already initialized
      List<String> wordsToShuffle;
      if (exercise.type == ExerciseType.sentenceBuilding) {
        // For sentence building, use the options (individual words)
        wordsToShuffle = List<String>.from(exercise.options);
      } else {
        // For other exercise types, split the correct answer
        wordsToShuffle = exercise.correctAnswer.split(' ');
      }
      
      // Always regenerate shuffled options for fresh state
      _shuffledOptions[_currentExerciseIndex] = List<String>.from(wordsToShuffle)..shuffle();
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
            color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Words:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
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
      // Shuffle options in study mode so correct answer isn't always first
      _shuffledOptions[questionIndex] = List<String>.from(exercise.options)..shuffle();
    }
  }

  bool _canCheckAnswer() {
    final currentExercise = _wordExercise.exercises[_currentExerciseIndex];
    
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
      _isCorrect = _correctAnswersMap[_currentExerciseIndex] ?? false; // Load stored correctness
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
    final currentExercise = _wordExercise.exercises[_currentExerciseIndex];
    final isSentenceBuilding = currentExercise.type == ExerciseType.sentenceBuilding;
    
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
              onPressed: isSentenceBuilding ? (_canCheckAnswer() ? () {
                if (!_showAnswer) {
                  _checkAnswer();
                } else {
                  _nextExercise();
                }
              } : null) : () {
                _nextExercise();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isSentenceBuilding ? (_canCheckAnswer() ? Colors.green : Colors.grey) : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                isSentenceBuilding 
                  ? (_showAnswer ? 'Next' : 'Check Answer')
                  : (_currentExerciseIndex == _wordExercise.exercises.length - 1 ? 'Finish' : 'Next')
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAnswer() async {
    final currentExercise = _wordExercise.exercises[_currentExerciseIndex];
    
    // Debug logging
    print('🔍 DutchWordExerciseDetailView: Checking answer for word "${_wordExercise.targetWord}", exercise $_currentExerciseIndex');
    print('🔍 DutchWordExerciseDetailView: Exercise prompt: "${currentExercise.prompt}"');
    print('🔍 DutchWordExerciseDetailView: Correct answer: "${currentExercise.correctAnswer}"');
    if (currentExercise.type == ExerciseType.sentenceBuilding) {
      print('🔍 DutchWordExerciseDetailView: Answer words: ${_answerWords.join(' ')}');
    } else {
      print('🔍 DutchWordExerciseDetailView: Selected answer: "$_selectedAnswer"');
    }
    
    bool isCorrect = false;
    
    if (currentExercise.type == ExerciseType.sentenceBuilding) {
      // Allow flexible placement for duplicate function words
      final correctWords = currentExercise.correctAnswer.split(' ');
      isCorrect = SentenceUtils.equalsWithFlexibleDuplicates(_answerWords, correctWords);
    } else {
      // For multiple choice and fill in blank, check if the selected answer matches the correct answer
      // The correctAnswer field contains the index (as string) of the correct option in the original options
      final options = _shuffledOptions[_currentExerciseIndex] ?? currentExercise.options;
      final originalCorrectIndex = int.tryParse(currentExercise.correctAnswer) ?? 0;
      // Get the actual correct answer value from the original options
      final originalCorrectAnswer = currentExercise.options[originalCorrectIndex];
      // Find the correct answer in the shuffled options and check if the selected answer matches it
      final shuffledCorrectIndex = options.indexOf(originalCorrectAnswer);
      isCorrect = _selectedAnswer != null && options.indexOf(_selectedAnswer!) == shuffledCorrectIndex;
    }
    
    // Update learning progress for the word exercise
    final dutchProvider = context.read<DutchWordExerciseProvider>();
    await dutchProvider.updateLearningProgress(_wordExercise.id, isCorrect);
    
    // Sync progress to main FlashCard
    await _syncProgressToFlashCard(isCorrect);
    
    // Track studied words and XP for comprehensive completion screen
    _trackExerciseProgress(isCorrect);
    
    // Force refresh of providers to ensure UI updates
    dutchProvider.notifyListeners();
    final flashcardProvider = context.read<FlashcardProvider>();
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
      _correctAnswersMap[_currentExerciseIndex] = isCorrect; // Store correctness value
    });
  }

  Future<void> _syncProgressToFlashCard(bool wasCorrect) async {
    try {
      final dutchProvider = context.read<DutchWordExerciseProvider>();
      final flashcardProvider = context.read<FlashcardProvider>();
      
      // Find the corresponding FlashCard
      final flashCard = flashcardProvider.cards.firstWhere(
        (card) => card.word.toLowerCase() == _wordExercise.targetWord.toLowerCase(),
        orElse: () => FlashCard(
          id: '',
          word: '',
          definition: '',
          example: '',
        ),
      );
      
      if (flashCard.id.isEmpty) {
        print('🔍 FlashCard not found for word: ${_wordExercise.targetWord}');
        return;
      }
      
      // Update the FlashCard's learning progress
      final updatedCard = flashCard.copyWith(
        learningMastery: flashCard.learningMastery.copyWith(),
      );
      
      // Update learning mastery based on difficulty (assuming medium for exercises)
      final xpService = XpService();
      
      if (wasCorrect) {
        updatedCard.markCorrect(GameDifficulty.medium);
        
        // Award XP using standard system (only if not in shuffle mode - shuffle mode handles XP separately)
        if (!widget.singleQuestionMode) {
          xpService.addXPToWord(updatedCard.learningMastery, 'dutch_word_exercise_detail', 1);
        }
      } else {
        updatedCard.markIncorrect(GameDifficulty.medium);
        
        // In shuffle mode (singleQuestionMode), reduce HP for incorrect answers
        if (widget.singleQuestionMode) {
          xpService.recordAttemptToWord(updatedCard.learningMastery, 'dutch_word_exercise_detail');
        }
      }
      
      await flashcardProvider.updateCard(updatedCard);
      print('🔍 Progress synced to FlashCard: ${flashCard.word} - timesShown: ${updatedCard.timesShown}, timesCorrect: ${updatedCard.timesCorrect}');
      print('🔍 FlashCard learning percentage: ${updatedCard.learningPercentage}%');
      print('🔍 DutchWordExercise learning percentage: ${widget.wordExercise.learningProgress.learningPercentage}%');
    } catch (e) {
      print('🔍 Error syncing progress to FlashCard: $e');
    }
  }
  
  void _trackExerciseProgress(bool wasCorrect) {
    // Find the corresponding FlashCard for tracking
    final flashcardProvider = context.read<FlashcardProvider>();
    final flashCard = flashcardProvider.cards.firstWhere(
      (card) => card.word.toLowerCase() == _wordExercise.targetWord.toLowerCase(),
      orElse: () => FlashCard(
        id: '',
        word: '',
        example: '',
        definition: '',
      ),
    );
    
    if (flashCard.id.isNotEmpty) {
      // Track studied words
      if (!_studiedWords.any((word) => word.id == flashCard.id)) {
        _studiedWords.add(flashCard);
      }
      
      // Track word mastery
      _wordMastery[flashCard.id] = flashCard.learningMastery;
      
      // Track XP gained (with daily decay applied)
      if (wasCorrect) {
        // Get the actual XP gained from the exercise history
        final actualXPGained = flashCard.learningMastery.exerciseHistory.isNotEmpty 
            ? flashCard.learningMastery.exerciseHistory.last['xpGained'] as int 
            : 0;
        _xpGainedPerWord[flashCard.id] = actualXPGained;
      }
    }
  }

  void _nextExercise() {
    // In single question mode, call the callback immediately after the first question
    if (widget.singleQuestionMode && widget.onComplete != null) {
      // Use the stored correctness value to ensure consistency
      final isCorrect = _correctAnswersMap[_currentExerciseIndex] ?? false;
      widget.onComplete!(isCorrect);
      return;
    }
    
    if (_currentExerciseIndex < _wordExercise.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _loadExerciseState();
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final percentage = (_correctAnswers / _totalAnswered * 100).round();
    final wasSuccessful = percentage >= 60; // Consider it successful if 60% or higher
    
    // Call callback if provided (for single question mode)
    if (widget.singleQuestionMode && widget.onComplete != null) {
      widget.onComplete!(wasSuccessful);
      return;
    }
    
    // Show comprehensive completion screen
    _showComprehensiveCompletionScreen();
  }
  
  void _showComprehensiveCompletionScreen() {
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
          hideNavigation: true, // Hide back button and swipe for word exercises
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close word progress screen
            // Reset and restart exercise
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
              
              // Reset RPG tracking
              _xpGainedPerWord.clear();
              _wordMastery.clear();
              _studiedWords.clear();
            });
          },
          onDone: () {
            Navigator.of(context).pop(); // Close word progress screen
            Navigator.of(context).pop(); // Go back to study type screen
          },
        ),
      ),
    );
  }

  void _checkAndResetStateIfNeeded() {
    // Generate a hash of the current exercise data
    final currentHash = _generateExerciseDataHash();
    
    // If the hash has changed, reset the state
    if (currentHash != _lastExerciseDataHash) {
      _resetExerciseState();
      _lastExerciseDataHash = currentHash;
    }
  }
  
  String _generateExerciseDataHash() {
    // Create a simple hash of the exercise data to detect changes
    final exerciseData = _wordExercise.exercises.map((e) => 
      '${e.prompt}|${e.correctAnswer}|${e.options.join(',')}'
    ).join('||');
    return exerciseData;
  }
  
  void _resetExerciseState() {
    // Reset all exercise state when data changes
    _selectedAnswer = null;
    _showAnswer = false;
    _isCorrect = false;
    _answerWords.clear();
    _availableWords.clear();
    _shuffledOptions.clear();
    _answeredQuestions.clear();
    _selectedAnswers.clear();
    _sentenceAnswers.clear();
    _sentenceAvailable.clear();
    
    // Reset RPG tracking
    _xpGainedPerWord.clear();
    _wordMastery.clear();
    _studiedWords.clear();
  }

  void _showDeleteWordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word'),
        content: Text(
          'Are you sure you want to delete "${_wordExercise.targetWord}"?\n\n'
          'This will permanently delete ${_wordExercise.exercises.length} exercises.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteWord();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _editWordExercise(context);
        break;
      case 'delete':
        _showDeleteWordDialog(context);
        break;
      case 'info':
        _showWordInfo(context);
        break;
    }
  }

  void _deleteWord() {
    final provider = context.read<DutchWordExerciseProvider>();
    provider.deleteWordExercise(_wordExercise.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${_wordExercise.targetWord}" deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Navigate back to the previous screen
    Navigator.of(context).pop();
  }

  void _editWordExercise(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateWordExerciseView(
          editingExercise: _wordExercise,
        ),
      ),
    ).then((_) {
      // Refresh the view when returning from edit
      setState(() {});
    });
  }

  void _showWordInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_wordExercise.targetWord),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Translation: ${_wordExercise.wordTranslation}'),
            const SizedBox(height: 8),
            Text('Category: ${_wordExercise.category.toString().split('.').last}'),
            const SizedBox(height: 8),
            Text('Difficulty: ${_wordExercise.difficulty.toString().split('.').last}'),
            const SizedBox(height: 8),
            Text('Total Exercises: ${_wordExercise.exercises.length}'),
            const SizedBox(height: 8),
            Text('Created: ${_wordExercise.createdAt.toString().split(' ')[0]}'),
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

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getCategoryColor(WordCategory category) {
    switch (category) {
      case WordCategory.common:
        return Colors.blue;
      case WordCategory.business:
        return Colors.green;
      case WordCategory.academic:
        return Colors.purple;
      case WordCategory.casual:
        return Colors.orange;
      case WordCategory.formal:
        return Colors.indigo;
      case WordCategory.technical:
        return Colors.red;
      case WordCategory.cultural:
        return Colors.teal;
      case WordCategory.other:
        return Colors.grey;
    }
  }

  Color _getDifficultyColor(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.beginner:
        return Colors.green;
      case ExerciseDifficulty.intermediate:
        return Colors.orange;
      case ExerciseDifficulty.advanced:
        return Colors.red;
    }
  }

  String _getExerciseTypeName(ExerciseType type) {
    switch (type) {
      case ExerciseType.fillInBlank:
        return 'Fill in the Blank';
      case ExerciseType.sentenceBuilding:
        return 'Sentence Building';
      case ExerciseType.multipleChoice:
        return 'Multiple Choice';
    }
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Exercise?'),
        content: const Text('Are you sure you want to end this exercise?'),
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
            child: const Text('End Exercise'),
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
        content: const Text('Are you sure you want to return to the home screen? This will end your current exercise.'),
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

  void _selectAnswer(String option, WordExercise exercise) {
    if (_showAnswer) return; // Don't allow changes after answering
    
    setState(() {
      _selectedAnswer = option;
    });
    
    // Use the proper answer checking method
    _checkAnswer();
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            'Exercise',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        
        // Left side - Back button with proper padding
        Positioned(
          left: 16, // Add proper padding from left edge
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () => _showCloseConfirmation(),
            icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        
        // Right side - Home button
        Positioned(
          right: 16, // Add proper padding from right edge
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () => _showHomeConfirmation(),
            icon: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
            tooltip: 'Go Home',
          ),
        ),
      ],
    );
  }
} 