import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/phrase.dart';
import '../providers/phrase_provider.dart';

class PhraseExerciseDetailView extends StatefulWidget {
  final Phrase phrase;
  final bool showEditDeleteButtons;
  final Function(bool)? onComplete;
  final bool singleQuestionMode;

  const PhraseExerciseDetailView({
    super.key,
    required this.phrase,
    this.showEditDeleteButtons = true,
    this.onComplete,
    this.singleQuestionMode = false,
  });

  @override
  State<PhraseExerciseDetailView> createState() => _PhraseExerciseDetailViewState();
}

class _PhraseExerciseDetailViewState extends State<PhraseExerciseDetailView> {
  int _currentExerciseIndex = 0;
  String? _selectedAnswer;
  bool _showAnswer = false;
  bool _isCorrect = false;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  
  // Current phrase (updated from provider)
  late Phrase _phrase;
  
  // Track if phrase data has changed to reset state
  String _lastPhraseDataHash = '';
  
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
  
  // Cache generated exercises to prevent regeneration
  List<Map<String, dynamic>>? _cachedExercises;

  @override
  Widget build(BuildContext context) {
    // Get the latest phrase from provider
    final provider = context.watch<PhraseProvider>();
    _phrase = provider.getPhraseById(widget.phrase.id) ?? widget.phrase;
    
    // Debug logging
    // print('🔍 PhraseExerciseDetailView: Displaying phrase "${_phrase.phrase}" with learning percentage: ${_phrase.learningPercentage}%');
    
    // Check if phrase data has changed and reset state if needed
    _checkAndResetStateIfNeeded();
    
    // Generate exercises for this phrase
    final exercises = _generateExercises();
    
    if (exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_phrase.phrase),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No exercises available for this phrase'),
        ),
      );
    }
    
    final currentExercise = exercises[_currentExerciseIndex];
    
    // Initialize shuffled options for this question if not already done
    _initializeShuffledOptions(_currentExerciseIndex, currentExercise);
    
    // Debug current state
    // print('🔍 Current state - Available: $_availableWords, Answer: $_answerWords, _showAnswer: $_showAnswer');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_phrase.phrase),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              if (widget.showEditDeleteButtons) ...[
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
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Progress bar
            _buildProgressBar(exercises.length),
            
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Exercise content
                  _buildExerciseContent(currentExercise),
                  
                  const SizedBox(height: 24),
                  
                  // Navigation buttons
                  _buildNavigationButtons(exercises.length),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int totalExercises) {
    final progress = _currentExerciseIndex / totalExercises;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Exercise ${_currentExerciseIndex + 1} of $totalExercises'),
              Text('${(progress * 100).toInt()}%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.school,
            color: Colors.teal,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learning Progress',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.teal[700],
                  ),
                ),
                Text(
                  '${_phrase.learningPercentage.toInt()}% learned',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseContent(Map<String, dynamic> exercise) {
    return Column(
      children: [
        // Question prompt
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                exercise['prompt'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                ),
                child: Text(
                  exercise['question'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Answer options
        _buildAnswerOptions(exercise),
      ],
    );
  }

  Widget _buildAnswerOptions(Map<String, dynamic> exercise) {
    if (exercise['type'] == 'multiple_choice') {
      return _buildMultipleChoiceOptions(exercise);
    } else if (exercise['type'] == 'sentence_builder') {
      return _buildSentenceBuilderOptions(exercise);
    }
    return const SizedBox.shrink();
  }

  Widget _buildMultipleChoiceOptions(Map<String, dynamic> exercise) {
    final options = _shuffledOptions[_currentExerciseIndex] ?? exercise['options'];
    
    return Column(
      children: options.map<Widget>((option) {
        final isSelected = _selectedAnswer == option;
        final isCorrect = option == exercise['correctAnswer'];
        final showCorrect = _showAnswer && isCorrect;
        final showIncorrect = _showAnswer && isSelected && !isCorrect;
        
        Color backgroundColor = Colors.white;
        Color borderColor = Colors.grey.withValues(alpha: 0.3);
        
        if (showCorrect) {
          backgroundColor = Colors.green.withValues(alpha: 0.1);
          borderColor = Colors.green;
        } else if (showIncorrect) {
          backgroundColor = Colors.red.withValues(alpha: 0.1);
          borderColor = Colors.red;
        } else if (isSelected) {
          backgroundColor = Colors.teal.withValues(alpha: 0.1);
          borderColor = Colors.teal;
        }
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showAnswer ? null : () => _selectAnswer(option),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + (options.indexOf(option) as int)),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: borderColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        option,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (showCorrect)
                      const Icon(Icons.check_circle, color: Colors.green, size: 24),
                    if (showIncorrect)
                      const Icon(Icons.cancel, color: Colors.red, size: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSentenceBuilderOptions(Map<String, dynamic> exercise) {
    return Column(
      children: [
        // Selected words
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Answer:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.teal[700],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _answerWords.map((word) => _buildWordChip(word, true)).toList(),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Available words (only show if there are words available)
        if (_availableWords.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Words:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableWords.map((word) => _buildWordChip(word, false)).toList(),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Check answer button
        if (!_showAnswer)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canCheckAnswer() ? _checkSentenceBuilderAnswer : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _getCheckAnswerButtonText(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWordChip(String word, bool isSelected) {
    // print('🔍 Building word chip: $word, isSelected: $isSelected, _showAnswer: $_showAnswer');
    
    // Determine colors based on state
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    
    if (_showAnswer && isSelected) {
      // Show correct/incorrect feedback for selected words when answer is shown
      final exercises = _generateExercises();
      final currentExercise = exercises[_currentExerciseIndex];
      final correctOrder = currentExercise['correctOrder'] as List<String>;
      final userAnswer = _answerWords.join(' ');
      final correctAnswer = correctOrder.join(' ');
      final isCorrect = userAnswer == correctAnswer;
      
      if (isCorrect) {
        backgroundColor = Colors.green.withOpacity(0.2);
        borderColor = Colors.green;
        textColor = Colors.green[700]!;
      } else {
        backgroundColor = Colors.red.withOpacity(0.2);
        borderColor = Colors.red;
        textColor = Colors.red[700]!;
      }
    } else if (isSelected) {
      backgroundColor = Colors.green.withOpacity(0.2);
      borderColor = Colors.green.withOpacity(0.5);
      textColor = Colors.green[700]!;
    } else {
      backgroundColor = Colors.blue.withOpacity(0.2);
      borderColor = Colors.blue.withOpacity(0.5);
      textColor = Colors.blue[700]!;
    }
    
    return GestureDetector(
      onTap: _showAnswer ? null : () {
        // print('🔍 GestureDetector tapped: $word, isSelected: $isSelected, _showAnswer: $_showAnswer');
        if (isSelected) {
          _handleSelectedWordTap(word);
        } else {
          _handleAvailableWordTap(word);
        }
      },
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
            if (_showAnswer && isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                _isCorrect ? Icons.check_circle : Icons.cancel,
                color: _isCorrect ? Colors.green : Colors.red,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }



  Widget _buildNavigationButtons(int totalExercises) {
    // Determine if we can go to next based on exercise type and answer status
    bool canGoNext = _showAnswer || _answeredQuestions[_currentExerciseIndex] == true;
    bool isLastQuestion = _currentExerciseIndex == totalExercises - 1;
    
    return Row(
      children: [
        // Previous button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _currentExerciseIndex > 0 ? _goToPrevious : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.withValues(alpha: 0.1),
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Next/Finish button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canGoNext ? _goToNext : null,
            icon: Icon(isLastQuestion ? Icons.check : Icons.arrow_forward),
            label: Text(isLastQuestion ? 'Finish' : 'Next'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLastQuestion ? Colors.green : Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _checkAndResetStateIfNeeded() {
    final currentHash = '${_phrase.id}_${_phrase.phrase}_${_phrase.translation}';
    if (currentHash != _lastPhraseDataHash) {
      _lastPhraseDataHash = currentHash;
      _resetState();
    }
  }

  void _resetState() {
    setState(() {
      _currentExerciseIndex = 0;
      _selectedAnswer = null;
      _showAnswer = false;
      _isCorrect = false;
      _correctAnswers = 0;
      _totalAnswered = 0;
      _shuffledOptions.clear();
      _answeredQuestions.clear();
      _selectedAnswers.clear();
      _sentenceAnswers.clear();
      _sentenceAvailable.clear();
      _cachedExercises = null; // Clear cached exercises
    });
  }

  void _initializeShuffledOptions(int exerciseIndex, Map<String, dynamic> exercise) {
    if (!_shuffledOptions.containsKey(exerciseIndex)) {
      final options = exercise['options'] as List<String>? ?? [];
      final shuffledOptions = List<String>.from(options);
      shuffledOptions.shuffle();
      _shuffledOptions[exerciseIndex] = shuffledOptions;
    }
    
    // Initialize sentence builder state if needed (only if not already initialized for this exercise)
    if (exercise['type'] == 'sentence_builder' && 
        !_sentenceAnswers.containsKey(exerciseIndex) && 
        !_sentenceAvailable.containsKey(exerciseIndex) &&
        _availableWords.isEmpty && 
        _answerWords.isEmpty) {  // Only initialize if both available words and answer words are empty
      final availableWords = exercise['availableWords'] as List<String>? ?? [];
      _availableWords = List<String>.from(availableWords);
      _answerWords = [];
      // print('🔍 Initialized sentence builder - Available: $_availableWords, Answer: $_answerWords, _showAnswer: $_showAnswer');
    }
  }

  List<Map<String, dynamic>> _generateExercises() {
    // Return cached exercises if available
    if (_cachedExercises != null) {
      return _cachedExercises!;
    }
    
    final phraseProvider = context.read<PhraseProvider>();
    final allPhrases = phraseProvider.phrases;
    
    // Generate translation exercise
    final translationExercise = phraseProvider.generateTranslationExercise(_phrase);
    
    // Generate sentence builder exercise
    final sentenceBuilderExercise = phraseProvider.generateSentenceBuilderExercise(_phrase);
    
    // Cache the exercises
    _cachedExercises = [translationExercise, sentenceBuilderExercise];
    
    return _cachedExercises!;
  }

  void _selectAnswer(String answer) {
    if (_showAnswer) return;
    
    setState(() {
      _selectedAnswer = answer;
      _showAnswer = true;
    });
    
    final exercises = _generateExercises();
    final currentExercise = exercises[_currentExerciseIndex];
    final isCorrect = answer == currentExercise['correctAnswer'];
    
    _isCorrect = isCorrect;
    _totalAnswered++;
    
    final phraseProvider = context.read<PhraseProvider>();
    if (isCorrect) {
      _correctAnswers++;
      phraseProvider.markPhraseCorrect(_phrase.id);
    } else {
      phraseProvider.markPhraseIncorrect(_phrase.id);
    }
    
    // Store the answer
    _answeredQuestions[_currentExerciseIndex] = true;
    _selectedAnswers[_currentExerciseIndex] = answer;
  }

  void _handleAvailableWordTap(String word) {
    if (_showAnswer) return; // Don't allow changes if answer is shown
    
    setState(() {
      _availableWords.remove(word);
      _answerWords.add(word);
    });
  }

  void _handleSelectedWordTap(String word) {
    if (_showAnswer) return; // Don't allow changes if answer is shown
    
    setState(() {
      _answerWords.remove(word);
      _availableWords.add(word);
    });
  }

  void _checkSentenceBuilderAnswer() {
    final exercises = _generateExercises();
    final currentExercise = exercises[_currentExerciseIndex];
    final correctOrder = currentExercise['correctOrder'] as List<String>;
    
    final isCorrect = _answerWords.length == correctOrder.length &&
        _answerWords.every((word) => correctOrder.contains(word)) &&
        _answerWords.join(' ') == correctOrder.join(' ');
    
    setState(() {
      _showAnswer = true;
      _isCorrect = isCorrect;
      _totalAnswered++;
    });
    
    final phraseProvider = context.read<PhraseProvider>();
    if (isCorrect) {
      _correctAnswers++;
      phraseProvider.markPhraseCorrect(_phrase.id);
    } else {
      phraseProvider.markPhraseIncorrect(_phrase.id);
    }
    
    // Store the answer
    _answeredQuestions[_currentExerciseIndex] = true;
    _sentenceAnswers[_currentExerciseIndex] = List<String>.from(_answerWords);
    _sentenceAvailable[_currentExerciseIndex] = List<String>.from(_availableWords);
  }

  void _goToPrevious() {
    if (_currentExerciseIndex > 0) {
      setState(() {
        _currentExerciseIndex--;
        // Restore previous state
        _showAnswer = _answeredQuestions[_currentExerciseIndex] ?? false;
        _selectedAnswer = _selectedAnswers[_currentExerciseIndex];
        _isCorrect = _showAnswer && (_selectedAnswer == _generateExercises()[_currentExerciseIndex]['correctAnswer']);
        
        // Restore sentence builder state
        final exercises = _generateExercises();
        final currentExercise = exercises[_currentExerciseIndex];
        if (currentExercise['type'] == 'sentence_builder') {
          _answerWords = _sentenceAnswers[_currentExerciseIndex] ?? [];
          final availableWords = currentExercise['availableWords'] as List<String>? ?? [];
          _availableWords = _sentenceAvailable[_currentExerciseIndex] ?? List<String>.from(availableWords);
        }
      });
    }
  }

  void _goToNext() {
    final exercises = _generateExercises();
    
    if (_currentExerciseIndex < exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _showAnswer = false;
        _selectedAnswer = null;
        _isCorrect = false;
        
        // Restore state if this question was already answered
        if (_answeredQuestions[_currentExerciseIndex] ?? false) {
          _showAnswer = true;
          _selectedAnswer = _selectedAnswers[_currentExerciseIndex];
          _isCorrect = _selectedAnswer == exercises[_currentExerciseIndex]['correctAnswer'];
          
          // Restore sentence builder state
          final currentExercise = exercises[_currentExerciseIndex];
          if (currentExercise['type'] == 'sentence_builder') {
            _answerWords = _sentenceAnswers[_currentExerciseIndex] ?? [];
            final availableWords = currentExercise['availableWords'] as List<String>? ?? [];
            _availableWords = _sentenceAvailable[_currentExerciseIndex] ?? List<String>.from(availableWords);
          }
        } else {
          // Reset sentence builder state for new question
          final currentExercise = exercises[_currentExerciseIndex];
          if (currentExercise['type'] == 'sentence_builder') {
            final availableWords = currentExercise['availableWords'] as List<String>? ?? [];
            _availableWords = List<String>.from(availableWords);
            _answerWords = [];
            // print('🔍 Reset sentence builder state in _goToNext - Available: $_availableWords, Answer: $_answerWords, _showAnswer: $_showAnswer');
          }
        }
      });
    } else {
      // Exercise complete - navigate back to phrases list
      final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered * 100).toInt() : 0;
      
      // Show completion dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(accuracy >= 60 ? 'Great Job!' : 'Keep Practicing'),
          content: Text('You got $_correctAnswers out of $_totalAnswered questions correct (${accuracy}%)'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to phrases list
              },
              child: const Text('Finish'),
            ),
          ],
        ),
      );
      
      if (widget.onComplete != null) {
        widget.onComplete!(accuracy >= 60);
      }
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        // TODO: Implement edit phrase functionality
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Phrase'),
        content: Text('Are you sure you want to delete "${_phrase.phrase}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePhrase();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deletePhrase() {
    final phraseProvider = context.read<PhraseProvider>();
    phraseProvider.deletePhrase(_phrase.id);
    Navigator.of(context).pop();
  }

  bool _canCheckAnswer() {
    final exercises = _generateExercises();
    final currentExercise = exercises[_currentExerciseIndex];
    if (currentExercise['type'] == 'sentence_builder') {
      final correctOrder = currentExercise['correctOrder'] as List<String>;
      return _answerWords.length == correctOrder.length;
    }
    return _answerWords.isNotEmpty;
  }

  String _getCheckAnswerButtonText() {
    final exercises = _generateExercises();
    final currentExercise = exercises[_currentExerciseIndex];
    if (currentExercise['type'] == 'sentence_builder') {
      final correctOrder = currentExercise['correctOrder'] as List<String>;
      final remaining = correctOrder.length - _answerWords.length;
      if (remaining > 0) {
        return 'Add $remaining more word${remaining == 1 ? '' : 's'}';
      }
      return 'Check Answer';
    }
    return 'Check Answer';
  }
}
