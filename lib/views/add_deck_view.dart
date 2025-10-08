import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';

import '../models/deck.dart';

class AddDeckView extends StatefulWidget {
  final String? parentDeckId;
  
  const AddDeckView({
    super.key,
    this.parentDeckId,
  });

  @override
  State<AddDeckView> createState() => _AddDeckViewState();
}

class _AddDeckViewState extends State<AddDeckView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedParentDeckId = '';
  bool _isSubDeck = false;
  bool _isPublic = false; // Private by default

  @override
  void initState() {
    super.initState();
    if (widget.parentDeckId != null) {
      _selectedParentDeckId = widget.parentDeckId!;
      _isSubDeck = true;
    }
    
    // Add listener to update save button state
    _nameController.addListener(() {
      setState(() {
        // This will trigger a rebuild to update the save button state
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfoSection(),
                    const SizedBox(height: 24),
                    _buildParentDeckSection(),
                    const SizedBox(height: 24),
                    _buildVisibilitySection(),
                    const SizedBox(height: 24),
                    _buildActionsSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Deck Name *',
                hintText: 'Enter deck name',
                border: const OutlineInputBorder(),
                errorText: _getDuplicateWarning(),
              ),
              onChanged: (value) {
                setState(() {
                  // Trigger rebuild to show/hide duplicate warning
                });
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a deck name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter deck description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentDeckSection() {
    return Consumer<FlashcardProvider>(
      builder: (context, provider, child) {
        final rootDecks = provider.getRootDecks();
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deck Organization',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Create as sub-deck'),
                  subtitle: const Text('Organize under another deck'),
                  value: _isSubDeck,
                  onChanged: (value) {
                    setState(() {
                      _isSubDeck = value ?? false;
                      if (!_isSubDeck) {
                        _selectedParentDeckId = '';
                      }
                    });
                  },
                ),
                if (_isSubDeck) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedParentDeckId.isEmpty ? null : _selectedParentDeckId,
                    decoration: const InputDecoration(
                      labelText: 'Parent Deck *',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Select a parent deck'),
                      ),
                      ...rootDecks.map((deck) => DropdownMenuItem(
                        value: deck.id,
                        child: Text(deck.name),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedParentDeckId = value ?? '';
                      });
                    },
                    validator: _isSubDeck ? (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a parent deck';
                      }
                      return null;
                    } : null,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildVisibilitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deck Visibility',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Make this deck public'),
              subtitle: const Text('Allow friends to see and study this deck'),
              value: _isPublic,
              onChanged: (value) {
                setState(() {
                  _isPublic = value ?? false;
                });
              },
              secondary: Icon(
                _isPublic ? Icons.visibility : Icons.visibility_off,
                color: _isPublic ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _createDeck,
            child: const Text('Create Deck'),
          ),
        ),
      ],
    );
  }

  Deck? _findDuplicateDeck() {
    final deckName = _nameController.text.trim().toLowerCase();
    if (deckName.isEmpty) return null;
    
    final provider = context.read<FlashcardProvider>();
    final allDecks = provider.decks;
    
    try {
      final duplicateDeck = allDecks.firstWhere(
        (deck) => deck.name.toLowerCase() == deckName,
      );
      
      return duplicateDeck;
    } catch (e) {
      return null;
    }
  }

  String? _getDuplicateWarning() {
    final duplicateDeck = _findDuplicateDeck();
    if (duplicateDeck != null) {
      return 'This deck already exists';
    }
    
    return null;
  }

  bool _canSave() {
    return _nameController.text.trim().isNotEmpty;
  }

  void _createDeck() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<FlashcardProvider>();
    final deckName = _nameController.text.trim();
    final parentId = _isSubDeck ? _selectedParentDeckId : null;

    // Check for duplicate deck
    final duplicateDeck = _findDuplicateDeck();
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

    provider.createDeck(
      deckName, 
      parentId: parentId,
      isPublic: _isPublic,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deck "$deckName" created successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.of(context).pop();
  }


  Widget _buildCustomHeader(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            'Create Deck',
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
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        
        // Right side - Save button
        Positioned(
          right: 16, // Add proper padding from right edge
          top: 0,
          bottom: 0,
          child: IconButton(
            onPressed: _canSave() ? _createDeck : null,
            icon: Icon(
              Icons.save,
              color: _canSave() 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              size: 24,
            ),
            tooltip: 'Save Deck',
          ),
        ),
      ],
    );
  }
} 