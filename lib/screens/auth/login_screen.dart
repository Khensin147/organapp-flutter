import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:organappfr/screens/Admin/tambah_guru.dart';
import 'package:organappfr/screens/Guru/guru_screen.dart' hide AdminScreen;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organappfr/screens/Admin/admin_screen.dart';
import 'package:organappfr/screens/navbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// LoginScreen — versi clean/minimalis.
/// Background putih polos, cuma ditemani 2 "blob" radial biru sangat
/// lembut di pojok layar sbg aksen (bukan foto grid), supaya kesannya
/// tenang & modern, tapi tetap satu warna keluarga dgn Splash &
/// Onboarding (_primaryColor / _lightBlue yg sama).
///
/// CATATAN KEAMANAN:
/// Bypass admin hardcoded (username == 'admin' && password == 'admin123')
/// SUDAH DIHAPUS. Sekarang semua user (siswa, guru, maupun admin) login
/// lewat Supabase Auth yang sesungguhnya. Setelah login berhasil, kode
/// ini mengecek kolom `role` di tabel `siswa` untuk menentukan tujuan
/// navigasi. Pastikan kamu sudah menambahkan kolom `role` dan mengatur
/// RLS (Row Level Security) di Supabase — validasi role di client saja
/// TIDAK cukup untuk melindungi data sensitif.
///
/// CATATAN SESI:
/// Setelah login berhasil, timestamp "last_active_timestamp" di
/// SharedPreferences dihapus/direset supaya AuthGate menghitung ulang
/// timer sesi 2 menit dari titik nol. Lihat auth_gate.dart untuk logika
/// auto-login dan auto-logout berbasis waktu tersebut.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordHidden = true;
  bool _isButtonPressed = false;

  // Warna disamakan persis dengan OnboardingScreen & SplashScreen.
  static const Color _primaryColor = Color(0xFF1B3F9E);
  static const Color _lightBlue = Color(0xFFE7ECFB);
  static const Color _darkText = Color(0xFF1A1A2C);
  static const double _radius = 16;
  static const double _badgeSize = 92;

  // ── ANIMASI MASUK (staggered), pola sama spt SplashScreen ───────
  late final AnimationController _entranceController;

  late final Animation<double> _heroFade; // blob dekoratif + tombol keluar

  late final Animation<double> _badgeFade;
  late final Animation<double> _badgeScale; // efek "mantul" ala bola di splash

  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;

  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;

  late final Animation<double> _usernameFade;
  late final Animation<Offset> _usernameSlide;

  late final Animation<double> _passwordFade;
  late final Animation<Offset> _passwordSlide;

  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  late final Animation<double> _footerFade;

  // ── ANIMASI GUNCANG (shake) SAAT LOGIN GAGAL ─────────────────────
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _heroFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    _badgeFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.05, 0.35, curve: Curves.easeIn),
    );
    // TweenSequence yang sama gayanya dgn animasi bola di SplashScreen:
    // membesar lewat ukuran normal, mengecil dikit, baru pas -> "mantul".
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 0.94)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.94, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 23,
      ),
    ]).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.05, 0.45, curve: Curves.linear),
    ));

    _titleFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.25, 0.55, curve: Curves.easeIn),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
    ));

    _subtitleFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.32, 0.60, curve: Curves.easeIn),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.32, 0.60, curve: Curves.easeOutCubic),
    ));

    _usernameFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.42, 0.70, curve: Curves.easeIn),
    );
    _usernameSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.42, 0.70, curve: Curves.easeOutCubic),
    ));

    _passwordFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.50, 0.78, curve: Curves.easeIn),
    );
    _passwordSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.50, 0.78, curve: Curves.easeOutCubic),
    ));

    _buttonFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.60, 0.88, curve: Curves.easeIn),
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.60, 0.88, curve: Curves.easeOutCubic),
    ));

    _footerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _signIn() async {
    final usernameInput = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (usernameInput.isEmpty || password.isEmpty) {
      _showSnackbar("Username dan Password wajib diisi", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Ambil email + role berdasarkan username dari tabel `siswa`.
      //    Pastikan kolom `role` sudah ada (default 'siswa', bisa
      //    'guru' atau 'admin').
      final siswaData = await supabase
          .from('siswa')
          .select('email, role')
          .eq('username', usernameInput)
          .maybeSingle();

      if (siswaData == null) {
        setState(() => _isLoading = false);
        if (mounted) _showSnackbar("Username tidak ditemukan!", isError: true);
        return;
      }

      final email = siswaData['email'] as String;
      final role = (siswaData['role'] as String?) ?? 'siswa';

      // 2. SEMUA user (termasuk admin & guru) login lewat Supabase Auth
      //    yang sesungguhnya. Tidak ada lagi bypass password hardcoded.
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.session != null && mounted) {
        // Reset timestamp "last_active" supaya timer sesi 2 menit
        // (dicek di AuthGate) mulai dihitung ulang dari sekarang.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_active_timestamp');

        _showSnackbar("Login berhasil!");

        // 3. Navigasi ditentukan oleh role dari database, bukan dari
        //    string username/password yang tertanam di kode.
        if (role == 'admin') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AdminScreen()),
                (route) => false,
          );
        } else if (role == 'guru') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const GuruScreen()),
                (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
                (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      _showSnackbar(e.message, isError: true);
    } catch (_) {
      _showSnackbar("Terjadi kesalahan koneksi", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );

    if (isError) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// Lingkaran glow lembut (radial, fade ke transparan) dipakai sbg
  /// aksen dekoratif di pojok layar. Bukan gambar apa pun, murni warna,
  /// jadi ringan dan gak perlu asset tambahan.
  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0.0)],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.black.withOpacity(0.35), fontSize: 14),
      filled: true,
      fillColor: _lightBlue.withOpacity(0.5),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
    );
  }

  /// Bungkus [child] supaya bergetar horizontal & meredam sendiri,
  /// dipakai utk kelompok field username+password saat login gagal.
  Widget _buildShaking({required Widget child}) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, c) {
        final t = _shakeController.value;
        final dx = math.sin(t * math.pi * 8) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: c);
      },
      child: child,
    );
  }

  /// Tombol utama — full width, rounded, teks + panah, ada efek
  /// mengecil saat ditekan dan transisi teks <-> spinner.
  Widget _buildLoginButton() {
    return GestureDetector(
      onTapDown: (_) {
        if (_isLoading) return;
        setState(() => _isButtonPressed = true);
      },
      onTapUp: (_) {
        if (_isLoading) return;
        setState(() => _isButtonPressed = false);
      },
      onTapCancel: () {
        if (_isLoading) return;
        setState(() => _isButtonPressed = false);
      },
      onTap: _isLoading ? null : _signIn,
      child: AnimatedScale(
        scale: _isButtonPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: _isButtonPressed
                ? const []
                : [
              BoxShadow(
                color: _primaryColor.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isLoading
                ? const SizedBox(
              key: ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Row(
              key: ValueKey('label'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Masuk",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── AKSEN DEKORATIF: 2 blob biru sangat lembut di pojok ──
          Positioned(
            top: -70,
            right: -60,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _heroFade,
                child: _blob(220, _lightBlue),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _heroFade,
                child: _blob(260, _primaryColor.withOpacity(0.06)),
              ),
            ),
          ),

          // ── TOMBOL KELUAR ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: FadeTransition(
              opacity: _heroFade,
              child: GestureDetector(
                onTap: () => SystemNavigator.pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _lightBlue.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: _primaryColor, size: 18),
                ),
              ),
            ),
          ),

          // ── KONTEN FORM ──
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 44),

                  // ── Badge logo, "mantul" masuk ──
                  FadeTransition(
                    opacity: _badgeFade,
                    child: ScaleTransition(
                      scale: _badgeScale,
                      child: Container(
                        width: _badgeSize,
                        height: _badgeSize,
                        decoration: BoxDecoration(
                          color: _lightBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/solo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.favorite_rounded,
                                size: 36,
                                color: _primaryColor,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Judul ──
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: const Text(
                        "Masuk ke Akunmu",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: _darkText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  FadeTransition(
                    opacity: _subtitleFade,
                    child: SlideTransition(
                      position: _subtitleSlide,
                      child: Text(
                        "Masukkan username dan password\nuntuk melanjutkan belajar",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Field Username & Password ──
                  _buildShaking(
                    child: Column(
                      children: [
                        FadeTransition(
                          opacity: _usernameFade,
                          child: SlideTransition(
                            position: _usernameSlide,
                            child: TextField(
                              controller: _usernameController,
                              enabled: !_isLoading,
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              style: const TextStyle(fontSize: 14, color: _darkText),
                              decoration: _fieldDecoration(
                                hint: "Username",
                                prefixIcon: Icon(
                                  Icons.person_outline_rounded,
                                  color: _primaryColor.withOpacity(0.55),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeTransition(
                          opacity: _passwordFade,
                          child: SlideTransition(
                            position: _passwordSlide,
                            child: TextField(
                              controller: _passwordController,
                              enabled: !_isLoading,
                              obscureText: _isPasswordHidden,
                              style: const TextStyle(fontSize: 14, color: _darkText),
                              decoration: _fieldDecoration(
                                hint: "Password",
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: _primaryColor.withOpacity(0.55),
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, anim) => RotationTransition(
                                      turns: anim,
                                      child: FadeTransition(opacity: anim, child: child),
                                    ),
                                    child: Icon(
                                      _isPasswordHidden
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      key: ValueKey(_isPasswordHidden),
                                      color: Colors.black.withOpacity(0.35),
                                      size: 20,
                                    ),
                                  ),
                                  onPressed: () => setState(
                                          () => _isPasswordHidden = !_isPasswordHidden),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ── Tombol Masuk ──
                  FadeTransition(
                    opacity: _buttonFade,
                    child: SlideTransition(
                      position: _buttonSlide,
                      child: _buildLoginButton(),
                    ),
                  ),

                  const SizedBox(height: 16),




                  const SizedBox(height: 8),

                  FadeTransition(
                    opacity: _footerFade,
                    child: Text(
                      "Hubungi guru jika lupa username atau password",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}