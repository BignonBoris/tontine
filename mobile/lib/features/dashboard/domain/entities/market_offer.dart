class MarketOffer {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String category;
  final double? price;
  final String? brand;

  const MarketOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    this.price,
    this.brand,
  });

  factory MarketOffer.fromMap(Map<dynamic, dynamic> map) {
    return MarketOffer(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      category: map['category'] as String? ?? '',
      price: _parseDouble(map['price']),
      brand: map['brand'] as String?,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  /// Copie de l'objet avec des modifications optionnelles
  MarketOffer copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? category,
    double? price,
    String? brand,
  }) {
    return MarketOffer(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      price: price ?? this.price,
      brand: brand ?? this.brand,
    );
  }
}
