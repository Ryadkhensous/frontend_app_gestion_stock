import 'product.dart';
import 'stock_movement.dart';

class DashboardStats {
  final int totalProducts;
  final int totalStockUnits;
  final double totalInventoryValue;
  final int totalPointsOfSale;
  final int activePointsOfSale;
  final int lowStockAlertsCount;
  final List<Product> lowStockProducts;
  final List<StockMovement> recentMovements;

  DashboardStats({
    required this.totalProducts,
    required this.totalStockUnits,
    required this.totalInventoryValue,
    required this.totalPointsOfSale,
    required this.activePointsOfSale,
    required this.lowStockAlertsCount,
    required this.lowStockProducts,
    required this.recentMovements,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalProducts: json['total_products'] as int? ?? 0,
      totalStockUnits: json['total_stock_units'] as int? ?? 0,
      totalInventoryValue: (json['total_inventory_value'] as num?)?.toDouble() ?? 0.0,
      totalPointsOfSale: json['total_points_of_sale'] as int? ?? 0,
      activePointsOfSale: json['active_points_of_sale'] as int? ?? 0,
      lowStockAlertsCount: json['low_stock_alerts_count'] as int? ?? 0,
      lowStockProducts: (json['low_stock_products'] as List<dynamic>? ?? [])
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .toList(),
      recentMovements: (json['recent_movements'] as List<dynamic>? ?? [])
          .map((m) => StockMovement.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
