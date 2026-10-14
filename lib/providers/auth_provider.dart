import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  static const String _keyToken = 'auth_jwt_token';
  static const String _keyUser = 'auth_user_data';
  static const String _keyTenant = 'auth_tenant_data';

  AuthUser? _currentUser;
  AuthTenant? _currentTenant;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  AuthUser? get currentUser => _currentUser;
  AuthTenant? get currentTenant => _currentTenant;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  bool get isAuthenticated => _token != null && _currentUser != null;

  String get storeName => _currentTenant?.name ?? "Magasin Principal";
  String get username => _currentUser?.username ?? "Invité";
  String get role => _currentUser?.role ?? "ADMIN";
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthProvider() {
    loadSavedAuth();
  }

  Future<void> loadSavedAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_keyToken);
      final savedUserJson = prefs.getString(_keyUser);
      final savedTenantJson = prefs.getString(_keyTenant);

      if (savedToken != null && savedUserJson != null && savedTenantJson != null) {
        _token = savedToken;
        ApiService.instance.setAuthToken(savedToken);
        _currentUser = AuthUser.fromJson(jsonDecode(savedUserJson));
        _currentTenant = AuthTenant.fromJson(jsonDecode(savedTenantJson));

        // Optionnel : rafraîchissement silencieux de session
        try {
          final meData = await ApiService.instance.getMe();
          if (meData.containsKey('user') && meData.containsKey('tenant')) {
            _currentUser = AuthUser.fromJson(meData['user']);
            _currentTenant = AuthTenant.fromJson(meData['tenant']);
            await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));
            await prefs.setString(_keyTenant, jsonEncode(_currentTenant!.toJson()));
          }
        } catch (_) {
          // Si hors-ligne, on conserve la session locale sauvegardée
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.instance.login(username.trim(), password);
      _token = res['access_token'] as String?;
      if (res['user'] != null) {
        _currentUser = AuthUser.fromJson(res['user']);
      }
      if (res['tenant'] != null) {
        _currentTenant = AuthTenant.fromJson(res['tenant']);
      }

      // Sauvegarde dans SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) await prefs.setString(_keyToken, _token!);
      if (_currentUser != null) {
        await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));
      }
      if (_currentTenant != null) {
        await prefs.setString(_keyTenant, jsonEncode(_currentTenant!.toJson()));
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerTenant({
    required String storeName,
    required String adminUsername,
    required String adminPassword,
    String? adminEmail,
    String subscriptionPlan = 'ENTERPRISE',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.instance.registerTenant(
        name: storeName.trim(),
        adminUsername: adminUsername.trim(),
        adminPassword: adminPassword,
        adminEmail: adminEmail?.trim(),
        subscriptionPlan: subscriptionPlan,
      );

      _token = res['access_token'] as String?;
      if (res['user'] != null) {
        _currentUser = AuthUser.fromJson(res['user']);
      }
      if (res['tenant'] != null) {
        _currentTenant = AuthTenant.fromJson(res['tenant']);
      }

      final prefs = await SharedPreferences.getInstance();
      if (_token != null) await prefs.setString(_keyToken, _token!);
      if (_currentUser != null) {
        await prefs.setString(_keyUser, jsonEncode(_currentUser!.toJson()));
      }
      if (_currentTenant != null) {
        await prefs.setString(_keyTenant, jsonEncode(_currentTenant!.toJson()));
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void continueAsGuest() {
    _token = null;
    ApiService.instance.setAuthToken(null);
    _currentUser = AuthUser(
      id: 1,
      tenantId: 1,
      username: "admin_demo",
      fullName: "Magasin Démo",
      role: "ADMIN",
      isActive: true,
    );
    _currentTenant = AuthTenant(
      id: 1,
      name: "Magasin Principal",
      slug: "magasin-principal",
      subscriptionPlan: "ENTERPRISE",
      isActive: true,
      maxUsers: 50,
      maxProducts: 50000,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _currentTenant = null;
    ApiService.instance.setAuthToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyTenant);

    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
