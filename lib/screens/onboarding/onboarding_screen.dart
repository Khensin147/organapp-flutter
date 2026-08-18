import 'package:flutter/material.dart';
import '../auth/auth_gate.dart'; // GANTI: dulu import login_screen, sekarang auth_gate
import 'auto_scrool_grid.dart'; // widget grid auto-scroll yang sudah dibuat sebelumnya

// Warna aksen disamakan dengan tema biru yang sekarang dipakai
// di LoginScreen, supaya onboarding terasa satu kesatuan dengan
// aplikasi. Tinggal ganti dua nilai ini kalau mau ubah warna lagi.
const Color _kAccent = Color(0xFF1B3F9E);
const Color _kAccentSoft = Color(0xFFE7ECFB);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // GANTI: judul dan deskripsi onboarding satu halaman ini.
  static const String _title = "Belajar Organ Tubuh\nManusia";
  static const String _description =
      "Pelajari sistem pencernaan, pernapasan, darah, dan ekskresi "
      "dengan cara yang menyenangkan, lalu uji pemahamanmu lewat quiz interaktif.";

  // FIX: karena foto organ pakai JPG (tidak transparan), background
  // warna di belakang foto dibuang. Foto sekarang langsung mengisi
  // penuh tile (BoxFit.cover), jadi "background" tile-nya ya foto
  // itu sendiri. Warna _kAccentSoft cuma dipakai lagi kalau fotonya
  // gagal dimuat (lihat errorBuilder di bawah).
  Widget _tile(String assetPath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover, // foto mengisi penuh tile, dipotong (crop) kalau perlu
        errorBuilder: (context, error, stackTrace) {
          // Placeholder kalau file gambar belum ada / gagal dimuat,
          // supaya tidak crash. Di sinilah warna aksen masih dipakai.
          return Container(
            color: _kAccentSoft,
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              size: 40,
              color: _kAccent,
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();
  }

  // CATATAN: dulu di sini kita simpan flag 'onboarding_selesai' ke
  // SharedPreferences supaya onboarding tidak muncul lagi di kemudian
  // hari. Sekarang flag itu SENGAJA TIDAK dipakai lagi karena
  // onboarding memang harus selalu tampil setiap app dibuka (sesuai
  // permintaan). Kalau suatu saat mau dikembalikan ke perilaku lama,
  // tinggal aktifkan lagi baris SharedPreferences di bawah.
  Future<void> _selesaiOnboarding() async {
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setBool('onboarding_selesai', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        // GANTI: dulu langsung ke LoginScreen(), sekarang ke AuthGate().
        // AuthGate yang akan memutuskan: kalau sesi login masih berlaku
        // (belum lewat 2 menit sejak app ditinggal), user langsung
        // diarahkan ke HomeScreen/AdminScreen TANPA perlu login ulang.
        // Kalau sesi sudah habis atau memang belum pernah login, baru
        // AuthGate menampilkan LoginScreen.
        builder: (context) => const AuthGate(),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── GRID FOTO ORGAN AUTO-SCROLL DI BAGIAN ATAS ──────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.56,
            child: SafeArea(
              bottom: false,
              child: AutoScrollGrid(
                height: screenHeight * 0.5,
                speed: 30, // pixel per detik — naikkan angka ini kalau mau lebih cepat
                // Kolom 1 & 3 ke atas, kolom 2 ke bawah (berlawanan)
                scrollUp: const [true, false, true],
                columns: [
                  [
                    _tile('assets/images/jantung.jpg'),
                    _tile('assets/images/paru.jpg'),
                    _tile('assets/images/ginjal.jpg'),
                  ],
                  [
                    _tile('assets/images/otak.jpg'),
                    _tile('assets/images/lambung.jpg'),
                    _tile('assets/images/hati.jpg'),
                  ],
                  [
                    _tile('assets/images/usus.jpg'),
                    _tile('assets/images/mata.jpg'),
                    _tile('assets/images/trakea.jpg'),
                  ],
                ],
              ),
            ),
          ),

          // ── GRADIENT SUPAYA GRID MEMUDAR KE PUTIH DI BAWAH ──────
          Positioned(
            top: screenHeight * 0.30,
            left: 0,
            right: 0,
            height: screenHeight * 0.30,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white],
                  ),
                ),
              ),
            ),
          ),

          // ── TEKS + TOMBOL DI BAGIAN BAWAH ───────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // TOMBOL MULAI (full width, sekarang lewat AuthGate)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _selesaiOnboarding,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Mulai Belajar",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
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