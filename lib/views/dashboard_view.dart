import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/stock_provider.dart';
import '../utils/constants.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import 'widgets/document_form_dialog.dart';
import 'widgets/barcode_scanner_dialog.dart';
import 'widgets/scanner_status_badge.dart';
import 'widgets/reorder_suggestions_dialog.dart';
import 'pos_checkout_view.dart';
import 'inventory_session_view.dart';
import 'product_profit_view.dart';
import 'settings_view.dart';
import 'sellers_view.dart';
import 'widgets/store_user_badge.dart';

class DashboardView extends StatelessWidget {
  final void Function(int index)? onNavigateToTab;

  const DashboardView({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final stats = stockProvider.stats;
    final currencyFormatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);

    if (stockProvider.isLoading && stats == null) {
      return const Center(child: CircularProgressIndicator(color: AppConstants.primary));
    }

    return RefreshIndicator(
      onRefresh: () => stockProvider.loadAll(),
      color: AppConstants.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec Magasin & Actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Tableau de Bord",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Vue d'ensemble de vos stocks",
                        style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const StoreUserBadge(),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: AppConstants.textSecondary),
                  tooltip: "Paramètres de l'application",
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const SettingsView()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Barre de statut Scanner & Titre des raccourcis
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Actions & Raccourcis",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFC7D2FE), width: 0.8),
                      ),
                      child: const Text(
                        "10 Outils",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ],
                ),
                const ScannerStatusBadge(),
              ],
            ),
            const SizedBox(height: 10),

            // Message d'erreur éventuel avec bouton réessayer
            if (stockProvider.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stockProvider.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => stockProvider.loadAll(),
                      child: const Text("Réessayer"),
                    )
                  ],
                ),
              ),

            // Barre d'actions rapides texturée & tactile
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF64748B).withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _TexturedActionButton(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const PosCheckoutView()),
                        );
                      },
                      icon: Icons.point_of_sale_rounded,
                      label: "Caisse POS",
                      gradientColors: const [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF3730A3)],
                      shadowColor: const Color(0xFF4F46E5),
                    ),
                    _TexturedActionButton(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const SellersView()),
                        );
                      },
                      icon: Icons.badge_rounded,
                      label: "Vendeurs & Com.",
                      gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF6D28D9)],
                      shadowColor: const Color(0xFF7C3AED),
                    ),
                    _TexturedActionButton(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const ProductProfitView()),
                        );
                      },
                      icon: Icons.trending_up_rounded,
                      label: "Bénéfices & Marge",
                      gradientColors: const [Color(0xFF10B981), Color(0xFF059669), Color(0xFF047857)],
                      shadowColor: const Color(0xFF059669),
                    ),
                    _TexturedActionButton(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const InventorySessionView()),
                        );
                      },
                      icon: Icons.fact_check_rounded,
                      label: "Inventaire",
                      gradientColors: const [Color(0xFF0EA5E9), Color(0xFF0284C7), Color(0xFF0369A1)],
                      shadowColor: const Color(0xFF0284C7),
                    ),
                    _TexturedActionButton(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const ReorderSuggestionsDialog(),
                        );
                      },
                      icon: Icons.auto_fix_high_rounded,
                      label: "Réappro Ruptures",
                      gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309)],
                      shadowColor: const Color(0xFFD97706),
                    ),
                    _TexturedActionButton(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const BarcodeScannerDialog(),
                        );
                      },
                      icon: Icons.qr_code_scanner_rounded,
                      label: "Scanner / Réception",
                      gradientColors: const [Color(0xFF334155), Color(0xFF1E293B), Color(0xFF0F172A)],
                      shadowColor: const Color(0xFF1E293B),
                    ),
                    _TexturedActionButton(
                      onTap: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => const DocumentFormDialog(initialDocType: 'ORDER'),
                        );
                      },
                      icon: Icons.add_shopping_cart_rounded,
                      label: "Nouveau Bon",
                      gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF5B21B6)],
                      shadowColor: const Color(0xFF7C3AED),
                    ),
                    _TexturedActionButton(
                      onTap: () => onNavigateToTab?.call(3),
                      icon: Icons.sync_alt_rounded,
                      label: "Mouvements",
                      gradientColors: const [Color(0xFF14B8A6), Color(0xFF0D9488), Color(0xFF0F766E)],
                      shadowColor: const Color(0xFF0D9488),
                    ),
                    _TexturedActionButton(
                      onTap: () => onNavigateToTab?.call(1),
                      icon: Icons.inventory_2_rounded,
                      label: "Gérer Stock",
                      gradientColors: const [Color(0xFF64748B), Color(0xFF475569), Color(0xFF334155)],
                      shadowColor: const Color(0xFF475569),
                    ),
                    _TexturedActionButton(
                      onTap: () => onNavigateToTab?.call(2),
                      icon: Icons.storefront_rounded,
                      label: "Points de Vente",
                      gradientColors: const [Color(0xFFEC4899), Color(0xFFDB2777), Color(0xFF9D174D)],
                      shadowColor: const Color(0xFFDB2777),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Grille des KPIs
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.35 : 1.15,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildKpiCard(
                  title: "Valeur du Stock",
                  value: currencyFormatter.format(stats?.totalInventoryValue ?? 0),
                  icon: Icons.account_balance_wallet_outlined,
                  gradient: const [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  onTap: () => onNavigateToTab?.call(1),
                ),
                _buildKpiCard(
                  title: "Articles en Stock",
                  value: "${stats?.totalStockUnits ?? 0} unités",
                  subtitle: "${stats?.totalProducts ?? 0} références",
                  icon: Icons.inventory_2_outlined,
                  gradient: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
                  onTap: () => onNavigateToTab?.call(1),
                ),
                _buildKpiCard(
                  title: "Points de Vente",
                  value: "${stats?.totalPointsOfSale ?? 0} magasins",
                  subtitle: "${stats?.activePointsOfSale ?? 0} actifs sur carte",
                  icon: Icons.storefront_outlined,
                  gradient: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  onTap: () => onNavigateToTab?.call(2),
                ),
                _buildKpiCard(
                  title: "Alertes Rupture",
                  value: "${stats?.lowStockAlertsCount ?? 0} produit(s)",
                  subtitle: (stats?.lowStockAlertsCount ?? 0) > 0 ? "Action requise" : "Stock optimal",
                  icon: Icons.warning_amber_rounded,
                  gradient: (stats?.lowStockAlertsCount ?? 0) > 0
                      ? const [Color(0xFFE11D48), Color(0xFFF43F5E)]
                      : const [Color(0xFF059669), Color(0xFF10B981)],
                  onTap: () {
                    if (!stockProvider.showOnlyLowStock) {
                      stockProvider.toggleLowStockFilter();
                    }
                    onNavigateToTab?.call(1);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bannière Rentabilité & Bénéfices avec Calendrier
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const ProductProfitView()),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF065F46), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Analyse de Bénéfice par Produit & Calendrier",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Visualisez vos marges réelles filtrées par date & chronologie",
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section Alertes Stock Bas
            if (stats != null && stats.lowStockProducts.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      "⚠️ Alertes Stock Critique",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        "${stats.lowStockProducts.length} réf.",
                        style: const TextStyle(fontSize: 13, color: AppConstants.danger, fontWeight: FontWeight.w600),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => const ReorderSuggestionsDialog(),
                          );
                        },
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                        label: const Text("Réappro 1-Clic", style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...stats.lowStockProducts.map((p) => _buildLowStockCard(context, p, stockProvider)),
              const SizedBox(height: 20),
            ],

            // Section Derniers Mouvements
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    "Derniers Mouvements",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text("Voir tout", style: TextStyle(fontSize: 12)),
                  onPressed: () => onNavigateToTab?.call(3),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (stats != null && stats.recentMovements.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text("Aucun mouvement enregistré.", style: TextStyle(color: AppConstants.textSecondary)),
                ),
              )
            else if (stats != null)
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stats.recentMovements.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final m = stats.recentMovements[index];
                    return _buildMovementTile(m);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required List<Color> gradient,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(icon, color: Colors.white, size: 20),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLowStockCard(BuildContext context, Product p, StockProvider provider) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFFEF2F2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFECACA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.priority_high, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppConstants.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "SKU: ${p.sku} • Seuil alerte : ${p.minStockAlert}",
                        style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${p.quantity} restants",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 15, color: AppConstants.primary),
                    label: const Text("Commander (BC)", style: TextStyle(fontSize: 11, color: AppConstants.primary, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppConstants.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => DocumentFormDialog(
                          initialDocType: 'ORDER',
                          initialDirection: 'INCOMING',
                          initialProduct: p,
                        ),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text("Réception directe (+)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                    onPressed: () => _showQuickRestockDialog(context, p, provider),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickRestockDialog(BuildContext context, Product p, StockProvider provider) {
    final qtyCtrl = TextEditingController(text: "10");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Réception directe : ${p.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Stock disponible : ${p.quantity}", style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Quantité reçue (+)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add_circle_outline, color: Colors.green),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text);
              if (qty == null || qty <= 0) return;
              Navigator.pop(ctx);
              final ok = await provider.addStockMovement({
                "product_id": p.id,
                "movement_type": "IN",
                "quantity": qty,
                "note": "Réception directe depuis le tableau de bord",
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? "+$qty unités ajoutées à ${p.name} !" : "Erreur lors de l'ajout"),
                    backgroundColor: ok ? AppConstants.success : AppConstants.danger,
                  ),
                );
              }
            },
            child: const Text("Ajouter au stock"),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementTile(StockMovement m) {
    final isIn = m.movementType == "IN";
    final isTransfer = m.movementType == "TRANSFER";
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    Color typeColor = isIn ? Colors.green : (isTransfer ? Colors.blue : Colors.orange);
    IconData typeIcon = isIn ? Icons.arrow_downward : (isTransfer ? Icons.swap_horiz : Icons.arrow_upward);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: typeColor.withValues(alpha: 0.12),
        child: Icon(typeIcon, color: typeColor, size: 18),
      ),
      title: Text(
        m.productName ?? "Produit inconnu",
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        "${dateFormatter.format(m.createdAt)}${m.pointOfSaleName != null ? ' • POS: ${m.pointOfSaleName}' : ''}",
        style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
      ),
      trailing: Text(
        "${isIn ? '+' : '-'}${m.quantity}",
        style: TextStyle(
          color: typeColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _TexturedActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final Color shadowColor;

  const _TexturedActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.shadowColor,
  });

  @override
  State<_TexturedActionButton> createState() => _TexturedActionButtonState();
}

class _TexturedActionButtonState extends State<_TexturedActionButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
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
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : (_isHovered ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: _isHovered ? 0.45 : 0.24),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.shadowColor.withValues(alpha: _isHovered ? 0.45 : 0.26),
                  blurRadius: _isHovered ? 14 : 7,
                  offset: Offset(0, _isHovered ? 5 : 2.5),
                  spreadRadius: _isHovered ? 1 : 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8.5),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
