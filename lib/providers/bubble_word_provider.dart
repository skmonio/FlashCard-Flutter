import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../models/bubble_word_models.dart';

class BubbleWordProvider extends ChangeNotifier {
  static final BubbleWordProvider _instance = BubbleWordProvider._internal();
  factory BubbleWordProvider() => _instance;
  BubbleWordProvider._internal();

  List<BubbleWordMap> _maps = [];
  String? _selectedMapId;
  String? _selectedNodeId;
  double _scale = 1.0; // Start zoomed in but with space to zoom out
  Offset _offset = Offset.zero;
  Offset _lastOffset = Offset.zero;
  bool _isConnecting = false;
  String? _firstSelectedNodeId;
  
  // Overlay functionality
  Set<String> _overlayMapIds = {};
  
  // Undo/Redo functionality
  List<List<BubbleWordMap>> _undoStack = [];
  List<List<BubbleWordMap>> _redoStack = [];
  static const int maxUndoSteps = 10; // Reduced from 20 to 10 for memory optimization
  
  // Performance limits
  static const int maxNodesPerMap = 50; // Limit nodes per map
  static const int maxMaps = 10; // Limit total maps
  static const int maxOverlayMaps = 3; // Limit overlay maps

  // Color palette
  final List<Color> _bubbleColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.pink,
    Colors.yellow,
    Colors.teal,
    Colors.indigo,
  ];

  // Getters
  List<BubbleWordMap> get maps => _maps;
  String? get selectedMapId => _selectedMapId;
  String? get selectedNodeId => _selectedNodeId;
  double get scale => _scale;
  Offset get offset => _offset;
  bool get isConnecting => _isConnecting;
    String? get firstSelectedNodeId => _firstSelectedNodeId;
  
  BubbleWordMap? get currentMap {
    if (_selectedMapId == null || _maps.isEmpty) return null;
    try {
      return _maps.firstWhere((map) => map.id == _selectedMapId);
    } catch (e) {
      // If selected map doesn't exist, select the first available map
      if (_maps.isNotEmpty) {
        _selectedMapId = _maps.first.id;
        return _maps.first;
      }
      return null;
    }
  }

  List<WordNode> get nodes {
    if (currentMap == null) return [];
    
    final allNodes = <String, WordNode>{};
    
    // Add nodes from current map
    for (final node in currentMap!.nodes) {
      allNodes[node.word] = node;
    }
    
    // Add nodes from overlay maps (merge duplicates by word)
    for (final mapId in _overlayMapIds) {
      try {
        final overlayMap = _maps.firstWhere((map) => map.id == mapId);
        for (final node in overlayMap.nodes) {
          if (!allNodes.containsKey(node.word)) {
            allNodes[node.word] = node;
          }
        }
      } catch (e) {
        print('BubbleWordProvider: Overlay map $mapId not found');
      }
    }
    
    return allNodes.values.toList();
  }
  
  List<WordConnection> get connections {
    if (currentMap == null) return [];
    
    final allConnections = <String, WordConnection>{};
    
    // Add connections from current map
    for (final connection in currentMap!.connections) {
      allConnections[connection.id] = connection;
    }
    
    // Add connections from overlay maps
    for (final mapId in _overlayMapIds) {
      try {
        final overlayMap = _maps.firstWhere((map) => map.id == mapId);
        for (final connection in overlayMap.connections) {
          allConnections[connection.id] = connection;
        }
      } catch (e) {
        print('BubbleWordProvider: Overlay map $mapId not found for connections');
      }
    }
    
    return allConnections.values.toList();
  }
  
  Set<String> get overlayMapIds => _overlayMapIds;
  
  // Undo/Redo getters
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // Helper method to get a node by word (for merged view)
  WordNode? getNodeByWord(String word) {
    if (currentMap == null) return null;
    
    // First check current map
    try {
      return currentMap!.nodes.firstWhere((node) => node.word == word);
    } catch (e) {
      // Not found in current map
    }
    
    // Check overlay maps
    for (final mapId in _overlayMapIds) {
      try {
        final overlayMap = _maps.firstWhere((map) => map.id == mapId);
        return overlayMap.nodes.firstWhere((node) => node.word == word);
      } catch (e) {
        // Continue to next overlay map
      }
    }
    
    return null;
  }

  // Initialize
  Future<void> initialize() async {
    print('BubbleWordProvider: Initializing...');
    await loadData();
    print('BubbleWordProvider: After loadData, maps count: ${_maps.length}');
    
    if (_maps.isEmpty) {
      print('BubbleWordProvider: No maps found, creating default map');
      createDefaultMap();
    }
    
    if (_selectedMapId == null && _maps.isNotEmpty) {
      _selectedMapId = _maps.first.id;
      print('BubbleWordProvider: Set selected map to first map: $_selectedMapId');
    } else if (_selectedMapId != null) {
      // Verify the selected map still exists
      final mapExists = _maps.any((map) => map.id == _selectedMapId);
      if (!mapExists && _maps.isNotEmpty) {
        _selectedMapId = _maps.first.id;
        print('BubbleWordProvider: Selected map no longer exists, set to first map: $_selectedMapId');
      }
    }
    
    print('BubbleWordProvider: Initialization complete. Maps: ${_maps.length}, Selected: $_selectedMapId');
    notifyListeners();
  }

  // Map Management
  BubbleWordMap createMap(String name) {
    // Check map limit
    if (_maps.length >= maxMaps) {
      print('BubbleWordProvider: Cannot create more maps. Limit reached: $maxMaps');
      // Return existing map if limit reached
      if (_maps.isNotEmpty) {
        _selectedMapId = _maps.first.id;
        notifyListeners();
        return _maps.first;
      }
    }

    final newMap = BubbleWordMap(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    _maps.add(newMap);
    _selectedMapId = newMap.id;
    
    print('BubbleWordProvider: Created new map: ${newMap.name} with ID: ${newMap.id}');
    print('BubbleWordProvider: Set selected map to: $_selectedMapId');
    
    // Clear any overlays when creating a new map
    _overlayMapIds.clear();
    
    saveData();
    notifyListeners();
    return newMap;
  }

  void deleteMap(String mapId) {
    _maps.removeWhere((map) => map.id == mapId);
    if (_selectedMapId == mapId) {
      _selectedMapId = _maps.isNotEmpty ? _maps.first.id : null;
    }
    saveData();
    notifyListeners();
  }

  void selectMap(String mapId) {
    _selectedMapId = mapId;
    _scale = 1.0; // Start zoomed in but with space to zoom out
    _offset = Offset.zero;
    _lastOffset = Offset.zero;
    _selectedNodeId = null;
    _isConnecting = false;
    _firstSelectedNodeId = null;
    
    // Clear overlays when switching maps to prevent confusion
    _overlayMapIds.clear();
    
    saveData();
    notifyListeners();
  }

  void toggleOverlay(String mapId) {
    print('BubbleWordProvider: Toggling overlay for map: $mapId');
    print('BubbleWordProvider: Current overlays: $_overlayMapIds');
    
    if (_overlayMapIds.contains(mapId)) {
      _overlayMapIds.remove(mapId);
      print('BubbleWordProvider: Removed overlay for map: $mapId');
    } else {
      // Check overlay limit
      if (_overlayMapIds.length >= maxOverlayMaps) {
        print('BubbleWordProvider: Cannot add more overlays. Limit reached: $maxOverlayMaps');
        return;
      }
      
      _overlayMapIds.add(mapId);
      print('BubbleWordProvider: Added overlay for map: $mapId');
      // Auto-align overlapping words when adding overlay
      _alignOverlappingWords(mapId);
    }
    
    print('BubbleWordProvider: New overlays: $_overlayMapIds');
    saveData();
    notifyListeners();
  }

  void _alignOverlappingWords(String overlayMapId) {
    if (currentMap == null) return;
    
    try {
      final overlayMap = _maps.firstWhere((map) => map.id == overlayMapId);
      
      // For each word in the overlay map, check if it exists in current map
      for (final overlayNode in overlayMap.nodes) {
        final currentMapNode = currentMap!.nodes.where((node) => node.word == overlayNode.word).firstOrNull;
        if (currentMapNode != null) {
          // Update the overlay node position to match current map
          final updatedNodes = overlayMap.nodes.map((node) {
            if (node.word == overlayNode.word) {
              return node.copyWith(position: currentMapNode.position);
            }
            return node;
          }).toList();
          
          final updatedMap = overlayMap.copyWith(
            nodes: updatedNodes,
            updatedAt: DateTime.now(),
          );
          _updateMap(updatedMap);
        }
      }
    } catch (e) {
      print('Error aligning overlapping words: $e');
    }
  }

  void clearOverlays() {
    _overlayMapIds.clear();
    saveData();
    notifyListeners();
  }

  void createDefaultMap() {
    final defaultMap = BubbleWordMap(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: "My First Map",
    );
    _maps.add(defaultMap);
    _selectedMapId = defaultMap.id;
    saveData();
    notifyListeners();
  }

  // Node Management
  void addNode(String word, String definition, Offset position) {
    if (currentMap == null) return;

    // Check node limit
    if (currentMap!.nodes.length >= maxNodesPerMap) {
      print('BubbleWordProvider: Cannot add more nodes. Limit reached: $maxNodesPerMap');
      return;
    }

    // Validate input lengths
    if (word.length > 20 || definition.length > 50) {
      print('BubbleWordProvider: Word or definition too long. Word: ${word.length}, Definition: ${definition.length}');
      return;
    }

    _saveStateForUndo();

    final node = WordNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      word: word,
      definition: definition,
      color: _bubbleColors[Random().nextInt(_bubbleColors.length)],
      position: position,
    );

    final updatedMap = currentMap!.copyWith(
      nodes: [...currentMap!.nodes, node],
      updatedAt: DateTime.now(),
    );
    
    _updateMap(updatedMap);
    saveData();
    notifyListeners();
  }

  void updateNode(String nodeId, {String? word, String? definition, Offset? position, Color? color, Color? textColor}) {
    if (currentMap == null) return;

    // Save state for undo if we're changing word/definition/color/textColor (not just position)
    if (word != null || definition != null || color != null || textColor != null) {
      _saveStateForUndo();
    }

    // Find the node to get its word
    WordNode? targetNode;
    String? targetWord;
    
    // First try to find in current map
    final nodeIndex = currentMap!.nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex != -1) {
      targetNode = currentMap!.nodes[nodeIndex];
      targetWord = targetNode.word;
    } else {
      // Try to find in overlay maps
      for (final mapId in _overlayMapIds) {
        try {
          final overlayMap = _maps.firstWhere((map) => map.id == mapId);
          final overlayNodeIndex = overlayMap.nodes.indexWhere((node) => node.id == nodeId);
          if (overlayNodeIndex != -1) {
            targetNode = overlayMap.nodes[overlayNodeIndex];
            targetWord = targetNode.word;
            break;
          }
        } catch (e) {
          // Continue to next overlay map
        }
      }
    }

    if (targetNode == null || targetWord == null) return;

    // If we're updating position, update ALL instances of this word across all maps
    if (position != null) {
      // Update current map
      if (currentMap != null) {
        final updatedNodes = List<WordNode>.from(currentMap!.nodes);
        for (int i = 0; i < updatedNodes.length; i++) {
          if (updatedNodes[i].word == targetWord) {
            updatedNodes[i] = updatedNodes[i].copyWith(position: position);
          }
        }
        final updatedMap = currentMap!.copyWith(
          nodes: updatedNodes,
          updatedAt: DateTime.now(),
        );
        _updateMap(updatedMap);
      }

      // Update overlay maps
      for (final mapId in _overlayMapIds) {
        try {
          final overlayMap = _maps.firstWhere((map) => map.id == mapId);
          final updatedNodes = List<WordNode>.from(overlayMap.nodes);
          bool updated = false;
          for (int i = 0; i < updatedNodes.length; i++) {
            if (updatedNodes[i].word == targetWord) {
              updatedNodes[i] = updatedNodes[i].copyWith(position: position);
              updated = true;
            }
          }
          if (updated) {
            final updatedMap = overlayMap.copyWith(
              nodes: updatedNodes,
              updatedAt: DateTime.now(),
            );
            _updateMap(updatedMap);
          }
        } catch (e) {
          // Continue to next overlay map
        }
      }
    } else {
      // For non-position updates, just update the specific node
      if (nodeIndex != -1) {
        final updatedNodes = List<WordNode>.from(currentMap!.nodes);
        final oldNode = updatedNodes[nodeIndex];
        updatedNodes[nodeIndex] = oldNode.copyWith(
          word: word ?? oldNode.word,
          definition: definition ?? oldNode.definition,
          color: color ?? oldNode.color,
          textColor: textColor ?? oldNode.textColor,
        );
        final updatedMap = currentMap!.copyWith(
          nodes: updatedNodes,
          updatedAt: DateTime.now(),
        );
        _updateMap(updatedMap);
      } else {
        // Update in overlay maps
        for (final mapId in _overlayMapIds) {
          try {
            final overlayMap = _maps.firstWhere((map) => map.id == mapId);
            final overlayNodeIndex = overlayMap.nodes.indexWhere((node) => node.id == nodeId);
            if (overlayNodeIndex != -1) {
              final updatedNodes = List<WordNode>.from(overlayMap.nodes);
              final oldNode = updatedNodes[overlayNodeIndex];
              updatedNodes[overlayNodeIndex] = oldNode.copyWith(
                word: word ?? oldNode.word,
                definition: definition ?? oldNode.definition,
                color: color ?? oldNode.color,
                textColor: textColor ?? oldNode.textColor,
              );
              final updatedMap = overlayMap.copyWith(
                nodes: updatedNodes,
                updatedAt: DateTime.now(),
              );
              _updateMap(updatedMap);
              break;
            }
          } catch (e) {
            // Continue to next overlay map
          }
        }
      }
    }

    saveData();
    notifyListeners();
  }

  // Special method for updating node position across all maps
  void updateNodePosition(String nodeId, Offset position) {
    if (currentMap == null) return;

    // Find the node to get its word
    WordNode? targetNode;
    String? targetWord;
    
    // First try to find in current map
    final nodeIndex = currentMap!.nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex != -1) {
      targetNode = currentMap!.nodes[nodeIndex];
      targetWord = targetNode.word;
    } else {
      // Try to find in overlay maps
      for (final mapId in _overlayMapIds) {
        try {
          final overlayMap = _maps.firstWhere((map) => map.id == mapId);
          final overlayNodeIndex = overlayMap.nodes.indexWhere((node) => node.id == nodeId);
          if (overlayNodeIndex != -1) {
            targetNode = overlayMap.nodes[overlayNodeIndex];
            targetWord = targetNode.word;
            break;
          }
        } catch (e) {
          // Continue to next overlay map
        }
      }
    }

    if (targetNode == null || targetWord == null) return;

    // Update ALL instances of this word across all maps
    // Update current map
    if (currentMap != null) {
      final updatedNodes = List<WordNode>.from(currentMap!.nodes);
      for (int i = 0; i < updatedNodes.length; i++) {
        if (updatedNodes[i].word == targetWord) {
          updatedNodes[i] = updatedNodes[i].copyWith(position: position);
        }
      }
      final updatedMap = currentMap!.copyWith(
        nodes: updatedNodes,
        updatedAt: DateTime.now(),
      );
      _updateMap(updatedMap);
    }

    // Update overlay maps
    for (final mapId in _overlayMapIds) {
      try {
        final overlayMap = _maps.firstWhere((map) => map.id == mapId);
        final updatedNodes = List<WordNode>.from(overlayMap.nodes);
        bool updated = false;
        for (int i = 0; i < updatedNodes.length; i++) {
          if (updatedNodes[i].word == targetWord) {
            updatedNodes[i] = updatedNodes[i].copyWith(position: position);
            updated = true;
          }
        }
        if (updated) {
          final updatedMap = overlayMap.copyWith(
            nodes: updatedNodes,
            updatedAt: DateTime.now(),
          );
          _updateMap(updatedMap);
        }
      } catch (e) {
        // Continue to next overlay map
      }
    }

    saveData();
    notifyListeners();
  }

  void deleteNode(String nodeId) {
    if (currentMap == null) return;

    _saveStateForUndo();

    // Find the node to get its word
    WordNode? targetNode;
    String? targetWord;
    
    // First try to find in current map
    final nodeIndex = currentMap!.nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex != -1) {
      targetNode = currentMap!.nodes[nodeIndex];
      targetWord = targetNode.word;
    } else {
      // Try to find in overlay maps
      for (final mapId in _overlayMapIds) {
        try {
          final overlayMap = _maps.firstWhere((map) => map.id == mapId);
          final overlayNodeIndex = overlayMap.nodes.indexWhere((node) => node.id == nodeId);
          if (overlayNodeIndex != -1) {
            targetNode = overlayMap.nodes[overlayNodeIndex];
            targetWord = targetNode.word;
            break;
          }
        } catch (e) {
          // Continue to next overlay map
        }
      }
    }

    if (targetNode == null || targetWord == null) return;

    // Delete ALL instances of this word across all maps
    // Delete from current map
    if (currentMap != null) {
      final updatedNodes = currentMap!.nodes.where((node) => node.word != targetWord).toList();
      final updatedConnections = currentMap!.connections
          .where((conn) {
            // Check if connection involves any node with this word
            final fromNode = currentMap!.nodes.firstWhere((node) => node.id == conn.fromNodeId);
            final toNode = currentMap!.nodes.firstWhere((node) => node.id == conn.toNodeId);
            return fromNode.word != targetWord && toNode.word != targetWord;
          })
          .toList();

      final updatedMap = currentMap!.copyWith(
        nodes: updatedNodes,
        connections: updatedConnections,
        updatedAt: DateTime.now(),
      );
      _updateMap(updatedMap);
    }

    // Delete from overlay maps
    for (final mapId in _overlayMapIds) {
      try {
        final overlayMap = _maps.firstWhere((map) => map.id == mapId);
        final updatedNodes = overlayMap.nodes.where((node) => node.word != targetWord).toList();
        final updatedConnections = overlayMap.connections
            .where((conn) {
              // Check if connection involves any node with this word
              final fromNode = overlayMap.nodes.firstWhere((node) => node.id == conn.fromNodeId);
              final toNode = overlayMap.nodes.firstWhere((node) => node.id == conn.toNodeId);
              return fromNode.word != targetWord && toNode.word != targetWord;
            })
            .toList();

        final updatedMap = overlayMap.copyWith(
          nodes: updatedNodes,
          connections: updatedConnections,
          updatedAt: DateTime.now(),
        );
        _updateMap(updatedMap);
      } catch (e) {
        // Continue to next overlay map
      }
    }

    _selectedNodeId = null;
    _isConnecting = false;
    _firstSelectedNodeId = null;
    saveData();
    notifyListeners();
  }

  // Connection Management
  void addConnection(String fromNodeId, String toNodeId) {
    if (currentMap == null) return;
    if (fromNodeId == toNodeId) return;

    _saveStateForUndo();

    // Check if connection already exists
    final existingConnection = currentMap!.connections.any(
      (conn) => (conn.fromNodeId == fromNodeId && conn.toNodeId == toNodeId) ||
                 (conn.fromNodeId == toNodeId && conn.toNodeId == fromNodeId),
    );

    if (existingConnection) return;

    final connection = WordConnection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
      color: Colors.red, // Use bright red for visibility
    );

    final updatedMap = currentMap!.copyWith(
      connections: [...currentMap!.connections, connection],
      updatedAt: DateTime.now(),
    );

    _updateMap(updatedMap);
    saveData();
    notifyListeners();
  }

  void deleteConnection(String connectionId) {
    if (currentMap == null) return;

    _saveStateForUndo();

    final updatedConnections = currentMap!.connections
        .where((conn) => conn.id != connectionId)
        .toList();

    final updatedMap = currentMap!.copyWith(
      connections: updatedConnections,
      updatedAt: DateTime.now(),
    );

    _updateMap(updatedMap);
    saveData();
    notifyListeners();
  }

  void deleteConnectionsForNode(String nodeId) {
    if (currentMap == null) return;

    final updatedConnections = currentMap!.connections
        .where((conn) => conn.fromNodeId != nodeId && conn.toNodeId != nodeId)
        .toList();

    final updatedMap = currentMap!.copyWith(
      connections: updatedConnections,
      updatedAt: DateTime.now(),
    );

    _updateMap(updatedMap);
    saveData();
    notifyListeners();
  }

  // Selection Management
  void selectNode(String? nodeId) {
    _selectedNodeId = nodeId;
    if (nodeId == null) {
      _isConnecting = false;
      _firstSelectedNodeId = null;
    }
    notifyListeners();
  }

  void startConnection(String nodeId) {
    _isConnecting = true;
    _firstSelectedNodeId = nodeId;
    notifyListeners();
  }

  void completeConnection(String nodeId) {
    if (_firstSelectedNodeId != null && _firstSelectedNodeId != nodeId) {
      addConnection(_firstSelectedNodeId!, nodeId);
    }
    _isConnecting = false;
    _firstSelectedNodeId = null;
    notifyListeners();
  }

  void startConnectionMode() {
    _isConnecting = true;
    _firstSelectedNodeId = null;
    _selectedNodeId = null;
    notifyListeners();
  }

  void selectFirstNodeForConnection(String nodeId) {
    _firstSelectedNodeId = nodeId;
    _selectedNodeId = nodeId;
    notifyListeners();
  }

  void cancelConnection() {
    _isConnecting = false;
    _firstSelectedNodeId = null;
    notifyListeners();
  }

  // View Management
  void setScale(double scale) {
    _scale = scale.clamp(0.5, 3.0);
    notifyListeners();
  }

  void setOffset(Offset offset) {
    _offset = offset;
    notifyListeners();
  }

  void resetView() {
    _scale = 1.0;
    _offset = Offset.zero;
    _lastOffset = Offset.zero;
    notifyListeners();
  }



  // Helper Methods
  void _updateMap(BubbleWordMap updatedMap) {
    final mapIndex = _maps.indexWhere((map) => map.id == updatedMap.id);
    if (mapIndex != -1) {
      _maps[mapIndex] = updatedMap;
    }
  }

  // Find a node across all maps (current + overlays)
  WordNode? findNodeAcrossAllMaps(String nodeId) {
    // First try to find in current map
    if (currentMap != null) {
      try {
        return currentMap!.nodes.firstWhere((node) => node.id == nodeId);
      } catch (e) {
        // Node not found in current map
      }
    }
    
    // Try to find in overlay maps
    for (final mapId in _overlayMapIds) {
      try {
        final overlayMap = _maps.firstWhere((map) => map.id == mapId);
        return overlayMap.nodes.firstWhere((node) => node.id == nodeId);
      } catch (e) {
        // Continue to next overlay map
      }
    }
    
    return null;
  }

  // Persistence
  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final mapsJson = _maps.map((map) => map.toJson()).toList();
    await prefs.setString('BubbleWordMaps', jsonEncode(mapsJson));
    await prefs.setString('BubbleWordSelectedMap', _selectedMapId ?? '');
    await prefs.setStringList('BubbleWordOverlayMaps', _overlayMapIds.toList());
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final mapsString = prefs.getString('BubbleWordMaps');
    print('BubbleWordProvider: Loading data, mapsString: ${mapsString?.substring(0, mapsString.length > 100 ? 100 : mapsString.length)}...');
    
    if (mapsString != null) {
      try {
        final mapsJson = jsonDecode(mapsString) as List<dynamic>;
        _maps = mapsJson.map((json) => BubbleWordMap.fromJson(json)).toList();
        print('BubbleWordProvider: Successfully loaded ${_maps.length} maps');
      } catch (e) {
        print('Error loading bubble word maps: $e');
        _maps = [];
      }
    } else {
      print('BubbleWordProvider: No saved maps found');
    }

    _selectedMapId = prefs.getString('BubbleWordSelectedMap');
    print('BubbleWordProvider: Selected map ID: $_selectedMapId');
    
    final overlayMaps = prefs.getStringList('BubbleWordOverlayMaps');
    if (overlayMaps != null) {
      _overlayMapIds = overlayMaps.toSet();
    }
  }

  // Flip node between word and definition
  void flipNode(String nodeId) {
    if (currentMap == null) return;
    
    _saveStateForUndo();
    
    // Find the node to get its word
    WordNode? targetNode;
    String? targetWord;
    
    // First try to find in current map
    final nodeIndex = currentMap!.nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex != -1) {
      targetNode = currentMap!.nodes[nodeIndex];
      targetWord = targetNode.word;
    } else {
      // Try to find in overlay maps
      for (final mapId in _overlayMapIds) {
        try {
          final overlayMap = _maps.firstWhere((map) => map.id == mapId);
          final overlayNodeIndex = overlayMap.nodes.indexWhere((node) => node.id == nodeId);
          if (overlayNodeIndex != -1) {
            targetNode = overlayMap.nodes[overlayNodeIndex];
            targetWord = targetNode.word;
            break;
          }
        } catch (e) {
          // Continue to next overlay map
        }
      }
    }

    if (targetNode == null || targetWord == null) return;

    // Flip ALL instances of this word across all maps
    // Flip in current map
    if (currentMap != null) {
      final updatedNodes = List<WordNode>.from(currentMap!.nodes);
      for (int i = 0; i < updatedNodes.length; i++) {
        if (updatedNodes[i].word == targetWord) {
          updatedNodes[i] = updatedNodes[i].copyWith(
            isFlipped: !updatedNodes[i].isFlipped,
          );
        }
      }
      final updatedMap = currentMap!.copyWith(
        nodes: updatedNodes,
        updatedAt: DateTime.now(),
      );
      _updateMap(updatedMap);
    }

    // Flip in overlay maps
    for (final mapId in _overlayMapIds) {
      try {
        final overlayMap = _maps.firstWhere((map) => map.id == mapId);
        final updatedNodes = List<WordNode>.from(overlayMap.nodes);
        bool updated = false;
        for (int i = 0; i < updatedNodes.length; i++) {
          if (updatedNodes[i].word == targetWord) {
            updatedNodes[i] = updatedNodes[i].copyWith(
              isFlipped: !updatedNodes[i].isFlipped,
            );
            updated = true;
          }
        }
        if (updated) {
          final updatedMap = overlayMap.copyWith(
            nodes: updatedNodes,
            updatedAt: DateTime.now(),
          );
          _updateMap(updatedMap);
        }
      } catch (e) {
        // Continue to next overlay map
      }
    }

    saveData();
    notifyListeners();
  }
  
  // Undo/Redo functionality
  void _saveStateForUndo() {
    // Save current state to undo stack
    final currentState = _maps.map((map) => map.copyWith()).toList();
    _undoStack.add(currentState);
    
    // Limit undo stack size
    if (_undoStack.length > maxUndoSteps) {
      _undoStack.removeAt(0);
    }
    
    // Clear redo stack when a new action is performed
    _redoStack.clear();
  }
  
  void undo() {
    if (!canUndo) return;
    
    // Save current state to redo stack
    final currentState = _maps.map((map) => map.copyWith()).toList();
    _redoStack.add(currentState);
    
    // Restore previous state
    final previousState = _undoStack.removeLast();
    _maps = previousState;
    
    // Verify selected map still exists
    if (_selectedMapId != null && !_maps.any((map) => map.id == _selectedMapId)) {
      _selectedMapId = _maps.isNotEmpty ? _maps.first.id : null;
    }
    
    saveData();
    notifyListeners();
  }
  
  void redo() {
    if (!canRedo) return;
    
    // Save current state to undo stack
    final currentState = _maps.map((map) => map.copyWith()).toList();
    _undoStack.add(currentState);
    
    // Restore next state
    final nextState = _redoStack.removeLast();
    _maps = nextState;
    
    // Verify selected map still exists
    if (_selectedMapId != null && !_maps.any((map) => map.id == _selectedMapId)) {
      _selectedMapId = _maps.isNotEmpty ? _maps.first.id : null;
    }
    
    saveData();
    notifyListeners();
  }

  // Flip all nodes across all maps
  void flipAllNodes() {
    if (_maps.isEmpty) return;
    
    _saveStateForUndo();
    
    // Flip all nodes across all maps
    final updatedMaps = _maps.map((map) {
      final updatedNodes = map.nodes.map((node) => 
        node.copyWith(isFlipped: !node.isFlipped)
      ).toList();
      
      return map.copyWith(
        nodes: updatedNodes,
        updatedAt: DateTime.now(),
      );
    }).toList();
    
    _maps = updatedMaps;
    saveData();
    notifyListeners();
  }

  // Show all words (unflip all nodes)
  void showAllWords() {
    if (_maps.isEmpty) return;
    
    _saveStateForUndo();
    
    // Set all nodes to show words (not flipped)
    final updatedMaps = _maps.map((map) {
      final updatedNodes = map.nodes.map((node) => 
        node.copyWith(isFlipped: false)
      ).toList();
      
      return map.copyWith(
        nodes: updatedNodes,
        updatedAt: DateTime.now(),
      );
    }).toList();
    
    _maps = updatedMaps;
    saveData();
    notifyListeners();
  }

  // Show all definitions (flip all nodes)
  void showAllDefinitions() {
    if (_maps.isEmpty) return;
    
    _saveStateForUndo();
    
    // Set all nodes to show definitions (flipped)
    final updatedMaps = _maps.map((map) {
      final updatedNodes = map.nodes.map((node) => 
        node.copyWith(isFlipped: true)
      ).toList();
      
      return map.copyWith(
        nodes: updatedNodes,
        updatedAt: DateTime.now(),
      );
    }).toList();
    
    _maps = updatedMaps;
    saveData();
    notifyListeners();
  }

  // Clear all data
  void clearAll() {
    _saveStateForUndo();
    
    final updatedMap = currentMap?.copyWith(
      nodes: [],
      connections: [],
      updatedAt: DateTime.now(),
    );
    
    if (updatedMap != null) {
      _updateMap(updatedMap);
    }
    
    _selectedNodeId = null;
    _isConnecting = false;
    _firstSelectedNodeId = null;
    saveData();
    notifyListeners();
  }
} 