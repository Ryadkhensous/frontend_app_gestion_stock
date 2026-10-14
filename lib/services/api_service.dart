import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/point_of_sale.dart';
import '../models/stock_movement.dart';
import '../models/dashboard_stats.dart';
import '../models/commercial_document.dart';
import '../models/product_profit.dart';
import '../models/seller.dart';
import '../utils/constants.dart';

import 'dart:io';
import 'dart:async';

class ApiService {
  static final ApiService instance = ApiService();

  String baseUrl;
  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 12);

  ApiService({String? customUrl}) : baseUrl = customUrl ?? AppConstants.defaultBaseUrl;

  void updateBaseUrl(String newUrl) {
    baseUrl = newUrl;
  }

  Future<bool> checkServerConnection() async {
    try {
      final rootUrl = baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      final uri = Uri.parse(rootUrl.isEmpty ? baseUrl : rootUrl);
      final res = await _client.get(uri).timeout(const Duration(seconds: 2));
      return res.statusCode >= 200 && res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  String _parseErrorMessage(http.Response res, String defaultMessage) {
    try {
      final dynamic body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body.containsKey('detail')) {
        final detail = body['detail'];
        if (detail is String) return detail;
        if (detail is List) {
          return detail.map((e) {
            if (e is Map) {
              return e['msg']?.toString() ?? e.toString();
            }
            return e.toString();
          }).join(', ');
        }
        return detail.toString();
      }
    } catch (_) {}
    return '$defaultMessage (${res.statusCode})';
  }

  String? _authToken;

  String? get authToken => _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _buildHeaders([Map<String, String>? customHeaders]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?customHeaders,
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // AUTH
  Future<Map<String, dynamic>> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final res = await _post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      setAuthToken(token);
      return data;
    } else {
      throw Exception(_parseErrorMessage(res, 'Échec de la connexion'));
    }
  }

  Future<Map<String, dynamic>> registerTenant({
    required String name,
    required String adminUsername,
    required String adminPassword,
    String? adminEmail,
    String subscriptionPlan = 'ENTERPRISE',
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register-tenant');
    final res = await _post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'admin_username': adminUsername,
        'admin_password': adminPassword,
        'admin_email': adminEmail,
        'subscription_plan': subscriptionPlan,
      }),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      setAuthToken(token);
      return data;
    } else {
      throw Exception(_parseErrorMessage(res, 'Échec de la création du magasin'));
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    final uri = Uri.parse('$baseUrl/auth/me');
    final res = await _get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception(_parseErrorMessage(res, 'Session expirée'));
    }
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) async {
    try {
      return await _client.get(uri, headers: _buildHeaders(headers)).timeout(_timeout);
    } on SocketException catch (_) {
      throw Exception("Connexion au serveur impossible ($baseUrl). Vérifiez le réseau ou l'adresse IP.");
    } on TimeoutException catch (_) {
      throw Exception("Délai d'attente dépassé avec le serveur.");
    }
  }

  Future<http.Response> _post(Uri uri, {Map<String, String>? headers, Object? body}) async {
    try {
      return await _client.post(uri, headers: _buildHeaders(headers), body: body).timeout(_timeout);
    } on SocketException catch (_) {
      throw Exception("Connexion au serveur impossible ($baseUrl). Vérifiez le réseau ou l'adresse IP.");
    } on TimeoutException catch (_) {
      throw Exception("Délai d'attente dépassé avec le serveur.");
    }
  }

  Future<http.Response> _put(Uri uri, {Map<String, String>? headers, Object? body}) async {
    try {
      return await _client.put(uri, headers: _buildHeaders(headers), body: body).timeout(_timeout);
    } on SocketException catch (_) {
      throw Exception("Connexion au serveur impossible ($baseUrl). Vérifiez le réseau ou l'adresse IP.");
    } on TimeoutException catch (_) {
      throw Exception("Délai d'attente dépassé avec le serveur.");
    }
  }

  Future<http.Response> _patch(Uri uri, {Map<String, String>? headers, Object? body}) async {
    try {
      return await _client.patch(uri, headers: _buildHeaders(headers), body: body).timeout(_timeout);
    } on SocketException catch (_) {
      throw Exception("Connexion au serveur impossible ($baseUrl). Vérifiez le réseau ou l'adresse IP.");
    } on TimeoutException catch (_) {
      throw Exception("Délai d'attente dépassé avec le serveur.");
    }
  }

  Future<http.Response> _delete(Uri uri, {Map<String, String>? headers}) async {
    try {
      return await _client.delete(uri, headers: _buildHeaders(headers)).timeout(_timeout);
    } on SocketException catch (_) {
      throw Exception("Connexion au serveur impossible ($baseUrl). Vérifiez le réseau ou l'adresse IP.");
    } on TimeoutException catch (_) {
      throw Exception("Délai d'attente dépassé avec le serveur.");
    }
  }

  // DASHBOARD
  Future<DashboardStats> getDashboardStats() async {
    final res = await _get(Uri.parse('$baseUrl/dashboard/stats'));
    if (res.statusCode == 200) {
      return DashboardStats.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception('Erreur lors du chargement des statistiques (${res.statusCode})');
    }
  }

  // PRODUITS
  Future<List<Product>> getProducts({
    String? search,
    int? categoryId,
    bool lowStockOnly = false,
  }) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (categoryId != null) queryParams['category_id'] = categoryId.toString();
    if (lowStockOnly) queryParams['low_stock_only'] = 'true';

    final uri = Uri.parse('$baseUrl/products/').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final res = await _get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((json) => Product.fromJson(json)).toList();
    } else {
      throw Exception('Erreur lors du chargement des produits (${res.statusCode})');
    }
  }

  Future<Product> createProduct(Map<String, dynamic> payload) async {
    final res = await _post(
      Uri.parse('$baseUrl/products/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return Product.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur lors de la création du produit'));
    }
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> payload) async {
    final res = await _put(
      Uri.parse('$baseUrl/products/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return Product.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur lors de la mise à jour du produit'));
    }
  }

  Future<void> deleteProduct(int id) async {
    final res = await _delete(Uri.parse('$baseUrl/products/$id'));
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Erreur lors de la suppression du produit');
    }
  }

  Future<String> uploadProductImage(List<int> bytes, String filename) async {
    try {
      final uri = Uri.parse('$baseUrl/products/upload-image');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['url'] as String;
      } else {
        throw Exception(_parseErrorMessage(response, "Échec du téléchargement de l'image"));
      }
    } catch (e) {
      if (e.toString().contains("SocketException") || e.toString().contains("Connection refused")) {
        throw Exception("Impossible de joindre le serveur ($baseUrl).");
      }
      rethrow;
    }
  }

  // CATEGORIES
  Future<List<Category>> getCategories() async {
    final res = await _get(Uri.parse('$baseUrl/categories/'));
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((json) => Category.fromJson(json)).toList();
    } else {
      throw Exception('Erreur chargement catégories (${res.statusCode})');
    }
  }

  Future<Category> createCategory(Map<String, dynamic> payload) async {
    final res = await _post(
      Uri.parse('$baseUrl/categories/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return Category.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur création catégorie'));
    }
  }

  // POINTS DE VENTE & CARTOGRAPHIE
  Future<List<PointOfSale>> getPointsOfSale({bool activeOnly = false}) async {
    final uri = Uri.parse('$baseUrl/points-of-sale/').replace(
      queryParameters: activeOnly ? {'active_only': 'true'} : null,
    );
    final res = await _get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((json) => PointOfSale.fromJson(json)).toList();
    } else {
      throw Exception('Erreur chargement points de vente (${res.statusCode})');
    }
  }

  Future<PointOfSale> createPointOfSale(Map<String, dynamic> payload) async {
    final res = await _post(
      Uri.parse('$baseUrl/points-of-sale/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return PointOfSale.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur création point de vente'));
    }
  }

  Future<PointOfSale> updatePointOfSale(int id, Map<String, dynamic> payload) async {
    final res = await _put(
      Uri.parse('$baseUrl/points-of-sale/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return PointOfSale.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur mise à jour point de vente'));
    }
  }

  Future<void> deletePointOfSale(int id) async {
    final res = await _delete(Uri.parse('$baseUrl/points-of-sale/$id'));
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Erreur suppression point de vente');
    }
  }

  // MOUVEMENTS DE STOCK
  Future<List<StockMovement>> getStockMovements({int? productId, int? posId, int limit = 50}) async {
    final query = <String, String>{'limit': limit.toString()};
    if (productId != null) query['product_id'] = productId.toString();
    if (posId != null) query['point_of_sale_id'] = posId.toString();

    final uri = Uri.parse('$baseUrl/stock-movements/').replace(queryParameters: query);
    final res = await _get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((json) => StockMovement.fromJson(json)).toList();
    } else {
      throw Exception('Erreur chargement mouvements (${res.statusCode})');
    }
  }

  Future<StockMovement> createStockMovement(Map<String, dynamic> payload) async {
    final res = await _post(
      Uri.parse('$baseUrl/stock-movements/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return StockMovement.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur enregistrement mouvement'));
    }
  }

  // DOCUMENTS COMMERCIAUX (Bons de commande & Bons de livraison)
  Future<List<CommercialDocument>> getDocuments({
    String? docType,
    String? status,
    String? search,
  }) async {
    final query = <String, String>{};
    if (docType != null && docType.isNotEmpty) query['doc_type'] = docType;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final uri = Uri.parse('$baseUrl/documents/').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final res = await _get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((json) => CommercialDocument.fromJson(json)).toList();
    } else {
      throw Exception('Erreur chargement documents (${res.statusCode})');
    }
  }

  Future<CommercialDocument> getDocumentById(int id) async {
    final res = await _get(Uri.parse('$baseUrl/documents/$id'));
    if (res.statusCode == 200) {
      return CommercialDocument.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception('Erreur chargement du document ($id)');
    }
  }

  Future<CommercialDocument> createDocument(Map<String, dynamic> payload) async {
    final res = await _post(
      Uri.parse('$baseUrl/documents/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return CommercialDocument.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur création document'));
    }
  }

  Future<CommercialDocument> updateDocument(int id, Map<String, dynamic> payload) async {
    final res = await _put(
      Uri.parse('$baseUrl/documents/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return CommercialDocument.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur modification document'));
    }
  }

  Future<CommercialDocument> updateDocumentStatus(int id, String status) async {
    final res = await _patch(
      Uri.parse('$baseUrl/documents/$id/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode == 200) {
      return CommercialDocument.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur mise à jour statut document'));
    }
  }

  Future<CommercialDocument> convertOrderToDelivery(int id, {bool autoDeliver = false}) async {
    final uri = Uri.parse('$baseUrl/documents/$id/convert-to-delivery${autoDeliver ? '?auto_deliver=true' : ''}');
    final res = await _post(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 201) {
      return CommercialDocument.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur conversion commande en livraison'));
    }
  }

  Future<void> deleteDocument(int id) async {
    final res = await _delete(Uri.parse('$baseUrl/documents/$id'));
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(_parseErrorMessage(res, 'Erreur suppression document'));
    }
  }

  // POS CHECKOUT (Caisse enregistreuse rapide)
  Future<Map<String, dynamic>> posCheckout(Map<String, dynamic> payload) async {
    final res = await _post(
      Uri.parse('$baseUrl/pos/checkout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur lors de l\'encaissement'));
    }
  }

  // INVENTAIRE PHYSIQUE & RÉCONCILIATION
  Future<Map<String, dynamic>> reconcileInventory(Map<String, dynamic> payload) async {
    final res = await _post(
      Uri.parse('$baseUrl/inventory/reconcile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur réconciliation inventaire'));
    }
  }

  // ANALYTICS & RÉAPPROVISIONNEMENT
  Future<Map<String, dynamic>> getReorderSuggestions() async {
    final res = await _get(Uri.parse('$baseUrl/analytics/reorder-suggestions'));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } else {
      throw Exception('Erreur chargement des suggestions de réapprovisionnement');
    }
  }

  Future<CommercialDocument> generateAutoOrder(Map<String, dynamic> payload) async {
    final res = await _post(
      Uri.parse('$baseUrl/analytics/auto-order'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      return CommercialDocument.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur génération commande automatique'));
    }
  }

  Future<Map<String, dynamic>> getFinancialOverview() async {
    final res = await _get(Uri.parse('$baseUrl/analytics/financials'));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } else {
      throw Exception('Erreur chargement des indicateurs financiers');
    }
  }

  // CALCUL DU BÉNÉFICE PAR PRODUIT PAR RAPPORT À UN CALENDRIER
  Future<ProductProfitReport> getProductProfitReport({
    DateTime? startDate,
    DateTime? endDate,
    int? posId,
    int? categoryId,
    String? search,
    String sortBy = 'profit_desc',
    bool includeUnsold = false,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) {
      queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(startDate);
    }
    if (endDate != null) {
      queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(endDate);
    }
    if (posId != null) queryParams['point_of_sale_id'] = posId.toString();
    if (categoryId != null) queryParams['category_id'] = categoryId.toString();
    if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();
    if (sortBy.isNotEmpty) queryParams['sort_by'] = sortBy;
    if (includeUnsold) queryParams['include_unsold'] = 'true';

    final uri = Uri.parse('$baseUrl/analytics/profit-by-product').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    final res = await _get(uri);
    if (res.statusCode == 200) {
      final dynamic body = jsonDecode(utf8.decode(res.bodyBytes));
      return ProductProfitReport.fromJson(body as Map<String, dynamic>);
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur calcul des bénéfices'));
    }
  }

  // GESTION DES VENDEURS & COMMISSIONS
  Future<List<Seller>> getSellers({bool activeOnly = false}) async {
    final uri = Uri.parse('$baseUrl/sellers/').replace(
      queryParameters: activeOnly ? {'active_only': 'true'} : null,
    );
    final res = await _get(uri);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((json) => Seller.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur lors du chargement des vendeurs'));
    }
  }

  Future<SellerOverview> getSellersSummary() async {
    final uri = Uri.parse('$baseUrl/sellers/summary');
    final res = await _get(uri);
    if (res.statusCode == 200) {
      final dynamic data = jsonDecode(utf8.decode(res.bodyBytes));
      return SellerOverview.fromJson(data as Map<String, dynamic>);
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur lors du chargement de la synthèse des vendeurs'));
    }
  }

  Future<SellerDetailData> getSellerDetail(int id) async {
    final uri = Uri.parse('$baseUrl/sellers/$id');
    final res = await _get(uri);
    if (res.statusCode == 200) {
      final dynamic data = jsonDecode(utf8.decode(res.bodyBytes));
      return SellerDetailData.fromJson(data as Map<String, dynamic>);
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur lors du chargement des détails du vendeur'));
    }
  }

  Future<Seller> createSeller(Map<String, dynamic> payload) async {
    final res = await _post(
      Uri.parse('$baseUrl/sellers/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      final dynamic data = jsonDecode(utf8.decode(res.bodyBytes));
      return Seller.fromJson(data as Map<String, dynamic>);
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur lors de la création du vendeur'));
    }
  }

  Future<Seller> updateSeller(int id, Map<String, dynamic> payload) async {
    final res = await _put(
      Uri.parse('$baseUrl/sellers/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      final dynamic data = jsonDecode(utf8.decode(res.bodyBytes));
      return Seller.fromJson(data as Map<String, dynamic>);
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur lors de la mise à jour du vendeur'));
    }
  }

  Future<Map<String, dynamic>> deleteSeller(int id) async {
    final res = await _delete(Uri.parse('$baseUrl/sellers/$id'));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception(_parseErrorMessage(res, 'Erreur lors de la suppression du vendeur'));
    }
  }
}

