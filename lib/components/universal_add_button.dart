import 'package:flutter/material.dart';
import '../views/add_deck_view.dart';
import '../views/add_card_view.dart';
import '../views/add_phrase_view.dart';
import '../views/photo_import_view.dart';

class UniversalAddButton extends StatelessWidget {
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final String? initialDeckId;

  const UniversalAddButton({
    super.key,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.initialDeckId,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showCreateItemDialog(context),
      tooltip: tooltip ?? 'Add New Item',
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      child: const Icon(Icons.add),
    );
  }

  void _showCreateItemDialog(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'card',
          child: Row(
            children: [
              Icon(Icons.style, size: 20, color: Colors.green),
              SizedBox(width: 12),
              Text('New Card'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.camera_alt, size: 20, color: Colors.blue),
              SizedBox(width: 12),
              Text('Import Cards'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'deck',
          child: Row(
            children: [
              Icon(Icons.folder, size: 20, color: Colors.blue),
              SizedBox(width: 12),
              Text('New Deck'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'card':
            _navigateToAddCard(context);
            break;
          case 'import':
            _navigateToImport(context);
            break;
          case 'deck':
            _navigateToAddDeck(context);
            break;
        }
      }
    });
  }


  void _navigateToAddDeck(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddDeckView(),
      ),
    );
  }

  void _navigateToAddCard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCardView(initialDeckId: initialDeckId),
      ),
    );
  }

  void _navigateToImport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoImportView(initialDeckId: initialDeckId),
      ),
    );
  }

}
