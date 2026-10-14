import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class SettingsProvider with ChangeNotifier {
  static const String _keyApiUrl = 'settings_api_url';
  static const String _keyCompanyName = 'settings_company_name';
  static const String _keyCompanyAddress = 'settings_company_address';
  static const String _keyCompanyPhone = 'settings_company_phone';
  static const String _keyCompanyEmail = 'settings_company_email';
  static const String _keyCompanyTaxId = 'settings_company_tax_id';
  static const String _keyCurrencySymbol = 'settings_currency_symbol';
  static const String _keyReceiptFooter = 'settings_receipt_footer';
  static const String _keyEnableHaptic = 'settings_enable_haptic';
  static const String _keyEnableSound = 'settings_enable_sound';
  static const String _keyDefaultPosId = 'settings_default_pos_id';
  static const String _keyDefaultPrintFormat = 'settings_default_print_format';
  static const String _keyDefaultMinStock = 'settings_default_min_stock';

  // Valeurs par défaut
  String _apiUrl = AppConstants.defaultBaseUrl;
  String _companyName = "Stockio";
  String _companyAddress = "Alger Centre, Algérie";
  String _companyPhone = "+213 (0) 550 12 34 56";
  String _companyEmail = "contact@gestionstock.dz";
  String _companyTaxId = "NIF: 001916012345678 • RC: 16/00-1234567";
  String _currencySymbol = "DA";
  String _receiptFooter = "Merci pour votre visite ! Les articles vendus sont sous garantie commerciale.";
  bool _enableHaptic = true;
  bool _enableSound = true;
  int? _defaultPosId;
  String _defaultPrintFormat = "THERMAL_80MM"; // 'THERMAL_80MM' ou 'A4'
  int _defaultMinStock = 5;

  bool _isLoaded = false;

  // Getters
  String get apiUrl => _apiUrl;
  String get companyName => _companyName;
  String get companyAddress => _companyAddress;
  String get companyPhone => _companyPhone;
  String get companyEmail => _companyEmail;
  String get companyTaxId => _companyTaxId;
  String get currencySymbol => _currencySymbol;
  String get receiptFooter => _receiptFooter;
  bool get enableHaptic => _enableHaptic;
  bool get enableSound => _enableSound;
  int? get defaultPosId => _defaultPosId;
  String get defaultPrintFormat => _defaultPrintFormat;
  int get defaultMinStock => _defaultMinStock;
  bool get isLoaded => _isLoaded;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiUrl = AppConstants.defaultBaseUrl;
      await prefs.setString(_keyApiUrl, _apiUrl);
      _companyName = prefs.getString(_keyCompanyName) ?? "Stockio";
      _companyAddress = prefs.getString(_keyCompanyAddress) ?? "Alger Centre, Algérie";
      _companyPhone = prefs.getString(_keyCompanyPhone) ?? "+213 (0) 550 12 34 56";
      _companyEmail = prefs.getString(_keyCompanyEmail) ?? "contact@gestionstock.dz";
      _companyTaxId = prefs.getString(_keyCompanyTaxId) ?? "NIF: 001916012345678 • RC: 16/00-1234567";
      _currencySymbol = prefs.getString(_keyCurrencySymbol) ?? "DA";
      _receiptFooter = prefs.getString(_keyReceiptFooter) ??
          "Merci pour votre visite ! Les articles vendus sont sous garantie commerciale.";
      _enableHaptic = prefs.getBool(_keyEnableHaptic) ?? true;
      _enableSound = prefs.getBool(_keyEnableSound) ?? true;
      _defaultPosId = prefs.getInt(_keyDefaultPosId);
      _defaultPrintFormat = prefs.getString(_keyDefaultPrintFormat) ?? "THERMAL_80MM";
      _defaultMinStock = prefs.getInt(_keyDefaultMinStock) ?? 5;

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur chargement des paramètres: $e");
    }
  }

  Future<void> saveSettings({
    String? apiUrl,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    String? companyTaxId,
    String? currencySymbol,
    String? receiptFooter,
    bool? enableHaptic,
    bool? enableSound,
    int? defaultPosId,
    String? defaultPrintFormat,
    int? defaultMinStock,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (apiUrl != null) {
      _apiUrl = apiUrl.trim();
      await prefs.setString(_keyApiUrl, _apiUrl);
    }
    if (companyName != null) {
      _companyName = companyName.trim();
      await prefs.setString(_keyCompanyName, _companyName);
    }
    if (companyAddress != null) {
      _companyAddress = companyAddress.trim();
      await prefs.setString(_keyCompanyAddress, _companyAddress);
    }
    if (companyPhone != null) {
      _companyPhone = companyPhone.trim();
      await prefs.setString(_keyCompanyPhone, _companyPhone);
    }
    if (companyEmail != null) {
      _companyEmail = companyEmail.trim();
      await prefs.setString(_keyCompanyEmail, _companyEmail);
    }
    if (companyTaxId != null) {
      _companyTaxId = companyTaxId.trim();
      await prefs.setString(_keyCompanyTaxId, _companyTaxId);
    }
    if (currencySymbol != null) {
      _currencySymbol = currencySymbol.trim();
      await prefs.setString(_keyCurrencySymbol, _currencySymbol);
    }
    if (receiptFooter != null) {
      _receiptFooter = receiptFooter.trim();
      await prefs.setString(_keyReceiptFooter, _receiptFooter);
    }
    if (enableHaptic != null) {
      _enableHaptic = enableHaptic;
      await prefs.setBool(_keyEnableHaptic, _enableHaptic);
    }
    if (enableSound != null) {
      _enableSound = enableSound;
      await prefs.setBool(_keyEnableSound, _enableSound);
    }
    if (defaultPosId != null) {
      _defaultPosId = defaultPosId;
      await prefs.setInt(_keyDefaultPosId, defaultPosId);
    }
    if (defaultPrintFormat != null) {
      _defaultPrintFormat = defaultPrintFormat;
      await prefs.setString(_keyDefaultPrintFormat, defaultPrintFormat);
    }
    if (defaultMinStock != null) {
      _defaultMinStock = defaultMinStock;
      await prefs.setInt(_keyDefaultMinStock, defaultMinStock);
    }

    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _apiUrl = AppConstants.defaultBaseUrl;
    _companyName = "Stockio";
    _companyAddress = "Alger Centre, Algérie";
    _companyPhone = "+213 (0) 550 12 34 56";
    _companyEmail = "contact@gestionstock.dz";
    _companyTaxId = "NIF: 001916012345678 • RC: 16/00-1234567";
    _currencySymbol = "DA";
    _receiptFooter = "Merci pour votre visite ! Les articles vendus sont sous garantie commerciale.";
    _enableHaptic = true;
    _enableSound = true;
    _defaultPosId = null;
    _defaultPrintFormat = "THERMAL_80MM";
    _defaultMinStock = 5;

    notifyListeners();
  }

  /// Test de connexion en direct à l'API avec mesure de latence
  Future<Map<String, dynamic>> testConnection([String? testUrl]) async {
    final urlToTest = (testUrl ?? _apiUrl).trim();
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse('$urlToTest/dashboard/stats');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      stopwatch.stop();

      if (res.statusCode == 200) {
        return {
          'success': true,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'message': 'Connecté avec succès (${stopwatch.elapsedMilliseconds} ms)',
        };
      } else {
        return {
          'success': false,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'message': 'Code réponse HTTP: ${res.statusCode}',
        };
      }
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'message': 'Erreur de connexion : $e',
      };
    }
  }
}
