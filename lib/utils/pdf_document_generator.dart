import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/commercial_document.dart';

class PdfDocumentGenerator {
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  /// Génère un document vectoriel A4 (Bon de Commande ou Bon de Livraison)
  /// Bug 3.3 : utilise pw.MultiPage au lieu de pw.Page pour gérer la pagination automatique
  static Future<Uint8List> generateA4Document(
    CommercialDocument doc, {
    String companyName = "Stockio",
    String companyPhone = "+213 (0) 550 12 34 56",
    String companyAddress = "Alger, Algérie",
    String currencySymbol = "DA",
  }) async {
    final pdf = pw.Document();
    final currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: currencySymbol, decimalDigits: 2);

    final isOrder = doc.isOrder;
    final docTitle = isOrder ? "BON DE COMMANDE" : "BON DE LIVRAISON";
    final docColor = isOrder ? PdfColors.indigo700 : PdfColors.teal700;

    // En-tête répété sur chaque page
    pw.Widget buildHeader(pw.Context context) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    doc.pointOfSaleName ?? companyAddress,
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    "Tél : $companyPhone",
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: docColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      docTitle,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "N° ${doc.referenceNumber}",
                      style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          // Bloc d'informations : Tiers et Date
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      isOrder ? "Fournisseur / Destinataire :" : "Client / Tiers :",
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      doc.partnerName != null && doc.partnerName!.isNotEmpty
                          ? doc.partnerName!
                          : (doc.pointOfSaleName ?? "Client au Comptoir"),
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                    ),
                    if (doc.pointOfSaleName != null)
                      pw.Text(
                        "Point de Vente : ${doc.pointOfSaleName}",
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Date d'émission : ${_dateFmt.format(doc.issueDate)}",
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: _getStatusBgColor(doc.status),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        doc.statusLabel,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _getStatusTextColor(doc.status),
                        ),
                      ),
                    ),
                    if (doc.parentDocumentReference != null)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(
                          "Réf Origine : ${doc.parentDocumentReference}",
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],
      );
    }

    // Pied de page répété sur chaque page
    pw.Widget buildFooter(pw.Context context) {
      return pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          "Page ${context.pageNumber} / ${context.pagesCount}",
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      );
    }

    pdf.addPage(
      // Bug 3.3 : MultiPage gère automatiquement la pagination sans débordement
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: buildHeader,
        footer: buildFooter,
        build: (pw.Context context) => [
          // Tableau des Articles
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(4.5), // Désignation
              1: const pw.FlexColumnWidth(2.5), // SKU
              2: const pw.FlexColumnWidth(1.5), // Qté
              3: const pw.FlexColumnWidth(2.5), // Prix U.
              4: const pw.FlexColumnWidth(2.5), // Total Ligne
            },
            children: [
              // En-tête tableau
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader("Désignation"),
                  _buildTableHeader("Réf / SKU"),
                  _buildTableHeader("Qté", align: pw.TextAlign.center),
                  _buildTableHeader("Prix Unit.", align: pw.TextAlign.right),
                  _buildTableHeader("Total", align: pw.TextAlign.right),
                ],
              ),
              // Lignes des articles
              ...doc.items.map((item) {
                return pw.TableRow(
                  children: [
                    _buildTableCell(item.productName),
                    _buildTableCell(item.productSku?.isNotEmpty == true ? item.productSku! : "-"),
                    _buildTableCell(item.quantity.toString(), align: pw.TextAlign.center),
                    _buildTableCell(currencyFmt.format(item.unitPrice), align: pw.TextAlign.right),
                    _buildTableCell(currencyFmt.format(item.totalPrice), align: pw.TextAlign.right, isBold: true),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),

          // Bloc Total & Notes
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Notes éventuelles
              pw.Expanded(
                flex: 5,
                child: doc.notes != null && doc.notes!.isNotEmpty
                    ? pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("Observations :", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text(doc.notes!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          ],
                        ),
                      )
                    : pw.Container(),
              ),
              pw.SizedBox(width: 20),
              // Récapitulatif Total
              pw.Expanded(
                flex: 4,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Total Articles :", style: const pw.TextStyle(fontSize: 11)),
                          pw.Text("${doc.items.fold(0, (acc, item) => acc + item.quantity)} unités",
                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Divider(color: PdfColors.grey300),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Net à Payer :",
                              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            currencyFmt.format(doc.totalAmount),
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: docColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 40),

          // Zone de signatures (pas de pw.Spacer() → incompatible avec MultiPage)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text("Signature du Client / Réceptionnaire", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.SizedBox(height: 40),
                  pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text("Cachet & Signature Société", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.SizedBox(height: 40),
                  pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              "Document officiel généré par le Système de Gestion de Stock & Caisse POS",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Génère un ticket de caisse thermique 80mm
  static Future<Uint8List> generateThermalReceipt({
    required CommercialDocument doc,
    required String paymentMethod,
    required double amountTendered,
    required double changeDue,
    String companyName = "Stockio",
    String receiptFooter = "Merci pour votre visite !",
    String currencySymbol = "DA",
  }) async {
    final pdf = pw.Document();
    final currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: currencySymbol, decimalDigits: 2);

    // Largeur standard rouleau thermique 80mm
    const double receiptWidth = 72 * PdfPageFormat.mm;
    final receiptFormat = PdfPageFormat(
      receiptWidth,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: receiptFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(companyName.toUpperCase(), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text(doc.pointOfSaleName ?? "Caisse Magasin", style: const pw.TextStyle(fontSize: 10)),
              pw.Text("Ticket N° ${doc.referenceNumber}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.Text(_dateFmt.format(doc.issueDate), style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 4),

              // Liste des articles
              pw.Column(
                children: doc.items.map((it) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(it.productName ?? "Article #${it.productId}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.Text("${it.quantity} x ${currencyFmt.format(it.unitPrice)}",
                                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                        pw.Text(currencyFmt.format(it.totalPrice),
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
              ),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 4),

              // Totaux & Monnaie
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL TTC :", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(currencyFmt.format(doc.totalAmount),
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Paiement :", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(paymentMethod, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (amountTendered > doc.totalAmount) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Espèces reçues :", style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(currencyFmt.format(amountTendered), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Monnaie rendue :", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(currencyFmt.format(changeDue),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],

              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Text(receiptFooter,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
      ),
    );
  }

  static pw.Widget _buildTableCell(String? text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text ?? "",
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.blueGrey800,
        ),
      ),
    );
  }

  static PdfColor _getStatusBgColor(String status) {
    switch (status) {
      case 'DELIVERED':
        return PdfColors.green100;
      case 'VALIDATED':
        return PdfColors.amber100;
      case 'CANCELLED':
        return PdfColors.red100;
      default:
        return PdfColors.grey200;
    }
  }

  static PdfColor _getStatusTextColor(String status) {
    switch (status) {
      case 'DELIVERED':
        return PdfColors.green900;
      case 'VALIDATED':
        return PdfColors.amber900;
      case 'CANCELLED':
        return PdfColors.red900;
      default:
        return PdfColors.grey800;
    }
  }
}
