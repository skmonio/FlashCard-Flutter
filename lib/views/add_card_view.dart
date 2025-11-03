import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';

import '../models/deck.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../models/dutch_word_exercise.dart';
import '../services/translation_service.dart';
import '../providers/translation_language_provider.dart';
import '../utils/enhanced_snackbar.dart';

class AddCardView extends StatefulWidget {
  final Deck? selectedDeck;
  final FlashCard? cardToEdit; // For editing existing cards
  final String? preFilledWord; // For pre-filling the word field
  
  const AddCardView({
    super.key,
    this.selectedDeck,
    this.cardToEdit,
    this.preFilledWord,
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
  bool _isTranslatingDefinition = false;
  bool _isTranslatingExample = false;
  final TranslationService _translationService = TranslationService();
  
  // Track original values for change detection
  String _originalWord = '';
  String _originalDefinition = '';
  String _originalExample = '';
  String _originalExampleTranslation = '';
  String _originalPlural = '';
  String _originalPastTense = '';
  String _originalFutureTense = '';
  String _originalPastParticiple = '';
  String _originalArticle = '';
  List<String> _originalDeckIds = [];

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
      
      // Store original values for change detection
      _originalWord = card.word;
      _originalDefinition = card.definition;
      _originalExample = card.example ?? '';
      _originalExampleTranslation = card.exampleTranslation ?? '';
      _originalPlural = card.plural ?? '';
      _originalPastTense = card.pastTense ?? '';
      _originalFutureTense = card.futureTense ?? '';
      _originalPastParticiple = card.pastParticiple ?? '';
      _originalArticle = card.article ?? '';
      _originalDeckIds = List.from(card.deckIds);
    } else if (widget.preFilledWord != null) {
      // If adding a new card with a pre-filled word
      _wordController.text = widget.preFilledWord!;
      _originalWord = widget.preFilledWord!;
    } else if (widget.selectedDeck != null) {
      // If adding a new card with a pre-selected deck
      _selectedDeckIds = [widget.selectedDeck!.id];
      _originalDeckIds = [widget.selectedDeck!.id];
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
    // No longer automatically select "Uncategorized" deck - users must choose
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // Fixed Header - matching Taal Trek header height
          SafeArea(
            child: Container(
              height: kToolbarHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: _buildCustomHeader(context),
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
                    
                    // Word with Translate Button
                    Consumer<TranslationLanguageProvider>(
                      builder: (context, langProvider, child) {
                        final wordLanguageName = langProvider.wordLanguage.name;
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: _wordController,
                                    maxLength: 100,
                                    decoration: InputDecoration(
                                      labelText: '$wordLanguageName Word *',
                                      hintText: 'e.g., ${wordLanguageName == 'Dutch' ? 'huis' : 'word'}',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.text_fields),
                                      counterText: '',
                                      errorText: _getDuplicateWarning(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter a $wordLanguageName word';
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
                            IconButton(
                              onPressed: _wordController.text.trim().isEmpty ? null : _translateWord,
                              icon: _isLoading ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ) : const Icon(Icons.translate),
                              tooltip: 'Translate',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Definition with Translate Button
                    Consumer<TranslationLanguageProvider>(
                      builder: (context, langProvider, child) {
                        final translationLanguageName = langProvider.translationLanguage.name;
                        return Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _definitionController,
                                maxLength: 200,
                                decoration: InputDecoration(
                                  labelText: '$translationLanguageName Definition *',
                                  hintText: 'e.g., translation',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.translate),
                                  counterText: '',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a definition';
                                  }
                                  if (value.length > 200) {
                                    return 'Definition must be 200 characters or less';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _definitionController.text.trim().isEmpty ? null : _translateDefinition,
                              icon: _isTranslatingDefinition ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ) : const Icon(Icons.translate),
                              tooltip: 'Translate',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Article Selection
                    _buildArticleSelector(),
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
              child: _buildArticleOption('de'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildArticleOption('het'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildArticleOption(String article) {
    final isSelected = _selectedArticle == article;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          // If already selected, deselect it; otherwise select it
          _selectedArticle = isSelected ? '' : article;
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
        child: Center(
          child: Text(
            article.toUpperCase(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
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
    final provider = context.read<FlashcardProvider>();
    
    // Get selected deck names for display
    String selectedDecksText;
    if (_selectedDeckIds.isEmpty) {
      selectedDecksText = 'Uncategorized';
    } else if (_selectedDeckIds.length == 1) {
      final deck = provider.getDeck(_selectedDeckIds.first);
      selectedDecksText = deck?.name ?? 'Unknown Deck';
    } else {
      selectedDecksText = '${_selectedDeckIds.length} decks selected';
    }
    
    return Card(
      child: InkWell(
        onTap: () => _showDeckSelectionDialog(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.folder, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select your deck(s)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedDecksText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
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

  void _showDeckSelectionDialog() {
    final provider = context.read<FlashcardProvider>();
    final allDecks = provider.getAllDecksHierarchical();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Decks'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400, // Fixed height to ensure scrolling works
            child: Column(
              children: [
                // "Create Deck" button at the top
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _createNewDeck(context);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Deck'),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Scrollable list of deck options
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Selected decks first (moved to top)
                        if (_selectedDeckIds.isNotEmpty) ...[
                          ...allDecks.where((deck) => _selectedDeckIds.contains(deck.id)).map((deck) => _buildDeckOption(
                            deck.name,
                            '${provider.getCardsForDeckWithSubDecks(deck.id).length} cards',
                            true,
                            () {
                              setDialogState(() {
                                _selectedDeckIds.remove(deck.id);
                              });
                              setState(() {
                                // Update the main widget state to reflect the changes
                              });
                            },
                          )),
                          const SizedBox(height: 8),
                        ],
                        
                        // Individual deck options (excluding already selected ones)
                        if (allDecks.isNotEmpty) ...[
                          ...allDecks.where((deck) => !_selectedDeckIds.contains(deck.id)).map((deck) => _buildDeckOption(
                            deck.name,
                            '${provider.getCardsForDeckWithSubDecks(deck.id).length} cards',
                            false,
                            () {
                              setDialogState(() {
                                _selectedDeckIds.add(deck.id);
                              });
                              setState(() {
                                // Update the main widget state to reflect the changes
                              });
                            },
                          )),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckOption(String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Colors.blue : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.blue : null,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected) ...[
                Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red[400],
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _createNewDeck(BuildContext context) {
    final nameController = TextEditingController();
    bool isPublic = false; // Private by default
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Deck'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Deck Name',
                  hintText: 'Enter deck name...',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Make this deck public'),
                subtitle: const Text('Allow friends to see and study this deck'),
                value: isPublic,
                onChanged: (value) {
                  setState(() {
                    isPublic = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final deckName = nameController.text.trim();
                  
                  // Check for duplicate deck
                  final provider = context.read<FlashcardProvider>();
                  final allDecks = provider.decks;
                  final duplicateDeck = allDecks.where(
                    (deck) => deck.name.toLowerCase() == deckName.toLowerCase(),
                  ).firstOrNull;
                  
                  if (duplicateDeck != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This deck already exists'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  
                  final navigator = Navigator.of(context);
                  final newDeck = await provider.createDeck(
                    deckName,
                    isPublic: isPublic,
                  );
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
      ),
    );
  }

  void _translateWord() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      final langProvider = context.read<TranslationLanguageProvider>();
      final wordLanguageName = langProvider.wordLanguage.name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a $wordLanguageName word to translate')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final langProvider = context.read<TranslationLanguageProvider>();
      final wordLanguageCode = langProvider.wordLanguageCode;
      final targetLanguageCode = langProvider.translationLanguageCode;
      
      final translation = await _translationService.translate(
        word,
        sourceLanguageCode: wordLanguageCode,
        targetLanguageCode: targetLanguageCode,
      );
      
      if (mounted) {
        setState(() {
          _definitionController.text = translation ?? '';
          _isLoading = false;
        });
        
        if (translation != null && translation.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Translated: "$word" → "$translation"'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
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

  void _translateDefinition() async {
    final definition = _definitionController.text.trim();
    if (definition.isEmpty) {
      final langProvider = context.read<TranslationLanguageProvider>();
      final translationLanguageName = langProvider.translationLanguage.name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a $translationLanguageName word to translate')),
      );
      return;
    }

    setState(() {
      _isTranslatingDefinition = true;
    });

    try {
      final langProvider = context.read<TranslationLanguageProvider>();
      // Reverse translation: from translation language to word language
      final sourceLanguageCode = langProvider.translationLanguageCode;
      final targetLanguageCode = langProvider.wordLanguageCode;
      
      final translation = await _translationService.translate(
        definition,
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: targetLanguageCode,
      );
      
      if (mounted) {
        setState(() {
          _wordController.text = translation ?? '';
          _isTranslatingDefinition = false;
        });
        
        if (translation != null && translation.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Translated: "$definition" → "$translation"'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslatingDefinition = false;
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
    final sentence = _exampleController.text.trim();
    if (sentence.isEmpty) {
      final langProvider = context.read<TranslationLanguageProvider>();
      final wordLanguageName = langProvider.wordLanguage.name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a $wordLanguageName sentence to translate')),
      );
      return;
    }

    setState(() {
      _isTranslatingExample = true;
    });

    try {
      final langProvider = context.read<TranslationLanguageProvider>();
      final wordLanguageCode = langProvider.wordLanguageCode;
      final targetLanguageCode = langProvider.translationLanguageCode;
      
      final translation = await _translationService.translate(
        sentence,
        sourceLanguageCode: wordLanguageCode,
        targetLanguageCode: targetLanguageCode,
      );
      
      if (mounted) {
        setState(() {
          _exampleTranslationController.text = translation ?? '';
          _isTranslatingExample = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translated: "$sentence" → "$translation"'),
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
           _definitionController.text.trim().isNotEmpty;
  }

  bool _hasUnsavedChanges() {
    // Check if any field has been modified from its original value
    return _wordController.text.trim() != _originalWord ||
           _definitionController.text.trim() != _originalDefinition ||
           _exampleController.text.trim() != _originalExample ||
           _exampleTranslationController.text.trim() != _originalExampleTranslation ||
           _pluralController.text.trim() != _originalPlural ||
           _pastTenseController.text.trim() != _originalPastTense ||
           _futureTenseController.text.trim() != _originalFutureTense ||
           _pastParticipleController.text.trim() != _originalPastParticiple ||
           _selectedArticle != _originalArticle ||
           !_listEquals(_selectedDeckIds, _originalDeckIds);
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Do you want to save them before going back?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back without saving
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Stay on the page
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _submitCard(); // Save and then go back
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  FlashCard? _findDuplicateCard() {
    final word = _wordController.text.trim().toLowerCase();
    if (word.isEmpty) return null;
    
    final provider = context.read<FlashcardProvider>();
    final allCards = provider.cards;
    
    try {
      final duplicateCard = allCards.firstWhere(
        (card) => card.word.toLowerCase() == word,
      );
      
      // When editing, don't consider the current card as a duplicate
      if (widget.cardToEdit != null && duplicateCard.id == widget.cardToEdit!.id) {
        return null;
      }
      
      return duplicateCard;
    } catch (e) {
      return null;
    }
  }

  String? _getDuplicateWarning() {
    // Don't show duplicate warning if we're currently loading (creating the card)
    if (_isLoading) {
      return null;
    }
    
    final duplicateCard = _findDuplicateCard();
    if (duplicateCard != null) {
      return 'This word already exists';
    }
    
    return null;
  }

  void _submitCard() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // If no deck is selected, let the service default to "Uncategorized"
    // The FlashcardService.createCard method will handle empty deckIds by creating/using Uncategorized deck
    
    // Check for duplicate card
    final duplicateCard = _findDuplicateCard();
    if (duplicateCard != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This word already exists'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
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
          // Check if any exercises need to be removed due to data deletion
          final exercisesToRemove = _getExercisesToRemove(widget.cardToEdit!);
          
          if (exercisesToRemove.isNotEmpty) {
            // Ask user if they want to remove the affected exercises
            final shouldRemove = await _showRemoveExercisesDialog(exercisesToRemove);
            
            if (shouldRemove) {
              // Remove the affected exercises
              await _removeExercises(updatedCard, exercisesToRemove);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Card updated successfully! ${exercisesToRemove.length} exercise${exercisesToRemove.length == 1 ? '' : 's'} removed.'),
                  backgroundColor: Colors.orange,
                ),
              );
              
              Navigator.of(context).pop(true);
              return;
            } else {
              // User cancelled - don't save the changes
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Card update cancelled.')),
              );
              
              Navigator.of(context).pop(false);
              return;
            }
          }
          
          // Check if exercises exist for the original word (before editing)
          final dutchProvider = context.read<DutchWordExerciseProvider>();
          final originalWord = widget.cardToEdit!.word;
          final existingExercise = dutchProvider.getWordExerciseByWord(originalWord);
          
          // Check if the word was changed
          final wordChanged = originalWord.toLowerCase() != updatedCard.word.toLowerCase();
          
          if (existingExercise != null && existingExercise.exercises.isNotEmpty) {
            // Exercises exist for the original word
            if (wordChanged) {
              // Word was changed - ask if user wants to update exercises for the new word
              final availableExercises = _getAvailableExerciseTypes(updatedCard);
              
              if (availableExercises.isNotEmpty && mounted) {
                final selectedExercises = await _showCreateExercisesDialog(
                  updatedCard.word, 
                  availableExercises,
                  message: 'The word was changed from "$originalWord" to "${updatedCard.word}". Would you like to create new exercises for the new word?'
                );
                
                if (selectedExercises.isNotEmpty) {
                  // Create new exercises for the new word
                  await _createSelectedExercises(updatedCard, selectedExercises);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Card updated successfully! ${selectedExercises.length} new exercise${selectedExercises.length == 1 ? '' : 's'} created for "${updatedCard.word}".'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card updated successfully! Exercises for the original word remain unchanged.')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card updated successfully! Exercises for the original word remain unchanged.')),
                );
              }
            } else {
              // Word wasn't changed - check if new grammar information was added
              final newExerciseTypes = _getNewExerciseTypes(widget.cardToEdit!, updatedCard);
              
              if (newExerciseTypes.isNotEmpty && mounted) {
                // Ask user if they want to create exercises for the newly added grammar information
                final selectedNewExercises = await _showCreateExercisesDialog(
                  updatedCard.word, 
                  newExerciseTypes,
                  message: 'New grammar information was added. Would you like to create exercises for these new features?'
                );
                
                if (selectedNewExercises.isNotEmpty) {
                  // Create exercises for the new grammar information
                  await _createSelectedExercises(updatedCard, selectedNewExercises);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Card updated successfully! ${selectedNewExercises.length} additional exercise${selectedNewExercises.length == 1 ? '' : 's'} created for new grammar information.'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card updated successfully!')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card updated successfully!')),
                );
              }
            }
          } else {
            // No exercises exist for the original word - check if we can create new ones
            final availableExercises = _getAvailableExerciseTypes(updatedCard);
            
            if (availableExercises.isNotEmpty && mounted) {
              // Ask user which exercises they want to create
              final selectedExercises = await _showCreateExercisesDialog(updatedCard.word, availableExercises);
              
              if (selectedExercises.isNotEmpty) {
                // Create selected exercises
                await _createSelectedExercises(updatedCard, selectedExercises);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Card updated successfully! ${selectedExercises.length} exercise${selectedExercises.length == 1 ? '' : 's'} created.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card updated successfully!')),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Card updated successfully!')),
              );
            }
          }
          
          Navigator.of(context).pop(true); // Return true to indicate successful update
        }
      } else {
        // Create new card
        final newCard = await provider.createCard(
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
        
        if (mounted && newCard != null) {
          // Check what exercises can be created based on card content
          final availableExercises = _getAvailableExerciseTypes(newCard);
          
          if (availableExercises.isNotEmpty && mounted) {
            // Ask user which exercises they want to create
            final selectedExercises = await _showCreateExercisesDialog(newCard.word, availableExercises);
            
            if (selectedExercises.isNotEmpty) {
              // Create selected exercises
              await _createSelectedExercises(newCard, selectedExercises);
              
              EnhancedSnackBar.showSuccess(
                context,
                message: 'Card added successfully! ${selectedExercises.length} exercise${selectedExercises.length == 1 ? '' : 's'} created.',
              );
            } else {
              EnhancedSnackBar.showSuccess(
                context,
                message: 'Card added successfully!',
              );
            }
          } else {
            EnhancedSnackBar.showSuccess(
              context,
              message: 'Card added successfully!',
            );
          }
          
          // Refresh the Dutch word exercise provider to show new exercises immediately
          final dutchProvider = context.read<DutchWordExerciseProvider>();
          await dutchProvider.initialize();
          
          Navigator.of(context).pop(true); // Return true to indicate successful update
        }
      }
    } catch (e) {
      if (mounted) {
        EnhancedSnackBar.showError(
          context,
          message: 'Error ${widget.cardToEdit != null ? 'updating' : 'adding'} card: $e',
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

  List<String> _generateIntelligentOptions(FlashCard targetCard, {String? preferredDeckId}) {
    // Start with the correct answer at position 0 (option 1)
    final options = <String>[targetCard.definition];
    final usedOptions = <String>{targetCard.definition}; // Track all used options to prevent duplicates
    
    // Get all cards from the provider
    final provider = context.read<FlashcardProvider>();
    final allCards = provider.cards;
    
    // Get other definitions, prioritizing the preferred deck if specified
    List<String> otherDefinitions = [];
    
    if (preferredDeckId != null) {
      // First, try to get definitions from the preferred deck
      final deckCards = allCards.where((card) => 
        card.id != targetCard.id && 
        card.definition.isNotEmpty &&
        card.deckIds.contains(preferredDeckId)
      ).map((card) => card.definition).toList();
      
      otherDefinitions.addAll(deckCards);
    }
    
    // If we don't have enough options, add from all other cards
    if (otherDefinitions.length < 5) {
      final remainingCards = allCards.where((card) => 
        card.id != targetCard.id && 
        card.definition.isNotEmpty &&
        !otherDefinitions.contains(card.definition)
      ).map((card) => card.definition).toList();
      
      otherDefinitions.addAll(remainingCards);
    }
    
    // Shuffle and take up to 5 more options (to make 6 total)
    otherDefinitions.shuffle();
    final additionalOptions = otherDefinitions.take(5).toList();
    
    // Add the additional options, ensuring no duplicates
    for (final option in additionalOptions) {
      if (!usedOptions.contains(option)) {
        options.add(option);
        usedOptions.add(option);
      }
    }
    
    // If we don't have enough options from other cards, add some generic but realistic options
    final genericOptions = [
      'to walk',
      'to eat',
      'to sleep',
      'to work',
      'to play',
      'to read',
      'to write',
      'to speak',
      'to listen',
      'to watch',
      'to buy',
      'to sell',
      'to give',
      'to take',
      'to come',
      'to go',
      'to see',
      'to know',
      'to think',
      'to feel',
    ];
    
    // Add generic options until we have 6 total, ensuring no duplicates
    for (final genericOption in genericOptions) {
      if (options.length >= 6) break;
      if (!usedOptions.contains(genericOption)) {
        options.add(genericOption);
        usedOptions.add(genericOption);
      }
    }
    
    // Don't shuffle - keep correct answer at index 0 (option 1)
    // Ensure we have exactly 6 options
    return options.take(6).toList();
  }

  /// Create selected exercises for a card
  Future<void> _createSelectedExercises(FlashCard card, List<String> selectedExercises) async {
    try {
      print('AddCardView: Creating ${selectedExercises.length} exercises for card: ${card.word}');
      
      final List<WordExercise> exercisesToCreate = [];
      
      for (final exerciseType in selectedExercises) {
        switch (exerciseType) {
          case 'Basic Multiple Choice':
            final preferredDeckId = card.deckIds.isNotEmpty ? card.deckIds.first : null;
            final options = _generateIntelligentOptions(card, preferredDeckId: preferredDeckId);
            
            exercisesToCreate.add(WordExercise(
              id: '${card.id}_basic_exercise',
              type: ExerciseType.multipleChoice,
              prompt: 'Translate "${card.word}" to English',
              correctAnswer: '0', // Index 0 (option 1) is always the correct answer
              options: options,
              explanation: 'The Dutch word "${card.word}" means "${card.definition}" in English.',
              difficulty: ExerciseDifficulty.beginner,
            ));
            break;
            
          case 'De/Het Article Exercise':
          case 'Plural Form Exercise':
          case 'Sentence Building Exercise':
            // These will be handled by the grammar exercise generator
            break;
        }
      }
      
      // Generate specific grammar exercises based on what was selected
      for (final exerciseType in selectedExercises) {
        switch (exerciseType) {
          case 'De/Het Article Exercise':
            if (card.article != null && card.article!.isNotEmpty) {
              // Generate only the article exercise
              final correctAnswer = card.article!;
              final wrongAnswer = correctAnswer == 'de' ? 'het' : 'de';
              final options = [correctAnswer, wrongAnswer];
              
              exercisesToCreate.add(WordExercise(
                id: '${card.id}_article_${DateTime.now().millisecondsSinceEpoch}',
                type: ExerciseType.multipleChoice,
                prompt: 'Is it De or Het "${card.word}"?',
                options: options,
                correctAnswer: '0', // Index 0 (option 1) is always the correct answer
                explanation: 'The correct article for "${card.word}" is "$correctAnswer".',
                difficulty: ExerciseDifficulty.beginner,
              ));
            }
            break;
            
          case 'Plural Form Exercise':
            if (card.plural != null && card.plural!.isNotEmpty) {
              // Generate only the plural exercise
              final correctPlural = card.plural!;
              final possibleWrongOptions = ['${card.word}s', '${card.word}en', '${card.word}eren'];
              
              // Filter out duplicates - only include wrong options that are different from the correct answer
              final wrongOptions = possibleWrongOptions
                  .where((option) => option != correctPlural)
                  .toList();
              
              final options = [correctPlural, ...wrongOptions];
              
              exercisesToCreate.add(WordExercise(
                id: '${card.id}_plural_${DateTime.now().millisecondsSinceEpoch}',
                type: ExerciseType.multipleChoice,
                prompt: 'What is the plural form of "${card.word}"?',
                options: options,
                correctAnswer: '0', // Index 0 (option 1) is always the correct answer
                explanation: 'The plural form of "${card.word}" is "${correctPlural}".',
                difficulty: ExerciseDifficulty.beginner,
              ));
            }
            break;
            
          case 'Sentence Building Exercise':
            if (card.example.isNotEmpty && card.exampleTranslation.isNotEmpty) {
              // Generate only the sentence building exercise
              final cleanedSentence = card.example.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
              final dutchWords = cleanedSentence.split(' ').where((word) => word.isNotEmpty).toList();
              final shuffledWords = List<String>.from(dutchWords)..shuffle();
              
              exercisesToCreate.add(WordExercise(
                id: '${card.id}_sentencebuilder_${DateTime.now().millisecondsSinceEpoch}',
                type: ExerciseType.sentenceBuilding,
                prompt: 'Build the correct Dutch sentence: ${card.exampleTranslation}',
                options: shuffledWords,
                correctAnswer: cleanedSentence,
                explanation: '${card.example}',
                difficulty: ExerciseDifficulty.beginner,
              ));
            }
            break;
        }
      }
      
      if (exercisesToCreate.isNotEmpty) {
        // Get the Dutch word exercise provider from the context
        final dutchProvider = context.read<DutchWordExerciseProvider>();
        
        // Check if there's already an exercise for this word
        final existingExercise = dutchProvider.getWordExerciseByWord(card.word);
        
        if (existingExercise != null) {
          // Add new exercises to existing word exercise
          final updatedExercise = DutchWordExercise(
            id: existingExercise.id,
            targetWord: existingExercise.targetWord,
            wordTranslation: existingExercise.wordTranslation,
            deckId: existingExercise.deckId,
            deckName: existingExercise.deckName,
            category: existingExercise.category,
            difficulty: existingExercise.difficulty,
            exercises: [...existingExercise.exercises, ...exercisesToCreate],
            createdAt: existingExercise.createdAt,
            isUserCreated: existingExercise.isUserCreated,
            learningProgress: existingExercise.learningProgress,
          );
          
          await dutchProvider.updateWordExercise(updatedExercise);
          print('AddCardView: Added ${exercisesToCreate.length} exercises to existing word exercise');
        } else {
          // Create new word exercise
          final provider = context.read<FlashcardProvider>();
          final deckId = card.deckIds.isNotEmpty ? card.deckIds.first : 'default';
          final deckName = provider.getDeck(deckId)?.name ?? 'Default';
          
          final newWordExercise = DutchWordExercise(
            id: card.id,
            targetWord: card.word,
            wordTranslation: card.definition,
            deckId: deckId,
            deckName: deckName,
            category: WordCategory.common,
            difficulty: ExerciseDifficulty.beginner,
            exercises: exercisesToCreate,
            createdAt: DateTime.now(),
            isUserCreated: true,
            learningProgress: LearningProgress(),
          );
          
          await dutchProvider.addWordExercise(newWordExercise);
          print('AddCardView: Created new word exercise with ${exercisesToCreate.length} exercises');
        }
      }
    } catch (e) {
      print('AddCardView: Error creating selected exercises: $e');
      // Don't throw the error as this is not critical for card creation
    }
  }



  /// Get available exercise types based on card content
  List<String> _getAvailableExerciseTypes(FlashCard card) {
    final availableExercises = <String>[];
    
    // Basic multiple choice requires word and definition
    if (card.word.isNotEmpty && card.definition.isNotEmpty) {
      availableExercises.add('Basic Multiple Choice');
    }
    
    // De/Het Article Exercise requires article selection
    if (_selectedArticle.isNotEmpty) {
      availableExercises.add('De/Het Article Exercise');
    }
    
    // Plural Form Exercise requires plural text
    if (_pluralController.text.trim().isNotEmpty) {
      availableExercises.add('Plural Form Exercise');
    }
    
    // Sentence Building Exercise requires both example and translation
    if (_exampleController.text.trim().isNotEmpty && _exampleTranslationController.text.trim().isNotEmpty) {
      availableExercises.add('Sentence Building Exercise');
    }
    
    return availableExercises;
  }

  /// Check what exercises will be removed if data is deleted
  List<String> _getExercisesToRemove(FlashCard originalCard) {
    final exercisesToRemove = <String>[];
    
    // Check if article was removed
    if (originalCard.article?.isNotEmpty == true && _selectedArticle.isEmpty) {
      exercisesToRemove.add('De/Het Article Exercise');
    }
    
    // Check if plural was removed
    if (originalCard.plural?.isNotEmpty == true && _pluralController.text.trim().isEmpty) {
      exercisesToRemove.add('Plural Form Exercise');
    }
    
    // Check if example or translation was removed
    if ((originalCard.example?.isNotEmpty == true && _exampleController.text.trim().isEmpty) ||
        (originalCard.exampleTranslation?.isNotEmpty == true && _exampleTranslationController.text.trim().isEmpty)) {
      exercisesToRemove.add('Sentence Building Exercise');
    }
    
    return exercisesToRemove;
  }

  /// Get new exercise types that were added to the card
  List<String> _getNewExerciseTypes(FlashCard originalCard, FlashCard updatedCard) {
    final newExerciseTypes = <String>[];

    // Check if article was added (not changed, only added)
    if ((originalCard.article?.isEmpty ?? true) && (updatedCard.article?.isNotEmpty ?? false)) {
      newExerciseTypes.add('De/Het Article Exercise');
    }

    // Check if plural was added (not changed, only added)
    if ((originalCard.plural?.isEmpty ?? true) && (updatedCard.plural?.isNotEmpty ?? false)) {
      newExerciseTypes.add('Plural Form Exercise');
    }

    // Check if example and translation were both added (not changed, only added)
    if ((originalCard.example?.isEmpty ?? true) && (updatedCard.example?.isNotEmpty ?? false) &&
        (originalCard.exampleTranslation?.isEmpty ?? true) && (updatedCard.exampleTranslation?.isNotEmpty ?? false)) {
      newExerciseTypes.add('Sentence Building Exercise');
    }

    return newExerciseTypes;
  }

  /// Show exercise selection dialog using a different approach
  Future<List<String>> _showExerciseSelectionDialog(String word, List<String> availableExercises) async {
    if (!mounted) {
      return [];
    }
    
    final selectedExercises = <String>{};
    
    // Check for existing exercises
    final dutchProvider = context.read<DutchWordExerciseProvider>();
    final existingExercise = dutchProvider.getWordExerciseByWord(word);
    
    try {
      // Use a completely different approach - create a custom dialog
      final result = await showDialog<List<String>>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxHeight: 600),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text(
                      'Select Exercises',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    Text('Which exercises would you like to create for "$word"?'),
                    const SizedBox(height: 16),
                    
                    // Show existing exercises if any
                    if (existingExercise != null && existingExercise.exercises.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Existing Exercises (${existingExercise.exercises.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...existingExercise.exercises.map((exercise) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 24, bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getExerciseTypeIcon(exercise.type),
                                      size: 14,
                                      color: Colors.blue[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getExerciseTypeName(exercise.type),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  
                  // Exercise checkboxes
                  ...availableExercises.map((exercise) {
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return CheckboxListTile(
                          title: Text(exercise),
                          value: selectedExercises.contains(exercise),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedExercises.add(exercise);
                              } else {
                                selectedExercises.remove(exercise);
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        );
                      },
                    );
                  }),
                  
                  const SizedBox(height: 20),
                  
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          print('Cancel pressed - new dialog approach');
                          Navigator.of(context).pop(<String>[]);
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          print('Create selected pressed - new dialog approach');
                          Navigator.of(context).pop(selectedExercises.toList());
                        },
                        child: const Text('Create Selected'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          );
        },
      );
      
      return result ?? [];
    } catch (e) {
      print('Error showing exercise selection dialog: $e');
      return [];
    }
  }

  /// Get exercise type name for display
  String _getExerciseTypeName(ExerciseType type) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return 'Multiple Choice';
      case ExerciseType.fillInBlank:
        return 'Fill in the Blank';
      case ExerciseType.sentenceBuilding:
        return 'Sentence Building';
      case ExerciseType.multipleChoice:
        return 'True/False';
      default:
        return 'Unknown';
    }
  }

  /// Get exercise type icon for display
  IconData _getExerciseTypeIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return Icons.quiz;
      case ExerciseType.fillInBlank:
        return Icons.edit;
      case ExerciseType.sentenceBuilding:
        return Icons.construction;
      case ExerciseType.multipleChoice:
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  /// Show dialog asking if user wants to remove exercises
  Future<bool> _showRemoveExercisesDialog(List<String> exercisesToRemove) async {
    if (!mounted) {
      return false;
    }
    
    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove Exercises?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The following exercises will be removed because their required data was deleted:'),
              const SizedBox(height: 16),
              ...exercisesToRemove.map((exercise) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(exercise),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              const Text('Do you want to continue?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove Exercises'),
            ),
          ],
        ),
      );
      
      return result ?? false;
    } catch (e) {
      print('Error showing remove exercises dialog: $e');
      return false;
    }
  }

  /// Remove exercises from the Dutch word exercise provider
  Future<void> _removeExercises(FlashCard card, List<String> exercisesToRemove) async {
    try {
      final dutchProvider = context.read<DutchWordExerciseProvider>();
      final existingExercise = dutchProvider.getWordExerciseByWord(card.word);
      
      if (existingExercise != null) {
        // Filter out exercises that should be removed
        final remainingExercises = existingExercise.exercises.where((exercise) {
          // Check if this exercise should be removed
          if (exercisesToRemove.contains('De/Het Article Exercise') && 
              exercise.prompt.contains('De or Het')) {
            return false; // Remove this exercise
          }
          if (exercisesToRemove.contains('Plural Form Exercise') && 
              exercise.prompt.contains('plural form')) {
            return false; // Remove this exercise
          }
          if (exercisesToRemove.contains('Sentence Building Exercise') && 
              exercise.prompt.contains('Build the correct Dutch sentence')) {
            return false; // Remove this exercise
          }
          return true; // Keep this exercise
        }).toList();
        
        if (remainingExercises.isEmpty) {
          // Remove the entire word exercise if no exercises remain
          await dutchProvider.deleteWordExercise(existingExercise.id);
          print('AddCardView: Removed entire word exercise for "${card.word}"');
        } else {
          // Update the word exercise with remaining exercises
          final updatedExercise = DutchWordExercise(
            id: existingExercise.id,
            targetWord: existingExercise.targetWord,
            wordTranslation: existingExercise.wordTranslation,
            deckId: existingExercise.deckId,
            deckName: existingExercise.deckName,
            category: existingExercise.category,
            difficulty: existingExercise.difficulty,
            exercises: remainingExercises,
            createdAt: existingExercise.createdAt,
            isUserCreated: existingExercise.isUserCreated,
            learningProgress: existingExercise.learningProgress,
          );
          
          await dutchProvider.updateWordExercise(updatedExercise);
          print('AddCardView: Updated word exercise for "${card.word}" - removed ${existingExercise.exercises.length - remainingExercises.length} exercises');
        }
      }
    } catch (e) {
      print('AddCardView: Error removing exercises: $e');
    }
  }

  /// Show dialog asking which exercises user wants to create
  Future<List<String>> _showCreateExercisesDialog(String word, List<String> availableExercises, {String? message}) async {
    // Check if widget is still mounted before showing dialog
    if (!mounted) {
      return [];
    }
    
    final selectedExercises = <String>{};
    
    try {
      // First show a simple confirmation dialog
      final shouldShowDialog = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Create Exercises?'),
          content: Text(message ?? 'Would you like me to create exercises for "$word"?'),
          actions: [
            TextButton(
              onPressed: () {
                print('No thanks pressed - simple dialog');
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('No, thanks'),
            ),
            ElevatedButton(
              onPressed: () {
                print('Yes pressed - simple dialog');
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Yes, create exercises'),
            ),
          ],
        ),
      );
      
      print('Simple dialog result: $shouldShowDialog');
      
      if (shouldShowDialog != true) {
        return [];
      }
      
      // If user wants to create exercises, show the detailed dialog using a different approach
      final result = await _showExerciseSelectionDialog(word, availableExercises);
      
      print('Detailed dialog result: $result');
      return result ?? [];
    } catch (e) {
      print('Error showing exercise creation dialog: $e');
      return [];
    }
  }



  // Note: Automatic grammar exercise generation has been completely disabled
  // Exercises are now only created when explicitly requested by the user

  Widget _buildCustomHeader(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            widget.cardToEdit != null ? 'Edit Card' : 'Add Card',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        
        // Left side - Back button with proper padding
        Positioned(
          left: 16, // Add proper padding from left edge
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: () {
              if (_hasUnsavedChanges()) {
                _showUnsavedChangesDialog();
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        
        // Right side - Add/Save button or loading indicator
        Positioned(
          right: 16, // Add proper padding from right edge
          top: 0,
          bottom: 0,
          child: _isLoading
              ? const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                )
              : IconButton(
                  onPressed: _canSave() ? _submitCard : null,
                  icon: Icon(
                    Icons.save,
                    color: _canSave() 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    size: 24,
                  ),
                  tooltip: _canSave() 
                      ? (widget.cardToEdit != null ? 'Save' : 'Add')
                      : 'Add',
                ),
        ),
      ],
    );
  }
} 