import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/flashcard_provider.dart';

import '../models/deck.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../models/flash_card.dart';
import '../services/translation_service.dart';
import '../providers/translation_language_provider.dart';
import '../utils/enhanced_snackbar.dart';

class AddCardView extends StatefulWidget {
  final Deck? selectedDeck;
  final String? initialDeckId; // Added to support pre-selected deck via ID
  final FlashCard? cardToEdit; // For editing existing cards
  final String? preFilledWord; // For pre-filling the word field
  
  const AddCardView({
    super.key,
    this.selectedDeck,
    this.initialDeckId,
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
  final _presentTenseController = TextEditingController();
  final _pastTenseController = TextEditingController();
  final _perfectTenseController = TextEditingController();
  
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
  String _originalPresentTense = '';
  String _originalPastTense = '';
  String _originalPerfectTense = '';
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
      _presentTenseController.text = card.presentTense ?? '';
      _pastTenseController.text = card.pastTense ?? '';
      _perfectTenseController.text = card.perfectTense ?? '';
      _selectedArticle = card.article ?? '';
      _selectedDeckIds = List.from(card.deckIds);
      
      // Store original values for change detection
      _originalWord = card.word;
      _originalDefinition = card.definition;
      _originalExample = card.example ?? '';
      _originalExampleTranslation = card.exampleTranslation ?? '';
      _originalPlural = card.plural ?? '';
      _originalPresentTense = card.presentTense ?? '';
      _originalPastTense = card.pastTense ?? '';
      _originalPerfectTense = card.perfectTense ?? '';
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
    } else if (widget.initialDeckId != null) {
      // If adding a new card with a pre-selected deck via ID
      _selectedDeckIds = [widget.initialDeckId!];
      _originalDeckIds = [widget.initialDeckId!];
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

    _exampleTranslationController.addListener(() => setState(() {}));
    _pluralController.addListener(() => setState(() {}));
    _presentTenseController.addListener(() => setState(() {}));
    _pastTenseController.addListener(() => setState(() {}));
    _perfectTenseController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _wordController.dispose();
    _definitionController.dispose();
    _exampleController.dispose();
    _exampleTranslationController.dispose();
    _pluralController.dispose();
    _presentTenseController.dispose();
    _pastTenseController.dispose();
    _perfectTenseController.dispose();
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
                                      suffixIcon: _wordController.text.isNotEmpty ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _wordController.clear();
                                          setState(() {});
                                        },
                                      ) : null,
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
                    
                    // Article Selection (moved before translation)
                    _buildArticleSelector(),
                    const SizedBox(height: 16),
                    
                    // Definition with Translate Button
                    Consumer<TranslationLanguageProvider>(
                      builder: (context, langProvider, child) {
                        final translationLanguageName = langProvider.translationLanguage.name;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                      suffixIcon: _definitionController.text.isNotEmpty ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _definitionController.clear();
                                          setState(() {});
                                        },
                                      ) : null,
                                      counterText: '',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        // Allow empty definition if it's a duplicate card (user might just want to add to decks)
                                        if (_findDuplicateCard() != null) {
                                          return null;
                                        }
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
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Example Sentence
                    TextFormField(
                      controller: _exampleController,
                      maxLines: 2,
                      maxLength: 300,
                      decoration: InputDecoration(
                        labelText: 'Example Sentence',
                        hintText: 'e.g., Ik woon in een groot huis.',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.format_quote),
                        suffixIcon: _exampleController.text.isNotEmpty ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _exampleController.clear();
                            setState(() {});
                          },
                        ) : null,
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
                      decoration: InputDecoration(
                        labelText: 'Example Translation',
                        hintText: 'e.g., I live in a big house.',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.translate),
                        suffixIcon: _exampleTranslationController.text.isNotEmpty ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _exampleTranslationController.clear();
                            setState(() {});
                          },
                        ) : null,
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
                      decoration: InputDecoration(
                        labelText: 'Plural Form',
                        hintText: 'e.g., huizen',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.list),
                        suffixIcon: _pluralController.text.isNotEmpty ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _pluralController.clear();
                            setState(() {});
                          },
                        ) : null,
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

                    // Game Compatibility
                    _buildSectionHeader('Game Compatibility'),
                    const SizedBox(height: 12),
                    _buildGameCompatibility(),
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
        const SizedBox(height: 12),
        // Present Tense
        TextFormField(
          controller: _presentTenseController,
          maxLength: 100,
          decoration: InputDecoration(
            labelText: 'Present Tense - Tegenwoordige Tijd',
            hintText: 'e.g., Ik ga',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.today),
            suffixIcon: _presentTenseController.text.isNotEmpty ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _presentTenseController.clear();
                setState(() {});
              },
            ) : null,
            counterText: '',
          ),
          validator: (value) {
            if (value != null && value.length > 100) {
              return 'Present tense must be 100 characters or less';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        // Past Tense
        TextFormField(
          controller: _pastTenseController,
          maxLength: 100,
          decoration: InputDecoration(
            labelText: 'Past Tense - Verleden Tijd',
            hintText: 'e.g., Ik ging',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.history),
            suffixIcon: _pastTenseController.text.isNotEmpty ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _pastTenseController.clear();
                setState(() {});
              },
            ) : null,
            counterText: '',
          ),
          validator: (value) {
            if (value != null && value.length > 100) {
              return 'Past tense must be 100 characters or less';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        // Perfect Tense
        TextFormField(
          controller: _perfectTenseController,
          maxLength: 100,
          decoration: InputDecoration(
            labelText: 'Perfect Tense - Voltooide Tijd',
            hintText: 'e.g., Ik ben gegaan',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.done_all),
            suffixIcon: _perfectTenseController.text.isNotEmpty ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _perfectTenseController.clear();
                setState(() {});
              },
            ) : null,
            counterText: '',
          ),
          validator: (value) {
            if (value != null && value.length > 100) {
              return 'Perfect tense must be 100 characters or less';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildGameCompatibility() {
    final hasWord = _wordController.text.trim().isNotEmpty;
    final hasDef = _definitionController.text.trim().isNotEmpty;
    final hasArticle = _selectedArticle.isNotEmpty;
    final hasPlural = _pluralController.text.trim().isNotEmpty;
    final hasTense = _presentTenseController.text.trim().isNotEmpty ||
        _pastTenseController.text.trim().isNotEmpty ||
        _perfectTenseController.text.trim().isNotEmpty;
    final hasExample = _exampleController.text.trim().isNotEmpty &&
        _exampleTranslationController.text.trim().isNotEmpty;

    final games = [
      _GameChip(label: 'Multiple Choice', icon: Icons.check_circle_outline, active: hasWord && hasDef),
      _GameChip(label: 'True / False', icon: Icons.help_outline, active: hasWord && hasDef),
      _GameChip(label: 'Memory', icon: Icons.psychology, active: hasWord && hasDef),
      _GameChip(label: 'Writing', icon: Icons.edit, active: hasWord),
      _GameChip(label: 'Word Scramble', icon: Icons.text_fields, active: hasWord),
      _GameChip(label: 'Pop Your Card', icon: Icons.bubble_chart, active: hasWord),
      _GameChip(label: 'Pick Your Card', icon: Icons.touch_app, active: hasWord),
      _GameChip(label: 'De / Het', icon: Icons.article, active: hasArticle),
      _GameChip(label: 'Plurals', icon: Icons.format_list_numbered, active: hasPlural),
      _GameChip(label: 'Verb Tenses', icon: Icons.timeline, active: hasTense),
      _GameChip(label: 'Sentence Building', icon: Icons.short_text, active: hasExample),
    ];

    final activeCount = games.where((g) => g.active).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active in $activeCount of ${games.length} games',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: games.map((g) {
            final color = g.active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: g.active
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(g.icon, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    g.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: g.active ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
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
      
      // If article is selected, include it in the translation for better accuracy
      // e.g., translate "de lol" instead of just "lol"
      final wordToTranslate = _selectedArticle.isNotEmpty 
          ? '${_selectedArticle} $word'
          : word;
      
      final translation = await _translationService.translate(
        wordToTranslate,
        sourceLanguageCode: wordLanguageCode,
        targetLanguageCode: targetLanguageCode,
      );
      
      if (mounted) {
        // Clean the translation result - remove any article that might have been translated
        String cleanedTranslation = translation ?? '';
        if (cleanedTranslation.isNotEmpty && _selectedArticle.isNotEmpty) {
          // Remove common article translations from the result
          // This handles cases where "de lol" might translate to "the fun" or "the joke"
          final lowerTranslation = cleanedTranslation.toLowerCase().trim();
          if (lowerTranslation.startsWith('the ')) {
            cleanedTranslation = cleanedTranslation.substring(4).trim();
          }
        }
        
        setState(() {
          _definitionController.text = cleanedTranslation;
          _isLoading = false;
        });
        
        if (cleanedTranslation.isNotEmpty) {
          final displayWord = _selectedArticle.isNotEmpty ? '$wordToTranslate' : word;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Translated: "$displayWord" → "$cleanedTranslation"'),
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
    final word = _wordController.text.trim();
    final definition = _definitionController.text.trim();
    
    // Can save if word is not empty AND (definition is not empty OR it's a duplicate card)
    if (word.isEmpty) return false;
    
    if (definition.isNotEmpty) return true;
    
    // If definition is empty, only allow save if the word already exists
    return _findDuplicateCard() != null;
  }

  bool _hasUnsavedChanges() {
    // Check if any field has been modified from its original value
    return _wordController.text.trim() != _originalWord ||
           _definitionController.text.trim() != _originalDefinition ||
           _exampleController.text.trim() != _originalExample ||
           _exampleTranslationController.text.trim() != _originalExampleTranslation ||
           _pluralController.text.trim() != _originalPlural ||
           _presentTenseController.text.trim() != _originalPresentTense ||
           _pastTenseController.text.trim() != _originalPastTense ||
           _perfectTenseController.text.trim() != _originalPerfectTense ||
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
      return 'Note: This word already exists';
    }
    
    return null;
  }

  Future<String?> _showDuplicateDialog(FlashCard duplicateCard) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Word Already Exists'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The word "${duplicateCard.word}" already exists in your library.'),
            const SizedBox(height: 12),
            Text('Existing definition: ${duplicateCard.definition}'),
            const SizedBox(height: 16),
            const Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('add_to_decks'),
            child: const Text('Keep Existing & Add to Decks'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('overwrite'),
            child: const Text('Overwrite with New Info'),
          ),
        ],
      ),
    );
  }

  void _submitCard() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // If no deck is selected, let the service default to "Uncategorized"
    // The FlashcardService.createCard method will handle empty deckIds by creating/using Uncategorized deck
    
    // Check for duplicate card
    FlashCard? cardToEdit = widget.cardToEdit;
    final duplicateCard = _findDuplicateCard();
    
    if (duplicateCard != null && cardToEdit == null) {
      // Found a duplicate and we're NOT in edit mode for a specific card
      final action = await _showDuplicateDialog(duplicateCard);
      
      if (action == null) {
        return; // User cancelled
      }
      
      if (action == 'add_to_decks') {
        setState(() {
          _isLoading = true;
        });
        
        try {
          final provider = context.read<FlashcardProvider>();
          // Combine existing decks with currently selected ones
          final updatedDeckIds = {...duplicateCard.deckIds, ..._selectedDeckIds};
          
          final updatedCard = duplicateCard.copyWith(
            deckIds: updatedDeckIds,
            lastModified: DateTime.now(),
          );
          
          await provider.updateCard(updatedCard);
          
          if (mounted) {
            EnhancedSnackBar.showSuccess(
              context,
              message: 'Added "${duplicateCard.word}" to selected decks!',
            );
            Navigator.of(context).pop(true);
          }
          return;
        } catch (e) {
          if (mounted) {
            EnhancedSnackBar.showError(context, message: 'Failed to update decks: $e');
            setState(() { _isLoading = false; });
          }
          return;
        }
      } else if (action == 'overwrite') {
        // Set cardToEdit to the duplicate card so the logic below treats it as an update
        cardToEdit = duplicateCard;
      }
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final provider = context.read<FlashcardProvider>();
      
      if (cardToEdit != null) {
        // Update existing card using copyWith to preserve fields not in the form
        final updatedCard = cardToEdit.copyWith(
          word: _wordController.text.trim(),
          definition: _definitionController.text.trim().isEmpty ? null : _definitionController.text.trim(),
          example: _exampleController.text.trim().isEmpty ? null : _exampleController.text.trim(),
          exampleTranslation: _exampleTranslationController.text.trim().isEmpty ? null : _exampleTranslationController.text.trim(),
          deckIds: _selectedDeckIds.toSet(),
          lastModified: DateTime.now(),
          article: _selectedArticle,
          plural: _pluralController.text.trim().isEmpty ? '' : _pluralController.text.trim(),
          presentTense: _presentTenseController.text.trim().isEmpty ? '' : _presentTenseController.text.trim(),
          pastTense: _pastTenseController.text.trim().isEmpty ? '' : _pastTenseController.text.trim(),
          perfectTense: _perfectTenseController.text.trim().isEmpty ? '' : _perfectTenseController.text.trim(),
        );
        
        await provider.updateCard(updatedCard);
        
        if (mounted) {
        if (mounted) Navigator.of(context).pop(true);
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
          presentTense: _presentTenseController.text.trim().isEmpty ? '' : _presentTenseController.text.trim(),
          pastTense: _pastTenseController.text.trim().isEmpty ? '' : _pastTenseController.text.trim(),
          perfectTense: _perfectTenseController.text.trim().isEmpty ? '' : _perfectTenseController.text.trim(),
          deckIds: _selectedDeckIds.toSet(),
        );
        
        if (mounted && newCard != null) {
          EnhancedSnackBar.showSuccess(
            context,
            message: 'Card added successfully!',
          );
          
          if (mounted) Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        EnhancedSnackBar.showError(
          context,
          message: 'Error ${cardToEdit != null ? 'updating' : 'adding'} card: $e',
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

  // Removed _syncExercises method as exercises are replaced by games



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

class _GameChip {
  final String label;
  final IconData icon;
  final bool active;
  const _GameChip({required this.label, required this.icon, required this.active});
}