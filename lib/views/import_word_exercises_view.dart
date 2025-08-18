import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../providers/dutch_word_exercise_provider.dart';

class ImportWordExercisesView extends StatefulWidget {
  final VoidCallback? onImportComplete;
  
  const ImportWordExercisesView({
    super.key,
    this.onImportComplete,
  });

  @override
  State<ImportWordExercisesView> createState() => _ImportWordExercisesViewState();
}

class _ImportWordExercisesViewState extends State<ImportWordExercisesView> {
  bool _isImporting = false;
  String? _selectedFileName;
  String? _error;
  String? _successMessage;
  Map<String, dynamic>? _importData;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Word Exercises'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionRow(
                      '1',
                      'Select a JSON or CSV file containing Dutch word exercises'
                    ),
                    _buildInstructionRow(
                      '2',
                      'The file should be exported from this app or follow the same format'
                    ),
                    _buildInstructionRow(
                      '3',
                      'Decks will be imported with their original structure'
                    ),
                    _buildInstructionRow(
                      '4',
                      'Review the import data before confirming'
                    ),
                    _buildInstructionRow(
                      '5',
                      'Existing exercises with the same ID will be updated'
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // File selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select File',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isImporting ? null : _pickFile,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('Choose File'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedFileName ?? 'No file selected',
                            style: TextStyle(
                              color: _selectedFileName != null 
                                  ? Colors.green 
                                  : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            if (_importData != null) ...[
              const SizedBox(height: 16),
              
              // Import preview
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Import Preview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPreviewRow('Version', _importData!['metadata']['version'] ?? 'Unknown'),
                      _buildPreviewRow('Author', _importData!['metadata']['author'] ?? 'Unknown'),
                      _buildPreviewRow('Description', _importData!['metadata']['description'] ?? 'No description'),
                      _buildPreviewRow('Export Date', _importData!['metadata']['exportDate'] ?? 'Unknown'),
                      _buildPreviewRow('Total Words', '${(_importData!['exercises'] as List).length}'),
                      _buildPreviewRow('Total Questions', '${(_importData!['exercises'] as List).fold<int>(0, (sum, e) => sum + (e['exercises'] as List).length)}'),
                      _buildPreviewRow('Decks', _getDeckCount(_importData!['exercises'])),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Import button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isImporting ? null : _importExercises,
                  icon: _isImporting 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isImporting ? 'Importing...' : 'Import Exercises'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
            
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
            
            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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

  Widget _buildPreviewRow(String label, String value) {
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
        withData: true, // Ensure we get the file data
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _error = null;
          _successMessage = null;
          _importData = null;
        });

        // Read and parse the file
        await _parseFile(file);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick file: $e';
      });
    }
  }

  Future<void> _parseFile(PlatformFile file) async {
    try {
      String fileContent;
      
      // Try to read from bytes first
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        fileContent = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        // If bytes are empty, try reading from file path
        final fileObj = File(file.path!);
        if (await fileObj.exists()) {
          fileContent = await fileObj.readAsString();
        } else {
          throw Exception('File does not exist at path: ${file.path}');
        }
      } else {
        throw Exception('File has no content and no path available');
      }
      
      if (fileContent.trim().isEmpty) {
        throw Exception('File content is empty after reading');
      }

      // Determine file type and parse accordingly
      if (file.name.toLowerCase().endsWith('.json')) {
        await _parseJsonFile(fileContent);
      } else if (file.name.toLowerCase().endsWith('.csv')) {
        await _parseCsvFile(fileContent);
      } else {
        throw Exception('Unsupported file format. Please use JSON or CSV files.');
      }

    } catch (e) {
      setState(() {
        _error = 'Failed to parse file: $e\nFile size: ${file.bytes?.length ?? 0} bytes\nPath: ${file.path ?? 'No path'}';
        _selectedFileName = null;
      });
    }
  }

  Future<void> _parseJsonFile(String fileContent) async {
    final data = json.decode(fileContent);

    // Validate the import data structure
    if (data is! Map<String, dynamic> || 
        !data.containsKey('metadata') || 
        !data.containsKey('exercises')) {
      throw Exception('Invalid JSON format. Expected JSON with metadata and exercises.');
    }

    setState(() {
      _importData = data;
    });
  }

  Future<void> _parseCsvFile(String fileContent) async {
    final lines = fileContent.split('\n');
    if (lines.length < 2) {
      throw Exception('CSV file is empty or has no data rows. Found ${lines.length} lines.');
    }

    // Debug: Show first few lines
    print('CSV Debug - First 3 lines:');
    for (int i = 0; i < lines.length && i < 3; i++) {
      print('Line $i: "${lines[i]}"');
    }

    // Parse header
    final headers = lines[0].split(',').map((h) => h.trim().replaceAll('"', '')).toList();
    
    // Expected headers for CSV import
    final expectedHeaders = ['Deck', 'Word', 'Translation', 'Exercise Type', 'Question', 'Correct Answer', 'Options', 'Explanation'];
    
    // Validate headers
    for (final expectedHeader in expectedHeaders) {
      if (!headers.contains(expectedHeader)) {
        throw Exception('Invalid CSV format. Missing required header: $expectedHeader');
      }
    }

    // Parse data rows and group by word
    final Map<String, Map<String, dynamic>> wordMap = {};

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final values = _parseCsvLine(line);
      if (values.length < headers.length) continue;

      final deckName = values[headers.indexOf('Deck')].trim();
      final word = values[headers.indexOf('Word')].trim();
      final translation = values[headers.indexOf('Translation')].trim();
      final exerciseType = values[headers.indexOf('Exercise Type')].trim();
      final question = values[headers.indexOf('Question')].trim();
      final correctAnswer = values[headers.indexOf('Correct Answer')].trim();
      final options = values[headers.indexOf('Options')].trim();
      final explanation = values[headers.indexOf('Explanation')].trim();

      // Create unique key for each word
      final wordKey = '${deckName}_${word}';
      
      // Create word if it doesn't exist
      if (!wordMap.containsKey(wordKey)) {
        wordMap[wordKey] = {
          'id': '${DateTime.now().millisecondsSinceEpoch}_${wordMap.length}',
          'targetWord': word,
          'wordTranslation': translation,
          'deckId': deckName.toLowerCase().replaceAll(' ', '_'),
          'deckName': deckName,
          'category': 'common',
          'difficulty': 'beginner',
          'exercises': <Map<String, dynamic>>[],
          'createdAt': DateTime.now().toIso8601String(),
          'isUserCreated': true,
        };
      }

      // Add exercise to word
      wordMap[wordKey]!['exercises'].add({
        'id': '${DateTime.now().millisecondsSinceEpoch}_${wordMap.length}_${wordMap[wordKey]!['exercises'].length}',
        'type': _convertExerciseType(exerciseType),
        'prompt': question,
        'options': _parseOptions(options, exerciseType),
        'correctAnswer': correctAnswer,
        'explanation': explanation,
        'difficulty': 'beginner',
      });
    }

    // Convert to the expected format
    final importData = {
      'metadata': {
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'format': 'csv',
      },
      'exercises': wordMap.values.toList(),
    };

    setState(() {
      _importData = importData;
    });
  }

  List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    String current = '';
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    
    result.add(current.trim());
    return result;
  }

  String _convertExerciseType(String csvType) {
    switch (csvType.toLowerCase()) {
      case 'sentence building':
        return 'sentenceBuilding';
      case 'multiple choice':
        return 'multipleChoice';
      case 'fill in the blank':
      case 'fill in blank':
        return 'fillInBlank';
      default:
        return 'multipleChoice'; // Default fallback
    }
  }

  List<String> _parseOptions(String options, String exerciseType) {
    if (options.isEmpty) return [];
    
    // Helper function to clean options by removing numbers in parentheses
    String cleanOption(String option) {
      String cleaned = option;
      
      // First try the regex approach
      cleaned = cleaned.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '');
      
      // If that didn't work, try a simpler approach
      if (cleaned == option) {
        // Look for the pattern manually
        final lastParenIndex = cleaned.lastIndexOf('(');
        if (lastParenIndex != -1) {
          final afterParen = cleaned.substring(lastParenIndex);
          if (RegExp(r'^\(\d+\)\s*$').hasMatch(afterParen)) {
            cleaned = cleaned.substring(0, lastParenIndex).trim();
          }
        }
      }
      
      return cleaned.trim();
    }
    
    // For sentence building, the options are individual words that should be shuffled
    // For other exercise types, they are different answer choices
    if (exerciseType.toLowerCase() == 'sentence building') {
      // Handle both semicolon and pipe separators for sentence building words
      if (options.contains(';')) {
        return options.split(';').map((opt) => cleanOption(opt.trim())).toList();
      } else if (options.contains('|')) {
        return options.split('|').map((opt) => cleanOption(opt.trim())).toList();
      } else {
        return [cleanOption(options.trim())];
      }
    } else {
      // For multiple choice and fill in blank, handle as before
      if (options.contains(';')) {
        return options.split(';').map((opt) => cleanOption(opt.trim())).toList();
      } else if (options.contains('|')) {
        return options.split('|').map((opt) => cleanOption(opt.trim())).toList();
      } else {
        return [cleanOption(options.trim())];
      }
    }
  }

  Future<void> _importExercises() async {
    if (_importData == null) return;

    setState(() {
      _isImporting = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final provider = context.read<DutchWordExerciseProvider>();
      final jsonString = json.encode(_importData);
      await provider.importFromJson(jsonString);

      setState(() {
        _isImporting = false;
        _successMessage = 'Exercises imported successfully!';
        _importData = null;
        _selectedFileName = null;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercises imported successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Notify parent to refresh
      if (widget.onImportComplete != null) {
        widget.onImportComplete!();
      }

    } catch (e) {
      setState(() {
        _isImporting = false;
        _error = 'Import failed: $e';
      });
    }
  }

  String _getDeckCount(List exercises) {
    final Set<String> deckIds = {};
    for (final exercise in exercises) {
      final deckId = exercise['deckId'] ?? 'default';
      deckIds.add(deckId);
    }
    return '${deckIds.length} decks';
  }
} 