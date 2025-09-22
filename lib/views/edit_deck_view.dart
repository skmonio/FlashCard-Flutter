import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';

import '../models/deck.dart';

class EditDeckView extends StatefulWidget {
  final Deck deck;
  
  const EditDeckView({
    super.key,
    required this.deck,
  });

  @override
  State<EditDeckView> createState() => _EditDeckViewState();
}

class _EditDeckViewState extends State<EditDeckView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedParentDeckId = '';
  bool _isSubDeck = false;
  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate the form with existing deck data
    _nameController.text = widget.deck.name;
    _selectedParentDeckId = widget.deck.parentId ?? '';
    _isSubDeck = widget.deck.parentId != null;
    _isPublic = widget.deck.isPublic;
    
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
              decoration: const InputDecoration(
                labelText: 'Deck Name *',
                hintText: 'Enter deck name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a deck name';
                }
                return null;
              },
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildParentDeckSection() {
    return Consumer<FlashcardProvider>(
      builder: (context, provider, child) {
        final rootDecks = provider.decks
            .where((deck) => deck.parentId == null && deck.id != widget.deck.id)
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        
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
                  title: const Text('Make this a sub-deck'),
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

  bool _canSave() {
    return _nameController.text.trim().isNotEmpty &&
           (!_isSubDeck || _selectedParentDeckId.isNotEmpty);
  }

  void _updateDeck() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<FlashcardProvider>();
    final deckName = _nameController.text.trim();
    final parentId = _isSubDeck ? _selectedParentDeckId : null;

    // Create updated deck
    final updatedDeck = Deck(
      id: widget.deck.id,
      name: deckName,
      cards: widget.deck.cards,
      parentId: parentId,
      subDeckIds: widget.deck.subDeckIds,
      dateCreated: widget.deck.dateCreated,
      lastModified: DateTime.now(),
      isPublic: _isPublic,
      cloudKitRecordName: widget.deck.cloudKitRecordName,
    );

    try {
      // Update the deck
      await provider.updateDeck(updatedDeck);
      
      // If public status changed, also update all cards in the deck
      if (widget.deck.isPublic != _isPublic) {
        await provider.updateDeckPublicStatus(widget.deck.id, _isPublic);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deck "$deckName" updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update deck: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Stack(
      children: [
        // Centered title - always in the center regardless of other elements
        Center(
          child: Text(
            'Edit Deck',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
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
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          ),
        ),
        
        // Right side - Save button
        Positioned(
          right: 16, // Add proper padding from right edge
          top: 0,
          bottom: 0,
          child: TextButton(
            onPressed: _canSave() ? _updateDeck : null,
            child: Text(
              'Save',
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
      ],
    );
  }
} 