import 'package:flutter/material.dart';

class AppConstants {
  // Détection dynamique de l'URL FastAPI
  static String get defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    // Serveur Cloud permanent Render (PostgreSQL Neon)
    return "https://gestion-stock-api-hzbg.onrender.com/api";
  }

  // Couleurs de l'application
  static const Color primary = Color(0xFF4F46E5);      
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color secondary = Color(0xFF0D9488);    
  static const Color accent = Color(0xFFF59E0B);     
  static const Color background = Color(0xFFF8FAFC);   
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);  
  static const Color textSecondary = Color(0xFF64748B); 
  static const Color danger = Color(0xFFEF4444);      
  static const Color success = Color(0xFF10B981);     
}
