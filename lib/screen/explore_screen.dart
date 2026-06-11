import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;

import '../services/supabase_service.dart';
import '../models/place_model.dart';
import 'detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final SupabaseService _svc = SupabaseService();

  List<PlaceModel> _allPlaces = [];
  Position? _userPos;
  PlaceModel? _selectedPlace;
  bool _loading = true;
  bool _gpsActive = false;

  // Animasi bottom sheet slide up
  late AnimationController _sheetAnim;
  late Animation<Offset> _sheetSlide;

  // Jawa Timur center default
  static const LatLng _defaultCenter = LatLng(-7.5360, 112.2384);

  @override
  void initState() {
    super.initState();

    _sheetAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sheetAnim, curve: Curves.easeOutCubic));

    _loadData();
  }

  @override
  void dispose() {
    _sheetAnim.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Ambil places dari Supabase
    final places = await _svc.fetchPlaces();

    // Coba ambil lokasi
    final pos = await _getLocation();

    if (mounted) {
      setState(() {
        _allPlaces = places;
        _userPos = pos;
        _gpsActive = pos != null;
        _loading = false;
      });

      // Slide up bottom sheet setelah data masuk
      await Future.delayed(const Duration(milliseconds: 200));
      _sheetAnim.forward();
    }
  }

  Future<Position?> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return null;
    }
  }

  // Museum terdekat — max 8, sort by distance
  List<PlaceModel> get _nearbyPlaces {
    if (_userPos == null) return _allPlaces.take(8).toList();

    final sorted = List<PlaceModel>.from(_allPlaces);
    sorted.sort((a, b) {
      final da = Geolocator.distanceBetween(
          _userPos!.latitude, _userPos!.longitude, a.lat, a.lng);
      final db = Geolocator.distanceBetween(
          _userPos!.latitude, _userPos!.longitude, b.lat, b.lng);
      return da.compareTo(db);
    });
    return sorted.take(8).toList();
  }

  String _distanceLabel(PlaceModel p) {
    if (_userPos == null) return '';
    final m = Geolocator.distanceBetween(
        _userPos!.latitude, _userPos!.longitude, p.lat, p.lng);
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  void _onMarkerTap(PlaceModel p) {
    setState(() => _selectedPlace = p);
    _mapController.move(LatLng(p.lat, p.lng), 13.5);
  }

  void _locateMe() {
    if (_userPos != null) {
      _mapController.move(
        LatLng(_userPos!.latitude, _userPos!.longitude),
        12.0,
      );
    }
  }

  LatLng get _mapCenter => _userPos != null
      ? LatLng(_userPos!.latitude, _userPos!.longitude)
      : _defaultCenter;

  double get _mapZoom => _userPos != null ? 10.5 : 7.8;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: Stack(
        children: [
          // ── PETA PENUH ────────────────────────────────────────
          _buildMap(),

          // ── TOP OVERLAY ───────────────────────────────────────
          _buildTopOverlay(),

          // ── LOADING ───────────────────────────────────────────
          if (_loading) _buildLoadingOverlay(),

          // ── BOTTOM SHEET: Selected place card ─────────────────
          if (_selectedPlace != null) _buildSelectedCard(),

          // ── BOTTOM SHEET: Nearby list (selalu tampil) ─────────
          if (!_loading && _selectedPlace == null) _buildNearbySheet(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MAP
  // ══════════════════════════════════════════════════════════════
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: _mapZoom,
        onTap: (_, __) {
          if (_selectedPlace != null) {
            setState(() => _selectedPlace = null);
          }
        },
      ),
      children: [
        // Tile layer — OSM default (sepia-ish via CSS tidak bisa di flutter_map,
        // tapi bisa pakai tile provider lain yg terlihat classic)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.museumnusantara.app',
          // Tile filter untuk tampilan cream/vintage
          tileBuilder: _sepiaTileBuilder,
        ),

        // Route polyline: user → selected place
        if (_selectedPlace != null && _userPos != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  LatLng(_userPos!.latitude, _userPos!.longitude),
                  LatLng(_selectedPlace!.lat, _selectedPlace!.lng),
                ],
                color: const Color(0xFF1A1614).withOpacity(0.6),
                strokeWidth: 2,
                isDotted: true,
              ),
            ],
          ),

        // Museum markers
        MarkerLayer(
          markers: [
            // User dot
            if (_userPos != null)
              Marker(
                point: LatLng(_userPos!.latitude, _userPos!.longitude),
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1614),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),

            // Museum markers
            ..._allPlaces.map((p) {
              final isSelected = _selectedPlace?.id == p.id;
              return Marker(
                point: LatLng(p.lat, p.lng),
                width: isSelected ? 52 : 40,
                height: isSelected ? 60 : 48,
                child: GestureDetector(
                  onTap: () => _onMarkerTap(p),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: isSelected ? 44 : 34,
                        height: isSelected ? 44 : 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFFC8A96B)
                              : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFC8A96B)
                                : const Color(0xFF3D3530),
                            width: isSelected ? 0 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isSelected
                                      ? const Color(0xFFC8A96B)
                                      : Colors.black)
                                  .withOpacity(0.25),
                              blurRadius: isSelected ? 12 : 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _MuseumMarkerIcon(
                            size: isSelected ? 22 : 17,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF3D3530),
                          ),
                        ),
                      ),
                      // Pin stem
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 2,
                        height: isSelected ? 10 : 8,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFC8A96B)
                              : const Color(0xFF3D3530),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  // Tile builder untuk efek vintage/cream pada peta
  Widget _sepiaTileBuilder(
      BuildContext context, Widget tileWidget, TileImage tile) {
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

  // ══════════════════════════════════════════════════════════════
  // TOP OVERLAY
  // ══════════════════════════════════════════════════════════════
  Widget _buildTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          children: [
            // Back button
            _MapButton(
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: Color(0xFF1A1614),
              ),
            ),

            const SizedBox(width: 10),

            // GPS status pill
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _gpsActive
                  ? _GpsPill(active: true)
                  : _GpsPill(active: false),
            ),

            const Spacer(),

            // Locate me
            _MapButton(
              onTap: _locateMe,
              child: Icon(
                Icons.my_location_rounded,
                size: 18,
                color: _gpsActive
                    ? const Color(0xFFC8A96B)
                    : const Color(0xFF7A6F65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // NEARBY BOTTOM SHEET
  // ══════════════════════════════════════════════════════════════
  Widget _buildNearbySheet() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SlideTransition(
        position: _sheetSlide,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F5F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 14,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 38,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8CFC4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Section title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      '✦',
                      style: TextStyle(
                        color: Color(0xFFC8A96B),
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _gpsActive ? 'MUSEUM TERDEKAT' : 'SEMUA MUSEUM',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: const Color(0xFF7A6F65),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_nearbyPlaces.length} tempat',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: const Color(0xFFB5AAA0),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Horizontal scroll cards
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _nearbyPlaces.length,
                  itemBuilder: (_, i) {
                    final p = _nearbyPlaces[i];
                    final dist = _distanceLabel(p);
                    return _NearbyCard(
                      place: p,
                      distance: dist,
                      isSelected: _selectedPlace?.id == p.id,
                      onTap: () => _onMarkerTap(p),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SELECTED PLACE CARD (muncul saat marker diklik)
  // ══════════════════════════════════════════════════════════════
  Widget _buildSelectedCard() {
    final p = _selectedPlace!;
    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 24,
      child: GestureDetector(
  onTap: () {
    // 1. Ambil latitude & longitude secara dinamis dari posisi user/default
    final double lat = _userPos != null ? _userPos!.latitude : _defaultCenter.latitude;
    final double lng = _userPos != null ? _userPos!.longitude : _defaultCenter.longitude;

    // 2. Bungkus ke dalam kelas LatLng milik google_maps_flutter secara eksplisit
    final googleMapsLatLng = maps.LatLng(lat, lng);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          place: p,
          userLocation: googleMapsLatLng, // Sekarang tipenya sudah cocok!
        ),
      ),
    );
  },
  child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDE6DC)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: p.photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: p.photoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _thumbPlaceholder(),
                        )
                      : _thumbPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1614),
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 11,
                          color: Color(0xFFC8A96B),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            p.city ?? p.address,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: const Color(0xFF7A6F65),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (p.rating != null) ...[
                          const Icon(Icons.star_rounded,
                              size: 12, color: Color(0xFFC8A96B)),
                          const SizedBox(width: 3),
                          Text(
                            p.ratingText,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1614),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (_distanceLabel(p).isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4EFE8),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _distanceLabel(p),
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFC8A96B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Action buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close
                  GestureDetector(
                    onTap: () => setState(() => _selectedPlace = null),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFFB5AAA0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Arrow
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1614),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Loading overlay ────────────────────────────────────────────
  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFFF8F5F0).withOpacity(0.8),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFC8A96B),
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: const Color(0xFFF4EFE8),
      child: Center(
        child: Image.asset(
          'assets/images/logo_musra.png',
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          opacity: const AlwaysStoppedAnimation(0.25),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NEARBY CARD (horizontal scroll)
// ══════════════════════════════════════════════════════════════
class _NearbyCard extends StatelessWidget {
  final PlaceModel place;
  final String distance;
  final bool isSelected;
  final VoidCallback onTap;

  const _NearbyCard({
    required this.place,
    required this.distance,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 96,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFC8A96B)
                : const Color(0xFFEDE6DC),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: SizedBox(
                width: double.infinity,
                height: 68,
                child: place.photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: place.photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _cardPlaceholder(),
                      )
                    : _cardPlaceholder(),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1614),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (distance.isNotEmpty)
                    Text(
                      distance,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: const Color(0xFFC8A96B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardPlaceholder() {
    return Container(
      color: const Color(0xFFF4EFE8),
      child: Center(
        child: _MuseumMarkerIcon(size: 22, color: const Color(0xFFD8CFC4)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MUSEUM MARKER ICON (SVG-style museum icon)
// ══════════════════════════════════════════════════════════════
class _MuseumMarkerIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _MuseumMarkerIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.museum_rounded,
      size: size,
      color: color,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MAP BUTTON (floating button di peta)
// ══════════════════════════════════════════════════════════════
class _MapButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _MapButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0D7CA)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// GPS STATUS PILL
// ══════════════════════════════════════════════════════════════
class _GpsPill extends StatelessWidget {
  final bool active;

  const _GpsPill({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(active),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFE0D7CA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot indicator
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFB5AAA0),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'GPS Aktif' : 'GPS Mati',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3D3530),
            ),
          ),
        ],
      ),
    );
  }
}