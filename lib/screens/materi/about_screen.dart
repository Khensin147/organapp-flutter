import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  // ── Data konten (ubah sesuai kebutuhanmu) ──
  static const String _appName = 'OrganKu';
  static const String _tagline =
      'Belajar Anatomi Organ Tubuh dengan Model 3D Interaktif';
  static const String _deskripsi =
      'OrganApp membantu siswa memahami sistem organ tubuh manusia '
      'melalui visualisasi model 3D interaktif. Kamu bisa menjelajahi '
      'setiap organ, membaca fungsinya, dan menguji pemahaman lewat '
      'quiz interaktif — semua dalam satu aplikasi.';

  final List<_FiturData> _fitur = const [
    _FiturData(
      icon: Icons.view_in_ar_rounded,
      title: 'Model Organ 3D',
      subtitle: 'Lihat dan putar model organ tubuh dalam bentuk 3D '
          'secara interaktif.',
    ),
    _FiturData(
      icon: Icons.menu_book_rounded,
      title: 'Materi per Pertemuan',
      subtitle: 'Materi organ tersusun rapi berdasarkan pertemuan '
          'atau minggu pembelajaran.',
    ),
    _FiturData(
      icon: Icons.quiz_outlined,
      title: 'Quiz Interaktif',
      subtitle: 'Uji pemahamanmu lewat kuis pilihan ganda '
          'per kategori materi.',
    ),
    _FiturData(
      icon: Icons.insights_rounded,
      title: 'Progress Belajar',
      subtitle: 'Pantau berapa banyak organ yang sudah kamu pelajari.',
    ),
  ];

  final List<_PanduanData> _panduan = const [
    _PanduanData(
      nomor: '1',
      title: 'Buka Materi',
      subtitle: 'Pilih menu Materi, lalu pilih pertemuan dan organ '
          'yang ingin dipelajari.',
    ),
    _PanduanData(
      nomor: '2',
      title: 'Jelajahi Model 3D',
      subtitle: 'Putar, geser, dan zoom model organ untuk melihat '
          'detailnya dari berbagai sisi.',
    ),
    _PanduanData(
      nomor: '3',
      title: 'Kerjakan Quiz',
      subtitle: 'Buka menu Quiz, pilih kategori, lalu jawab '
          'pertanyaan untuk menguji pemahamanmu.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = 'v${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      // package_info_plus belum terpasang / gagal diambil — abaikan saja
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeroCard(),
                const SizedBox(height: 20),
                _buildSectionTitle('Tentang'),
                const SizedBox(height: 10),
                _buildDeskripsiCard(),
                const SizedBox(height: 20),
                _buildSectionTitle('Fitur Utama'),
                const SizedBox(height: 10),
                _buildFiturList(),
                const SizedBox(height: 20),
                _buildSectionTitle('Cara Menggunakan'),
                const SizedBox(height: 10),
                _buildPanduanList(),
                const SizedBox(height: 20),
                _buildSectionTitle('Pengembang'),
                const SizedBox(height: 10),
                _buildPengembangCard(),
                const SizedBox(height: 24),
                _buildFooter(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── APP BAR ──────────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: Color(0xFF111111)),
      ),
      title: const Text(
        'Tentang Aplikasi',
        style: TextStyle(
          fontSize: 16,
          color: Color(0xFF111111),
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
    );
  }

  // ── HERO CARD (identitas app) ───────────────────────────────────────────
  Widget _buildHeroCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.monitor_heart_outlined,
                  size: 28, color: Color(0xFF111111)),
            ),
            const SizedBox(height: 16),
            const Text(
              _appName,
              style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _tagline,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            if (_version.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _version,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── SECTION TITLE ────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF111111),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── DESKRIPSI ─────────────────────────────────────────────────────────────
  Widget _buildDeskripsiCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Text(
          _deskripsi,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  // ── FITUR LIST ────────────────────────────────────────────────────────────
  Widget _buildFiturList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: List.generate(_fitur.length, (i) {
            final isLast = i == _fitur.length - 1;
            final f = _fitur[i];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(f.icon,
                            size: 20, color: const Color(0xFF444444)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.title,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF111111),
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 3),
                            Text(f.subtitle,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                    height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 72,
                    endIndent: 16,
                    color: Colors.grey[200],
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── PANDUAN PENGGUNAAN ───────────────────────────────────────────────────
  Widget _buildPanduanList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _panduan.map((p) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF111111),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    p.nomor,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF111111),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(p.subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── PENGEMBANG / KREDIT ──────────────────────────────────────────────────
  Widget _buildPengembangCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.code_rounded,
                      size: 20, color: Color(0xFF444444)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ganti dengan nama pembuat / tim kamu
                      Text('Dikembangkan oleh',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF888888),
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('Nama Kamu / Tim',
                          style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF111111),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.grey[200]),
            const SizedBox(height: 14),
            _buildKontakRow(
              icon: Icons.email_outlined,
              label: 'kontak@email.com',
              onTap: () => _launchUrl('mailto:kontak@email.com'),
            ),
            const SizedBox(height: 10),
            _buildKontakRow(
              icon: Icons.language_rounded,
              label: 'instagram.com/namamu',
              onTap: () => _launchUrl('https://instagram.com/namamu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKontakRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF888888)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF444444),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── FOOTER ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Center(
      child: Text(
        '© 2026 $_appName. All rights reserved.',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[400],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── DATA MODELS ───────────────────────────────────────────────────────────────
class _FiturData {
  final IconData icon;
  final String title, subtitle;
  const _FiturData(
      {required this.icon, required this.title, required this.subtitle});
}

class _PanduanData {
  final String nomor;
  final String title, subtitle;
  const _PanduanData(
      {required this.nomor, required this.title, required this.subtitle});
}