import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/stock_provider.dart';
import '../models/point_of_sale.dart';
import '../utils/constants.dart';
import 'widgets/document_form_dialog.dart';
import 'widgets/map_location_picker_dialog.dart';
import '../utils/permission_utils.dart';

enum MapTileStyle {
  standard(
    "OpenStreetMap Standard",
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    "https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",
  ),
  voyager(
    "Plan Détaillé (OSM)",
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    "https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",
  ),
  light(
    "Plan Urbain (Esri World)",
    "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}",
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  ),
  dark(
    "Vue Sombre / Satellite (Esri)",
    "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  ),
  hot(
    "Humanitaire (HOT - Contrasté)",
    "https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  ),
  satellite(
    "Vue Satellite (Esri Imagery)",
    "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  ),
  topo(
    "Topographique (Esri Topo)",
    "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}",
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  );

  final String label;
  final String url;
  final String fallbackUrl;
  const MapTileStyle(this.label, this.url, this.fallbackUrl);
}

class PointsOfSaleView extends StatefulWidget {
  const PointsOfSaleView({super.key});

  @override
  State<PointsOfSaleView> createState() => _PointsOfSaleViewState();
}

class _PointsOfSaleViewState extends State<PointsOfSaleView> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  bool _isMapView = true;
  ll.LatLng _center = const ll.LatLng(36.7538, 3.0588); // Alger par défaut
  Position? _userGpsPosition;
  bool _isLoadingGps = false;
  bool _sortByDistance = false;
  MapTileStyle _tileStyle = MapTileStyle.standard;
  MapTileStyle get safeTileStyle {
    try {
      return _tileStyle;
    } catch (_) {
      return MapTileStyle.standard;
    }
  }

  bool _isValidLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN || lat.isInfinite || lng.isInfinite) return false;
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGpsLocation();
      try {
        final posList = context.read<StockProvider>().pointsOfSale;
        if (posList.isNotEmpty) {
          final first = posList.first;
          if (_isValidLatLng(first.latitude, first.longitude)) {
            setState(() {
              _center = ll.LatLng(first.latitude, first.longitude);
            });
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initGpsLocation() async {
    try {
      final ok = await PermissionUtils.requestGpsPermission(context, showDialogs: false);
      if (!ok) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted && _isValidLatLng(pos.latitude, pos.longitude)) {
        setState(() {
          _userGpsPosition = pos;
        });
      }
    } catch (_) {}
  }

  double? _calculateDistanceMeters(PointOfSale pos) {
    if (_userGpsPosition == null) return null;
    if (!_isValidLatLng(pos.latitude, pos.longitude)) return null;
    if (!_isValidLatLng(_userGpsPosition!.latitude, _userGpsPosition!.longitude)) return null;
    try {
      return Geolocator.distanceBetween(
        _userGpsPosition!.latitude,
        _userGpsPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  String _formatDistance(double meters) {
    if (meters.isNaN || meters.isInfinite || meters < 0) return "-- m";
    if (meters < 1000) {
      return "${meters.round()} m";
    }
    final km = meters / 1000.0;
    return "${km.toStringAsFixed(1)} km";
  }

  String _formatDrivingTime(double meters) {
    if (meters.isNaN || meters.isInfinite || meters < 0) return "-- min";
    final minutes = (meters / 1000.0 / 35.0 * 60).round();
    if (minutes < 1) return "< 1 min";
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return "${h}h ${m}m en voiture";
    }
    return "~$minutes min en voiture";
  }

  List<PointOfSale> _filterAndSortPos(List<PointOfSale> originalList) {
    final query = _searchCtrl.text.trim().toLowerCase();
    var list = originalList.where((p) {
      if (query.isEmpty) return true;
      final name = p.name.toLowerCase();
      final city = (p.city ?? "").toLowerCase();
      final address = p.address.toLowerCase();
      return name.contains(query) || city.contains(query) || address.contains(query);
    }).toList();

    if (_sortByDistance && _userGpsPosition != null) {
      list.sort((a, b) {
        final distA = _calculateDistanceMeters(a) ?? double.infinity;
        final distB = _calculateDistanceMeters(b) ?? double.infinity;
        return distA.compareTo(distB);
      });
    }

    return list;
  }

  PointOfSale? _getNearestPos(List<PointOfSale> list) {
    if (_userGpsPosition == null || list.isEmpty) return null;
    PointOfSale? nearest;
    double minDistance = double.infinity;
    for (final pos in list) {
      final dist = _calculateDistanceMeters(pos);
      if (dist != null && dist < minDistance) {
        minDistance = dist;
        nearest = pos;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StockProvider>();
    final posList = provider.pointsOfSale;
    final filteredList = _filterAndSortPos(posList);
    final selectedPos = provider.selectedPos;
    final nearestPos = _getNearestPos(posList);

    return Scaffold(
      backgroundColor: AppConstants.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "Points de Vente & GPS",
          style: TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.list_alt_rounded : Icons.map_outlined, color: AppConstants.primary),
            tooltip: _isMapView ? "Afficher en liste" : "Afficher sur la carte",
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
          IconButton(
            icon: _isLoadingGps
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primary),
                  )
                : const Icon(Icons.my_location, color: AppConstants.primary),
            tooltip: "Centrer sur ma position GPS",
            onPressed: _isLoadingGps ? null : _centerOnCurrentLocation,
          ),
        ],
      ),
      body: Builder(
        builder: (ctx) {
          try {
            return _isMapView
                ? _buildMapInterface(filteredList, selectedPos, provider, nearestPos)
                : _buildListView(filteredList, provider, nearestPos);
          } catch (e, stack) {
            debugPrint("Erreur affichage PointsOfSaleView: $e\n$stack");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off_rounded, color: AppConstants.primary, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      "Affichage des points de vente",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "La carte est en cours de recalibration. Basculez en vue liste pour continuer.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.list_alt_rounded),
                      label: const Text("Passer en vue liste"),
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary, foregroundColor: Colors.white),
                      onPressed: () => setState(() => _isMapView = false),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_new_pos',
        backgroundColor: AppConstants.primary,
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text("Nouveau Point de Vente", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showPosDialog(context, provider),
      ),
    );
  }

  Widget _buildMapInterface(
    List<PointOfSale> posList,
    PointOfSale? selectedPos,
    StockProvider provider,
    PointOfSale? nearestPos,
  ) {
    final validCenter = _isValidLatLng(_center.latitude, _center.longitude)
        ? _center
        : const ll.LatLng(36.7538, 3.0588);

    return Stack(
      children: [
        // Carte FlutterMap principale
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: validCenter,
            initialZoom: 7.0,
            onTap: (_, point) {
              provider.selectPos(null);
            },
          ),
          children: [
            // Couche de tuiles cartographiques
            TileLayer(
              urlTemplate: safeTileStyle.url,
              fallbackUrl: safeTileStyle.fallbackUrl,
              userAgentPackageName: 'com.stockapp.frontend',
              errorTileCallback: (tile, error, stackTrace) {},
            ),

            // Tracé direct vol d'oiseau entre la position GPS et le magasin sélectionné
            if (selectedPos != null &&
                _userGpsPosition != null &&
                _isValidLatLng(selectedPos.latitude, selectedPos.longitude) &&
                _isValidLatLng(_userGpsPosition!.latitude, _userGpsPosition!.longitude))
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      ll.LatLng(_userGpsPosition!.latitude, _userGpsPosition!.longitude),
                      ll.LatLng(selectedPos.latitude, selectedPos.longitude),
                    ],
                    strokeWidth: 3.5,
                    color: const Color(0xFF2563EB),
                  ),
                ],
              ),

            // Couche des Marqueurs
            MarkerLayer(
              markers: [
                // Marqueur de l'utilisateur avec halo bleu pulsé
                if (_userGpsPosition != null && _isValidLatLng(_userGpsPosition!.latitude, _userGpsPosition!.longitude))
                  Marker(
                    point: ll.LatLng(_userGpsPosition!.latitude, _userGpsPosition!.longitude),
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2563EB),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Marqueurs des points de vente
                ...posList.where((pos) => _isValidLatLng(pos.latitude, pos.longitude)).map((pos) {
                  final isSelected = selectedPos?.id == pos.id;
                  final isNearest = nearestPos?.id == pos.id;
                  final distance = _calculateDistanceMeters(pos);

                  return Marker(
                    point: ll.LatLng(pos.latitude, pos.longitude),
                    width: isSelected ? 80 : 64,
                    height: isSelected ? 75 : 62,
                    child: GestureDetector(
                      onTap: () {
                        provider.selectPos(pos);
                        _mapController.move(ll.LatLng(pos.latitude, pos.longitude), 14.0);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (distance != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFDC2626)
                                    : (isNearest ? const Color(0xFF10B981) : const Color(0xFF1E293B)),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                                ],
                              ),
                              child: Text(
                                _formatDistance(distance),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Icon(
                            Icons.location_on,
                            color: isSelected
                                ? const Color(0xFFDC2626)
                                : (isNearest ? const Color(0xFF10B981) : AppConstants.primary),
                            size: isSelected ? 42 : 34,
                            shadows: const [
                              Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // Barre de recherche et filtres supérieurs flottants
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
                      if (mounted) setState(() {});
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Rechercher par nom ou ville (ex: Alger, Oran)...",
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, color: AppConstants.primary),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Chips d'état GPS & Tri
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Badge état GPS
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _userGpsPosition != null
                            ? Colors.green.withValues(alpha: 0.9)
                            : const Color(0xFF475569),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _userGpsPosition != null ? Icons.gps_fixed : Icons.gps_not_fixed,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _userGpsPosition != null ? "GPS Connecté" : "GPS En attente",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bouton Tri par distance
                    FilterChip(
                      label: const Text("Trier par proximité GPS", style: TextStyle(fontSize: 11)),
                      avatar: const Icon(Icons.near_me, size: 14),
                      showCheckmark: false,
                      selected: _sortByDistance,
                      selectedColor: AppConstants.primary,
                      labelStyle: TextStyle(
                        color: _sortByDistance ? Colors.white : const Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        setState(() => _sortByDistance = val);
                        if (val && _userGpsPosition == null) {
                          _initGpsLocation();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Magasin le plus proche badge
                    if (nearestPos != null)
                      GestureDetector(
                        onTap: () {
                          provider.selectPos(nearestPos);
                          _mapController.move(ll.LatLng(nearestPos.latitude, nearestPos.longitude), 14.0);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storefront_rounded, color: Colors.green, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "Plus proche : ${nearestPos.name}",
                                style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Outils de contrôle sur le côté droit de la carte
        Positioned(
          top: 130,
          right: 12,
          child: Column(
            children: [
              // Bouton Ma Position
              _buildMapToolButton(
                icon: Icons.my_location,
                tooltip: "Centrer sur ma position GPS",
                onPressed: _centerOnCurrentLocation,
              ),
              const SizedBox(height: 8),
              // Bouton Tout Afficher (Fit Bounds)
              _buildMapToolButton(
                icon: Icons.zoom_out_map_rounded,
                tooltip: "Ajuster la vue (Tout afficher)",
                onPressed: () => _fitAllPoints(posList),
              ),
              const SizedBox(height: 8),
              // Bouton Sélecteur de style de carte
              _buildMapToolButton(
                icon: Icons.layers_outlined,
                tooltip: "Style de la carte",
                onPressed: _showTileStyleSheet,
              ),
            ],
          ),
        ),

        // Carte flottante des détails du point de vente sélectionné
        if (selectedPos != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: 80,
            child: _buildPosDetailCard(selectedPos, provider),
          ),
      ],
    );
  }

  Widget _buildMapToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppConstants.primary, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  void _showTileStyleSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choisir le fond cartographique",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...MapTileStyle.values.map((style) => ListTile(
                  leading: Icon(
                    style == _tileStyle ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: AppConstants.primary,
                  ),
                  title: Text(style.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    setState(() => _tileStyle = style);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _fitAllPoints(List<PointOfSale> posList) {
    if (posList.isEmpty && _userGpsPosition == null) return;

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;

    void includePoint(double lat, double lng) {
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    if (_userGpsPosition != null) {
      includePoint(_userGpsPosition!.latitude, _userGpsPosition!.longitude);
    }

    for (final pos in posList) {
      includePoint(pos.latitude, pos.longitude);
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    _mapController.move(ll.LatLng(centerLat, centerLng), 6.5);
  }

  Widget _buildPosDetailCard(PointOfSale pos, StockProvider provider) {
    final distanceMeters = _calculateDistanceMeters(pos);

    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête & titre
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppConstants.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.store, color: AppConstants.primary, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pos.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () => provider.selectPos(null),
                )
              ],
            ),
            const SizedBox(height: 6),

            // Adresse
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppConstants.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "${pos.address}${pos.city != null ? ', ${pos.city}' : ''}",
                    style: const TextStyle(fontSize: 13, color: AppConstants.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Données GPS & Distance
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.gps_fixed, size: 14, color: AppConstants.primary),
                      const SizedBox(width: 6),
                      Text(
                        "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}",
                        style: const TextStyle(fontSize: 11, color: AppConstants.primary, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  if (distanceMeters != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_car_rounded, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          "${_formatDistance(distanceMeters)} (${_formatDrivingTime(distanceMeters)})",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            if (pos.phone != null || pos.managerName != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (pos.managerName != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: AppConstants.textSecondary),
                        const SizedBox(width: 4),
                        Text(pos.managerName!, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  if (pos.phone != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppConstants.textSecondary),
                        const SizedBox(width: 4),
                        Text(pos.phone!, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Actions : Itinéraire, Nouveau Bon, Modifier, Supprimer
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                // Bouton Itinéraire GPS direct vers l'application Google Maps
                ElevatedButton.icon(
                  icon: const Icon(Icons.navigation_rounded, size: 15),
                  label: const Text("Itinéraire GPS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _launchGoogleMapsItinerary(pos),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF64748B)),
                  tooltip: "Détails & Distance",
                  onPressed: () => _showItineraryDialog(context, pos),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_rounded, size: 15, color: Color(0xFF0D9488)),
                  label: const Text("Nouveau Bon", style: TextStyle(color: Color(0xFF0D9488), fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => DocumentFormDialog(
                        initialDocType: 'DELIVERY',
                        initialDirection: 'OUTGOING',
                        initialPos: pos,
                      ),
                    );
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppConstants.primary),
                  label: const Text("Modifier", style: TextStyle(color: AppConstants.primary, fontSize: 12)),
                  onPressed: () => _showPosDialog(context, provider, posToEdit: pos),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text("Supprimer", style: TextStyle(color: Colors.red, fontSize: 12)),
                  onPressed: () => _confirmDeletePos(context, provider, pos),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Ouvre directement l'application Google Maps avec l'itinéraire préconfiguré
  Future<void> _launchGoogleMapsItinerary(PointOfSale pos) async {
    final lat = pos.latitude;
    final lng = pos.longitude;

    // 1. Schéma natif de navigation Google Maps (Android : lance directement l'appli en mode guidage GPS)
    final Uri nativeNavUri = Uri.parse("google.navigation:q=$lat,$lng&mode=d");

    // 2. URL universelle Google Maps Directions (Android / iOS / Web / PC)
    final Uri universalUri = Uri.parse(
      _userGpsPosition != null
          ? "https://www.google.com/maps/dir/?api=1&origin=${_userGpsPosition!.latitude},${_userGpsPosition!.longitude}&destination=$lat,$lng&travelmode=driving"
          : "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
    );

    try {
      // Tenter d'ouvrir l'application Google Maps native
      if (await canLaunchUrl(nativeNavUri)) {
        final launched = await launchUrl(nativeNavUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }
    } catch (_) {}

    // Fallback vers l'URL universelle (ouvre l'application Google Maps ou le navigateur)
    try {
      final launched = await launchUrl(universalUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(universalUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Impossible d'ouvrir Google Maps : $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showItineraryDialog(BuildContext context, PointOfSale pos) {
    final distanceMeters = _calculateDistanceMeters(pos);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Navigation GPS vers ${pos.name}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        "${pos.address}${pos.city != null ? ', ${pos.city}' : ''}",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Distance vol d'oiseau :", style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      Text(
                        distanceMeters != null ? _formatDistance(distanceMeters) : "Position GPS inconnue",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                  if (distanceMeters != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Temps estimé de trajet :", style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        Text(
                          _formatDrivingTime(distanceMeters),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Coordonnées GPS :", style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      Text(
                        "${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}",
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text("Copier Coordonnées"),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: "${pos.latitude},${pos.longitude}"));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Coordonnées GPS copiées dans le presse-papier !"),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: const Text("Ouvrir Google Maps"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _launchGoogleMapsItinerary(pos);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<PointOfSale> posList, StockProvider provider, PointOfSale? nearestPos) {
    if (posList.isEmpty) {
      return const Center(child: Text("Aucun point de vente trouvé."));
    }
    return RefreshIndicator(
      onRefresh: () => provider.loadPointsOfSale(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: posList.length,
        itemBuilder: (context, index) {
          final pos = posList[index];
          final isNearest = nearestPos?.id == pos.id;
          final distanceMeters = _calculateDistanceMeters(pos);

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isNearest ? const Color(0xFF10B981) : Colors.grey.shade200,
                width: isNearest ? 1.5 : 1.0,
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isNearest ? const Color(0xFFDCFCE7) : const Color(0xFFEEF2FF),
                child: Icon(
                  Icons.store,
                  color: isNearest ? const Color(0xFF10B981) : AppConstants.primary,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      pos.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (distanceMeters != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isNearest ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatDistance(distanceMeters),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${pos.address}${pos.city != null ? ' (${pos.city})' : ''}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "GPS: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}",
                        style: const TextStyle(fontSize: 11, color: AppConstants.primary, fontFamily: 'monospace'),
                      ),
                      if (isNearest)
                        const Text(
                          "• Le plus proche",
                          style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 19),
                    tooltip: "Itinéraire Google Maps",
                    onPressed: () => _launchGoogleMapsItinerary(pos),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.map, color: AppConstants.primary, size: 19),
                    tooltip: "Voir sur la carte",
                    onPressed: () {
                      provider.selectPos(pos);
                      setState(() {
                        _isMapView = true;
                        _center = ll.LatLng(pos.latitude, pos.longitude);
                      });
                      _mapController.move(ll.LatLng(pos.latitude, pos.longitude), 14.0);
                    },
                  ),
                  PopupMenuButton<String>(
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                    onSelected: (val) {
                      if (val == 'itinerary') {
                        _launchGoogleMapsItinerary(pos);
                      } else if (val == 'details') {
                        _showItineraryDialog(context, pos);
                      } else if (val == 'order') {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => DocumentFormDialog(
                            initialDocType: 'DELIVERY',
                            initialDirection: 'OUTGOING',
                            initialPos: pos,
                          ),
                        );
                      } else if (val == 'edit') {
                        _showPosDialog(context, provider, posToEdit: pos);
                      } else if (val == 'delete') {
                        _confirmDeletePos(context, provider, pos);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'itinerary',
                        child: Row(
                          children: [
                            Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 18),
                            SizedBox(width: 8),
                            Text("Itinéraire Google Maps"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 18),
                            SizedBox(width: 8),
                            Text("Détails & Coordonnées"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'order',
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, color: Color(0xFF0D9488), size: 18),
                            SizedBox(width: 8),
                            Text("Créer un Bon"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, color: AppConstants.primary, size: 18),
                            SizedBox(width: 8),
                            Text("Modifier"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text("Supprimer", style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _centerOnCurrentLocation() async {
    final ok = await PermissionUtils.requestGpsPermission(context, showDialogs: true);
    if (!ok) return;

    setState(() => _isLoadingGps = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final target = ll.LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _userGpsPosition = position;
          _center = target;
          _isLoadingGps = false;
        });
        _mapController.move(target, 14.5);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Position GPS indisponible : $e")),
        );
      }
    }
  }

  void _confirmDeletePos(BuildContext context, StockProvider provider, PointOfSale pos) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer le point de vente ?"),
        content: Text("Voulez-vous vraiment supprimer '${pos.name}' ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deletePointOfSale(pos.id);
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPosDialog(BuildContext context, StockProvider provider, {PointOfSale? posToEdit}) {
    final nameCtrl = TextEditingController(text: posToEdit?.name ?? "");
    final addressCtrl = TextEditingController(text: posToEdit?.address ?? "");
    final cityCtrl = TextEditingController(text: posToEdit?.city ?? "");
    final latCtrl = TextEditingController(
      text: posToEdit != null
          ? posToEdit.latitude.toStringAsFixed(6)
          : (_userGpsPosition?.latitude.toStringAsFixed(6) ?? _center.latitude.toStringAsFixed(6)),
    );
    final lngCtrl = TextEditingController(
      text: posToEdit != null
          ? posToEdit.longitude.toStringAsFixed(6)
          : (_userGpsPosition?.longitude.toStringAsFixed(6) ?? _center.longitude.toStringAsFixed(6)),
    );
    final phoneCtrl = TextEditingController(text: posToEdit?.phone ?? "");
    final managerCtrl = TextEditingController(text: posToEdit?.managerName ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        posToEdit == null ? "Nouveau Point de Vente" : "Modifier le Point de Vente",
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.touch_app_rounded, size: 16),
                      label: const Text("Pointer sur la carte", style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: AppConstants.primary),
                      ),
                      onPressed: () async {
                        final curLat = double.tryParse(latCtrl.text) ?? 36.7538;
                        final curLng = double.tryParse(lngCtrl.text) ?? 3.0588;
                        final selectedLoc = await showDialog<ll.LatLng>(
                          context: context,
                          builder: (_) => MapLocationPickerDialog(
                            initialPosition: ll.LatLng(curLat, curLng),
                            title: "Positionner ${nameCtrl.text.isNotEmpty ? nameCtrl.text : 'le magasin'}",
                          ),
                        );
                        if (selectedLoc != null) {
                          setModalState(() {
                            latCtrl.text = selectedLoc.latitude.toStringAsFixed(6);
                            lngCtrl.text = selectedLoc.longitude.toStringAsFixed(6);
                          });
                        }
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text("Ma position GPS", style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () async {
                        final ok = await PermissionUtils.requestGpsPermission(context, showDialogs: true);
                        if (!ok) return;
                        try {
                          final pos = await Geolocator.getCurrentPosition(
                            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                          );
                          setModalState(() {
                            latCtrl.text = pos.latitude.toStringAsFixed(6);
                            lngCtrl.text = pos.longitude.toStringAsFixed(6);
                          });
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Impossible de lire la position GPS : $e")),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Nom du Magasin / Point de vente *", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: "Adresse physique *", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: "Ville (ex: Alger, Oran...)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: "Latitude GPS *",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.gps_fixed, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: "Longitude GPS *",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.gps_fixed, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: managerCtrl,
                        decoration: const InputDecoration(labelText: "Responsable", border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: "Téléphone", border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || addressCtrl.text.isEmpty || latCtrl.text.isEmpty || lngCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text("Le nom, l'adresse et les coordonnées GPS sont requis.")),
                        );
                        return;
                      }
                      final lat = double.tryParse(latCtrl.text);
                      final lng = double.tryParse(lngCtrl.text);
                      if (lat == null || lng == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text("Coordonnées GPS invalides.")),
                        );
                        return;
                      }

                      final data = {
                        "name": nameCtrl.text.trim(),
                        "address": addressCtrl.text.trim(),
                        "city": cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim(),
                        "latitude": lat,
                        "longitude": lng,
                        "manager_name": managerCtrl.text.trim().isEmpty ? null : managerCtrl.text.trim(),
                        "phone": phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                        "is_active": true,
                      };

                      bool ok;
                      if (posToEdit == null) {
                        ok = await provider.addPointOfSale(data);
                      } else {
                        ok = await provider.updatePointOfSale(posToEdit.id, data);
                      }

                      if (ok && ctx.mounted) {
                        Navigator.pop(ctx);
                        _mapController.move(ll.LatLng(lat, lng), 14.0);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(posToEdit == null ? "Point de vente créé !" : "Point de vente mis à jour !"),
                            backgroundColor: AppConstants.success,
                          ),
                        );
                      } else if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(provider.errorMessage ?? "Erreur lors de l'enregistrement")),
                        );
                      }
                    },
                    child: Text(
                      posToEdit == null ? "Enregistrer sur la Carte" : "Mettre à jour le Magasin",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
