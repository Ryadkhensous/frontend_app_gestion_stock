import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../main.dart';

class SplashView extends StatefulWidget {
  final bool fastMode;
  const SplashView({super.key, this.fastMode = false});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  String _currentStep = "Initialisation du système...";
  String _detailStep = "Démarrage des services Stockio";
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();

    // Démarrage de la préparation réelle des fichiers et services
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runRealPreparation();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _runRealPreparation() async {
    final stepDelay = widget.fastMode ? const Duration(milliseconds: 10) : const Duration(milliseconds: 320);

    try {
      // 1. Étape 1 : Initialisation du stockage local (SharedPreferences)
      _updateProgress(0.15, "Initialisation du stockage local...", "Vérification des partitions SharedPreferences");
      await SharedPreferences.getInstance();
      await Future.delayed(stepDelay);

      // 2. Étape 2 : Chargement des paramètres de l'entreprise
      _updateProgress(0.38, "Chargement des paramètres...", "Lecture devise, identifiants légaux et profil");
      if (mounted) {
        final settings = context.read<SettingsProvider>();
        await settings.loadSettings().catchError((_) {});
      }
      await Future.delayed(stepDelay);

      // 3. Étape 3 : Session utilisateur & Authentification
      _updateProgress(0.62, "Vérification de la session...", "Lecture des jetons d'accès et sécurité");
      if (mounted) {
        final auth = context.read<AuthProvider>();
        if (!auth.isInitialized) {
          await auth.loadSavedAuth().catchError((_) {});
        }
      }
      await Future.delayed(stepDelay);

      // 4. Étape 4 : Test de connectivité API Cloud
      _updateProgress(0.85, "Synchronisation des services...", "Test de liaison avec l'infrastructure Cloud");
      try {
        await ApiService.instance.checkServerConnection().timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );
      } catch (_) {}
      await Future.delayed(stepDelay);

      // 5. Étape 5 : Finalisation
      _updateProgress(1.0, "Stockio est prêt !", "Bienvenue sur votre application");
      await Future.delayed(widget.fastMode ? const Duration(milliseconds: 20) : const Duration(milliseconds: 400));

    } catch (e) {
      // En cas d'imprévu, on s'assure que l'utilisateur peut toujours entrer
      _updateProgress(1.0, "Prêt !", "Démarrage en mode hors-ligne");
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (mounted && !_hasNavigated) {
      _hasNavigated = true;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    }
  }

  void _updateProgress(double progress, String step, String detail) {
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _currentStep = step;
      _detailStep = detail;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    // Dimension ajustée du logo selon l'écran
    final logoSize = (size.width * (isTablet ? 0.32 : 0.58)).clamp(180.0, 260.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B), // Bleu nuit profond élégant
      body: Stack(
        children: [
          // Arrière-plan dégradé subtil avec orbe lumineux
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0284C7).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal centré et ajusté
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Logo Stockio animé
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: logoSize,
                        height: logoSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                              blurRadius: 36,
                              spreadRadius: 2,
                              offset: const Offset(0, 14),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/images/stockio_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Sous-titre moderne
                    Opacity(
                      opacity: 0.85,
                      child: Text(
                        "GESTION DE STOCK & POINTS DE VENTE",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: isTablet ? 13 : 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Section Loading Réel
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Column(
                        children: [
                          // Barre de progression avec animation continue et fluide
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutQuad,
                            tween: Tween<double>(begin: 0.0, end: _progress),
                            builder: (context, value, child) {
                              return Column(
                                children: [
                                  // Pourcentage et étape en cours
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _currentStep,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "${(value * 100).toInt()}%",
                                        style: const TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Barre stylisée avec dégradé
                                  Container(
                                    height: 7,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            width: constraints.maxWidth * value.clamp(0.0, 1.0),
                                            height: 7,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF0284C7),
                                                  Color(0xFF38BDF8),
                                                  Color(0xFFF97316),
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // Détail de l'étape
                          Text(
                            _detailStep,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Version au bas de l'écran
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        "Stockio v1.0 • Sécurisé & Multi-Plateforme",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
