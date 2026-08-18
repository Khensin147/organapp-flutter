import 'package:flutter/material.dart';
import 'package:organappfr/screens/materi/materi_screen.dart';
import 'package:organappfr/screens/quiz/quiz_screen.dart';
import 'package:organappfr/service/organ_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // untuk simpan status "sudah lihat tour"
import 'package:showcaseview/showcaseview.dart'; // package showcase tour
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../notifikasi/notifikasiscreen.dart';
import '../materi/about_screen.dart';
import '../materi/profile_screen.dart';

import '../leaderboard.dart';


class _HomeColors {
  static const Color primary = Color(0xFF1B3F9E);
  static const Color primaryDark = Color(0xFF122C6F);
  static const Color primarySoft = Color(0xFFE7ECFA);
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF16181D);
  static const Color textGray = Color(0xFF6B7280);
  static const Color textFaint = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFEDEDF2);
  static const Color accentOrange = Color(0xFFFFA726);
  static const Color badgeGreenBg = Color(0xFFDDF5E7);
  static const Color badgeGreenText = Color(0xFF1B9C5A);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final OrganService _organService = OrganService();
  final _supabase = Supabase.instance.client;

  String _namaSiswa = '';
  String? _avatarUrl;
  int _organSudah = 0;
  int _organTotal = 0;
  bool _isLoadingProgress = true;

  // Controller & index untuk carousel "Fakta Menarik" (murni state UI,
  // tidak menyimpan apapun ke backend).
  final PageController _faktaPageController = PageController();
  int _faktaIndex = 0;

  // ── ANIMASI PEMBUKAAN APLIKASI (entrance animation) ─────────────────────
  // Satu controller dipakai bersama untuk semua section, tiap section
  // hanya mengambil "potongan waktu" (Interval) yang berbeda supaya
  // urutan munculnya bertahap (staggered), bukan langsung serentak.
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  // Kalimat ajakan belajar di samping profil — berubah sesuai jam, tapi
  // isinya selalu mengajak belajar (bukan sekadar "Selamat pagi/malam").
  String get _greetingAjakan {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Yuk mulai belajar pagi ini!';
    if (hour < 15) return 'Semangat lanjutkan belajarmu!';
    if (hour < 18) return 'Waktu yang pas untuk belajar!';
    return 'Sedikit lagi, ayo belajar!';
  }

  bool get _showLanjutkanButton =>
      !_isLoadingProgress && _organTotal > 0 && _organSudah < _organTotal;

  final GlobalKey _keyFeatured = GlobalKey();
  final GlobalKey _keyProfile = GlobalKey();
  final GlobalKey _keyMateri = GlobalKey();
  final GlobalKey _keyQuiz = GlobalKey();
  final GlobalKey _keyTentang = GlobalKey();
  final GlobalKey _keyRanking = GlobalKey();
  final GlobalKey _keyProgress = GlobalKey();

  // Data grid "Quick Action" — 4 menu utama, sekarang tiap item punya
  // subtitle singkat mengikuti gaya referensi (mis. "PDF, DOCX atau Scanned").
  final List<_MenuItemData> _menuItems = const [
    _MenuItemData(
      icon: Icons.monitor_heart_outlined,
      title: 'Materi',
      subtitle: 'Jelajahi organ tubuh',
      color: Color(0xFF3E8EF7),
    ),
    _MenuItemData(
      icon: Icons.quiz_outlined,
      title: 'Quiz',
      subtitle: 'Uji pemahamanmu',
      color: Color(0xFF16A085),
    ),
    _MenuItemData(
      icon: Icons.info_outline_rounded,
      title: 'Tentang',
      subtitle: 'Panduan aplikasi',
      color: Color(0xFFEF5DA8),
    ),
    _MenuItemData(
      icon: Icons.emoji_events_outlined,
      title: 'Nilai',
      subtitle: 'Lihat rekap nilaimu',
      color: Color(0xFFFFA726),
    ),
  ];

  // TODO: masih statis (hardcoded). Kalau mau dinamis, ganti sumbernya
  // dengan fetch dari Supabase (misal tabel `fakta_organ`) lewat
  // organ_service.dart, lalu isi list ini di dalam _loadData().
  final List<_FaktaData> _fakta = const [
    _FaktaData(
      icon: Icons.favorite_rounded,
      judul: 'Jantung Berdetak',
      isi: 'Berdetak sekitar 100.000 kali sehari, tanpa istirahat.',
      color: Color(0xFFEF5350),
    ),
    _FaktaData(
      icon: Icons.air_rounded,
      judul: 'Kapasitas Paru-paru',
      isi: 'Total saluran udara di paru-paru bisa mencapai 2.400 km.',
      color: Color(0xFF3E8EF7),
    ),
    _FaktaData(
      icon: Icons.psychology_rounded,
      judul: 'Otak yang Rakus',
      isi: 'Hanya 2% berat tubuh, tapi memakai 20% energi tubuhmu.',
      color: Color(0xFF9C6ADE),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();

    // Jalankan animasi pembukaan begitu frame pertama siap, tidak perlu
    // menunggu data selesai dimuat supaya transisi terasa instan saat
    // layar ini pertama kali tampil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceController.forward();
      _maybeStartTour();
    });
  }

  @override
  void dispose() {
    _faktaPageController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _maybeStartTour() async {
    final prefs = await SharedPreferences.getInstance();
    final sudahLihat = prefs.getBool('tour_home_done') ?? false;
    if (sudahLihat) return;
    if (!mounted) return;

    ShowCaseWidget.of(context).startShowCase([
      _keyProfile,
      _keyFeatured,
      _keyMateri,
      _keyQuiz,
      _keyTentang,
      _keyRanking,
      _keyProgress,
    ]);

    await prefs.setBool('tour_home_done', true);
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingProgress = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final siswaData = await _supabase
            .from('siswa')
            .select('nama, avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        if (siswaData != null) {
          _namaSiswa = siswaData['nama'] ?? '';
          _avatarUrl = siswaData['avatar_url'];
        }
      }

      final progress = await _organService.getProgress();
      setState(() {
        _organSudah = progress['sudah'] ?? 0;
        _organTotal = progress['total'] ?? 0;
      });
    } catch (e) {
      debugPrint("Gagal load data home: $e");
    } finally {
      setState(() => _isLoadingProgress = false);
    }
  }

  double get _progressValue => _organTotal == 0 ? 0 : _organSudah / _organTotal;

  String get _progressPersen => '${(_progressValue * 100).toInt()}%';

  void _goToMateri() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MateriScreen()),
    ).then((_) => _loadData());
  }

  void _goToQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuizScreen()),
    );
  }

  void _goToAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AboutScreen()),
    );
  }

  void _goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    ).then((_) => _loadData());
  }

  // Menuju halaman Nilai. Nama method & class tujuan (`LeaderboardScreen`)
  // sengaja belum diganti supaya tidak memutus import/route yang sudah ada
  // di project kamu — hanya teks yang tampil ke user (label & subtitle
  // kartu, showcase) yang diperbarui menjadi "Nilai".
  void _goToLeaderboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
    );
  }

  // Membuka halaman Pengaturan Pengingat Belajar (NotifikasiScreen).
  void _goToNotifikasi() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotifikasiScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeColors.background,
      body: SafeArea(
        top: false, // header sengaja "bleed" sampai belakang status bar
        child: RefreshIndicator(
          color: _HomeColors.primary,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header wave + kartu statistik melayang di atasnya.
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _EntranceFade(
                      controller: _entranceController,
                      interval: const Interval(0.0, 0.55, curve: Curves.easeOut),
                      beginOffset: const Offset(0, -0.15),
                      child: _buildHeaderWave(context),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: -34,
                      child: _EntranceFade(
                        controller: _entranceController,
                        interval:
                        const Interval(0.2, 0.7, curve: Curves.easeOut),
                        beginOffset: const Offset(0, 0.4),
                        child: _buildFloatingStatCard(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 46), // ruang untuk kartu melayang
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EntranceFade(
                        controller: _entranceController,
                        interval:
                        const Interval(0.25, 0.6, curve: Curves.easeOut),
                        beginOffset: const Offset(0, 0.15),
                        child: _buildSectionHeader('Quick Action'),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActionGrid(),
                      const SizedBox(height: 20),
                      _EntranceFade(
                        controller: _entranceController,
                        interval:
                        const Interval(0.55, 0.9, curve: Curves.easeOut),
                        beginOffset: const Offset(0, 0.2),
                        child: _buildProgresBelajar(),
                      ),
                      const SizedBox(height: 26),
                      _EntranceFade(
                        controller: _entranceController,
                        interval:
                        const Interval(0.65, 1.0, curve: Curves.easeOut),
                        beginOffset: const Offset(0, 0.15),
                        child: _buildSectionHeader('Fakta Menarik'),
                      ),
                      const SizedBox(height: 12),
                      _EntranceFade(
                        controller: _entranceController,
                        interval:
                        const Interval(0.7, 1.0, curve: Curves.easeOut),
                        beginOffset: const Offset(0, 0.2),
                        child: _buildFaktaMenarikCarousel(),
                      ),
                      const SizedBox(height: 40),
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

  // ── HEADER WAVE (ungu, sudut bawah melengkung) ───────────────────────────
  Widget _buildHeaderWave(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return ClipPath(
      clipper: _HeaderWaveClipper(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: topPad + 16,
          bottom: 64,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_HomeColors.primary, _HomeColors.primaryDark],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ikon notifikasi, sekarang di pojok KANAN atas header.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _goToNotifikasi,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.16),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Avatar + nama + subtitle ajakan belajar.
            Row(
              children: [
                Showcase(
                  key: _keyProfile,
                  title: 'Profil Kamu',
                  description: 'Tap foto ini untuk lihat dan ubah profilmu.',
                  targetShapeBorder: const CircleBorder(),
                  tooltipBackgroundColor: _HomeColors.primary,
                  textColor: Colors.white,
                  child: GestureDetector(
                    onTap: _goToProfile,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.18),
                        border: Border.all(color: Colors.white, width: 2),
                        image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                            ? DecorationImage(
                          image: NetworkImage(_avatarUrl!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                          ? const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 26,
                      )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _namaSiswa.isNotEmpty ? _namaSiswa : 'Sahabat Organ',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.22),
                            ),
                            child: const Icon(
                              Icons.auto_stories_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _greetingAjakan,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── KARTU STATISTIK MELAYANG (setengah di header, setengah di putih) ────
  // Datanya memakai progress yang sama (_organSudah / _organTotal), cuma
  // ditampilkan ulang dalam bentuk kartu 2 kolom seperti referensi foto.
  Widget _buildFloatingStatCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _HomeColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              value: _isLoadingProgress ? '...' : '$_organSudah',
              label: 'Organ Selesai',
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: _HomeColors.border,
          ),
          Expanded(
            child: _StatColumn(
              value: _isLoadingProgress ? '...' : '$_organTotal',
              label: 'Total Organ',
            ),
          ),
        ],
      ),
    );
  }

  // ── SECTION HEADER ──────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15.5,
        color: _HomeColors.textDark,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ── QUICK ACTION GRID (2x2, kotak ikon pastel) ──────────────────────────
  GlobalKey _menuKeyFor(int i) {
    switch (i) {
      case 0:
        return _keyMateri;
      case 1:
        return _keyQuiz;
      case 2:
        return _keyTentang;
      default:
        return _keyRanking;
    }
  }

  String _menuShowcaseTitle(int i) {
    switch (i) {
      case 0:
        return 'Materi';
      case 1:
        return 'Quiz';
      case 2:
        return 'Tentang Aplikasi';
      default:
        return 'Nilai';
    }
  }

  String _menuShowcaseDesc(int i) {
    switch (i) {
      case 0:
        return 'Jelajahi koleksi model organ 3D interaktif di sini.';
      case 1:
        return 'Uji seberapa paham kamu lewat quiz interaktif.';
      case 2:
        return 'Baca panduan lengkap penggunaan aplikasi ini.';
      default:
        return 'Lihat rekap nilai kuis kamu di sini.';
    }
  }

  VoidCallback _menuActionFor(int i) {
    switch (i) {
      case 0:
        return _goToMateri;
      case 1:
        return _goToQuiz;
      case 2:
        return _goToAbout;
      default:
        return _goToLeaderboard;
    }
  }

  Widget _buildQuickActionGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.3,
      children: List.generate(_menuItems.length, (i) {
        final data = _menuItems[i];
        // Tiap kartu diberi jeda kecil (0.06 per index) supaya muncul
        // satu-satu dari kiri-atas ke kanan-bawah (efek cascade), masih
        // dalam rentang waktu keseluruhan grid (0.3 – 1.0 dari durasi).
        final start = (0.3 + (i * 0.08)).clamp(0.0, 1.0);
        final end = (start + 0.4).clamp(0.0, 1.0);
        return _EntranceFade(
          controller: _entranceController,
          interval: Interval(start, end, curve: Curves.easeOut),
          beginOffset: const Offset(0, 0.2),
          child: Showcase(
            key: _menuKeyFor(i),
            title: _menuShowcaseTitle(i),
            description: _menuShowcaseDesc(i),
            targetBorderRadius: BorderRadius.circular(18),
            tooltipBackgroundColor: _HomeColors.primary,
            textColor: Colors.white,
            child: _QuickActionCard(
              data: data,
              onTap: _menuActionFor(i),
            ),
          ),
        );
      }),
    );
  }

  // ── PROGRES BELAJAR (disederhanakan: judul + lingkaran persentase) ─────
  Widget _buildProgresBelajar() {
    return Showcase(
      key: _keyFeatured,
      title: 'Progres Belajar',
      description: 'Pantau progres belajarmu di sini.',
      targetBorderRadius: BorderRadius.circular(20),
      tooltipBackgroundColor: _HomeColors.primary,
      textColor: Colors.white,
      child: GestureDetector(
        onTap: _showLanjutkanButton ? _goToMateri : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: _HomeColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progres Belajar',
                style: TextStyle(
                  fontSize: 15,
                  color: _HomeColors.textDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animasi progress lingkaran ikut "mengisi" dari 0
                    // menuju nilai sebenarnya saat layar pertama dibuka,
                    // alih-alih langsung muncul penuh.
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: _isLoadingProgress ? 0 : _progressValue,
                      ),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return SizedBox(
                          width: 54,
                          height: 54,
                          child: CircularProgressIndicator(
                            value: _isLoadingProgress ? null : value,
                            strokeWidth: 5,
                            backgroundColor: _HomeColors.primarySoft,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              _HomeColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
                    Text(
                      _isLoadingProgress ? '...' : _progressPersen,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _HomeColors.textDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAKTA MENARIK (carousel satu kartu, bisa digeser) ───────────────────
  Widget _buildFaktaMenarikCarousel() {
    return Showcase(
      key: _keyProgress,
      title: 'Fakta Menarik',
      description: 'Geser untuk melihat fakta menarik lainnya.',
      targetBorderRadius: BorderRadius.circular(16),
      tooltipBackgroundColor: _HomeColors.primary,
      textColor: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: PageView.builder(
              controller: _faktaPageController,
              itemCount: _fakta.length,
              onPageChanged: (i) => setState(() => _faktaIndex = i),
              itemBuilder: (context, i) {
                return _ActivityListItem(fakta: _fakta[i]);
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_fakta.length, (i) {
              final active = i == _faktaIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? _HomeColors.primary : _HomeColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── HELPER WIDGETS ────────────────────────────────────────────────────────────

// Widget kecil untuk animasi pembukaan (fade-in + slide-in) yang dipakai
// berulang di seluruh section HomeScreen. Menerima AnimationController yang
// sama dan sebuah Interval agar tiap section bisa "mulai" & "selesai" pada
// potongan waktu yang berbeda (efek staggered).
class _EntranceFade extends StatelessWidget {
  final AnimationController controller;
  final Interval interval;
  final Offset beginOffset;
  final Widget child;

  const _EntranceFade({
    required this.controller,
    required this.interval,
    required this.child,
    this.beginOffset = const Offset(0, 0.2),
  });

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: controller, curve: interval);
    final slide = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(fade);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Opacity(
          opacity: fade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              slide.value.dx * 40,
              slide.value.dy * 40,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// Clipper custom untuk header "wave": sudut bawah melengkung ke bawah di
// bagian tengah (bukan borderRadius kotak biasa), mendekati referensi foto.
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 46);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 18,
      size.width,
      size.height - 46,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Satu kolom angka + label di dalam kartu statistik melayang.
class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            color: _HomeColors.textDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: _HomeColors.textFaint,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Kartu grid "Quick Action": kotak ikon PASTEL (bg = warna transparan +
// ikon berwarna solid) + judul + subtitle, dengan efek shadow melayang.
class _QuickActionCard extends StatelessWidget {
  final _MenuItemData data;
  final VoidCallback? onTap;
  const _QuickActionCard({required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _HomeColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: data.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, size: 21, color: data.color),
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              style: const TextStyle(
                fontSize: 13.5,
                color: _HomeColors.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              data.subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: _HomeColors.textFaint,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Kartu satu fakta untuk carousel "Fakta Menarik": ikon kotak, judul,
// subtitle, dan badge kecil di kanan, dengan shadow melayang.
class _ActivityListItem extends StatelessWidget {
  final _FaktaData fakta;
  const _ActivityListItem({required this.fakta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _HomeColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: fakta.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(fakta.icon, size: 20, color: fakta.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fakta.judul,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _HomeColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  fakta.isi,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: _HomeColors.textGray,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _HomeColors.badgeGreenBg,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Info',
              style: TextStyle(
                fontSize: 10.5,
                color: _HomeColors.badgeGreenText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── DATA MODELS ───────────────────────────────────────────────────────────────
class _MenuItemData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _MenuItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

class _FaktaData {
  final IconData icon;
  final String judul, isi;
  final Color color;
  const _FaktaData({
    required this.icon,
    required this.judul,
    required this.isi,
    required this.color,
  });
}