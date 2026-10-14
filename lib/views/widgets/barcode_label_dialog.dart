import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/product.dart';
import '../../utils/constants.dart';
import '../../utils/barcode_painter.dart';

class BarcodeLabelDialog extends StatefulWidget {
  final Product product;

  const BarcodeLabelDialog({super.key, required this.product});

  @override
  State<BarcodeLabelDialog> createState() => _BarcodeLabelDialogState();
}

class _BarcodeLabelDialogState extends State<BarcodeLabelDialog> {
  int _copies = 1;
  String _selectedFormat = "THERMAL_50X30"; // "THERMAL_50X30" | "A4_SHEET"

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 0, locale: 'fr_FR');
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Entête
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Impression d'Étiquette Code-Barres",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Contenu
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "Aperçu de l'étiquette thermique de rayon / emballage :",
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),

                  // Simulation de l'étiquette autocollante thermique
                  Container(
                    width: 320,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // En-tête magasin
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "STOCKIO",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.8, color: Color(0xFF334155)),
                            ),
                            Text(
                              DateFormat('MM/yy').format(DateTime.now()),
                              style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Nom de l'article
                        Text(
                          widget.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), height: 1.2),
                        ),
                        const SizedBox(height: 8),

                        // Tracé du code-barres 1D standard (Code 128)
                        BarcodeWidget(
                          data: widget.product.sku.isNotEmpty ? widget.product.sku : "SKU-${widget.product.id}",
                          height: 46,
                          showText: true,
                          textStyle: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Prix de vente
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("PRIX : ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              Text(
                                currencyFormat.format(widget.product.price),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppConstants.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Sélecteur de format
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.receipt_long, size: 16),
                        label: const Text("Thermique (50x30mm)", style: TextStyle(fontSize: 12)),
                        selected: _selectedFormat == "THERMAL_50X30",
                        selectedColor: AppConstants.primary.withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => _selectedFormat = "THERMAL_50X30"),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.grid_on_rounded, size: 16),
                        label: const Text("Planche A4 (24 étiquettes)", style: TextStyle(fontSize: 12)),
                        selected: _selectedFormat == "A4_SHEET",
                        selectedColor: AppConstants.primary.withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => _selectedFormat = "A4_SHEET"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Sélecteur de nombre de copies
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text("Nombre d'exemplaires :", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppConstants.primary),
                            onPressed: _copies > 1 ? () => setState(() => _copies--) : null,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              "$_copies",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppConstants.primary),
                            onPressed: () => setState(() => _copies++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Pied de page
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text("Copier SKU"),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.product.sku));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("SKU ${widget.product.sku} copié !"),
                          backgroundColor: AppConstants.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: Text("Imprimer ($_copies)"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Ordre d'impression envoyé : $_copies étiquette(s) pour ${widget.product.name} (${widget.product.sku})",
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: AppConstants.success,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
