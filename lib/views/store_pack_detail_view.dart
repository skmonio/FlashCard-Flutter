import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/store_pack.dart';
import '../models/store_pack.dart';
import '../providers/flashcard_provider.dart';
import 'add_deck_view.dart';

class StorePackDetailView extends StatefulWidget {
  final StorePack pack;

  const StorePackDetailView({Key? key, required this.pack}) : super(key: key);

  @override
  State<StorePackDetailView> createState() => _StorePackDetailViewState();
}

class _StorePackDetailViewState extends State<StorePackDetailView> {
  List<Map<String, dynamic>> _packContents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPackContents();
    
    // Listen to flashcard provider changes to update UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flashcardProvider = context.read<FlashcardProvider>();
      flashcardProvider.addListener(_onFlashcardProviderChanged);
    });
  }

  @override
  void dispose() {
    // Remove listener when widget is disposed
    final flashcardProvider = context.read<FlashcardProvider>();
    flashcardProvider.removeListener(_onFlashcardProviderChanged);
    super.dispose();
  }

  void _onFlashcardProviderChanged() {
    // Rebuild the widget when flashcard data changes
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPackContents() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final csvString = await DefaultAssetBundle.of(context)
          .loadString('assets/data/store_packs/${widget.pack.filename}');
      
      final lines = csvString.split('\n').where((line) => line.trim().isNotEmpty).toList();
      
      if (lines.length < 2) {
        throw Exception('No data found in pack');
      }

      final headers = _parseCSVLine(lines[0]);
      final contents = <Map<String, dynamic>>[];

      for (int i = 1; i < lines.length; i++) {
        final fields = _parseCSVLine(lines[i]);
        if (fields.length >= headers.length) {
          final item = <String, dynamic>{};
          for (int j = 0; j < headers.length; j++) {
            item[headers[j]] = fields[j];
          }
          contents.add(item);
        }
      }

      setState(() {
        _packContents = contents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<String> _parseCSVLine(String line) {
    final result = <String>[];
    String current = '';
    bool inQuotes = false;
    
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pack.name),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_packContents.isNotEmpty)
            IconButton(
              onPressed: _importAllItems,
              icon: const Icon(Icons.download),
              tooltip: 'Import all items',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Error loading pack contents',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPackContents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_packContents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No contents found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This pack appears to be empty.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _packContents.length,
        itemBuilder: (context, index) {
          final item = _packContents[index];
          return _buildContentItem(item, index);
        },
    );
  }

  Widget _buildContentItem(Map<String, dynamic> item, int index) {
    return _buildVocabularyItem(item, index);
  }



  Widget _buildVocabularyItem(Map<String, dynamic> item, int index) {
    final word = item['Word'] ?? '';
    final definition = item['Definition'] ?? '';
    final example = item['Example'] ?? '';
    final article = item['Article'] ?? '';

    // Check if the word already exists in any deck
    final flashcardProvider = context.read<FlashcardProvider>();
    final existingCard = flashcardProvider.cards.where(
      (card) => card.word.toLowerCase() == word.toLowerCase(),
    ).firstOrNull;
    
    final wordExists = existingCard != null;
    final deckNames = wordExists 
        ? flashcardProvider.getDeckNamesForCard(existingCard!)
        : <String>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (article.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Article: $article',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (wordExists)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Word exists',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Text(
                      'New word',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                if (!wordExists)
                  IconButton(
                    onPressed: () => _importVocabularyItem(item),
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Import this word',
                  )
                else
                  IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'Word already exists in: ${deckNames.join(', ')}',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              definition,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (example.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                example,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (wordExists && deckNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Text(
                  'Exists in: ${deckNames.join(', ')}',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _importVocabularyItem(Map<String, dynamic> item) async {
    final flashcardProvider = context.read<FlashcardProvider>();
    
    final word = item['Word'] ?? '';
    
    // Check if word already exists
    final existingCard = flashcardProvider.cards.where(
      (card) => card.word.toLowerCase() == word.toLowerCase(),
    ).firstOrNull;

    if (existingCard != null) {
      final deckNames = flashcardProvider.getDeckNamesForCard(existingCard);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Word "$word" already exists in: ${deckNames.join(', ')}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }
    
    // Show deck selection dialog
    final selectedDeckId = await _showDeckSelectionDialog();
    if (selectedDeckId == null) return;

    try {
      final definition = item['Definition'] ?? '';
      final example = item['Example'] ?? '';
      final article = item['Article'] ?? '';

      // Create the flashcard
      final card = await flashcardProvider.createCard(
        word: word,
        definition: definition,
        example: example,
        article: article,
        deckIds: {selectedDeckId},
      );
      
      final success = card != null;

      if (success) {
        if (mounted) {
          // Force a rebuild to update the UI immediately
          setState(() {});
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported "$word"'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to import word'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing word: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showDeckSelectionDialog() async {
    final flashcardProvider = context.read<FlashcardProvider>();
    final decks = List.from(flashcardProvider.decks)..sort((a, b) => a.name.compareTo(b.name));

    if (decks.isEmpty) {
      // Show dialog to create a new deck
      final shouldCreate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Decks Available'),
          content: const Text('You need to create a deck first to import items. Would you like to create a new deck?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create Deck'),
            ),
          ],
        ),
      );

      if (shouldCreate == true) {
        // Navigate to create deck view
        final result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AddDeckView()),
        );
        if (result == true) {
          // Refresh decks and show selection dialog
          return _showDeckSelectionDialog();
        }
      }
      return null;
    }

    // Show deck selection dialog
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Deck'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: decks.length,
            itemBuilder: (context, index) {
              final deck = decks[index];
              final actualCardCount = flashcardProvider.getCardsForDeck(deck.id).length;
              return ListTile(
                title: Text(deck.name),
                subtitle: Text('$actualCardCount cards'),
                onTap: () => Navigator.of(context).pop(deck.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _importAllItems() async {
    if (_packContents.isEmpty) return;

    final selectedDeckId = await _showDeckSelectionDialog();
    if (selectedDeckId == null) return;

    try {
      final flashcardProvider = context.read<FlashcardProvider>();
      
      int importedCount = 0;
      int skippedCount = 0;

      // For vocabulary cards, import all cards
      for (final item in _packContents) {
        final word = item['Word']?.toString().trim() ?? '';
        final definition = (item['Definition'] ?? item['Correct Answer'])?.toString().trim() ?? '';
        
        if (word.isNotEmpty) {
          // Check if card already exists
          final existingCard = flashcardProvider.cards.where(
            (card) => card.word.toLowerCase() == word.toLowerCase(),
          ).firstOrNull;

          if (existingCard == null) {
            final newCard = await flashcardProvider.createCard(
              word: word,
              definition: definition,
              deckIds: {selectedDeckId},
            );
            
            if (newCard != null) {
              importedCount++;
            }
          } else {
            skippedCount++;
          }
        }
      }

      if (mounted) {
        // Force a rebuild to update the UI immediately
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import completed: $importedCount items imported, $skippedCount skipped',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}