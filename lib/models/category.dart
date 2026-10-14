class Category {
  final int id;
  final String name;
  final String? description;
  final String color;
  final int productsCount;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.color = "#4F46E5",
    this.productsCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: json['color'] as String? ?? "#4F46E5",
      productsCount: json['products_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'color': color,
    };
  }
}
