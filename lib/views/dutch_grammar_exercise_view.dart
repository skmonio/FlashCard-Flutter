import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../models/dutch_grammar_rule.dart';
import '../providers/dutch_grammar_provider.dart';

import '../services/sound_manager.dart';
import '../services/haptic_service.dart';
import '../utils/sentence_utils.dart';


class DutchGrammarExerciseView extends StatefulWidget {
  final List<GrammarExercise> exercises;
  final String ruleTitle;
  final String ruleId;
  final int? startIndex;
  final Function(bool)? onComplete;
  final bool shuffleMode;

  const DutchGrammarExerciseView({
    super.key,
    required this.exercises,
    required this.ruleTitle,
    required this.ruleId,
    this.startIndex,
    this.onComplete,
    this.shuffleMode = false,
  });

  @override
  State<DutchGrammarExerciseView> createState() => _DutchGrammarExerciseViewState();
}

class _DutchGrammarExerciseViewState extends State<DutchGrammarExerciseView> {
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  bool _showingResults = false;
  bool _answered = false;
  bool _isCorrect = false;
  int? _selectedAnswer;
  final Random _random = Random();
  // Track answers for each exercise
  Map<int, int> _exerciseAnswers = {}; // exerciseIndex -> selectedAnswer
  Map<int, bool> _exerciseAnswered = {}; // exerciseIndex -> isAnswered
  
  // Session tracking
  DateTime _sessionStartTime = DateTime.now();
  List<int> _questionResults = []; // 1 for correct, 0 for incorrect
  
  // Sentence building variables (per-exercise state management)
  List<String> _answerWords = [];
  List<String> _availableWords = [];
  Map<int, List<String>> _sentenceAnswers = {};
  Map<int, List<String>> _sentenceAvailable = {};
  Map<int, List<String>> _shuffledOptions = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex ?? 0;
    // Initialize current exercise state
    _answered = _isExerciseAnswered(_currentIndex);
    _selectedAnswer = _getExerciseAnswer(_currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.ruleTitle)),
        body: const Center(
          child: Text('No exercises available'),
        ),
      );
    }

    if (_showingResults) {
      return _buildResultsView();
    }

    final currentExercise = widget.exercises[_currentIndex];

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
        ],
      ),
    );
  }

  Widget _buildExerciseContent(GrammarExercise exercise) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          
          // Exercise prompt
          SelectableText(
            exercise.question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.left,
            enableInteractiveSelection: true,
            showCursor: false,
          ),
          
          const SizedBox(height: 24),
          
          // Answer options
          Expanded(
            child: _buildAnswerOptions(exercise),
          ),
          
          // Answer feedback
          if (_answered) _buildAnswerFeedback(exercise),
          
          // Navigation
          if (widget.exercises.length > 1 || widget.shuffleMode) ...[
            const SizedBox(height: 16),
            _buildNavigation(),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerOptions(GrammarExercise exercise) {
    if (exercise.exerciseType == ExerciseType.fillInTheBlank) {
      return _buildFillInBlankOptions(exercise);
    } else if (exercise.exerciseType == ExerciseType.sentenceBuilding) {
      return _buildSentenceBuildingOptions(exercise);
    } else {
      return _buildMultipleChoiceOptions(exercise);
    }
  }

  Widget _buildExerciseTypeIndicator(ExerciseType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getExerciseTypeColor(type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getExerciseTypeColor(type).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getExerciseTypeIcon(type),
            size: 16,
            color: _getExerciseTypeColor(type),
          ),
          const SizedBox(width: 6),
          Text(
            _getExerciseTypeName(type),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getExerciseTypeColor(type),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMultipleChoiceOptions(GrammarExercise exercise) {
    return Column(
      children: exercise.options.map((option) {
        final isSelected = _selectedAnswer == exercise.options.indexOf(option);
        final isCorrect = exercise.options.indexOf(option) == exercise.correctAnswer;
        
        Color backgroundColor = Theme.of(context).colorScheme.surface;
        Color borderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
        bool showCorrect = false;
        bool showIncorrect = false;
        
        if (_answered) {
          if (isCorrect) {
            backgroundColor = Colors.green.withValues(alpha: 0.1);
            borderColor = Colors.green;
            showCorrect = true;
          } else if (isSelected && !isCorrect) {
            backgroundColor = Colors.red.withValues(alpha: 0.1);
            borderColor = Colors.red;
            showIncorrect = true;
          }
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
              onTap: _answered ? null : () => _selectAnswer(exercise.options.indexOf(option)),
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

  Widget _buildFillInBlankOptions(GrammarExercise exercise) {
    return Column(
      children: exercise.options.map((option) {
        final isSelected = _selectedAnswer == exercise.options.indexOf(option);
        final isCorrect = exercise.options.indexOf(option) == exercise.correctAnswer;
        
        Color backgroundColor = Theme.of(context).colorScheme.surface;
        Color borderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
        bool showCorrect = false;
        bool showIncorrect = false;
        
        if (_answered) {
          if (isCorrect) {
            backgroundColor = Colors.green.withValues(alpha: 0.1);
            borderColor = Colors.green;
            showCorrect = true;
          } else if (isSelected && !isCorrect) {
            backgroundColor = Colors.red.withValues(alpha: 0.1);
            borderColor = Colors.red;
            showIncorrect = true;
          }
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
              onTap: _answered ? null : () => _selectAnswer(exercise.options.indexOf(option)),
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

  Widget _buildSentenceBuildingOptions(GrammarExercise exercise) {
    // Initialize sentence building state if not already done
    if (_answered) {
      // Load saved state for this specific exercise
      _answerWords = List<String>.from(_sentenceAnswers[_currentIndex] ?? []);
      _availableWords = List<String>.from(_sentenceAvailable[_currentIndex] ?? []);
    } else if (_availableWords.isEmpty && _answerWords.isEmpty) {
      // Initialize fresh state for this specific exercise
      List<String> wordsToShuffle;
      if (exercise.exerciseType == ExerciseType.sentenceBuilding) {
        // For sentence building, use the options (individual words)
        wordsToShuffle = List<String>.from(exercise.options);
      } else {
        // For other exercise types, split the correct answer
        wordsToShuffle = exercise.options[exercise.correctAnswer].split(' ');
      }
      
      // Store shuffled options for this specific exercise
      if (!_shuffledOptions.containsKey(_currentIndex)) {
        _shuffledOptions[_currentIndex] = List<String>.from(wordsToShuffle)..shuffle();
      }
      _availableWords = List<String>.from(_shuffledOptions[_currentIndex]!);
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
    if (_answered) return; // Don't allow changes after answering
    
    setState(() {
      _answerWords.add(word);
      _availableWords.remove(word);
    });
  }

  void _moveWordToAvailable(String word) {
    if (_answered) return; // Don't allow changes after answering
    
    setState(() {
      _answerWords.remove(word);
      _availableWords.add(word);
    });
  }

  Widget _buildAnswerFeedback(GrammarExercise exercise) {
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
            exercise.explanation ?? 'Good job!' + (_isCorrect ? '' : ' Try again!'),
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.left,
            enableInteractiveSelection: true,
            showCursor: false,
          ),
          if (!_isCorrect && exercise.exerciseType == ExerciseType.sentenceBuilding) ...[
            const SizedBox(height: 12),
            Text(
              'Correct answer: ${exercise.options[exercise.correctAnswer]}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _checkSentenceBuildingAnswer() {
    final currentExercise = widget.exercises[_currentIndex];
    final correctWords = currentExercise.options[currentExercise.correctAnswer].split(' ');
    
    // Use SentenceUtils for flexible comparison (handles duplicate function words)
    final isCorrect = SentenceUtils.equalsWithFlexibleDuplicates(_answerWords, correctWords);
    
    setState(() {
      _answered = true;
      _isCorrect = isCorrect;
      _sentenceAnswers[_currentIndex] = List<String>.from(_answerWords);
      _sentenceAvailable[_currentIndex] = List<String>.from(_availableWords);
    });

    if (isCorrect) {
      HapticService().lightImpact();
      SoundManager().playCorrectSound();
    } else {
      HapticService().heavyImpact();
      SoundManager().playWrongSound();
    }
  }

  Widget _buildTrueFalseOptions(GrammarExercise exercise) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildTrueFalseButton(true, exercise),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTrueFalseButton(false, exercise),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrueFalseButton(bool isTrue, GrammarExercise exercise) {
    final isSelected = _selectedAnswer == (isTrue ? 0 : 1);
    final isCorrect = (isTrue ? 0 : 1) == exercise.correctAnswer;
    
    Color backgroundColor = Theme.of(context).colorScheme.surface;
    Color borderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.3);
    
    if (_answered) {
      if (isCorrect) {
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        borderColor = Colors.green;
      } else if (isSelected && !isCorrect) {
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        borderColor = Colors.red;
      }
    } else if (isSelected) {
      backgroundColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
      borderColor = Theme.of(context).colorScheme.primary;
    }
    
    return Container(
      height: 120,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _answered ? null : () => _selectAnswer(isTrue ? 0 : 1),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      isTrue ? 'T' : 'F',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isTrue ? 'TRUE' : 'FALSE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: borderColor,
                  ),
                ),
                if (_answered && isCorrect)
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                if (_answered && isSelected && !isCorrect)
                  const Icon(Icons.cancel, color: Colors.red, size: 24),
              ],
            ),
          ),
        ),
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
                'Exercise ${_currentIndex + 1} of ${widget.exercises.length}',
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
            value: _currentIndex / widget.exercises.length,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    final currentExercise = widget.exercises[_currentIndex];
    final isSentenceBuilding = currentExercise.exerciseType == ExerciseType.sentenceBuilding;
    
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: (_currentIndex > 0 && !widget.shuffleMode) ? _goToPrevious : null,
            child: const Text('Previous'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: isSentenceBuilding ? (_answered ? _goToNext : null) : _goToNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: isSentenceBuilding ? (_answered ? Colors.green : Colors.grey) : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(
              isSentenceBuilding 
                ? (_answered ? (widget.shuffleMode ? 'Complete' : (_currentIndex == widget.exercises.length - 1 ? 'Finish' : 'Next')) : 'Check Answer')
                : (widget.shuffleMode ? 'Complete' : (_currentIndex == widget.exercises.length - 1 ? 'Finish' : 'Next'))
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered * 100).toInt() : 0;
    
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
              child: _buildCustomHeaderResults(context),
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Score Circle
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
                  _buildStatCard('Exercises', _totalAnswered.toString(), Icons.quiz),
                  const SizedBox(height: 16),
                  _buildStatCard('Correct', _correctAnswers.toString(), Icons.check_circle, Colors.green),
                  const SizedBox(height: 16),
                  _buildStatCard('Incorrect', (_totalAnswered - _correctAnswers).toString(), Icons.cancel, Colors.red),
                  
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  Row(
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
                              _selectedAnswer = null;
                            });
                          },
                          child: const Text('Practice Again'),
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

  void _selectAnswer(int index) {
    if (_answered) return;
    
    final currentExercise = widget.exercises[_currentIndex];
    bool isCorrect;
    
    // Handle different exercise types
    if (currentExercise.exerciseType == ExerciseType.sentenceBuilding) {
      // For sentence building, check the answer words
      final correctWords = currentExercise.options[currentExercise.correctAnswer].split(' ');
      isCorrect = SentenceUtils.equalsWithFlexibleDuplicates(_answerWords, correctWords);
    } else {
      // For multiple choice and fill in blank
      isCorrect = index == currentExercise.correctAnswer;
    }
    
    // Provide haptic feedback
    if (isCorrect) {
      HapticService().successFeedback();
      SoundManager().playCorrectSound();
    } else {
      HapticService().errorFeedback();
      SoundManager().playWrongSound();
    }
    
    // Record the result
    context.read<DutchGrammarProvider>().recordExerciseResult(
      widget.ruleId,
      _currentIndex,
      isCorrect,
    );
    
    // Track session results
    _questionResults.add(isCorrect ? 1 : 0);
    
    // Store the answer for this exercise
    _exerciseAnswers[_currentIndex] = index;
    _exerciseAnswered[_currentIndex] = true;
    
    setState(() {
      _selectedAnswer = index;
      _answered = true;
      _isCorrect = isCorrect;
      _totalAnswered++;
      
      if (isCorrect) {
        _correctAnswers++;
      }
    });
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        // Keep the answer state when going back
        _answered = _isExerciseAnswered(_currentIndex);
        _selectedAnswer = _getExerciseAnswer(_currentIndex);
        
        // Reset sentence building state for new exercise
        _answerWords.clear();
        _availableWords.clear();
      });
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.exercises.length - 1) {
      setState(() {
        _currentIndex++;
        // Keep the answer state when going forward
        _answered = _isExerciseAnswered(_currentIndex);
        _selectedAnswer = _getExerciseAnswer(_currentIndex);
        
        // Reset sentence building state for new exercise
        _answerWords.clear();
        _availableWords.clear();
      });
    } else {
      // Record the study session
      _recordStudySession();
      
      if (widget.shuffleMode && widget.onComplete != null) {
        // For shuffle mode, call the callback immediately
        final wasCorrect = _correctAnswers == _totalAnswered;
        widget.onComplete!(wasCorrect);
      } else {
        // Normal mode, show results
        setState(() {
          _showingResults = true;
        });
        SoundManager().playCompleteSound();
      }
    }
  }

  void _recordStudySession() {
    final sessionEndTime = DateTime.now();
    final timeSpentSeconds = sessionEndTime.difference(_sessionStartTime).inSeconds;
    final accuracy = _totalAnswered > 0 ? _correctAnswers / _totalAnswered : 0.0;
    
    final session = GrammarStudySession(
      date: sessionEndTime,
      totalQuestions: _totalAnswered,
      correctAnswers: _correctAnswers,
      accuracy: accuracy,
      timeSpentSeconds: timeSpentSeconds,
      questionResults: List<int>.from(_questionResults),
    );
    
    context.read<DutchGrammarProvider>().recordStudySession(widget.ruleId, session);
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Exercise?'),
        content: const Text('Are you sure you want to end this exercise? Your progress will be saved.'),
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
          ElevatedButton(
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

  String _getExerciseTypeName(ExerciseType type) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return 'Multiple Choice';
      case ExerciseType.fillInTheBlank:
        return 'Fill in the Blank';
      case ExerciseType.sentenceBuilding:
        return 'Sentence Building';
      case ExerciseType.translation:
        return 'Translation';
      case ExerciseType.trueFalse:
        return 'True/False';
    }
  }

  IconData _getExerciseTypeIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return Icons.format_list_bulleted;
      case ExerciseType.fillInTheBlank:
        return Icons.edit;
      case ExerciseType.sentenceBuilding:
        return Icons.sort;
      case ExerciseType.translation:
        return Icons.translate;
      case ExerciseType.trueFalse:
        return Icons.check_circle_outline;
    }
  }

  Color _getExerciseTypeColor(ExerciseType type) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return Colors.blue;
      case ExerciseType.fillInTheBlank:
        return Colors.orange;
      case ExerciseType.sentenceBuilding:
        return Colors.purple;
      case ExerciseType.translation:
        return Colors.green;
      case ExerciseType.trueFalse:
        return Colors.red;
    }
  }

  // Helper methods for tracking exercise state
  bool _isExerciseAnswered(int exerciseIndex) {
    return _exerciseAnswered[exerciseIndex] ?? false;
  }

  int? _getExerciseAnswer(int exerciseIndex) {
    return _exerciseAnswers[exerciseIndex];
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            'Exercise',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
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
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
        ),
        
        // Right side - Home button
        Positioned(
          right: 16, // Add proper padding from right edge
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () => _showHomeConfirmation(),
            icon: const Icon(Icons.home, color: Colors.black),
            tooltip: 'Go Home',
          ),
        ),
      ],
    );
  }

  Widget _buildCustomHeaderResults(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            'Exercise Complete',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        
        // Left side - Back button with proper padding
        Positioned(
          left: 16, // Add proper padding from left edge
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
        ),
      ],
    );
  }
}
