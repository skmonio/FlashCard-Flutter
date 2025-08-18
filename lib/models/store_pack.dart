class StorePack {
  final String id;
  final String name;
  final String description;
  final int cardCount;
  final String filename;
  final bool unlocked;
  final String category;
  final String difficulty;

  StorePack({
    required this.id,
    required this.name,
    required this.description,
    required this.cardCount,
    required this.filename,
    required this.unlocked,
    required this.category,
    required this.difficulty,
  });

  factory StorePack.fromJson(Map<String, dynamic> json) {
    return StorePack(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      cardCount: json['card_count'] ?? 0,
      filename: json['filename'] ?? '',
      unlocked: json['unlocked'] ?? false,
      category: json['category'] ?? 'vocabulary',
      difficulty: json['difficulty'] ?? 'intermediate',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'card_count': cardCount,
      'filename': filename,
      'unlocked': unlocked,
      'category': category,
      'difficulty': difficulty,
    };
  }

  StorePack copyWith({
    String? id,
    String? name,
    String? description,
    int? cardCount,
    String? filename,
    bool? unlocked,
    String? category,
    String? difficulty,
  }) {
    return StorePack(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      cardCount: cardCount ?? this.cardCount,
      filename: filename ?? this.filename,
      unlocked: unlocked ?? this.unlocked,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}
