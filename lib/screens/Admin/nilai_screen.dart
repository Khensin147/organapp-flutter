import 'package:flutter/material.dart';
import 'package:organappfr/service/quiz_service.dart';
import 'package:organappfr/service/siswa_services.dart';
import 'package:excel/excel.dart' hide Border; // untuk CellValue, TextCellValue, IntCellValue
import '../../utils/export_excel.dart'; // helper export terpisah

class NilaiScreen extends StatefulWidget {
  const NilaiScreen({super.key});

  @override
  State<NilaiScreen> createState() => _NilaiScreenState();
}

class _NilaiScreenState extends State<NilaiScreen> {
  final QuizService _service = QuizService();
  final SiswaServices _siswaService = SiswaServices();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _hasilList = [];
  bool _isLoading = true;
  String _query = '';

  String? _filterKelas; // null = "Semua Kelas"
  String? _filterKategori; // null = "Semua Materi"
  List<String> _daftarKelas = [];
  List<String> _daftarKategori = [];

  bool _isExporting = false;

  static const Color _primaryColor = Color(0xFF0E6E3B);
  static const Color _bgColor = Color(0xFFF5F7F6);
  static const Color _darkText = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _loadNilai();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNilai() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getHasilQuiz();

      final siswaList = await _siswaService.getSiswa();
      final Map<String, String> emailKeKelas = {
        for (final s in siswaList)
          if (s['email'] != null)
            (s['email'] as String): (s['kelas'] ?? '-').toString(),
      };

      final hasilDenganKelas = data.map((h) {
        final email = (h['siswa_email'] ?? '').toString();
        return {
          ...h,
          'kelas': emailKeKelas[email] ?? '-',
        };
      }).toList();

      final kelasSet = <String>{};
      final kategoriSet = <String>{};
      for (final h in hasilDenganKelas) {
        final kelas = (h['kelas'] ?? '-').toString();
        final kategori = (h['judul_kategori'] ?? '-').toString();
        if (kelas.isNotEmpty) kelasSet.add(kelas);
        if (kategori.isNotEmpty) kategoriSet.add(kategori);
      }

      setState(() {
        _hasilList = List<Map<String, dynamic>>.from(hasilDenganKelas);
        _daftarKelas = kelasSet.toList()..sort();
        _daftarKategori = kategoriSet.toList()..sort();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    if (nilai >= 80) return const Color(0xFF0E6E3B);
    if (nilai >= 60) return const Color(0xFFE08A00);
    return const Color(0xFFD32F2F);
  }

  String _labelNilai(int nilai) {
    if (nilai >= 80) return "Baik";
    if (nilai >= 60) return "Cukup";
    return "Kurang";
  }

  List<Map<String, dynamic>> get _filteredList {
    return _hasilList.where((h) {
      final nama = (h['nama_siswa'] ?? '').toString().toLowerCase();
      final kategori = (h['judul_kategori'] ?? '').toString();
      final kelas = (h['kelas'] ?? '').toString();

      final cocokQuery = _query.isEmpty ||
          nama.contains(_query) ||
          kategori.toLowerCase().contains(_query);
      final cocokKelas = _filterKelas == null || kelas == _filterKelas;
      final cocokKategori =
          _filterKategori == null || kategori == _filterKategori;

      return cocokQuery && cocokKelas && cocokKategori;
    }).toList();
  }

  double get _rataRata {
    final list = _filteredList;
    if (list.isEmpty) return 0;
    final total = list.fold<int>(
      0,
          (sum, h) => sum + _hitungNilai(h['skor'], h['total_soal']),
    );
    return total / list.length;
  }

  // ── Export data nilai (mengikuti filter aktif) ke Excel ──
  // Screen ini HANYA menyiapkan data (rows), semua logika pembuatan
  // file Excel & share ada di ExportExcelHelper (utils/export_excel.dart)
  Future<void> _exportKeExcel() async {
    final data = _filteredList;

    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.orange,
          content: const Text("Tidak ada data untuk diekspor"),
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final rows = <List<CellValue>>[];
      for (var i = 0; i < data.length; i++) {
        final h = data[i];
        final nilai = _hitungNilai(h['skor'], h['total_soal']);
        final createdAt = h['created_at'] != null
            ? DateTime.tryParse(h['created_at'].toString())
            : null;
        final tanggalText = createdAt != null
            ? '${createdAt.day.toString().padLeft(2, '0')}/'
            '${createdAt.month.toString().padLeft(2, '0')}/'
            '${createdAt.year}'
            : '-';

        rows.add([
          IntCellValue(i + 1),
          TextCellValue((h['nama_siswa'] ?? '-').toString()),
          TextCellValue((h['kelas'] ?? '-').toString()),
          TextCellValue((h['judul_kategori'] ?? '-').toString()),
          IntCellValue((h['skor'] as num?)?.toInt() ?? 0),
          IntCellValue((h['total_soal'] as num?)?.toInt() ?? 0),
          IntCellValue(nilai),
          TextCellValue(_labelNilai(nilai)),
          TextCellValue(tanggalText),
        ]);
      }

      await ExportExcelHelper.exportToExcel(
        sheetName: 'Data Nilai',
        headers: const [
          'No',
          'Nama Siswa',
          'Kelas',
          'Materi/Kategori',
          'Skor Benar',
          'Total Soal',
          'Nilai (0-100)',
          'Predikat',
          'Tanggal',
        ],
        rows: rows,
        fileNamePrefix: 'Data_Nilai',
        shareText: 'Data Nilai Organku',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.red,
            content: Text("Gagal mengekspor: $e"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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
              "Data Nilai",
              style: TextStyle(
                color: _darkText,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              "${_hasilList.length} hasil quiz tercatat",
              style: TextStyle(
                color: Colors.black.withOpacity(0.45),
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (_hasilList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _isExporting
                  ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _primaryColor,
                  ),
                ),
              )
                  : IconButton(
                tooltip: "Export ke Excel",
                onPressed: _exportKeExcel,
                icon: const Icon(Icons.file_download_outlined,
                    color: _primaryColor),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: _primaryColor))
          : _hasilList.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          _buildStatsHeader(),
          _buildSearchField(),
          _buildFilterRow(),
          Expanded(
            child: _filteredList.isEmpty
                ? _buildNoResult()
                : RefreshIndicator(
              color: _primaryColor,
              onRefresh: _loadNilai,
              child: ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _filteredList.length,
                itemBuilder: (context, index) {
                  final h = _filteredList[index];
                  final nilai = _hitungNilai(
                      h['skor'], h['total_soal']);
                  return _buildNilaiCard(h, nilai);
                },
              ),
            ),
          ),
        ],
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
            "Belum ada nilai.",
            style: TextStyle(color: Colors.black.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResult() {
    final adaFilterAktif = _filterKelas != null || _filterKategori != null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: Colors.black.withOpacity(0.2)),
          const SizedBox(height: 10),
          Text(
            _query.isNotEmpty
                ? "Tidak ada hasil untuk \"$_query\""
                : adaFilterAktif
                ? "Tidak ada data untuk filter ini"
                : "Tidak ada data",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black.withOpacity(0.4)),
          ),
          if (adaFilterAktif) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(() {
                _filterKelas = null;
                _filterKategori = null;
              }),
              child: const Text("Hapus semua filter",
                  style: TextStyle(color: _primaryColor)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final rataRata = _rataRata;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.groups_rounded,
              label: "Total Peserta",
              value: "${_filteredList.length}",
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
      ),
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

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14, color: _darkText),
        decoration: InputDecoration(
          hintText: "Cari nama siswa atau kategori...",
          hintStyle:
          TextStyle(color: Colors.black.withOpacity(0.35), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded,
              color: _primaryColor.withOpacity(0.7), size: 20),
          suffixIcon: _query.isNotEmpty
              ? InkWell(
            onTap: () => _searchController.clear(),
            child: Icon(Icons.close_rounded,
                color: Colors.black.withOpacity(0.4), size: 18),
          )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryColor, width: 1.5),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterDropdown(
              hint: "Semua Kelas",
              icon: Icons.school_outlined,
              value: _filterKelas,
              items: _daftarKelas,
              onChanged: (val) => setState(() => _filterKelas = val),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFilterDropdown(
              hint: "Semua Materi",
              icon: Icons.menu_book_outlined,
              value: _filterKategori,
              items: _daftarKategori,
              onChanged: (val) => setState(() => _filterKategori = val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.black.withOpacity(0.4), size: 20),
          hint: Row(
            children: [
              Icon(icon, size: 16, color: _primaryColor.withOpacity(0.6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hint,
                  style: TextStyle(
                      fontSize: 12.5, color: Colors.black.withOpacity(0.5)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          selectedItemBuilder: (context) => [
            Row(
              children: [
                Icon(icon, size: 16, color: _primaryColor.withOpacity(0.6)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hint,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _darkText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            ...items.map(
                  (item) => Row(
                children: [
                  Icon(icon, size: 16, color: _primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _darkText),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(hint,
                  style: TextStyle(
                      fontSize: 13, color: Colors.black.withOpacity(0.6))),
            ),
            ...items.map(
                  (item) => DropdownMenuItem<String?>(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildNilaiCard(Map<String, dynamic> h, int nilai) {
    final nama = (h['nama_siswa'] ?? '-').toString();
    final kategori = (h['judul_kategori'] ?? '-').toString();
    final kelas = (h['kelas'] ?? '-').toString();
    final skor = h['skor'] ?? 0;
    final totalSoal = h['total_soal'] ?? 0;
    final warna = _warnaNilai(nilai);
    final initial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';

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
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nama,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _darkText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (kelas != '-')
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          kelas,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  kategori,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.55),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.quiz_outlined,
                        size: 13, color: Colors.black.withOpacity(0.35)),
                    const SizedBox(width: 4),
                    Text(
                      "$skor/$totalSoal soal benar",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
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