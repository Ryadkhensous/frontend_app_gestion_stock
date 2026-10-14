import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/stock_provider.dart';
import '../../utils/constants.dart';
import '../../models/commercial_document.dart';
import 'pdf_preview_dialog.dart';

class ReorderSuggestionsDialog extends StatefulWidget {
  const ReorderSuggestionsDialog({super.key});

  @override
  State<ReorderSuggestionsDialog> createState() => _ReorderSuggestionsDialogState();
}

class _ReorderSuggestionsDialogState extends State<ReorderSuggestionsDialog> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  int _totalShortages = 0;
  double _estimatedBudget = 0.0;
  List<Map<String, dynamic>> _items = [];

  int? _selectedPosId;
  final TextEditingController _partnerController = TextEditingController(text: "Fournisseur Principal");

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  @override
  void dispose() {
    _partnerController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = context.read<StockProvider>().api;
      final res = await api.getReorderSuggestions();
      if (!mounted) return;
      if (res.containsKey('suggestions')) {
        final List raw = res['suggestions'] ?? [];
        _items = raw.map((e) => Map<String, dynamic>.from(e)).toList();
        _totalShortages = (res['total_products_in_alert'] ?? res['total_shortages'] as num?)?.toInt() ?? _items.length;
        _estimatedBudget = (res['total_estimated_budget'] ?? res['estimated_reorder_budget'] as num?)?.toDouble() ?? 0.0;
        
        final posList = context.read<StockProvider>().pointsOfSale;
        if (posList.isNotEmpty && _selectedPosId == null) {
          _selectedPosId = posList.first.id;
        }
      } else {
        _errorMessage = res['detail'] ?? "Impossible de charger les suggestions";
      }
    } catch (e) {
      if (mounted) {
        _errorMessage = "Erreur: $e";
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _recalculateBudget() {
    double total = 0.0;
    for (var it in _items) {
      final qty = ((it['suggested_order_quantity'] ?? it['suggested_order_qty']) as num?)?.toInt() ?? 0;
      final cost = ((it['unit_cost_price'] ?? it['unit_cost']) as num?)?.toDouble() ?? 0.0;
      total += qty * cost;
    }
    setState(() {
      _estimatedBudget = total;
    });
  }

  Future<void> _submitAutoOrder() async {
    if (_items.isEmpty) return;

    final validItems = _items
        .where((it) => (((it['suggested_order_quantity'] ?? it['suggested_order_qty']) as num?)?.toInt() ?? 0) > 0)
        .map((it) => {
              'product_id': it['product_id'],
              'quantity': it['suggested_order_quantity'] ?? it['suggested_order_qty'],
              'unit_price': it['unit_cost_price'] ?? it['unit_cost'],
            })
        .toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Toutes les quantités sont à zéro."), backgroundColor: AppConstants.accent),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = context.read<StockProvider>().api;
      final payload = {
        if (_selectedPosId != null) "point_of_sale_id": _selectedPosId,
        "partner_name": _partnerController.text.trim().isEmpty ? "Fournisseur Principal" : _partnerController.text.trim(),
        "notes": "Généré automatiquement par l'assistant de réapprovisionnement",
        "items": validItems,
      };

      final CommercialDocument newDoc = await api.generateAutoOrder(payload);

      if (!mounted) return;

      // Rafraîchir l'application
      await context.read<StockProvider>().loadAll();

      if (mounted) {
        Navigator.pop(context); // Fermer dialogue
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bon de commande ${newDoc.referenceNumber} généré avec succès !"),
            backgroundColor: AppConstants.success,
          ),
        );

        // Proposer d'afficher le PDF immédiatement
        showDialog(
          context: context,
          builder: (ctx) => PdfPreviewDialog(document: newDoc),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: AppConstants.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);
    final posList = context.watch<StockProvider>().pointsOfSale;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 820,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFFF59E0B), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Réapprovisionnement Intelligent",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Détection des ruptures de stock & Bon de commande 1-Clic",
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Corps
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppConstants.primary))
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 40, color: Colors.red),
                              const SizedBox(height: 10),
                              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _fetchSuggestions, child: const Text("Réessayer")),
                            ],
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle_outline_rounded,
                                        size: 48, color: Color(0xFF10B981)),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Aucune rupture de stock détectée !",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    "Tous vos articles sont au-dessus de leur seuil minimal de sécurité.",
                                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Résumé alertes & budget
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 22),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            "$_totalShortages article(s) ont franchi leur seuil minimal. "
                                            "Le volume de réassort suggéré permet d'atteindre le double du seuil de sécurité.",
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text(
                                              "Budget Estimé",
                                              style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                                            ),
                                            Text(
                                              currency.format(_estimatedBudget),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFB45309),
                                              ),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Paramètres Commande (Fournisseur & POS)
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: isMobile
                                        ? Column(
                                            children: [
                                              _buildSupplierField(),
                                              const SizedBox(height: 12),
                                              _buildPosDropdown(posList),
                                            ],
                                          )
                                        : Row(
                                            children: [
                                              Expanded(child: _buildSupplierField()),
                                              const SizedBox(width: 16),
                                              Expanded(child: _buildPosDropdown(posList)),
                                            ],
                                          ),
                                  ),
                                  const SizedBox(height: 16),

                                  const Text(
                                    "Articles à réapprovisionner :",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 8),

                                  // Liste des suggestions
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _items.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (context, index) {
                                      final item = _items[index];
                                      final currentQty = item['current_stock'] ?? item['current_quantity'] ?? 0;
                                      final threshold = item['min_stock_alert'] ?? item['min_threshold'] ?? 0;
                                      final suggested = (item['suggested_order_quantity'] ?? item['suggested_order_qty'] ?? 0) as int;
                                      final cost = ((item['unit_cost_price'] ?? item['unit_cost']) as num?)?.toDouble() ?? 0.0;
                                      final sku = item['product_sku'] ?? item['sku'];
                                      final lineTotal = suggested * cost;

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Row(
                                          children: [
                                            // Badges et nom
                                            Expanded(
                                              flex: 4,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['product_name'] ?? "Produit #${item['product_id']}",
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                  if (sku != null && sku.toString().isNotEmpty)
                                                    Text(
                                                      "SKU: $sku",
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                    ),
                                                  const SizedBox(height: 3),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFEE2E2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      "Stock : $currentQty (Seuil: $threshold)",
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFFDC2626),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Contrôle Quantité à commander
                                            Expanded(
                                              flex: 3,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                                    onPressed: suggested > 0
                                                        ? () {
                                                            setState(() {
                                                              item['suggested_order_quantity'] = suggested - 1;
                                                              item['suggested_order_qty'] = suggested - 1;
                                                              _recalculateBudget();
                                                            });
                                                          }
                                                        : null,
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      "$suggested",
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                                    onPressed: () {
                                                      setState(() {
                                                        item['suggested_order_quantity'] = suggested + 1;
                                                        item['suggested_order_qty'] = suggested + 1;
                                                        _recalculateBudget();
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Coût total ligne
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    currency.format(lineTotal),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  Text(
                                                    "@ ${currency.format(cost)}/u",
                                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Annuler"),
                  ),
                  if (_items.isNotEmpty && !_isLoading)
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitAutoOrder,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(_isSubmitting ? "Génération..." : "Créer le Bon de Commande (1-Clic)"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Fournisseur cible",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _partnerController,
          decoration: InputDecoration(
            isDense: true,
            hintText: "Ex: Fournisseur Central",
            prefixIcon: const Icon(Icons.business_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPosDropdown(List<dynamic> posList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Point de vente destinataire",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<int?>(
          value: _selectedPosId,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: posList
              .map((pos) => DropdownMenuItem<int?>(
                    value: pos.id,
                    child: Text(
                      pos.name,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedPosId = v),
        ),
      ],
    );
  }
}
