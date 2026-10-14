class StockMovement {
  final int id;
  final int productId;
  final int? pointOfSaleId;
  final String movementType; // IN, OUT, TRANSFER
  final int quantity;
  final String? reference;
  final String? note;
  final DateTime createdAt;
  final String? productName;
  final String? pointOfSaleName;

  StockMovement({
    required this.id,
    required this.productId,
    this.pointOfSaleId,
    required this.movementType,
    required this.quantity,
    this.reference,
    this.note,
    required this.createdAt,
    this.productName,
    this.pointOfSaleName,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      pointOfSaleId: json['point_of_sale_id'] as int?,
      movementType: json['movement_type'] as String,
      quantity: json['quantity'] as int,
      reference: json['reference'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      productName: json['product_name'] as String?,
      pointOfSaleName: json['point_of_sale_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'point_of_sale_id': pointOfSaleId,
      'movement_type': movementType,
      'quantity': quantity,
      'reference': reference,
      'note': note,
    };
  }
}
