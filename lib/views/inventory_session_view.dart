import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/stock_provider.dart';
import '../services/scanner_service.dart';
import '../utils/constants.dart';
import 'widgets/scanner_status_badge.dart';

class InventoryCountRecord {
  final Product product;
  int countedQuantity;

  InventoryCountRecord({
    required this.product,
    required this.countedQuantity,
  });

  int get variance => countedQuantity - product.quantity;
}

class InventorySessionView extends StatefulWidget {
  const InventorySessionView({super.key});

  @override
  State<InventorySessionView> createState() => _InventorySessionViewState();
}

class _InventorySessionViewState extends State<InventorySessionView> {
  final Map<int, InventoryCountRecord> _countedItems = {};
  final TextEditingController _barcodeCtrl = TextEditingController();
  final FocusNode _barcodeFocus = FocusNode();
  StreamSubscription? _scanSubscription;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocus.requestFocus();
      final scanner = context.read<ScannerService>();
      _scanSubscription = scanner.onBarcodeScanned.listen((code) {
        if (mounted) {
          _handleBarcodeScan(code);
        }
      });
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    super.dispose();
  }

  void _handleBarcodeScan(String code) {
    final raw = code.trim();
    if (raw.isEmpty) return;

    final provider = context.read<StockProvider>();
    Product? found;

    try {
      found = provider.products.firstWhere(
        (p) => p.sku.toLowerCase() == raw.toLowerCase() || p.id.toString() == raw,
      );
    } catch (_) {
      try {
        found = provider.products.firstWhere(
          (p) => p.name.toLowerCase().contains(raw.toLowerCase()),
        );
      } catch (_) {}
    }

    _barcodeCtrl.clear();

    if (found != null) {
      HapticFeedback.lightImpact();
      setState(() {
        if (_countedItems.containsKey(found!.id)) {
          _countedItems[found.id]!.countedQuantity += 1;
        } else {
          _countedItems[found.id] = InventoryCountRecord(
            product: found,
            countedQuantity: 1,
          );
        }
      });
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Code '$raw' introuvable dans le catalogue."),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _barcodeFocus.requestFocus();
  }

  int get _totalScannedUnits =>
      _countedItems.values.fold(0, (acc, item) => acc + item.countedQuantity);

  int get _discrepanciesCount =>
      _countedItems.values.where((item) => item.variance != 0).length;

  Future<void> _submitReconciliation() async {
    if (_countedItems.isEmpty || _isSubmitting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.rule_folder_rounded, color: AppConstants.primary),
            SizedBox(width: 8),
            Text("Appliquer la Réconciliation ?"),
          ],
        ),
        content: Text(
          "Cette action va ajuster le stock de ${_countedItems.length} article(s) "
          "et enregistrer les écarts en base de données. Confirmer ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("Confirmer l'Ajustement"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSubmitting = true);
    final provider = context.read<StockProvider>();

    try {
      final payload = {
        "session_title": "Inventaire Physique Douchette",
        if (provider.selectedPos != null) "point_of_sale_id": provider.selectedPos!.id,
        "items": _countedItems.values.map((item) {
          return {
            "product_id": item.product.id,
            "counted_quantity": item.countedQuantity,
            "note": item.variance > 0
                ? "Surplus inventaire (+${item.variance})"
                : (item.variance < 0 ? "Déficit inventaire (${item.variance})" : "Conforme"),
          };
        }).toList(),
      };

      final result = await provider.api.reconcileInventory(payload);
      await provider.loadAll();

      if (mounted) {
        setState(() {
          _countedItems.clear();
          _isSubmitting = false;
        });

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text("Inventaire Réconcilié !"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Réf. Session : ${result['reference']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Total articles revus : ${result['total_reviewed']}"),
                Text("Articles ajustés : ${result['total_adjusted']}"),
                const SizedBox(height: 12),
                const Text("Tous les stocks ont été mis à jour avec succès !", style: TextStyle(color: Color(0xFF059669))),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary, foregroundColor: Colors.white),
                child: const Text("Fermer"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _countedItems.values.toList();

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text("Session d'Inventaire Physique"),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: ScannerStatusBadge(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Barre de saisie & Scan
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeCtrl,
                        focusNode: _barcodeFocus,
                        decoration: InputDecoration(
                          hintText: "Scannez un code ou tapez un SKU...",
                          prefixIcon: const Icon(Icons.qr_code_scanner, color: AppConstants.primary),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.keyboard_return, color: AppConstants.primary),
                            onPressed: () => _handleBarcodeScan(_barcodeCtrl.text),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onSubmitted: _handleBarcodeScan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _handleBarcodeScan(_barcodeCtrl.text),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Compter"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Badges KPI Session
                Row(
                  children: [
                    _buildKpiPill(
                      label: "Articles uniques",
                      value: _countedItems.length.toString(),
                      color: const Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 8),
                    _buildKpiPill(
                      label: "Total scanné",
                      value: "$_totalScannedUnits unités",
                      color: const Color(0xFF059669),
                    ),
                    const SizedBox(width: 8),
                    _buildKpiPill(
                      label: "Écarts détectés",
                      value: "$_discrepanciesCount",
                      color: _discrepanciesCount > 0 ? Colors.orange.shade800 : Colors.grey.shade600,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Tableau des Articles Scannés
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          "Prêt pour le comptage",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Scannez vos articles avec la douchette Bluetooth.\nChaque scan incrémentera le compteur.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final item = records[index];
                      final variance = item.variance;

                      Color varianceColor;
                      String varianceText;
                      if (variance > 0) {
                        varianceColor = const Color(0xFF059669);
                        varianceText = "+$variance (Surplus)";
                      } else if (variance < 0) {
                        varianceColor = Colors.red.shade700;
                        varianceText = "$variance (Déficit)";
                      } else {
                        varianceColor = Colors.grey.shade600;
                        varianceText = "Conforme";
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "SKU: ${item.product.sku} | Théorique: ${item.product.quantity} unités",
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: varianceColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Écart: $varianceText",
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: varianceColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Contrôles de quantité (+ / -)
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        if (item.countedQuantity > 1) {
                                          item.countedQuantity -= 1;
                                        } else {
                                          _countedItems.remove(item.product.id);
                                        }
                                      });
                                    },
                                  ),
                                  Text(
                                    "${item.countedQuantity}",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: AppConstants.primary),
                                    onPressed: () {
                                      setState(() {
                                        item.countedQuantity += 1;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 3. Barre d'action inférieure
          if (records.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _countedItems.clear()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: const Text("Effacer"),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitReconciliation,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(_isSubmitting ? "Ajustement..." : "Appliquer & Réconcilier"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiPill({required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
