import 'dart:async';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/point_of_sale.dart';
import '../models/stock_movement.dart';
import '../models/dashboard_stats.dart';
import '../models/commercial_document.dart';
import '../models/seller.dart';
import '../services/api_service.dart';

class StockProvider with ChangeNotifier {
  final ApiService api = ApiService.instance;

  bool _isLoading = false;
  String? _errorMessage;

  DashboardStats? _stats;
  List<Product> _products = [];
  List<Category> _categories = [];
  List<PointOfSale> _pointsOfSale = [];
  List<StockMovement> _movements = [];
  List<CommercialDocument> _documents = [];
  List<CommercialDocument> _orders = [];
  List<CommercialDocument> _deliveries = [];
  List<Seller> _sellers = [];
  SellerOverview? _sellersOverview;

  // In-flight request guards
  bool _isLoadingProducts = false;
  bool _isLoadingMovements = false;
  bool _isLoadingDocuments = false;

  // Filtres
  int? _selectedCategoryId;
  String _searchQuery = "";
  bool _showOnlyLowStock = false;
  PointOfSale? _selectedPos;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DashboardStats? get stats => _stats;
  List<Product> get products => _products;
  List<Category> get categories => _categories;
  List<PointOfSale> get pointsOfSale => _pointsOfSale;
  List<StockMovement> get movements => _movements;
  List<CommercialDocument> get documents => _documents;
  List<CommercialDocument> get orders => _orders;
  List<CommercialDocument> get deliveries => _deliveries;
  List<Seller> get sellers => _sellers;
  SellerOverview? get sellersOverview => _sellersOverview;
  int? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get showOnlyLowStock => _showOnlyLowStock;
  PointOfSale? get selectedPos => _selectedPos;
  String get currentApiUrl => api.baseUrl;

  void updateApiUrl(String newUrl) {
    api.updateBaseUrl(newUrl);
    ApiService.instance.updateBaseUrl(newUrl);
    loadAll();
  }

  void selectPos(PointOfSale? pos) {
    _selectedPos = pos;
    notifyListeners();
  }

  Timer? _searchDebounce;

  void setSelectedCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    loadProducts();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      loadProducts();
    });
  }

  void toggleLowStockFilter() {
    _showOnlyLowStock = !_showOnlyLowStock;
    loadProducts();
  }

  // Chargement global
  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        loadStats(notify: false),
        loadCategories(notify: false),
        loadProducts(notify: false),
        loadPointsOfSale(notify: false),
        loadMovements(notify: false),
        loadDocuments(notify: false, force: true),
        loadSellers(notify: false),
      ]);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStats({bool notify = true}) async {
    try {
      _stats = await api.getDashboardStats();
      if (notify) notifyListeners();
    } catch (e) {
      if (notify) {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        notifyListeners();
      }
    }
  }

  Future<void> loadCategories({bool notify = true}) async {
    try {
      _categories = await api.getCategories();
      if (notify) notifyListeners();
    } catch (e) {
      if (notify) {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        notifyListeners();
      }
    }
  }

  Future<void> loadProducts({bool notify = true}) async {
    if (_isLoadingProducts) return;
    _isLoadingProducts = true;
    try {
      _products = await api.getProducts(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categoryId: _selectedCategoryId,
        lowStockOnly: _showOnlyLowStock,
      );
      if (notify) notifyListeners();
    } catch (e) {
      if (notify) {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        notifyListeners();
      }
    } finally {
      _isLoadingProducts = false;
    }
  }

  Future<void> loadPointsOfSale({bool notify = true}) async {
    try {
      _pointsOfSale = await api.getPointsOfSale();
      if (notify) notifyListeners();
    } catch (e) {
      if (notify) {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        notifyListeners();
      }
    }
  }

  Future<void> loadMovements({bool notify = true}) async {
    if (_isLoadingMovements) return;
    _isLoadingMovements = true;
    try {
      _movements = await api.getStockMovements();
      if (notify) notifyListeners();
    } catch (e) {
      if (notify) {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        notifyListeners();
      }
    } finally {
      _isLoadingMovements = false;
    }
  }

  // Actions CRUD Produits
  Future<bool> addProduct(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      await api.createProduct(data);
      await loadProducts(notify: false);
      await loadStats(notify: false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      debugPrint("StockProvider.addProduct error: $_errorMessage");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProduct(int id, Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      await api.updateProduct(id, data);
      await loadProducts(notify: false);
      await loadStats(notify: false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      debugPrint("StockProvider.updateProduct error: $_errorMessage");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      await api.deleteProduct(id);
      await loadProducts(notify: false);
      await loadStats(notify: false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  Future<String?> uploadProductImage(List<int> bytes, String filename) async {
    try {
      _errorMessage = null;
      final url = await api.uploadProductImage(bytes, filename);
      return url;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      debugPrint("StockProvider.uploadProductImage error: $_errorMessage");
      notifyListeners();
      return null;
    }
  }

  // Actions Points de Vente
  Future<bool> addPointOfSale(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      notifyListeners();
      final newPos = await api.createPointOfSale(data);
      _selectedPos = newPos;
      await loadPointsOfSale(notify: false);
      await loadStats(notify: false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePointOfSale(int id, Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      notifyListeners();
      await api.updatePointOfSale(id, data);
      await loadPointsOfSale(notify: false);
      await loadStats(notify: false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deletePointOfSale(int id) async {
    try {
      await api.deletePointOfSale(id);
      if (_selectedPos?.id == id) _selectedPos = null;
      await loadPointsOfSale(notify: false);
      await loadStats(notify: false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  // Actions Mouvements de stock
  Future<bool> addStockMovement(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      notifyListeners();
      await api.createStockMovement(data);
      await loadProducts(notify: false);
      await loadMovements(notify: false);
      await loadStats(notify: false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Documents Commerciaux (Bons de Commande & Bons de Livraison)
  Future<void> loadDocuments({
    bool notify = true,
    String? docType,
    String? status,
    String? search,
    bool force = false,
  }) async {
    // Si on demande la liste complète et qu'elle est déjà en mémoire, on évite un appel réseau redondant
    if (!force && docType == null && status == null && search == null && _documents.isNotEmpty && !_isLoadingDocuments) {
      if (notify) notifyListeners();
      return;
    }
    if (_isLoadingDocuments) return;
    _isLoadingDocuments = true;

    try {
      _documents = await api.getDocuments(docType: docType, status: status, search: search);
      _orders = _documents.where((d) => d.isOrder).toList(growable: false);
      _deliveries = _documents.where((d) => d.isDelivery).toList(growable: false);
      if (notify) notifyListeners();
    } catch (e) {
      if (notify) {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        notifyListeners();
      }
    } finally {
      _isLoadingDocuments = false;
    }
  }

  Future<bool> addDocument(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      notifyListeners();
      await api.createDocument(data);
      await loadDocuments(notify: false, force: true);
      await loadProducts(notify: false);
      await loadMovements(notify: false);
      await loadStats(notify: false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateDocument(int id, Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      notifyListeners();
      await api.updateDocument(id, data);
      await loadDocuments(notify: false, force: true);
      await loadProducts(notify: false);
      await loadMovements(notify: false);
      await loadStats(notify: false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateDocumentStatus(int id, String status) async {
    try {
      _isLoading = true;
      notifyListeners();
      await api.updateDocumentStatus(id, status);
      await loadDocuments(notify: false, force: true);
      await loadProducts(notify: false);
      await loadMovements(notify: false);
      await loadStats(notify: false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> convertOrderToDelivery(int id, {bool autoDeliver = false}) async {
    try {
      _isLoading = true;
      notifyListeners();
      await api.convertOrderToDelivery(id, autoDeliver: autoDeliver);
      await loadDocuments(notify: false, force: true);
      if (autoDeliver) {
        await loadProducts(notify: false);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDocument(int id) async {
    try {
      _isLoading = true;
      notifyListeners();
      await api.deleteDocument(id);
      await loadDocuments(notify: false, force: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Gestion des Vendeurs ---
  Future<void> loadSellers({bool notify = true}) async {
    try {
      final overview = await api.getSellersSummary();
      _sellersOverview = overview;
      _sellers = overview.sellers;
      if (notify) notifyListeners();
    } catch (e) {
      try {
        _sellers = await api.getSellers();
        if (notify) notifyListeners();
      } catch (inner) {
        if (notify) {
          _errorMessage = inner.toString().replaceFirst("Exception: ", "");
          notifyListeners();
        }
      }
    }
  }

  Future<bool> createSeller(Map<String, dynamic> payload) async {
    try {
      _isLoading = true;
      notifyListeners();
      await api.createSeller(payload);
      await loadSellers(notify: false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSeller(int id, Map<String, dynamic> payload) async {
    try {
      _isLoading = true;
      notifyListeners();
      await api.updateSeller(id, payload);
      await loadSellers(notify: false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSeller(int id) async {
    try {
      _isLoading = true;
      notifyListeners();
      await api.deleteSeller(id);
      await loadSellers(notify: false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
