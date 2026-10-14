import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScannerService extends ChangeNotifier {
  static final ScannerService _instance = ScannerService._internal();
  factory ScannerService() => _instance;

  static const MethodChannel _methodChannel = MethodChannel('com.stockapp/scanner_status');
  static const EventChannel _eventChannel = EventChannel('com.stockapp/scanner_events');

  bool _isConnected = false;
  String _deviceName = '';
  DateTime? _lastStatusChange;
  String? _lastScannedBarcode;

  StreamSubscription? _eventSubscription;

  // Global barcode buffer detection for HID scanners
  final StringBuffer _keyBuffer = StringBuffer();
  DateTime _lastKeyPress = DateTime.now();
  final StreamController<String> _scanStreamController = StreamController<String>.broadcast();

  bool get isConnected => _isConnected;
  String get deviceName => _deviceName.isNotEmpty ? _deviceName : "Douchette Bluetooth";
  DateTime? get lastStatusChange => _lastStatusChange;
  String? get lastScannedBarcode => _lastScannedBarcode;
  Stream<String> get onBarcodeScanned => _scanStreamController.stream;

  ScannerService._internal() {
    _init();
  }

  void _init() {
    _checkInitialStatus();
    _startListeningToDeviceEvents();
    _setupGlobalKeyHandler();
  }

  Future<void> _checkInitialStatus() async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>('getScannerStatus');
      if (result != null) {
        _updateStatus(
          connected: result['connected'] as bool? ?? false,
          name: result['deviceName'] as String? ?? '',
        );
      }
    } catch (e) {
      debugPrint('[ScannerService] Note: Scanner platform channel not available on this platform: $e');
    }
  }

  void _startListeningToDeviceEvents() {
    try {
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final connected = event['connected'] as bool? ?? false;
            final name = event['deviceName'] as String? ?? '';
            _updateStatus(connected: connected, name: name);
          }
        },
        onError: (err) {
          debugPrint('[ScannerService] EventChannel error: $err');
        },
      );
    } catch (e) {
      debugPrint('[ScannerService] Could not listen to EventChannel: $e');
    }
  }

  void _updateStatus({required bool connected, required String name}) {
    if (_isConnected != connected || _deviceName != name) {
      _isConnected = connected;
      _deviceName = name;
      _lastStatusChange = DateTime.now();
      notifyListeners();
    }
  }

  // Intercepte les frappes ultra-rapides du lecteur de code-barres physique (Mode HID)
  void _setupGlobalKeyHandler() {
    HardwareKeyboard.instance.addHandler((KeyEvent event) {
      if (event is KeyDownEvent) {
        final now = DateTime.now();
        final diff = now.difference(_lastKeyPress).inMilliseconds;
        _lastKeyPress = now;

        // Une douchette tape à moins de 80ms par caractère
        if (diff > 160 && _keyBuffer.isNotEmpty) {
          _keyBuffer.clear();
        }

        final char = event.character;
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          if (_keyBuffer.isNotEmpty) {
            final barcode = _keyBuffer.toString().trim();
            _keyBuffer.clear();
            if (barcode.isNotEmpty) {
              _onBarcodeRead(barcode);
            }
          }
        } else if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
          _keyBuffer.write(char);
        }
      }
      return false; // Permet aux autres widgets de recevoir l'événement normalement
    });
  }

  void _onBarcodeRead(String code) {
    triggerBarcodeScan(code, deviceSource: "Douchette Physique HID");
  }

  /// Déclenche un scan de code-barres (depuis douchette, clavier HID ou test d'interface)
  void triggerBarcodeScan(String code, {String? deviceSource}) {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;

    _lastScannedBarcode = cleanCode;
    _updateStatus(
      connected: true,
      name: deviceSource ?? (_deviceName.isNotEmpty ? _deviceName : "Douchette USB / Bluetooth"),
    );
    _scanStreamController.add(cleanCode);
    notifyListeners();
  }

  /// Réinitialise l'état de la douchette
  void resetStatus() {
    _updateStatus(connected: false, name: "");
    _lastScannedBarcode = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _scanStreamController.close();
    super.dispose();
  }
}
