import 'category.dart';
import '../utils/constants.dart';

class Product {
  final int id;
  final String name;
  final String sku;
  final String? description;
  final double price;
  final double costPrice;
  final int quantity;
  final int minStockAlert;
  final int? categoryId;
  final String? imageUrl;
  final bool isLowStock;
  final Category? category;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    this.description,
    required this.price,
    this.costPrice = 0.0,
    required this.quantity,
    this.minStockAlert = 5,
    this.categoryId,
    this.imageUrl,
    required this.isLowStock,
    this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      sku: json['sku'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int,
      minStockAlert: json['min_stock_alert'] as int? ?? 5,
      categoryId: json['category_id'] as int?,
      imageUrl: json['image_url'] as String?,
      isLowStock: json['is_low_stock'] as bool? ?? false,
      category: json['category'] != null ? Category.fromJson(json['category']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sku': sku,
      'description': description,
      'price': price,
      'cost_price': costPrice,
      'quantity': quantity,
      'min_stock_alert': minStockAlert,
      'category_id': categoryId,
      'image_url': imageUrl,
    };
  }

  /// Résout l'URL de l'image pour l'affichage (supporte https://... et /static/uploads/...)
  static String? resolveUrl(String? rawUrl, [String? apiBaseUrl]) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final raw = rawUrl.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final base = (apiBaseUrl != null && apiBaseUrl.isNotEmpty)
        ? apiBaseUrl
        : AppConstants.defaultBaseUrl;
    final host = base.replaceAll(RegExp(r'/api/?$'), '');
    if (raw.startsWith('/')) {
      return '$host$raw';
    }
    return '$host/$raw';
  }
}
