import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import 'dashboard_view.dart';
import 'products_view.dart';
import 'points_of_sale_view.dart';
import 'movements_view.dart';
import 'documents_view.dart';
import 'settings_view.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  void _navigateToTab(int index) {
    if (mounted) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardView(onNavigateToTab: _navigateToTab),
      const ProductsView(),
      const PointsOfSaleView(),
      const MovementsView(),
      const DocumentsView(),
    ];
    // Chargement initial des données au lancement de l'application
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = context.read<SettingsProvider>();
      final stock = context.read<StockProvider>();
      if (!settings.isLoaded) {
        await settings.loadSettings();
      }
      if (settings.apiUrl.isNotEmpty && stock.currentApiUrl != settings.apiUrl) {
        stock.updateApiUrl(settings.apiUrl);
      } else {
        stock.loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      // Disposition Responsive pour Tablettes et Écrans Larges (NavigationRail)
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Icon(Icons.all_inbox_rounded, color: AppConstants.primary, size: 36),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded, color: AppConstants.primary),
                  label: Text("Dashboard"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2_rounded, color: AppConstants.primary),
                  label: Text("Stock"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map_rounded, color: AppConstants.primary),
                  label: Text("Magasins"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.sync_alt_outlined),
                  selectedIcon: Icon(Icons.sync_alt_rounded, color: AppConstants.primary),
                  label: Text("Mouvements"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded, color: AppConstants.primary),
                  label: Text("Bons & Cdes"),
                ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined, color: AppConstants.textSecondary),
                      tooltip: "Paramètres",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (ctx) => const SettingsView()),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: IndexedStack(index: _currentIndex, children: _pages)),
          ],
        ),
      );
    }

    // Disposition Mobile Standard avec IndexedStack pour préserver l'état et le scroll
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(child: IndexedStack(index: _currentIndex, children: _pages)),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 1.0),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 62,
            elevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppConstants.primary.withValues(alpha: 0.12),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppConstants.primary : AppConstants.textSecondary,
                letterSpacing: 0.2,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 22,
                color: isSelected ? AppConstants.primary : AppConstants.textSecondary.withValues(alpha: 0.75),
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: "Accueil",
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: "Stock",
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: "Magasins",
              ),
              NavigationDestination(
                icon: Icon(Icons.swap_horiz_rounded),
                selectedIcon: Icon(Icons.swap_horiz_rounded),
                label: "Flux",
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: "Bons",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
