import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/stock_provider.dart';
import '../models/stock_movement.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import 'widgets/barcode_scanner_dialog.dart';

class MovementsView extends StatefulWidget {
  const MovementsView({super.key});

  @override
  State<MovementsView> createState() => _MovementsViewState();
}

class _MovementsViewState extends State<MovementsView> {
  String? _filterType;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StockProvider>();
    final allMovements = provider.movements;
    final filtered = _filterType == null
        ? allMovements
        : allMovements.where((m) => m.movementType == _filterType).toList();

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "Mouvements de Stock",
          style: TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppConstants.primary),
            tooltip: "Scanner / Réception Code-barres",
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const BarcodeScannerDialog(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filtres par type (Tous, Entrée, Sortie, Transfert)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip("Tous", null, icon: Icons.filter_list_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip("Entrées", "IN", color: const Color(0xFF10B981), icon: Icons.arrow_downward_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip("Sorties", "OUT", color: const Color(0xFFF59E0B), icon: Icons.arrow_upward_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip("Transferts", "TRANSFER", color: const Color(0xFF3B82F6), icon: Icons.swap_horiz_rounded),
                ],
              ),
            ),
          ),

          // Liste des mouvements
          Expanded(
            child: provider.isLoading && allMovements.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppConstants.primary))
                : filtered.isEmpty
                    ? const Center(
                        child: Text("Aucun mouvement enregistré.", style: TextStyle(color: AppConstants.textSecondary)),
                      )
                    : RefreshIndicator(
                        onRefresh: () => provider.loadMovements(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final m = filtered[index];
                            return _buildMovementCard(m);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_new_movement',
        backgroundColor: AppConstants.primary,
        icon: const Icon(Icons.sync_alt, color: Colors.white),
        label: const Text("Nouveau Mouvement", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddMovementDialog(context, provider),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? type, {Color? color, IconData? icon}) {
    final isSelected = _filterType == type;
    final primaryColor = color ?? AppConstants.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _filterType = type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
              width: 1.1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13.5,
                  color: isSelected ? Colors.white : primaryColor,
                ),
                const SizedBox(width: 5.5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovementCard(StockMovement m) {
    final isIn = m.movementType == "IN";
    final isTransfer = m.movementType == "TRANSFER";
    final dateFormatter = DateFormat('dd/MM/yyyy à HH:mm');

    Color typeColor = isIn ? Colors.green : (isTransfer ? Colors.blue : Colors.orange);
    String typeLabel = isIn ? "ENTRÉE EN STOCK" : (isTransfer ? "TRANSFERT MAGASIN" : "SORTIE DE STOCK");
    IconData typeIcon = isIn ? Icons.arrow_downward : (isTransfer ? Icons.swap_horiz : Icons.arrow_upward);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: typeColor.withValues(alpha: 0.15),
                        child: Icon(typeIcon, color: typeColor, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          typeLabel,
                          style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateFormatter.format(m.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.productName ?? "Produit inconnu",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppConstants.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (m.pointOfSaleName != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.storefront, size: 13, color: AppConstants.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Point de vente : ${m.pointOfSaleName}",
                                style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (m.reference != null && m.reference!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          "Réf : ${m.reference}",
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    "${isIn ? '+' : '-'}${m.quantity}",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: typeColor),
                  ),
                ),
              ],
            ),
            if (m.note != null && m.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Note : ${m.note}",
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddMovementDialog(BuildContext context, StockProvider provider) {
    int? selectedProductId = provider.products.isNotEmpty ? provider.products.first.id : null;
    int? selectedPosId;
    String movementType = "IN";
    final qtyCtrl = TextEditingController(text: "1");
    final refCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Product? currentProduct;
          try {
            currentProduct = provider.products.firstWhere((p) => p.id == selectedProductId);
          } catch (_) {}

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Enregistrer un Mouvement", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Sélection du type de mouvement
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text("Entrée (+)", style: TextStyle(fontSize: 12))),
                          selected: movementType == "IN",
                          selectedColor: Colors.green,
                          labelStyle: TextStyle(color: movementType == "IN" ? Colors.white : Colors.black),
                          onSelected: (_) => setSheetState(() => movementType = "IN"),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text("Sortie (-)", style: TextStyle(fontSize: 12))),
                          selected: movementType == "OUT",
                          selectedColor: Colors.orange,
                          labelStyle: TextStyle(color: movementType == "OUT" ? Colors.white : Colors.black),
                          onSelected: (_) => setSheetState(() => movementType = "OUT"),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text("Transfert", style: TextStyle(fontSize: 12))),
                          selected: movementType == "TRANSFER",
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(color: movementType == "TRANSFER" ? Colors.white : Colors.black),
                          onSelected: (_) => setSheetState(() => movementType = "TRANSFER"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sélection du produit
                  DropdownButtonFormField<int>(
                    value: selectedProductId,
                    decoration: const InputDecoration(labelText: "Produit concerné *", border: OutlineInputBorder()),
                    items: provider.products.map((p) {
                      return DropdownMenuItem<int>(
                        value: p.id,
                        child: Text("${p.name} (Stock: ${p.quantity})", overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setSheetState(() => selectedProductId = val),
                  ),
                  const SizedBox(height: 12),

                  // Si transfert ou point de vente associé
                  if (movementType == "TRANSFER" || movementType == "OUT") ...[
                    DropdownButtonFormField<int?>(
                      value: selectedPosId,
                      decoration: const InputDecoration(labelText: "Point de Vente destinataire", border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text("Aucun (Client direct / Général)")),
                        ...provider.pointsOfSale.map((pos) => DropdownMenuItem<int?>(value: pos.id, child: Text(pos.name))),
                      ],
                      onChanged: (val) => setSheetState(() => selectedPosId = val),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Quantité
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Quantité à déplacer *",
                      border: const OutlineInputBorder(),
                      helperText: currentProduct != null && movementType != "IN"
                          ? "Stock disponible actuel : ${currentProduct.quantity}"
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: refCtrl,
                    decoration: const InputDecoration(labelText: "Référence (N° Bon / Facture)", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: "Note / Observation", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        if (selectedProductId == null) return;
                        final qty = int.tryParse(qtyCtrl.text);
                        if (qty == null || qty <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text("Veuillez saisir une quantité valide (> 0).")),
                          );
                          return;
                        }

                        if (movementType != "IN" && currentProduct != null && qty > currentProduct.quantity) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text("Stock insuffisant ! Disponible : ${currentProduct.quantity}")),
                          );
                          return;
                        }

                        final payload = {
                          "product_id": selectedProductId,
                          "point_of_sale_id": selectedPosId,
                          "movement_type": movementType,
                          "quantity": qty,
                          "reference": refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                          "note": noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                        };

                        final ok = await provider.addStockMovement(payload);
                        if (ok && ctx.mounted) {
                          Navigator.pop(ctx);
                        } else if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(provider.errorMessage ?? "Erreur")),
                          );
                        }
                      },
                      child: const Text("Valider le Mouvement", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
