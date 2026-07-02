import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/favorite_service.dart';
import '../services/activity_service.dart'; // Tambahan Import untuk mencatat aktivitas
import 'map_screen.dart';
import 'review_section.dart';
import 'login_screen.dart';

class DetailScreen extends StatefulWidget {
  final dynamic place;
  final LatLng userLocation;
  final bool scrollToReview;

  const DetailScreen({
    super.key,
    required this.place,
    required this.userLocation,
    this.scrollToReview = false,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _reviewKey = GlobalKey();
  final FavoriteService _favService = FavoriteService();

  static const Color gold     = Color(0xFFC8A96B);
  static const Color darkBrown = Color(0xFF3E2723);
  static const Color bg       = Color(0xFFF8F5F0);

  // ── Data museum ───────────────────────────────────────────────
  String museumName        = 'Tanpa Nama';
  String museumAddress     = 'Alamat tidak tersedia';
  String museumOpenHours   = '08:00 – 16:00';
  String museumDescription = 'Belum ada deskripsi mendalam mengenai museum ini.';
  String photoUrl          = 'https://images.unsplash.com/photo-1541123437800-1bb1317badc2?q=80&w=600';
  String placeId           = '';
  double? museumRating;
  String? museumCity;

  // ── Favorit state ─────────────────────────────────────────────
  bool _isFavorited  = false;
  bool _favLoading   = false;

  @override
  void initState() {
    super.initState();

    // Ekstraksi data dari PlaceModel / objek place
    try {
      if (widget.place != null) {
        if (widget.place.name        != null) museumName        = widget.place.name.toString();
        if (widget.place.address     != null) museumAddress     = widget.place.address.toString();
        if (widget.place.openHours   != null) museumOpenHours   = widget.place.openHours.toString();
        if (widget.place.description != null) museumDescription = widget.place.description.toString();
        if (widget.place.photoUrl    != null) photoUrl          = widget.place.photoUrl.toString();
        if (widget.place.id          != null) placeId           = widget.place.id.toString();
        try { museumRating = (widget.place.rating as num?)?.toDouble(); } catch (_) {}
        try { museumCity = widget.place.city?.toString(); } catch (_) {}
      }
    } catch (e) {
      debugPrint('Gagal ekstraksi data model di DetailScreen: $e');
    }

    // Cek status favorit
    if (placeId.isNotEmpty) {
      _favService.isFavorited(placeId).then((val) {
        if (mounted) setState(() => _isFavorited = val);
      });
    }

    // Auto-scroll ke review jika diminta
    if (widget.scrollToReview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToReviewSection();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll ke section review ──────────────────────────────────
  void _scrollToReviewSection() {
    final ctx = _reviewKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  // ── Toggle favorit ────────────────────────────────────────────
  Future<void> _toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (result != true || !mounted) return;
      // setelah login, lanjut toggle favorit
    }
    if (placeId.isEmpty) return;

    setState(() => _favLoading = true);

    final result = await _favService.toggleFavorite(placeId);

    if (mounted) {
      setState(() {
        _isFavorited = result;
        _favLoading  = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result ? '❤️  Ditambahkan ke favorit' : 'Dihapus dari favorit',
            style: GoogleFonts.dmSans(fontSize: 13),
          ),
          backgroundColor: result
              ? const Color(0xFFC8A96B)
              : const Color(0xFF1A1614),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Buka peta rute ────────────────────────────────────────────
  void _openMapRoute() async {
    if (widget.place == null) return;
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user == null) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (result != true) return; // login dibatalkan
      // setelah login, langsung buka peta
    }

    // TAMBAHAN BARU: Catat aktivitas navigasi sebelum pindah halaman
    if (placeId.isNotEmpty) {
      ActivityService().recordNavigation(placeId);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          place: widget.place,
          userLocation: widget.userLocation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          _buildBody(),
        ],
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SLIVER APP BAR — foto hero + tombol favorit
  // ══════════════════════════════════════════════════════════════
  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: darkBrown,
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,

      // Back button kustom
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),

      // Tombol favorit di kanan
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _favLoading ? null : _toggleFavorite,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              child: _favLoading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        _isFavorited
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(_isFavorited),
                        size: 20,
                        color: _isFavorited
                            ? const Color(0xFFFF6B6B)
                            : Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],

      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Foto museum
            Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: gold.withOpacity(0.15),
                child: const Center(
                  child: Icon(Icons.museum_rounded, size: 72, color: gold),
                ),
              ),
            ),

            // Gradient gelap bawah
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.4, 1.0],
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),

            // Info nama + kota di atas foto
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (museumCity != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        museumCity!.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    museumName,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.1,
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

  // ══════════════════════════════════════════════════════════════
  // BODY CONTENT
  // ══════════════════════════════════════════════════════════════
  SliverToBoxAdapter _buildBody() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Info cards row ─────────────────────────────────
          _buildInfoCards(),

          // ── Divider ────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Color(0xFFE0D7CA), height: 1),
          ),

          // ── Tentang museum ─────────────────────────────────
          _buildAboutSection(),

          // ── Divider ────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Color(0xFFE0D7CA), height: 1),
          ),

          // ── Review section ─────────────────────────────────
          _buildReviewSection(),

          // Bottom padding untuk bottomSheet
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  // ── Info cards (alamat, jam, rating) ─────────────────────────
  Widget _buildInfoCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: [
          // Alamat
          _InfoRow(
            icon: Icons.location_on_rounded,
            iconColor: gold,
            child: Text(
              museumAddress,
              style: GoogleFonts.dmSans(
                  fontSize: 14, color: Colors.grey[700], height: 1.4),
            ),
          ),
          const SizedBox(height: 10),

          // Jam buka
          _InfoRow(
            icon: Icons.access_time_rounded,
            iconColor: gold,
            child: Text(
              'Jam Buka: $museumOpenHours',
              style: GoogleFonts.dmSans(
                  fontSize: 14, color: Colors.grey[700]),
            ),
          ),

          // Rating (jika ada)
          if (museumRating != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.star_rounded,
              iconColor: gold,
              child: Row(
                children: [
                  Text(
                    museumRating!.toStringAsFixed(1),
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: darkBrown,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < museumRating!.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 14,
                        color: gold,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tentang museum ────────────────────────────────────────────
  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              const Text('✦',
                  style: TextStyle(color: gold, fontSize: 9)),
              const SizedBox(width: 7),
              Text(
                'TENTANG MUSEUM',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: const Color(0xFF7A6F65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            museumName,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: darkBrown,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            museumDescription,
            textAlign: TextAlign.justify,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: darkBrown.withOpacity(0.75),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  // ── Review section ────────────────────────────────────────────
  Widget _buildReviewSection() {
    return Container(
      key: _reviewKey,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('✦',
                  style: TextStyle(color: gold, fontSize: 9)),
              const SizedBox(width: 7),
              Text(
                'ULASAN PENGUNJUNG',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: const Color(0xFF7A6F65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Review widget
          if (placeId.isNotEmpty)
            ReviewSection(placeId: placeId)
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'ID museum tidak tersedia.',
                style: GoogleFonts.dmSans(
                    color: Colors.grey[400], fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BOTTOM BAR — Tombol rute
  // ══════════════════════════════════════════════════════════════
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE0D7CA), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Favorit button (secondary)
          GestureDetector(
            onTap: _favLoading ? null : _toggleFavorite,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _isFavorited
                    ? const Color(0xFFFCEBEB)
                    : const Color(0xFFF4EFE8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isFavorited
                      ? const Color(0xFFF0BBBB)
                      : const Color(0xFFE0D7CA),
                ),
              ),
              child: _favLoading
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE24B4A),
                      ),
                    )
                  : Icon(
                      _isFavorited
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 22,
                      color: _isFavorited
                          ? const Color(0xFFE24B4A)
                          : const Color(0xFF7A6F65),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // Rute button (primary)
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _openMapRoute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: Text(
                  'BUKA RUTE NAVIGASI',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// INFO ROW — helper widget baris icon + konten
// ══════════════════════════════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}