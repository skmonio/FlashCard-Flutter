import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../providers/flashcard_provider.dart';

class DeckSelectionDialog extends StatefulWidget {
  final List<Deck> decks;
  final bool isMove;
  final Function(List<String>) onConfirm;

  const DeckSelectionDialog({
    super.key,
    required this.decks,
    required this.isMove,
    required this.onConfirm,
  });

  @override
  State<DeckSelectionDialog> createState() => _DeckSelectionDialogState();
}

class _DeckSelectionDialogState extends State<DeckSelectionDialog> {
  final Set<String> _selectedDeckIds = {};

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FlashcardProvider>();
    final cardCounts = {
      for (final deck in widget.decks)
        deck.id: provider.getCardsForDeck(deck.id).length,
    };
    return AlertDialog(
      title: Text('Select Deck${widget.decks.length > 1 ? 's' : ''} to ${widget.isMove ? 'Move' : 'Copy'} To'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: widget.decks.length,
          itemBuilder: (context, index) {
            final deck = widget.decks[index];
            final isSelected = _selectedDeckIds.contains(deck.id);
            return CheckboxListTile(
              title: Text(deck.name),
              subtitle: Text('${cardCounts[deck.id] ?? 0} cards'),
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
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _selectedDeckIds.isEmpty ? null : () => widget.onConfirm(_selectedDeckIds.toList()),
          style: TextButton.styleFrom(
            foregroundColor: widget.isMove ? Colors.blue : Colors.green,
          ),
          child: Text('${widget.isMove ? "Move" : "Copy"} to ${_selectedDeckIds.length} deck${_selectedDeckIds.length == 1 ? '' : 's'}'),
        ),
      ],
    );
  }
}
