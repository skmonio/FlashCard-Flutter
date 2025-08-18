import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/photo_import_service.dart';
import '../services/translation_service.dart';
import '../providers/flashcard_provider.dart';
import '../components/unified_header.dart';
import '../models/deck.dart';

class PhotoImportView extends StatefulWidget {
  const PhotoImportView({super.key});

  @override
  State<PhotoImportView> createState() => _PhotoImportViewState();
}

class _PhotoImportViewState extends State<PhotoImportView> {
  final PhotoImportService _photoService = PhotoImportService();
  final TranslationService _translationService = TranslationService();
  
  File? _selectedImage;
  List<ExtractedWord> _extractedWords = [];
  Set<String> _selectedWords = {};
  Map<String, String> _translations = {};
  bool _isProcessing = false;
  bool _isLoading = false;
  bool _isPickingImage = false;
  bool _isPickingCamera = false;
  bool _isPickingGallery = false;
  bool _isTranslating = false;
  bool _enableTranslation = true;
  String? _errorMessage;
  String? _selectedDeckId;
  String _newDeckName = '';
  
  /// Check if camera is available
  bool get _isCameraAvailable {
    return _photoService.isCameraAvailable;
  }

  @override
  void dispose() {
    _photoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
          UnifiedHeader(
            title: 'Photo Import',
            onBack: () => Navigator.of(context).pop(),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructions
                  _buildInstructions(),
                  const SizedBox(height: 24),
                  
                  // Image Selection
                  _buildImageSelection(),
                  const SizedBox(height: 24),
                  
                  // Processing Indicator
                  if (_isProcessing) _buildProcessingIndicator(),
                  
                  // Extracted Words
                  if (_extractedWords.isNotEmpty) _buildExtractedWords(),
                  
                  // Translation Toggle
                  if (_extractedWords.isNotEmpty) _buildTranslationToggle(),
                  
                  // Deck Selection
                  if (_selectedWords.isNotEmpty) _buildDeckSelection(),
                  
                  // Error Message
                  if (_errorMessage != null) _buildErrorMessage(),
                  
                  // Action Buttons
                  if (_selectedWords.isNotEmpty) _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.camera_alt,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                'Import Dutch Words',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Take a photo or select an image containing Dutch text. The app will extract words and let you choose which ones to add as flashcards.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Image',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Image preview
        if (_selectedImage != null) ...[
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.error, size: 48, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Action buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_isPickingImage || !_isCameraAvailable) ? null : () => _pickImage(fromCamera: true),
                icon: _isPickingImage && _isPickingCamera
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt),
                label: Text(_isPickingImage && _isPickingCamera ? 'Opening Camera...' : 'Camera'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPickingImage ? null : () => _pickImage(fromCamera: false),
                icon: _isPickingImage && _isPickingGallery
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library),
                label: Text(_isPickingImage && _isPickingGallery ? 'Opening Gallery...' : 'Gallery'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
        
        // Note: Camera and gallery availability will be handled by the system
        // No need for simulator warnings as the system will handle permissions
        
        // Process button
        if (_selectedImage != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processImage,
              icon: _isProcessing 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.text_fields),
              label: Text(_isProcessing ? 'Processing...' : 'Extract Words'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Processing image and extracting text...',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedWords() {
    final provider = context.read<FlashcardProvider>();
    final existingWords = provider.cards.map((card) => card.word.toLowerCase()).toSet();
    
    // Sort words alphabetically and mark duplicates
    final sortedWords = List<ExtractedWord>.from(_extractedWords)
      ..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Extracted Words (${sortedWords.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            TextButton.icon(
              onPressed: _selectedWords.length == sortedWords.length
                  ? _deselectAll
                  : _selectAll,
              icon: Icon(
                _selectedWords.length == sortedWords.length
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
              ),
              label: Text(
                _selectedWords.length == sortedWords.length
                    ? 'Deselect All'
                    : 'Select All',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Words list in alphabetical order
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedWords.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              final extractedWord = sortedWords[index];
              final isSelected = _selectedWords.contains(extractedWord.word);
              final isDuplicate = existingWords.contains(extractedWord.word.toLowerCase());
              
              return ListTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            extractedWord.word,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isDuplicate ? Colors.grey.shade600 : null,
                            ),
                          ),
                        ),
                        if (isDuplicate)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'EXISTS',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_enableTranslation && _translations.containsKey(extractedWord.word))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _translations[extractedWord.word]!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Checkbox(
                  value: isSelected,
                  onChanged: isDuplicate ? null : (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedWords.add(extractedWord.word);
                      } else {
                        _selectedWords.remove(extractedWord.word);
                      }
                    });
                  },
                ),
                onTap: isDuplicate ? null : () {
                  setState(() {
                    if (isSelected) {
                      _selectedWords.remove(extractedWord.word);
                    } else {
                      _selectedWords.add(extractedWord.word);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Translation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Switch(
              value: _enableTranslation,
              onChanged: (value) {
                setState(() {
                  _enableTranslation = value;
                });
                if (value && _translations.isEmpty) {
                  _translateWords();
                }
              },
            ),
          ],
        ),
        if (_enableTranslation) ...[
          const SizedBox(height: 8),
          Text(
            'Automatically translate Dutch words to English',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          if (_isTranslating) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Translating words...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDeckSelection() {
    final provider = context.read<FlashcardProvider>();
    final decks = provider.getAllDecksHierarchical();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Select Deck',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Deck selection dropdown
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDeckId,
              hint: const Text('Select a deck'),
              isExpanded: true,
              items: [
                // Uncategorized option
                const DropdownMenuItem<String>(
                  value: 'uncategorized',
                  child: Text('Uncategorized'),
                ),
                // Existing decks
                ...decks.map((deck) => DropdownMenuItem<String>(
                  value: deck.id,
                  child: Text(deck.name),
                )),
                // Create new deck option
                const DropdownMenuItem<String>(
                  value: 'new_deck',
                  child: Text('+ Create New Deck'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDeckId = value;
                  if (value != 'new_deck') {
                    _newDeckName = '';
                  }
                });
              },
            ),
          ),
        ),
        
        // New deck name input
        if (_selectedDeckId == 'new_deck') ...[
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'New Deck Name',
              border: OutlineInputBorder(),
              hintText: 'Enter deck name',
            ),
            onChanged: (value) {
              setState(() {
                _newDeckName = value;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _addSelectedWords,
            icon: _isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
            label: Text(_isLoading 
              ? 'Adding...' 
              : 'Add ${_selectedWords.length} Word${_selectedWords.length == 1 ? '' : 's'}'
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    setState(() {
      _isPickingImage = true;
      if (fromCamera) {
        _isPickingCamera = true;
      } else {
        _isPickingGallery = true;
      }
      _errorMessage = null;
    });

    try {
      print('PhotoImportView: Starting image picker...');
      
      // Add timeout to prevent hanging
      final image = await _photoService.pickImage(fromCamera: fromCamera)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        print('PhotoImportView: Image picker timed out');
        return null;
      });
      
      if (image != null) {
        print('PhotoImportView: Image selected successfully');
        setState(() {
          _selectedImage = image;
          _extractedWords = [];
          _selectedWords = {};
          _translations = {};
          _errorMessage = null;
        });
      } else {
        print('PhotoImportView: No image selected or error occurred');
        setState(() {
          _errorMessage = 'No image selected or file is too large. Please try a smaller image.';
        });
      }
    } catch (e) {
      print('PhotoImportView: Error picking image: $e');
      setState(() {
        _errorMessage = 'Error accessing ${fromCamera ? 'camera' : 'gallery'}: $e';
      });
    } finally {
      setState(() {
        _isPickingImage = false;
        _isPickingCamera = false;
        _isPickingGallery = false;
      });
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      print('PhotoImportView: Starting image processing...');
      
      // Add timeout to prevent hanging during OCR
      final words = await _photoService.extractWordsWithPosition(_selectedImage!.path)
          .timeout(const Duration(seconds: 60), onTimeout: () {
        print('PhotoImportView: OCR processing timed out');
        return <ExtractedWord>[];
      });
      
      setState(() {
        _extractedWords = words;
        _isProcessing = false;
      });

      if (words.isEmpty) {
        setState(() {
          _errorMessage = 'No words found in the image. Try a clearer image with better text contrast.';
        });
      } else {
        print('PhotoImportView: Successfully extracted ${words.length} words');
        
        // Auto-translate words if translation is enabled
        if (_enableTranslation) {
          _translateWords();
        }
      }
    } catch (e) {
      print('PhotoImportView: Error processing image: $e');
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error processing image: $e';
      });
    }
  }

  void _selectAll() {
    setState(() {
      _selectedWords = _extractedWords.map((w) => w.word).toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedWords.clear();
    });
  }

  Future<void> _translateWords() async {
    if (_extractedWords.isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      print('PhotoImportView: Starting translation of ${_extractedWords.length} words');
      
      // Get unique words for translation
      final wordsToTranslate = _extractedWords
          .map((e) => e.word)
          .where((word) => _translationService.isLikelyDutch(word))
          .toSet()
          .toList();

      if (wordsToTranslate.isNotEmpty) {
        final translations = await _translationService.translateMultipleWords(wordsToTranslate);
        
        setState(() {
          _translations = translations;
          _isTranslating = false;
        });
        
        print('PhotoImportView: Successfully translated ${translations.length} words');
      } else {
        setState(() {
          _isTranslating = false;
        });
        print('PhotoImportView: No Dutch words found to translate');
      }
    } catch (e) {
      print('PhotoImportView: Error translating words: $e');
      setState(() {
        _isTranslating = false;
        _errorMessage = 'Error translating words: $e';
      });
    }
  }

  Future<void> _addSelectedWords() async {
    if (_selectedWords.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('PhotoImportView: Starting to add ${_selectedWords.length} words...');
      final provider = context.read<FlashcardProvider>();
      
      // Determine target deck
      String targetDeckId = '';
      if (_selectedDeckId == 'new_deck' && _newDeckName.isNotEmpty) {
        // Create new deck
        final newDeck = await provider.createDeck(_newDeckName);
        if (newDeck != null) {
          targetDeckId = newDeck.id;
        } else {
          throw Exception('Failed to create new deck');
        }
      } else if (_selectedDeckId == 'uncategorized') {
        // Use uncategorized deck (first deck or create one)
        final decks = provider.getAllDecksHierarchical();
        if (decks.isNotEmpty) {
          targetDeckId = decks.first.id;
        } else {
          final uncategorizedDeck = await provider.createDeck('Uncategorized');
          if (uncategorizedDeck != null) {
            targetDeckId = uncategorizedDeck.id;
          } else {
            throw Exception('Failed to create uncategorized deck');
          }
        }
      } else if (_selectedDeckId != null) {
        targetDeckId = _selectedDeckId!;
      } else {
        throw Exception('No deck selected');
      }

      // Add each selected word as a card
      int addedCount = 0;
      for (String word in _selectedWords) {
        try {
          await provider.createCard(
            word: word,
            definition: _translations[word], // Use translation if available
            example: null,
            deckIds: {targetDeckId},
          );
          addedCount++;
        } catch (e) {
          print('PhotoImportView: Error adding word "$word": $e');
          // Continue with other words even if one fails
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully added $addedCount word${addedCount == 1 ? '' : 's'} to your flashcards!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('PhotoImportView: Error adding words: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error adding words: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
