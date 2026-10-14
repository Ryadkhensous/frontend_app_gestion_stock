import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/seller.dart';
import '../providers/stock_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'widgets/seller_form_dialog.dart';
import 'widgets/seller_details_dialog.dart';

class SellersView extends StatefulWidget {
  const SellersView({super.key});

  @override
  State<SellersView> createState() => _SellersViewState();
}

class _SellersViewState extends State<SellersView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filterStatus = "ALL"; // ALL, ACTIVE, INACTIVE
  final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'DA',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockProvider>().loadSellers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Seller> _getFilteredSellers(List<Seller> sellers) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return sellers.where((s) {
      if (_filterStatus == "ACTIVE" && !s.isActive) return false;
      if (_filterStatus == "INACTIVE" && s.isActive) return false;

      if (query.isNotEmpty) {
        final matchName = s.fullName.toLowerCase().contains(query);
        final matchUser = s.username.toLowerCase().contains(query);
        final matchPhone = (s.phone ?? '').toLowerCase().contains(query);
        final matchPos = (s.pointOfSaleName ?? '').toLowerCase().contains(query);
        return matchName || matchUser || matchPhone || matchPos;
      }
      return true;
    }).toList();
  }

  void _openCreateSellerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const SellerFormDialog(),
    );
  }

  void _openEditSellerDialog(Seller seller) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SellerFormDialog(seller: seller),
    );
  }

  void _openSellerDetails(Seller seller) {
    showDialog(
      context: context,
      builder: (ctx) => SellerDetailsDialog(seller: seller),
    );
  }

  Future<void> _toggleSellerStatus(Seller seller) async {
    final provider = context.read<StockProvider>();
    final newStatus = !seller.isActive;
    final success = await provider.updateSeller(seller.id, {
      "is_active": newStatus,
    });

    if (mounted) {
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (newStatus
                    ? "Vendeur '${seller.fullName}' réactivé avec succès."
                    : "Vendeur '${seller.fullName}' désactivé.")
                : (provider.errorMessage ?? "Erreur lors du changement de statut."),
          ),
          backgroundColor: success
              ? (newStatus ? AppConstants.success : Colors.orange.shade800)
              : AppConstants.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteSeller(Seller seller) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppConstants.danger),
            SizedBox(width: 8),
            Text("Supprimer le vendeur ?"),
          ],
        ),
        content: Text(
          "Êtes-vous sûr de vouloir supprimer le compte de '${seller.fullName}' (@${seller.username}) ?\n\n"
          "Si le vendeur possède déjà des ventes enregistrées, son compte sera désactivé pour préserver l'historique comptable.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<StockProvider>();
    final success = await provider.deleteSeller(seller.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? "Opération effectuée avec succès."
                : (provider.errorMessage ?? "Erreur lors de la suppression."),
          ),
          backgroundColor: success ? AppConstants.success : AppConstants.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final authProvider = context.watch<AuthProvider>();
    final overview = stockProvider.sellersOverview;
    final sellers = stockProvider.sellers;
    final filteredSellers = _getFilteredSellers(sellers);

    final totalCount = overview?.totalSellers ?? sellers.length;
    final activeCount = overview?.activeSellers ?? sellers.where((s) => s.isActive).length;
    final totalTurnover = overview?.totalTurnover ?? sellers.fold<double>(0.0, (acc, s) => acc + s.totalTurnover);
    final totalCommission = overview?.totalCommission ?? sellers.fold<double>(0.0, (acc, s) => acc + s.totalCommission);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Équipe & Vendeurs",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Actualiser",
            onPressed: () => stockProvider.loadSellers(),
          ),
        ],
      ),
      floatingActionButton: authProvider.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openCreateSellerDialog,
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                "Nouveau Vendeur",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => stockProvider.loadSellers(),
        color: const Color(0xFF4F46E5),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // 1. CARTE EN-TÊTE SYNTHÈSE GLOBALE
            _buildOverviewCards(
              totalCount: totalCount,
              activeCount: activeCount,
              totalTurnover: totalTurnover,
              totalCommission: totalCommission,
            ),
            const SizedBox(height: 18),

            // 2. BARRE DE RECHERCHE ET FILTRES
            _buildSearchAndFilters(),
            const SizedBox(height: 16),

            // 3. LISTE DES VENDEURS
            if (stockProvider.isLoading && sellers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                ),
              )
            else if (filteredSellers.isEmpty)
              _buildEmptyState()
            else
              ...filteredSellers.map((seller) => _buildSellerCard(seller)),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards({
    required int totalCount,
    required int activeCount,
    required double totalTurnover,
    required double totalCommission,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.badge_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Force de Vente & Commissions",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Suivi des vendeurs et commissions dues",
                        style: TextStyle(
                          color: Color(0xFFC7D2FE),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$activeCount / $totalCount actifs",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  label: "Chiffre d'Affaires Ventes",
                  value: _currencyFmt.format(totalTurnover),
                  icon: Icons.trending_up_rounded,
                  accentColor: const Color(0xFF34D399),
                ),
              ),
              Container(width: 1, height: 42, color: Colors.white24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: _buildMetricItem(
                    label: "Commissions Estimées",
                    value: _currencyFmt.format(totalCommission),
                    icon: Icons.payments_rounded,
                    accentColor: const Color(0xFFFBBF24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE0E7FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Rechercher par nom, identifiant, téléphone...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Menu filtre statut
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list_rounded,
              color: _filterStatus != "ALL" ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
            ),
            tooltip: "Filtrer les vendeurs",
            onSelected: (val) => setState(() => _filterStatus = val),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: "ALL",
                child: Row(
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 18,
                      color: _filterStatus == "ALL" ? const Color(0xFF4F46E5) : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text("Tous les vendeurs"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "ACTIVE",
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: _filterStatus == "ACTIVE" ? const Color(0xFF4F46E5) : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text("Actifs uniquement"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "INACTIVE",
                child: Row(
                  children: [
                    Icon(
                      Icons.pause_circle_outline,
                      size: 18,
                      color: _filterStatus == "INACTIVE" ? const Color(0xFF4F46E5) : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Text("Inactifs / Suspendus"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSellerCard(Seller seller) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: seller.isActive ? const Color(0xFFE2E8F0) : Colors.red.shade100,
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSellerDetails(seller),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne supérieure : Avatar, Nom, Badge commission, Menu actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar texturé
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: seller.isActive
                            ? const [Color(0xFF4F46E5), Color(0xFF7C3AED)]
                            : [Colors.grey.shade500, Colors.grey.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (seller.isActive ? const Color(0xFF4F46E5) : Colors.grey)
                              .withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      seller.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Infos Nom & Identifiant
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                seller.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: seller.isActive ? const Color(0xFF0F172A) : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (!seller.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red.shade200, width: 0.6),
                                ),
                                child: Text(
                                  "INACTIF",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              "@${seller.username}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo.shade600,
                              ),
                            ),
                            if (seller.phone != null && seller.phone!.isNotEmpty) ...[
                              const Text(" • ", style: TextStyle(color: Colors.grey)),
                              Icon(Icons.phone_outlined, size: 12, color: Colors.grey.shade600),
                              const SizedBox(width: 3),
                              Text(
                                seller.phone!,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Badge de Commission (%)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.percent_rounded, size: 12, color: Color(0xFF059669)),
                        const SizedBox(width: 3),
                        Text(
                          "${seller.commissionRate.toStringAsFixed(seller.commissionRate.truncateToDouble() == seller.commissionRate ? 0 : 1)}% com.",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Menu d'options
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      switch (val) {
                        case 'details':
                          _openSellerDetails(seller);
                          break;
                        case 'edit':
                          _openEditSellerDialog(seller);
                          break;
                        case 'toggle':
                          _toggleSellerStatus(seller);
                          break;
                        case 'delete':
                          _confirmDeleteSeller(seller);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.analytics_outlined, size: 18, color: Color(0xFF4F46E5)),
                            SizedBox(width: 10),
                            Text("Historique des ventes"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0D9488)),
                            SizedBox(width: 10),
                            Text("Modifier le profil / Taux"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              seller.isActive ? Icons.block_rounded : Icons.check_circle_outline,
                              size: 18,
                              color: seller.isActive ? Colors.orange.shade800 : Colors.green.shade700,
                            ),
                            const SizedBox(width: 10),
                            Text(seller.isActive ? "Désactiver le vendeur" : "Activer le vendeur"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppConstants.danger),
                            SizedBox(width: 10),
                            Text("Supprimer", style: TextStyle(color: AppConstants.danger)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Point de vente rattaché (si configuré)
              if (seller.pointOfSaleName != null) ...[
                Row(
                  children: [
                    Icon(Icons.storefront_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 5),
                    Text(
                      "Point de vente : ${seller.pointOfSaleName}",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // Ligne de statistiques : Ventes, CA, Commissions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Ventes",
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${seller.totalSalesCount} tickets",
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 26, color: Colors.grey.shade300),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Chiffre Réalisé",
                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currencyFmt.format(seller.totalTurnover),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, height: 26, color: Colors.grey.shade300),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Gains Commission",
                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currencyFmt.format(seller.totalCommission),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4338CA),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 48,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Aucun vendeur trouvé",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchCtrl.text.isNotEmpty
                  ? "Aucun résultat pour '${_searchCtrl.text}'."
                  : "Ajoutez vos premiers vendeurs travaillant à la commission.",
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openCreateSellerDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text("Ajouter un Vendeur"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
