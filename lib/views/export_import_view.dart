import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../services/export_service.dart';
import '../models/flash_card.dart';
import '../models/deck.dart';
import 'enhanced_export_view.dart';

class ExportImportView extends StatefulWidget {
  const ExportImportView({super.key});

  @override
  State<ExportImportView> createState() => _ExportImportViewState();
}

class _ExportImportViewState extends State<ExportImportView> {
  Set<String> _selectedDeckIds = {};
  bool _isExporting = false;
  bool _isImporting = false;
  String? _importResult;
  List<String> _importErrors = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios),
                    iconSize: 20,
                  ),
                  const Spacer(),
                  const Text(
                    'Export & Import',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance the layout
                ],
              ),
            ),
          ),
          
          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Export Section
                  _buildExportSection(),
                  const SizedBox(height: 32),
                  
                  // Import Section
                  _buildImportSection(),
                  const SizedBox(height: 32),
                  
                  // CSV Format Section
                  _buildCSVFormatSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    final provider = context.read<FlashcardProvider>();
    final decks = provider.getAllDecksHierarchical();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Export',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Export your flashcards to CSV format',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        
        // Deck Selection
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Decks to Export',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _selectAllDecks,
                          child: const Text('Select All'),
                        ),
                        TextButton(
                          onPressed: _deselectAllDecks,
                          child: const Text('Select None'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_selectedDeckIds.length} of ${decks.length} decks selected',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                ...decks.map((deck) => _buildDeckCheckbox(deck)).toList(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Export Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _selectedDeckIds.isEmpty ? null : _navigateToEnhancedExport,
            icon: const Icon(Icons.file_download),
            label: const Text('Export Selected Decks'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeckCheckbox(Deck deck) {
    final isSelected = _selectedDeckIds.contains(deck.id);
    final provider = context.read<FlashcardProvider>();
    final deckCards = deck.isSubDeck 
        ? provider.getCardsForDeck(deck.id)
        : provider.getCardsForDeckWithSubDecks(deck.id);
    
    return CheckboxListTile(
      title: Row(
        children: [
          if (deck.isSubDeck) ...[
            const SizedBox(width: 16),
            const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              deck.name,
              style: TextStyle(
                fontWeight: deck.isSubDeck ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        deck.isSubDeck 
            ? '${deckCards.length} cards'
            : '${deckCards.length} cards (including sub-decks)',
      ),
      value: isSelected,
      onChanged: (value) {
        setState(() {
          if (value == true) {
            _selectedDeckIds.add(deck.id);
          } else {
            _selectedDeckIds.remove(deck.id);
          }
        });
      },
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildImportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Import',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Import flashcards from CSV format',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        
        // Import Button
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
                : const Icon(Icons.file_upload),
            label: Text(_isImporting ? 'Importing...' : 'Import from CSV'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        // Import Result
        if (_importResult != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _importErrors.isEmpty 
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _importErrors.isEmpty 
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _importResult!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _importErrors.isEmpty ? Colors.green : Colors.orange,
                  ),
                ),
                if (_importErrors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._importErrors.map((error) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $error',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  )).toList(),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCSVFormatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CSV Format',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CSV Structure',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildCSVField('Word (required)'),
                _buildCSVField('Definition (required)'),
                _buildCSVField('Example (optional)'),
                _buildCSVField('Article (optional: de/het)'),
                _buildCSVField('Plural (optional)'),
                _buildCSVField('Past Tense (optional)'),
                _buildCSVField('Future Tense (optional)'),
                _buildCSVField('Past Participle (optional)'),
                _buildCSVField('Decks (optional: separated by ;)'),
                _buildCSVField('Success Count (optional)'),
                _buildCSVField('Times Shown (optional)'),
                _buildCSVField('Times Correct (optional)'),
                
                const SizedBox(height: 16),
                Text(
                  'Example',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '''Word,Definition,Example,Article,Plural,Past Tense,Future Tense,Past Participle,Decks,Success Count,Times Shown,Times Correct
Hallo,Hello,"Hallo, hoe gaat het?",,,,,"A1 - Basics",5,10,8
Brood,Bread,"Ik eet brood met kaas",het,broden,,,"A1 - Food & Drinks; Basics",3,5,3''',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCSVField(String field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '• $field',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  void _selectAllDecks() {
    final provider = context.read<FlashcardProvider>();
    final allDeckIds = provider.getAllDecksHierarchical().map((deck) => deck.id).toSet();
    setState(() {
      _selectedDeckIds = allDeckIds;
    });
  }

  void _deselectAllDecks() {
    setState(() {
      _selectedDeckIds.clear();
    });
  }

  void _navigateToEnhancedExport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedExportView(
          selectedDeckIds: _selectedDeckIds,
        ),
      ),
    );
  }

  Future<void> _exportToCSV() async {
    if (_selectedDeckIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one deck to export')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final provider = context.read<FlashcardProvider>();
      final dutchProvider = context.read<DutchWordExerciseProvider>();
      
      // Get all exercises for the selected decks
      final allExercises = dutchProvider.wordExercises;
      
      final csvContent = provider.exportUnifiedCSV(_selectedDeckIds, exercises: allExercises);
      
      // Save file using FilePicker for mobile compatibility
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save FlashCards Export',
        fileName: 'FlashCards_Export_$timestamp.csv',
        allowedExtensions: ['csv'],
        type: FileType.custom,
        bytes: utf8.encode(csvContent), // Convert string to bytes for mobile
      );
      
      // Show success message
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export successful! File saved to your device.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
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

  Future<void> _importFromCSV() async {
    setState(() {
      _isImporting = true;
      _importResult = null;
      _importErrors = [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (file.path != null) {
          final csvContent = await File(file.path!).readAsString();
          final provider = context.read<FlashcardProvider>();
          final result = await provider.importFromCSV(csvContent);
          
          setState(() {
            _importResult = 'Imported ${result['success']} cards successfully';
            _importErrors = List<String>.from(result['errors'] ?? []);
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
} 