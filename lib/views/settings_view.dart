import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stock_provider.dart';
import '../providers/auth_provider.dart';
import '../services/feedback_service.dart';
import '../models/commercial_document.dart';
import '../utils/constants.dart';
import 'widgets/pdf_preview_dialog.dart';
import 'login_view.dart';
import 'sellers_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _companyNameCtrl;
  late TextEditingController _companyAddressCtrl;
  late TextEditingController _companyPhoneCtrl;
  late TextEditingController _companyEmailCtrl;
  late TextEditingController _companyTaxIdCtrl;
  String _selectedCurrency = "DA";
  late TextEditingController _receiptFooterCtrl;
  late TextEditingController _minStockCtrl;

  bool _enableHaptic = true;
  bool _enableSound = true;
  String _printFormat = "THERMAL_80MM";
  int? _defaultPosId;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();

    _companyNameCtrl = TextEditingController(text: settings.companyName);
    _companyAddressCtrl = TextEditingController(text: settings.companyAddress);
    _companyPhoneCtrl = TextEditingController(text: settings.companyPhone);
    _companyEmailCtrl = TextEditingController(text: settings.companyEmail);
    _companyTaxIdCtrl = TextEditingController(text: settings.companyTaxId);
    _selectedCurrency = settings.currencySymbol;
    _receiptFooterCtrl = TextEditingController(text: settings.receiptFooter);
    _minStockCtrl = TextEditingController(
      text: settings.defaultMinStock.toString(),
    );

    _enableHaptic = settings.enableHaptic;
    _enableSound = settings.enableSound;
    _printFormat = settings.defaultPrintFormat;
    _defaultPosId = settings.defaultPosId;
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyAddressCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyTaxIdCtrl.dispose();

    _receiptFooterCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAllSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final settings = context.read<SettingsProvider>();

    final minStock = int.tryParse(_minStockCtrl.text.trim()) ?? 5;

    await settings.saveSettings(
      apiUrl: AppConstants.defaultBaseUrl,
      companyName: _companyNameCtrl.text.trim(),
      companyAddress: _companyAddressCtrl.text.trim(),
      companyPhone: _companyPhoneCtrl.text.trim(),
      companyEmail: _companyEmailCtrl.text.trim(),
      companyTaxId: _companyTaxIdCtrl.text.trim(),
      currencySymbol: _selectedCurrency,
      receiptFooter: _receiptFooterCtrl.text.trim(),
      enableHaptic: _enableHaptic,
      enableSound: _enableSound,
      defaultPosId: _defaultPosId,
      defaultPrintFormat: _printFormat,
      defaultMinStock: minStock,
    );

    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Paramètres enregistrés avec succès !"),
          backgroundColor: AppConstants.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Réinitialiser les paramètres ?"),
            content: const Text(
              "Toutes vos préférences et informations d'entreprise seront restaurées aux valeurs par défaut.",
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
                child: const Text("Réinitialiser"),
              ),
            ],
          ),
    );

    if (confirm != true || !mounted) return;

    final settings = context.read<SettingsProvider>();
    await settings.resetToDefaults();

    setState(() {
      _companyNameCtrl.text = settings.companyName;
      _companyAddressCtrl.text = settings.companyAddress;
      _companyPhoneCtrl.text = settings.companyPhone;
      _companyEmailCtrl.text = settings.companyEmail;
      _companyTaxIdCtrl.text = settings.companyTaxId;
      _selectedCurrency = settings.currencySymbol;
      _receiptFooterCtrl.text = settings.receiptFooter;
      _minStockCtrl.text = settings.defaultMinStock.toString();
      _enableHaptic = settings.enableHaptic;
      _enableSound = settings.enableSound;
      _printFormat = settings.defaultPrintFormat;
      _defaultPosId = settings.defaultPosId;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Paramètres réinitialisés."),
          backgroundColor: AppConstants.secondary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final authProvider = context.watch<AuthProvider>();
    final posList = stockProvider.pointsOfSale;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Paramètres de l'Application",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_rounded),
            tooltip: "Réinitialiser aux valeurs d'usine",
            onPressed: _confirmReset,
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppConstants.primary),
            tooltip: "Enregistrer",
            onPressed: _saveAllSettings,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // 0. SECTION COMPTE & MAGASIN (SaaS Multi-Tenant)
            _buildSectionHeader(
              title: "Compte & Magasin Connecté",
              subtitle:
                  "Informations sur le magasin actif et la session utilisateur",
              icon: Icons.storefront_rounded,
              color: AppConstants.primary,
            ),
            _buildStoreAccountCard(),
            const SizedBox(height: 20),

            // 1. SECTION ENTREPRISE & FACTURATION
            _buildSectionHeader(
              title: "Identité de l'Entreprise",
              subtitle:
                  "Données figurant sur les documents officiels et tickets de caisse",
              icon: Icons.business_rounded,
              color: const Color(0xFF0D9488),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _companyNameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nom de l'Entreprise / Enseigne",
                        prefixIcon: Icon(Icons.store_rounded),
                      ),
                      validator:
                          (v) =>
                              v == null || v.trim().isEmpty
                                  ? "Nom requis"
                                  : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _companyPhoneCtrl,
                            decoration: const InputDecoration(
                              labelText: "Téléphone",
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value:
                                _currencyList.contains(_selectedCurrency)
                                    ? _selectedCurrency
                                    : _currencyList.first,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: "Devise",
                              prefixIcon: Icon(Icons.payments_outlined),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            items:
                                _currencyList.map((c) {
                                  final label = _currencyLabels[c] ?? c;
                                  return DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCurrency = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _companyAddressCtrl,
                      decoration: const InputDecoration(
                        labelText: "Adresse du Siège",
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _companyEmailCtrl,
                      decoration: const InputDecoration(
                        labelText: "Email de Contact",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Identifiants Légaux — Tap pour popup
                    InkWell(
                      onTap: _showLegalIdsDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Identifiants Légaux (NIF / RC)",
                          prefixIcon: const Icon(Icons.badge_outlined),
                          suffixIcon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppConstants.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _companyTaxIdCtrl.text.isNotEmpty
                              ? _companyTaxIdCtrl.text
                              : "Appuyez pour modifier",
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                _companyTaxIdCtrl.text.isNotEmpty
                                    ? AppConstants.textPrimary
                                    : Colors.grey.shade400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. SECTION TICKETS & IMPRESSION
            _buildSectionHeader(
              title: "Impression & Tickets",
              subtitle: "Format des documents et personnalisation des reçus",
              icon: Icons.print_rounded,
              color: const Color(0xFF0284C7),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Format d'impression favori :",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: "THERMAL_80MM",
                          label: Text("Ticket Caisse 80mm"),
                          icon: Icon(Icons.receipt_long_rounded),
                        ),
                        ButtonSegment(
                          value: "A4",
                          label: Text("Document A4 Pro"),
                          icon: Icon(Icons.picture_as_pdf_rounded),
                        ),
                      ],
                      selected: {_printFormat},
                      onSelectionChanged: (val) {
                        final selected = val.first;
                        setState(() => _printFormat = selected);
                        context.read<SettingsProvider>().saveSettings(
                          defaultPrintFormat: selected,
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _receiptFooterCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Pied de page des tickets de caisse",
                        hintText:
                            "Message de remerciement, politique d'échange...",
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: const Text("Prévisualiser le Ticket"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              side: const BorderSide(color: Color(0xFFBAE6FD)),
                              backgroundColor: const Color(0xFFF0F9FF),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              context.read<SettingsProvider>().saveSettings(
                                receiptFooter: _receiptFooterCtrl.text.trim(),
                                defaultPrintFormat: _printFormat,
                              );
                              final stockProvider =
                                  context.read<StockProvider>();
                              final sampleDoc =
                                  stockProvider.documents.isNotEmpty
                                      ? stockProvider.documents.first
                                      : CommercialDocument(
                                        id: 1,
                                        referenceNumber: "TK-DEMO-001",
                                        docType: "DELIVERY",
                                        direction: "OUTGOING",
                                        status: "DELIVERED",
                                        partnerName: "Client Comptoir (Démo)",
                                        pointOfSaleName: "Caisse Principale",
                                        issueDate: DateTime.now(),
                                        totalAmount: 2450.0,
                                        createdAt: DateTime.now(),
                                        notes: "Vente au comptoir",
                                        items: [
                                          DocumentItem(
                                            productId: 1,
                                            productName: "Article Démo A",
                                            productSku: "ART-001",
                                            quantity: 2,
                                            unitPrice: 600.0,
                                            totalPrice: 1200.0,
                                          ),
                                          DocumentItem(
                                            productId: 2,
                                            productName: "Article Démo B",
                                            productSku: "ART-002",
                                            quantity: 1,
                                            unitPrice: 1250.0,
                                            totalPrice: 1250.0,
                                          ),
                                        ],
                                      );
                              showDialog(
                                context: context,
                                builder:
                                    (_) => PdfPreviewDialog(
                                      document: sampleDoc,
                                      isThermalReceipt:
                                          _printFormat == "THERMAL_80MM",
                                      paymentMethod: "Espèces",
                                      amountTendered: 3000.0,
                                      changeDue: 550.0,
                                    ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 4. SECTION SCANNER & MATÉRIEL
            _buildSectionHeader(
              title: "Douchette & Scanner Barcode",
              subtitle:
                  "Comportement du lecteur optique et retours utilisateur",
              icon: Icons.qr_code_scanner_rounded,
              color: const Color(0xFFD97706),
            ),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      "Retour Haptique (Vibration)",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      "Vibre lors de la lecture d'un code-barres et des actions de vente",
                    ),
                    secondary: const Icon(
                      Icons.vibration_rounded,
                      color: Color(0xFFD97706),
                    ),
                    value: _enableHaptic,
                    onChanged: (val) {
                      setState(() => _enableHaptic = val);
                      context.read<SettingsProvider>().saveSettings(
                        enableHaptic: val,
                      );
                      if (val) {
                        FeedbackService.scanSuccess(haptic: true, sound: false);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text(
                      "Bip Audio de Validation",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      "Émet un son audible lors de la détection réussie d'un code",
                    ),
                    secondary: const Icon(
                      Icons.volume_up_rounded,
                      color: Color(0xFFD97706),
                    ),
                    value: _enableSound,
                    onChanged: (val) {
                      setState(() => _enableSound = val);
                      context.read<SettingsProvider>().saveSettings(
                        enableSound: val,
                      );
                      if (val) {
                        FeedbackService.scanSuccess(haptic: false, sound: true);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. SECTION MAGASIN & STOCKS
            _buildSectionHeader(
              title: "Magasin & Alertes Stock",
              subtitle: "Point de vente par défaut et seuils de sécurité",
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF10B981),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<int?>(
                      value: _defaultPosId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Point de Vente Actif par Défaut",
                        prefixIcon: Icon(Icons.storefront_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            "Aucun (Demander à chaque opération)",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...posList.map((pos) {
                          return DropdownMenuItem<int?>(
                            value: pos.id,
                            child: Text(
                              "${pos.name} (${pos.city ?? 'Dépôt'})",
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) => setState(() => _defaultPosId = val),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _minStockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Seuil d'Alerte de Stock Minimal par Défaut",
                        hintText: "Ex: 5 unités",
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 5.b SECTION ÉQUIPE & VENDEURS
            if (authProvider.isAdmin) ...[
              _buildSectionHeader(
                title: "Équipe & Vendeurs",
                subtitle: "Gestion des comptes vendeurs et calcul des commissions",
                icon: Icons.badge_rounded,
                color: const Color(0xFF4F46E5),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.people_alt_rounded,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        title: const Text(
                          "Comptes Vendeurs & Commissions",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          "${stockProvider.sellers.length} vendeurs enregistrés (${stockProvider.sellers.where((s) => s.isActive).length} actifs)",
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SellersView()),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text("Gérer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 6. SECTION SYSTÈME & MAINTENANCE (Réservé aux Administrateurs)
            if (authProvider.isAdmin) ...[
              _buildSectionHeader(
                title: "Système & Maintenance",
                subtitle: "Cache local et diagnostic de l'application",
                icon: Icons.info_outline_rounded,
                color: const Color(0xFF64748B),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 12,
                        color: Color(0xFFEF4444),
                      ),
                      SizedBox(width: 4),
                      Text(
                        "ADMIN",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.blue,
                          ),
                        ),
                        title: const Text(
                          "Rafraîchir toutes les données",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          "Recharge les stocks, magasins, mouvements et documents depuis le serveur",
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await stockProvider.loadAll();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Données synchronisées avec succès !",
                                  ),
                                  backgroundColor: AppConstants.success,
                                ),
                              );
                            }
                          },
                          child: const Text("Synchroniser"),
                        ),
                      ),
                      const Divider(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Version de l'Application",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            "1.0.0 (Build Pro)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Base de Données Backend",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            "PostgreSQL (Online)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Bouton Enregistrer Principal
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saveAllSettings,
                icon: const Icon(Icons.save_rounded, size: 20),
                label: const Text(
                  "Enregistrer les Paramètres",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildStoreAccountCard() {
    final auth = context.watch<AuthProvider>();
    final storeName = auth.storeName;
    final username = auth.username;
    final role = auth.role;
    final plan = auth.currentTenant?.subscriptionPlan ?? "PRO";
    final isGuest = !auth.isAuthenticated;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppConstants.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isGuest
                            ? "Mode Démo / Invité"
                            : "Plan $plan • Rôle: $role",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isGuest ? Colors.orange.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          isGuest
                              ? Colors.orange.shade200
                              : Colors.green.shade200,
                    ),
                  ),
                  child: Text(
                    isGuest ? "INVITÉ" : "ACTIF",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color:
                          isGuest
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Utilisateur : $username",
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppConstants.textSecondary,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 16,
                    color: AppConstants.danger,
                  ),
                  label: const Text(
                    "Changer de Compte",
                    style: TextStyle(
                      color: AppConstants.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () async {
                    await auth.logout();
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginView()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Currency data ──────────────────────────────────────────
  static const List<String> _currencyList = [
    'DA',
    'EUR',
    'USD',
    'GBP',
    'MAD',
    'TND',
    'LYD',
    'EGP',
    'SAR',
    'AED',
    'QAR',
    'KWD',
    'BHD',
    'OMR',
    'JOD',
    'TRY',
    'CHF',
    'CAD',
    'AUD',
    'JPY',
    'CNY',
    'INR',
    'BRL',
    'RUB',
    'ZAR',
    'NGN',
    'GHS',
    'KES',
    'XOF',
    'XAF',
  ];

  static const Map<String, String> _currencyLabels = {
    'DA': 'DA – Dinar Algérien',
    'EUR': '€ – Euro',
    'USD': r'$ – Dollar US',
    'GBP': '£ – Livre Sterling',
    'MAD': 'MAD – Dirham Marocain',
    'TND': 'TND – Dinar Tunisien',
    'LYD': 'LYD – Dinar Libyen',
    'EGP': 'EGP – Livre Égyptienne',
    'SAR': 'SAR – Riyal Saoudien',
    'AED': 'AED – Dirham Émirati',
    'QAR': 'QAR – Riyal Qatari',
    'KWD': 'KWD – Dinar Koweïtien',
    'BHD': 'BHD – Dinar Bahreïni',
    'OMR': 'OMR – Rial Omanais',
    'JOD': 'JOD – Dinar Jordanien',
    'TRY': '₺ – Livre Turque',
    'CHF': 'CHF – Franc Suisse',
    'CAD': r'CAD – Dollar Canadien',
    'AUD': r'AUD – Dollar Australien',
    'JPY': '¥ – Yen Japonais',
    'CNY': '¥ – Yuan Chinois',
    'INR': '₹ – Roupie Indienne',
    'BRL': r'R$ – Réal Brésilien',
    'RUB': '₽ – Rouble Russe',
    'ZAR': 'ZAR – Rand Sud-Africain',
    'NGN': '₦ – Naira Nigérian',
    'GHS': 'GHS – Cedi Ghanéen',
    'KES': 'KES – Shilling Kényan',
    'XOF': 'XOF – Franc CFA (BCEAO)',
    'XAF': 'XAF – Franc CFA (BEAC)',
  };

  // ── Legal IDs Popup ────────────────────────────────────────
  Future<void> _showLegalIdsDialog() async {
    // Parse existing value into NIF and RC
    final existing = _companyTaxIdCtrl.text;
    String nifValue = '';
    String rcValue = '';

    final nifMatch = RegExp(r'NIF\s*:\s*([^•\n]+)').firstMatch(existing);
    final rcMatch = RegExp(r'RC\s*:\s*([^•\n]+)').firstMatch(existing);
    if (nifMatch != null) nifValue = nifMatch.group(1)!.trim();
    if (rcMatch != null) rcValue = rcMatch.group(1)!.trim();

    final nifCtrl = TextEditingController(text: nifValue);
    final rcCtrl = TextEditingController(text: rcValue);

    final saved = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: AppConstants.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Identifiants Légaux",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Modifiez chaque champ séparément",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nifCtrl,
                  decoration: InputDecoration(
                    labelText: "NIF (Numéro d'Identification Fiscale)",
                    hintText: "ex: 001916012345678",
                    prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: rcCtrl,
                  decoration: InputDecoration(
                    labelText: "RC (Registre de Commerce)",
                    hintText: "ex: 16/00-1234567",
                    prefixIcon: const Icon(Icons.article_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Annuler"),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text(
                  "Valider",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
    );

    if (saved == true) {
      final parts = <String>[];
      if (nifCtrl.text.trim().isNotEmpty) {
        parts.add('NIF: ${nifCtrl.text.trim()}');
      }
      if (rcCtrl.text.trim().isNotEmpty) {
        parts.add('RC: ${rcCtrl.text.trim()}');
      }
      setState(() {
        _companyTaxIdCtrl.text = parts.join(' • ');
      });
    }

    nifCtrl.dispose();
    rcCtrl.dispose();
  }
}
