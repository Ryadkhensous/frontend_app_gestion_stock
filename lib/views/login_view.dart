import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/stock_provider.dart';
import '../utils/constants.dart';
import 'main_screen.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _isRegisterMode = false;

  // Login form controllers
  final _loginUsernameCtrl = TextEditingController(text: "admin");
  final _loginPasswordCtrl = TextEditingController(text: "admin123");
  bool _loginObscure = true;

  // Register form controllers
  final _regStoreNameCtrl = TextEditingController();
  final _regUsernameCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  bool _regObscure = true;

  @override
  void dispose() {
    _loginUsernameCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regStoreNameCtrl.dispose();
    _regUsernameCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regEmailCtrl.dispose();
    super.dispose();
  }


  Future<void> _handleLogin() async {
    final auth = context.read<AuthProvider>();
    final username = _loginUsernameCtrl.text.trim();
    final password = _loginPasswordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      _showToast("Veuillez renseigner votre identifiant et mot de passe", isError: true);
      return;
    }

    final success = await auth.login(username, password);
    if (!mounted) return;

    if (success) {
      await context.read<StockProvider>().loadAll();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      _showToast(auth.errorMessage ?? "Identifiant ou mot de passe incorrect", isError: true);
    }
  }

  Future<void> _handleRegister() async {
    final auth = context.read<AuthProvider>();
    final storeName = _regStoreNameCtrl.text.trim();
    final username = _regUsernameCtrl.text.trim();
    final password = _regPasswordCtrl.text;
    final email = _regEmailCtrl.text.trim();

    if (storeName.isEmpty || username.isEmpty || password.isEmpty) {
      _showToast("Veuillez renseigner les champs obligatoires (*)", isError: true);
      return;
    }

    final success = await auth.registerTenant(
      storeName: storeName,
      adminUsername: username,
      adminPassword: password,
      adminEmail: email.isNotEmpty ? email : null,
      subscriptionPlan: "ENTERPRISE",
    );
    if (!mounted) return;

    if (success) {
      await context.read<StockProvider>().loadAll();
      if (!mounted) return;
      _showToast("Magasin '$storeName' créé avec succès !");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      _showToast(auth.errorMessage ?? "Échec de création du magasin", isError: true);
    }
  }


  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppConstants.danger : AppConstants.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Arrière-plan décoratif avec gradient immersif
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppConstants.primary.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppConstants.secondary.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 460 : double.infinity),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge Logo & Titre
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppConstants.primary.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/stockio_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Stockio",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Solution Multi-Magasins & Points de Vente",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Sélecteur Mode : Connexion / Nouveau Magasin
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildModeSwitchButton(
                                label: "Connexion",
                                icon: Icons.login_rounded,
                                isSelected: !_isRegisterMode,
                                onTap: () => setState(() => _isRegisterMode = false),
                              ),
                            ),
                            Expanded(
                              child: _buildModeSwitchButton(
                                label: "Nouveau Magasin",
                                icon: Icons.add_business_rounded,
                                isSelected: _isRegisterMode,
                                onTap: () => setState(() => _isRegisterMode = true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Carte Formulaire Blanche Ultra-Propre
                      Container(
                        padding: const EdgeInsets.all(22.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: AnimatedCrossFade(
                          duration: const Duration(milliseconds: 250),
                          crossFadeState: _isRegisterMode
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: _buildLoginForm(auth),
                          secondChild: _buildRegisterForm(auth),
                        ),
                      ),


                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitchButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppConstants.primary : Colors.white70,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppConstants.textPrimary : Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_open_rounded, color: AppConstants.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Espace Magasin",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Connectez-vous à votre boutique",
                    style: TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Champ Identifiant
        TextFormField(
          controller: _loginUsernameCtrl,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: "Identifiant",
            hintText: "ex: admin",
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),

        // Champ Mot de passe
        TextFormField(
          controller: _loginPasswordCtrl,
          obscureText: _loginObscure,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: "Mot de passe",
            prefixIcon: const Icon(Icons.key_outlined, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_loginObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              onPressed: () => setState(() => _loginObscure = !_loginObscure),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),


        // Bouton Connexion avec dégradé
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: auth.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            icon: auth.isLoading
                ? const SizedBox.shrink()
                : const Icon(Icons.login_rounded, size: 18),
            label: auth.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    "Se Connecter au Magasin",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_business_rounded, color: AppConstants.secondary, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Nouveau Client Magasin",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Créez une boutique isolée en 1 clic",
                    style: TextStyle(fontSize: 11, color: AppConstants.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _regStoreNameCtrl,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: "Nom de l'Enseigne / Magasin *",
            hintText: "ex: Superette Alger Centre",
            prefixIcon: const Icon(Icons.storefront_outlined, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _regUsernameCtrl,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: "Identifiant Administrateur *",
            hintText: "ex: gerant_alger",
            prefixIcon: const Icon(Icons.account_circle_outlined, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _regPasswordCtrl,
          obscureText: _regObscure,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: "Mot de passe initial *",
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_regObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              onPressed: () => setState(() => _regObscure = !_regObscure),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: auth.isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            icon: auth.isLoading
                ? const SizedBox.shrink()
                : const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: auth.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    "Créer le Magasin & Démarrer",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ),
      ],
    );
  }
}
