import 'package:flutter/material.dart';

import '../../service/guru_service.dart';
import 'package:excel/excel.dart' hide Border; // untuk CellValue, TextCellValue, IntCellValue
import '../../utils/export_excel.dart'; // helper export terpisah
import 'nilaidetailguru.dart';

/// Bundel data yang dibutuhkan halaman ini dalam satu future: daftar
/// siswa (untuk tahu kelas masing-masing siswa & isi dropdown filter
/// kelas) dan daftar nilai mentah (per-quiz, untuk isi dropdown filter
/// kategori quiz + bahan grouping per siswa).
class _GuruDataBundle {
  final List<Map<String, dynamic>> siswa;
  final List<Map<String, dynamic>> nilai;

  _GuruDataBundle({required this.siswa, required this.nilai});
}

/// Daftar siswa (ringkas: nama + ringkasan nilai) di kelas yang diampu
/// guru ini. Bisa difilter berdasarkan kelas dan kategori quiz yang
/// dikerjakan. Tap salah satu siswa -> lihat detail semua quiz yang
/// sudah dikerjakan siswa tsb.
class NilaiSiswaScreen extends StatefulWidget {
  const NilaiSiswaScreen({Key? key}) : super(key: key);

  @override
  State<NilaiSiswaScreen> createState() => _NilaiSiswaScreenState();
}

class _NilaiSiswaScreenState extends State<NilaiSiswaScreen> {
  static const Color _primaryColor = Color(0xFF1B3F9E);
  static const Color _filterBg = Color(0xFFF5F7F6);
  final GuruService _guruService = GuruService();

  late Future<_GuruDataBundle> _future;
  bool _isExporting = false; // status loading tombol export

  // Filter aktif. null artinya "Semua".
  String? _selectedKelas;
  String? _selectedKuis;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_GuruDataBundle> _loadData() async {
    final hasil = await Future.wait([
      _guruService.getSiswaSaya(),
      _guruService.getNilaiSiswaSaya(),
    ]);
    return _GuruDataBundle(
      siswa: hasil[0],
      nilai: hasil[1],
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadData());
  }

  /// Kelompokkan data mentah (per-quiz) menjadi ringkasan per-siswa.
  /// Key grouping pakai `nama_siswa`. Kalau ada field id siswa di data
  /// (misal `siswa_id`), lebih baik pakai itu sebagai key supaya tidak
  /// tertukar antar siswa yang kebetulan namanya sama.
  List<Map<String, dynamic>> _groupBySiswa(List<Map<String, dynamic>> raw) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final row in raw) {
      final nama = (row['nama_siswa'] ?? '-') as String;
      grouped.putIfAbsent(nama, () => []).add(row);
    }

    return grouped.entries.map((entry) {
      final nama = entry.key;
      final quizList = entry.value;

      final totalSkor = quizList.fold<int>(
        0,
            (sum, q) => sum + ((q['skor'] as num?)?.toInt() ?? 0),
      );
      final totalSoalSemua = quizList.fold<int>(
        0,
            (sum, q) => sum + ((q['total_soal'] as num?)?.toInt() ?? 0),
      );
      final jumlahQuiz = quizList.length;
      final rataRata = totalSoalSemua > 0
          ? (totalSkor / totalSoalSemua * 100).round()
          : 0;

      // Ambil email dari salah satu baris quiz siswa ini, dipakai
      // untuk mencocokkan kelas siswa (lihat _applyFilters).
      final email = (quizList.first['siswa_email'] as String?) ?? '';

      return {
        'nama_siswa': nama,
        'siswa_email': email,
        'jumlah_quiz': jumlahQuiz,
        'rata_rata': rataRata,
        'quiz_list': quizList, // dibawa ke halaman detail
      };
    }).toList()
      ..sort((a, b) =>
          (a['nama_siswa'] as String).compareTo(b['nama_siswa'] as String));
  }

  /// Terapkan filter kelas & kategori quiz yang sedang aktif ke bundel
  /// data, dan kembalikan ringkasan per-siswa yang sudah difilter +
  /// sudah dilampiri field 'kelas'. Dipakai baik oleh tampilan list
  /// maupun oleh export Excel, supaya keduanya selalu konsisten.
  List<Map<String, dynamic>> _applyFilters(_GuruDataBundle data) {
    // Peta email (lowercase) -> kelas, dari daftar siswa guru ini.
    final kelasByEmail = <String, String>{};
    for (final s in data.siswa) {
      final email = (s['email'] as String?)?.trim().toLowerCase();
      final kelas = (s['kelas'] as String?)?.trim() ?? '';
      if (email != null && email.isNotEmpty) {
        kelasByEmail[email] = kelas;
      }
    }

    // 1. Filter data mentah berdasarkan kategori quiz dulu (kalau ada).
    var rawNilai = data.nilai;
    if (_selectedKuis != null) {
      rawNilai = rawNilai
          .where((r) =>
      (r['judul_kategori'] ?? '-').toString() == _selectedKuis)
          .toList();
    }

    // 2. Kelompokkan per siswa dari data yang sudah difilter kategori.
    final siswaList = _groupBySiswa(rawNilai);

    // 3. Lampirkan kelas ke tiap siswa, lalu filter berdasarkan kelas
    //    (kalau ada) menggunakan field itu.
    for (final s in siswaList) {
      final email = (s['siswa_email'] as String?)?.trim().toLowerCase();
      s['kelas'] =
      (email != null && kelasByEmail.containsKey(email))
          ? kelasByEmail[email]
          : '-';
    }

    if (_selectedKelas != null) {
      return siswaList.where((s) => s['kelas'] == _selectedKelas).toList();
    }
    return siswaList;
  }

  List<String> _kelasOptions(_GuruDataBundle data) {
    final set = data.siswa
        .map((s) => (s['kelas'] as String?)?.trim() ?? '')
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList();
    set.sort();
    return set;
  }

  List<String> _kuisOptions(_GuruDataBundle data) {
    final set = data.nilai
        .map((n) => (n['judul_kategori'] ?? '-').toString())
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList();
    set.sort();
    return set;
  }

  // ── Export ringkasan nilai (yang sedang tampil, sesuai filter) ke Excel ──
  Future<void> _exportKeExcel() async {
    _GuruDataBundle data;
    try {
      data = await _future;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.red,
            content: Text("Gagal memuat data: $e"),
          ),
        );
      }
      return;
    }

    final siswaList = _applyFilters(data);

    if (siswaList.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.orange,
            content: const Text("Tidak ada data untuk diekspor"),
          ),
        );
      }
      return;
    }

    setState(() => _isExporting = true);
    try {
      final rows = <List<CellValue>>[];
      for (var i = 0; i < siswaList.length; i++) {
        final s = siswaList[i];
        final quizList =
            (s['quiz_list'] as List<Map<String, dynamic>>?) ?? const [];
        final kategoriUnik = quizList
            .map((q) => (q['judul_kategori'] ?? '-').toString())
            .toSet() // hilangkan duplikat kalau siswa ngerjain kategori sama > 1x
            .join(', ');

        rows.add([
          IntCellValue(i + 1),
          TextCellValue((s['nama_siswa'] ?? '-').toString()),
          TextCellValue((s['kelas'] ?? '-').toString()),
          TextCellValue(kategoriUnik.isEmpty ? '-' : kategoriUnik),
          IntCellValue((s['rata_rata'] as int?) ?? 0),
        ]);
      }

      await ExportExcelHelper.exportToExcel(
        sheetName: 'Ringkasan Nilai Siswa',
        headers: const [
          'No',
          'Nama Siswa',
          'Kelas',
          'Kategori Quiz',
          'Rata-rata'
        ],
        rows: rows,
        fileNamePrefix: 'Ringkasan_Nilai_Siswa',
        shareText: 'Ringkasan Nilai Siswa',
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

  Widget _buildExportHeader() {
    return Container(
      color: Colors.white, // pastikan background selalu putih agar teks kontras
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Daftar Siswa",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF1A1A1A),
            ),
          ),
          _isExporting
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _primaryColor,
            ),
          )
              : IconButton(
            tooltip: "Export ke Excel",
            onPressed: _exportKeExcel,
            icon: const Icon(Icons.file_download_outlined,
                color: _primaryColor),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  /// Baris 2 dropdown filter: kelas & kategori quiz.
  Widget _buildFilterRow(_GuruDataBundle data) {
    final kelasOptions = _kelasOptions(data);
    final kuisOptions = _kuisOptions(data);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterDropdown(
              label: "Kelas",
              value: _selectedKelas,
              options: kelasOptions,
              onChanged: (v) => setState(() => _selectedKelas = v),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildFilterDropdown(
              label: "Quiz",
              value: _selectedKuis,
              options: kuisOptions,
              onChanged: (v) => setState(() => _selectedKuis = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: _filterBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: Colors.black.withOpacity(0.4)),
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                "Semua $label",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.black.withOpacity(0.55)),
              ),
            ),
            ...options.map(
                  (o) => DropdownMenuItem<String?>(
                value: o,
                child: Text(o, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // background eksplisit agar tidak tergantung parent
      child: Column(
        children: [
          _buildExportHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<_GuruDataBundle>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Gagal memuat nilai: ${snapshot.error}'));
                  }

                  final data =
                      snapshot.data ?? _GuruDataBundle(siswa: [], nilai: []);

                  if (data.nilai.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(
                            child:
                            Text('Belum ada siswa yang mengerjakan quiz')),
                      ],
                    );
                  }

                  final siswaList = _applyFilters(data);

                  return Column(
                    children: [
                      _buildFilterRow(data),
                      Expanded(
                        child: siswaList.isEmpty
                            ? ListView(
                          physics:
                          const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 100),
                            Center(
                                child: Text(
                                    'Tidak ada siswa yang cocok dengan filter ini')),
                          ],
                        )
                            : ListView.separated(
                          physics:
                          const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                              16, 0, 16, 16),
                          itemCount: siswaList.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final s = siswaList[i];
                            final rataRata = s['rata_rata'] as int;
                            final jumlahQuiz = s['jumlah_quiz'] as int;
                            final namaSiswa = s['nama_siswa'] as String;
                            final kelasSiswa =
                            (s['kelas'] ?? '-') as String;
                            final quizList = s['quiz_list']
                            as List<Map<String, dynamic>>;

                            return Card(
                              elevation: 0,
                              color: const Color(0xFFE7ECFB)
                                  .withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _primaryColor,
                                  child: Text(
                                    '$rataRata',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  namaSiswa,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  'Kelas $kelasSiswa • Rata-rata $rataRata • $jumlahQuiz quiz dikerjakan',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          NilaiSiswaDetailScreen(
                                            namaSiswa: namaSiswa,
                                            kelas: kelasSiswa,
                                            quizList: quizList,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}