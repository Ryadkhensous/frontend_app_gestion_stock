import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  /// Demande et vérifie l'autorisation d'accès aux fichiers et photos de l'appareil.
  /// Affiche une boîte de dialogue explicative si la permission est refusée.
  /// Renvoie `true` si autorisé, `false` sinon.
  static Future<bool> requestFileStoragePermission(BuildContext context) async {
    // Sur le Web et Desktop (Windows, macOS, Linux), les dialogues natifs de fichiers
    // sont directement gérés par l'OS sans système de permissions mobiles à l'exécution.
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return true;
    }

    try {
      PermissionStatus status;
      if (Platform.isAndroid) {
        // Tenter d'abord la permission photos (Android 13+ / API 33+)
        status = await Permission.photos.status;
        if (status.isDenied) {
          status = await Permission.photos.request();
        }

        // Si photos n'est pas accordé, tester storage (Android 12 et versions antérieures)
        if (!status.isGranted && !status.isLimited) {
          final storageStatus = await Permission.storage.status;
          if (storageStatus.isDenied) {
            status = await Permission.storage.request();
          } else if (storageStatus.isGranted) {
            status = storageStatus;
          }
        }
      } else {
        // iOS
        status = await Permission.photos.status;
        if (status.isDenied) {
          status = await Permission.photos.request();
        }
      }

      if (status.isGranted || status.isLimited) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        if (context.mounted) {
          await _showPermissionDeniedDialog(
            context,
            title: "Autorisation Fichiers & Photos",
            message: "L'accès aux photos et fichiers a été désactivé. Pour importer une photo de produit depuis votre appareil, veuillez autoriser l'accès dans les paramètres.",
            onOpenSettings: () => openAppSettings(),
          );
        }
        return false;
      }

      if (status.isDenied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Accès aux fichiers refusé. Impossible de sélectionner une photo."),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      return false;
    } catch (e) {
      debugPrint("PermissionUtils.requestFileStoragePermission error: $e");
      return true;
    }
  }

  /// Demande et vérifie l'accès au service et à la permission GPS (Localisation).
  /// Vérifie si le GPS matériel est activé et demande la permission si nécessaire.
  /// Renvoie `true` si le GPS est activé et autorisé, `false` sinon.
  static Future<bool> requestGpsPermission(BuildContext context, {bool showDialogs = true}) async {
    try {
      // 1. Vérifier si le service de localisation GPS est allumé sur l'appareil
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showDialogs && context.mounted) {
          await _showPermissionDeniedDialog(
            context,
            title: "Service GPS désactivé",
            message: "La localisation GPS de votre appareil est désactivée. Souhaitez-vous ouvrir les paramètres pour l'activer ?",
            buttonText: "Activer le GPS",
            onOpenSettings: () => Geolocator.openLocationSettings(),
          );
        }
        return false;
      }

      // 2. Vérifier la permission de localisation
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (showDialogs && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("L'autorisation GPS a été refusée."),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (showDialogs && context.mounted) {
          await _showPermissionDeniedDialog(
            context,
            title: "Autorisation GPS requise",
            message: "L'accès à votre position GPS a été refusé de façon permanente. Pour afficher votre position et calculer les distances avec les points de vente, veuillez l'autoriser dans les paramètres.",
            onOpenSettings: () => Geolocator.openAppSettings(),
          );
        }
        return false;
      }

      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint("PermissionUtils.requestGpsPermission error: $e");
      return false;
    }
  }

  /// Boîte de dialogue explicative invitant l'utilisateur à ouvrir les paramètres de l'appareil
  static Future<void> _showPermissionDeniedDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = "Ouvrir les Paramètres",
    required Future<bool> Function() onOpenSettings,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: Color(0xFF4F46E5), size: 24),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onOpenSettings();
            },
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
