class ProductProfitItem {
  final int productId;
  final String productName;
  final String productSku;
  final String? categoryName;
  final int currentStock;
  final int quantitySold;
  final double avgSalePrice;
  final double unitCostPrice;
  final double totalRevenue;
  final double totalCost;
  final double totalProfit;
  final double marginPercentage;
  final int salesCount;

  ProductProfitItem({
    required this.productId,
    required this.productName,
    required this.productSku,
    this.categoryName,
    required this.currentStock,
    required this.quantitySold,
    required this.avgSalePrice,
    required this.unitCostPrice,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.marginPercentage,
    required this.salesCount,
  });

  factory ProductProfitItem.fromJson(Map<String, dynamic> json) {
    return ProductProfitItem(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      productSku: json['product_sku'] as String,
      categoryName: json['category_name'] as String?,
      currentStock: json['current_stock'] as int? ?? 0,
      quantitySold: json['quantity_sold'] as int? ?? 0,
      avgSalePrice: (json['avg_sale_price'] as num?)?.toDouble() ?? 0.0,
      unitCostPrice: (json['unit_cost_price'] as num?)?.toDouble() ?? 0.0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0.0,
      marginPercentage: (json['margin_percentage'] as num?)?.toDouble() ?? 0.0,
      salesCount: json['sales_count'] as int? ?? 0,
    );
  }
}

class DailyProfitItem {
  final String date;
  final double revenue;
  final double cost;
  final double profit;
  final int unitsSold;

  DailyProfitItem({
    required this.date,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.unitsSold,
  });

  factory DailyProfitItem.fromJson(Map<String, dynamic> json) {
    return DailyProfitItem(
      date: json['date'] as String,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0.0,
      unitsSold: json['units_sold'] as int? ?? 0,
    );
  }
}

class ProfitSummary {
  final String? startDate;
  final String? endDate;
  final double totalRevenue;
  final double totalCost;
  final double totalProfit;
  final double marginPercentage;
  final int totalUnitsSold;
  final int totalSalesCount;
  final String? topProfitableProduct;

  ProfitSummary({
    this.startDate,
    this.endDate,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.marginPercentage,
    required this.totalUnitsSold,
    required this.totalSalesCount,
    this.topProfitableProduct,
  });

  factory ProfitSummary.fromJson(Map<String, dynamic> json) {
    return ProfitSummary(
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0.0,
      marginPercentage: (json['margin_percentage'] as num?)?.toDouble() ?? 0.0,
      totalUnitsSold: json['total_units_sold'] as int? ?? 0,
      totalSalesCount: json['total_sales_count'] as int? ?? 0,
      topProfitableProduct: json['top_profitable_product'] as String?,
    );
  }
}

class ProductProfitReport {
  final ProfitSummary summary;
  final List<ProductProfitItem> products;
  final List<DailyProfitItem> dailyBreakdown;

  ProductProfitReport({
    required this.summary,
    required this.products,
    required this.dailyBreakdown,
  });

  factory ProductProfitReport.fromJson(Map<String, dynamic> json) {
    return ProductProfitReport(
      summary: ProfitSummary.fromJson(json['summary'] as Map<String, dynamic>),
      products: (json['products'] as List<dynamic>?)
              ?.map((e) => ProductProfitItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dailyBreakdown: (json['daily_breakdown'] as List<dynamic>?)
              ?.map((e) => DailyProfitItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
