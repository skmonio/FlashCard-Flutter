import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../providers/bubble_word_provider.dart';
import '../providers/flashcard_provider.dart';
import '../models/bubble_word_models.dart';
import '../components/unified_header.dart';
import '../services/haptic_service.dart';

class BubbleWordView extends StatefulWidget {
  const BubbleWordView({super.key});

  @override
  State<BubbleWordView> createState() => _BubbleWordViewState();
}

class _BubbleWordViewState extends State<BubbleWordView> {
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _definitionController = TextEditingController();
  bool _showingAddWord = false;
  bool _showingEditWord = false;
  WordNode? _editingNode;
  


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _wordController.dispose();
    _definitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BubbleWordProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            children: [
              // Header
              UnifiedHeader(
                title: 'Bubble Words',
                onBack: () => _showSavePrompt(context),
                trailing: _buildTrailingMenu(context, provider),
              ),
              
              // Action buttons
              _buildActionButtons(provider),
              
              // Canvas
              Expanded(
                child: Stack(
                  children: [
                    _buildCanvas(provider),
                    
                    // Show create map button if no maps exist
                    if (provider.maps.isEmpty)
                      Positioned.fill(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bubble_chart,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Maps Yet',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first bubble word map to get started',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _showCreateMapDialog(context, provider),
                                icon: const Icon(Icons.add),
                                label: const Text('Create New Map'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Zoom controls - positioned in bottom right
                    Positioned(
                      bottom: 32,
                      right: 20,
                      child: Column(
                        children: [
                          // Reset view
                          FloatingActionButton.small(
                            onPressed: () {
                              HapticService().buttonTapFeedback();
                              provider.setScale(1.0); // Reset to normal zoom
                              provider.setOffset(Offset.zero);
                            },
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            child: Icon(Icons.center_focus_strong, color: Theme.of(context).colorScheme.primary),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Zoom in
                          FloatingActionButton.small(
                            onPressed: () {
                              HapticService().buttonTapFeedback();
                              final newScale = (provider.scale * 1.2).clamp(0.5, 3.0);
                              provider.setScale(newScale);
                            },
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            child: Icon(Icons.zoom_in, color: Theme.of(context).colorScheme.primary),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Zoom out
                          FloatingActionButton.small(
                            onPressed: () {
                              HapticService().buttonTapFeedback();
                              final newScale = (provider.scale / 1.2).clamp(0.5, 3.0);
                              provider.setScale(newScale);
                            },
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            child: Icon(Icons.zoom_out, color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                    
                    // Floating action buttons - positioned in bottom right
                    Positioned(
                      bottom: 32,
                      left: 20,
                      child: Column(
                        children: [
                          // Add word button
                          if (provider.maps.isNotEmpty)
                            FloatingActionButton(
                              onPressed: () => _showAddWordOptions(context),
                              backgroundColor: Colors.green,
                              child: const Icon(Icons.add, color: Colors.white),
                            ),
                          
                          const SizedBox(height: 8),
                          
                          // Add map button (small)
                          if (provider.maps.isNotEmpty)
                            FloatingActionButton.small(
                              onPressed: () => _showCreateMapDialog(context, provider),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: const Icon(Icons.map, color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrailingMenu(BuildContext context, BubbleWordProvider provider) {
    return PopupMenuButton<String>(
      onSelected: (value) => _handleMenuAction(value, context, provider),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'add',
          child: Row(
            children: [
              Icon(Icons.add),
              SizedBox(width: 8),
              Text('Add Word'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'new_map',
          child: Row(
            children: [
              Icon(Icons.map),
              SizedBox(width: 8),
              Text('New Map'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'save_map',
          child: Row(
            children: [
              Icon(Icons.save),
              SizedBox(width: 8),
              Text('Save Map'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'overlay',
          child: Row(
            children: [
              Icon(Icons.layers),
              SizedBox(width: 8),
              Text('Overlay Maps'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'undo',
          enabled: provider.canUndo,
          child: Row(
            children: [
              Icon(Icons.undo, color: provider.canUndo ? null : Colors.grey),
              SizedBox(width: 8),
              Text('Undo', style: TextStyle(color: provider.canUndo ? null : Colors.grey)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'redo',
          enabled: provider.canRedo,
          child: Row(
            children: [
              Icon(Icons.redo, color: provider.canRedo ? null : Colors.grey),
              SizedBox(width: 8),
              Text('Redo', style: TextStyle(color: provider.canRedo ? null : Colors.grey)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'reset',
          child: Row(
            children: [
              Icon(Icons.refresh),
              SizedBox(width: 8),
              Text('Reset View'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'show_words',
          child: Row(
            children: [
              Icon(Icons.text_fields),
              SizedBox(width: 8),
              Text('Show Words'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'show_definitions',
          child: Row(
            children: [
              Icon(Icons.description),
              SizedBox(width: 8),
              Text('Show Definitions'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.clear_all, color: Colors.red),
              SizedBox(width: 8),
              Text('Clear All', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete_map',
          child: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Map', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BubbleWordProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Spacer(),
        ],
      ),
    );
  }



  Widget _buildCanvas(BubbleWordProvider provider) {
    // Debug information
    print('BubbleWordView: Building canvas');
    print('BubbleWordView: Current map: ${provider.currentMap?.name ?? "none"}');
    print('BubbleWordView: Nodes count: ${provider.nodes.length}');
    print('BubbleWordView: Connections count: ${provider.connections.length}');
    print('BubbleWordView: Scale: ${provider.scale}, Offset: ${provider.offset}');
    for (final node in provider.nodes) {
      print('BubbleWordView: Node "${node.word}" at position: ${node.position}');
    }
    
    return InteractiveViewer(
      minScale: 0.1,
      maxScale: 5.0,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      constrained: false,
      onInteractionUpdate: (details) {
        // Update provider scale and offset from InteractiveViewer
        provider.setScale(details.scale);
        provider.setOffset(details.focalPoint - Offset(
          MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height / 2,
        ));
      },
      child: GestureDetector(
        onTapUp: (details) {
          // Deselect if tapping on empty space
          if (provider.selectedNodeId != null) {
            provider.selectNode(null);
          }
        },
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          width: 2000, // Large canvas size
          height: 2000,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Connections
                  ...provider.connections.map((connection) => _buildConnection(connection, provider)),
                  
                  // Word bubbles
                  ...provider.nodes.map((node) => _buildWordBubble(node, provider)),
                  
                  // Empty state message
                  if (provider.nodes.isEmpty)
                    Positioned.fill(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bubble_chart,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No words yet',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to add your first word',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConnection(WordConnection connection, BubbleWordProvider provider) {
    // Find nodes by ID across all maps (current + overlays)
    WordNode? fromNode;
    WordNode? toNode;
    
    // First try to find in current map
    if (provider.currentMap != null) {
      try {
        fromNode = provider.currentMap!.nodes.firstWhere((node) => node.id == connection.fromNodeId);
        toNode = provider.currentMap!.nodes.firstWhere((node) => node.id == connection.toNodeId);
      } catch (e) {
        // Not found in current map, continue to overlays
      }
    }
    
    // If not found in current map, search in overlay maps
    if (fromNode == null || toNode == null) {
      for (final mapId in provider.overlayMapIds) {
        try {
          final overlayMap = provider.maps.firstWhere((map) => map.id == mapId);
          
          if (fromNode == null) {
            try {
              fromNode = overlayMap.nodes.firstWhere((node) => node.id == connection.fromNodeId);
            } catch (e) {
              // Continue searching
            }
          }
          
          if (toNode == null) {
            try {
              toNode = overlayMap.nodes.firstWhere((node) => node.id == connection.toNodeId);
            } catch (e) {
              // Continue searching
            }
          }
          
          if (fromNode != null && toNode != null) break;
        } catch (e) {
          // Overlay map not found, continue
        }
      }
    }
    
    if (fromNode == null || toNode == null) {
      print('BubbleWordView: Connection nodes not found: ${connection.fromNodeId} -> ${connection.toNodeId}');
      return const SizedBox.shrink();
    }
    
    return Transform.translate(
      offset: Offset.zero, // Connections are positioned at their raw coordinates
      child: GestureDetector(
        onLongPress: () => _showDeleteConnectionDialog(context, connection, provider),
        child: CustomPaint(
          size: Size.infinite,
          painter: ConnectionPainter(
            from: fromNode.position,
            to: toNode.position,
            color: connection.color,
          ),
        ),
      ),
    );
  }



  // Calculate dynamic bubble size based on text length
  double _calculateBubbleSize(String text) {
    const double minSize = 60.0;
    const double maxSize = 120.0; // Reduced from 150 to 120
    const double baseSize = 70.0; // Reduced from 80 to 70
    const double sizePerCharacter = 2.5; // Reduced from 4.0 to 2.5
    
    // Calculate size based on text length
    final calculatedSize = baseSize + (text.length * sizePerCharacter);
    
    // Clamp to min/max values
    return calculatedSize.clamp(minSize, maxSize);
  }

  Widget _buildWordBubble(WordNode node, BubbleWordProvider provider) {
    final isSelected = provider.selectedNodeId == node.id;
    
    // Calculate dynamic size based on the current displayed text
    final displayText = node.isFlipped ? node.definition : node.word;
    final dynamicSize = _calculateBubbleSize(displayText);
    
    // Check if this node is from an overlay map
    bool isOverlayNode = false;
    if (provider.currentMap != null) {
      try {
        provider.currentMap!.nodes.firstWhere((n) => n.id == node.id);
      } catch (e) {
        // Node not found in current map, so it's from an overlay
        isOverlayNode = true;
      }
    }
    
    return Transform.translate(
      offset: Offset(node.position.dx - dynamicSize / 2, node.position.dy - dynamicSize / 2),
      child: GestureDetector(
          onTap: () => _handleNodeTap(node, provider),
          onDoubleTap: () => _showEditWordDialog(context, node),
          onPanUpdate: (details) {
            final newPosition = node.position + details.delta;
            // Update node position across all maps (current + overlays)
            provider.updateNodePosition(node.id, newPosition);
          },
          onLongPress: () => _showDeleteWordDialog(context, node, provider),
        child: Container(
          width: dynamicSize,
          height: dynamicSize,
          decoration: BoxDecoration(
            color: node.color,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 3)
                : isOverlayNode
                    ? Border.all(color: Colors.orange, width: 2)
                    : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: node.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Overlay indicator
              if (isOverlayNode)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }



  void _handleNodeTap(WordNode node, BubbleWordProvider provider) {
    HapticService().bubbleWordFeedback();
    
    // Simple tap-to-connect: if a node is already selected, connect to this one
    if (provider.selectedNodeId != null && provider.selectedNodeId != node.id) {
      // Check if we can connect these nodes based on overlay restrictions
      if (_canConnectNodes(provider.selectedNodeId!, node.id, provider)) {
        // Connect the selected node to this one
        provider.addConnection(provider.selectedNodeId!, node.id);
        // Keep the new node selected
        provider.selectNode(node.id);
      } else {
        // Show error message or just select the new node
        provider.selectNode(node.id);
      }
    } else {
      // Just select this node
      provider.selectNode(node.id);
    }
  }
  

  
  bool _canConnectNodes(String fromNodeId, String toNodeId, BubbleWordProvider provider) {
    // If no overlays are active, allow all connections
    if (provider.overlayMapIds.isEmpty) {
      return true;
    }
    
    // Check if both nodes are from the current map (not overlays)
    bool fromNodeInCurrentMap = false;
    bool toNodeInCurrentMap = false;
    
    if (provider.currentMap != null) {
      fromNodeInCurrentMap = provider.currentMap!.nodes.any((node) => node.id == fromNodeId);
      toNodeInCurrentMap = provider.currentMap!.nodes.any((node) => node.id == toNodeId);
    }
    
    // Only allow connections if both nodes are from the current map
    return fromNodeInCurrentMap && toNodeInCurrentMap;
  }

  void _handleMenuAction(String action, BuildContext context, BubbleWordProvider provider) {
    switch (action) {
      case 'add':
        _showAddWordOptions(context);
        break;
      case 'new_map':
        _showNewMapDialog(context, provider);
        break;
      case 'save_map':
        _showSaveMapDialog(context, provider);
        break;
      case 'overlay':
        _showOverlayMapsDialog(context, provider);
        break;
      case 'undo':
        provider.undo();
        break;
      case 'redo':
        provider.redo();
        break;
      case 'reset':
        provider.resetView();
        break;
              case 'show_words':
          provider.showAllWords();
          break;
        case 'show_definitions':
          provider.showAllDefinitions();
          break;
      case 'clear':
        _showClearAllDialog(context, provider);
        break;
      case 'delete_map':
        _showDeleteMapDialog(context, provider);
        break;
    }
  }

  void _showAddWordOptions(BuildContext context) {
    final provider = context.read<BubbleWordProvider>();
    
    // Check if we can add more words
    final canAddWords = (provider.currentMap?.nodes.length ?? 0) < 50;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Word'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!canAddWords) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Maximum 50 words per map reached',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('New Word'),
              subtitle: const Text('Create a new word'),
              enabled: canAddWords,
              onTap: canAddWords ? () {
                Navigator.of(context).pop();
                _showAddWordDialog(context);
              } : null,
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Existing Word'),
              subtitle: const Text('Choose from your flashcards'),
              enabled: canAddWords,
              onTap: canAddWords ? () {
                Navigator.of(context).pop();
                _showExistingWordsDialog(context);
              } : null,
            ),
          ],
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

  void _showAddWordDialog(BuildContext context) {
    _wordController.clear();
    _definitionController.clear();
    _showingAddWord = true;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Word'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _wordController,
              decoration: const InputDecoration(
                labelText: 'Word',
                border: OutlineInputBorder(),
                helperText: 'Max 20 characters',
                counterText: '', // Hide default counter
              ),
              maxLength: 20,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _definitionController,
              decoration: const InputDecoration(
                labelText: 'Definition',
                border: OutlineInputBorder(),
                helperText: 'Max 50 characters',
                counterText: '', // Hide default counter
              ),
              maxLength: 50,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_wordController.text.isNotEmpty && _wordController.text.length <= 20) {
                final provider = context.read<BubbleWordProvider>();
                // Position the word at the center of the screen (simple approach)
                final screenSize = MediaQuery.of(context).size;
                final position = Offset(screenSize.width / 2, screenSize.height / 2);
                print('BubbleWordView: Adding word at screen center: $position');
                provider.addNode(
                  _wordController.text.trim(),
                  _definitionController.text.trim(),
                  position,
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add Word'),
          ),
        ],
      ),
    );
  }

  void _showExistingWordsDialog(BuildContext context) {
    final flashcardProvider = context.read<FlashcardProvider>();
    final cards = flashcardProvider.cards;
    // Sort cards alphabetically by word
    final sortedCards = List.from(cards)..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Existing Word'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: sortedCards.length,
            itemBuilder: (context, index) {
              final card = sortedCards[index];
              return ListTile(
                title: Text(card.word),
                subtitle: Text(card.definition),
                onTap: () {
                  final bubbleProvider = context.read<BubbleWordProvider>();
                                    // Position the word at the center of the screen (simple approach)
                  final screenSize = MediaQuery.of(context).size;
                  final position = Offset(screenSize.width / 2, screenSize.height / 2);
                  print('BubbleWordView: Adding existing word at screen center: $position');
                  bubbleProvider.addNode(
                    card.word,
                    card.definition,
                    position,
                  );
                  Navigator.of(context).pop();
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
        ],
      ),
    );
  }

  void _showEditWordDialog(BuildContext context, WordNode node) {
    _wordController.text = node.word;
    _definitionController.text = node.definition;
    _editingNode = node;
    _showingEditWord = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Color selectedBubbleColor = node.color;
          Color selectedTextColor = node.textColor;
          
          return AlertDialog(
            title: const Text('Edit Word'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _wordController,
                  decoration: const InputDecoration(
                    labelText: 'Word',
                    border: OutlineInputBorder(),
                    helperText: 'Max 20 characters',
                    counterText: '', // Hide default counter
                  ),
                  maxLength: 20,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _definitionController,
                  decoration: const InputDecoration(
                    labelText: 'Definition',
                    border: OutlineInputBorder(),
                    helperText: 'Max 50 characters',
                    counterText: '', // Hide default counter
                  ),
                  maxLength: 50,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                
                // Color pickers
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bubble Color', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final color = await showColorPickerDialog(
                                context,
                                selectedBubbleColor,
                                title: const Text('Select Bubble Color'),
                                width: 40,
                                height: 40,
                                spacing: 0,
                                runSpacing: 0,
                                borderRadius: 0,
                                wheelDiameter: 165,
                                enableOpacity: false,
                                showColorCode: true,
                                colorCodeHasColor: true,
                                pickersEnabled: <ColorPickerType, bool>{
                                  ColorPickerType.wheel: true,
                                  ColorPickerType.accent: false,
                                  ColorPickerType.primary: false,
                                  ColorPickerType.both: false,
                                },
                              );
                              if (color != null) {
                                setState(() {
                                  selectedBubbleColor = color;
                                });
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: selectedBubbleColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Text Color', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final color = await showColorPickerDialog(
                                context,
                                selectedTextColor,
                                title: const Text('Select Text Color'),
                                width: 40,
                                height: 40,
                                spacing: 0,
                                runSpacing: 0,
                                borderRadius: 0,
                                wheelDiameter: 165,
                                enableOpacity: false,
                                showColorCode: true,
                                colorCodeHasColor: true,
                                pickersEnabled: <ColorPickerType, bool>{
                                  ColorPickerType.wheel: true,
                                  ColorPickerType.accent: false,
                                  ColorPickerType.primary: false,
                                  ColorPickerType.both: false,
                                },
                              );
                              if (color != null) {
                                setState(() {
                                  selectedTextColor = color;
                                });
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: selectedTextColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Icon(Icons.text_fields, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_wordController.text.isNotEmpty && 
                      _wordController.text.length <= 20 && 
                      _definitionController.text.length <= 50) {
                    final provider = context.read<BubbleWordProvider>();
                    provider.updateNode(
                      node.id,
                      word: _wordController.text.trim(),
                      definition: _definitionController.text.trim(),
                      color: selectedBubbleColor,
                      textColor: selectedTextColor,
                    );
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }



  void _showClearAllDialog(BuildContext context, BubbleWordProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All'),
        content: const Text('Are you sure you want to clear all words and connections? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearAll();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMapDialog(BuildContext context, BubbleWordProvider provider) {
    if (provider.currentMap == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Map'),
        content: Text('Are you sure you want to delete "${provider.currentMap!.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final mapId = provider.selectedMapId;
              if (mapId != null) {
                provider.deleteMap(mapId);
                Navigator.of(context).pop();
                // Navigate back to map selection
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteWordDialog(BuildContext context, WordNode node, BubbleWordProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word'),
        content: Text('Are you sure you want to delete "${node.word}"? This will also remove all connections to this word.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteNode(node.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConnectionDialog(BuildContext context, WordConnection connection, BubbleWordProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Connection'),
        content: const Text('Are you sure you want to delete this connection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteConnection(connection.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showNewMapDialog(BuildContext context, BubbleWordProvider provider) {
    final nameController = TextEditingController(text: 'New Map ${provider.maps.length + 1}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Map'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Map Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                provider.createMap(nameController.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showSaveMapDialog(BuildContext context, BubbleWordProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Map'),
        content: const Text('Map has been saved automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showOverlayMapsDialog(BuildContext context, BubbleWordProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Overlay Maps'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Consumer<BubbleWordProvider>(
            builder: (context, provider, child) {
              return Column(
                children: [
                  Text(
                    'Select maps to overlay. Duplicate words will be merged automatically:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                        child: Column(
                          children: [
                        // Current map at the top
                        ...provider.maps.where((map) => provider.selectedMapId == map.id).map((map) {
                          return ListTile(
                            title: Text(map.name),
                            subtitle: Text('${map.nodes.length} words, ${map.connections.length} connections'),
                            leading: const Icon(Icons.radio_button_checked, color: Colors.blue),
                            trailing: const Text('Current', style: TextStyle(color: Colors.blue)),
                          );
                        }),
                        
                        // Divider
                        if (provider.maps.any((map) => provider.selectedMapId != map.id))
                          const Divider(),
                        
                        // Other maps below
                        ...provider.maps.where((map) => provider.selectedMapId != map.id).map((map) {
                          final isOverlayed = provider.overlayMapIds.contains(map.id);
                          return ListTile(
                            title: Text(map.name),
                            subtitle: Text('${map.nodes.length} words, ${map.connections.length} connections'),
                            leading: Switch(
                              value: isOverlayed,
                              onChanged: (value) {
                                provider.toggleOverlay(map.id);
                              },
                            ),
                            onTap: () {
                              provider.toggleOverlay(map.id);
                            },
                          );
                        }),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.clearOverlays();
              Navigator.of(context).pop();
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showCreateMapDialog(BuildContext context, BubbleWordProvider provider) {
    final nameController = TextEditingController(text: 'New Map ${provider.maps.length + 1}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Map'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Map Name',
                hintText: 'Enter a name for your new map',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                provider.createMap(name);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showSavePrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Changes?'),
        content: const Text('Do you want to save your changes before leaving?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Don\'t Save'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// Custom painters for connections
class ConnectionPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;

  ConnectionPainter({
    required this.from,
    required this.to,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a simple connection line
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw the main line
    canvas.drawLine(from, to, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

 