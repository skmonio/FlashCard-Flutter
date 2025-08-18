import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bubble_word_provider.dart';
import '../models/bubble_word_models.dart';
import '../components/unified_header.dart';
import 'bubble_word_view.dart';

class BubbleWordMapSelectionView extends StatefulWidget {
  const BubbleWordMapSelectionView({super.key});

  @override
  State<BubbleWordMapSelectionView> createState() => _BubbleWordMapSelectionViewState();
}

class _BubbleWordMapSelectionViewState extends State<BubbleWordMapSelectionView> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<BubbleWordProvider>();
      await provider.initialize();
      print('BubbleWordMapSelectionView: Maps loaded: ${provider.maps.length}');
      for (final map in provider.maps) {
        print('Map: ${map.name} (${map.id}) - ${map.nodes.length} nodes, ${map.connections.length} connections');
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                title: 'Bubble Word Maps',
                onBack: () => Navigator.of(context).pop(),
              ),
              
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [

                      
                      // Welcome message
                      if (provider.maps.isEmpty) ...[
                        const SizedBox(height: 40),
                        Icon(
                          Icons.map,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to Bubble Word!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first word map to start organizing your vocabulary visually.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                      ],
                      
                      // Create new map button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showCreateMapDialog(context, provider),
                          icon: const Icon(Icons.add),
                          label: Text(provider.maps.isEmpty ? 'Create Your First Map' : 'Create New Map'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Existing maps
                      if (provider.maps.isNotEmpty) ...[
                        Text(
                          'Your Maps',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: provider.maps.length,
                            itemBuilder: (context, index) {
                              final map = provider.maps[index];
                              final isSelected = provider.selectedMapId == map.id;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.map,
                                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                                  ),
                                  title: Text(
                                    map.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${map.nodes.length} words, ${map.connections.length} connections',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.arrow_forward_ios, size: 16),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _showDeleteMapDialog(context, map, provider),
                                        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                                        tooltip: 'Delete Map',
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    provider.selectMap(map.id);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const BubbleWordView(),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateMapDialog(BuildContext context, BubbleWordProvider provider) {
    _nameController.text = 'New Map ${provider.maps.length + 1}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Map'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Map Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty) {
                final newMap = provider.createMap(_nameController.text.trim());
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BubbleWordView(),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMapDialog(BuildContext context, BubbleWordMap map, BubbleWordProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Map'),
        content: Text('Are you sure you want to delete "${map.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteMap(map.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
} 