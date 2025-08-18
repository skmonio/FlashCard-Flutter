import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../services/export_service.dart';
import '../models/flash_card.dart';
import '../models/dutch_word_exercise.dart';

class EnhancedExportView extends StatefulWidget {
  final Set<String>? selectedDeckIds;
  
  const EnhancedExportView({
    Key? key,
    this.selectedDeckIds,
  }) : super(key: key);

  @override
  State<EnhancedExportView> createState() => _EnhancedExportViewState();
}

class _EnhancedExportViewState extends State<EnhancedExportView> {
  String _selectedFormat = ExportService.formatCSV;
  String _selectedContent = ExportService.contentBoth;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Format Selection
            _buildSectionTitle('Export Format'),
            const SizedBox(height: 8),
            _buildFormatSelection(),
            const SizedBox(height: 24),
            
            // Content Selection
            _buildSectionTitle('Export Content'),
            const SizedBox(height: 8),
            _buildContentSelection(),
            const SizedBox(height: 24),
            
            // Preview
            _buildSectionTitle('Preview'),
            const SizedBox(height: 8),
            _buildPreview(),
            const SizedBox(height: 24),
            
            // Export Button
            _buildExportButton(),
            const SizedBox(height: 24), // Add extra padding at bottom for better scrolling
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildFormatSelection() {
    return Card(
      child: Column(
        children: [
          RadioListTile<String>(
            title: Row(
              children: [
                Icon(Icons.table_chart, color: Colors.green),
                const SizedBox(width: 8),
                const Text('CSV Format'),
              ],
            ),
            subtitle: const Text('Compatible with Excel, Google Sheets, and other spreadsheet applications'),
            value: ExportService.formatCSV,
            groupValue: _selectedFormat,
            onChanged: (value) {
              setState(() {
                _selectedFormat = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: Row(
              children: [
                Icon(Icons.code, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('JSON Format'),
              ],
            ),
            subtitle: const Text('Structured data format, good for programming and data analysis'),
            value: ExportService.formatJSON,
            groupValue: _selectedFormat,
            onChanged: (value) {
              setState(() {
                _selectedFormat = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContentSelection() {
    return Card(
      child: Column(
        children: [
          RadioListTile<String>(
            title: Row(
              children: [
                Icon(Icons.style, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Cards Only'),
              ],
            ),
            subtitle: const Text('Export only flashcard data (words, definitions, examples, etc.)'),
            value: ExportService.contentCards,
            groupValue: _selectedContent,
            onChanged: (value) {
              setState(() {
                _selectedContent = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: Row(
              children: [
                Icon(Icons.quiz, color: Colors.purple),
                const SizedBox(width: 8),
                const Text('Exercises Only'),
              ],
            ),
            subtitle: const Text('Export only exercise data (questions, answers, options)'),
            value: ExportService.contentExercises,
            groupValue: _selectedContent,
            onChanged: (value) {
              setState(() {
                _selectedContent = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: Row(
              children: [
                Icon(Icons.integration_instructions, color: Colors.teal),
                const SizedBox(width: 8),
                const Text('Cards & Exercises'),
              ],
            ),
            subtitle: const Text('Export both flashcard and exercise data together'),
            value: ExportService.contentBoth,
            groupValue: _selectedContent,
            onChanged: (value) {
              setState(() {
                _selectedContent = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Consumer2<FlashcardProvider, DutchWordExerciseProvider>(
      builder: (context, flashcardProvider, exerciseProvider, child) {
        final cards = _getCardsToExport(flashcardProvider);
        final exercises = _getExercisesToExport(exerciseProvider, cards);
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Export Summary',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPreviewRow('Cards to export:', '${cards.length}'),
                _buildPreviewRow('Exercises to export:', '${exercises.length}'),
                _buildPreviewRow('Format:', _selectedFormat.toUpperCase()),
                _buildPreviewRow('Content:', _getContentDescription()),
                if (widget.selectedDeckIds != null && widget.selectedDeckIds!.isNotEmpty)
                  _buildPreviewRow('Selected decks:', '${widget.selectedDeckIds!.length}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getContentDescription() {
    switch (_selectedContent) {
      case ExportService.contentCards:
        return 'Cards Only';
      case ExportService.contentExercises:
        return 'Exercises Only';
      case ExportService.contentBoth:
        return 'Cards & Exercises';
      default:
        return 'Unknown';
    }
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isExporting ? null : _exportData,
        icon: _isExporting 
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.download),
        label: Text(_isExporting ? 'Exporting...' : 'Export Data'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  List<FlashCard> _getCardsToExport(FlashcardProvider provider) {
    if (widget.selectedDeckIds != null && widget.selectedDeckIds!.isNotEmpty) {
      // Export selected decks
      final allCards = <FlashCard>{};
      for (final deckId in widget.selectedDeckIds!) {
        final deckCards = provider.getCardsForDeckWithSubDecks(deckId);
        allCards.addAll(deckCards);
      }
      return allCards.toList();
    } else {
      // Export all cards
      return provider.cards;
    }
  }

  List<DutchWordExercise> _getExercisesToExport(
    DutchWordExerciseProvider provider, 
    List<FlashCard> cards
  ) {
    if (_selectedContent == ExportService.contentExercises) {
      // Export all exercises
      return provider.wordExercises;
    } else {
      // Export only exercises for the selected cards
      final cardWords = cards.map((card) => card.word).toSet();
      return provider.wordExercises
          .where((exercise) => cardWords.contains(exercise.targetWord))
          .toList();
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final flashcardProvider = context.read<FlashcardProvider>();
      final exerciseProvider = context.read<DutchWordExerciseProvider>();
      
      final cards = _getCardsToExport(flashcardProvider);
      final exercises = _getExercisesToExport(exerciseProvider, cards);
      
      // Generate export content
      final exportContent = ExportService.export(
        format: _selectedFormat,
        content: _selectedContent,
        cards: cards,
        exercises: exercises,
        decks: flashcardProvider.decks,
      );
      
      // Generate filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final contentSuffix = _selectedContent == ExportService.contentBoth 
          ? 'unified' 
          : _selectedContent;
      final filename = 'flashcards_${contentSuffix}_export_$timestamp.${_selectedFormat}';
      
      // Save file
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Export File',
        fileName: filename,
        allowedExtensions: [_selectedFormat],
        type: FileType.custom,
        bytes: utf8.encode(exportContent),
      );
      
      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export successful! File saved as: $filename'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
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
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}
