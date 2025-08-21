import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../models/dutch_word_exercise.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/flashcard_provider.dart';

class CreateWordExerciseView extends StatefulWidget {
  final DutchWordExercise? editingExercise;
  
  const CreateWordExerciseView({
    super.key,
    this.editingExercise,
  });

  @override
  State<CreateWordExerciseView> createState() => _CreateWordExerciseViewState();
}

class _CreateWordExerciseViewState extends State<CreateWordExerciseView> {
  final _formKey = GlobalKey<FormState>();
  final _targetWordController = TextEditingController();
  final _translationController = TextEditingController();
  bool _isPickingExistingWord = false;
  String? _selectedWordId;
  
  final List<WordExercise> _exercises = [];
  final List<TextEditingController> _promptControllers = [];
  final List<List<TextEditingController>> _optionControllers = [];
  final List<TextEditingController> _correctAnswerControllers = [];
  final List<TextEditingController> _explanationControllers = [];
  final List<ExerciseType> _exerciseTypes = [];

  @override
  void initState() {
    super.initState();
    
    if (widget.editingExercise != null) {
      _loadExerciseForEditing();
    }
    // Don't start with any exercises - let user add their own
  }

  @override
  void dispose() {
    _targetWordController.dispose();
    _translationController.dispose();
    for (final controller in _promptControllers) {
      controller.dispose();
    }
    for (final optionList in _optionControllers) {
      for (final controller in optionList) {
        controller.dispose();
      }
    }
    for (final controller in _correctAnswerControllers) {
      controller.dispose();
    }
    for (final controller in _explanationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingExercise != null ? 'Edit Exercise' : 'Exercise'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveExercise,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Word information
              _buildWordInfoSection(),
              
              const SizedBox(height: 24),
              
              // Exercises section
              _buildExercisesSection(),
              
              const SizedBox(height: 24),
              
              // Add exercise button (only show when there are existing exercises)
              if (_exercises.isNotEmpty) _buildAddExerciseButton(),
              
              const SizedBox(height: 24),
              
              // Save button
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordInfoSection() {
    // Don't show word information section when editing an existing exercise
    if (widget.editingExercise != null) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Word Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Word selection (only existing words)
            if (widget.editingExercise == null) ...[
              const Text(
                'Select an existing word to add exercises to:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Existing word selection
              Consumer<FlashcardProvider>(
                builder: (context, flashcardProvider, child) {
                  final cards = List.from(flashcardProvider.cards)..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Existing Word',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Consumer<DutchWordExerciseProvider>(
                          builder: (context, dutchProvider, child) {
                            return ListView.builder(
                              itemCount: cards.length,
                              itemBuilder: (context, index) {
                                final card = cards[index];
                                final isSelected = _selectedWordId == card.id;
                                final existingExercise = dutchProvider.getWordExerciseByWord(card.word);
                                final exerciseCount = existingExercise?.exercises.length ?? 0;
                                
                                return ListTile(
                                  title: Text(card.word),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(card.definition),
                                      if (exerciseCount > 0)
                                        Text(
                                          '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: isSelected 
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedWordId = card.id;
                                      _targetWordController.text = card.word;
                                      _translationController.text = card.definition;
                                      _loadExistingExercisesForWord(card.word);
                                    });
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Deck info (auto-assigned based on selected card) - only show when not editing
            if (widget.editingExercise == null) _buildDeckInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckInfoSection() {
    return Consumer<FlashcardProvider>(
      builder: (context, flashcardProvider, child) {
        String? selectedCardDeckId;
        String? selectedCardDeckName;
        
        // Find the deck info for the selected card
        if (_selectedWordId != null) {
          final selectedCard = flashcardProvider.cards.firstWhere(
            (card) => card.id == _selectedWordId,
            orElse: () => FlashCard(
              word: '',
              definition: '',
              example: '',
              deckIds: <String>{},
              dateCreated: DateTime.now(),
              learningMastery: LearningMastery(),
              article: '',
              plural: '',
              pastTense: '',
              futureTense: '',
              pastParticiple: '',
            ),
          );
          
          if (selectedCard.deckIds.isNotEmpty) {
            selectedCardDeckId = selectedCard.deckIds.first;
            // Get deck name from the deck ID (you might need to implement this)
            selectedCardDeckName = selectedCardDeckId; // For now, use ID as name
          }
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deck Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            
            if (_selectedWordId != null && selectedCardDeckId != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Card Deck: ${selectedCardDeckName ?? selectedCardDeckId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'The exercise will be automatically assigned to this deck.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedWordId != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Text(
                  'Selected card is not assigned to any deck. Exercise will be created without deck assignment.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: const Text(
                  'Please select a card to see deck information.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildExercisesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Exercises',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_exercises.length} exercises',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Exercise list
        if (_exercises.isEmpty) ...[
          // Show message when no exercises
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.quiz,
                  size: 48,
                  color: Colors.grey.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'No exercises yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first exercise to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _buildAddExerciseButton(),
              ],
            ),
          ),
        ] else ...[
          // Show existing exercises
          ...List.generate(_exercises.length, (index) {
            return _buildExerciseCard(index);
          }),
        ],
      ],
    );
  }

  Widget _buildExerciseCard(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exercise ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeExercise(index),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Exercise type
            DropdownButtonFormField<ExerciseType>(
              value: _exerciseTypes[index],
              decoration: const InputDecoration(
                labelText: 'Exercise Type',
                border: OutlineInputBorder(),
              ),
              items: ExerciseType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getExerciseTypeName(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _exerciseTypes[index] = value!;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Prompt
            TextFormField(
              controller: _promptControllers[index],
              decoration: const InputDecoration(
                labelText: 'Prompt/Question',
                hintText: 'Enter the question or prompt',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a prompt';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Options (for multiple choice and fill in blank)
            if (_exerciseTypes[index] == ExerciseType.multipleChoice ||
                _exerciseTypes[index] == ExerciseType.fillInBlank)
              _buildOptionsSection(index),
            
            // Sentence building preview
            if (_exerciseTypes[index] == ExerciseType.sentenceBuilding)
              _buildSentenceBuildingPreview(index),
            
            const SizedBox(height: 16),
            
            // Correct answer (not needed for multiple choice)
            if (_exerciseTypes[index] != ExerciseType.multipleChoice)
              TextFormField(
                controller: _correctAnswerControllers[index],
                decoration: const InputDecoration(
                  labelText: 'Correct Answer',
                  hintText: 'Enter the correct answer',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the correct answer';
                  }
                  return null;
                },
              ),
            
            if (_exerciseTypes[index] != ExerciseType.multipleChoice)
              const SizedBox(height: 16),
            
            // Explanation (optional)
            TextFormField(
              controller: _explanationControllers[index],
              decoration: const InputDecoration(
                labelText: 'Explanation (Optional)',
                hintText: 'Explain why this is correct (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSection(int exerciseIndex) {
    final options = _optionControllers[exerciseIndex];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Options',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_exerciseTypes[exerciseIndex] == ExerciseType.multipleChoice)
                  Text(
                    'First option is the correct answer',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _addOption(exerciseIndex),
              icon: const Icon(Icons.add),
              label: const Text('Add Option'),
            ),
          ],
        ),
        
        ...List.generate(options.length, (optionIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: options[optionIndex],
                    decoration: InputDecoration(
                      labelText: _exerciseTypes[exerciseIndex] == ExerciseType.multipleChoice && optionIndex == 0
                          ? 'Correct Answer (Option 1)'
                          : 'Option ${optionIndex + 1}',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an option';
                      }
                      return null;
                    },
                  ),
                ),
                if (options.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.red),
                    onPressed: () => _removeOption(exerciseIndex, optionIndex),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSentenceBuildingPreview(int exerciseIndex) {
    final correctAnswer = _correctAnswerControllers[exerciseIndex].text;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Correct Answer: "$correctAnswer"',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Words will be: ${words.map((word) => '"$word"').join(', ')}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
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
              'Enter a correct answer to see the word options',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddExerciseButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _saveExercise,
        icon: const Icon(Icons.save),
        label: const Text('Save Word Exercise'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  void _addExercise() {
    setState(() {
      _exercises.add(WordExercise(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ExerciseType.multipleChoice,
        prompt: '',
        options: ['', '', '', ''],
        correctAnswer: '',
        explanation: '',
        difficulty: ExerciseDifficulty.beginner,
      ));
      
      _promptControllers.add(TextEditingController());
      _correctAnswerControllers.add(TextEditingController());
      _explanationControllers.add(TextEditingController());
      _exerciseTypes.add(ExerciseType.multipleChoice);
      
      // Add option controllers
      final optionControllers = <TextEditingController>[];
      for (int i = 0; i < 4; i++) {
        optionControllers.add(TextEditingController());
      }
      _optionControllers.add(optionControllers);
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
      _promptControllers[index].dispose();
      _promptControllers.removeAt(index);
      _correctAnswerControllers[index].dispose();
      _correctAnswerControllers.removeAt(index);
      _explanationControllers[index].dispose();
      _explanationControllers.removeAt(index);
      _exerciseTypes.removeAt(index);
      
      // Dispose option controllers
      for (final controller in _optionControllers[index]) {
        controller.dispose();
      }
      _optionControllers.removeAt(index);
    });
    
    // If this was the last exercise and we're editing an existing exercise, 
    // navigate back to create exercise view
    if (_exercises.isEmpty && widget.editingExercise != null) {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreateWordExerciseView(
            editingExercise: widget.editingExercise,
          ),
        ),
      );
    }
  }

  void _addOption(int exerciseIndex) {
    setState(() {
      _optionControllers[exerciseIndex].add(TextEditingController());
    });
  }

  void _removeOption(int exerciseIndex, int optionIndex) {
    if (_optionControllers[exerciseIndex].length > 2) {
      setState(() {
        _optionControllers[exerciseIndex][optionIndex].dispose();
        _optionControllers[exerciseIndex].removeAt(optionIndex);
      });
    }
  }

  void _saveExercise() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Validate word selection
    if (_isPickingExistingWord && _selectedWordId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an existing word'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (!_isPickingExistingWord && (_targetWordController.text.isEmpty || _translationController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both Dutch word and translation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Build exercises from form data
    final exercises = <WordExercise>[];
    
    for (int i = 0; i < _exercises.length; i++) {
      List<String> options;
      String correctAnswer;
      
      if (_exerciseTypes[i] == ExerciseType.sentenceBuilding) {
        // For sentence building, split the correct answer into individual words
        correctAnswer = _correctAnswerControllers[i].text;
        options = correctAnswer.split(' ').where((String word) => word.isNotEmpty).toList();
      } else if (_exerciseTypes[i] == ExerciseType.multipleChoice) {
        // For multiple choice, first option is the correct answer
        options = _optionControllers[i].map((c) => c.text).toList();
        correctAnswer = options.isNotEmpty ? options[0] : '';
      } else {
        // For other exercise types, use the options from the form and separate correct answer
        options = _optionControllers[i].map((c) => c.text).toList();
        correctAnswer = _correctAnswerControllers[i].text;
      }
      
      exercises.add(WordExercise(
        id: '${DateTime.now().millisecondsSinceEpoch}_$i',
        type: _exerciseTypes[i],
        prompt: _promptControllers[i].text,
        options: options,
        correctAnswer: correctAnswer,
        explanation: _explanationControllers[i].text,
        difficulty: ExerciseDifficulty.beginner,
      ));
    }

    // Determine deck information based on selected card
    String deckId;
    String deckName;
    
    if (_isPickingExistingWord && _selectedWordId != null) {
      // Get deck info from the selected card
      final flashcardProvider = context.read<FlashcardProvider>();
      final selectedCard = flashcardProvider.cards.firstWhere(
        (card) => card.id == _selectedWordId,
        orElse: () => FlashCard(
          word: '',
          definition: '',
          example: '',
                      deckIds: <String>{},
            dateCreated: DateTime.now(),
            learningMastery: LearningMastery(),
          article: '',
          plural: '',
          pastTense: '',
          futureTense: '',
          pastParticiple: '',
        ),
      );
      
      if (selectedCard.deckIds.isNotEmpty) {
        deckId = selectedCard.deckIds.first;
        deckName = deckId; // For now, use ID as name
      } else {
        deckId = 'default';
        deckName = 'Default';
      }
    } else {
      // For new words, use default deck
      deckId = 'default';
      deckName = 'Default';
    }

    // Check if there's already an existing exercise for this word
    final provider = context.read<DutchWordExerciseProvider>();
    final existingExercise = provider.getWordExerciseByWord(_targetWordController.text);
    
    DutchWordExercise wordExercise;
    
    if (existingExercise != null) {
      // Update existing exercise
      wordExercise = DutchWordExercise(
        id: existingExercise.id,
        targetWord: existingExercise.targetWord,
        wordTranslation: existingExercise.wordTranslation,
        deckId: existingExercise.deckId,
        deckName: existingExercise.deckName,
        category: existingExercise.category,
        difficulty: existingExercise.difficulty,
        exercises: exercises,
        createdAt: existingExercise.createdAt,
        isUserCreated: existingExercise.isUserCreated,
        learningProgress: existingExercise.learningProgress,
      );
      provider.updateWordExercise(wordExercise);
    } else {
      // Create new exercise
      wordExercise = DutchWordExercise(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        targetWord: _targetWordController.text,
        wordTranslation: _translationController.text,
        deckId: deckId,
        deckName: deckName,
        category: WordCategory.common, // Default category
        difficulty: ExerciseDifficulty.beginner, // Default difficulty
        exercises: exercises,
        createdAt: DateTime.now(),
        isUserCreated: true,
      );
      provider.addWordExercise(wordExercise);
    }

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Word exercise "${wordExercise.targetWord}" ${existingExercise != null ? 'updated' : 'created'} successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate back
    Navigator.of(context).pop();
  }

  void _loadExerciseForEditing() {
    final exercise = widget.editingExercise!;
    
    // Set word information
    _targetWordController.text = exercise.targetWord;
    _translationController.text = exercise.wordTranslation;
    
    // Find the card ID for this word to set as selected
    final flashcardProvider = context.read<FlashcardProvider>();
    final card = flashcardProvider.cards.firstWhere(
      (card) => card.word == exercise.targetWord,
      orElse: () => FlashCard(
        word: '',
        definition: '',
        example: '',
        deckIds: <String>{},
        dateCreated: DateTime.now(),
                            learningMastery: LearningMastery(),
        article: '',
        plural: '',
        pastTense: '',
        futureTense: '',
        pastParticiple: '',
      ),
    );
    
    if (card.word.isNotEmpty) {
      _selectedWordId = card.id;
    }
    
    // Clear existing exercises
    _exercises.clear();
    _promptControllers.clear();
    _optionControllers.clear();
    _correctAnswerControllers.clear();
    _explanationControllers.clear();
    _exerciseTypes.clear();
    
    // Load exercises
    for (final wordExercise in exercise.exercises) {
      _exercises.add(wordExercise);
      _promptControllers.add(TextEditingController(text: wordExercise.prompt));
      _correctAnswerControllers.add(TextEditingController(text: wordExercise.correctAnswer));
      _explanationControllers.add(TextEditingController(text: wordExercise.explanation));
      _exerciseTypes.add(wordExercise.type);
      
      // Add option controllers
      final optionControllers = <TextEditingController>[];
      for (final option in wordExercise.options) {
        optionControllers.add(TextEditingController(text: option));
      }
      _optionControllers.add(optionControllers);
    }
  }

  void _loadExistingExercisesForWord(String word) {
    final dutchProvider = context.read<DutchWordExerciseProvider>();
    final existingExercise = dutchProvider.getWordExerciseByWord(word);
    
    if (existingExercise != null) {
      // Clear existing exercises
      _exercises.clear();
      _promptControllers.clear();
      _optionControllers.clear();
      _correctAnswerControllers.clear();
      _explanationControllers.clear();
      _exerciseTypes.clear();
      
      // Load existing exercises
      for (final wordExercise in existingExercise.exercises) {
        _exercises.add(wordExercise);
        _promptControllers.add(TextEditingController(text: wordExercise.prompt));
        _correctAnswerControllers.add(TextEditingController(text: wordExercise.correctAnswer));
        _explanationControllers.add(TextEditingController(text: wordExercise.explanation));
        _exerciseTypes.add(wordExercise.type);
        
        // Add option controllers
        final optionControllers = <TextEditingController>[];
        for (final option in wordExercise.options) {
          optionControllers.add(TextEditingController(text: option));
        }
        _optionControllers.add(optionControllers);
      }
      
      // Show message about existing exercises
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded ${existingExercise.exercises.length} existing exercises for "$word"'),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      // Clear exercises for new word
      _exercises.clear();
      _promptControllers.clear();
      _optionControllers.clear();
      _correctAnswerControllers.clear();
      _explanationControllers.clear();
      _exerciseTypes.clear();
      
      // Don't add default exercise - let user add their own
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
} 