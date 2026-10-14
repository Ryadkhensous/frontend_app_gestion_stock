import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../models/commercial_document.dart';
import '../../providers/settings_provider.dart';
import '../../utils/constants.dart';
import '../../utils/pdf_document_generator.dart';

class PdfPreviewDialog extends StatefulWidget {
  final CommercialDocument document;
  final bool? isThermalReceipt;
  final String? paymentMethod;
  final double? amountTendered;
  final double? changeDue;

  const PdfPreviewDialog({
    super.key,
    required this.document,
    this.isThermalReceipt,
    this.paymentMethod,
    this.amountTendered,
    this.changeDue,
  });

  @override
  State<PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<PdfPreviewDialog> {
  late bool _isThermal;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _isThermal = widget.isThermalReceipt ?? (settings.defaultPrintFormat == "THERMAL_80MM");
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final settings = context.watch<SettingsProvider>();

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 36,
        vertical: isMobile ? 16 : 32,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: _isThermal ? 480 : 840,
        height: size.height * 0.88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Entête dialog avec switcher de format
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isThermal ? Icons.receipt_long_rounded : Icons.picture_as_pdf_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isThermal
                          ? "Ticket 80mm (${widget.document.referenceNumber})"
                          : "Document A4 Pro (${widget.document.referenceNumber})",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Sélecteur de format direct
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FormatTabButton(
                          title: "80mm",
                          icon: Icons.receipt_long_rounded,
                          isSelected: _isThermal,
                          onTap: () => setState(() => _isThermal = true),
                        ),
                        _FormatTabButton(
                          title: "A4",
                          icon: Icons.picture_as_pdf_rounded,
                          isSelected: !_isThermal,
                          onTap: () => setState(() => _isThermal = false),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Visualiseur d'impression Printing
            Expanded(
              child: PdfPreview(
                build: (format) => _isThermal
                    ? PdfDocumentGenerator.generateThermalReceipt(
                        doc: widget.document,
                        paymentMethod: widget.paymentMethod ?? "Espèces",
                        amountTendered: widget.amountTendered ?? widget.document.totalAmount,
                        changeDue: widget.changeDue ?? 0.0,
                        companyName: settings.companyName,
                        receiptFooter: settings.receiptFooter,
                        currencySymbol: settings.currencySymbol,
                      )
                    : PdfDocumentGenerator.generateA4Document(
                        widget.document,
                        companyName: settings.companyName,
                        companyPhone: settings.companyPhone,
                        companyAddress: settings.companyAddress,
                        currencySymbol: settings.currencySymbol,
                      ),
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                dynamicLayout: false,
                pdfFileName: "${widget.document.referenceNumber}.pdf",
                previewPageMargin: const EdgeInsets.all(8),
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: AppConstants.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatTabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatTabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
