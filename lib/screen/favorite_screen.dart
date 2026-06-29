import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../models/favorite_model.dart';
import '../models/place_model.dart';
import '../services/favorite_service.dart';
import 'detail_screen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({Key? key}) : super(key: key);

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen>
    with TickerProviderStateMixin {
  final FavoriteService _favService = FavoriteService();

  List<FavoriteModel> _favorites = [];
  bool _isLoading = true;
  Position? _userPos;

  late AnimationController _enterCtrl;
  late Animation<double> _fadeAnim;

  static const Color _gold = Color(0xFFC8A96B);
  static const Color _darkBrown = Color(0xFF3E2723);
  static const Color _bg = Color(0xFFF8F5F0);
  static const Color _inkDark = Color(0xFF1A1614);
  static const Color _inkLight = Color(0xFF7A6F65);
  static const Color _inkFaint = Color(0xFFB5AAA0);
  static const Color _rule = Color(0xFFE0D7CA);
  static const Color _cardBorder = Color(0xFFEDE6DC);
  static const Color _goldFaint = Color(0xFFF4EFE8);

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();

    _fadeAnim =
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);

    _loadData();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

Future<void> _loadData() async {
  setState(() => _isLoading = true);

  // ambil favorit dari service
  final favs = await _favService.getMyFavorites();

  debugPrint("Jumlah favorit: ${favs.length}");
  debugPrint(favs.toString());

  final pos = await _getLocation();

  if (mounted) {
    setState(() {
      _favorites = favs;
      _userPos = pos;
      _isLoading = false;
    });
  }
}

  Future<Position?> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
    } catch (_) {
      return null;
    }
  }

  String _distanceLabel(FavoriteModel fav) {
    if (_userPos == null || fav.placeLat == null || fav.placeLng == null) {
      return '';
    }
    final m = Geolocator.distanceBetween(
      _userPos!.latitude,
      _userPos!.longitude,
      fav.placeLat!,
      fav.placeLng!,
    );
    if (m < 1000) return '${m.round()} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _removeFavorite(FavoriteModel fav) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmRemoveDialog(name: fav.placeName ?? 'Museum ini'),
    );
    if (confirm != true) return;

    setState(() {
      _favorites.removeWhere((f) => f.id == fav.id);
    });

    await _favService.removeFavorite(fav.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${fav.placeName ?? "Museum"} dihapus dari favorit',
            style: GoogleFonts.dmSans(fontSize: 13),
          ),
          backgroundColor: _inkDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Tutup',
            textColor: _gold,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _openDetail(FavoriteModel fav) {
    // Buat PlaceModel dari data favorit
    final place = PlaceModel(
      id: fav.placeId,
      name: fav.placeName ?? '',
      address: fav.placeAddress ?? '',
      lat: fav.placeLat ?? 0,
      lng: fav.placeLng ?? 0,
      photoUrl: fav.placePhotoUrl,
      rating: fav.placeRating,
      description: fav.placeDescription,
      openHours: fav.placeOpenHours,
      city: fav.placeCity,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          place: place,
          userLocation: _userPos != null
              ? LatLng(_userPos!.latitude, _userPos!.longitude)
              : const LatLng(-7.5360, 112.2384),
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? _buildLoading()
                    : _favorites.isEmpty
                        ? _buildEmpty()
                        : _buildList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _rule),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: _inkDark,
                  ),
                ),
              ),
              const Spacer(),
              // Jumlah favorit badge
              if (_favorites.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _goldFaint,
                    borderRadius: BorderRadius.circular(100),
                    border:
                        Border.all(color: _gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_rounded,
                          size: 11, color: _gold),
                      const SizedBox(width: 5),
                      Text(
                        '${_favorites.length} museum',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _gold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Editorial title — center
          Center(
            child: Column(
              children: [
                _OrnamentalDivider(),
                const SizedBox(height: 8),
                Text(
                  'Museum',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: Colors.black87,
                    height: 1.0,
                  ),
                ),
                Text(
                  'Favorit Saya',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: _gold,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                _OrnamentalDivider(),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Container(height: 0.5, color: _rule),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LIST
  // ══════════════════════════════════════════════════════════════
  Widget _buildList() {
    return RefreshIndicator(
      color: _gold,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        itemCount: _favorites.length,
        itemBuilder: (_, i) {
          final fav = _favorites[i];
          final start = (i * 0.08).clamp(0.0, 0.7);
          final end = (start + 0.4).clamp(0.0, 1.0);

          final itemFade = Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
                parent: _enterCtrl,
                curve: Interval(start, end, curve: Curves.easeOut)),
          );
          final itemSlide = Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(
              parent: _enterCtrl,
              curve: Interval(start, end, curve: Curves.easeOut)));

          return FadeTransition(
            opacity: itemFade,
            child: SlideTransition(
              position: itemSlide,
              child: _FavoriteCard(
                fav: fav,
                index: i,
                distance: _distanceLabel(fav),
                onTap: () => _openDetail(fav),
                onRemove: () => _removeFavorite(fav),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════════════════════
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _goldFaint,
                shape: BoxShape.circle,
                border: Border.all(color: _gold.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 36,
                color: _gold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Favorit',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _inkDark,
              ),
            ),
            const SizedBox(height: 6),
            _OrnamentalDivider(),
            const SizedBox(height: 12),
            Text(
              'Temukan museum menarik dan simpan ke daftar favorit Anda.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _inkLight,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _inkDark,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Jelajahi Museum',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LOADING
  // ══════════════════════════════════════════════════════════════
  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: 4,
      itemBuilder: (_, __) => _SkeletonCard(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FAVORITE CARD
// ══════════════════════════════════════════════════════════════
class _FavoriteCard extends StatelessWidget {
  final FavoriteModel fav;
  final int index;
  final String distance;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  static const Color _gold = Color(0xFFC8A96B);
  static const Color _inkDark = Color(0xFF1A1614);
  static const Color _inkLight = Color(0xFF7A6F65);
  static const Color _inkFaint = Color(0xFFB5AAA0);
  static const Color _rule = Color(0xFFE0D7CA);
  static const Color _cardBorder = Color(0xFFEDE6DC);
  static const Color _goldFaint = Color(0xFFF4EFE8);

  const _FavoriteCard({
    required this.fav,
    required this.index,
    required this.distance,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── IMAGE ─────────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: fav.placePhotoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: fav.placePhotoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: _goldFaint,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFC8A96B),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                  ),
                  // Gradient overlay bawah
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.5, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.25),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Hapus button — pojok kanan atas
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.red.shade100),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 16,
                          color: Color(0xFFE24B4A),
                        ),
                      ),
                    ),
                  ),
                  // Nomor urut — pojok kiri atas
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${(index + 1).toString().padLeft(2, '0')}',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 11,
                          color: _gold,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── INFO ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama
                  Text(
                    fav.placeName ?? 'Nama tidak tersedia',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _inkDark,
                      height: 1.1,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Lokasi
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 13, color: _gold),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          fav.placeCity != null
                              ? '${fav.placeCity} · ${fav.placeAddress ?? ''}'
                              : fav.placeAddress ?? '',
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: _inkLight,
                              height: 1.4),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Container(height: 0.5, color: _rule),
                  const SizedBox(height: 12),

                  // Footer row
                  Row(
                    children: [
                      // Rating
                      if (fav.placeRating != null) ...[
                        const Icon(Icons.star_rounded,
                            size: 14, color: _gold),
                        const SizedBox(width: 4),
                        Text(
                          fav.ratingText,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _inkDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Jam buka
                      if (fav.placeOpenHours != null) ...[
                        const Icon(Icons.access_time_rounded,
                            size: 12, color: _inkFaint),
                        const SizedBox(width: 4),
                        Text(
                          fav.placeOpenHours!,
                          style: GoogleFonts.dmSans(
                              fontSize: 11, color: _inkFaint),
                        ),
                        const SizedBox(width: 12),
                      ],

                      const Spacer(),

                      // Distance chip
                      if (distance.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _goldFaint,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            distance,
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _gold,
                            ),
                          ),
                        ),

                      const SizedBox(width: 8),

                      // Lihat detail button
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _inkDark,
                          borderRadius:
                              BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Lihat Detail',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF4EFE8),
      child: Center(
        child: Icon(
          Icons.museum_rounded,
          size: 48,
          color: const Color(0xFFC8A96B).withOpacity(0.3),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// KONFIRMASI HAPUS DIALOG
// ══════════════════════════════════════════════════════════════
class _ConfirmRemoveDialog extends StatelessWidget {
  final String name;
  const _ConfirmRemoveDialog({required this.name});

  static const Color _gold = Color(0xFFC8A96B);
  static const Color _inkDark = Color(0xFF1A1614);
  static const Color _inkLight = Color(0xFF7A6F65);
  static const Color _goldFaint = Color(0xFFF4EFE8);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D7CA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFCEBEB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFE24B4A),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Hapus dari Favorit?',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _inkDark,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              '"$name" akan dihapus dari daftar favorit Anda.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _inkLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _goldFaint,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                        child: Text(
                          'Batal',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3D3530),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE24B4A),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                        child: Text(
                          'Hapus',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SKELETON CARD
// ══════════════════════════════════════════════════════════════
class _SkeletonCard extends StatefulWidget {
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.4 + (_anim.value * 0.4);
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDE6DC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(244, 239, 232,
                      opacity.clamp(0.0, 1.0)),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 22,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(244, 239, 232,
                            opacity.clamp(0.0, 1.0)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 14,
                      width: 280,
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(244, 239, 232,
                            opacity.clamp(0.0, 1.0)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 14,
                      width: 160,
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(244, 239, 232,
                            opacity.clamp(0.0, 1.0)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════
class _OrnamentalDivider extends StatelessWidget {
  const _OrnamentalDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 30, height: 0.5, color: const Color(0xFFC8A96B)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 7),
          child: Text('✦',
              style: TextStyle(
                  color: Color(0xFFC8A96B), fontSize: 8)),
        ),
        Container(
            width: 30, height: 0.5, color: const Color(0xFFC8A96B)),
      ],
    );
  }
}