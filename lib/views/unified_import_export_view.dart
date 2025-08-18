import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../services/unified_import_service.dart';
import '../services/export_service.dart';
import '../models/flash_card.dart';
import '../models/dutch_word_exercise.dart';
import '../models/deck.dart';
import 'enhanced_export_view.dart';

class UnifiedImportExportView extends StatefulWidget {
  const UnifiedImportExportView({super.key});

  @override
  State<UnifiedImportExportView> createState() => _UnifiedImportExportViewState();
}

class _UnifiedImportExportViewState extends State<UnifiedImportExportView> {
  bool _isImporting = false;
  bool _isExporting = false;
  String? _importResult;
  List<String> _importErrors = [];
  String? _selectedFileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unified Import/Export'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection(),
            const SizedBox(height: 24),
            _buildImportSection(),
            const SizedBox(height: 24),
            _buildExportSection(),
            const SizedBox(height: 24),
            if (_importResult != null) _buildResultSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Unified Import/Export',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This system allows you to import and export both flashcards and exercises in a single CSV file. '
              'Words can have basic information (definition, example, etc.) and optional exercises (multiple choice, fill in blank, sentence building).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'CSV Format: Word, Definition, Example, Article, Plural, Past Tense, Future Tense, Past Participle, Decks, Exercise Type, Question, Correct Answer, Options, Explanation',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: Colors.grey[100],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Import flashcards and exercises from a CSV file. The system will automatically create both flashcards and exercises for words that have exercise data.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isImporting ? null : _importFromCSV,
                    icon: _isImporting 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_isImporting ? 'Importing...' : 'Import CSV'),
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedFileName != null)
                  Expanded(
                    child: Text(
                      _selectedFileName!,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Export your flashcards and exercises with flexible options. Choose between CSV or JSON format, and export cards only, exercises only, or both together.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _navigateToEnhancedExport(),
              icon: const Icon(Icons.download),
              label: const Text('Export Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEnhancedExport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EnhancedExportView(),
      ),
    );
  }

  Widget _buildResultSection() {
    return Card(
      color: _importErrors.isNotEmpty ? Colors.red[50] : Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _importErrors.isNotEmpty ? Icons.error : Icons.check_circle,
                  color: _importErrors.isNotEmpty ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _importErrors.isNotEmpty ? 'Import Errors' : 'Import Successful',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _importErrors.isNotEmpty ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_importResult!),
            if (_importErrors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Errors:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 4),
              ...(_importErrors.map((error) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Text(
                  '• $error',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ))),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _importFromCSV() async {
    setState(() {
      _isImporting = true;
      _importResult = null;
      _importErrors = [];
      _selectedFileName = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
        });

        if (file.path != null) {
          final csvContent = await File(file.path!).readAsString();
          final flashcardProvider = context.read<FlashcardProvider>();
          final dutchProvider = context.read<DutchWordExerciseProvider>();

          // Parse the CSV to get both cards and exercises
          final parseResult = await UnifiedImportService.parseUnifiedCSV(csvContent);
          
          final cards = parseResult['cards'] as List<FlashCard>? ?? [];
          final exercises = parseResult['exercises'] as List<DutchWordExercise>? ?? [];
          final parseErrors = parseResult['errors'] as List<String>? ?? [];
          final errors = <String>[];
          
          // Add parsing errors to the error list
          errors.addAll(parseErrors);

          // Import cards using FlashcardProvider
          var cardSuccessCount = 0;
          var skippedCount = 0;
          
          for (final card in cards) {
            // Check for duplicates
            final existingCard = flashcardProvider.cards.firstWhere(
              (existing) => existing.word.toLowerCase() == card.word.toLowerCase(),
              orElse: () => FlashCard(
                id: '',
                word: '',
                definition: '',
                example: '',
              ),
            );
            
            if (existingCard.id.isNotEmpty) {
              skippedCount++;
              continue;
            }
            
            // Fix deck assignment - create decks if they don't exist
            final actualDeckIds = <String>{};
            print('🔍 Processing card: ${card.word} with deckIds: ${card.deckIds}');
            
            for (final deckId in card.deckIds) {
              final deckName = deckId.replaceAll('_', ' ');
              print('🔍 Looking for deck: "$deckName"');
              
              // Try to find existing deck by name (case-insensitive)
              final existingDeck = flashcardProvider.decks.firstWhere(
                (deck) => deck.name.toLowerCase() == deckName.toLowerCase(),
                orElse: () => Deck(id: '', name: '', parentId: null),
              );
              
              if (existingDeck.id.isNotEmpty) {
                print('🔍 Found existing deck: "${existingDeck.name}" (${existingDeck.id})');
                actualDeckIds.add(existingDeck.id);
              } else {
                print('🔍 Creating new deck: "$deckName"');
                // Create the deck if it doesn't exist
                final newDeck = await flashcardProvider.createDeck(deckName);
                if (newDeck != null) {
                  print('🔍 Created deck: "${newDeck.name}" (${newDeck.id})');
                  actualDeckIds.add(newDeck.id);
                }
              }
            }
            
            print('🔍 Final deck IDs for ${card.word}: $actualDeckIds');
            
            // If no decks found, add to Uncategorized
            if (actualDeckIds.isEmpty) {
              final uncategorizedDeck = flashcardProvider.decks.firstWhere(
                (deck) => deck.name == 'Uncategorized',
                orElse: () => Deck(id: '', name: '', parentId: null),
              );
              if (uncategorizedDeck.id.isNotEmpty) {
                actualDeckIds.add(uncategorizedDeck.id);
              }
            }
            
            final newCard = await flashcardProvider.createCard(
              word: card.word,
              definition: card.definition,
              example: card.example,
              deckIds: actualDeckIds,
              article: card.article,
              plural: card.plural,
              pastTense: card.pastTense,
              futureTense: card.futureTense,
              pastParticiple: card.pastParticiple,
            );
            
            if (newCard != null) {
              cardSuccessCount++;
            }
          }

          // Import exercises using DutchWordExerciseProvider
          var exerciseSuccessCount = 0;
          for (final exercise in exercises) {
            // Check for duplicates
            final existingExercise = dutchProvider.wordExercises.firstWhere(
              (existing) => existing.targetWord.toLowerCase() == exercise.targetWord.toLowerCase(),
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
            
            if (existingExercise.id.isNotEmpty) {
              continue; // Skip duplicate
            }
            
            // Add the exercise
            await dutchProvider.addWordExercise(exercise);
            exerciseSuccessCount++;
          }

          setState(() {
            if (errors.isNotEmpty) {
              _importResult = 'Import completed with errors. '
                  'Imported $cardSuccessCount cards and $exerciseSuccessCount exercises. '
                  'Skipped $skippedCount duplicate cards.';
            } else {
              _importResult = 'Import completed successfully! '
                  'Imported $cardSuccessCount cards and $exerciseSuccessCount exercises. '
                  'Skipped $skippedCount duplicate cards.';
            }
            _importErrors = List<String>.from(errors);
          });
        } else {
          setState(() {
            _importResult = 'Import failed';
            _importErrors = ['Could not read file'];
          });
        }
      }
    } catch (e) {
      setState(() {
        _importResult = 'Import failed';
        _importErrors = [e.toString()];
      });
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  Future<void> _exportToCSV() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final flashcardProvider = context.read<FlashcardProvider>();
      final dutchProvider = context.read<DutchWordExerciseProvider>();

      // Get all deck IDs for export
      final allDeckIds = flashcardProvider.decks.map((d) => d.id).toSet();
      
      // Get all exercises for export
      final allExercises = dutchProvider.wordExercises;
      
      // Export using unified service
      final csvContent = flashcardProvider.exportUnifiedCSV(
        allDeckIds,
        exercises: allExercises,
      );

      // Save file using proper mobile approach
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Unified Export',
        fileName: 'flashcards_unified_export_${DateTime.now().millisecondsSinceEpoch}.csv',
        allowedExtensions: ['csv'],
        type: FileType.custom,
        bytes: utf8.encode(csvContent), // Convert string to bytes for mobile
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }
} 