import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/stock_provider.dart';
import '../models/commercial_document.dart';
import '../utils/constants.dart';
import 'widgets/document_preview_dialog.dart';
import 'widgets/document_form_dialog.dart';
import 'widgets/pdf_preview_dialog.dart';
import 'widgets/document_edit_confirm_dialog.dart';

class DocumentsView extends StatefulWidget {
  const DocumentsView({super.key});

  @override
  State<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<DocumentsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = "";
  String? _statusFilter;

  final TextEditingController _searchController = TextEditingController();

  static final _currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 2, locale: 'fr_FR');
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StockProvider>();
      if (provider.documents.isEmpty) {
        provider.loadDocuments();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateDialog(String docType, {String? direction, bool? immediateDelivery}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DocumentFormDialog(
        initialDocType: docType,
        initialDirection: direction,
        initialImmediateDelivery: immediateDelivery,
      ),
    );
  }

  void _openPreviewDialog(CommercialDocument doc) {
    showDialog(
      context: context,
      builder: (ctx) => DocumentPreviewDialog(document: doc),
    );
  }

  Future<void> _handleEditDocument(CommercialDocument doc) async {
    final confirmed = await showDocumentEditConfirmDialog(context, doc);
    if (confirmed == true && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DocumentFormDialog(documentToEdit: doc),
      );
    }
  }

  Future<void> _handleStatusChange(CommercialDocument doc, String newStatus) async {
    final provider = context.read<StockProvider>();
    final success = await provider.updateDocumentStatus(doc.id, newStatus);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Statut du bon ${doc.referenceNumber} mis à jour : $newStatus"),
          backgroundColor: AppConstants.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? "Erreur lors de la mise à jour"),
          backgroundColor: AppConstants.danger,
        ),
      );
    }
  }

  Future<void> _handleConvertToDelivery(CommercialDocument order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Convertir en Bon de Livraison"),
        content: Text(
          "Voulez-vous générer un Bon de Livraison à partir de la commande ${order.referenceNumber} ?\n"
          "Tous les articles et quantités seront reportés (créé en brouillon).",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
            ),
            child: const Text("Générer BL"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<StockProvider>();
    final success = await provider.convertOrderToDelivery(order.id, autoDeliver: false);
    if (!mounted) return;

    if (success) {
      _tabController.animateTo(2); // Bascule automatique vers l'onglet Livraisons
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bon de Livraison généré avec succès !"),
          backgroundColor: AppConstants.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? "Erreur de conversion"),
          backgroundColor: AppConstants.danger,
        ),
      );
    }
  }

  Future<void> _handleConvertAndDeliver(CommercialDocument order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.flash_on_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text("Livrer & Déstocker"),
          ],
        ),
        content: Text(
          "Voulez-vous expédier la commande ${order.referenceNumber} et mettre à jour le stock immédiatement ?\n\n"
          "✓ Bon de Livraison généré automatiquement\n"
          "✓ Déduction physique des articles du stock\n"
          "✓ Traçabilité et mouvement d'audit enregistrés",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Annuler")),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.flash_on_rounded, size: 16),
            label: const Text("Valider & Déstocker"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<StockProvider>();
    final success = await provider.convertOrderToDelivery(order.id, autoDeliver: true);
    if (!mounted) return;

    if (success) {
      _tabController.animateTo(2); // Bascule automatique vers l'onglet Livraisons
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✓ Commande ${order.referenceNumber} livrée et stock déduit avec succès !"),
          backgroundColor: AppConstants.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? "Erreur lors de la livraison"),
          backgroundColor: AppConstants.danger,
        ),
      );
    }
  }

  Future<void> _handleDeleteDocument(CommercialDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer le document"),
        content: Text("Êtes-vous sûr de vouloir supprimer définitivement le bon ${doc.referenceNumber} ?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.danger, foregroundColor: Colors.white),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<StockProvider>();
    final success = await provider.deleteDocument(doc.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Document supprimé."), backgroundColor: AppConstants.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? "Erreur de suppression"), backgroundColor: AppConstants.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final isWide = MediaQuery.of(context).size.width >= 800;

    // Filtrage
    List<CommercialDocument> filterDocs(List<CommercialDocument> list) {
      return list.where((d) {
        if (_statusFilter != null && d.status != _statusFilter) return false;
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesRef = d.referenceNumber.toLowerCase().contains(query);
          final matchesPartner = (d.partnerName ?? "").toLowerCase().contains(query);
          final matchesPos = (d.pointOfSaleName ?? "").toLowerCase().contains(query);
          if (!matchesRef && !matchesPartner && !matchesPos) return false;
        }
        return true;
      }).toList();
    }

    final filteredAll = filterDocs(stockProvider.documents);
    final filteredOrders = filterDocs(stockProvider.orders);
    final filteredDeliveries = filterDocs(stockProvider.deliveries);

    return Scaffold(
      backgroundColor: AppConstants.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => stockProvider.loadDocuments(),
          child: Column(
            children: [
              // Header avec titre et boutons d'action
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Bons & Commandes",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Gestion unifiée des commandes et sorties de stock",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Menu contextuel création rapide optimisé
                    PopupMenuButton<Map<String, dynamic>>(
                      tooltip: "Nouveau Bon",
                      offset: const Offset(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) => _openCreateDialog(
                        val['docType'] as String,
                        direction: val['direction'] as String?,
                        immediateDelivery: val['immediate'] as bool?,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 5),
                            Text(
                              "Nouveau Bon",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: {'docType': 'DELIVERY', 'direction': 'OUTGOING', 'immediate': true},
                          child: Row(
                            children: [
                              Icon(Icons.flash_on_rounded, color: Color(0xFF10B981), size: 20),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Sortie / Vente Directe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text("BL avec déstockage immédiat", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: {'docType': 'ORDER', 'direction': 'OUTGOING', 'immediate': false},
                          child: Row(
                            children: [
                              Icon(Icons.shopping_cart_outlined, color: AppConstants.primary, size: 20),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Bon de Commande", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text("Réservation (sans toucher au stock)", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: {'docType': 'DELIVERY', 'direction': 'INCOMING', 'immediate': true},
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, color: Color(0xFF0D9488), size: 20),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Réception Fournisseur", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text("Entrée physique et ajout au stock", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Cartes statistiques rapides
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    _buildStatMiniCard(
                      title: "Commandes",
                      value: stockProvider.orders.length.toString(),
                      icon: Icons.shopping_bag_rounded,
                      color: AppConstants.primary,
                    ),
                    const SizedBox(width: 8),
                    _buildStatMiniCard(
                      title: "Livraisons",
                      value: stockProvider.deliveries.length.toString(),
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 8),
                    _buildStatMiniCard(
                      title: "En attente",
                      value: stockProvider.deliveries.where((d) => d.status != 'DELIVERED').length.toString(),
                      icon: Icons.pending_actions_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),

              // Onglets Unifiés (Tous / Commandes / Livraisons)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    labelColor: AppConstants.textPrimary,
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    tabs: [
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text("Tous (${stockProvider.documents.length})"),
                            ],
                          ),
                        ),
                      ),
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_cart_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text("Commandes (${stockProvider.orders.length})"),
                            ],
                          ),
                        ),
                      ),
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.local_shipping_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text("Livraisons (${stockProvider.deliveries.length})"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Barre de Recherche & Filtres Statut
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Rechercher un bon...",
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = "";
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Filtre Statut Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _statusFilter,
                          isDense: true,
                          hint: const Text("Statut", style: TextStyle(fontSize: 12)),
                          icon: const Icon(Icons.filter_list_rounded, size: 18),
                          items: const [
                            DropdownMenuItem(value: null, child: Text("Tous", style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'DRAFT', child: Text("Brouillon", style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'VALIDATED', child: Text("Confirmé", style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'DELIVERED', child: Text("Livré", style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'CANCELLED', child: Text("Annulé", style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) => setState(() => _statusFilter = val),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenu des onglets unifiés
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Onglet 1: Tous les bons
                    _buildDocumentList(filteredAll, isWide: isWide),
                    // Onglet 2: Bons de commande
                    _buildDocumentList(filteredOrders, isWide: isWide),
                    // Onglet 3: Bons de livraison
                    _buildDocumentList(filteredDeliveries, isWide: isWide),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
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

  Widget _buildDocumentList(List<CommercialDocument> docs, {required bool isWide}) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 54,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              "Aucun document trouvé",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              "Cliquez sur '+ Nouveau Bon' pour créer votre premier document.",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<StockProvider>().loadDocuments(force: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: docs.length,
        itemBuilder: (context, index) {
        final doc = docs[index];
        final isDelivery = doc.isDelivery;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openPreviewDialog(doc),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icône type
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDelivery
                              ? const Color(0xFF0D9488).withValues(alpha: 0.1)
                              : AppConstants.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDelivery ? Icons.local_shipping_rounded : Icons.receipt_long_rounded,
                          color: isDelivery ? const Color(0xFF0D9488) : AppConstants.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Infos principales
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isDelivery ? const Color(0xFFCCFBF1) : const Color(0xFFE0E7FF),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    isDelivery ? "BL" : "BC",
                                    style: TextStyle(
                                      color: isDelivery ? const Color(0xFF0F766E) : const Color(0xFF4338CA),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  doc.referenceNumber,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.textPrimary),
                                ),
                                _buildStatusBadge(doc.status, doc.statusLabel),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doc.partnerName?.isNotEmpty == true
                                  ? doc.partnerName!
                                  : (doc.pointOfSaleName ?? "Client au comptoir"),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${doc.totalItemsCount} article(s) • ${_dateFormat.format(doc.issueDate)}",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Montant Total
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _currencyFormat.format(doc.totalAmount),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: isDelivery ? const Color(0xFF0D9488) : AppConstants.primary,
                              ),
                            ),
                          ),
                          if (doc.parentDocumentReference != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                "Réf: ${doc.parentDocumentReference}",
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),

                  // Actions rapides sur la carte avec Wrap pour éviter tout overflow
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Aperçu A4
                        TextButton.icon(
                          onPressed: () => _openPreviewDialog(doc),
                          icon: const Icon(Icons.visibility_outlined, size: 15),
                          label: const Text("Aperçu"),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),

                        // Exporter / Imprimer PDF Pro
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => PdfPreviewDialog(document: doc),
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 15, color: AppConstants.primary),
                          label: const Text("PDF / Imprimer"),
                          style: TextButton.styleFrom(
                            foregroundColor: AppConstants.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),

                        // Modifier le bon (avec pop-up de confirmation préalable)
                        TextButton.icon(
                          onPressed: () => _handleEditDocument(doc),
                          icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF0D9488)),
                          label: const Text("Modifier"),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0D9488),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),

                        // Si Commande : Boutons Convertir / Livrer
                        if (doc.isOrder && doc.status != 'CANCELLED') ...[
                          ElevatedButton.icon(
                            onPressed: () => _handleConvertAndDeliver(doc),
                            icon: const Icon(Icons.flash_on_rounded, size: 14),
                            label: const Text("Livrer & Déstocker"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _handleConvertToDelivery(doc),
                            icon: const Icon(Icons.transform_rounded, size: 14),
                            label: const Text("BL Brouillon"),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0D9488),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],

                        // Si Livraison et pas encore livrée : Bouton Valider & Déstocker
                        if (doc.isDelivery && doc.status != 'DELIVERED' && doc.status != 'CANCELLED') ...[
                          ElevatedButton.icon(
                            onPressed: () => _handleStatusChange(doc, 'DELIVERED'),
                            icon: const Icon(Icons.check_circle_outline, size: 15),
                            label: const Text("Valider & Déstocker"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],

                        // Si Livraison déjà livrée : Badge stock à jour
                        if (doc.isDelivery && doc.status == 'DELIVERED') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Text(
                                  doc.direction == 'INCOMING' ? "Stock ajouté" : "Stock déduit",
                                  style: const TextStyle(color: Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Menu 3 petits points (Autres statuts, Supprimer)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                          onSelected: (action) {
                            if (action == 'DELETE') {
                              _handleDeleteDocument(doc);
                            } else if (action == 'EDIT') {
                              _handleEditDocument(doc);
                            } else {
                              _handleStatusChange(doc, action);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'EDIT',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0D9488)),
                                  SizedBox(width: 8),
                                  Text("Modifier le bon"),
                                ],
                              ),
                            ),
                            if (doc.status != 'VALIDATED')
                              const PopupMenuItem(value: 'VALIDATED', child: Text("Marquer comme Validé")),
                            if (doc.status != 'DELIVERED')
                              const PopupMenuItem(value: 'DELIVERED', child: Text("Marquer comme Livré")),
                            if (doc.status != 'CANCELLED')
                              const PopupMenuItem(value: 'CANCELLED', child: Text("Marquer comme Annulé")),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'DELETE',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: AppConstants.danger, size: 18),
                                  SizedBox(width: 8),
                                  Text("Supprimer", style: TextStyle(color: AppConstants.danger)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

  Widget _buildStatusBadge(String status, String label) {
    Color bg;
    Color fg;
    switch (status) {
      case 'DELIVERED':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'VALIDATED':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
