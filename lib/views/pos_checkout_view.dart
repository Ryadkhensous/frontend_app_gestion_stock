import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/commercial_document.dart';
import '../providers/stock_provider.dart';
import '../providers/auth_provider.dart';
import '../services/scanner_service.dart';
import '../utils/constants.dart';
import 'widgets/scanner_status_badge.dart';
import 'widgets/pdf_preview_dialog.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get totalPrice => product.price * quantity;
}

class PosCheckoutView extends StatefulWidget {
  const PosCheckoutView({super.key});

  @override
  State<PosCheckoutView> createState() => _PosCheckoutViewState();
}

class _PosCheckoutViewState extends State<PosCheckoutView> {
  final Map<int, CartItem> _cart = {};
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  StreamSubscription? _scanSubscription;
  final NumberFormat _currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
      final scanner = context.read<ScannerService>();
      _scanSubscription = scanner.onBarcodeScanned.listen((code) {
        if (mounted) {
          _addToCartByCode(code);
        }
      });
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _addToCartByCode(String code) {
    final raw = code.trim();
    if (raw.isEmpty) return;

    final provider = context.read<StockProvider>();
    Product? found;

    try {
      found = provider.products.firstWhere(
        (p) => p.sku.toLowerCase() == raw.toLowerCase() || p.id.toString() == raw,
      );
    } catch (_) {
      try {
        found = provider.products.firstWhere((p) => p.name.toLowerCase().contains(raw.toLowerCase()));
      } catch (_) {}
    }

    _searchCtrl.clear();

    if (found != null) {
      _addProduct(found);
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Article '$raw' introuvable dans le stock."),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _searchFocus.requestFocus();
  }

  void _addProduct(Product product) {
    if (product.quantity <= 0) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rupture de stock pour '${product.name}'."),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final currentQtyInCart = _cart[product.id]?.quantity ?? 0;
    if (currentQtyInCart + 1 > product.quantity) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Stock maximal atteint (${product.quantity} disp.)"),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id]!.quantity += 1;
      } else {
        _cart[product.id] = CartItem(product: product);
      }
    });
  }

  double get _totalAmount => _cart.values.fold(0.0, (acc, item) => acc + item.totalPrice);
  int get _totalItemsCount => _cart.values.fold(0, (acc, item) => acc + item.quantity);

  void _openPaymentModal() {
    if (_cart.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaymentModal(
        totalAmount: _totalAmount,
        cartItems: _cart.values.toList(),
        onSuccess: (result) {
          setState(() => _cart.clear());
          _showReceiptDialog(result);
        },
      ),
    );
  }

  void _showReceiptDialog(Map<String, dynamic> result) {
    final docMap = result['document'];
    final doc = CommercialDocument.fromJson(docMap);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text("Vente Validée !"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Ticket : ${doc.referenceNumber}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("Total encaissé : ${_currencyFmt.format(result['amount_tendered'])}"),
            if (result['change_due'] > 0)
              Text("Monnaie rendue : ${_currencyFmt.format(result['change_due'])}",
                  style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text("Le stock a été décrémenté automatiquement.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print, size: 18),
            label: const Text("Imprimer Ticket"),
            onPressed: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                builder: (_) => PdfPreviewDialog(
                  document: doc,
                  paymentMethod: result['payment_method'],
                  amountTendered: (result['amount_tendered'] as num).toDouble(),
                  changeDue: (result['change_due'] as num).toDouble(),
                ),
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Nouvelle Vente"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _cart.values.toList();

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        title: const Text("Caisse Enregistreuse POS"),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: ScannerStatusBadge(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Barre de recherche et scan
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: "Scannez un code-barres ou recherchez...",
                      prefixIcon: const Icon(Icons.qr_code_scanner, color: AppConstants.primary),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_shopping_cart, color: AppConstants.primary),
                        onPressed: () => _addToCartByCode(_searchCtrl.text),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onSubmitted: _addToCartByCode,
                  ),
                ),
              ],
            ),
          ),

          // 2. Liste des Articles dans le Panier
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.point_of_sale_rounded, size: 70, color: Colors.grey.shade300),
                        const SizedBox(height: 14),
                        const Text(
                          "Panier de caisse vide",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Scannez des articles pour démarrer une vente.",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  color: const Color(0xFFF1F5F9),
                                  child: item.product.imageUrl != null && item.product.imageUrl!.trim().isNotEmpty
                                      ? Image.network(
                                          Product.resolveUrl(item.product.imageUrl)!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Center(
                                            child: Icon(Icons.inventory_2_outlined, color: AppConstants.primary, size: 18),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(Icons.inventory_2_outlined, color: AppConstants.primary, size: 18),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${_currencyFmt.format(item.product.price)} / unité",
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                                    onPressed: () {
                                      setState(() {
                                        if (item.quantity > 1) {
                                          item.quantity -= 1;
                                        } else {
                                          _cart.remove(item.product.id);
                                        }
                                      });
                                    },
                                  ),
                                  Text("${item.quantity}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: AppConstants.primary, size: 22),
                                    onPressed: () {
                                      if (item.quantity < item.product.quantity) {
                                        setState(() => item.quantity += 1);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Stock maximal atteint"), duration: Duration(seconds: 1)),
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currencyFmt.format(item.totalPrice),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppConstants.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 3. Barre Totaux & Encaissement
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$_totalItemsCount article(s)", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    Text(
                      _currencyFmt.format(_totalAmount),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _cart.isEmpty ? null : _openPaymentModal,
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text("Encaisser", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentModal extends StatefulWidget {
  final double totalAmount;
  final List<CartItem> cartItems;
  final void Function(Map<String, dynamic> result) onSuccess;

  const _PaymentModal({
    required this.totalAmount,
    required this.cartItems,
    required this.onSuccess,
  });

  @override
  State<_PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<_PaymentModal> {
  final TextEditingController _customerCtrl = TextEditingController(text: "Client Comptoir");
  final TextEditingController _amountTenderedCtrl = TextEditingController();
  String _paymentMethod = "Espèces";
  bool _isProcessing = false;
  int? _selectedSellerId;
  final NumberFormat _currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _amountTenderedCtrl.text = widget.totalAmount.toInt().toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final stock = context.read<StockProvider>();
      if (auth.currentUser != null) {
        final match = stock.sellers.where((s) => s.id == auth.currentUser!.id).firstOrNull;
        if (match != null) {
          setState(() => _selectedSellerId = match.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _amountTenderedCtrl.dispose();
    super.dispose();
  }

  double get _tendered => double.tryParse(_amountTenderedCtrl.text) ?? widget.totalAmount;
  double get _changeDue => max(0.0, _tendered - widget.totalAmount);

  double max(double a, double b) => a > b ? a : b;

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    final provider = context.read<StockProvider>();

    try {
      final payload = {
        "customer_name": _customerCtrl.text.trim(),
        "payment_method": _paymentMethod,
        "amount_tendered": _tendered,
        if (_selectedSellerId != null) "seller_id": _selectedSellerId,
        if (provider.selectedPos != null) "point_of_sale_id": provider.selectedPos!.id,
        "items": widget.cartItems.map((it) => {
          "product_id": it.product.id,
          "quantity": it.quantity,
          "unit_price": it.product.price,
        }).toList(),
      };

      final result = await provider.api.posCheckout(payload);
      await provider.loadAll();

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Règlement de la Vente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Carte Montant Net
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Montant Total Net :", style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
                  Text(
                    _currencyFmt.format(widget.totalAmount),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mode de Paiement
            const Text("Mode de Règlement :", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPaymentMethodChip("Espèces", Icons.payments_outlined),
                const SizedBox(width: 8),
                _buildPaymentMethodChip("Carte Bancaire", Icons.credit_card),
                const SizedBox(width: 8),
                _buildPaymentMethodChip("Crédit Client", Icons.assignment_outlined),
              ],
            ),
            const SizedBox(height: 16),

            // Nom du Client
            TextField(
              controller: _customerCtrl,
              decoration: const InputDecoration(
                labelText: "Nom du Client / Tiers",
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),

            // Vendeur attribué à la vente
            DropdownButtonFormField<int?>(
              value: _selectedSellerId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Vendeur Attribué (Commission)",
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text("Aucun vendeur spécifique", overflow: TextOverflow.ellipsis),
                ),
                ...context.watch<StockProvider>().sellers.where((s) => s.isActive).map((s) {
                  return DropdownMenuItem<int?>(
                    value: s.id,
                    child: Text(
                      "${s.fullName} (${s.commissionRate.toStringAsFixed(s.commissionRate.truncateToDouble() == s.commissionRate ? 0 : 1)}%)",
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _selectedSellerId = val),
            ),
            if (_selectedSellerId != null) ...[
              const SizedBox(height: 8),
              Builder(builder: (ctx) {
                final seller = ctx
                    .watch<StockProvider>()
                    .sellers
                    .where((s) => s.id == _selectedSellerId)
                    .firstOrNull;
                if (seller == null || seller.commissionRate <= 0) return const SizedBox.shrink();
                final commissionEst = widget.totalAmount * (seller.commissionRate / 100.0);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Commission vendeur (${seller.commissionRate.toStringAsFixed(1)}%) : +${_currencyFmt.format(commissionEst)}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 14),

            // Espèces reçues & Rendu monnaie
            if (_paymentMethod == "Espèces") ...[
              TextField(
                controller: _amountTenderedCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Montant reçu en espèces (DA)",
                  prefixIcon: Icon(Icons.money),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              // Rendu de monnaie calculé
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _changeDue > 0 ? const Color(0xFFDCFCE7) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _changeDue > 0 ? const Color(0xFF86EFAC) : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Monnaie à rendre :",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _changeDue > 0 ? const Color(0xFF166534) : Colors.grey.shade700,
                        )),
                    Text(
                      _currencyFmt.format(_changeDue),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _changeDue > 0 ? const Color(0xFF166534) : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Bouton de Validation
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _processPayment,
                icon: _isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _isProcessing ? "Validation en cours..." : "Valider l'Encaissement",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChip(String method, IconData icon) {
    final isSelected = _paymentMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = method),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.primary.withValues(alpha: 0.12) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppConstants.primary : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? AppConstants.primary : Colors.grey.shade700),
              const SizedBox(height: 4),
              Text(
                method,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppConstants.primary : Colors.grey.shade800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
