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
        title: const Text('Import/Export'),
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
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Import/Export Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Import your flashcards from CSV files or export your current data for backup. '
              'Supported formats include word lists, exercises, and complete deck structures.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Import: Add new cards and exercises from CSV files\n'
              '• Export: Save your data as CSV files for backup\n'
              '• Format: Use standard CSV format with headers',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _importFromCSV,
                icon: _isImporting 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_isImporting ? 'Importing...' : 'Import Data'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_selectedFileName != null) ...[
              const SizedBox(height: 8),
              Text(
                _selectedFileName!,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToEnhancedExport(),
                icon: const Icon(Icons.download),
                label: const Text('Export Data'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
      print('🔍 Starting CSV import...');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        print('🔍 Selected file: ${file.name}, size: ${file.size} bytes');
        
        setState(() {
          _selectedFileName = file.name;
        });

        if (file.path != null) {
          print('🔍 Reading file from path: ${file.path}');
          final csvContent = await File(file.path!).readAsString();
          print('🔍 CSV content length: ${csvContent.length} characters');
          print('🔍 CSV content preview: ${csvContent.substring(0, csvContent.length > 200 ? 200 : csvContent.length)}...');
          
          final flashcardProvider = context.read<FlashcardProvider>();
          final dutchProvider = context.read<DutchWordExerciseProvider>();

          // Parse the CSV to get both cards and exercises
          print('🔍 Parsing CSV with UnifiedImportService...');
          final parseResult = await UnifiedImportService.parseUnifiedCSV(csvContent);
          
          final cards = parseResult['cards'] as List<FlashCard>? ?? [];
          final exercises = parseResult['exercises'] as List<DutchWordExercise>? ?? [];
          final parseErrors = parseResult['errors'] as List<String>? ?? [];
          final errors = <String>[];
          
          print('🔍 Parse result: ${cards.length} cards, ${exercises.length} exercises, ${parseErrors.length} errors');
          
          // Add parsing errors to the error list
          errors.addAll(parseErrors);

          // Import cards using FlashcardProvider
          var cardSuccessCount = 0;
          var skippedCount = 0;
          
          print('🔍 Starting card import...');
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
              print('🔍 Skipping duplicate card: ${card.word}');
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
              print('🔍 Successfully created card: ${card.word}');
            } else {
              print('🔍 Failed to create card: ${card.word}');
              errors.add('Failed to create card: ${card.word}');
            }
          }

          // Import exercises using DutchWordExerciseProvider
          var exerciseSuccessCount = 0;
          print('🔍 Starting exercise import...');
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
              print('🔍 Skipping duplicate exercise: ${exercise.targetWord}');
              continue; // Skip duplicate
            }
            
            // Add the exercise
            await dutchProvider.addWordExercise(exercise);
            exerciseSuccessCount++;
            print('🔍 Successfully created exercise: ${exercise.targetWord}');
          }

          print('🔍 Import completed: $cardSuccessCount cards, $exerciseSuccessCount exercises, $skippedCount skipped');

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
          print('🔍 File path is null');
          setState(() {
            _importResult = 'Import failed';
            _importErrors = ['Could not read file - file path is null'];
          });
        }
      } else {
        print('🔍 No file selected');
        setState(() {
          _importResult = 'Import cancelled';
          _importErrors = ['No file selected'];
        });
      }
    } catch (e) {
      print('🔍 Import error: $e');
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