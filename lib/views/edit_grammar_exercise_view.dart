import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dutch_grammar_rule.dart';
import '../providers/dutch_grammar_provider.dart';

class EditGrammarExerciseView extends StatefulWidget {
  final DutchGrammarRule rule;
  final GrammarExercise? editingExercise;
  final int? exerciseIndex;
  
  const EditGrammarExerciseView({
    super.key,
    required this.rule,
    this.editingExercise,
    this.exerciseIndex,
  });

  @override
  State<EditGrammarExerciseView> createState() => _EditGrammarExerciseViewState();
}

class _EditGrammarExerciseViewState extends State<EditGrammarExerciseView> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final _hintController = TextEditingController();
  final _correctAnswerController = TextEditingController();
  
  ExerciseType _selectedExerciseType = ExerciseType.multipleChoice;
  final List<TextEditingController> _optionControllers = [];
  int _correctAnswerIndex = 0;
  
  bool get _isEditing => widget.editingExercise != null;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    
    // Add listener to correct answer controller for sentence building preview
    _correctAnswerController.addListener(() {
      if (_selectedExerciseType == ExerciseType.sentenceBuilding) {
        setState(() {});
      }
    });
  }

  void _initializeControllers() {
    if (_isEditing) {
      final exercise = widget.editingExercise!;
      _questionController.text = exercise.question;
      _explanationController.text = exercise.explanation;
      _hintController.text = exercise.hint ?? '';
      _selectedExerciseType = exercise.exerciseType;
      
      // Set correct answer based on exercise type
      if (exercise.exerciseType == ExerciseType.multipleChoice || exercise.exerciseType == ExerciseType.fillInTheBlank) {
        _correctAnswerIndex = exercise.correctAnswer;
        if (_correctAnswerIndex == -1) _correctAnswerIndex = 0;
      } else {
        _correctAnswerController.text = exercise.options[exercise.correctAnswer];
      }
      
      // Initialize option controllers
      for (final option in exercise.options) {
        _optionControllers.add(TextEditingController(text: option));
      }
    } else {
      // Initialize with default values for new exercise
      _optionControllers.addAll([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    _hintController.dispose();
    _correctAnswerController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          
          // Content
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exercise Type Selection
                    _buildExerciseTypeSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Question Section
                    _buildQuestionSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Options Section
                    _buildOptionsSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Correct Answer Section
                    _buildCorrectAnswerSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Hint Section
                    _buildHintSection(),
                    
                    const SizedBox(height: 32),
                    
                    // Save Button
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            _isEditing ? 'Edit Exercise' : 'New Exercise',
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
        
        // Right side - Save button
        Positioned(
          right: 16, // Add proper padding from right edge
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: _saveExercise,
            icon: const Icon(Icons.save, color: Colors.black),
            tooltip: 'Save Exercise',
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exercise Type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ExerciseType>(
          value: _selectedExerciseType,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: ExerciseType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(_getExerciseTypeName(type)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedExerciseType = value;
                _adjustOptionsForType();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildQuestionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _questionController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter the exercise question...',
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Question is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    // For sentence building, show the preview instead of options
    if (_selectedExerciseType == ExerciseType.sentenceBuilding) {
      return _buildSentenceBuildingPreview();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_selectedExerciseType == ExerciseType.multipleChoice || _selectedExerciseType == ExerciseType.fillInTheBlank) ...[
              IconButton(
                onPressed: _addOption,
                icon: const Icon(Icons.add),
                tooltip: 'Add Option',
              ),
              IconButton(
                onPressed: _removeOption,
                icon: const Icon(Icons.remove),
                tooltip: 'Remove Option',
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_optionControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              controller: _optionControllers[index],
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Option ${index + 1}',
                prefixIcon: Icon(
                  _correctAnswerIndex == index ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _correctAnswerIndex == index ? Colors.green : null,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Option ${index + 1} is required';
                }
                return null;
              },
              onTap: () {
                setState(() {
                  _correctAnswerIndex = index;
                });
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSentenceBuildingPreview() {
    final correctAnswer = _correctAnswerController.text;
    final words = correctAnswer.split(' ').where((String word) => word.isNotEmpty).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Word Options (Auto-generated from correct answer)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (words.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: words.map((word) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    word,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Text(
              'Enter a correct answer to see the word options.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCorrectAnswerSection() {
    if (_selectedExerciseType == ExerciseType.sentenceBuilding) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Correct Answer',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _correctAnswerController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter the correct sentence...',
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the correct answer';
              }
              return null;
            },
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Correct Answer',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap on the correct option above to select it.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildExplanationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explanation',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _explanationController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Explain why this is the correct answer...',
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Explanation is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildHintSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hint (Optional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _hintController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Provide a helpful hint for this exercise...',
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveExercise,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          _isEditing ? 'Update Exercise' : 'Create Exercise',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _adjustOptionsForType() {
    switch (_selectedExerciseType) {
      case ExerciseType.multipleChoice:
        // Ensure we have at least 2 options
        while (_optionControllers.length < 2) {
          _optionControllers.add(TextEditingController());
        }
        break;
      case ExerciseType.fillInTheBlank:
        // Ensure we have at least 2 options for fill in blank
        while (_optionControllers.length < 2) {
          _optionControllers.add(TextEditingController());
        }
        break;
      case ExerciseType.sentenceBuilding:
        // Clear options for sentence building
        _optionControllers.clear();
        break;
      case ExerciseType.translation:
        // Ensure we have at least 2 options for translation
        while (_optionControllers.length < 2) {
          _optionControllers.add(TextEditingController());
        }
        break;
      case ExerciseType.trueFalse:
        // Ensure we have exactly 2 options for true/false
        _optionControllers.clear();
        _optionControllers.add(TextEditingController(text: 'True'));
        _optionControllers.add(TextEditingController(text: 'False'));
        break;
    }
    
    // Ensure correct answer index is valid
    if (_correctAnswerIndex >= _optionControllers.length) {
      _correctAnswerIndex = 0;
    }
  }

  void _addOption() {
    if (_optionControllers.length < 6) { // Limit to 6 options
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption() {
    if (_optionControllers.length > 2) { // Keep at least 2 options
      setState(() {
        _optionControllers.removeLast();
        if (_correctAnswerIndex >= _optionControllers.length) {
          _correctAnswerIndex = _optionControllers.length - 1;
        }
      });
    }
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

  void _saveExercise() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Collect options (only for multiple choice and fill in blank)
    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if ((_selectedExerciseType == ExerciseType.multipleChoice || _selectedExerciseType == ExerciseType.fillInTheBlank) && options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 2 options are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Determine correct answer based on exercise type
    int correctAnswer;
    if (_selectedExerciseType == ExerciseType.multipleChoice || _selectedExerciseType == ExerciseType.fillInTheBlank) {
      correctAnswer = _correctAnswerIndex;
    } else {
      // For other exercise types, find the index of the correct answer in options
      final correctText = _correctAnswerController.text.trim();
      correctAnswer = options.indexOf(correctText);
      if (correctAnswer == -1) correctAnswer = 0; // Default to first option if not found
    }

    // Create the exercise
    final exercise = GrammarExercise(
      question: _questionController.text.trim(),
      options: options,
      correctAnswer: correctAnswer,
      explanation: _explanationController.text.trim(),
      hint: _hintController.text.trim().isEmpty ? null : _hintController.text.trim(),
      exerciseType: _selectedExerciseType,
    );

    // Save the exercise
    final provider = context.read<DutchGrammarProvider>();
    
    if (_isEditing && widget.exerciseIndex != null) {
      // Update existing exercise
      provider.updateExerciseInRule(widget.rule.id, widget.exerciseIndex!, exercise);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercise updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Add new exercise
      provider.addExerciseToRule(widget.rule.id, exercise);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercise added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }

    Navigator.of(context).pop();
  }
}
