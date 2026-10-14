class Seller {
  final int id;
  final int tenantId;
  final String username;
  final String? email;
  final String? phone;
  final String fullName;
  final String role;
  final double commissionRate;
  final String commissionType;
  final int? pointOfSaleId;
  final String? pointOfSaleName;
  final bool isActive;
  final DateTime createdAt;
  final int totalSalesCount;
  final double totalTurnover;
  final double totalCommission;
  final Map<String, dynamic>? permissions;

  Seller({
    required this.id,
    required this.tenantId,
    required this.username,
    this.email,
    this.phone,
    required this.fullName,
    required this.role,
    this.commissionRate = 0.0,
    this.commissionType = "PERCENTAGE",
    this.pointOfSaleId,
    this.pointOfSaleName,
    this.isActive = true,
    required this.createdAt,
    this.totalSalesCount = 0,
    this.totalTurnover = 0.0,
    this.totalCommission = 0.0,
    this.permissions,
  });

  factory Seller.fromJson(Map<String, dynamic> json) {
    return Seller(
      id: json['id'] as int,
      tenantId: json['tenant_id'] as int? ?? 1,
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String? ?? json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'SELLER',
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.0,
      commissionType: json['commission_type'] as String? ?? 'PERCENTAGE',
      pointOfSaleId: json['point_of_sale_id'] as int?,
      pointOfSaleName: json['point_of_sale_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalSalesCount: json['total_sales_count'] as int? ?? 0,
      totalTurnover: (json['total_turnover'] as num?)?.toDouble() ?? 0.0,
      totalCommission: (json['total_commission'] as num?)?.toDouble() ?? 0.0,
      permissions: json['permissions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'username': username,
    'email': email,
    'phone': phone,
    'full_name': fullName,
    'role': role,
    'commission_rate': commissionRate,
    'commission_type': commissionType,
    'point_of_sale_id': pointOfSaleId,
    'point_of_sale_name': pointOfSaleName,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'total_sales_count': totalSalesCount,
    'total_turnover': totalTurnover,
    'total_commission': totalCommission,
    'permissions': permissions,
  };

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'V';
  }
}

class SellerSaleItem {
  final int id;
  final String referenceNumber;
  final double totalAmount;
  final double commissionAmount;
  final DateTime issueDate;
  final String status;
  final String? partnerName;
  final String? pointOfSaleName;

  SellerSaleItem({
    required this.id,
    required this.referenceNumber,
    required this.totalAmount,
    required this.commissionAmount,
    required this.issueDate,
    required this.status,
    this.partnerName,
    this.pointOfSaleName,
  });

  factory SellerSaleItem.fromJson(Map<String, dynamic> json) {
    return SellerSaleItem(
      id: json['id'] as int,
      referenceNumber: json['reference_number'] as String? ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0.0,
      issueDate: json['issue_date'] != null
          ? DateTime.tryParse(json['issue_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? 'DELIVERED',
      partnerName: json['partner_name'] as String?,
      pointOfSaleName: json['point_of_sale_name'] as String?,
    );
  }
}

class SellerDetailData {
  final Seller seller;
  final List<SellerSaleItem> recentSales;

  SellerDetailData({
    required this.seller,
    required this.recentSales,
  });

  factory SellerDetailData.fromJson(Map<String, dynamic> json) {
    return SellerDetailData(
      seller: Seller.fromJson(json['seller'] as Map<String, dynamic>),
      recentSales: (json['recent_sales'] as List<dynamic>? ?? [])
          .map((item) => SellerSaleItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SellerOverview {
  final int totalSellers;
  final int activeSellers;
  final int totalSalesCount;
  final double totalTurnover;
  final double totalCommission;
  final List<Seller> sellers;

  SellerOverview({
    required this.totalSellers,
    required this.activeSellers,
    required this.totalSalesCount,
    required this.totalTurnover,
    required this.totalCommission,
    required this.sellers,
  });

  factory SellerOverview.fromJson(Map<String, dynamic> json) {
    return SellerOverview(
      totalSellers: json['total_sellers'] as int? ?? 0,
      activeSellers: json['active_sellers'] as int? ?? 0,
      totalSalesCount: json['total_sales_count'] as int? ?? 0,
      totalTurnover: (json['total_turnover'] as num?)?.toDouble() ?? 0.0,
      totalCommission: (json['total_commission'] as num?)?.toDouble() ?? 0.0,
      sellers: (json['sellers'] as List<dynamic>? ?? [])
          .map((item) => Seller.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
