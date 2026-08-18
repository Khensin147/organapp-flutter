import 'package:flutter/material.dart';

import '../../service/guru_service.dart';

/// Daftar siswa yang berada di kelas yang diampu guru yang sedang login.
/// Desain clean/minimal: warna netral, kartu putih dengan sudut membulat,
/// dan siswa ditampilkan dalam bentuk tabel per kelas.
/// Read-only, tidak ada navigasi ke detail nilai.
class SiswaSayaScreen extends StatefulWidget {
  const SiswaSayaScreen({Key? key}) : super(key: key);

  @override
  State<SiswaSayaScreen> createState() => _SiswaSayaScreenState();
}

class _SiswaSayaScreenState extends State<SiswaSayaScreen> {
  // ---- Palet clean/minimal ----
  static const Color _bg = Color(0xFFF5F6F8);
  static const Color _primary = Color(0xFF2F5EFF);
  static const Color _primaryDark = Color(0xFF1E3FCC);
  static const Color _surface = Colors.white;
  static const Color _border = Color(0xFFE4E7EC);
  static const Color _textPrimary = Color(0xFF1D2433);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _headerRowBg = Color(0xFFF9FAFB);

  final GuruService _guruService = GuruService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _guruService.getSiswaSaya();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = _guruService.getSiswaSaya());
  }

  String _initial(String nama) {
    final trimmed = nama.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  /// Mengelompokkan siswa per kelas, diurutkan secara natural
  /// (mis. "7", "8", "9", "10" — bukan urut abjad string).
  Map<String, List<Map<String, dynamic>>> _groupByKelas(
      List<Map<String, dynamic>> siswa) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in siswa) {
      final kelas = (s['kelas']?.toString().trim().isNotEmpty ?? false)
          ? s['kelas'].toString().trim()
          : '-';
      grouped.putIfAbsent(kelas, () => []).add(s);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final na = int.tryParse(a);
        final nb = int.tryParse(b);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.compareTo(b);
      });
    return {for (final k in sortedKeys) k: grouped[k]!};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final hasError = snapshot.hasError;
            final semuaSiswa = snapshot.data ?? [];

            final filteredSiswa = _query.isEmpty
                ? semuaSiswa
                : semuaSiswa.where((s) {
              final nama = (s['nama'] ?? '').toString().toLowerCase();
              return nama.contains(_query);
            }).toList();

            final grouped = _groupByKelas(filteredSiswa);
            final jumlahKelas = _groupByKelas(semuaSiswa).length;

            return Column(
              children: [
                _buildHeader(semuaSiswa.length, jumlahKelas),
                Expanded(
                  child: RefreshIndicator(
                    color: _primary,
                    onRefresh: _refresh,
                    child: isLoading
                        ? const Center(
                        child: CircularProgressIndicator(color: _primary))
                        : hasError
                        ? _buildErrorState('${snapshot.error}')
                        : semuaSiswa.isEmpty
                        ? _buildEmptyState('Belum ada siswa di kelas kamu')
                        : filteredSiswa.isEmpty
                        ? _buildEmptyState('Tidak ada siswa dengan nama itu')
                        : _buildRoster(grouped),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- HEADER ----------------

  Widget _buildHeader(int totalSiswa, int jumlahKelas) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Siswa Saya',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            totalSiswa == 0
                ? 'Belum ada data'
                : '$totalSiswa siswa · $jumlahKelas kelas',
            style: const TextStyle(
              fontSize: 13,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _buildSearchField(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, color: _textSecondary.withOpacity(0.8), size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14, color: _textPrimary),
              cursorColor: _primary,
              decoration: InputDecoration(
                hintText: 'Cari nama siswa',
                hintStyle: TextStyle(
                    color: _textSecondary.withOpacity(0.7), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: _textSecondary, size: 17),
              onPressed: () => _searchController.clear(),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  // ---------------- ROSTER (TABEL) ----------------

  Widget _buildRoster(Map<String, List<Map<String, dynamic>>> grouped) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        for (final entry in grouped.entries) ...[
          _buildKelasLabel(entry.key, entry.value.length),
          const SizedBox(height: 8),
          _buildKelasTable(entry.value),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildKelasLabel(String kelas, int jumlah) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Kelas $kelas',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$jumlah siswa',
            style: const TextStyle(
              fontSize: 12.5,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Tabel siswa: kolom No, Nama.
  Widget _buildKelasTable(List<Map<String, dynamic>> siswaList) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header tabel.
          Container(
            color: _headerRowBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: const [
                SizedBox(
                  width: 32,
                  child: Text(
                    'No',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nama',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Baris data.
          for (int i = 0; i < siswaList.length; i++)
            _buildTableRow(
              nomor: i + 1,
              nama: (siswaList[i]['nama'] ?? '-') as String,
              isEven: i % 2 == 0,
              isLast: i == siswaList.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required int nomor,
    required String nama,
    required bool isEven,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isEven ? _surface : _headerRowBg.withOpacity(0.5),
        border: Border(
          top: BorderSide(
            color: isLast ? Colors.transparent : _border,
            width: 0,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$nomor',
              style: const TextStyle(
                fontSize: 13,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar inisial kecil.
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primary.withOpacity(0.1),
            ),
            child: Text(
              _initial(nama),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _primaryDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              nama,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- EMPTY / ERROR ----------------

  Widget _buildEmptyState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 110),
        Icon(Icons.people_outline, size: 40, color: _textSecondary.withOpacity(0.4)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 110),
        Icon(Icons.error_outline, size: 40, color: Colors.red.withOpacity(0.6)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Text(
                'Gagal memuat siswa',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: _textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}