import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../components/unified_header.dart';
import '../models/deck.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../services/translation_service.dart';

class AddCardView extends StatefulWidget {
  final Deck? selectedDeck;
  final FlashCard? cardToEdit; // For editing existing cards
  
  const AddCardView({
    super.key,
    this.selectedDeck,
    this.cardToEdit,
  });

  @override
  State<AddCardView> createState() => _AddCardViewState();
}

class _AddCardViewState extends State<AddCardView> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _definitionController = TextEditingController();
  final _exampleController = TextEditingController();
  final _exampleTranslationController = TextEditingController();
  final _pluralController = TextEditingController();
  final _pastTenseController = TextEditingController();
  final _futureTenseController = TextEditingController();
  final _pastParticipleController = TextEditingController();
  
  String _selectedArticle = '';
  List<String> _selectedDeckIds = [];
  bool _isLoading = false;
  bool _isTranslatingExample = false;
  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    
    // If editing an existing card, populate the fields
    if (widget.cardToEdit != null) {
      final card = widget.cardToEdit!;
      _wordController.text = card.word;
      _definitionController.text = card.definition;
      _exampleController.text = card.example ?? '';
      _exampleTranslationController.text = card.exampleTranslation ?? '';
      _pluralController.text = card.plural ?? '';
      _pastTenseController.text = card.pastTense ?? '';
      _futureTenseController.text = card.futureTense ?? '';
      _pastParticipleController.text = card.pastParticiple ?? '';
      _selectedArticle = card.article ?? '';
      _selectedDeckIds = List.from(card.deckIds);
    } else if (widget.selectedDeck != null) {
      // If adding a new card with a pre-selected deck
      _selectedDeckIds = [widget.selectedDeck!.id];
    }
    // Note: Default deck selection will be handled in build method
    
    // Add listeners to update save button state
    _wordController.addListener(() {
      setState(() {
        // This will trigger a rebuild to update the save button state
      });
    });
    
    _definitionController.addListener(() {
      setState(() {
        // This will trigger a rebuild to update the save button state
      });
    });
    
    _exampleController.addListener(() {
      setState(() {
        // This will trigger a rebuild to update the translate button state
      });
    });
  }

  @override
  void dispose() {
    _wordController.dispose();
    _definitionController.dispose();
    _exampleController.dispose();
    _exampleTranslationController.dispose();
    _pluralController.dispose();
    _pastTenseController.dispose();
    _futureTenseController.dispose();
    _pastParticipleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set default deck to "Uncategorized" if no deck is selected and we're not editing
    if (_selectedDeckIds.isEmpty && widget.cardToEdit == null && widget.selectedDeck == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<FlashcardProvider>();
        final uncategorizedDeck = provider.decks.firstWhere(
          (deck) => deck.name.toLowerCase() == 'uncategorized',
          orElse: () => provider.decks.isNotEmpty ? provider.decks.first : Deck(id: '', name: 'Uncategorized'),
        );
        if (uncategorizedDeck.id.isNotEmpty && !_selectedDeckIds.contains(uncategorizedDeck.id)) {
          setState(() {
            _selectedDeckIds = [uncategorizedDeck.id];
          });
        }
      });
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
          UnifiedHeader(
            title: widget.cardToEdit != null ? 'Edit Card' : 'Add Card',
            onBack: () => Navigator.of(context).pop(),
            trailing: _isLoading
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : TextButton(
                    onPressed: _canSave() ? _submitCard : null,
                    child: Text(
                      _canSave() 
                          ? (widget.cardToEdit != null ? 'Save' : 'Add')
                          : (_wordController.text.trim().isEmpty ? 'Enter word' : 'Select deck'),
                      style: TextStyle(
                        color: _canSave() 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          
          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Section
                    _buildSectionHeader('Basic Information'),
                    const SizedBox(height: 16),
                    
                    // Dutch Word with Translate Button
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _wordController,
                                maxLength: 100,
                                decoration: InputDecoration(
                                  labelText: 'Dutch Word *',
                                  hintText: 'e.g., huis',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.text_fields),
                                  counterText: '',
                                  errorText: _getDuplicateWarning(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a Dutch word';
                                  }
                                  if (value.length > 100) {
                                    return 'Word must be 100 characters or less';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _wordController.text.trim().isEmpty ? null : _translateWord,
                          icon: _isLoading ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ) : const Icon(Icons.translate),
                          label: const Text('Translate'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Article Selection
                    _buildArticleSelector(),
                    const SizedBox(height: 16),
                    
                    // English Definition
                    TextFormField(
                      controller: _definitionController,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'English Definition (optional)',
                        hintText: 'e.g., house (you can add this later)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.translate),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value != null && value.length > 200) {
                          return 'Definition must be 200 characters or less';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Example Sentence
                    TextFormField(
                      controller: _exampleController,
                      maxLines: 2,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        labelText: 'Example Sentence',
                        hintText: 'e.g., Ik woon in een groot huis.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_quote),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value != null && value.length > 300) {
                          return 'Example must be 300 characters or less';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    
                    // Translate Example Sentence Button
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _exampleController.text.trim().isEmpty ? null : _translateExampleSentence,
                            icon: _isTranslatingExample ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ) : const Icon(Icons.translate, size: 16),
                            label: Text(_isTranslatingExample ? 'Translating...' : 'Translate Sentence'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Example Translation
                    TextFormField(
                      controller: _exampleTranslationController,
                      maxLines: 2,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        labelText: 'Example Translation',
                        hintText: 'e.g., I live in a big house.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.translate),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value != null && value.length > 300) {
                          return 'Example translation must be 300 characters or less';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Grammar Section
                    _buildSectionHeader('Grammar'),
                    const SizedBox(height: 16),
                    
                    // Plural Form
                    TextFormField(
                      controller: _pluralController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Plural Form',
                        hintText: 'e.g., huizen',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.list),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value != null && value.length > 100) {
                          return 'Plural form must be 100 characters or less';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Verb Forms (if applicable)
                    _buildVerbForms(),
                    const SizedBox(height: 24),
                    
                    // Deck Selection
                    _buildSectionHeader('Deck Assignment'),
                    const SizedBox(height: 16),
                    
                    _buildDeckSelection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildArticleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Article (optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildArticleOption('de', 'De (masculine/feminine)'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildArticleOption('het', 'Het (neuter)'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildArticleOption(String article, String label) {
    final isSelected = _selectedArticle == article;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedArticle = article;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.outline,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : null,
        ),
        child: Column(
          children: [
            Text(
              article.toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerbForms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verb Forms (if applicable)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _pastTenseController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Past Tense',
                  hintText: 'e.g., woonde',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (value) {
                  if (value != null && value.length > 100) {
                    return 'Past tense must be 100 characters or less';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _futureTenseController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Future Tense',
                  hintText: 'e.g., zal wonen',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (value) {
                  if (value != null && value.length > 100) {
                    return 'Future tense must be 100 characters or less';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _pastParticipleController,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Past Participle',
            hintText: 'e.g., gewoond',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          validator: (value) {
            if (value != null && value.length > 100) {
              return 'Past participle must be 100 characters or less';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDeckSelection() {
    return Consumer<FlashcardProvider>(
      builder: (context, provider, child) {
        final decks = provider.getAllDecksHierarchical();
        
        if (decks.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Icon(Icons.folder_open, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                const Text(
                  'No decks available',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _createNewDeck(context),
                  child: const Text('Create New Deck'),
                ),
              ],
            ),
          );
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Decks:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...decks.map((deck) => _buildDeckCheckbox(deck)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _createNewDeck(context),
              icon: const Icon(Icons.add),
              label: const Text('Create New Deck'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeckCheckbox(Deck deck) {
    final isSelected = _selectedDeckIds.contains(deck.id);
    
    return CheckboxListTile(
      title: Row(
        children: [
          // Indentation for sub-decks
          if (deck.isSubDeck) ...[
            const SizedBox(width: 16),
            Icon(
              Icons.subdirectory_arrow_right,
              color: Colors.grey[600],
              size: 16,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(deck.name),
          ),
        ],
      ),
      subtitle: Consumer<FlashcardProvider>(
        builder: (context, provider, child) {
          final cardCount = provider.cards.where((card) => card.deckIds.contains(deck.id)).length;
          return Text('$cardCount cards');
        },
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
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  void _createNewDeck(BuildContext context) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Deck'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Deck Name',
            hintText: 'Enter deck name...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final navigator = Navigator.of(context);
                final provider = context.read<FlashcardProvider>();
                final newDeck = await provider.createDeck(nameController.text.trim());
                if (mounted && newDeck != null) {
                  setState(() {
                    _selectedDeckIds.add(newDeck.id);
                  });
                  navigator.pop();
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _translateWord() async {
    final dutchWord = _wordController.text.trim();
    if (dutchWord.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Dutch word to translate')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final translation = await _translationService.translateDutchToEnglish(dutchWord);
      
      if (mounted) {
        setState(() {
          _definitionController.text = translation ?? '';
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translated: "$dutchWord" → "$translation"'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _translateExampleSentence() async {
    final dutchSentence = _exampleController.text.trim();
    if (dutchSentence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Dutch sentence to translate')),
      );
      return;
    }

    setState(() {
      _isTranslatingExample = true;
    });

    try {
      final translation = await _translationService.translateDutchToEnglish(dutchSentence);
      
      if (mounted) {
        setState(() {
          _exampleTranslationController.text = translation ?? '';
          _isTranslatingExample = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translated: "$dutchSentence" → "$translation"'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslatingExample = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  bool _canSave() {
    return _wordController.text.trim().isNotEmpty && 
           _selectedDeckIds.isNotEmpty;
  }

  FlashCard? _findDuplicateCard() {
    if (widget.cardToEdit != null) {
      // Don't check for duplicates when editing
      return null;
    }
    
    final word = _wordController.text.trim().toLowerCase();
    if (word.isEmpty) return null;
    
    final provider = context.read<FlashcardProvider>();
    final allCards = provider.cards;
    
    try {
      return allCards.firstWhere(
        (card) => card.word.toLowerCase() == word,
      );
    } catch (e) {
      return null;
    }
  }

  String? _getDuplicateWarning() {
    if (widget.cardToEdit != null) {
      // Don't show warning when editing
      return null;
    }
    
    final duplicateCard = _findDuplicateCard();
    if (duplicateCard != null) {
      final provider = context.read<FlashcardProvider>();
      final deckNames = provider.getDeckNamesForCard(duplicateCard);
      final deckInfo = deckNames.isNotEmpty ? ' in ${deckNames.join(', ')}' : '';
      return 'This word already exists$deckInfo';
    }
    
    return null;
  }

  void _submitCard() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selectedDeckIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one deck')),
      );
      return;
    }
    
    // Check for duplicate card
    final duplicateCard = _findDuplicateCard();
    if (duplicateCard != null) {
      final shouldProceed = await _showDuplicateWarningDialog(duplicateCard);
      if (!shouldProceed) {
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final provider = context.read<FlashcardProvider>();
      
      if (widget.cardToEdit != null) {
        // Update existing card
        final updatedCard = FlashCard(
          id: widget.cardToEdit!.id,
          word: _wordController.text.trim(),
          definition: _definitionController.text.trim().isEmpty ? null : _definitionController.text.trim(),
          example: _exampleController.text.trim().isEmpty ? null : _exampleController.text.trim(),
          exampleTranslation: _exampleTranslationController.text.trim().isEmpty ? null : _exampleTranslationController.text.trim(),
          deckIds: _selectedDeckIds.toSet(),
          successCount: widget.cardToEdit!.successCount,
          dateCreated: widget.cardToEdit!.dateCreated,
          lastModified: DateTime.now(),
          cloudKitRecordName: widget.cardToEdit!.cloudKitRecordName,
          learningMastery: widget.cardToEdit!.learningMastery,
          article: _selectedArticle,
          plural: _pluralController.text.trim().isEmpty ? '' : _pluralController.text.trim(),
          pastTense: _pastTenseController.text.trim().isEmpty ? '' : _pastTenseController.text.trim(),
          futureTense: _futureTenseController.text.trim().isEmpty ? '' : _futureTenseController.text.trim(),
          pastParticiple: _pastParticipleController.text.trim().isEmpty ? '' : _pastParticipleController.text.trim(),
        );
        
        await provider.updateCard(updatedCard);
        
        if (mounted) {
          // Refresh the Dutch word exercise provider to show new exercises immediately
          final dutchProvider = context.read<DutchWordExerciseProvider>();
          await dutchProvider.initialize();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Card updated successfully!')),
          );
          Navigator.of(context).pop();
        }
      } else {
        // Create new card
        await provider.createCard(
          word: _wordController.text.trim(),
          definition: _definitionController.text.trim().isEmpty ? null : _definitionController.text.trim(),
          example: _exampleController.text.trim().isEmpty ? null : _exampleController.text.trim(),
          exampleTranslation: _exampleTranslationController.text.trim().isEmpty ? null : _exampleTranslationController.text.trim(),
          article: _selectedArticle,
          plural: _pluralController.text.trim().isEmpty ? '' : _pluralController.text.trim(),
          pastTense: _pastTenseController.text.trim().isEmpty ? '' : _pastTenseController.text.trim(),
          futureTense: _futureTenseController.text.trim().isEmpty ? '' : _futureTenseController.text.trim(),
          pastParticiple: _pastParticipleController.text.trim().isEmpty ? '' : _pastParticipleController.text.trim(),
          deckIds: _selectedDeckIds.toSet(),
        );
        
        if (mounted) {
          // Refresh the Dutch word exercise provider to show new exercises immediately
          final dutchProvider = context.read<DutchWordExerciseProvider>();
          await dutchProvider.initialize();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Card added successfully!')),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${widget.cardToEdit != null ? 'updating' : 'adding'} card: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showDuplicateWarningDialog(FlashCard duplicateCard) async {
    final provider = context.read<FlashcardProvider>();
    final deckNames = provider.getDeckNamesForCard(duplicateCard);
    final deckInfo = deckNames.isNotEmpty ? ' in ${deckNames.join(', ')}' : '';
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Duplicate Card Found'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A card with the word "${duplicateCard.word}" already exists$deckInfo.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Existing card:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Definition: ${duplicateCard.definition}'),
                    if (duplicateCard.example.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Example: ${duplicateCard.example}'),
                    ],
                    if (deckNames.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Decks: ${deckNames.join(', ')}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'What would you like to do?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
              child: const Text('Add Anyway'),
            ),
          ],
        );
      },
    ) ?? false;
  }
} 