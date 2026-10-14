import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Application smoke test - Auth & Login view standard and small screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StockioApp(skipSplash: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Stockio'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Nouveau Magasin'), findsOneWidget);
    expect(find.text('Se Connecter au Magasin'), findsOneWidget);

    // Switch to Register mode
    await tester.tap(find.text('Nouveau Magasin'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Nouveau Client Magasin'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('Créer le Magasin & Démarrer'), findsOneWidget);

    // Tap BASIC plan
    await tester.tap(find.text('BASIC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
  });
}
