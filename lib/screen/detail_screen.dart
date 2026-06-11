import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_screen.dart'; // Import file peta internal aplikasi

class DetailScreen extends StatelessWidget {
  final dynamic place; // Menampung objek model museum (PlaceModel)
  final LatLng userLocation; // Menampung koordinat GPS asli dari halaman depan

  const DetailScreen({
    super.key,
    required this.place,
    required this.userLocation,
  });

  // Fungsi untuk berpindah ke halaman peta internal bawaan aplikasi
  void _openMapRoute(BuildContext context) {
    if (place == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          place: place,
          userLocation: userLocation, // Oper koordinat GPS asli ke MapScreen
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definisi Tema Warna Premium Museum Nusantara
    const Color gold = Color(0xFFC8A96B);
    const Color darkBrown = Color(0xFF3E2723);
    const Color bg = Color(0xFFF8F5F0);

    // ── EKSTRAKSI DATA AMAN DARI OBJEK DYNAMIC (ANTI-CRASH) ──
    String museumName = 'Tanpa Nama';
    String museumAddress = 'Alamat tidak tersedia';
    String museumOpenHours = '08:00 - 16:00';
    String museumDescription = 'Belum ada deskripsi mendalam mengenai museum ini.';
    String photoUrl = 'https://images.unsplash.com/photo-1541123437800-1bb1317badc2?q=80&w=600';

    try {
      if (place != null) {
        if (place.name != null) museumName = place.name.toString();
        if (place.address != null) museumAddress = place.address.toString();
        if (place.openHours != null) museumOpenHours = place.openHours.toString();
        if (place.description != null) museumDescription = place.description.toString();
        if (place.photoUrl != null) photoUrl = place.photoUrl.toString();
      }
    } catch (e) {
      debugPrint("Gagal ekstraksi data model di DetailScreen: $e");
    }

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // 1. HEADER: Banner Gambar yang Bisa Mengecil Saat Di-scroll (SliverAppBar)
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
                      child: const Icon(Icons.museum_rounded, size: 64, color: gold),
                    ),
                  ),
                  // Efek gradasi gelap di bawah gambar agar teks judul terlihat saat menyusut
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

          // 2. BODY: Informasi Lengkap Museum
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Judul Besar Museum
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

                  // Alamat Lengkap dengan Icon Marker
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, color: gold, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          museumAddress,
                          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.grey[700], height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Jam Operasional Kerja
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: gold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Jam Buka: $museumOpenHours',
                        style: GoogleFonts.dmSans(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Divider(color: Colors.black12),
                  const SizedBox(height: 16),

                  // Label Judul Deskripsi
                  Text(
                    'Tentang Museum',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkBrown,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Teks Narasi Sejarah Lengkap
                  Text(
                    museumDescription,
                    textAlign: TextAlign.justify,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: darkBrown.withOpacity(0.8),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 100), // Spacing bawah agar tidak tertutup tombol fixed
                ],
              ),
            ),
          )
        ],
      ),

      // 3. FOOTER: Tombol Navigasi yang Melayang Tetap di Bagian Bawah Layar
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.navigation_rounded, size: 20),
              label: Text(
                'BUKA RUTE NAVIGASI',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}