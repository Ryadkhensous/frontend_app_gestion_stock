import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../providers/stock_provider.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import 'widgets/document_form_dialog.dart';
import 'widgets/barcode_label_dialog.dart';
import 'widgets/barcode_scanner_dialog.dart';
import 'widgets/scanner_status_badge.dart';
import '../utils/permission_utils.dart';

class ProductsView extends StatelessWidget {
  const ProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final products = stockProvider.products;
    final categories = stockProvider.categories;
    final currencyFormatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);
    final lowStockCount = stockProvider.stats?.lowStockAlertsCount ?? products.where((p) => p.isLowStock).length;

    return Scaffold(
      backgroundColor: AppConstants.background,
      body: Column(
        children: [
          // Barre de recherche et filtres supérieurs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        "Catalogue Produits",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const ScannerStatusBadge(),
                  ],
                ),
                const SizedBox(height: 10),                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                        ),
                        child: TextField(
                          onChanged: (val) => stockProvider.setSearchQuery(val),
                          decoration: InputDecoration(
                            hintText: "Rechercher par nom ou code SKU...",
                            hintStyle: const TextStyle(fontSize: 13, color: AppConstants.textSecondary),
                            prefixIcon: const Icon(Icons.search, size: 20, color: AppConstants.textSecondary),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppConstants.primary),
                              tooltip: "Scanner / Réception Code-barres",
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const BarcodeScannerDialog(),
                                );
                              },
                            ),
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LowStockFilterButton(
                      isSelected: stockProvider.showOnlyLowStock,
                      count: lowStockCount,
                      onTap: () => stockProvider.toggleLowStockFilter(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Chips des Catégories texturés
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _CategoryFilterChip(
                        label: "Toutes",
                        isSelected: stockProvider.selectedCategoryId == null,
                        onTap: () => stockProvider.setSelectedCategory(null),
                      ),
                      ...categories.map((c) => _CategoryFilterChip(
                            label: c.name,
                            isSelected: stockProvider.selectedCategoryId == c.id,
                            onTap: () => stockProvider.setSelectedCategory(c.id),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste des produits
          Expanded(
            child: stockProvider.isLoading && products.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppConstants.primary))
                : products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              "Aucun produit trouvé.",
                              style: TextStyle(color: AppConstants.textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => stockProvider.loadProducts(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final p = products[index];
                            return _buildProductCard(context, p, currencyFormatter, stockProvider);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_new_product',
        backgroundColor: AppConstants.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nouveau Produit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showProductDialog(context, stockProvider, null),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product p,
    NumberFormat currency,
    StockProvider provider,
  ) {
    Color stockColor = p.quantity <= 0
        ? Colors.red
        : (p.isLowStock ? Colors.orange : const Color(0xFF10B981));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showProductDetailsModal(context, p, currency, provider),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image miniature du produit
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFFF1F5F9),
                    child: p.imageUrl != null && p.imageUrl!.trim().isNotEmpty
                        ? Image.network(
                            Product.resolveUrl(p.imageUrl, provider.currentApiUrl)!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.inventory_2_outlined, color: AppConstants.primary, size: 22),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.inventory_2_outlined, color: AppConstants.primary, size: 22),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppConstants.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Réf / SKU: ${p.sku}",
                        style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Badge de quantité
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: stockColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_rounded, color: stockColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${p.quantity} en stock",
                        style: TextStyle(color: stockColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p.description != null && p.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                p.description!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currency.format(p.price),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.costPrice > 0)
                        Text(
                          "Achat: ${currency.format(p.costPrice)}",
                          style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF0D9488)),
                      tooltip: "Créer un Bon pour ce produit",
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => DocumentFormDialog(
                            initialDocType: 'DELIVERY',
                            initialDirection: 'OUTGOING',
                            initialProduct: p,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 20, color: Color(0xFF334155)),
                      tooltip: "Imprimer Étiquette Code-Barres",
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => BarcodeLabelDialog(product: p),
                        );
                      },
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppConstants.primary),
                      tooltip: "Modifier le produit",
                      onPressed: () => _showProductDialog(context, provider, p),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      tooltip: "Supprimer le produit",
                      onPressed: () => _confirmDelete(context, provider, p),
                    ),
                  ],
                )
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showProductDetailsModal(BuildContext context, Product p, NumberFormat currency, StockProvider provider) {
    final margin = p.price - p.costPrice;
    final marginPct = p.costPrice > 0 ? ((margin / p.costPrice) * 100) : 0.0;
    final stockValue = p.quantity * p.price;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Text("SKU / Réf : ${p.sku}", style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary)),
            if (p.imageUrl != null && p.imageUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      Product.resolveUrl(p.imageUrl, provider.currentApiUrl)!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Quantité en Stock :"),
                      Text("${p.quantity} unités", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Valeur du Stock :"),
                      Text(currency.format(stockValue), style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Prix de vente :"),
                      Text(currency.format(p.price), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Marge brute estimée :"),
                      Text(
                        "${currency.format(margin)} (${marginPct.toStringAsFixed(1)}%)",
                        style: TextStyle(fontWeight: FontWeight.bold, color: margin >= 0 ? Colors.green : Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text("Créer Bon"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (dCtx) => DocumentFormDialog(
                          initialDocType: 'DELIVERY',
                          initialDirection: 'OUTGOING',
                          initialProduct: p,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text("Modifier"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showProductDialog(context, provider, p);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code_2_rounded, size: 22, color: Color(0xFF1E293B)),
                  tooltip: "Imprimer Étiquette Code-Barres",
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (dCtx) => BarcodeLabelDialog(product: p),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, StockProvider provider, Product p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer le produit ?"),
        content: Text("Êtes-vous sûr de vouloir supprimer '${p.name}' ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await provider.deleteProduct(p.id);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.errorMessage ?? "Erreur de suppression")),
                );
              }
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showProductDialog(BuildContext context, StockProvider provider, Product? product) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: product?.name ?? "");
    final skuCtrl = TextEditingController(text: product?.sku ?? "");
    final imageCtrl = TextEditingController(text: product?.imageUrl ?? "");
    final descCtrl = TextEditingController(text: product?.description ?? "");
    final priceCtrl = TextEditingController(text: product != null ? (product.price == product.price.roundToDouble() ? product.price.toInt().toString() : product.price.toString()) : "");
    final costCtrl = TextEditingController(text: product != null ? (product.costPrice == product.costPrice.roundToDouble() ? product.costPrice.toInt().toString() : product.costPrice.toString()) : "");
    final qtyCtrl = TextEditingController(text: product?.quantity.toString() ?? "0");
    final alertCtrl = TextEditingController(text: product?.minStockAlert.toString() ?? "5");
    int? selectedCategory = product?.categoryId;

    // Pré-remplir automatiquement un SKU unique si nouveau produit
    if (product == null && skuCtrl.text.isEmpty) {
      final now = DateTime.now();
      final datePart = DateFormat('yyMMdd').format(now);
      final rand = (Random().nextInt(9000) + 1000).toString();
      skuCtrl.text = "REF-$datePart-$rand";
    }

    bool isSaving = false;
    String? formError;
    Uint8List? localImageBytes;
    String? localImageName;
    bool isUploadingImage = false;
    String? imageUploadError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        product == null ? Icons.add_box_rounded : Icons.edit_note_rounded,
                        color: AppConstants.primary,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        product == null ? "Ajouter un Produit" : "Modifier le Produit",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nom du produit *",
                      hintText: "Ex: Écran Dell 24 pouces",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Le nom du produit est requis";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: skuCtrl,
                    decoration: InputDecoration(
                      labelText: "Référence SKU / Code-barres *",
                      hintText: "Scannez ou générez automatiquement...",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.qr_code_2_rounded),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (skuCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                tooltip: "Effacer",
                                onPressed: () {
                                  skuCtrl.clear();
                                  setSheetState(() {});
                                },
                              ),
                            ElevatedButton.icon(
                              onPressed: () {
                                final now = DateTime.now();
                                final datePart = DateFormat('yyMMdd').format(now);
                                final rand = (Random().nextInt(9000) + 1000).toString();
                                skuCtrl.text = "REF-$datePart-$rand";
                                HapticFeedback.lightImpact();
                                setSheetState(() {});
                              },
                              icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                              label: const Text("Générer", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "La référence SKU est requise";
                      }
                      return null;
                    },
                    onChanged: (val) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      value: selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Catégorie",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text("Sans catégorie")),
                        ...provider.categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (val) => setSheetState(() => selectedCategory = val),
                    ),
                    const SizedBox(height: 14),

                    // SECTION IMAGE DU PRODUIT
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.image_outlined, size: 18, color: AppConstants.primary),
                                  SizedBox(width: 8),
                                  Text(
                                    "Image du produit",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              if (imageCtrl.text.trim().isNotEmpty || localImageBytes != null)
                                TextButton.icon(
                                  onPressed: () {
                                    imageCtrl.clear();
                                    localImageBytes = null;
                                    localImageName = null;
                                    imageUploadError = null;
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                  label: const Text("Retirer", style: TextStyle(fontSize: 12, color: Colors.red)),
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Aperçu en direct (Image locale sélectionnée OU Image distante / serveur)
                          if (localImageBytes != null || imageCtrl.text.trim().isNotEmpty)
                            Center(
                              child: Container(
                                height: 120,
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                  color: Colors.white,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: localImageBytes != null
                                      ? Image.memory(
                                          localImageBytes!,
                                          fit: BoxFit.contain,
                                        )
                                      : Image.network(
                                          Product.resolveUrl(imageCtrl.text.trim(), provider.currentApiUrl)!,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) => Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image_outlined, color: Colors.red.shade300, size: 32),
                                              const SizedBox(height: 4),
                                              const Text(
                                                "Lien d'image inaccessible",
                                                style: TextStyle(fontSize: 11, color: Colors.red),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ),

                          // Badge d'info si fichier uploadé
                          if (localImageName != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Fichier importé : $localImageName",
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Bouton d'upload principal depuis l'appareil
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isUploadingImage
                                  ? null
                                  : () async {
                                      try {
                                        setSheetState(() {
                                          imageUploadError = null;
                                        });

                                        // Demande préalable des permissions d'accès aux fichiers / photos
                                        final hasPermission = await PermissionUtils.requestFileStoragePermission(context);
                                        if (!hasPermission) return;

                                        final result = await FilePicker.pickFiles(
                                          type: FileType.image,
                                          withData: true,
                                        );
                                        if (result != null && result.files.isNotEmpty) {
                                          final picked = result.files.first;
                                          List<int>? bytes = picked.bytes;
                                          if (bytes == null && picked.path != null) {
                                            try {
                                              bytes = await File(picked.path!).readAsBytes();
                                            } catch (_) {}
                                          }

                                          if (bytes != null && bytes.isNotEmpty) {
                                            final uploadBytes = bytes;
                                            setSheetState(() {
                                              localImageBytes = Uint8List.fromList(uploadBytes);
                                              localImageName = picked.name;
                                              isUploadingImage = true;
                                            });

                                            final uploadedUrl = await provider.uploadProductImage(uploadBytes, picked.name);
                                            if (uploadedUrl != null) {
                                              imageCtrl.text = uploadedUrl;
                                              setSheetState(() {
                                                isUploadingImage = false;
                                              });
                                              HapticFeedback.lightImpact();
                                            } else {
                                              setSheetState(() {
                                                isUploadingImage = false;
                                                imageUploadError = provider.errorMessage ?? "Échec de l'upload de l'image.";
                                              });
                                            }
                                          }
                                        }
                                      } catch (e) {
                                        setSheetState(() {
                                          isUploadingImage = false;
                                          imageUploadError = "Erreur lors de la sélection : $e";
                                        });
                                      }
                                    },
                              icon: isUploadingImage
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.file_upload_outlined, size: 20),
                              label: Text(
                                isUploadingImage
                                    ? "Téléversement en cours..."
                                    : (localImageBytes != null || imageCtrl.text.isNotEmpty
                                        ? "Changer l'image depuis l'appareil"
                                        : "Importer une image depuis l'appareil"),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),

                          if (imageUploadError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              imageUploadError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Champ URL de l'image (Option manuelle)
                          TextFormField(
                            controller: imageCtrl,
                            decoration: InputDecoration(
                              labelText: "Ou lien direct d'image (URL web)",
                              hintText: "https://exemple.com/image.jpg",
                              isDense: true,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.link_rounded, size: 20),
                              suffixIcon: imageCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        imageCtrl.clear();
                                        localImageBytes = null;
                                        localImageName = null;
                                        setSheetState(() {});
                                      },
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                                      tooltip: "Coller le lien",
                                      onPressed: () async {
                                        final clipData = await Clipboard.getData(Clipboard.kTextPlain);
                                        if (clipData?.text != null && clipData!.text!.isNotEmpty) {
                                          imageCtrl.text = clipData.text!.trim();
                                          localImageBytes = null;
                                          localImageName = null;
                                          setSheetState(() {});
                                        }
                                      },
                                    ),
                            ),
                            onChanged: (_) {
                              localImageBytes = null;
                              localImageName = null;
                              setSheetState(() {});
                            },
                          ),
                          const SizedBox(height: 8),

                          // Suggestions rapides d'images
                          const Text(
                            "Suggestions rapides :",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildPresetChip(
                                  "Laptop",
                                  Icons.laptop_mac_rounded,
                                  "https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=500&auto=format&fit=crop&q=60",
                                  imageCtrl,
                                  setSheetState,
                                  onSelect: () {
                                    localImageBytes = null;
                                    localImageName = null;
                                  },
                                ),
                                _buildPresetChip(
                                  "Écran",
                                  Icons.desktop_windows_rounded,
                                  "https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=500&auto=format&fit=crop&q=60",
                                  imageCtrl,
                                  setSheetState,
                                  onSelect: () {
                                    localImageBytes = null;
                                    localImageName = null;
                                  },
                                ),
                                _buildPresetChip(
                                  "Souris",
                                  Icons.mouse_rounded,
                                  "https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=500&auto=format&fit=crop&q=60",
                                  imageCtrl,
                                  setSheetState,
                                  onSelect: () {
                                    localImageBytes = null;
                                    localImageName = null;
                                  },
                                ),
                                _buildPresetChip(
                                  "Clavier",
                                  Icons.keyboard_rounded,
                                  "https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=500&auto=format&fit=crop&q=60",
                                  imageCtrl,
                                  setSheetState,
                                  onSelect: () {
                                    localImageBytes = null;
                                    localImageName = null;
                                  },
                                ),
                                _buildPresetChip(
                                  "Casque",
                                  Icons.headphones_rounded,
                                  "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&auto=format&fit=crop&q=60",
                                  imageCtrl,
                                  setSheetState,
                                  onSelect: () {
                                    localImageBytes = null;
                                    localImageName = null;
                                  },
                                ),
                                _buildPresetChip(
                                  "Smartphone",
                                  Icons.phone_android_rounded,
                                  "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500&auto=format&fit=crop&q=60",
                                  imageCtrl,
                                  setSheetState,
                                  onSelect: () {
                                    localImageBytes = null;
                                    localImageName = null;
                                  },
                                ),
                                _buildPresetChip(
                                  "Imprimante",
                                  Icons.print_rounded,
                                  "https://images.unsplash.com/photo-1612815154858-60aa4c59eaa6?w=500&auto=format&fit=crop&q=60",
                                  imageCtrl,
                                  setSheetState,
                                  onSelect: () {
                                    localImageBytes = null;
                                    localImageName = null;
                                  },
                                ),
                                _buildPresetChip(
                                  "Composant",
                                  Icons.memory_rounded,
                                  "https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?w=500&auto=format&fit=crop&q=60",
                                  imageCtrl,
                                  setSheetState,
                                  onSelect: () {
                                    localImageBytes = null;
                                    localImageName = null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: "Prix Vente (DA) *",
                            hintText: "0.00",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.sell_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return "Prix requis";
                            }
                            final p = double.tryParse(v.trim().replaceAll(',', '.'));
                            if (p == null || p < 0) {
                              return "Invalide (>= 0)";
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: "Coût Achat (DA)",
                            hintText: "0.00",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.shopping_bag_outlined),
                          ),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final c = double.tryParse(v.trim().replaceAll(',', '.'));
                              if (c == null || c < 0) return "Invalide (>= 0)";
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Quantité en stock",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.layers_outlined),
                          ),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final q = int.tryParse(v.trim());
                              if (q == null || q < 0) return "Invalide (>= 0)";
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: alertCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Seuil d'alerte",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notification_important_outlined),
                          ),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final a = int.tryParse(v.trim());
                              if (a == null || a < 0) return "Invalide (>= 0)";
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (formError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              formError!,
                              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSaving ? Colors.grey.shade400 : AppConstants.primary,
                        foregroundColor: Colors.white,
                        elevation: isSaving ? 0 : 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setSheetState(() => formError = null);
                              if (!formKey.currentState!.validate()) {
                                HapticFeedback.heavyImpact();
                                return;
                              }

                              setSheetState(() => isSaving = true);

                              final priceVal = double.tryParse(priceCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
                              final costVal = double.tryParse(costCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
                              final qtyVal = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                              final alertVal = int.tryParse(alertCtrl.text.trim()) ?? 5;

                              final data = {
                                "name": nameCtrl.text.trim(),
                                "sku": skuCtrl.text.trim(),
                                "description": descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                                "price": priceVal,
                                "cost_price": costVal,
                                "quantity": qtyVal,
                                "min_stock_alert": alertVal,
                                "category_id": selectedCategory,
                                "image_url": imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : null,
                              };

                              bool ok;
                              if (product == null) {
                                ok = await provider.addProduct(data);
                              } else {
                                ok = await provider.updateProduct(product.id, data);
                              }

                              if (!ctx.mounted) return;

                              if (ok) {
                                Navigator.pop(ctx);
                                HapticFeedback.lightImpact();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.white),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              product == null
                                                  ? "Produit '${data['name']}' enregistré avec succès !"
                                                  : "Produit mis à jour avec succès !",
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppConstants.success,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } else {
                                setSheetState(() {
                                  isSaving = false;
                                  formError = provider.errorMessage ?? "Une erreur inattendue est survenue.";
                                });
                                HapticFeedback.heavyImpact();
                              }
                            },
                      child: isSaving
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Enregistrement...",
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(product == null ? Icons.add_circle_outline_rounded : Icons.save_rounded, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  product == null ? "Enregistrer le Produit" : "Mettre à jour",
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    IconData icon,
    String url,
    TextEditingController controller,
    StateSetter setSheetState, {
    VoidCallback? onSelect,
  }) {
    final isSelected = controller.text == url;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : AppConstants.primary),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isSelected ? AppConstants.primary : Colors.white,
        side: BorderSide(color: isSelected ? AppConstants.primary : const Color(0xFFCBD5E1)),
        onPressed: () {
          controller.text = url;
          onSelect?.call();
          HapticFeedback.lightImpact();
          setSheetState(() {});
        },
      ),
    );
  }
}

class _LowStockFilterButton extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final int count;

  const _LowStockFilterButton({
    required this.isSelected,
    required this.onTap,
    this.count = 0,
  });

  @override
  State<_LowStockFilterButton> createState() => _LowStockFilterButtonState();
}

class _LowStockFilterButtonState extends State<_LowStockFilterButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSel = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : (_isHovered ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9.5),
            decoration: BoxDecoration(
              gradient: isSel
                  ? const LinearGradient(
                      colors: [Color(0xFFF43F5E), Color(0xFFE11D48), Color(0xFFBE123C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: _isHovered
                          ? const [Color(0xFFFFF1F2), Color(0xFFFFE4E6)]
                          : const [Colors.white, Color(0xFFFFF5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel
                    ? Colors.white.withValues(alpha: 0.35)
                    : (_isHovered ? const Color(0xFFFDA4AF) : const Color(0xFFFECDD3)),
                width: 1.1,
              ),
              boxShadow: [
                if (isSel) ...[
                  BoxShadow(
                    color: const Color(0xFFE11D48).withValues(alpha: _isHovered ? 0.45 : 0.30),
                    blurRadius: _isHovered ? 12 : 8,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ] else ...[
                  BoxShadow(
                    color: const Color(0xFFE11D48).withValues(alpha: _isHovered ? 0.12 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4.5),
                  decoration: BoxDecoration(
                    color: isSel
                        ? Colors.white.withValues(alpha: 0.22)
                        : const Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel
                          ? Colors.white.withValues(alpha: 0.4)
                          : const Color(0xFFFECDD3),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: isSel ? Colors.white : const Color(0xFFE11D48),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Stock Bas",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isSel ? Colors.white : const Color(0xFFBE123C),
                    letterSpacing: 0.2,
                  ),
                ),
                if (widget.count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isSel
                          ? Colors.white.withValues(alpha: 0.25)
                          : const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${widget.count}",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryFilterChip> createState() => _CategoryFilterChipState();
}

class _CategoryFilterChipState extends State<_CategoryFilterChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSel = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _isHovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(right: 7),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              gradient: isSel
                  ? const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: _isHovered
                          ? const [Color(0xFFF1F5F9), Color(0xFFE2E8F0)]
                          : const [Colors.white, Color(0xFFF8FAFC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSel
                    ? Colors.white.withValues(alpha: 0.3)
                    : (_isHovered ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
                width: 1.0,
              ),
              boxShadow: [
                if (isSel)
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: _isHovered ? 0.40 : 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2.5),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isHovered ? 0.05 : 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
              ],
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                color: isSel ? Colors.white : const Color(0xFF475569),
                letterSpacing: 0.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
