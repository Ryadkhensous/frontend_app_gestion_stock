import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import '../../utils/constants.dart';
import '../../utils/permission_utils.dart';

class MapLocationPickerDialog extends StatefulWidget {
  final ll.LatLng? initialPosition;
  final String? title;

  const MapLocationPickerDialog({
    super.key,
    this.initialPosition,
    this.title,
  });

  @override
  State<MapLocationPickerDialog> createState() => _MapLocationPickerDialogState();
}

class _MapLocationPickerDialogState extends State<MapLocationPickerDialog> {
  final MapController _mapController = MapController();
  late ll.LatLng _selectedLocation;
  bool _isLoadingGps = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialPosition ?? const ll.LatLng(36.7538, 3.0588);
  }

  Future<void> _fetchCurrentGps() async {
    final ok = await PermissionUtils.requestGpsPermission(context, showDialogs: true);
    if (!ok) return;

    setState(() => _isLoadingGps = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final newLoc = ll.LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _selectedLocation = newLoc;
          _isLoadingGps = false;
        });
        _mapController.move(newLoc, 15.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'obtenir la position GPS : $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 580,
          height: 620,
          child: Stack(
            children: [
              // Carte interactive
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedLocation,
                  initialZoom: 13.0,
                  onTap: (_, point) {
                    setState(() {
                      _selectedLocation = point;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    fallbackUrl: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.stockapp.frontend',
                    errorTileCallback: (tile, error, stackTrace) {
                      // Gestion silencieuse des coupures réseau temporaires
                    },
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFFDC2626),
                          size: 46,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Barre d'instructions supérieure
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, color: AppConstants.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title ?? "Sélectionnez l'emplacement GPS",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              "GPS: ${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}",
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),

              // Bouton GPS Ma Position
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'fab_my_location_picker',
                  backgroundColor: Colors.white,
                  foregroundColor: AppConstants.primary,
                  onPressed: _isLoadingGps ? null : _fetchCurrentGps,
                  child: _isLoadingGps
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primary),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),

              // Barre inférieure de validation
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text(
                          "Valider cet emplacement",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        onPressed: () {
                          Navigator.pop(context, _selectedLocation);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
