class AuthUser {
  final int id;
  final int tenantId;
  final String username;
  final String? email;
  final String? fullName;
  final String role; // SUPERADMIN, ADMIN, MANAGER, CASHIER
  final int? pointOfSaleId;
  final bool isActive;

  AuthUser({
    required this.id,
    required this.tenantId,
    required this.username,
    this.email,
    this.fullName,
    required this.role,
    this.pointOfSaleId,
    required this.isActive,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      tenantId: json['tenant_id'] as int? ?? 1,
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      role: json['role'] as String? ?? 'ADMIN',
      pointOfSaleId: json['point_of_sale_id'] as int?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'username': username,
    'email': email,
    'full_name': fullName,
    'role': role,
    'point_of_sale_id': pointOfSaleId,
    'is_active': isActive,
  };

  bool get isAdmin =>
      role.trim().toUpperCase() == 'ADMIN' ||
      role.trim().toUpperCase() == 'SUPERADMIN';
}

class AuthTenant {
  final int id;
  final String name;
  final String slug;
  final String subscriptionPlan; // BASIC, PRO, ENTERPRISE
  final bool isActive;
  final int maxUsers;
  final int maxProducts;

  AuthTenant({
    required this.id,
    required this.name,
    required this.slug,
    required this.subscriptionPlan,
    required this.isActive,
    required this.maxUsers,
    required this.maxProducts,
  });

  factory AuthTenant.fromJson(Map<String, dynamic> json) {
    return AuthTenant(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Mon Magasin',
      slug: json['slug'] as String? ?? '',
      subscriptionPlan: json['subscription_plan'] as String? ?? 'PRO',
      isActive: json['is_active'] as bool? ?? true,
      maxUsers: json['max_users'] as int? ?? 10,
      maxProducts: json['max_products'] as int? ?? 5000,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'subscription_plan': subscriptionPlan,
    'is_active': isActive,
    'max_users': maxUsers,
    'max_products': maxProducts,
  };
}
