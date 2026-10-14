import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/commercial_document.dart';
import '../../utils/constants.dart';

/// Affiche un pop-up de confirmation avant de modifier un bon (notamment un Bon de Livraison).
/// Retourne `true` si l'utilisateur confirme vouloir modifier le document.
Future<bool?> showDocumentEditConfirmDialog(BuildContext context, CommercialDocument doc) {
  final isDelivery = doc.isDelivery;
  final isDelivered = doc.isDelivered;
  final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 2, locale: 'fr_FR');
  final dateFormat = DateFormat('dd/MM/yyyy');

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDelivered ? const Color(0xFFF59E0B) : const Color(0xFF0D9488))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDelivered ? Icons.warning_amber_rounded : Icons.edit_note_rounded,
              color: isDelivered ? const Color(0xFFD97706) : const Color(0xFF0D9488),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDelivery ? "Modifier le Bon de Livraison" : "Modifier le Document",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  doc.referenceNumber,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDelivery ? const Color(0xFF0D9488) : AppConstants.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carte récapitulative du document
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        doc.partnerName ?? (doc.pointOfSaleName ?? 'Client au comptoir'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        dateFormat.format(doc.issueDate),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${doc.totalItemsCount} article(s)",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                      Text(
                        currencyFormat.format(doc.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Message d'avertissement ou d'information selon le statut
            if (isDelivered) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Impact sur le stock physique :",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Ce bon de livraison est déjà marqué comme LIVRÉ.\n"
                            "Si vous validez des modifications, les anciens mouvements de stock seront automatiquement réajustés pour refléter les nouvelles quantités.",
                            style: TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.help_outline_rounded, color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Modifier les informations :",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF166534),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Vous pouvez ajuster les articles, prix, quantités, partenaires et notes de ce bon.",
                            style: TextStyle(fontSize: 11, color: Color(0xFF15803D), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Text(
              "Souhaitez-vous continuer et ouvrir l'écran de modification ?",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text("Annuler"),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.edit_rounded, size: 16),
          label: const Text("Continuer la modification"),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDelivery ? const Color(0xFF0D9488) : AppConstants.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    ),
  );
}
