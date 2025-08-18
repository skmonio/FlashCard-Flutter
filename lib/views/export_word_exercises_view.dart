import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../models/dutch_word_exercise.dart';

class ExportWordExercisesView extends StatefulWidget {
  const ExportWordExercisesView({super.key});

  @override
  State<ExportWordExercisesView> createState() => _ExportWordExercisesViewState();
}

class _ExportWordExercisesViewState extends State<ExportWordExercisesView> {
  bool _isExporting = false;
  String? _exportPath;
  String? _error;
  
  // Export options
  String _exportFormat = 'json'; // 'json' or 'csv'
  String _exportScope = 'all'; // 'all', 'selected'
  Set<String> _selectedDeckIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Word Exercises'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Consumer<DutchWordExerciseProvider>(
        builder: (context, provider, child) {
          final exercises = provider.wordExercises;
          final decks = provider.getDecks();
          final deckNames = provider.getDeckNames();
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Export options
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Options',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Format selection
                        const Text(
                          'Export Format:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('JSON'),
                                value: 'json',
                                groupValue: _exportFormat,
                                onChanged: (value) {
                                  setState(() {
                                    _exportFormat = value!;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('CSV'),
                                value: 'csv',
                                groupValue: _exportFormat,
                                onChanged: (value) {
                                  setState(() {
                                    _exportFormat = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Scope selection
                        const Text(
                          'Export Scope:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: [
                            RadioListTile<String>(
                              title: const Text('All Decks'),
                              subtitle: Text('Export all ${decks.length} decks'),
                              value: 'all',
                              groupValue: _exportScope,
                              onChanged: (value) {
                                setState(() {
                                  _exportScope = value!;
                                  _selectedDeckIds.clear();
                                });
                              },
                            ),
                            RadioListTile<String>(
                              title: const Text('Selected Decks'),
                              subtitle: Text('Export ${_selectedDeckIds.length} selected decks'),
                              value: 'selected',
                              groupValue: _exportScope,
                              onChanged: (value) {
                                setState(() {
                                  _exportScope = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Deck selection (only show if "selected" is chosen)
                if (_exportScope == 'selected') ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Select Decks to Export',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    if (_selectedDeckIds.length == decks.length) {
                                      _selectedDeckIds.clear();
                                    } else {
                                      _selectedDeckIds = decks.toSet();
                                    }
                                  });
                                },
                                child: Text(
                                  _selectedDeckIds.length == decks.length 
                                      ? 'Deselect All' 
                                      : 'Select All',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              itemCount: decks.length,
                              itemBuilder: (context, index) {
                                final deckId = decks[index];
                                final deckName = deckNames[deckId] ?? deckId;
                                final deckExercises = provider.getExercisesByDeck(deckId);
                                final totalExercises = deckExercises.fold<int>(0, (sum, exercise) => sum + exercise.exercises.length);
                                final isSelected = _selectedDeckIds.contains(deckId);
                                
                                return CheckboxListTile(
                                  title: Text(deckName),
                                  subtitle: Text('${deckExercises.length} words • $totalExercises exercises'),
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedDeckIds.add(deckId);
                                      } else {
                                        _selectedDeckIds.remove(deckId);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Info section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Total Words', '${_getExportCount(exercises)}'),
                        _buildInfoRow('Total Questions', '${_getTotalQuestions(exercises)}'),
                        _buildInfoRow('Format', _exportFormat.toUpperCase()),
                        _buildInfoRow('Export Date', DateTime.now().toString().split(' ')[0]),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Export button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : () => _exportExercises(provider),
                    icon: _isExporting 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download),
                    label: Text(_isExporting ? 'Exporting...' : 'Export Exercises'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                if (_exportPath != null) ...[
                  const SizedBox(height: 16),
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
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text(
                              'Export Successful!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('File saved to: $_exportPath'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _shareFile(),
                                icon: const Icon(Icons.share),
                                label: const Text('Share'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openFile(),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Open'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Instructions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Instructions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionRow(
                          '1',
                          'Choose your export format (JSON or CSV)'
                        ),
                        _buildInstructionRow(
                          '2',
                          'Select which decks to export (all or selected)'
                        ),
                        _buildInstructionRow(
                          '3',
                          'Review the export information before confirming'
                        ),
                        _buildInstructionRow(
                          '4',
                          'Use the Share button to send the file via email, messaging, or cloud storage'
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _getExportCount(List<DutchWordExercise> exercises) {
    if (_exportScope == 'all') {
      return exercises.length;
    } else {
      return _selectedDeckIds.length;
    }
  }

  int _getTotalQuestions(List<DutchWordExercise> exercises) {
    if (_exportScope == 'all') {
      return exercises.fold<int>(0, (sum, e) => sum + e.exercises.length);
    } else {
      return exercises
          .where((e) => _selectedDeckIds.contains(e.deckId))
          .fold<int>(0, (sum, e) => sum + e.exercises.length);
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _exportExercises(DutchWordExerciseProvider provider) async {
    setState(() {
      _isExporting = true;
      _error = null;
      _exportPath = null;
    });

    try {
      // Get exercises to export based on selected decks
      final allExercises = provider.wordExercises;
      final exercisesToExport = _exportScope == 'all' 
          ? allExercises 
          : allExercises.where((e) => _selectedDeckIds.contains(e.deckId)).toList();

      if (exercisesToExport.isEmpty) {
        throw Exception('No exercises selected for export');
      }

      // Get the documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _exportFormat == 'json' ? 'json' : 'csv';
      final fileName = 'dutch_word_exercises_$timestamp.$extension';
      final file = File('${directory.path}/$fileName');
      
      if (_exportFormat == 'json') {
        await _exportAsJson(exercisesToExport, file);
      } else {
        await _exportAsCsv(exercisesToExport, file);
      }
      
      setState(() {
        _exportPath = file.path;
        _isExporting = false;
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Decks exported successfully as $_exportFormat!'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      setState(() {
        _error = 'Export failed: $e';
        _isExporting = false;
      });
    }
  }

  Future<void> _exportAsJson(List<DutchWordExercise> exercises, File file) async {
    final import = DutchWordExerciseImport(
      metadata: ImportMetadata(
        version: '1.0',
        exportDate: DateTime.now(),
        description: 'Dutch Word Exercises Export',
        author: 'FlashCard App',
      ),
      exercises: exercises,
    );
    
    final jsonString = jsonEncode(import.toJson());
    await file.writeAsString(jsonString);
  }

  Future<void> _exportAsCsv(List<DutchWordExercise> exercises, File file) async {
    final csvBuffer = StringBuffer();
    
    // Headers
    csvBuffer.writeln('Deck,Word,Translation,Exercise Type,Question,Correct Answer,Options,Explanation');
    
    // Data rows
    for (final exercise in exercises) {
      for (final question in exercise.exercises) {
        final options = question.options.join('; ');
        final row = [
          _escapeCsvField(exercise.deckName),
          _escapeCsvField(exercise.targetWord),
          _escapeCsvField(exercise.wordTranslation),
          _escapeCsvField(question.type.toString().split('.').last),
          _escapeCsvField(question.prompt),
          _escapeCsvField(question.correctAnswer),
          _escapeCsvField(options),
          _escapeCsvField(question.explanation),
        ];
        csvBuffer.writeln(row.join(','));
      }
    }
    
    await file.writeAsString(csvBuffer.toString());
  }
  
  String _escapeCsvField(String field) {
    // Escape quotes and wrap in quotes if contains comma, quote, or newline
    final escaped = field.replaceAll('"', '""');
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  Future<void> _shareFile() async {
    if (_exportPath == null) return;
    
    try {
      // For now, just show a dialog with the file path
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share File'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File saved to:'),
              const SizedBox(height: 8),
              SelectableText(
                _exportPath!,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text('You can copy this path and share the file manually.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openFile() async {
    if (_exportPath == null) return;
    
    try {
      // This would typically open the file with the default app
      // For now, we'll just show a dialog with the file content
      final file = File(_exportPath!);
      final content = await file.readAsString();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export File Content'),
          content: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 