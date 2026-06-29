import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'landingpage_screen.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'my_reviews_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── User data ─────────────────────────────────────────────────
  bool get _isLoggedIn => _client.auth.currentUser != null;

  String get _displayName {
    final meta = _client.auth.currentUser?.userMetadata;
    if (meta?['full_name'] != null) return meta!['full_name'] as String;
    final email = _client.auth.currentUser?.email ?? '';
    return email.isNotEmpty ? email.split('@').first : 'Pengguna';
  }

  String get _email => _client.auth.currentUser?.email ?? '';

  String get _avatarUrl {
    final meta = _client.auth.currentUser?.userMetadata;
    return meta?['avatar_url'] as String? ?? '';
  }

  String get _initials {
    final parts = _displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _displayName.isNotEmpty
        ? _displayName[0].toUpperCase()
        : '?';
  }

  // ── Logout ────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmLogoutDialog(),
    );
    if (confirm != true) return;

    await _client.auth.signOut();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, anim, __) => FadeTransition(
            opacity: anim,
            child: const LandingPageScreen(),
          ),
        ),
        (_) => false,
      );
    }
  }

  // ── Go to login ───────────────────────────────────────────────
  void _goLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HEADER ──────────────────────────────────────
              _buildHeader(),

              // ── CONTENT ─────────────────────────────────────
              SliverToBoxAdapter(
                child: _isLoggedIn
                    ? _buildLoggedInContent()
                    : _buildGuestContent(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HEADER — dark background, avatar, stats
  // ══════════════════════════════════════════════════════════════
 // ══════════════════════════════════════════════════════════════
// HEADER — versi terang & simple tanpa logo/avatar besar
// ══════════════════════════════════════════════════════════════
SliverToBoxAdapter _buildHeader() {
  return SliverToBoxAdapter(
    child: Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5EFE6),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE7DDD0),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 14,
        left: 20,
        right: 20,
      ),
      child: Column(
        children: [
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
                    border: Border.all(
                      color: const Color(0xFFE2D7C8),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: Color(0xFF6F6257),
                  ),
                ),
              ),

              const Spacer(),

              Text(
                'Profil Saya',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3D3530),
                ),
              ),

              const Spacer(),

              const SizedBox(width: 38),
            ],
          ),

          // User info kecil aja
          if (_isLoggedIn) ...[
            const SizedBox(height: 16),

            Text(
              _displayName,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3D3530),
              ),
            ),

            const SizedBox(height: 4),

            Text(
              _email,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: const Color(0xFF8A8178),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),

            Text(
              'Masuk untuk menikmati fitur lengkap',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: const Color(0xFF8A8178),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
  

  Widget _avatarFallback() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A1614),
        border: Border.all(color: const Color(0xFFC8A96B), width: 2),
      ),
      child: Center(
        child: Text(
          _initials,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFC8A96B),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LOGGED IN CONTENT
  // ══════════════════════════════════════════════════════════════
  Widget _buildLoggedInContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── AKUN section ──────────────────────────────────────
          _SectionLabel(label: 'AKUN'),
          const SizedBox(height: 10),
          _MenuCard(
            items: [
              _MenuItem(
                icon: Icons.person_outline_rounded,
                label: 'Edit Profil',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditProfileScreen()),
                  ).then((_) {
                    if (mounted) setState(() {});
                  });
                },
              ),
              _MenuItem(
                icon: Icons.favorite_border_rounded,
                label: 'Museum Favorit',
                badge: '0',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.star_border_rounded,
                label: 'Ulasan Saya',
                badge: null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyReviewsScreen()),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.history_rounded,
                label: 'Riwayat Kunjungan',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── PENGATURAN section ────────────────────────────────
          _SectionLabel(label: 'PENGATURAN'),
          const SizedBox(height: 10),
          _MenuCard(
            items: [
              _MenuItem(
                icon: Icons.notifications_none_rounded,
                label: 'Notifikasi',
                trailing: _ToggleSwitch(value: true, onChanged: (_) {}),
                onTap: null,
              ),
              _MenuItem(
                icon: Icons.language_rounded,
                label: 'Bahasa',
                value: 'Indonesia',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.location_on_outlined,
                label: 'Izin Lokasi',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── LAINNYA section ───────────────────────────────────
          _SectionLabel(label: 'LAINNYA'),
          const SizedBox(height: 10),
          _MenuCard(
            items: [
              _MenuItem(
                icon: Icons.info_outline_rounded,
                label: 'Tentang Aplikasi',
                value: 'v1.0.0',
                onTap: () => _showAboutDialog(),
              ),
              _MenuItem(
                icon: Icons.shield_outlined,
                label: 'Kebijakan Privasi',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── KELUAR button ─────────────────────────────────────
          GestureDetector(
            onTap: _logout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0BBBB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    size: 16,
                    color: Color(0xFFE24B4A),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Keluar dari Akun',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE24B4A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // GUEST CONTENT
  // ══════════════════════════════════════════════════════════════
  Widget _buildGuestContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        children: [
          // Login prompt card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEDE6DC)),
            ),
            child: Column(
              children: [
                
                Text(
                  'Masuk untuk Fitur Lengkap',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1614),
                  ),
                ),
                const SizedBox(height: 6),
                // Ornamental divider
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 30,
                        height: 0.5,
                        color: const Color(0xFFC8A96B)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7),
                      child: Text('✦',
                          style: TextStyle(
                              color: Color(0xFFC8A96B), fontSize: 8)),
                    ),
                    Container(
                        width: 30,
                        height: 0.5,
                        color: const Color(0xFFC8A96B)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Simpan museum favorit, tulis ulasan, dan lihat riwayat kunjungan Anda.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF7A6F65),
                    height: 1.6,
                  ),
                ),
               SizedBox(
  width: double.infinity,
  height: 48,
  child: ElevatedButton(
    onPressed: _goLogin,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1A1614),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
      ),
    ),
    child: Text(
      'Masuk',
      style: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  ),
),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Features preview
          _SectionLabel(label: 'FITUR TERSEDIA'),
          const SizedBox(height: 10),

          _MenuCard(
            items: [
              _MenuItem(
                icon: Icons.favorite_border_rounded,
                label: 'Simpan Favorit',
                value: 'Login diperlukan',
                valueColor: const Color(0xFFC8A96B),
                onTap: _goLogin,
              ),
              _MenuItem(
                icon: Icons.star_border_rounded,
                label: 'Tulis Ulasan',
                value: 'Login diperlukan',
                valueColor: const Color(0xFFC8A96B),
                onTap: _goLogin,
              ),
              _MenuItem(
                icon: Icons.history_rounded,
                label: 'Riwayat Kunjungan',
                value: 'Login diperlukan',
                valueColor: const Color(0xFFC8A96B),
                onTap: _goLogin,
              ),
            ],
          ),

          const SizedBox(height: 20),

          _SectionLabel(label: 'LAINNYA'),
          const SizedBox(height: 10),
          _MenuCard(
            items: [
              _MenuItem(
                icon: Icons.info_outline_rounded,
                label: 'Tentang Aplikasi',
                value: 'v1.0.0',
                onTap: () => _showAboutDialog(),
              ),
              _MenuItem(
                icon: Icons.shield_outlined,
                label: 'Kebijakan Privasi',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(
                'Museum Nusantara',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1614),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Direktori Museum Jawa Timur',
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: const Color(0xFF7A6F65)),
              ),
              const SizedBox(height: 12),
              Container(height: 0.5, color: const Color(0xFFE0D7CA)),
              const SizedBox(height: 12),
              Text(
                'Versi 1.0.0\nCloud Computing Project\n© 2025 Museum Nusantara',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF7A6F65),
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1614),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Tutup',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STAT CELL (di header)
// ══════════════════════════════════════════════════════════════
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFC8A96B),
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 9,
                color: const Color(0xFF7A6F65),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SECTION LABEL
// ══════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '✦',
          style: TextStyle(color: Color(0xFFC8A96B), fontSize: 8),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: const Color(0xFF7A6F65),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MENU CARD — container putih dengan list item
// ══════════════════════════════════════════════════════════════
class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;

  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE6DC)),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              if (i > 0)
                Container(
                  height: 0.5,
                  color: const Color(0xFFF0EBE3),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
              item,
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MENU ITEM
// ══════════════════════════════════════════════════════════════
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final String? badge;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.badge,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF4EFE8),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 17,
                color: const Color(0xFF7A6F65),
              ),
            ),
            const SizedBox(width: 12),

            // Label
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF1A1614),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Badge
            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EFE8),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  badge!,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC8A96B),
                  ),
                ),
              ),

            // Value text
            if (value != null)
              Text(
                value!,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: valueColor ?? const Color(0xFFB5AAA0),
                ),
              ),

            // Custom trailing
            if (trailing != null) trailing!,

            // Chevron (hanya kalau ada onTap dan bukan toggle)
            if (onTap != null && trailing == null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: Color(0xFFB5AAA0),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TOGGLE SWITCH (styled)
// ══════════════════════════════════════════════════════════════
class _ToggleSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSwitch({required this.value, required this.onChanged});

  @override
  State<_ToggleSwitch> createState() => _ToggleSwitchState();
}

class _ToggleSwitchState extends State<_ToggleSwitch> {
  late bool _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _val = !_val);
        widget.onChanged(_val);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 40,
        height: 22,
        decoration: BoxDecoration(
          color: _val
              ? const Color(0xFFC8A96B)
              : const Color(0xFFE0D7CA),
          borderRadius: BorderRadius.circular(100),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment:
              _val ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CONFIRM LOGOUT DIALOG
// ══════════════════════════════════════════════════════════════
class _ConfirmLogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
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
                Icons.logout_rounded,
                color: Color(0xFFE24B4A),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Keluar?',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1614),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda akan keluar dari akun Museum Nusantara.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: const Color(0xFF7A6F65),
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
                        color: const Color(0xFFF4EFE8),
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
                          'Keluar',
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