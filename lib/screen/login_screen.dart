import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'register_screen.dart';
import 'admin_dashboard_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  static const Color _gold = Color(0xFFC8A96B);
  static const Color _bg = Color(0xFFF8F5F0);
  static const Color _darkBrown = Color(0xFF3E2723);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Email dan password tidak boleh kosong', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Proses Autentikasi Utama ke Supabase Auth
      final AuthResponse response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final sessionUser = response.user;
      if (sessionUser == null) throw const AuthException('Pengguna tidak ditemukan');

      // 2. Tarik data kustom dari tabel 'public.users' untuk memeriksa kolom 'role' (Sesuai ERD)
      final userData = await Supabase.instance.client
          .from('users')
          .select('role') // Kita hanya butuh field role saja agar efisien
          .eq('id', sessionUser.id)
          .single(); // Mengambil satu baris data objek JSON

      if (!mounted) return;

      final String? role = userData['role'] as String?;

      // 3. Logika Percabangan / Routing Berdasarkan Hak Akses Role
      if (role == 'admin') {
        _showSnackBar('Login sukses sebagai Admin!');
        
        // Menuju Dashboard Admin (CRUD Places)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } else {
        _showSnackBar('Selamat Datang di Museum Nusantara!');
        
      
       Navigator.pop(context, true);
      }

    } on AuthException catch (e) {
      // Menangkap error autentikasi bawaan Supabase (password salah, email tidak terdaftar)
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      // Menangkap error jika tabel kustom bermasalah
      debugPrint('Error Role Checking: $e');
      _showSnackBar('Gagal memproses hak akses akun Anda.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cormorantGaramond()),
        backgroundColor: isError ? Colors.red[700] : _gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
           
              // Header
                          Text(
                'Selamat\nDatang Kembali',
                textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: _darkBrown,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masuk untuk menjelajahi museum di Jawa Timur',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 15,
                  color: _darkBrown.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 48),

              // Divider ornament
              Row(
                children: [
                  Expanded(child: Divider(color: _gold.withOpacity(0.4))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.museum_outlined, size: 18, color: _gold),
                  ),
                  Expanded(child: Divider(color: _gold.withOpacity(0.4))),
                ],
              ),
              const SizedBox(height: 36),

              // Email field
              _buildLabel('Email'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hint: 'contoh@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Password field
              _buildLabel('Password'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _passwordController,
                hint: '••••••••',
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: _gold,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 40),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Masuk',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Register link
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: RichText(
                    text: TextSpan(
                      text: 'Belum punya akun? ',
                      style: GoogleFonts.cormorantGaramond(
                        color: _darkBrown.withOpacity(0.6),
                        fontSize: 15,
                      ),
                      children: [
                        TextSpan(
                          text: 'Daftar',
                          style: GoogleFonts.cormorantGaramond(
                            color: _gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.cormorantGaramond(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _darkBrown,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: GoogleFonts.cormorantGaramond(fontSize: 16, color: _darkBrown),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.cormorantGaramond(
            color: _darkBrown.withOpacity(0.35),
            fontSize: 15,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          suffixIcon: suffix,
        ),
      ),
    );
  }
}