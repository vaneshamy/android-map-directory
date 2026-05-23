import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';


import '../services/supabase_service.dart';
import '../models/category_model.dart';
import '../models/place_model.dart';

import 'login_screen.dart';
import 'explore_screen.dart';
import 'profile_screen.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchCtrl = TextEditingController();

  late Future<List<CategoryModel>> _categoriesFuture;
  late Future<List<PlaceModel>> _placesFuture;

  String? _selectedCategory;
  String _searchQuery = '';
  int _selectedIndex = 0;
  bool _locationChecked = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();

    _fetchData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLocationPermissionDialog();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data fetch ─────────────────────────────────────────────────
  void _fetchData() {
    _categoriesFuture = _supabaseService.fetchCategories();
    _placesFuture = _supabaseService.fetchPlaces(
      categoryId: _selectedCategory,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
  }

  void _reload() => setState(() => _fetchData());

  // ── GPS dialog (bottom sheet, sesuai desain) ───────────────────
  Future<void> _showLocationPermissionDialog() async {
    if (_locationChecked) return;
    _locationChecked = true;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _LocationBottomSheet(
        onAllow: () async {
          Navigator.pop(context);
          await _requestLocation();
        },
        onSkip: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _requestLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  // ── Filter lokal (search + kategori) ──────────────────────────
  List<PlaceModel> _filterPlaces(List<PlaceModel> places) {
    return places.where((place) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          place.name.toLowerCase().contains(q) ||
          place.address.toLowerCase().contains(q) ||
          (place.city?.toLowerCase().contains(q) ?? false);
      return matchSearch;
    }).toList();
  }

  // ── Bottom nav ─────────────────────────────────────────────────
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) {
      Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ExploreScreen()))
          .then((_) => setState(() => _selectedIndex = 0));
    }
    if (index == 2) {
      Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()))
          .then((_) => setState(() => _selectedIndex = 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(),
            _buildSearchSliver(),
            _buildCategorySliver(),
            _buildCountSliver(),
            _buildListSliver(),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  SliverToBoxAdapter _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Logo dalam lingkaran — background hitam agar gunungan tampil
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0A0805),
                    border: Border.all(
                      color: const Color(0xFFC8A96B).withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo_musra.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Museum Nusantara',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 10,
                          color: Color(0xFFC8A96B),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Jawa Timur',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.black87,
                      size: 20,
                    ),
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
                    'Museum Directory',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: Colors.black87,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'Jawa Timur',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFC8A96B),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _OrnamentalDivider(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(height: 0.5, color: const Color(0xFFE0D7CA)),
          ],
        ),
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────────
  SliverToBoxAdapter _buildSearchSliver() {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0D7CA)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded, size: 18, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    _reload();
                  },
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Cari museum atau kota...',
                    hintStyle: GoogleFonts.dmSans(
                        fontSize: 13, color: Colors.grey[400]),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                    _reload();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Category chips ─────────────────────────────────────────────
  SliverToBoxAdapter _buildCategorySliver() {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(height: 0.5, color: const Color(0xFFE0D7CA)),
            FutureBuilder<List<CategoryModel>>(
              future: _categoriesFuture,
              builder: (_, snap) {
                if (!snap.hasData) return const SizedBox(height: 44);
                final cats = snap.data!;
                return SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildCategoryChip(
                        label: 'Semua',
                        isSelected: _selectedCategory == null,
                        onTap: () {
                          setState(() => _selectedCategory = null);
                          _reload();
                        },
                      ),
                      ...cats.map((c) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _buildCategoryChip(
                              label: c.name,
                              isSelected: _selectedCategory == c.id,
                              onTap: () {
                                setState(() => _selectedCategory =
                                    _selectedCategory == c.id ? null : c.id);
                                _reload();
                              },
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
            Container(height: 0.5, color: const Color(0xFFE0D7CA)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A1614)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1A1614)
                : const Color(0xFFE0D7CA),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  // ── Count ──────────────────────────────────────────────────────
  SliverToBoxAdapter _buildCountSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
        child: FutureBuilder<List<PlaceModel>>(
          future: _placesFuture,
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Text('Memuat...',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: Colors.grey[400]));
            }
            final count =
                snap.hasData ? _filterPlaces(snap.data!).length : 0;
            return Text(
              '$count museum ditemukan',
              style: GoogleFonts.dmSans(
                  fontSize: 11, color: Colors.grey[400]),
            );
          },
        ),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────
  SliverToBoxAdapter _buildListSliver() {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<PlaceModel>>(
        future: _placesFuture,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _buildSkeletonList();
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return _buildEmptyState(
                '🏛', 'Belum ada museum', 'Data belum tersedia');
          }
          final places = _filterPlaces(snap.data!);
          if (places.isEmpty) {
            return _buildEmptyState(
                '🔍', 'Tidak ditemukan', 'Coba ubah kata kunci');
          }
          return Column(
            children: List.generate(places.length, (i) {
              return Padding(
                padding:
                    const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: _buildPlaceCard(places[i], i),
              );
            }),
          );
        },
      ),
    );
  }

  // ── Place Card ─────────────────────────────────────────────────
  Widget _buildPlaceCard(PlaceModel place, int index) {
    final animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          (index * 0.08).clamp(0.0, 0.7),
          ((index * 0.08) + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      ),
    );

    final slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        (index * 0.08).clamp(0.0, 0.7),
        ((index * 0.08) + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ),
    ));

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: slide,
        child: GestureDetector(
          onTap: () {
            final user = Supabase.instance.client.auth.currentUser;
            if (user == null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => DetailScreen(place: place)),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEDE6DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  child: SizedBox(
                    height: 185,
                    width: double.infinity,
                    child: place.photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: place.photoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFF4EFE8),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFC8A96B),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) =>
                                _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Number + name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${(index + 1).toString().padLeft(2, '0')}',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 12,
                              color: const Color(0xFFC8A96B),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              place.name,
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Address
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 13, color: Color(0xFFC8A96B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place.city != null
                                  ? '${place.city} · ${place.address}'
                                  : place.address,
                              style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  height: 1.4),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Divider
                      Container(
                          height: 0.5,
                          color: const Color(0xFFE0D7CA)),
                      const SizedBox(height: 12),
                      // Footer
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFC8A96B)),
                          const SizedBox(width: 4),
                          Text(
                            place.ratingText,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (place.openHours != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              place.openHours!,
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: Colors.grey[400]),
                            ),
                          ],
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1614),
                              borderRadius: BorderRadius.circular(100),
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
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF4EFE8),
      child: Center(
        child: Image.asset(
          'assets/images/logo_musra.png',
          width: 56,
          height: 56,
          fit: BoxFit.contain,
          opacity: const AlwaysStoppedAnimation(0.25),
        ),
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────
  Widget _buildSkeletonList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: List.generate(3, (_) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFFF4EFE8),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }),
      ),
    );
  }

  // ── Empty ──────────────────────────────────────────────────────
  Widget _buildEmptyState(String emoji, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(title,
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 18, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(sub,
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0D7CA), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: _selectedIndex == 0,
                onTap: () => _onItemTapped(0),
              ),
              _NavItem(
                icon: Icons.map_rounded,
                label: 'Explore',
                active: _selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profil',
                active: _selectedIndex == 2,
                onTap: () => _onItemTapped(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// GPS BOTTOM SHEET
// ══════════════════════════════════════════════════════════════
class _LocationBottomSheet extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  const _LocationBottomSheet({required this.onAllow, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 3.5,
            decoration: BoxDecoration(
              color: const Color(0xFFE0D7CA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          // Icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF4EFE8),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: const Color(0xFFE0D7CA)),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFFC8A96B),
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Aktifkan Lokasi',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          _OrnamentalDivider(),
          const SizedBox(height: 12),
          Text(
            'Museum Nusantara membutuhkan akses lokasi Anda untuk menampilkan museum terdekat dan estimasi jarak.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.7,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onAllow,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1614),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Izinkan Akses Lokasi',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onSkip,
            child: Text(
              'Lewati untuk sekarang',
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
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
        Container(width: 30, height: 0.5, color: const Color(0xFFC8A96B)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 7),
          child: Text('✦',
              style:
                  TextStyle(color: Color(0xFFC8A96B), fontSize: 8)),
        ),
        Container(width: 30, height: 0.5, color: const Color(0xFFC8A96B)),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: active
                  ? const Color(0xFFC8A96B)
                  : Colors.grey[400],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w400,
                color: active
                    ? const Color(0xFFC8A96B)
                    : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? const Color(0xFFC8A96B)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}