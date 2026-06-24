import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'map_screen.dart';
import 'review_section.dart';

class DetailScreen extends StatefulWidget {
  final dynamic place;
  final LatLng userLocation;
  final bool scrollToReview; // ← jika true, otomatis scroll ke section ulasan

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
  // ScrollController untuk mengontrol posisi scroll
  final ScrollController _scrollController = ScrollController();

  // GlobalKey untuk menemukan posisi widget ReviewSection
  final GlobalKey _reviewKey = GlobalKey();

  static const Color gold = Color(0xFFC8A96B);
  static const Color darkBrown = Color(0xFF3E2723);
  static const Color bg = Color(0xFFF8F5F0);

  String museumName = 'Tanpa Nama';
  String museumAddress = 'Alamat tidak tersedia';
  String museumOpenHours = '08:00 - 16:00';
  String museumDescription = 'Belum ada deskripsi mendalam mengenai museum ini.';
  String photoUrl = 'https://images.unsplash.com/photo-1541123437800-1bb1317badc2?q=80&w=600';
  String placeId = '';

  @override
  void initState() {
    super.initState();

    // Ekstraksi data dari objek place
    try {
      if (widget.place != null) {
        if (widget.place.name != null) museumName = widget.place.name.toString();
        if (widget.place.address != null) museumAddress = widget.place.address.toString();
        if (widget.place.openHours != null) museumOpenHours = widget.place.openHours.toString();
        if (widget.place.description != null) museumDescription = widget.place.description.toString();
        if (widget.place.photoUrl != null) photoUrl = widget.place.photoUrl.toString();
        if (widget.place.id != null) placeId = widget.place.id.toString();
      }
    } catch (e) {
      debugPrint("Gagal ekstraksi data model di DetailScreen: $e");
    }

    // Jika dibuka dari tap rating, scroll ke section review setelah render selesai
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

  // Fungsi scroll otomatis ke section ulasan
  void _scrollToReviewSection() {
    final context = _reviewKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.0, // 0 = rata atas viewport
      );
    }
  }

  void _openMapRoute(BuildContext context) {
    if (widget.place == null) return;
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
    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── 1. HEADER: Banner foto ──
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: darkBrown,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: gold.withOpacity(0.2),
                      child: const Icon(Icons.museum_rounded,
                          size: 64, color: gold),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 2. BODY: Informasi museum + review ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama museum
                  Text(
                    museumName,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: darkBrown,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Alamat
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: gold, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          museumAddress,
                          style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Jam buka
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: gold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Jam Buka: $museumOpenHours',
                        style: GoogleFonts.dmSans(
                            fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Divider(color: Colors.black12),
                  const SizedBox(height: 16),

                  // Tentang Museum
                  Text(
                    'Tentang Museum',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkBrown,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    museumDescription,
                    textAlign: TextAlign.justify,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: darkBrown.withOpacity(0.8),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ══════════════════════════════════════════════
                  //  SECTION ULASAN — pakai GlobalKey agar bisa
                  //  di-scroll ke sini dari luar
                  // ══════════════════════════════════════════════
                  Container(
                    key: _reviewKey, // ← anchor untuk scroll
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: Colors.black12),
                        const SizedBox(height: 20),

                        // Header section ulasan dengan tombol "scroll ke sini"
                        Row(
                          children: [
                            Text(
                              'Ulasan Pengunjung',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: darkBrown,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Widget CRUD Review
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
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── 3. FOOTER: Tombol navigasi ──
      bottomSheet: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _openMapRoute(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.navigation_rounded, size: 20),
              label: Text(
                'BUKA RUTE NAVIGASI',
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}