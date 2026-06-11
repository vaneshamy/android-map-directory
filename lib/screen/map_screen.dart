import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  final dynamic place;
  final LatLng userLocation;

  const MapScreen({
    super.key,
    required this.place,
    required this.userLocation,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<LatLng> routePoints = [];
  bool _isLoading = true;
  String _distance = '-';
  String _duration = '-';

  @override
  void initState() {
    super.initState();
    _getRoute();
  }

  Future<void> _getRoute() async {
    final double userLat = widget.userLocation.latitude;
    final double userLng = widget.userLocation.longitude;
    final double museumLat = double.tryParse(widget.place.lat.toString()) ?? 0.0;
    final double museumLng = double.tryParse(widget.place.lng.toString()) ?? 0.0;

    final String url = 'https://router.project-osrm.org/route/v1/driving/$userLng,$userLat;$museumLng,$museumLat?geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
        
        // Ambil data meta rute untuk dipasang di panel informasi
        final double distanceMeters = data['routes'][0]['distance']?.toDouble() ?? 0.0;
        final double durationSeconds = data['routes'][0]['duration']?.toDouble() ?? 0.0;

        setState(() {
          routePoints = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
          
          // Format jarak meter ke km
          _distance = distanceMeters < 1000 
              ? '${distanceMeters.round()} m' 
              : '${(distanceMeters / 1000).toStringAsFixed(1)} km';
          
          // Format menit
          _duration = '${(durationSeconds / 60).round()} mnt';
          _isLoading = false;
        });

        // Fit kamera otomatis agar kedua marker langsung terlihat proporsional di layar
        _fitRouteBounds(LatLng(userLat, userLng), LatLng(museumLat, museumLng));
      }
    } catch (e) {
      debugPrint("Gagal mengambil rute OSRM: $e");
      setState(() { _isLoading = false; });
    }
  }

  void _fitRouteBounds(LatLng userLoc, LatLng museumLoc) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bounds = LatLngBounds.fromPoints([userLoc, museumLoc]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(70.0),
        ),
      );
    });
  }

  // Desain filter sepia agar peta menyatu dengan nuansa vintage Nusantara
  Widget _vintageTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.85, 0.10, 0.05, 0, 10,
        0.05, 0.80, 0.05, 0, 6,
        0.00, 0.05, 0.70, 0, 0,
        0,    0,    0,    1, 0,
      ]),
      child: tileWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color gold = Color(0xFFC8A96B);
    const Color darkBrown = Color(0xFF3E2723);
    const Color bg = Color(0xFFF8F5F0);

    final double museumLat = double.tryParse(widget.place.lat.toString()) ?? 0.0;
    final double museumLng = double.tryParse(widget.place.lng.toString()) ?? 0.0;
    final LatLng museumLocation = LatLng(museumLat, museumLng);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          widget.place.name ?? "Rute Navigasi",
          style: GoogleFonts.cormorantGaramond(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: darkBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          // ── COMPONENT PETA UTAMA ────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.userLocation,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.museum.nusantara',
                tileBuilder: _vintageTileBuilder,
              ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: darkBrown.withOpacity(0.75),
                      strokeWidth: 4.5,
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Premium Marker Posisi HP User (Dark Brown Dot)
                  Marker(
                    point: widget.userLocation,
                    width: 40,
                    height: 40,
                    child: _buildCustomMarker(
                      icon: Icons.my_location_rounded,
                      baseColor: darkBrown,
                      iconColor: Colors.white,
                    ),
                  ),
                  // Premium Marker Lokasi Museum (Gold Premium Pin)
                  Marker(
                    point: museumLocation,
                    width: 45,
                    height: 55,
                    child: _buildCustomMarker(
                      icon: Icons.museum_rounded,
                      baseColor: gold,
                      iconColor: Colors.white,
                      isMuseum: true,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── FLOATING ROUTE PANEL (Top UX Info Card) ─────────────
          if (!_isLoading)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEDE6DC)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoColumn('JARAK TEMPUH', _distance, gold),
                      Container(width: 1, height: 30, color: const Color(0xFFEDE6DC)),
                      _buildInfoColumn('ESTIMASI WAKTU', _duration, darkBrown),
                    ],
                  ),
                ),
              ),
            ),

          // ── CUSTOM PREMIUM LOADER OVERLAY ───────────────────────
          if (_isLoading)
            Container(
              color: bg.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(gold),
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper Widget: Pembuat struktur item kolom informasi atas
  Widget _buildInfoColumn(String title, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: const Color(0xFF7A6F65),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // Helper Widget: Custom Pin Desain Kreatif Premium
  Widget _buildCustomMarker({
    required IconData icon,
    required Color baseColor,
    required Color iconColor,
    bool isMuseum = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
        if (isMuseum)
          Container(
            width: 2,
            height: 6,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}