import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({Key? key}) : super(key: key);

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen>
    with TickerProviderStateMixin {
  late AnimationController _lineCtrl;
  late AnimationController _textCtrl;
  late AnimationController _subCtrl;
  late AnimationController _btnCtrl;

  @override
  void initState() {
    super.initState();

    _lineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _subCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _runSequence();
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    _textCtrl.dispose();
    _subCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _lineCtrl.forward();
    await _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    await _subCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _btnCtrl.forward();
  }

  void _enter() {
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, anim, __) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: const HomeScreen(),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Animations
    final lineAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut));

    final textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);

    final textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    final subFade = CurvedAnimation(parent: _subCtrl, curve: Curves.easeOut);

    final btnFade = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);

    final btnSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOutCubic));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── TOP LINE ──────────────────────────────────────
              AnimatedBuilder(
                animation: lineAnim,
                builder: (_, __) => Container(
                  height: 0.5,
                  width: 180 * lineAnim.value,
                  color: const Color(0xFFC8A96B),
                ),
              ),

              const SizedBox(height: 16),

              // ── ASTERISK ICON ─────────────────────────────────
              FadeTransition(
                opacity: textFade,
                child: const Text(
                  '✦',
                  style: TextStyle(
                    color: Color(0xFFC8A96B),
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── LOGO ──────────────────────────────────────────
              // Logo ditampilkan apa adanya — background cream sudah sesuai
              FadeTransition(
                opacity: textFade,
                child: SlideTransition(
                  position: textSlide,
                  child: Image.asset(
                    'assets/images/logo_musra.png',
                    height: 280,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── JAWA TIMUR subtitle ───────────────────────────
              SlideTransition(
                position: textSlide,
                child: FadeTransition(
                  opacity: textFade,
                  child: Text(
                    'JAWA TIMUR',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFC8A96B),
                      letterSpacing: 6,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── BOTTOM LINE ───────────────────────────────────
              AnimatedBuilder(
                animation: lineAnim,
                builder: (_, __) => Container(
                  height: 0.5,
                  width: 180 * lineAnim.value,
                  color: const Color(0xFFC8A96B),
                ),
              ),

              const SizedBox(height: 20),

              // ── TAGLINE ───────────────────────────────────────
              FadeTransition(
                opacity: subFade,
                child: Text(
                  'Direktori Wisata Sejarah & Budaya',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF7A6F65),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(flex: 2),

              // ── BUTTON ────────────────────────────────────────
              SlideTransition(
                position: btnSlide,
                child: FadeTransition(
                  opacity: btnFade,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _enter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1614),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Jelajahi Museum',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '80+ museum terdaftar di Jawa Timur',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFFB5AAA0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}