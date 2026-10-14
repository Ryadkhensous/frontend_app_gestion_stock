import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/seller.dart';
import '../../providers/stock_provider.dart';
import '../../utils/constants.dart';

class SellerFormDialog extends StatefulWidget {
  final Seller? seller;

  const SellerFormDialog({super.key, this.seller});

  @override
  State<SellerFormDialog> createState() => _SellerFormDialogState();
}

class _SellerFormDialogState extends State<SellerFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _commissionRateCtrl;

  bool _obscurePassword = true;
  bool _isActive = true;
  int? _selectedPosId;
  bool _isSaving = false;

  bool get _isEditing => widget.seller != null;

  @override
  void initState() {
    super.initState();
    final s = widget.seller;
    _fullNameCtrl = TextEditingController(text: s?.fullName ?? '');
    _usernameCtrl = TextEditingController(text: s?.username ?? '');
    _passwordCtrl = TextEditingController();
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');
    _commissionRateCtrl = TextEditingController(
      text: s != null ? s.commissionRate.toString() : '5.0',
    );
    _isActive = s?.isActive ?? true;
    _selectedPosId = s?.pointOfSaleId;
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _commissionRateCtrl.dispose();
    super.dispose();
  }

  void _applyQuickCommission(double rate) {
    setState(() {
      _commissionRateCtrl.text = rate.toString();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<StockProvider>();
    final commission = double.tryParse(_commissionRateCtrl.text.replaceAll(',', '.')) ?? 0.0;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        final payload = <String, dynamic>{
          "full_name": _fullNameCtrl.text.trim(),
          "phone": _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
          "email": _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
          "commission_rate": commission,
          "point_of_sale_id": _selectedPosId,
          "is_active": _isActive,
        };
        if (_passwordCtrl.text.trim().isNotEmpty) {
          payload["password"] = _passwordCtrl.text.trim();
        }

        final success = await provider.updateSeller(widget.seller!.id, payload);
        if (mounted) {
          if (success) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Vendeur mis à jour avec succès !"),
                backgroundColor: AppConstants.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.errorMessage ?? "Erreur lors de la modification"),
                backgroundColor: AppConstants.danger,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        final payload = <String, dynamic>{
          "username": _usernameCtrl.text.trim().toLowerCase(),
          "password": _passwordCtrl.text.trim(),
          "full_name": _fullNameCtrl.text.trim(),
          "phone": _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
          "email": _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
          "commission_rate": commission,
          "point_of_sale_id": _selectedPosId,
          "is_active": _isActive,
        };

        final success = await provider.createSeller(payload);
        if (mounted) {
          if (success) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Compte vendeur créé avec succès !"),
                backgroundColor: AppConstants.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.errorMessage ?? "Erreur lors de la création"),
                backgroundColor: AppConstants.danger,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final posList = stockProvider.pointsOfSale;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                          color: const Color(0xFF4F46E5),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? "Modifier le Vendeur" : "Nouveau Vendeur",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              _isEditing
                                  ? "Ajustez le taux de commission ou les accès"
                                  : "Créez un compte dédié avec suivi des commissions",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                        tooltip: "Fermer",
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 18),

                  // 1. Nom complet
                  TextFormField(
                    controller: _fullNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Nom et Prénom du Vendeur *",
                      hintText: "ex: Karim Benali",
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? "Nom requis" : null,
                  ),
                  const SizedBox(height: 14),

                  // 2. Identifiant & Mot de passe
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _usernameCtrl,
                          enabled: !_isEditing,
                          decoration: InputDecoration(
                            labelText: "Identifiant (Username) *",
                            hintText: "ex: karim_vendeur",
                            prefixIcon: const Icon(Icons.alternate_email_rounded),
                            helperText: _isEditing ? "Non modifiable" : null,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Identifiant requis";
                            if (v.trim().length < 3) return "Min. 3 caractères";
                            if (v.contains(' ')) return "Pas d'espaces";
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: _isEditing ? "Nouveau Mot de Passe" : "Mot de Passe *",
                            hintText: _isEditing ? "Laisser vide si inchangé" : "Min. 4 car.",
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (!_isEditing && (v == null || v.trim().length < 4)) {
                              return "Min. 4 caractères";
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Téléphone & Email
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: "Téléphone",
                            hintText: "ex: 0550 12 34 56",
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: "Email (Optionnel)",
                            hintText: "vendeur@magasin.com",
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 4. Section Commission
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.percent_rounded, size: 18, color: Color(0xFF15803D)),
                            SizedBox(width: 8),
                            Text(
                              "Taux de Commission sur les Ventes (%)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _commissionRateCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: "Commission (%)",
                                  hintText: "ex: 5.0",
                                  suffixText: "%",
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return "Taux requis";
                                  final num = double.tryParse(v.replaceAll(',', '.'));
                                  if (num == null || num < 0 || num > 100) {
                                    return "Entre 0 et 100%";
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [2.0, 5.0, 7.5, 10.0].map((rate) {
                                  final isCurrent = _commissionRateCtrl.text == rate.toString();
                                  return ChoiceChip(
                                    label: Text("${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1)}%"),
                                    selected: isCurrent,
                                    onSelected: (_) => _applyQuickCommission(rate),
                                    selectedColor: const Color(0xFF16A34A),
                                    labelStyle: TextStyle(
                                      color: isCurrent ? Colors.white : const Color(0xFF166534),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Point de Vente rattaché
                  DropdownButtonFormField<int?>(
                    value: _selectedPosId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Point de Vente ou Dépôt Assigné",
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          "Aucun (Tous les points de vente)",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...posList.map((pos) => DropdownMenuItem<int?>(
                            value: pos.id,
                            child: Text(
                              "${pos.name} (${pos.city ?? 'Dépôt'})",
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (val) => setState(() => _selectedPosId = val),
                  ),
                  const SizedBox(height: 14),

                  // 6. Statut Actif / Inactif
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Compte Actif",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      "Permet au vendeur de se connecter et d'enregistrer des ventes",
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _isActive,
                    activeColor: const Color(0xFF16A34A),
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                  const SizedBox(height: 20),

                  // Boutons d'action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: const Text("Annuler"),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submitForm,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          _isSaving
                              ? "Enregistrement..."
                              : (_isEditing ? "Enregistrer" : "Créer le Vendeur"),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
