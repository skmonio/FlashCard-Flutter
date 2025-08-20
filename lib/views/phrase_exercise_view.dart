import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/phrase.dart';
import '../providers/phrase_provider.dart';
import '../services/sound_manager.dart';
import '../services/haptic_service.dart';

class PhraseExerciseView extends StatefulWidget {
  final Phrase phrase;

  const PhraseExerciseView({super.key, required this.phrase});

  @override
  State<PhraseExerciseView> createState() => _PhraseExerciseViewState();
}

class _PhraseExerciseViewState extends State<PhraseExerciseView> {
  late PhraseProvider _phraseProvider;
  Map<String, dynamic>? _currentExercise;
  String _exerciseType = 'translation'; // 'translation' or 'sentence_builder'
  int _currentQuestionIndex = 0;
  int _correctAnswers = 0;
  int _totalQuestions = 0;
  bool _showResult = false;
  String? _selectedAnswer;
  List<String> _selectedWords = [];
  List<String> _availableWords = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phraseProvider = context.read<PhraseProvider>();
      _generateNextExercise();
    });
  }

  void _generateNextExercise() {
    if (_currentQuestionIndex >= 2) { // 2 exercises per phrase
      _showResults();
      return;
    }

    setState(() {
      _exerciseType = _currentQuestionIndex == 0 ? 'translation' : 'sentence_builder';
      _currentExercise = _exerciseType == 'translation'
          ? _phraseProvider.generateTranslationExercise(widget.phrase)
          : _phraseProvider.generateSentenceBuilderExercise(widget.phrase);
      _selectedAnswer = null;
      _selectedWords = [];
      _availableWords = _currentExercise!['shuffledWords'] ?? [];
      _showResult = false;
    });
  }

  void _showResults() {
    setState(() {
      _showResult = true;
    });
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
    final isCorrect = listEquals(_selectedWords, correctOrder);

    if (isCorrect) {
      _phraseProvider.markPhraseCorrect(widget.phrase.id);
      HapticService().lightImpact();
      SoundManager().playCorrectSound();
    } else {
      _phraseProvider.markPhraseIncorrect(widget.phrase.id);
      HapticService().heavyImpact();
      SoundManager().playWrongSound();
    }

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

  void _restartExercise() {
    setState(() {
      _currentQuestionIndex = 0;
      _correctAnswers = 0;
      _totalQuestions = 0;
      _showResult = false;
    });
    _generateNextExercise();
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return _buildResultsScreen();
    }

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
              child: _exerciseType == 'translation'
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
                color: isSelected
                    ? (isCorrect ? Colors.green : Colors.red)
                    : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    option,
                    style: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          isCorrect ? Icons.check : Icons.close,
                          color: Colors.white,
                        )
                      : null,
                  onTap: _selectedAnswer == null
                      ? () => _handleTranslationAnswer(option)
                      : null,
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

        // Selected words (answer area)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your answer:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedWords.map((word) {
                  return ActionChip(
                    label: Text(word),
                    onPressed: () => _handleSelectedWordTap(word),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Available words
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available words:',
                style: Theme.of(context).textTheme.titleSmall,
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

  Widget _buildResultsScreen() {
    final percentage = _totalQuestions > 0 ? (_correctAnswers / _totalQuestions * 100).round() : 0;
    final isPerfect = _correctAnswers == _totalQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Complete'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPerfect ? Icons.celebration : Icons.emoji_events,
              size: 80,
              color: isPerfect ? Colors.amber : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              isPerfect ? 'Perfect!' : 'Good job!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You got $_correctAnswers out of $_totalQuestions correct',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '$percentage%',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _restartExercise,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Practice Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
