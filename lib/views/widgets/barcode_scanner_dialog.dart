import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/stock_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/scanner_service.dart';
import '../../services/feedback_service.dart';
import '../../utils/constants.dart';
import 'barcode_label_dialog.dart';
import 'scanner_status_badge.dart';

class ScannedItemLog {
  final Product product;
  final int quantity;
  final DateTime timestamp;

  ScannedItemLog({
    required this.product,
    required this.quantity,
    required this.timestamp,
  });
}

class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final TextEditingController _barcodeCtrl = TextEditingController();
  final FocusNode _scannerFocus = FocusNode();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');

  Product? _selectedProduct;
  String? _notFoundCode;
  bool _autoReceiveOnScan = false;
  bool _isSubmitting = false;

  final List<ScannedItemLog> _sessionHistory = [];
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scannerFocus.requestFocus();
      final scannerService = Provider.of<ScannerService>(context, listen: false);
      _scanSubscription = scannerService.onBarcodeScanned.listen((code) {
        if (mounted) {
          _barcodeCtrl.text = code;
          _onBarcodeSubmitted(code);
        }
      });
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _barcodeCtrl.dispose();
    _scannerFocus.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _onBarcodeSubmitted(String code) {
    final rawCode = code.trim();
    if (rawCode.isEmpty) return;

    final provider = Provider.of<StockProvider>(context, listen: false);
    Product? found;

    // 1. Recherche exacte par SKU
    try {
      found = provider.products.firstWhere(
        (p) => p.sku.trim().toLowerCase() == rawCode.toLowerCase(),
      );
    } catch (_) {}

    // 2. Recherche par ID numérique
    if (found == null) {
      final id = int.tryParse(rawCode);
      if (id != null) {
        try {
          found = provider.products.firstWhere((p) => p.id == id);
        } catch (_) {}
      }
    }

    // 3. Recherche partielle par SKU ou nom si exact non trouvé
    if (found == null) {
      try {
        found = provider.products.firstWhere(
          (p) =>
              p.sku.toLowerCase().contains(rawCode.toLowerCase()) ||
              p.name.toLowerCase().contains(rawCode.toLowerCase()),
        );
      } catch (_) {}
    }

    _barcodeCtrl.clear();

    final settings = context.read<SettingsProvider>();

    if (found != null) {
      FeedbackService.scanSuccess(
        haptic: settings.enableHaptic,
        sound: settings.enableSound,
      );
      setState(() {
        _selectedProduct = found;
        _notFoundCode = null;
      });

      if (_autoReceiveOnScan) {
        final qty = int.tryParse(_qtyCtrl.text) ?? 1;
        _executeReception(found, qty);
      } else {
        _scannerFocus.requestFocus();
      }
    } else {
      FeedbackService.scanError(
        haptic: settings.enableHaptic,
        sound: settings.enableSound,
      );
      setState(() {
        _selectedProduct = null;
        _notFoundCode = rawCode;
      });
      _scannerFocus.requestFocus();
    }
  }

  Future<void> _executeReception(Product product, int quantity) async {
    if (quantity <= 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final provider = Provider.of<StockProvider>(context, listen: false);

    final ok = await provider.addStockMovement({
      "product_id": product.id,
      "movement_type": "IN",
      "quantity": quantity,
      "reference": "SCAN-REC-${product.sku.isNotEmpty ? product.sku : product.id}",
      "note": "Réception par lecture code-barres (douchette / lecteur)",
      if (provider.selectedPos != null) "point_of_sale_id": provider.selectedPos!.id,
    });

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (ok) {
        HapticFeedback.lightImpact();
        setState(() {
          _sessionHistory.insert(
            0,
            ScannedItemLog(
              product: product,
              quantity: quantity,
              timestamp: DateTime.now(),
            ),
          );
          try {
            _selectedProduct = provider.products.firstWhere((p) => p.id == product.id);
          } catch (_) {}
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "+$quantity reçus pour ${product.name} (Nouveau stock: ${_selectedProduct?.quantity ?? (product.quantity + quantity)})",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppConstants.success,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? "Erreur lors de la réception"),
            backgroundColor: AppConstants.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _scannerFocus.requestFocus();
    }
  }

  void _showCreateProductDialog(String initialSku) {
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController(text: initialSku);
    final priceCtrl = TextEditingController(text: "0");
    final costCtrl = TextEditingController(text: "0");
    final qtyCtrl = TextEditingController(text: "1");
    int? selectedCategory;

    showDialog(
      context: context,
      builder: (ctx) => Consumer<StockProvider>(
        builder: (c, provider, _) => StatefulBuilder(
          builder: (ctx2, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_box_outlined, color: AppConstants.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Nouveau Produit Scanné",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: skuCtrl,
                    decoration: InputDecoration(
                      labelText: "Code-barres / SKU *",
                      prefixIcon: const Icon(Icons.qr_code_2),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final now = DateTime.now();
                            final datePart = DateFormat('yyMMdd').format(now);
                            final rand = (Random().nextInt(9000) + 1000).toString();
                            skuCtrl.text = "REF-$datePart-$rand";
                            HapticFeedback.lightImpact();
                            setDialogState(() {});
                          },
                          icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                          label: const Text("Générer", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: "Désignation / Nom du produit *",
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: "Catégorie", prefixIcon: Icon(Icons.category_outlined)),
                  items: provider.categories
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (val) => selectedCategory = val,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Prix Vente (DA)"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Coût Achat (DA)"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Stock Initial"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || skuCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx);
                final ok = await provider.addProduct({
                  "name": nameCtrl.text.trim(),
                  "sku": skuCtrl.text.trim(),
                  "price": double.tryParse(priceCtrl.text) ?? 0.0,
                  "cost_price": double.tryParse(costCtrl.text) ?? 0.0,
                  "quantity": int.tryParse(qtyCtrl.text) ?? 0,
                  "category_id": selectedCategory,
                  "min_stock_alert": 5,
                });
                if (ok && mounted) {
                  _onBarcodeSubmitted(skuCtrl.text.trim());
                }
              },
              child: const Text("Créer & Réceptionner"),
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final totalReceivedInSession = _sessionHistory.fold<int>(0, (sum, item) => sum + item.quantity);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 12 : 20),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.92 : 0.85),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Entête
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppConstants.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Scanner Code-Barres & Réception",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isMobile ? "Douchettes USB/Bluetooth & PDA" : "Supporte douchettes USB / Bluetooth & terminaux PDA",
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Corps scrollable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Champ de capture du scanner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _scannerFocus.hasFocus ? AppConstants.primary : const Color(0xFFE2E8F0),
                          width: _scannerFocus.hasFocus ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.keyboard_rounded,
                                size: 16,
                                color: _scannerFocus.hasFocus ? AppConstants.primary : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Entrée Lecteur / Douchette :",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _scannerFocus.hasFocus ? AppConstants.primary : const Color(0xFF475569),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const ScannerStatusBadge(compact: true),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _barcodeCtrl,
                                  focusNode: _scannerFocus,
                                  autofocus: true,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: _onBarcodeSubmitted,
                                  decoration: InputDecoration(
                                    hintText: "Code-barres ou SKU...",
                                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.barcode_reader, color: AppConstants.primary),
                                    suffixIcon: _barcodeCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              _barcodeCtrl.clear();
                                              setState(() {});
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppConstants.primary, width: 2),
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _onBarcodeSubmitted(_barcodeCtrl.text),
                                child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Option mode continu
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _autoReceiveOnScan,
                                  activeColor: AppConstants.primary,
                                  onChanged: (val) {
                                    setState(() => _autoReceiveOnScan = val ?? false);
                                    _scannerFocus.requestFocus();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _autoReceiveOnScan = !_autoReceiveOnScan);
                                    _scannerFocus.requestFocus();
                                  },
                                  child: const Text(
                                    "Réception continue (auto à chaque bip)",
                                    style: TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Erreur si produit non trouvé
                    if (_notFoundCode != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Aucun produit : $_notFoundCode",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Vérifiez le SKU ou créez cet article.",
                                    style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text("Créer", style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onPressed: () => _showCreateProductDialog(_notFoundCode!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Produit identifié & panneau de réception
                    if (_selectedProduct != null) ...[
                      _buildProductReceptionCard(_selectedProduct!),
                      const SizedBox(height: 16),
                    ],

                    // Historique de la session de réception
                    if (_sessionHistory.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.history_rounded, size: 16, color: Color(0xFF475569)),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Historique de cette session (${_sessionHistory.length})",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Total : $totalReceivedInSession pcs",
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _sessionHistory.take(5).length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              itemBuilder: (context, idx) {
                                final log = _sessionHistory[idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.arrow_downward_rounded, color: Colors.green, size: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              log.product.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                            ),
                                            Text(
                                              "SKU: ${log.product.sku.isNotEmpty ? log.product.sku : log.product.id}",
                                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        "+${log.quantity} pcs",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bas de dialogue
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _sessionHistory.isEmpty
                          ? "Pointez le lecteur sur le code-barres"
                          : "$totalReceivedInSession article(s) réceptionné(s)",
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: const Text("Terminer"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductReceptionCard(Product product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête produit
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: AppConstants.primary, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "SKU: ${product.sku.isNotEmpty ? product.sku : product.id}",
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (product.category?.name != null)
                          Text(
                            product.category!.name,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Bouton imprimer étiquette pour ce produit
              Tooltip(
                message: "Imprimer étiquette code-barres",
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.print_rounded, size: 15),
                  label: const Text("Étiquette", style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => BarcodeLabelDialog(product: product),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // État actuel du stock
          Row(
            children: [
              const Text("Stock en magasin : ", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: product.isLowStock ? Colors.red.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${product.quantity} unités",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: product.isLowStock ? Colors.red : Colors.green,
                  ),
                ),
              ),
              if (product.isLowStock) ...[
                const SizedBox(width: 6),
                const Text(
                  "(Stock bas !)",
                  style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // Contrôles de réception
          const Text(
            "Quantité à réceptionner (Entrée en stock) :",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),

          // Sélecteur de quantité & touches rapides
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.remove_circle_outline, color: AppConstants.primary, size: 24),
                    onPressed: () {
                      final cur = int.tryParse(_qtyCtrl.text) ?? 1;
                      if (cur > 1) {
                        _qtyCtrl.text = (cur - 1).toString();
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 65,
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.add_circle_outline, color: AppConstants.primary, size: 24),
                    onPressed: () {
                      final cur = int.tryParse(_qtyCtrl.text) ?? 1;
                      _qtyCtrl.text = (cur + 1).toString();
                      setState(() {});
                    },
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _quickQtyButton(product, 5),
                  const SizedBox(width: 5),
                  _quickQtyButton(product, 10),
                  const SizedBox(width: 5),
                  _quickQtyButton(product, 50),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bouton de validation
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(
                _isSubmitting
                    ? "Enregistrement en cours..."
                    : "Valider la réception (+${_qtyCtrl.text} unités)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 1,
              ),
              onPressed: _isSubmitting
                  ? null
                  : () {
                      final qty = int.tryParse(_qtyCtrl.text) ?? 1;
                      _executeReception(product, qty);
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickQtyButton(Product product, int addQty) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        _qtyCtrl.text = addQty.toString();
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          "+$addQty",
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
      ),
    );
  }
}
