import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:latlong2/latlong.dart';

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

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchCtrl = TextEditingController();

  late Future<List<CategoryModel>> _categoriesFuture;
  late Future<List<PlaceModel>> _placesFuture;

  String? _selectedCategory;
  String _searchQuery = '';
  int _selectedIndex = 0;
  bool _locationChecked = false;

  late AnimationController _animationController;

  // PERUBAHAN: getter agar rebuild otomatis saat setState
  List<Widget> get _pages => [
    _HomeTab(parent: this),
    const ExploreScreen(),
    const ProfileScreen(),
  ];

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

  void _fetchData() {
    _categoriesFuture = _supabaseService.fetchCategories();
    _placesFuture = _supabaseService.fetchPlaces(
      categoryId: _selectedCategory,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
  }

  void _reload() {
    setState(() {
      _placesFuture = _supabaseService.fetchPlaces(
        categoryId: _selectedCategory,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
    });
  }

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
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  List<PlaceModel> _filterPlaces(List<PlaceModel> places) {
    return places.where((place) {
      final q = _searchQuery.toLowerCase();

      return q.isEmpty ||
          place.name.toLowerCase().contains(q) ||
          place.address.toLowerCase().contains(q) ||
          (place.city?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE0D7CA),
            width: 0.5,
          ),
        ),
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
                onTap: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              ),
              _NavItem(
                icon: Icons.map_rounded,
                label: 'Explore',
                active: _selectedIndex == 1,
                onTap: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profil',
                active: _selectedIndex == 2,
                onTap: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final _HomeScreenState parent;

  const _HomeTab({
    required this.parent,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeader(),
          _buildSearch(),
          _buildCategories(),
          _buildCountBar(),
          _buildList(context),
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Museum Nusantara',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1614),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(width: 32, height: 0.5, color: const Color(0xFFC8A96B)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('✦', style: TextStyle(color: Color(0xFFC8A96B), fontSize: 8)),
                    ),
                    Container(width: 32, height: 0.5, color: const Color(0xFFC8A96B)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Direktori museum bersejarah di Jawa Timur',
                  style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF7A6F65), height: 1.6),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                image: const DecorationImage(
                  image: AssetImage('assets/images/museum_banner.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.72), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Explore Heritage',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Temukan museum terbaik dan paling bersejarah',
                        style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSearch() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0D7CA)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, color: Color(0xFFB5AAA0), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: parent._searchCtrl,
                  onChanged: (value) {
                    parent._searchQuery = value;
                    parent._reload();
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Cari museum atau kota...',
                    hintStyle: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFFB5AAA0)),
                  ),
                  style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF1A1614)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildCategories() {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<CategoryModel>>(
        future: parent._categoriesFuture,
        builder: (_, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 60);

          final categories = snapshot.data!;

          return SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildChip(
                  label: 'Semua',
                  isSelected: parent._selectedCategory == null,
                  onTap: () {
                    parent._selectedCategory = null;
                    parent._reload();
                  },
                ),
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: _buildChip(
                      label: category.name,
                      isSelected: parent._selectedCategory == category.id,
                      onTap: () {
                        parent._selectedCategory =
                            parent._selectedCategory == category.id ? null : category.id;
                        parent._reload();
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: isSelected ? const Color(0xFF1A1614) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF1A1614) : const Color(0xFFE0D7CA),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF7A6F65),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildCountBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: FutureBuilder<List<PlaceModel>>(
          future: parent._placesFuture,
          builder: (_, snapshot) {
            final count = snapshot.hasData ? parent._filterPlaces(snapshot.data!).length : 0;
            return Text(
              '$count museum ditemukan',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFB5AAA0)),
            );
          },
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildList(BuildContext context) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<PlaceModel>>(
        future: parent._placesFuture,
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return _buildSkeleton();
          if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmpty();

          final places = parent._filterPlaces(snapshot.data!);

          return Column(
            children: List.generate(
              places.length,
              (index) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: _PlaceCard(
                  place: places[index],
                  index: index,
                  animCtrl: parent._animationController,
                  onTap: () async {
                    final user = Supabase.instance.client.auth.currentUser;

                    if (user == null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    } else {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC8A96B)),
                          ),
                        ),
                      );

                      try {
                        Position position = await Geolocator.getCurrentPosition(
                          desiredAccuracy: LocationAccuracy.high,
                        );

                        if (context.mounted) Navigator.pop(context);

                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailScreen(
                                place: places[index],
                                userLocation: LatLng(position.latitude, position.longitude),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) Navigator.pop(context);
                        debugPrint("Gagal menangkap lokasi GPS: $e");

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Gagal mendeteksi lokasi GPS aktif Anda.")),
                          );
                        }
                      }
                    }
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFFF4EFE8),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          const Text('🏛', style: TextStyle(fontSize: 42)),
          const SizedBox(height: 12),
          Text(
            'Museum tidak ditemukan',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1614)),
          ),
          const SizedBox(height: 6),
          Text(
            'Coba gunakan kata kunci lain',
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFB5AAA0)),
          ),
        ],
      ),
    );
  }
}

// PLACE CARD
class _PlaceCard extends StatelessWidget {
  final PlaceModel place;
  final int index;
  final AnimationController animCtrl;
  final VoidCallback onTap;

  const _PlaceCard({
    required this.place,
    required this.index,
    required this.animCtrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEDE6DC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: place.photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: place.photoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFFF4EFE8),
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFFC8A96B)),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 25, fontWeight: FontWeight.w700, color: const Color(0xFF1A1614)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFC8A96B)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          place.city != null ? '${place.city} • ${place.address}' : place.address,
                          style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF7A6F65)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFC8A96B)),
                      const SizedBox(width: 4),
                      Text(
                        place.ratingText,
                        style: GoogleFonts.dmSans(
                            fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1A1614)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1614),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Lihat Detail',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
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

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF4EFE8),
      child: Center(child: Icon(Icons.museum_rounded, size: 60, color: Colors.grey.shade300)),
    );
  }
}

// LOCATION BOTTOM SHEET
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
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0D7CA), borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.location_on_rounded, size: 46, color: Color(0xFFC8A96B)),
          const SizedBox(height: 18),
          Text('Aktifkan Lokasi',
              style: GoogleFonts.cormorantGaramond(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            'Museum Nusantara membutuhkan akses lokasi untuk menampilkan museum terdekat.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF7A6F65), height: 1.7),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: onAllow,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1614),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Izinkan Lokasi',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onSkip,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text('Lewati',
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFB5AAA0))),
            ),
          ),
        ],
      ),
    );
  }
}

// NAV ITEM
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

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
            Icon(icon, size: 22, color: active ? const Color(0xFFC8A96B) : Colors.grey[400]),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? const Color(0xFFC8A96B) : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}