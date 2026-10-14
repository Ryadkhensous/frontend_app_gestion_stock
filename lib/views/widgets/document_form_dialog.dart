import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/stock_provider.dart';
import '../../models/product.dart';
import '../../models/point_of_sale.dart';
import '../../models/commercial_document.dart';
import '../../utils/constants.dart';

class FormItemRow {
  Product? product;
  int quantity;
  double unitPrice;

  FormItemRow({
    this.product,
    this.quantity = 1,
    this.unitPrice = 0.0,
  });

  double get lineTotal => quantity * unitPrice;
}

class DocumentFormDialog extends StatefulWidget {
  final String initialDocType; // 'ORDER' or 'DELIVERY'
  final String? initialDirection; // 'OUTGOING' or 'INCOMING'
  final bool? initialImmediateDelivery;
  final Product? initialProduct;
  final PointOfSale? initialPos;
  final CommercialDocument? documentToEdit;

  const DocumentFormDialog({
    super.key,
    this.initialDocType = 'ORDER',
    this.initialDirection,
    this.initialImmediateDelivery,
    this.initialProduct,
    this.initialPos,
    this.documentToEdit,
  });

  @override
  State<DocumentFormDialog> createState() => _DocumentFormDialogState();
}

class _DocumentFormDialogState extends State<DocumentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _docType;
  String _direction = 'OUTGOING'; // 'OUTGOING' | 'INCOMING'
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _partnerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  PointOfSale? _selectedPos;
  DateTime _issueDate = DateTime.now();
  bool _markAsDeliveredDirectly = false;
  bool _isSaving = false;

  final List<FormItemRow> _itemRows = [];

  bool get _isEditing => widget.documentToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final doc = widget.documentToEdit!;
      _docType = doc.docType;
      _direction = doc.direction;
      _refController.text = doc.referenceNumber;
      _partnerController.text = doc.partnerName ?? '';
      _notesController.text = doc.notes ?? '';
      _issueDate = doc.issueDate;
      _markAsDeliveredDirectly = doc.isDelivered;
    } else {
      _docType = widget.initialDocType;
      if (widget.initialDirection != null) {
        _direction = widget.initialDirection!;
      }
      _markAsDeliveredDirectly = widget.initialImmediateDelivery ?? (_docType == 'DELIVERY');
      if (widget.initialPos != null) {
        _selectedPos = widget.initialPos;
        _partnerController.text = widget.initialPos!.name;
      }
      _generateDefaultReference();
    }

    // Initialiser les lignes d'articles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StockProvider>();
      final products = provider.products;

      if (_isEditing) {
        final doc = widget.documentToEdit!;
        // Déterminer le POS si applicable
        if (doc.pointOfSaleId != null) {
          try {
            _selectedPos = provider.pointsOfSale.firstWhere((pos) => pos.id == doc.pointOfSaleId);
          } catch (_) {}
        }

        setState(() {
          _itemRows.clear();
          for (var item in doc.items) {
            Product? matchedProduct;
            try {
              matchedProduct = products.firstWhere((p) => p.id == item.productId);
            } catch (_) {
              matchedProduct = Product(
                id: item.productId,
                name: item.productName ?? "Produit #${item.productId}",
                sku: item.productSku ?? "SKU-${item.productId}",
                price: item.unitPrice,
                quantity: 0,
                isLowStock: false,
              );
            }
            _itemRows.add(FormItemRow(
              product: matchedProduct,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
            ));
          }
          if (_itemRows.isEmpty) {
            if (products.isNotEmpty) {
              _itemRows.add(FormItemRow(
                product: products.first,
                quantity: 1,
                unitPrice: _direction == 'INCOMING' ? products.first.costPrice : products.first.price,
              ));
            } else {
              _itemRows.add(FormItemRow());
            }
          }
        });
      } else if (widget.initialProduct != null) {
        setState(() {
          _itemRows.add(FormItemRow(
            product: widget.initialProduct,
            quantity: 1,
            unitPrice: _direction == 'INCOMING'
                ? widget.initialProduct!.costPrice
                : widget.initialProduct!.price,
          ));
        });
      } else {
        if (products.isNotEmpty) {
          setState(() {
            _itemRows.add(FormItemRow(
              product: products.first,
              quantity: 1,
              unitPrice: _direction == 'INCOMING' ? products.first.costPrice : products.first.price,
            ));
          });
        } else {
          setState(() {
            _itemRows.add(FormItemRow());
          });
        }
      }
    });
  }

  void _generateDefaultReference() {
    final prefix = _docType == 'ORDER' ? 'BC' : 'BL';
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final randomSuffix = (DateTime.now().millisecondsSinceEpoch % 900 + 100).toString();
    _refController.text = "$prefix-$dateStr-$randomSuffix";
  }

  double get _calculatedTotal => _itemRows.fold<double>(0.0, (sum, item) => sum + item.lineTotal);
  int get _calculatedQuantity => _itemRows.fold<int>(0, (sum, item) => sum + item.quantity);

  void _addNewItem() {
    final products = context.read<StockProvider>().products;
    setState(() {
      _itemRows.add(FormItemRow(
        product: products.isNotEmpty ? products.first : null,
        quantity: 1,
        unitPrice: products.isNotEmpty
            ? (_direction == 'INCOMING' ? products.first.costPrice : products.first.price)
            : 0.0,
      ));
    });
  }

  void _removeItem(int index) {
    if (_itemRows.length > 1) {
      setState(() {
        _itemRows.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le bon doit contenir au moins un article.")),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_itemRows.isEmpty || _itemRows.any((r) => r.product == null || r.quantity <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner un produit et une quantité valide pour chaque ligne."),
          backgroundColor: AppConstants.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    String finalStatus = 'DRAFT';
    if (_isEditing) {
      if (_docType == 'DELIVERY') {
        finalStatus = _markAsDeliveredDirectly
            ? 'DELIVERED'
            : (widget.documentToEdit!.status == 'DELIVERED' ? 'VALIDATED' : widget.documentToEdit!.status);
      } else {
        finalStatus = widget.documentToEdit!.status;
      }
    } else {
      if (_docType == 'DELIVERY' && _markAsDeliveredDirectly) {
        finalStatus = 'DELIVERED';
      }
    }

    final payload = {
      'reference_number': _refController.text.trim(),
      'doc_type': _docType,
      'direction': _direction,
      'status': finalStatus,
      'point_of_sale_id': _direction == 'OUTGOING' ? _selectedPos?.id : null,
      'partner_name': _partnerController.text.trim().isNotEmpty
          ? _partnerController.text.trim()
          : (_selectedPos?.name ?? (_direction == 'INCOMING' ? 'Fournisseur Général' : 'Client Comptoir')),
      'issue_date': _issueDate.toIso8601String(),
      'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      'items': _itemRows.map((r) => {
        'product_id': r.product!.id,
        'quantity': r.quantity,
        'unit_price': r.unitPrice,
      }).toList(),
    };

    final provider = context.read<StockProvider>();
    final bool success;
    if (_isEditing) {
      success = await provider.updateDocument(widget.documentToEdit!.id, payload);
    } else {
      success = await provider.addDocument(payload);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? "Bon ${_refController.text} modifié avec succès !"
                  : (_docType == 'ORDER'
                      ? "Bon de commande ${_refController.text} créé avec succès !"
                      : "Bon de livraison ${_refController.text} enregistré ${_markAsDeliveredDirectly ? 'et stock mis à jour' : ''} !"),
            ),
            backgroundColor: AppConstants.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? "Erreur lors de l'enregistrement du bon"),
            backgroundColor: AppConstants.danger,
          ),
        );
      }
    }
  }

  Widget _buildModeInfoBanner() {
    final bool isIncoming = _direction == 'INCOMING';
    final bool isDelivery = _docType == 'DELIVERY';

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData icon;
    final String title;
    final String subtitle;

    if (isDelivery && !isIncoming) {
      bgColor = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFFBBF7D0);
      textColor = const Color(0xFF15803D);
      icon = Icons.flash_on_rounded;
      title = "Mode Vente / Sortie Directe (BL)";
      subtitle = "Sortie physique immédiate : les articles seront décomptés du stock dès validation.";
    } else if (!isDelivery && !isIncoming) {
      bgColor = const Color(0xFFEEF2FF);
      borderColor = const Color(0xFFC7D2FE);
      textColor = const Color(0xFF3730A3);
      icon = Icons.assignment_outlined;
      title = "Mode Bon de Commande (BC)";
      subtitle = "Réservation / Devis : fige les prix et quantités. Le stock ne sera déduit que lors de la livraison.";
    } else {
      bgColor = const Color(0xFFF0FDFA);
      borderColor = const Color(0xFF99F6E4);
      textColor = const Color(0xFF115E59);
      icon = Icons.inventory_2_outlined;
      title = isDelivery ? "Mode Réception Fournisseur (BL)" : "Mode Commande Fournisseur (BC)";
      subtitle = isDelivery
          ? "Entrée de marchandise : les quantités reçues seront directement ajoutées au stock."
          : "Bon de commande d'achat auprès d'un fournisseur sans impact stock immédiat.";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.9), height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final products = stockProvider.products;
    final pointsOfSale = stockProvider.pointsOfSale;
    final isDelivery = _docType == 'DELIVERY';
    final isMobile = MediaQuery.of(context).size.width < 600;

    final typeSegmentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Type de Document", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ORDER', label: FittedBox(fit: BoxFit.scaleDown, child: Text("Commande")), icon: Icon(Icons.shopping_cart_outlined, size: 16)),
            ButtonSegment(value: 'DELIVERY', label: FittedBox(fit: BoxFit.scaleDown, child: Text("Livraison")), icon: Icon(Icons.local_shipping_outlined, size: 16)),
          ],
          selected: {_docType},
          onSelectionChanged: _isEditing ? null : (val) {
            setState(() {
              _docType = val.first;
              if (_docType == 'DELIVERY') {
                _markAsDeliveredDirectly = true;
              } else {
                _markAsDeliveredDirectly = false;
              }
              _generateDefaultReference();
            });
          },
        ),
      ],
    );

    final directionSegmentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Flux / Direction", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'OUTGOING', label: FittedBox(fit: BoxFit.scaleDown, child: Text("Sortie / Envoi"))),
            ButtonSegment(value: 'INCOMING', label: FittedBox(fit: BoxFit.scaleDown, child: Text("Entrée / Réception"))),
          ],
          selected: {_direction},
          onSelectionChanged: (val) {
            setState(() {
              _direction = val.first;
              for (var row in _itemRows) {
                if (row.product != null) {
                  row.unitPrice = _direction == 'INCOMING'
                      ? row.product!.costPrice
                      : row.product!.price;
                }
              }
            });
          },
        ),
      ],
    );

    final refField = TextFormField(
      controller: _refController,
      decoration: InputDecoration(
        labelText: "N° Référence",
        prefixIcon: const Icon(Icons.tag_rounded, size: 18),
        suffixIcon: IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 18),
          tooltip: "Générer un numéro",
          onPressed: _generateDefaultReference,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (val) => val == null || val.trim().isEmpty ? "Champ requis" : null,
    );

    final dateField = InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _issueDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          setState(() => _issueDate = picked);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "Date",
          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          DateFormat('dd/MM/yyyy').format(_issueDate),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );

    final posField = DropdownButtonFormField<PointOfSale?>(
      value: _selectedPos,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: "Point de Vente Destinataire (Optionnel)",
        prefixIcon: const Icon(Icons.store_rounded, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: [
        const DropdownMenuItem<PointOfSale?>(
          value: null,
          child: Text("Aucun (Client direct / Tiers)"),
        ),
        ...pointsOfSale.map((pos) => DropdownMenuItem<PointOfSale?>(
          value: pos,
          child: Text("${pos.name} (${pos.city})"),
        )),
      ],
      onChanged: (val) {
        setState(() {
          _selectedPos = val;
          if (val != null && _partnerController.text.isEmpty) {
            _partnerController.text = val.name;
          }
        });
      },
    );

    final partnerField = TextFormField(
      controller: _partnerController,
      decoration: InputDecoration(
        labelText: _direction == 'INCOMING' ? "Nom du Fournisseur" : "Nom du Client / Tiers",
        prefixIcon: Icon(_direction == 'INCOMING' ? Icons.business_rounded : Icons.person_outline_rounded, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: isMobile ? 12 : 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 850),
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
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDelivery ? const Color(0xFF0D9488) : AppConstants.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDelivery ? Icons.local_shipping_rounded : Icons.shopping_bag_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isEditing
                              ? (isDelivery ? "Modifier le Bon de Livraison" : "Modifier le Bon de Commande")
                              : (isDelivery ? "Nouveau Bon de Livraison" : "Nouveau Bon de Commande"),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Contenu formulaire
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 14 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Choix Type et Direction
                        if (isMobile) ...[
                          typeSegmentWidget,
                          const SizedBox(height: 12),
                          directionSegmentWidget,
                        ] else ...[
                          Row(
                            children: [
                              Expanded(child: typeSegmentWidget),
                              const SizedBox(width: 16),
                              Expanded(child: directionSegmentWidget),
                            ],
                          ),
                        ],

                        const SizedBox(height: 12),
                        _buildModeInfoBanner(),
                        const SizedBox(height: 16),

                        // Référence et Tiers / Magasin
                        if (isMobile) ...[
                          Row(
                            children: [
                              Expanded(flex: 3, child: refField),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: dateField),
                            ],
                          ),
                          if (_direction == 'OUTGOING') ...[
                            const SizedBox(height: 10),
                            posField,
                          ],
                          const SizedBox(height: 10),
                          partnerField,
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: refField),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: dateField),
                              const SizedBox(width: 12),
                              if (_direction == 'OUTGOING') ...[
                                Expanded(flex: 3, child: posField),
                                const SizedBox(width: 12),
                              ],
                              Expanded(flex: 3, child: partnerField),
                            ],
                          ),
                        ],

                        const SizedBox(height: 20),
                        const Divider(thickness: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 10),

                        // Section Articles
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Articles du Bon",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                            ElevatedButton.icon(
                              onPressed: _addNewItem,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text("Ajouter"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDelivery ? const Color(0xFF0D9488) : AppConstants.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Liste des lignes d'articles
                        ...List.generate(_itemRows.length, (index) {
                          final row = _itemRows[index];

                          final productDropdown = DropdownButtonFormField<Product>(
                            value: row.product,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: "Produit",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: products.map((p) => DropdownMenuItem<Product>(
                              value: p,
                              child: Text(
                                "${p.name} (Dispo: ${p.quantity})",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            )).toList(),
                            onChanged: (p) {
                              setState(() {
                                row.product = p;
                                if (p != null) {
                                  row.unitPrice = _direction == 'INCOMING' ? p.costPrice : p.price;
                                }
                              });
                            },
                          );

                          final qtyField = TextFormField(
                            initialValue: row.quantity.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Qté",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            onChanged: (val) {
                              final q = int.tryParse(val) ?? 0;
                              setState(() => row.quantity = q);
                            },
                          );

                          final priceField = TextFormField(
                            key: ValueKey("price_${row.product?.id}_${row.unitPrice}"),
                            initialValue: row.unitPrice.toStringAsFixed(2),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: "P.U. (DA)",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            onChanged: (val) {
                              final p = double.tryParse(val) ?? 0.0;
                              setState(() => row.unitPrice = p);
                            },
                          );

                          final totalLineWidget = SizedBox(
                            width: 75,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("Total", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                Text(
                                  "${row.lineTotal.toStringAsFixed(2)} DA",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          );

                          final deleteButton = IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppConstants.danger, size: 20),
                            onPressed: () => _removeItem(index),
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            color: const Color(0xFFF8FAFC),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: isMobile
                                  ? Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: productDropdown),
                                            deleteButton,
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(flex: 2, child: qtyField),
                                            const SizedBox(width: 8),
                                            Expanded(flex: 2, child: priceField),
                                            const SizedBox(width: 8),
                                            totalLineWidget,
                                          ],
                                        ),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(flex: 4, child: productDropdown),
                                        const SizedBox(width: 10),
                                        Expanded(flex: 2, child: qtyField),
                                        const SizedBox(width: 10),
                                        Expanded(flex: 2, child: priceField),
                                        const SizedBox(width: 10),
                                        totalLineWidget,
                                        deleteButton,
                                      ],
                                    ),
                            ),
                          );
                        }),

                        const SizedBox(height: 12),

                        // Récapitulatif dynamique
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: isMobile
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Total articles :", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569))),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            "$_calculatedQuantity article(s)",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Montant Total :", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              "${_calculatedTotal.toStringAsFixed(2)} DA",
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
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Total : $_calculatedQuantity article(s)",
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                    ),
                                    Row(
                                      children: [
                                        const Text("Montant Total : ", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                        Text(
                                          "${_calculatedTotal.toStringAsFixed(2)} DA",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: isDelivery ? const Color(0xFF0D9488) : AppConstants.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Si Bon de Livraison : Option validation immédiate
                        if (isDelivery) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: CheckboxListTile(
                              value: _markAsDeliveredDirectly,
                              onChanged: (val) => setState(() => _markAsDeliveredDirectly = val ?? false),
                              activeColor: AppConstants.success,
                              title: const Text(
                                "Valider et mettre à jour les stocks immédiatement",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                              ),
                              subtitle: const Text(
                                "Si coché, les quantités seront directement déduites/ajoutées au stock et un mouvement sera créé.",
                                style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: "Notes ou instructions complémentaires",
                            prefixIcon: const Icon(Icons.notes_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Boutons d'action en bas
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: isMobile ? 12 : 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                        child: const Text("Annuler"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submitForm,
                        icon: _isSaving
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(_isSaving ? "Enregistrement..." : (_isEditing ? "Mettre à jour" : "Enregistrer")),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDelivery ? const Color(0xFF0D9488) : AppConstants.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: isMobile ? 10 : 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
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
