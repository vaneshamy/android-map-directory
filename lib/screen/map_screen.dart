import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ══════════════════════════════════════════════════════════════
// MODA PERJALANAN
// ══════════════════════════════════════════════════════════════
enum _TravelMode { walking, cycling, motorcycle, driving }

extension _TravelModeX on _TravelMode {
  String get label {
    switch (this) {
      case _TravelMode.walking:
        return 'Jalan Kaki';
      case _TravelMode.cycling:
        return 'Sepeda';
      case _TravelMode.motorcycle:
        return 'Motor';
      case _TravelMode.driving:
        return 'Mobil';
    }
  }

  IconData get icon {
    switch (this) {
      case _TravelMode.walking:
        return Icons.directions_walk_rounded;
      case _TravelMode.cycling:
        return Icons.directions_bike_rounded;
      case _TravelMode.motorcycle:
        return Icons.two_wheeler_rounded;
      case _TravelMode.driving:
        return Icons.directions_car_filled_rounded;
    }
  }

  // Kecepatan rata-rata (km/jam) dipakai untuk estimasi non-mobil.
  // Mobil pakai durasi asli dari OSRM (mengikuti kondisi jalan sebenarnya).
  double get avgSpeedKmh {
    switch (this) {
      case _TravelMode.walking:
        return 5.0;
      case _TravelMode.cycling:
        return 15.0;
      case _TravelMode.motorcycle:
        return 38.0;
      case _TravelMode.driving:
        return 0; // ditandai khusus, pakai _totalDurationSec asli
    }
  }

  // Parameter mode untuk Google Maps (hanya mendukung d/w/b)
  String get googleWebMode {
    switch (this) {
      case _TravelMode.walking:
        return 'walking';
      case _TravelMode.cycling:
        return 'bicycling';
      case _TravelMode.motorcycle:
      case _TravelMode.driving:
        return 'driving';
    }
  }

  String get googleAppMode {
    switch (this) {
      case _TravelMode.walking:
        return 'w';
      case _TravelMode.cycling:
        return 'b';
      case _TravelMode.motorcycle:
      case _TravelMode.driving:
        return 'd';
    }
  }
}

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

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  List<LatLng> _routePoints   = [];
  List<_Step>  _steps         = [];   // langkah navigasi
  bool _isLoading             = true;
  bool _hasError              = false;
  bool _showDirectionSheet    = false; // panel direction

  // Jarak & durasi mentah hasil OSRM (profil driving)
  double _totalDistanceM  = 0;
  double _totalDurationSec = 0;

  // Moda yang sedang dipilih user
  _TravelMode _selectedMode = _TravelMode.driving;

  // Animasi panel bawah utama
  late AnimationController _panelCtrl;
  late Animation<Offset>   _panelSlide;
  late Animation<double>   _panelFade;

  // Animasi direction sheet
  late AnimationController _dirCtrl;
  late Animation<Offset>   _dirSlide;

  static const Color _gold       = Color(0xFFC8A96B);
  static const Color _darkBrown  = Color(0xFF3E2723);
  static const Color _bg         = Color(0xFFF8F5F0);
  static const Color _inkDark    = Color(0xFF1A1614);
  static const Color _inkMid     = Color(0xFF3D3530);
  static const Color _inkLight   = Color(0xFF7A6F65);
  static const Color _inkFaint   = Color(0xFFB5AAA0);
  static const Color _rule       = Color(0xFFE0D7CA);
  static const Color _goldFaint  = Color(0xFFF4EFE8);

  // ── Getter jarak & durasi (bergantung moda terpilih) ───────────
  String get _distance =>
      _totalDistanceM <= 0 ? '–' : _formatDistance(_totalDistanceM);

  String get _duration => _totalDistanceM <= 0
      ? '–'
      : _formatDuration(_estimatedSecondsForMode(_selectedMode));

  double _estimatedSecondsForMode(_TravelMode mode) {
    if (mode == _TravelMode.driving) return _totalDurationSec;
    final double speedMs = mode.avgSpeedKmh * 1000 / 3600;
    if (speedMs <= 0) return _totalDurationSec;
    return _totalDistanceM / speedMs;
  }

  // Rasio durasi moda terpilih terhadap durasi asli (dipakai untuk
  // menyesuaikan estimasi waktu tiap langkah navigasi)
  double get _modeDurationRatio {
    if (_totalDurationSec <= 0) return 1.0;
    return _estimatedSecondsForMode(_selectedMode) / _totalDurationSec;
  }

  String _formatDistance(double m) => m < 1000
      ? '${m.round()} m'
      : '${(m / 1000).toStringAsFixed(1)} km';

  String _formatDuration(double sec) => sec < 3600
      ? '${(sec / 60).round()} mnt'
      : '${(sec / 3600).toStringAsFixed(1)} jam';

  @override
  void initState() {
    super.initState();

    _panelCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 1), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));
    _panelFade = CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOut);

    _dirCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _dirSlide = Tween<Offset>(
      begin: const Offset(0, 1), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _dirCtrl, curve: Curves.easeOutCubic));

    _fetchRoute();
  }

  @override
  void dispose() {
    _panelCtrl.dispose();
    _dirCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  // FETCH ROUTE + STEPS dari OSRM
  // ══════════════════════════════════════════════════════════════
  Future<void> _fetchRoute() async {
    setState(() {
      _isLoading = true;
      _hasError  = false;
      _steps     = [];
    });

    final double userLat   = widget.userLocation.latitude;
    final double userLng   = widget.userLocation.longitude;
    final double museumLat = double.tryParse(widget.place.lat.toString()) ?? 0.0;
    final double museumLng = double.tryParse(widget.place.lng.toString()) ?? 0.0;

    // steps=true agar OSRM kembalikan langkah navigasi
    final String url =
        'https://router.project-osrm.org/route/v1/driving/'
        '$userLng,$userLat;$museumLng,$museumLat'
        '?geometries=geojson&overview=full&steps=true&annotations=false';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data    = json.decode(response.body);
        final route   = data['routes'][0];
        final coords  = route['geometry']['coordinates'] as List<dynamic>;
        final double distM  = (route['distance'] as num).toDouble();
        final double durSec = (route['duration'] as num).toDouble();

        // Parse langkah-langkah navigasi dari legs → steps
        final List<_Step> steps = [];
        final legs = route['legs'] as List<dynamic>;
        for (final leg in legs) {
          final legSteps = leg['steps'] as List<dynamic>;
          for (final s in legSteps) {
            final maneuver = s['maneuver'] as Map<String, dynamic>;
            final String type      = maneuver['type']?.toString() ?? '';
            final String? modifier = maneuver['modifier']?.toString();
            final String name      = s['name']?.toString() ?? '';
            final double stepDist  = (s['distance'] as num).toDouble();
            final double stepDur   = (s['duration'] as num).toDouble();

            // Skip langkah terakhir "arrive" jika kosong
            if (type == 'arrive' && name.isEmpty) {
              steps.add(_Step(
                instruction: 'Tiba di tujuan',
                streetName: widget.place.name?.toString() ?? 'Museum',
                distanceM: stepDist,
                durationSec: stepDur,
                maneuverType: type,
                modifier: modifier,
                isLast: true,
              ));
              continue;
            }

            if (stepDist < 1 && type != 'depart' && type != 'arrive') continue;

            steps.add(_Step(
              instruction: _buildInstruction(type, modifier, name),
              streetName: name,
              distanceM: stepDist,
              durationSec: stepDur,
              maneuverType: type,
              modifier: modifier,
              isLast: type == 'arrive',
            ));
          }
        }

        if (mounted) {
          setState(() {
            _routePoints = coords
                .map((c) => LatLng(c[1] as double, c[0] as double))
                .toList();
            _totalDistanceM  = distM;
            _totalDurationSec = durSec;
            _steps    = steps;
            _isLoading = false;
          });

          _fitBounds(LatLng(userLat, userLng), LatLng(museumLat, museumLng));
          await Future.delayed(const Duration(milliseconds: 200));
          _panelCtrl.forward();
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('OSRM error: $e');
      if (mounted) {
        setState(() { _isLoading = false; _hasError = true; });
        _panelCtrl.forward();
      }
    }
  }

  // Bangun kalimat instruksi dari tipe maneuver OSRM
  String _buildInstruction(String type, String? modifier, String name) {
    final street = name.isNotEmpty ? ' ke $name' : '';
    switch (type) {
      case 'depart':    return 'Mulai perjalanan$street';
      case 'arrive':    return 'Tiba di tujuan';
      case 'turn':
        switch (modifier) {
          case 'left':          return 'Belok kiri$street';
          case 'right':         return 'Belok kanan$street';
          case 'slight left':   return 'Sedikit ke kiri$street';
          case 'slight right':  return 'Sedikit ke kanan$street';
          case 'sharp left':    return 'Belok tajam ke kiri$street';
          case 'sharp right':   return 'Belok tajam ke kanan$street';
          case 'uturn':         return 'Putar balik$street';
          default:              return 'Belok$street';
        }
      case 'new name':        return 'Lanjutkan$street';
      case 'continue':        return 'Terus lurus$street';
      case 'merge':           return 'Gabung$street';
      case 'on ramp':         return 'Masuk jalur$street';
      case 'off ramp':        return 'Keluar jalur$street';
      case 'fork':
        return modifier == 'left'
            ? 'Di persimpangan, ambil kiri$street'
            : 'Di persimpangan, ambil kanan$street';
      case 'end of road':
        return modifier == 'left'
            ? 'Di ujung jalan, belok kiri$street'
            : 'Di ujung jalan, belok kanan$street';
      case 'roundabout':      return 'Masuk bundaran$street';
      case 'rotary':          return 'Masuk putaran$street';
      case 'roundabout turn': return 'Di bundaran, belok$street';
      case 'notification':    return 'Perhatikan$street';
      default:                return 'Lanjutkan$street';
    }
  }

  void _fitBounds(LatLng a, LatLng b) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([a, b]),
        padding: const EdgeInsets.fromLTRB(48, 120, 48, 300),
      ));
    });
  }

  // ── Ganti moda perjalanan ───────────────────────────────────────
  void _selectMode(_TravelMode mode) {
    if (mode == _selectedMode) return;
    setState(() => _selectedMode = mode);
  }

  // ── Buka Google Maps (mengikuti moda terpilih) ──────────────────
  Future<void> _openGoogleMaps() async {
    final double lat  = double.tryParse(widget.place.lat.toString()) ?? 0.0;
    final double lng  = double.tryParse(widget.place.lng.toString()) ?? 0.0;

    final Uri appUri = Uri.parse(
        'google.navigation:q=$lat,$lng&mode=${_selectedMode.googleAppMode}');
    final Uri webUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$lat,$lng&travelmode=${_selectedMode.googleWebMode}');

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Toggle direction sheet ────────────────────────────────────
  void _toggleDirection() {
    setState(() => _showDirectionSheet = !_showDirectionSheet);
    if (_showDirectionSheet) {
      _dirCtrl.forward();
    } else {
      _dirCtrl.reverse();
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans(fontSize: 13)),
      backgroundColor: isError ? Colors.red[700] : _gold,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final double museumLat =
        double.tryParse(widget.place.lat.toString()) ?? 0.0;
    final double museumLng =
        double.tryParse(widget.place.lng.toString()) ?? 0.0;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── PETA ─────────────────────────────────────────────
          _buildMap(LatLng(museumLat, museumLng)),

          // ── TOP BAR ──────────────────────────────────────────
          _buildTopBar(),

          // ── BOTTOM PANEL utama ────────────────────────────────
          if (!_isLoading)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: SlideTransition(
                position: _panelSlide,
                child: FadeTransition(
                  opacity: _panelFade,
                  child: _buildBottomPanel(),
                ),
              ),
            ),

          // ── DIRECTION SHEET (overlay) ─────────────────────────
          if (_showDirectionSheet)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleDirection,
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
            ),
          if (_showDirectionSheet)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: SlideTransition(
                position: _dirSlide,
                child: _buildDirectionSheet(),
              ),
            ),

          // ── LOADING ───────────────────────────────────────────
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MAP
  // ══════════════════════════════════════════════════════════════
  Widget _buildMap(LatLng museumLatLng) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.userLocation,
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.museum.nusantara',
          tileBuilder: _vintageTile,
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                  points: _routePoints,
                  color: Colors.white.withOpacity(0.6),
                  strokeWidth: 7),
              Polyline(
                  points: _routePoints,
                  color: _darkBrown.withOpacity(0.85),
                  strokeWidth: 4.5),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: widget.userLocation,
              width: 44, height: 44,
              child: _buildDotMarker(
                  bg: _darkBrown, icon: Icons.my_location_rounded),
            ),
            Marker(
              point: museumLatLng,
              width: 48, height: 58,
              child: _buildMuseumPin(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _vintageTile(BuildContext ctx, Widget tile, TileImage img) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.85, 0.10, 0.05, 0, 10,
        0.05, 0.80, 0.05, 0, 6,
        0.00, 0.05, 0.70, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: tile,
    );
  }

  Widget _buildDotMarker(
      {required Color bg, required IconData icon}) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle, color: bg,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Center(child: Icon(icon, size: 17, color: Colors.white)),
    );
  }

  Widget _buildMuseumPin() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: _gold,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [BoxShadow(
              color: _gold.withOpacity(0.4),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Center(
          child: Icon(Icons.museum_rounded, size: 20, color: Colors.white)),
      ),
      Container(
        width: 2.5, height: 10,
        decoration: BoxDecoration(
            color: _gold, borderRadius: BorderRadius.circular(2)),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════
  // TOP BAR
  // ══════════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          children: [
            _FloatButton(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 18, color: _inkDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _rule),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.museum_rounded,
                        size: 14, color: _gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.place.name?.toString() ?? 'Rute Navigasi',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _inkDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _FloatButton(
              onTap: _fetchRoute,
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: _inkDark),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BOTTOM PANEL
  // ══════════════════════════════════════════════════════════════
  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(
            color: Color(0x18000000),
            blurRadius: 20, offset: Offset(0, -4))],
      ),
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 3.5,
              decoration: BoxDecoration(
                  color: _rule,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          const SizedBox(height: 16),

          if (_hasError)
            _buildErrorState()
          else ...[
            // ── Pemilih moda perjalanan ─────────────────────────
            Row(children: [
              const Text('✦',
                  style: TextStyle(color: _gold, fontSize: 8)),
              const SizedBox(width: 7),
              Text(
                'PILIH MODA',
                style: GoogleFonts.dmSans(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  letterSpacing: 2, color: _inkLight,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _buildModeSelector(),

            const SizedBox(height: 16),
            Container(height: 0.5, color: _rule),
            const SizedBox(height: 16),

            // ── Info rute (jarak & estimasi sesuai moda) ────────
            _buildRouteInfo(),

            const SizedBox(height: 16),
            Container(height: 0.5, color: _rule),
            const SizedBox(height: 16),

            // Label
            Row(children: [
              const Text('✦',
                  style: TextStyle(color: _gold, fontSize: 8)),
              const SizedBox(width: 7),
              Text(
                'PILIH NAVIGASI',
                style: GoogleFonts.dmSans(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  letterSpacing: 2, color: _inkLight,
                ),
              ),
            ]),

            const SizedBox(height: 10),

            // ── Dua tombol: Google Maps + Direction ────────────
            Row(
              children: [
                // Google Maps — tracking real-time
                Expanded(
                  flex: 3,
                  child: _NavButton(
                    onTap: _openGoogleMaps,
                    icon: _selectedMode.icon,
                    label: 'Google Maps',
                    sublabel: 'Mode ${_selectedMode.label}',
                    bgColor: _inkDark,
                    iconBgColor: Colors.white.withOpacity(0.15),
                    textColor: Colors.white,
                    subColor: Colors.white.withOpacity(0.6),
                  ),
                ),

                const SizedBox(width: 10),

                // Direction — langkah di app
                Expanded(
                  flex: 2,
                  child: _NavButton(
                    onTap: _steps.isEmpty ? null : _toggleDirection,
                    icon: Icons.turn_right_rounded,
                    label: 'Petunjuk',
                    sublabel: '${_steps.length} langkah',
                    bgColor: _steps.isEmpty ? _goldFaint : _gold,
                    iconBgColor: Colors.white.withOpacity(0.2),
                    textColor: _steps.isEmpty ? _inkFaint : Colors.white,
                    subColor: _steps.isEmpty
                        ? _inkFaint
                        : Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Center(
              child: Text(
                _selectedMode == _TravelMode.driving
                    ? 'Google Maps untuk navigasi langsung · Petunjuk untuk panduan arah'
                    : 'Estimasi ${_selectedMode.label.toLowerCase()} berdasarkan rute jalan · bisa berbeda dari kondisi nyata',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 10, color: _inkFaint),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Pemilih moda (Jalan Kaki / Sepeda / Motor / Mobil) ─────────
  Widget _buildModeSelector() {
    return Row(
      children: _TravelMode.values.map((mode) {
        final bool selected = mode == _selectedMode;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => _selectMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _inkDark : _goldFaint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected ? _inkDark : _rule),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(mode.icon,
                      size: 18,
                      color: selected ? Colors.white : _inkLight),
                  const SizedBox(height: 4),
                  Text(mode.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : _inkMid,
                      )),
                  const SizedBox(height: 1),
                  Text(
                    _totalDistanceM <= 0
                        ? '–'
                        : _formatDuration(_estimatedSecondsForMode(mode)),
                    style: GoogleFonts.dmSans(
                      fontSize: 8.5,
                      color: selected
                          ? Colors.white.withOpacity(0.7)
                          : _inkFaint,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Route info ────────────────────────────────────────────────
  Widget _buildRouteInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: _goldFaint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _rule),
      ),
      child: Row(
        children: [
          Expanded(child: _RouteCell(
              icon: Icons.straighten_rounded,
              label: 'JARAK', value: _distance, color: _inkDark)),
          Container(width: 0.5, height: 36, color: _rule),
          Expanded(child: _RouteCell(
              icon: Icons.access_time_rounded,
              label: 'ESTIMASI', value: _duration, color: _inkDark)),
          Container(width: 0.5, height: 36, color: _rule),
          Expanded(child: _RouteCell(
              icon: Icons.alt_route_rounded,
              label: 'LANGKAH',
              value: _steps.isEmpty ? '–' : '${_steps.length}',
              color: _steps.isEmpty ? _inkLight : const Color(0xFF3B6D11))),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────
  Widget _buildErrorState() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFCEBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0BBBB)),
        ),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded,
              size: 18, color: Color(0xFFE24B4A)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rute tidak dapat dimuat',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: const Color(0xFFA32D2D))),
              Text('Periksa koneksi internet.',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: const Color(0xFFE24B4A))),
            ],
          )),
          GestureDetector(
            onTap: _fetchRoute,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE24B4A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Coba lagi',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      _NavButton(
        onTap: _openGoogleMaps,
        icon: Icons.navigation_rounded,
        label: 'Tetap buka Google Maps',
        sublabel: 'Navigasi langsung',
        bgColor: _inkDark,
        iconBgColor: Colors.white.withOpacity(0.15),
        textColor: Colors.white,
        subColor: Colors.white.withOpacity(0.65),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════
  // DIRECTION SHEET — turn-by-turn di dalam app
  // ══════════════════════════════════════════════════════════════
  Widget _buildDirectionSheet() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFE0D7CA), width: 0.5)),
            ),
            child: Column(
              children: [
                // Handle
                Center(child: Container(
                  width: 36, height: 3.5,
                  decoration: BoxDecoration(
                      color: _rule,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Icon — mengikuti moda terpilih
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _goldFaint,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: _rule),
                      ),
                      child: Icon(_selectedMode.icon,
                          size: 20, color: _gold),
                    ),
                    const SizedBox(width: 12),
                    // Judul + info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Petunjuk Arah',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _inkDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Text('✦',
                                style: TextStyle(
                                    color: _gold, fontSize: 7)),
                            const SizedBox(width: 5),
                            Text(
                              '${_selectedMode.label} · $_distance · $_duration',
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: _inkLight),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    // Tutup
                    GestureDetector(
                      onTap: _toggleDirection,
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4EFE8),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 17, color: _inkMid),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Pemilih moda ringkas di dalam sheet
                _buildModeSelector(),

                const SizedBox(height: 12),

                // Info strip: asal → tujuan
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _goldFaint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _rule),
                  ),
                  child: Row(children: [
                    // Asal
                    const Icon(Icons.my_location_rounded,
                        size: 14, color: _darkBrown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lokasi Anda',
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: _inkMid,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    // Arrow
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          size: 12, color: _gold),
                    ),
                    const SizedBox(width: 8),
                    // Tujuan
                    Expanded(
                      child: Text(
                        widget.place.name?.toString() ?? 'Museum',
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: _inkMid,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.museum_rounded,
                        size: 14, color: _gold),
                  ]),
                ),
              ],
            ),
          ),

          // ── List langkah ───────────────────────────────────
          Flexible(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20,
                  MediaQuery.of(context).padding.bottom + 20),
              physics: const BouncingScrollPhysics(),
              itemCount: _steps.length,
              separatorBuilder: (_, __) => Container(
                height: 0.5, color: _rule,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
              itemBuilder: (_, i) {
                final step = _steps[i];
                final isFirst = i == 0;
                final isLast  = step.isLast;

                return _StepTile(
                  step: step,
                  stepNumber: i + 1,
                  isFirst: isFirst,
                  isLast: isLast,
                  durationScale: _modeDurationRatio,
                  gold: _gold,
                  inkDark: _inkDark,
                  inkLight: _inkLight,
                  inkFaint: _inkFaint,
                  goldFaint: _goldFaint,
                  rule: _rule,
                );
              },
            ),
          ),

          // ── Footer: buka GMaps ─────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20,
                MediaQuery.of(context).padding.bottom + 12),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: Color(0xFFE0D7CA), width: 0.5)),
            ),
            child: _NavButton(
              onTap: _openGoogleMaps,
              icon: _selectedMode.icon,
              label: 'Mulai Navigasi Real-Time',
              sublabel: 'Beralih ke Google Maps · ${_selectedMode.label}',
              bgColor: _inkDark,
              iconBgColor: Colors.white.withOpacity(0.15),
              textColor: Colors.white,
              subColor: Colors.white.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading overlay ───────────────────────────────────────────
  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: _bg.withOpacity(0.5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(
                  color: _gold, strokeWidth: 2.5),
              const SizedBox(height: 12),
              Text('Memuat rute...',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: _inkLight)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MODEL: Step navigasi
// ══════════════════════════════════════════════════════════════
class _Step {
  final String instruction;
  final String streetName;
  final double distanceM;
  final double durationSec;
  final String maneuverType;
  final String? modifier;
  final bool isLast;

  const _Step({
    required this.instruction,
    required this.streetName,
    required this.distanceM,
    required this.durationSec,
    required this.maneuverType,
    this.modifier,
    this.isLast = false,
  });

  String get distanceText {
    if (distanceM < 50) return '';
    if (distanceM < 1000) return '${distanceM.round()} m';
    return '${(distanceM / 1000).toStringAsFixed(1)} km';
  }

  // scale: rasio kecepatan moda terpilih terhadap durasi asli (mobil)
  String durationText([double scale = 1.0]) {
    final double sec = durationSec * scale;
    if (sec < 60) return '< 1 mnt';
    return '${(sec / 60).round()} mnt';
  }
}

// ══════════════════════════════════════════════════════════════
// STEP TILE — satu baris langkah navigasi
// ══════════════════════════════════════════════════════════════
class _StepTile extends StatelessWidget {
  final _Step step;
  final int stepNumber;
  final bool isFirst;
  final bool isLast;
  final double durationScale;
  final Color gold, inkDark, inkLight, inkFaint, goldFaint, rule;

  const _StepTile({
    required this.step,
    required this.stepNumber,
    required this.isFirst,
    required this.isLast,
    required this.durationScale,
    required this.gold,
    required this.inkDark,
    required this.inkLight,
    required this.inkFaint,
    required this.goldFaint,
    required this.rule,
  });

  // Pilih ikon berdasarkan maneuver
  IconData get _icon {
    if (isFirst)              return Icons.my_location_rounded;
    if (isLast)               return Icons.museum_rounded;
    switch (step.maneuverType) {
      case 'turn':
        switch (step.modifier) {
          case 'left':         return Icons.turn_left_rounded;
          case 'right':        return Icons.turn_right_rounded;
          case 'slight left':  return Icons.turn_slight_left_rounded;
          case 'slight right': return Icons.turn_slight_right_rounded;
          case 'sharp left':   return Icons.turn_sharp_left_rounded;
          case 'sharp right':  return Icons.turn_sharp_right_rounded;
          case 'uturn':        return Icons.u_turn_left_rounded;
          default:             return Icons.turn_right_rounded;
        }
      case 'roundabout':
      case 'rotary':          return Icons.roundabout_left_rounded;
      case 'fork':
        return step.modifier == 'left'
            ? Icons.fork_left_rounded
            : Icons.fork_right_rounded;
      case 'merge':           return Icons.merge_rounded;
      case 'on ramp':         return Icons.ramp_right_rounded;
      case 'off ramp':        return Icons.ramp_left_rounded;
      case 'depart':          return Icons.play_arrow_rounded;
      case 'arrive':          return Icons.location_on_rounded;
      default:                return Icons.straight_rounded;
    }
  }

  Color get _iconBg {
    if (isFirst) return const Color(0xFF1A1614);
    if (isLast)  return gold;
    switch (step.maneuverType) {
      case 'turn':             return const Color(0xFF2A6B9B);
      case 'roundabout':
      case 'rotary':           return const Color(0xFF3A7D44);
      case 'fork':
      case 'merge':            return const Color(0xFF9B4E8C);
      default:                 return const Color(0xFF4A5568);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Icon arah ──────────────────────────────────────
          Column(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(
                      color: _iconBg.withOpacity(0.3),
                      blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Center(
                  child: Icon(_icon, size: 18, color: Colors.white),
                ),
              ),
              // Garis vertikal penghubung
              if (!isLast)
                Container(
                  width: 1.5, height: 20,
                  margin: const EdgeInsets.only(top: 4),
                  color: rule,
                ),
            ],
          ),

          const SizedBox(width: 14),

          // ── Instruksi ──────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: inkDark,
                    height: 1.3,
                  ),
                ),

                if (step.streetName.isNotEmpty &&
                    !step.instruction.contains(step.streetName)) ...[
                  const SizedBox(height: 2),
                  Text(
                    step.streetName,
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: inkLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 6),

                // Distance + durasi chip (durasi menyesuaikan moda terpilih)
                if (step.distanceText.isNotEmpty || !isLast)
                  Wrap(spacing: 6, children: [
                    if (step.distanceText.isNotEmpty)
                      _Chip(
                        icon: Icons.straighten_rounded,
                        label: step.distanceText,
                        bg: goldFaint,
                        color: gold,
                      ),
                    if (!isLast && step.durationSec > 0)
                      _Chip(
                        icon: Icons.access_time_rounded,
                        label: step.durationText(durationScale),
                        bg: const Color(0xFFECECEC),
                        color: inkLight,
                      ),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip kecil info jarak/waktu ───────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color color;

  const _Chip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NAV BUTTON
// ══════════════════════════════════════════════════════════════
class _NavButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final String sublabel;
  final Color bgColor;
  final Color iconBgColor;
  final Color textColor;
  final Color subColor;

  const _NavButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.bgColor,
    required this.iconBgColor,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: textColor),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(sublabel,
                  style: GoogleFonts.dmSans(
                      fontSize: 10, color: subColor)),
            ],
          )),
          Icon(Icons.arrow_forward_rounded,
              size: 14, color: textColor.withOpacity(0.7)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ROUTE CELL
// ══════════════════════════════════════════════════════════════
class _RouteCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _RouteCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(children: [
        Icon(icon, size: 15, color: const Color(0xFFC8A96B)),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.dmSans(
              fontSize: 9, fontWeight: FontWeight.w600,
              letterSpacing: 1, color: const Color(0xFFB5AAA0),
            )),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w700, color: color,
            )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FLOAT BUTTON
// ══════════════════════════════════════════════════════════════
class _FloatButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _FloatButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0D7CA)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Center(child: child),
      ),
    );
  }
}