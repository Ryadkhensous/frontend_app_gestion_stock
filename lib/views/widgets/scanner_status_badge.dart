import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/scanner_service.dart';
import '../../services/feedback_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/stock_provider.dart';
import '../../models/product.dart';
import '../../utils/constants.dart';

class ScannerStatusBadge extends StatelessWidget {
  final bool compact;

  const ScannerStatusBadge({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scannerService = context.watch<ScannerService>();
    final isConnected = scannerService.isConnected;

    return InkWell(
      onTap: () => _showStatusDetails(context, scannerService),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          gradient: isConnected
              ? const LinearGradient(
                  colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.grey.shade50, Colors.grey.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isConnected
                ? const Color(0xFF10B981).withValues(alpha: 0.45)
                : Colors.grey.shade300,
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: isConnected
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicateur lumineux pulsant
            _PulsingDot(isActive: isConnected),
            const SizedBox(width: 6),
            Icon(
              isConnected
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_disabled_rounded,
              size: compact ? 15 : 17,
              color: isConnected ? const Color(0xFF059669) : Colors.grey.shade600,
            ),
            if (!compact) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  isConnected ? scannerService.deviceName : "Douchette off",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isConnected
                        ? const Color(0xFF065F46)
                        : Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showStatusDetails(BuildContext context, ScannerService scannerService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ScannerStatusModal(scannerService: scannerService),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final bool isActive;

  const _PulsingDot({required this.isActive});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(
                  alpha: 0.3 + 0.4 * _controller.value,
                ),
                blurRadius: 4 + 4 * _controller.value,
                spreadRadius: 1 + 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScannerStatusModal extends StatefulWidget {
  final ScannerService scannerService;

  const _ScannerStatusModal({required this.scannerService});

  @override
  State<_ScannerStatusModal> createState() => _ScannerStatusModalState();
}

class _ScannerStatusModalState extends State<_ScannerStatusModal> {
  final TextEditingController _testCtrl = TextEditingController();

  @override
  void dispose() {
    _testCtrl.dispose();
    super.dispose();
  }

  void _processCode(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;
    final settings = context.read<SettingsProvider>();
    FeedbackService.scanSuccess(
      haptic: settings.enableHaptic,
      sound: settings.enableSound,
    );
    widget.scannerService.triggerBarcodeScan(code, deviceSource: "Test Douchette (Saisie Directe)");
    _testCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.scannerService,
      builder: (context, _) {
        final s = widget.scannerService;
        final isConnected = s.isConnected;

        // Recherche du produit correspondant dans le stock actuel
        final stockProv = context.watch<StockProvider>();
        Product? matchedProduct;
        if (s.lastScannedBarcode != null) {
          final query = s.lastScannedBarcode!.trim().toLowerCase();
          try {
            matchedProduct = stockProv.products.firstWhere(
              (p) => p.sku.trim().toLowerCase() == query || p.id.toString() == query,
            );
          } catch (_) {
            try {
              matchedProduct = stockProv.products.firstWhere(
                (p) => p.name.trim().toLowerCase().contains(query),
              );
            } catch (_) {}
          }
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barre de poignée
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // En-tête
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isConnected ? Icons.barcode_reader : Icons.bluetooth_searching,
                          color: isConnected ? const Color(0xFF059669) : Colors.orange.shade800,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Lecteur Code-Barres & Douchette",
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              isConnected
                                  ? "🟢 Connecté en Mode Clavier HID (Prêt)"
                                  : "⚪ En attente de scan ou déconnecté",
                              style: TextStyle(
                                fontSize: 13,
                                color: isConnected ? const Color(0xFF059669) : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Carte Statut Matériel & Scan Réel
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isConnected ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isConnected ? const Color(0xFFBBF7D0) : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        _StatusRow(
                          label: "État de connexion",
                          value: isConnected ? "🟢 En ligne (Prêt au scan)" : "⚪ Déconnecté / En veille",
                          valueColor: isConnected ? const Color(0xFF065F46) : Colors.grey.shade700,
                          isBold: true,
                        ),
                        const Divider(height: 14),
                        _StatusRow(
                          label: "Appareil détecté",
                          value: isConnected ? s.deviceName : "Aucun périphérique HID externe",
                        ),
                        const Divider(height: 14),
                        _StatusRow(
                          label: "Dernier code scanné",
                          value: s.lastScannedBarcode ?? "Aucun scan récent",
                          isCode: s.lastScannedBarcode != null,
                          valueColor: s.lastScannedBarcode != null ? const Color(0xFF1D4ED8) : null,
                          isBold: s.lastScannedBarcode != null,
                        ),
                        if (s.lastScannedBarcode != null) ...[
                          const Divider(height: 14),
                          _StatusRow(
                            label: "Article identifié",
                            value: matchedProduct != null
                                ? "📦 ${matchedProduct.name} (${matchedProduct.quantity} en stock)"
                                : "ℹ️ Référence absente du catalogue",
                            valueColor: matchedProduct != null ? const Color(0xFF059669) : Colors.amber.shade900,
                            isBold: true,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Zone de Test en direct
                  const Text(
                    "Tester votre lecteur ou simuler un scan :",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _testCtrl,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: "Scannez ou saisissez un code puis tapez Entrée...",
                      prefixIcon: const Icon(Icons.qr_code_scanner, color: AppConstants.primary),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded, size: 18, color: AppConstants.primary),
                        onPressed: () => _processCode(_testCtrl.text),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (code) => _processCode(code),
                  ),
                  const SizedBox(height: 8),

                  // Boutons de test rapide en 1-clic
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _processCode("REF-260908-6949"),
                        icon: const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF4F46E5)),
                        label: const Text(
                          "Tester Surface 8 Pro (REF-260908-6949)",
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (isConnected)
                        TextButton.icon(
                          onPressed: () {
                            widget.scannerService.resetStatus();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.grey),
                          label: const Text("Réinitialiser", style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Guide d'explication
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Comment fonctionne la détection réelle ?",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "• Mode HID Universel : N'importe quelle douchette (USB ou Bluetooth) agit comme un clavier rapide. Dès le premier scan, l'application capte le code et passe au vert.\n"
                                "• Sur Android : Associez la douchette dans Paramètres Bluetooth.\n"
                                "• Prêt à l'emploi : Les scans alimentent automatiquement la Caisse POS, l'Inventaire et la Réception de stock.",
                                style: TextStyle(fontSize: 11.5, color: Colors.blue.shade800, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bouton pour fermer
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Fermer"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  final bool isCode;

  const _StatusRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppConstants.textPrimary,
              fontFamily: isCode ? 'monospace' : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
