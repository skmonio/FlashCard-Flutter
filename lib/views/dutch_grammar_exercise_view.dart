import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../models/dutch_grammar_rule.dart';
import '../providers/dutch_grammar_provider.dart';
import '../components/unified_header.dart';
import '../services/sound_manager.dart';
import '../services/haptic_service.dart';


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
  int? _selectedAnswer;
  final Random _random = Random();
  // Track answers for each exercise
  Map<int, int> _exerciseAnswers = {}; // exerciseIndex -> selectedAnswer
  Map<int, bool> _exerciseAnswered = {}; // exerciseIndex -> isAnswered
  
  // Session tracking
  DateTime _sessionStartTime = DateTime.now();
  List<int> _questionResults = []; // 1 for correct, 0 for incorrect

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
          // Header
          UnifiedHeader(
            title: 'Exercise',
            onBack: () => _showCloseConfirmation(),
            trailing: IconButton(
              onPressed: () => _showHomeConfirmation(),
              icon: const Icon(Icons.home),
              tooltip: 'Go Home',
            ),
          ),
          
          // Progress Bar
          _buildProgressBar(),
          
          // Exercise Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [

                  
                  // Question
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: SelectableText(
                      currentExercise.question,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.left,
                      enableInteractiveSelection: true,
                      showCursor: false,
                      contextMenuBuilder: (context, editableTextState) {
                        return AdaptiveTextSelectionToolbar(
                          anchors: editableTextState.contextMenuAnchors,
                          children: [
                            CupertinoButton(
                              child: const Text('Copy'),
                              onPressed: () {
                                final selectedText = editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text);
                                Clipboard.setData(ClipboardData(text: selectedText));
                                editableTextState.hideToolbar();
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Options
                  Expanded(
                    child: _buildOptions(currentExercise),
                  ),
                  
                  // Navigation
                  if (widget.exercises.length > 1 || widget.shuffleMode) ...[
                    const SizedBox(height: 16),
                    _buildNavigation(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildOptions(GrammarExercise exercise) {
    switch (exercise.exerciseType) {
      case ExerciseType.multipleChoice:
        return _buildMultipleChoiceOptions(exercise);
      case ExerciseType.trueFalse:
        return _buildTrueFalseOptions(exercise);
      case ExerciseType.translation:
        return _buildMultipleChoiceOptions(exercise);
      case ExerciseType.fillInTheBlank:
        return _buildMultipleChoiceOptions(exercise);
      case ExerciseType.sentenceOrder:
        return _buildMultipleChoiceOptions(exercise);
    }
  }

  Widget _buildMultipleChoiceOptions(GrammarExercise exercise) {
    return ListView.builder(
      itemCount: exercise.options.length,
      itemBuilder: (context, index) {
        final option = exercise.options[index];
        final isSelected = _selectedAnswer == index;
        final isCorrect = index == exercise.correctAnswer;
        
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
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _answered ? null : () => _selectAnswer(index),
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
                          String.fromCharCode(65 + index), // A, B, C, D...
                          style: TextStyle(
                            fontSize: 14,
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
                          height: 1.4,
                        ),
                        textAlign: TextAlign.left,
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
      },
    );
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
    final progress = _currentIndex / widget.exercises.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Exercise ${_currentIndex + 1} of ${widget.exercises.length}'),
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

  Widget _buildNavigation() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (_currentIndex > 0 && !widget.shuffleMode) ? _goToPrevious : null,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Previous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: (_currentIndex > 0 && !widget.shuffleMode) ? Colors.blue : Colors.grey,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _answered ? _goToNext : null,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(widget.shuffleMode ? 'Complete' : (_currentIndex == widget.exercises.length - 1 ? 'Finish' : 'Next')),
            style: ElevatedButton.styleFrom(
              backgroundColor: _answered ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
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
          UnifiedHeader(
            title: 'Exercise Complete',
            onBack: () => Navigator.of(context).pop(),
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
    final isCorrect = index == currentExercise.correctAnswer;
    
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
      case ExerciseType.translation:
        return 'Translation';
      case ExerciseType.fillInTheBlank:
        return 'Fill in the Blank';
      case ExerciseType.sentenceOrder:
        return 'Sentence Order';
      case ExerciseType.trueFalse:
        return 'True/False';
    }
  }

  IconData _getExerciseTypeIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return Icons.format_list_bulleted;
      case ExerciseType.translation:
        return Icons.translate;
      case ExerciseType.fillInTheBlank:
        return Icons.edit;
      case ExerciseType.sentenceOrder:
        return Icons.sort;
      case ExerciseType.trueFalse:
        return Icons.check_circle_outline;
    }
  }

  Color _getExerciseTypeColor(ExerciseType type) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return Colors.blue;
      case ExerciseType.translation:
        return Colors.green;
      case ExerciseType.fillInTheBlank:
        return Colors.orange;
      case ExerciseType.sentenceOrder:
        return Colors.purple;
      case ExerciseType.trueFalse:
        return Colors.teal;
    }
  }

  // Helper methods for tracking exercise state
  bool _isExerciseAnswered(int exerciseIndex) {
    return _exerciseAnswered[exerciseIndex] ?? false;
  }

  int? _getExerciseAnswer(int exerciseIndex) {
    return _exerciseAnswers[exerciseIndex];
  }


}
