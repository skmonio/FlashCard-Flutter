import 'package:uuid/uuid.dart';
import 'flash_card.dart';

class Deck {
  final String id;
  String name;
  List<FlashCard> cards;
  String? parentId; // Parent deck ID for sub-decks
  Set<String> subDeckIds; // Child deck IDs
  DateTime dateCreated;
  DateTime lastModified;
  
  // CloudKit tracking
  String? cloudKitRecordName;
  
  Deck({
    String? id,
    required this.name,
    List<FlashCard>? cards,
    this.parentId,
    Set<String>? subDeckIds,
    DateTime? dateCreated,
    DateTime? lastModified,
    this.cloudKitRecordName,
  }) : 
    id = id ?? const Uuid().v4(),
    cards = cards ?? [],
    subDeckIds = subDeckIds ?? {},
    dateCreated = dateCreated ?? DateTime.now(),
    lastModified = lastModified ?? DateTime.now();
  
  // Helper computed properties
  bool get isSubDeck {
    return parentId != null;
  }
  
  String get displayName {
    return name;
  }
  
  int get cardCount {
    return cards.length;
  }
  
  // Get cards that are due for review
  List<FlashCard> get dueCards {
    return cards.where((card) => card.isDueForReview).toList();
  }
  
  // Get new cards (never reviewed)
  List<FlashCard> get newCards {
    return cards.where((card) => card.isNew).toList();
  }
  
  // Get learning cards (levels 1-3)
  List<FlashCard> get learningCards {
    return cards.where((card) => card.isLearning).toList();
  }
  
  // Get review cards (levels 4+)
  List<FlashCard> get reviewCards {
    return cards.where((card) => card.isReviewing).toList();
  }
  
  // Get fully learned cards
  List<FlashCard> get learnedCards {
    return cards.where((card) => card.isFullyLearned).toList();
  }
  
  // Calculate overall learning percentage
  double get learningPercentage {
    print('🔍 Deck calculation: Deck "$name" has ${cards.length} cards');
    if (cards.isEmpty) {
      print('🔍 Deck calculation: No cards, returning 0%');
      return 0.0;
    }
    
    // Use the new learning percentage system for each card
    double totalPercentage = 0.0;
    
    for (final card in cards) {
      print('🔍 Deck calculation: Card "${card.word}" has ${card.learningPercentage}%');
      totalPercentage += card.learningPercentage.toDouble();
    }
    
    final result = totalPercentage / cards.length;
    print('🔍 Deck calculation: Total: $totalPercentage, Count: ${cards.length}, Average: $result%');
    return result;
  }
  
  // Calculate learning percentage with provided cards
  static double calculateLearningPercentage(String deckName, List<FlashCard> cards) {
    print('🔍 Static Deck calculation: Deck "$deckName" has ${cards.length} cards');
    if (cards.isEmpty) {
      print('🔍 Static Deck calculation: No cards, returning 0%');
      return 0.0;
    }
    
    // Use the new learning percentage system for each card
    double totalPercentage = 0.0;
    
    for (final card in cards) {
      print('🔍 Static Deck calculation: Card "${card.word}" has ${card.learningPercentage}%');
      totalPercentage += card.learningPercentage.toDouble();
    }
    
    final result = totalPercentage / cards.length;
    print('🔍 Static Deck calculation: Total: $totalPercentage, Count: ${cards.length}, Average: $result%');
    return result;
  }
  
  // MARK: - Card Management
  
  void addCard(FlashCard card) {
    cards.add(card);
    card.deckIds.add(id);
    lastModified = DateTime.now();
  }
  
  void removeCard(FlashCard card) {
    cards.remove(card);
    card.deckIds.remove(id);
    lastModified = DateTime.now();
  }
  
  void addCards(List<FlashCard> newCards) {
    for (final card in newCards) {
      addCard(card);
    }
  }
  
  // MARK: - Sub-deck Management
  
  void addSubDeck(String subDeckId) {
    subDeckIds.add(subDeckId);
    lastModified = DateTime.now();
  }
  
  void removeSubDeck(String subDeckId) {
    subDeckIds.remove(subDeckId);
    lastModified = DateTime.now();
  }
  
  // MARK: - JSON Serialization
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'subDeckIds': subDeckIds.toList(),
      'dateCreated': dateCreated.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'cloudKitRecordName': cloudKitRecordName,
    };
  }
  
  factory Deck.fromJson(Map<String, dynamic> json) {
    return Deck(
      id: json['id'],
      name: json['name'] ?? '',
      parentId: json['parentId'],
      subDeckIds: Set<String>.from(json['subDeckIds'] ?? []),
      dateCreated: json['dateCreated'] != null 
          ? DateTime.parse(json['dateCreated']) 
          : DateTime.now(),
      lastModified: json['lastModified'] != null 
          ? DateTime.parse(json['lastModified']) 
          : DateTime.now(),
      cloudKitRecordName: json['cloudKitRecordName'],
    );
  }
  
  // MARK: - Copy Methods
  
  Deck copyWith({
    String? name,
    List<FlashCard>? cards,
    String? parentId,
    Set<String>? subDeckIds,
    DateTime? dateCreated,
    DateTime? lastModified,
    String? cloudKitRecordName,
  }) {
    return Deck(
      id: id,
      name: name ?? this.name,
      cards: cards ?? this.cards,
      parentId: parentId ?? this.parentId,
      subDeckIds: subDeckIds ?? this.subDeckIds,
      dateCreated: dateCreated ?? this.dateCreated,
      lastModified: lastModified ?? this.lastModified,
      cloudKitRecordName: cloudKitRecordName ?? this.cloudKitRecordName,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Deck && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'Deck(id: $id, name: $name, cardCount: ${cards.length})';
  }
} 