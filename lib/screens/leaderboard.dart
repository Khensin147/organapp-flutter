import 'package:flutter/material.dart';
import 'package:organappfr/service/quiz_service.dart';

// FIX: Halaman ini sebelumnya adalah leaderboard ranking antar siswa
// (podium top 3, dsb). Sekarang diganti total menjadi halaman personal
// "Nilai Saya" yang menampilkan daftar quiz yang SUDAH DIKERJAKAN oleh
// siswa yang sedang login, per kategori, lengkap dengan skor & predikat.
// Nama class tetap LeaderboardScreen supaya tidak perlu mengubah
// referensi di navbar / MainScreen.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final QuizService _service = QuizService();

  List<Map<String, dynamic>> _hasilList = [];
  bool _isLoading = true;

  static const Color _primaryColor = Color(0xFF0E6E3B);
  static const Color _bgColor = Color(0xFFF5F7F6);
  static const Color _darkText = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _loadNilaiSaya();
  }

  Future<void> _loadNilaiSaya() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getHasilQuizSaya();
      setState(() => _hasilList = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.red,
            content: Text("Gagal memuat nilai: $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _hitungNilai(dynamic skor, dynamic total) {
    final s = (skor as num?)?.toInt() ?? 0;
    final t = (total as num?)?.toInt() ?? 0;
    if (t == 0) return 0;
    return ((s / t) * 100).round();
  }

  Color _warnaNilai(int nilai) {
    if (nilai >= 80) return _primaryColor; // hijau
    if (nilai >= 60) return const Color(0xFFE08A00); // oranye
    return const Color(0xFFD32F2F); // merah
  }

  String _labelNilai(int nilai) {
    if (nilai >= 80) return "Baik";
    if (nilai >= 60) return "Cukup";
    return "Kurang";
  }

  double get _rataRata {
    if (_hasilList.isEmpty) return 0;
    final total = _hasilList.fold<int>(
      0,
          (sum, h) => sum + _hitungNilai(h['skor'], h['total_soal']),
    );
    return total / _hasilList.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Nilai Saya",
              style: TextStyle(
                color: _darkText,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              "${_hasilList.length} quiz sudah dikerjakan",
              style: TextStyle(
                color: Colors.black.withOpacity(0.45),
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: _primaryColor))
          : _hasilList.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        color: _primaryColor,
        onRefresh: _loadNilaiSaya,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildStatsHeader(),
            const SizedBox(height: 16),
            ..._hasilList.map((h) {
              final nilai = _hitungNilai(h['skor'], h['total_soal']);
              return _buildNilaiCard(h, nilai);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded,
              size: 56, color: Colors.black.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text(
            "Belum ada nilai.\nKerjakan quiz dulu, yuk!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  // ── Ringkasan statistik pribadi (jumlah quiz & rata-rata nilai) ──
  Widget _buildStatsHeader() {
    final rataRata = _rataRata;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.fact_check_outlined,
            label: "Quiz Selesai",
            value: "${_hasilList.length}",
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.insights_rounded,
            label: "Rata-rata Nilai",
            value: rataRata.toStringAsFixed(1),
            valueColor: _warnaNilai(rataRata.round()),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _primaryColor.withOpacity(0.7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.45),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor ?? _darkText,
            ),
          ),
        ],
      ),
    );
  }

  // ── Kartu nilai per kategori quiz ──
  Widget _buildNilaiCard(Map<String, dynamic> h, int nilai) {
    final kategori = (h['judul_kategori'] ?? '-').toString();
    final skor = h['skor'] ?? 0;
    final totalSoal = h['total_soal'] ?? 0;
    final warna = _warnaNilai(nilai);

    final createdAt = h['created_at'] != null
        ? DateTime.tryParse(h['created_at'].toString())
        : null;
    final tanggalText = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year}'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ikon kategori
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.quiz_outlined, color: _primaryColor, size: 22),
          ),
          const SizedBox(width: 14),

          // Konten
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kategori,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _darkText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 13, color: Colors.black.withOpacity(0.35)),
                    const SizedBox(width: 4),
                    Text(
                      "$skor/$totalSoal soal benar",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.45),
                      ),
                    ),
                    if (tanggalText != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.calendar_today_outlined,
                          size: 11, color: Colors.black.withOpacity(0.3)),
                      const SizedBox(width: 3),
                      Text(
                        tanggalText,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black.withOpacity(0.35),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Badge nilai
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: warna.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$nilai",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: warna,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _labelNilai(nilai),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: warna.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}