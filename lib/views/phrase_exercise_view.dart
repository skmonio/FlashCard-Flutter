import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/phrase.dart';
import '../providers/phrase_provider.dart';
import '../services/sound_manager.dart';
import '../services/haptic_service.dart';
import '../components/word_progress_display.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../utils/sentence_utils.dart';

class PhraseExerciseView extends StatefulWidget {
  final Phrase phrase;
  final bool singleQuestionMode;
  final Function(bool)? onComplete;

  const PhraseExerciseView({
    super.key,
    required this.phrase,
    this.singleQuestionMode = false,
    this.onComplete,
  });

  @override
  State<PhraseExerciseView> createState() => _PhraseExerciseViewState();
}

class _PhraseExerciseViewState extends State<PhraseExerciseView> {
  late PhraseProvider _phraseProvider;
  Map<String, dynamic>? _currentExercise;
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  List<String> _selectedWords = [];
  List<String> _availableWords = [];
  int _correctAnswers = 0;
  int _totalQuestions = 0;
  bool _showResult = false;
  
  // RPG tracking variables
  final Map<String, int> _xpGainedPerWord = {};
  final Map<String, LearningMastery> _wordMastery = {};
  final List<FlashCard> _studiedWords = [];

  @override
  void initState() {
    super.initState();
    _phraseProvider = context.read<PhraseProvider>();
    _generateNextExercise();
  }

  void _generateNextExercise() {
    if (_currentQuestionIndex >= 2) {
      _showResults();
      return;
    }

    final exercises = [
      {
        'type': 'translation',
        'question': 'Translate: ${widget.phrase.phrase}',
        'options': [
          widget.phrase.translation,
          'Incorrect option 1',
          'Incorrect option 2',
          'Incorrect option 3',
        ],
        'correctAnswer': widget.phrase.translation,
      },
      {
        'type': 'sentence_builder',
        'question': 'Build the correct Dutch sentence: ${widget.phrase.translation}',
        'correctOrder': widget.phrase.phrase.split(' '),
        'availableWords': widget.phrase.phrase.split(' ')..shuffle(),
      },
    ];

    setState(() {
      _currentExercise = exercises[_currentQuestionIndex];
      _selectedAnswer = null;
      _selectedWords.clear();
      if (_currentExercise!['type'] == 'sentence_builder') {
        _availableWords = List<String>.from(_currentExercise!['availableWords']);
      }
    });
  }

  void _showResults() {
    // Show comprehensive completion screen directly (skip old results screen)
    _showComprehensiveCompletionScreen();
  }
  
  void _showComprehensiveCompletionScreen() {
    final percentage = _totalQuestions > 0 ? (_correctAnswers / _totalQuestions * 100).round() : 0;
    
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
          hideNavigation: false, // Allow swipe for phrase exercises
          onStudyAgain: () {
            Navigator.of(context).pop(); // Close word progress screen
            _restartExercise();
          },
          onDone: () {
            Navigator.of(context).pop(); // Close word progress screen
            Navigator.of(context).pop(); // Go back to study type screen
          },
        ),
      ),
    );
  }

  void _handleTranslationAnswer(String answer) {
    setState(() {
      _selectedAnswer = answer;
    });

    final isCorrect = answer == _currentExercise!['correctAnswer'];
    
    if (isCorrect) {
      _phraseProvider.markPhraseCorrect(widget.phrase.id);
      HapticService().lightImpact();
      SoundManager().playCorrectSound();
    } else {
      _phraseProvider.markPhraseIncorrect(widget.phrase.id);
      HapticService().heavyImpact();
      SoundManager().playWrongSound();
    }
    
    // Track progress for comprehensive completion screen
    _trackExerciseProgress(isCorrect);

    _totalQuestions++;
    if (isCorrect) _correctAnswers++;

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _currentQuestionIndex++;
        });
        _generateNextExercise();
      }
    });
  }

  void _handleSentenceBuilderWordTap(String word) {
    setState(() {
      _selectedWords.add(word);
      _availableWords.remove(word);
    });
  }

  void _handleSelectedWordTap(String word) {
    setState(() {
      _selectedWords.remove(word);
      _availableWords.add(word);
    });
  }

  void _checkSentenceBuilderAnswer() {
    final correctOrder = _currentExercise!['correctOrder'] as List<String>;
    final isCorrect = SentenceUtils.equalsWithFlexibleDuplicates(_selectedWords, correctOrder);

    if (isCorrect) {
      _phraseProvider.markPhraseCorrect(widget.phrase.id);
      HapticService().lightImpact();
      SoundManager().playCorrectSound();
    } else {
      _phraseProvider.markPhraseIncorrect(widget.phrase.id);
      HapticService().heavyImpact();
      SoundManager().playWrongSound();
    }
    
    // Track progress for comprehensive completion screen
    _trackExerciseProgress(isCorrect);

    _totalQuestions++;
    if (isCorrect) _correctAnswers++;

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _currentQuestionIndex++;
        });
        _generateNextExercise();
      }
    });
  }

  void _trackExerciseProgress(bool wasCorrect) {
    // For phrases, we'll create a simple FlashCard representation for tracking
    final flashCard = FlashCard(
      id: widget.phrase.id,
      word: widget.phrase.phrase,
      definition: widget.phrase.translation,
      example: widget.phrase.phrase,
    );
    
    // Track studied phrases
    if (!_studiedWords.any((word) => word.id == flashCard.id)) {
      _studiedWords.add(flashCard);
    }
    
    // Track word mastery (simplified for phrases)
    _wordMastery[flashCard.id] = LearningMastery();
    
    // Track XP gained with daily decay (game-based)
    if (wasCorrect) {
      final nextXp = flashCard.learningMastery.getXPForGame('phrase_exercise');
      _xpGainedPerWord[flashCard.id] = nextXp; // XP that will actually be gained
    }
  }

  void _restartExercise() {
    setState(() {
      _currentQuestionIndex = 0;
      _correctAnswers = 0;
      _totalQuestions = 0;
      _showResult = false;
      
      // Reset RPG tracking
      _xpGainedPerWord.clear();
      _wordMastery.clear();
      _studiedWords.clear();
    });
    _generateNextExercise();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentExercise == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Exercise ${_currentQuestionIndex + 1}/2'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / 2,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Exercise content
            Expanded(
              child: _currentExercise!['type'] == 'translation'
                  ? _buildTranslationExercise()
                  : _buildSentenceBuilderExercise(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationExercise() {
    final question = _currentExercise!['question'] as String;
    final options = _currentExercise!['options'] as List<String>;

    return Column(
      children: [
        // Question
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.translate,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  question,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Options
        Expanded(
          child: ListView.builder(
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = _selectedAnswer == option;
              final isCorrect = option == _currentExercise!['correctAnswer'];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(option),
                  onTap: () => _handleTranslationAnswer(option),
                  tileColor: isSelected
                      ? (isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2))
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isSelected
                        ? BorderSide(
                            color: isCorrect ? Colors.green : Colors.red,
                            width: 2,
                          )
                        : BorderSide.none,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSentenceBuilderExercise() {
    final question = _currentExercise!['question'] as String;

    return Column(
      children: [
        // Question
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.build,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  question,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Selected words
        if (_selectedWords.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your sentence:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedWords.map((word) {
                      return Chip(
                        label: Text(word),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        deleteIcon: Icon(
                          Icons.close,
                          size: 18,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        onDeleted: () => _handleSelectedWordTap(word),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Available words
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available words:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableWords.map((word) {
                      return ActionChip(
                        label: Text(word),
                        onPressed: () => _handleSentenceBuilderWordTap(word),
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Check answer button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedWords.isNotEmpty ? _checkSentenceBuilderAnswer : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Check Answer'),
          ),
        ),
      ],
    );
  }
}
