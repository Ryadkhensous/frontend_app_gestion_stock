import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/commercial_document.dart';
import '../../providers/stock_provider.dart';
import '../../utils/constants.dart';
import 'pdf_preview_dialog.dart';
import 'document_form_dialog.dart';
import 'document_edit_confirm_dialog.dart';

class DocumentPreviewDialog extends StatelessWidget {
  final CommercialDocument document;

  const DocumentPreviewDialog({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 2, locale: 'fr_FR');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isDelivery = document.isDelivery;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final companyInfoWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.all_inbox_rounded, color: AppConstants.primary, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "STOCKIO",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    "Logistique & Distribution Multi-points",
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text("Tél : +213 (0) 23 45 67 89 | contact@gestionstock.com", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );

    final documentBadgeWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDelivery ? const Color(0xFF0D9488).withValues(alpha: 0.1) : AppConstants.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDelivery ? const Color(0xFF0D9488).withValues(alpha: 0.3) : AppConstants.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            isDelivery ? "BON DE LIVRAISON" : "BON DE COMMANDE",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDelivery ? const Color(0xFF0D9488) : AppConstants.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            document.referenceNumber,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );

    final destinataireBox = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDelivery ? "DESTINATAIRE / LIVRÉ À :" : "ÉMIS POUR / PARTENAIRE :",
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Text(
            document.partnerName?.isNotEmpty == true
                ? document.partnerName!
                : (document.pointOfSaleName ?? "Client au comptoir"),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
          ),
          if (document.pointOfSaleName != null && document.partnerName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text("Magasin : ${document.pointOfSaleName}", style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              "Flux : ${document.directionLabel}",
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );

    final metadataBox = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Date d'émission :", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Text(dateFormat.format(document.issueDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          if (document.deliveryDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Date livraison :", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text(dateFormat.format(document.deliveryDate!), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (document.parentDocumentReference != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Commande N° :", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text(document.parentDocumentReference!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.primary)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Statut actuel :", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              _buildStatusBadge(document.status, document.statusLabel),
            ],
          ),
        ],
      ),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: isMobile ? 12 : 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750, maxHeight: 850),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            children: [
              // Barre d'actions du haut
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDelivery ? Icons.local_shipping_rounded : Icons.shopping_bag_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isDelivery ? "Aperçu Bon de Livraison" : "Aperçu Bon de Commande",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                      tooltip: "Imprimer / Exporter",
                      onPressed: () => _showPrintExportDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Contenu du document (Feuille A4 stylisée)
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 14 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Entête de la société & Type de document
                      if (isMobile) ...[
                        companyInfoWidget,
                        const SizedBox(height: 10),
                        documentBadgeWidget,
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: companyInfoWidget),
                            documentBadgeWidget,
                          ],
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(thickness: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),

                      // Bloc Informations Date, Tiers et Statut
                      if (isMobile) ...[
                        destinataireBox,
                        const SizedBox(height: 10),
                        metadataBox,
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: destinataireBox),
                            const SizedBox(width: 16),
                            Expanded(child: metadataBox),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Tableau des articles
                      const Text(
                        "Détail des Articles",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: isMobile ? 500 : 650,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                // Header du tableau
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(flex: 5, child: Text("Désignation / Réf", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                                      Expanded(flex: 2, child: Text("Qté", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                                      Expanded(flex: 3, child: Text("Prix U. HT", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                                      Expanded(flex: 3, child: Text("Total HT", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                                    ],
                                  ),
                                ),

                                // Lignes des articles
                                ...document.items.map((it) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: const BoxDecoration(
                                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                it.productName ?? "Article #${it.productId}",
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                                              ),
                                              if (it.productSku != null && it.productSku!.isNotEmpty)
                                                Text("SKU: ${it.productSku}", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            "${it.quantity}",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              currencyFormat.format(it.unitPrice),
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              currencyFormat.format(it.totalPrice),
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Récapitulatif Totaux
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: isMobile ? double.infinity : 280,
                          padding: const EdgeInsets.all(14),
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
                                  const Text("Total Articles :", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  Text("${document.totalItemsCount} unités", style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Divider(thickness: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("MONTANT TOTAL :", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        currencyFormat.format(document.totalAmount),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: isDelivery ? const Color(0xFF0D9488) : AppConstants.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (document.notes != null && document.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Notes / Instructions : ${document.notes}",
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Zones de Signatures
                      if (isMobile) ...[
                        Container(
                          height: 80,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Visa & Cachet Émetteur :", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 80,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDelivery ? "Date & Signature Réceptionnaire :" : "Bon pour accord Partenaire :",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 100,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Visa & Cachet Émetteur :", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Container(
                                height: 100,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDelivery ? "Date & Signature Réceptionnaire :" : "Bon pour accord Partenaire :",
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Barre d'actions en bas
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text("PDF / Impression Pro"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => PdfPreviewDialog(document: document),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text("Copier texte"),
                      onPressed: () => _showPrintExportDialog(context),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0D9488)),
                      label: const Text("Modifier"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D9488),
                        side: const BorderSide(color: Color(0xFF0D9488)),
                      ),
                      onPressed: () => _handleEditDocument(context),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (document.isOrder) ...[
                          ElevatedButton.icon(
                            onPressed: () => _handleConvertToDelivery(context),
                            icon: const Icon(Icons.transform_rounded, size: 16),
                            label: const Text("Convertir en BL"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ] else if (document.isDelivery && document.status != 'DELIVERED') ...[
                          ElevatedButton.icon(
                            onPressed: () => _handleMarkAsDelivered(context),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                            label: const Text("Valider Livraison"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.success,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Fermer"),
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
  }

  String _generateDocumentText() {
    final StringBuffer sb = StringBuffer();
    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 2, locale: 'fr_FR');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    sb.writeln("================================================");
    sb.writeln("                  STOCKIO                       ");
    sb.writeln("      Logistique & Distribution Multi-points    ");
    sb.writeln("================================================");
    sb.writeln(document.isDelivery ? ">> BON DE LIVRAISON <<" : ">> BON DE COMMANDE <<");
    sb.writeln("N° Référence : ${document.referenceNumber}");
    sb.writeln("Date         : ${dateFormat.format(document.issueDate)}");
    sb.writeln("Statut       : ${document.statusLabel}");
    sb.writeln("Flux         : ${document.directionLabel}");
    sb.writeln("Partenaire   : ${document.partnerName ?? (document.pointOfSaleName ?? 'Client au comptoir')}");
    if (document.pointOfSaleName != null) {
      sb.writeln("Magasin / POS: ${document.pointOfSaleName}");
    }
    if (document.parentDocumentReference != null) {
      sb.writeln("Lié au Bon   : ${document.parentDocumentReference}");
    }
    sb.writeln("------------------------------------------------");
    sb.writeln("DÉTAIL DES ARTICLES :");
    for (var i = 0; i < document.items.length; i++) {
      final it = document.items[i];
      sb.writeln("${i + 1}. ${it.productName ?? 'Produit #${it.productId}'}");
      if (it.productSku?.isNotEmpty == true) {
        sb.writeln("   SKU: ${it.productSku}");
      }
      sb.writeln("   Qté: ${it.quantity} x ${currencyFormat.format(it.unitPrice)} = ${currencyFormat.format(it.totalPrice)}");
    }
    sb.writeln("------------------------------------------------");
    sb.writeln("TOTAL ARTICLES : ${document.totalItemsCount} article(s)");
    sb.writeln("MONTANT TOTAL  : ${currencyFormat.format(document.totalAmount)}");
    if (document.notes?.isNotEmpty == true) {
      sb.writeln("------------------------------------------------");
      sb.writeln("Notes : ${document.notes}");
    }
    sb.writeln("================================================");
    sb.writeln("Document généré par Stockio");
    return sb.toString();
  }

  void _showPrintExportDialog(BuildContext context) {
    final textContent = _generateDocumentText();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: AppConstants.primary, size: 22),
            const SizedBox(width: 8),
            Text("Imprimer / Partager (${document.referenceNumber})", style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Aperçu du ticket / document prêt à l'impression :",
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Container(
                height: 250,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    textContent,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFF8FAFC),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fermer"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text("Copier le texte"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: textContent));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Bon ${document.referenceNumber} copié dans le presse-papier !"),
                  backgroundColor: AppConstants.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleEditDocument(BuildContext context) async {
    final confirm = await showDocumentEditConfirmDialog(context, document);
    if (confirm == true && context.mounted) {
      Navigator.of(context).pop(); // Fermer l'aperçu
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DocumentFormDialog(documentToEdit: document),
      );
    }
  }

  Future<void> _handleConvertToDelivery(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Générer le Bon de Livraison"),
        content: Text("Voulez-vous transformer la commande ${document.referenceNumber} en Bon de Livraison ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final provider = context.read<StockProvider>();
    final ok = await provider.convertOrderToDelivery(document.id);

    if (context.mounted) {
      if (ok) {
        Navigator.pop(context); // Fermer aperçu
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bon de Livraison généré avec succès !"),
            backgroundColor: AppConstants.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? "Erreur lors de la conversion"),
            backgroundColor: AppConstants.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleMarkAsDelivered(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Valider la Livraison"),
        content: Text(
          "Valider le bon ${document.referenceNumber} mettra à jour automatiquement les stocks des articles.\n"
          "Confirmer la validation ?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.success, foregroundColor: Colors.white),
            child: const Text("Valider et déduire stocks"),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final provider = context.read<StockProvider>();
    final ok = await provider.updateDocumentStatus(document.id, 'DELIVERED');

    if (context.mounted) {
      if (ok) {
        Navigator.pop(context); // Fermer aperçu
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bon de livraison ${document.referenceNumber} validé et stock mis à jour !"),
            backgroundColor: AppConstants.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? "Erreur lors de la validation"),
            backgroundColor: AppConstants.danger,
          ),
        );
      }
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
