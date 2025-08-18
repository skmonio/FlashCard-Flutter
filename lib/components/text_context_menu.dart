import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/translation_service.dart';

class TextContextMenu extends StatelessWidget {
  final String selectedText;
  final VoidCallback? onCopy;
  final VoidCallback? onTranslate;
  final VoidCallback? onAddToDeck;
  final VoidCallback? onSearch;
  final bool showAddToDeck;
  final bool showSearch;

  const TextContextMenu({
    super.key,
    required this.selectedText,
    this.onCopy,
    this.onTranslate,
    this.onAddToDeck,
    this.onSearch,
    this.showAddToDeck = true,
    this.showSearch = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected text preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              selectedText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Menu options
          ..._buildMenuItems(context),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final items = <Widget>[];

    // Copy option
    items.add(_buildMenuItem(
      context,
      icon: Icons.copy,
      label: 'Copy',
      onTap: () {
        Clipboard.setData(ClipboardData(text: selectedText));
        onCopy?.call();
        Navigator.of(context).pop();
        _showSnackBar(context, 'Copied to clipboard');
      },
    ));

    // Translate option
    items.add(_buildMenuItem(
      context,
      icon: Icons.translate,
      label: 'Translate',
      onTap: () async {
        Navigator.of(context).pop();
        onTranslate?.call();
        await _showTranslationDialog(context);
      },
    ));

    // Add to deck option
    if (showAddToDeck) {
      items.add(_buildMenuItem(
        context,
        icon: Icons.add_card,
        label: 'Add to Deck',
        onTap: () {
          Navigator.of(context).pop();
          onAddToDeck?.call();
        },
      ));
    }

    // Search option
    if (showSearch) {
      items.add(_buildMenuItem(
        context,
        icon: Icons.search,
        label: 'Search',
        onTap: () {
          Navigator.of(context).pop();
          onSearch?.call();
        },
      ));
    }

    return items;
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTranslationDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Translation'),
        content: FutureBuilder<String?>(
          future: TranslationService().translateDutchToEnglish(selectedText),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Translating...'),
                ],
              );
            }
            
            if (snapshot.hasError) {
              return Text('Translation error: ${snapshot.error}');
            }
            
            final translation = snapshot.data;
            if (translation == null || translation.isEmpty) {
              return const Text('No translation available');
            }
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  translation,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Extension to add context menu to SelectableText
extension SelectableTextContextMenu on SelectableText {
  Widget withContextMenu({
    required String text,
    VoidCallback? onCopy,
    VoidCallback? onTranslate,
    VoidCallback? onAddToDeck,
    VoidCallback? onSearch,
    bool showAddToDeck = true,
    bool showSearch = true,
  }) {
    return SelectableText(
      text,
      contextMenuBuilder: (context, editableTextState) {
        final selectedText = editableTextState.textEditingValue.selection.textInside(text);
        if (selectedText.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return TextContextMenu(
          selectedText: selectedText,
          onCopy: onCopy,
          onTranslate: onTranslate,
          onAddToDeck: onAddToDeck,
          onSearch: onSearch,
          showAddToDeck: showAddToDeck,
          showSearch: showSearch,
        );
      },
    );
  }
}
