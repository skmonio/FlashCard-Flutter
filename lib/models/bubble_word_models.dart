import 'package:flutter/material.dart';

// Word Node Model
class WordNode {
  final String id;
  final String word;
  final String definition;
  final Color color;
  final Color textColor;
  final Offset position;
  final double size;
  bool isSelected;
  bool isDragging;
  bool isFlipped;

  WordNode({
    required this.id,
    required this.word,
    required this.definition,
    required this.color,
    this.textColor = Colors.white,
    required this.position,
    this.size = 80,
    this.isSelected = false,
    this.isDragging = false,
    this.isFlipped = false,
  });

  WordNode copyWith({
    String? id,
    String? word,
    String? definition,
    Color? color,
    Color? textColor,
    Offset? position,
    double? size,
    bool? isSelected,
    bool? isDragging,
    bool? isFlipped,
  }) {
    return WordNode(
      id: id ?? this.id,
      word: word ?? this.word,
      definition: definition ?? this.definition,
      color: color ?? this.color,
      textColor: textColor ?? this.textColor,
      position: position ?? this.position,
      size: size ?? this.size,
      isSelected: isSelected ?? this.isSelected,
      isDragging: isDragging ?? this.isDragging,
      isFlipped: isFlipped ?? this.isFlipped,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'definition': definition,
      'color': color.value,
      'textColor': textColor.value,
      'position': {'dx': position.dx, 'dy': position.dy},
      'size': size,
      'isFlipped': isFlipped,
    };
  }

  factory WordNode.fromJson(Map<String, dynamic> json) {
    return WordNode(
      id: json['id'],
      word: json['word'],
      definition: json['definition'],
      color: Color(json['color']),
      textColor: json['textColor'] != null ? Color(json['textColor']) : Colors.white,
      position: Offset(json['position']['dx'], json['position']['dy']),
      size: json['size'] ?? 80,
      isFlipped: json['isFlipped'] ?? false,
    );
  }
}

// Word Connection Model
class WordConnection {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final Color color;

  WordConnection({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromNodeId': fromNodeId,
      'toNodeId': toNodeId,
      'color': color.value,
    };
  }

  factory WordConnection.fromJson(Map<String, dynamic> json) {
    return WordConnection(
      id: json['id'],
      fromNodeId: json['fromNodeId'],
      toNodeId: json['toNodeId'],
      color: Color(json['color']),
    );
  }
}

// Bubble Word Map Model
class BubbleWordMap {
  final String id;
  final String name;
  final List<WordNode> nodes;
  final List<WordConnection> connections;
  final DateTime createdAt;
  final DateTime updatedAt;

  BubbleWordMap({
    required this.id,
    required this.name,
    List<WordNode>? nodes,
    List<WordConnection>? connections,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    nodes = nodes ?? [],
    connections = connections ?? [],
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  BubbleWordMap copyWith({
    String? id,
    String? name,
    List<WordNode>? nodes,
    List<WordConnection>? connections,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BubbleWordMap(
      id: id ?? this.id,
      name: name ?? this.name,
      nodes: nodes ?? this.nodes,
      connections: connections ?? this.connections,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nodes': nodes.map((node) => node.toJson()).toList(),
      'connections': connections.map((conn) => conn.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BubbleWordMap.fromJson(Map<String, dynamic> json) {
    return BubbleWordMap(
      id: json['id'],
      name: json['name'],
      nodes: (json['nodes'] as List<dynamic>)
          .map((nodeJson) => WordNode.fromJson(nodeJson))
          .toList(),
      connections: (json['connections'] as List<dynamic>)
          .map((connJson) => WordConnection.fromJson(connJson))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
} 