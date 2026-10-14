class DocumentItem {
  final int? id;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? productName;
  final String? productSku;

  DocumentItem({
    this.id,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.productName,
    this.productSku,
  });

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    return DocumentItem(
      id: json['id'] as int?,
      productId: json['product_id'] as int,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      productName: json['product_name'] as String?,
      productSku: json['product_sku'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}

class CommercialDocument {
  final int id;
  final String referenceNumber;
  final String docType; // 'ORDER' | 'DELIVERY'
  final String direction; // 'OUTGOING' | 'INCOMING'
  final String status; // 'DRAFT' | 'VALIDATED' | 'DELIVERED' | 'CANCELLED'
  final int? pointOfSaleId;
  final String? pointOfSaleName;
  final int? sellerId;
  final String? sellerName;
  final String? partnerName;
  final int? parentDocumentId;
  final String? parentDocumentReference;
  final DateTime issueDate;
  final DateTime? deliveryDate;
  final double totalAmount;
  final double commissionAmount;
  final String? notes;
  final DateTime createdAt;
  final List<DocumentItem> items;

  CommercialDocument({
    required this.id,
    required this.referenceNumber,
    required this.docType,
    required this.direction,
    required this.status,
    this.pointOfSaleId,
    this.pointOfSaleName,
    this.sellerId,
    this.sellerName,
    this.partnerName,
    this.parentDocumentId,
    this.parentDocumentReference,
    required this.issueDate,
    this.deliveryDate,
    required this.totalAmount,
    this.commissionAmount = 0.0,
    this.notes,
    required this.createdAt,
    required this.items,
  });

  bool get isOrder => docType == 'ORDER';
  bool get isDelivery => docType == 'DELIVERY';
  bool get isDelivered => status == 'DELIVERED';
  bool get isDraft => status == 'DRAFT';
  bool get isValidated => status == 'VALIDATED';
  bool get isCancelled => status == 'CANCELLED';

  String get typeLabel => isOrder ? 'Bon de Commande' : 'Bon de Livraison';

  String get directionLabel {
    if (direction == 'INCOMING') {
      return 'Réception Fournisseur (Entrée)';
    }
    return pointOfSaleName != null ? 'Vers Magasin (Transfert)' : 'Vers Client (Sortie)';
  }

  String get statusLabel {
    switch (status) {
      case 'DRAFT':
        return 'Brouillon';
      case 'VALIDATED':
        return isOrder ? 'Confirmé' : 'En attente';
      case 'DELIVERED':
        return isOrder ? 'Traité' : 'Livré';
      case 'CANCELLED':
        return 'Annulé';
      default:
        return status;
    }
  }

  int get totalItemsCount {
    return items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  factory CommercialDocument.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    List<DocumentItem> parsedItems = rawItems
        .map((e) => DocumentItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return CommercialDocument(
      id: json['id'] as int,
      referenceNumber: json['reference_number'] as String,
      docType: json['doc_type'] as String,
      direction: json['direction'] as String? ?? 'OUTGOING',
      status: json['status'] as String? ?? 'DRAFT',
      pointOfSaleId: json['point_of_sale_id'] as int?,
      pointOfSaleName: json['point_of_sale_name'] as String?,
      sellerId: json['seller_id'] as int?,
      sellerName: json['seller_name'] as String?,
      partnerName: json['partner_name'] as String?,
      parentDocumentId: json['parent_document_id'] as int?,
      parentDocumentReference: json['parent_document_reference'] as String?,
      issueDate: json['issue_date'] != null
          ? DateTime.parse(json['issue_date'] as String)
          : DateTime.now(),
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'] as String)
          : null,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      items: parsedItems,
    );
  }
}
