import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/settings_provider.dart';
import 'package:frontend/providers/stock_provider.dart';
import 'package:frontend/services/scanner_service.dart';
import 'package:frontend/views/splash_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SplashView displays branding, progress bar and finishes preparation', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => StockProvider()),
          ChangeNotifierProvider(create: (_) => ScannerService()),
        ],
        child: const MaterialApp(
          home: SplashView(fastMode: true),
        ),
      ),
    );

    // Vérifier l'apparition des éléments de branding et pourcentage initial
    expect(find.text("GESTION DE STOCK & POINTS DE VENTE"), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('%'), findsWidgets);

    // Avancer le temps pour que la préparation se termine et navigue vers AuthGate / LoginView
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));

    // Vérifier que la navigation vers l'écran d'accueil / login a eu lieu
    expect(find.text('Connexion'), findsOneWidget);
  });
}
