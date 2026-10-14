import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product_profit.dart';
import '../models/point_of_sale.dart';
import '../models/category.dart';
import '../providers/stock_provider.dart';
import '../utils/constants.dart';

enum ProfitDatePreset {
  today,
  last7Days,
  thisMonth,
  lastMonth,
  thisYear,
  allTime,
  custom,
}

class ProductProfitView extends StatefulWidget {
  const ProductProfitView({super.key});

  @override
  State<ProductProfitView> createState() => _ProductProfitViewState();
}

class _ProductProfitViewState extends State<ProductProfitView> {
  final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);
  final dateFormat = DateFormat('dd/MM/yyyy');

  bool _isLoading = true;
  String? _errorMessage;
  ProductProfitReport? _report;

  // Filtres
  ProfitDatePreset _selectedPreset = ProfitDatePreset.allTime;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedPosId;
  int? _selectedCategoryId;
  String _searchQuery = "";
  String _sortBy = "profit_desc";
  bool _includeUnsold = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyPreset(ProfitDatePreset.allTime, fetch: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReport();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyPreset(ProfitDatePreset preset, {bool fetch = true}) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case ProfitDatePreset.today:
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case ProfitDatePreset.last7Days:
          _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case ProfitDatePreset.thisMonth:
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case ProfitDatePreset.lastMonth:
          final firstDayPrevMonth = DateTime(now.year, now.month - 1, 1);
          final lastDayPrevMonth = DateTime(now.year, now.month, 0, 23, 59, 59);
          _startDate = firstDayPrevMonth;
          _endDate = lastDayPrevMonth;
          break;
        case ProfitDatePreset.thisYear:
          _startDate = DateTime(now.year, 1, 1);
          _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
        case ProfitDatePreset.allTime:
          _startDate = null;
          _endDate = null;
          break;
        case ProfitDatePreset.custom:
          break;
      }
    });

    if (fetch) {
      _loadReport();
    }
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(2020, 1, 1);
    final lastDate = DateTime(now.year + 2, 12, 31);

    final initialRange = DateTimeRange(
      start: _startDate ?? DateTime(now.year, now.month, 1),
      end: _endDate ?? now,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialRange,
      helpText: 'Sélectionner la période d\'analyse',
      cancelText: 'Annuler',
      confirmText: 'Appliquer',
      saveText: 'Valider',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF059669),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppConstants.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = ProfitDatePreset.custom;
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stockProvider = context.read<StockProvider>();
      final api = stockProvider.api;

      final report = await api.getProductProfitReport(
        startDate: _startDate,
        endDate: _endDate,
        posId: _selectedPosId,
        categoryId: _selectedCategoryId,
        search: _searchQuery,
        sortBy: _sortBy,
        includeUnsold: _includeUnsold,
      );

      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  String _getPeriodLabel() {
    if (_startDate == null && _endDate == null) {
      return "Tout l'historique";
    }
    if (_startDate != null && _endDate != null) {
      if (dateFormat.format(_startDate!) == dateFormat.format(_endDate!)) {
        return "Le ${dateFormat.format(_startDate!)}";
      }
      return "Du ${dateFormat.format(_startDate!)} au ${dateFormat.format(_endDate!)}";
    }
    if (_startDate != null) {
      return "À partir du ${dateFormat.format(_startDate!)}";
    }
    return "Jusqu'au ${dateFormat.format(_endDate!)}";
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final pointsOfSale = stockProvider.pointsOfSale;
    final categories = stockProvider.categories;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bénéfices & Marges par Produit",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
            ),
            Text(
              "Période : ${_getPeriodLabel()}",
              style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF059669)),
            tooltip: "Calendrier interactif",
            onPressed: _pickCustomDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Actualiser",
            onPressed: _loadReport,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        color: const Color(0xFF059669),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Barre de presets calendrier
              _buildDatePresetBar(),
              const SizedBox(height: 12),

              // Bannière période active
              _buildActivePeriodBanner(),
              const SizedBox(height: 16),

              // Erreur éventuelle
              if (_errorMessage != null) _buildErrorCard(),

              // 2. Synthèse financière globale
              if (_report != null) ...[
                _buildKpiSummary(_report!.summary),
                const SizedBox(height: 20),

                // 3. Décomposition calendrier journalier
                if (_report!.dailyBreakdown.isNotEmpty) ...[
                  _buildDailyBreakdownCard(_report!.dailyBreakdown),
                  const SizedBox(height: 20),
                ],
              ],

              // 4. Barre d'outils et de filtres
              _buildFilterAndSearchToolbar(pointsOfSale, categories),
              const SizedBox(height: 16),

              // 5. Liste des produits avec bénéfice
              if (_isLoading && _report == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: Color(0xFF059669)),
                  ),
                )
              else if (_report != null)
                _buildProductsProfitList(_report!)
              else if (!_isLoading)
                _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePresetBar() {
    final presets = [
      {'preset': ProfitDatePreset.today, 'label': "Aujourd'hui"},
      {'preset': ProfitDatePreset.last7Days, 'label': "7 jours"},
      {'preset': ProfitDatePreset.thisMonth, 'label': "Ce mois"},
      {'preset': ProfitDatePreset.lastMonth, 'label': "Mois dernier"},
      {'preset': ProfitDatePreset.thisYear, 'label': "Cette année"},
      {'preset': ProfitDatePreset.allTime, 'label': "Tout"},
      {'preset': ProfitDatePreset.custom, 'label': "Calendrier 📅"},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presets.map((item) {
          final p = item['preset'] as ProfitDatePreset;
          final label = item['label'] as String;
          final isSelected = _selectedPreset == p;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: const Color(0xFF059669),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppConstants.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? const Color(0xFF059669) : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (selected) {
                if (p == ProfitDatePreset.custom) {
                  _pickCustomDateRange();
                } else {
                  _applyPreset(p);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivePeriodBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded, color: Color(0xFF059669), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Période analysée : ${_getPeriodLabel()}",
              style: const TextStyle(
                color: Color(0xFF065F46),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (_selectedPreset != ProfitDatePreset.allTime)
            InkWell(
              onTap: () => _applyPreset(ProfitDatePreset.allTime),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, size: 16, color: Color(0xFF065F46)),
                    SizedBox(width: 2),
                    Text(
                      "Tout voir",
                      style: TextStyle(color: Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _loadReport,
            child: const Text("Réessayer"),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummary(ProfitSummary summary) {
    final isPositive = summary.totalProfit >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carte principale : Bénéfice Net Réalisé
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPositive
                  ? [const Color(0xFF047857), const Color(0xFF10B981)]
                  : [const Color(0xFFB91C1C), const Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "BÉNÉFICE NET RÉALISÉ",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${summary.marginPercentage}% de marge",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  "${isPositive ? '+' : ''}${currencyFormat.format(summary.totalProfit)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summary.topProfitableProduct != null
                    ? "Produit le plus rentable : ${summary.topProfitableProduct}"
                    : "Aucune vente sur la période",
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3 cartes secondaires responsive
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;

            if (isNarrow) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniStatCard(
                          title: "Chiffre d'Affaires",
                          value: currencyFormat.format(summary.totalRevenue),
                          icon: Icons.point_of_sale_rounded,
                          color: const Color(0xFF4F46E5),
                          bgColor: const Color(0xFFEEF2FF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniStatCard(
                          title: "Coût d'Achat",
                          value: currencyFormat.format(summary.totalCost),
                          icon: Icons.inventory_rounded,
                          color: const Color(0xFFD97706),
                          bgColor: const Color(0xFFFFFBEB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildMiniStatCard(
                    title: "Volume des Ventes",
                    value: "${summary.totalUnitsSold} unités vendues",
                    subtitle: "${summary.totalSalesCount} transaction(s) au total",
                    icon: Icons.shopping_basket_rounded,
                    color: const Color(0xFF0D9488),
                    bgColor: const Color(0xFFF0FDFA),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _buildMiniStatCard(
                    title: "Chiffre d'Affaires",
                    value: currencyFormat.format(summary.totalRevenue),
                    icon: Icons.point_of_sale_rounded,
                    color: const Color(0xFF4F46E5),
                    bgColor: const Color(0xFFEEF2FF),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStatCard(
                    title: "Coût d'Achat",
                    value: currencyFormat.format(summary.totalCost),
                    icon: Icons.inventory_rounded,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStatCard(
                    title: "Articles Vendus",
                    value: "${summary.totalUnitsSold} un.",
                    subtitle: "${summary.totalSalesCount} ventes",
                    icon: Icons.shopping_basket_rounded,
                    color: const Color(0xFF0D9488),
                    bgColor: const Color(0xFFF0FDFA),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyBreakdownCard(List<DailyProfitItem> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF059669)),
                  SizedBox(width: 8),
                  Text(
                    "Chronologie Journalière (Calendrier)",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                  ),
                ],
              ),
              Text(
                "${items.length} jour(s)",
                style: const TextStyle(fontSize: 12, color: AppConstants.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...items.map((day) {
            DateTime? parsedDate;
            try {
              parsedDate = DateTime.parse(day.date);
            } catch (_) {}

            final dateTitle = parsedDate != null
                ? DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(parsedDate)
                : day.date;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      parsedDate != null ? DateFormat('dd').format(parsedDate) : "•",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppConstants.textPrimary),
                        ),
                        Text(
                          "CA: ${currencyFormat.format(day.revenue)} • Coût: ${currencyFormat.format(day.cost)} • ${day.unitsSold} vendus",
                          style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: day.profit >= 0 ? const Color(0xFFECFDF5) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: day.profit >= 0 ? const Color(0xFFA7F3D0) : Colors.red.shade200,
                      ),
                    ),
                    child: Text(
                      "${day.profit >= 0 ? '+' : ''}${currencyFormat.format(day.profit)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: day.profit >= 0 ? const Color(0xFF047857) : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchToolbar(List<PointOfSale> posList, List<Category> catList) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Champ de recherche
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Rechercher par nom ou référence SKU...",
              prefixIcon: const Icon(Icons.search_rounded, color: AppConstants.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                        _loadReport();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            onSubmitted: (value) {
              setState(() => _searchQuery = value.trim());
              _loadReport();
            },
          ),
          const SizedBox(height: 10),

          // Filtres déroulants responsive
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;

              final categoryDropdown = DropdownButtonFormField<int?>(
                value: _selectedCategoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: "Catégorie",
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text("Toutes", style: TextStyle(fontSize: 12)),
                  ),
                  ...catList.map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(fontSize: 12)),
                      )),
                ],
                onChanged: (val) {
                  setState(() => _selectedCategoryId = val);
                  _loadReport();
                },
              );

              final sortDropdown = DropdownButtonFormField<String>(
                value: _sortBy,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: "Tri",
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: "profit_desc", child: Text("Bénéfice ↓", style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: "profit_asc", child: Text("Bénéfice ↑", style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: "revenue_desc", child: Text("CA ↓", style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: "quantity_desc", child: Text("Ventes ↓", style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: "name_asc", child: Text("Nom A-Z", style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _sortBy = val);
                    _loadReport();
                  }
                },
              );

              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: categoryDropdown),
                        const SizedBox(width: 8),
                        Expanded(child: sortDropdown),
                      ],
                    ),
                    if (posList.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        value: _selectedPosId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Magasin / POS",
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text("Tous les magasins", style: TextStyle(fontSize: 12)),
                          ),
                          ...posList.map((p) => DropdownMenuItem<int?>(
                                value: p.id,
                                child: Text(p.name, style: const TextStyle(fontSize: 12)),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedPosId = val);
                          _loadReport();
                        },
                      ),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: categoryDropdown),
                  const SizedBox(width: 8),
                  if (posList.isNotEmpty) ...[
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _selectedPosId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Magasin / POS",
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text("Tous", style: TextStyle(fontSize: 12)),
                          ),
                          ...posList.map((p) => DropdownMenuItem<int?>(
                                value: p.id,
                                child: Text(p.name, style: const TextStyle(fontSize: 12)),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedPosId = val);
                          _loadReport();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: sortDropdown),
                ],
              );
            },
          ),
          const SizedBox(height: 6),

          // Option : Inclure stock sans vente
          Row(
            children: [
              Checkbox(
                value: _includeUnsold,
                activeColor: const Color(0xFF059669),
                visualDensity: VisualDensity.compact,
                onChanged: (val) {
                  setState(() => _includeUnsold = val ?? false);
                  _loadReport();
                },
              ),
              const Expanded(
                child: Text(
                  "Afficher également les articles du stock sans vente sur cette période",
                  style: TextStyle(fontSize: 12, color: AppConstants.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsProfitList(ProductProfitReport report) {
    final products = report.products;
    final totalProfit = report.summary.totalProfit;

    if (products.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Détail par Produit (${products.length})",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
            ),
            Text(
              "Marge globale : ${report.summary.marginPercentage}%",
              style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = products[index];
            return _buildProductProfitCard(item, totalProfit);
          },
        ),
      ],
    );
  }

  Widget _buildProductProfitCard(ProductProfitItem item, double totalProfitPeriod) {
    final isPositive = item.totalProfit >= 0;
    final profitRatio = totalProfitPeriod > 0
        ? (item.totalProfit / totalProfitPeriod).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showProductDetailsDialog(item),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Nom, Réf et Bénéfice
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.productSku,
                                style: const TextStyle(fontSize: 11, color: AppConstants.textSecondary, fontFamily: 'monospace'),
                              ),
                            ),
                            if (item.categoryName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.categoryName!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.w500),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.currentStock <= 5 ? Colors.red.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Stock : ${item.currentStock}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: item.currentStock <= 5 ? Colors.red.shade700 : Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Badge Bénéfice Réalisé
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isPositive ? const Color(0xFFECFDF5) : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isPositive ? const Color(0xFFA7F3D0) : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              size: 16,
                              color: isPositive ? const Color(0xFF047857) : Colors.red.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${isPositive ? '+' : ''}${currencyFormat.format(item.totalProfit)}",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isPositive ? const Color(0xFF047857) : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "${item.marginPercentage}% marge",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPositive ? const Color(0xFF059669) : Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Ligne 2 : Métriques financières responsive (2 lignes de 3/2 colonnes pour éviter tout overflow)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCol("Qté Vendue", "${item.quantitySold} un."),
                        _buildMetricCol("Prix Moyen", currencyFormat.format(item.avgSalePrice)),
                        _buildMetricCol("Coût Achat", currencyFormat.format(item.unitCostPrice)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCol("Total Ventes (CA)", currencyFormat.format(item.totalRevenue)),
                        _buildMetricCol("Total Coût Achat", currencyFormat.format(item.totalCost)),
                        _buildMetricCol("Bénéfice Net", "${isPositive ? '+' : ''}${currencyFormat.format(item.totalProfit)}"),
                      ],
                    ),
                  ],
                ),
              ),

              // Ligne 3 : Contribution au bénéfice global
              if (item.totalProfit > 0 && totalProfitPeriod > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: profitRatio,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${(profitRatio * 100).toStringAsFixed(1)}% du gain",
                      style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
        ),
      ],
    );
  }

  void _showProductDetailsDialog(ProductProfitItem item) {
    final isPositive = item.totalProfit >= 0;
    final unitProfit = item.avgSalePrice - item.unitCostPrice;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                item.productName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
              ),
              Text(
                "Réf : ${item.productSku} • Catégorie : ${item.categoryName ?? 'Non classé'}",
                style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              _buildDetailRow("Bénéfice Net sur la période", "${isPositive ? '+' : ''}${currencyFormat.format(item.totalProfit)}", isHighlight: true, isPositive: isPositive),
              _buildDetailRow("Taux de Marge Réalisé", "${item.marginPercentage}%"),
              _buildDetailRow("Bénéfice Unitaire Moyen", "${unitProfit >= 0 ? '+' : ''}${currencyFormat.format(unitProfit)} / unité"),
              _buildDetailRow("Prix de Vente Unitaire Moyen", currencyFormat.format(item.avgSalePrice)),
              _buildDetailRow("Coût d'Achat Unitaire", currencyFormat.format(item.unitCostPrice)),
              _buildDetailRow("Quantité Totale Vendue", "${item.quantitySold} unités"),
              _buildDetailRow("Chiffre d'Affaires Brut (CA)", currencyFormat.format(item.totalRevenue)),
              _buildDetailRow("Coût Total Marchandises", currencyFormat.format(item.totalCost)),
              _buildDetailRow("Nombre de Transactions", "${item.salesCount} ventes"),
              _buildDetailRow("Stock Actuel en Réserve", "${item.currentStock} unités"),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Fermer"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, bool isPositive = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isHighlight ? AppConstants.textPrimary : AppConstants.textSecondary,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 15 : 13,
              color: isHighlight
                  ? (isPositive ? const Color(0xFF047857) : Colors.red.shade700)
                  : AppConstants.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_month_outlined, size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text(
            "Aucune vente enregistrée",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            "Aucun produit n'a été vendu sur la période sélectionnée (${_getPeriodLabel()}).",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _applyPreset(ProfitDatePreset.allTime),
            icon: const Icon(Icons.all_inclusive_rounded, size: 16),
            label: const Text("Voir tout l'historique"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
