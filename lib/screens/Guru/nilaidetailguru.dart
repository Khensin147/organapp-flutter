import 'package:flutter/material.dart';
import '../../service/guru_service.dart';
import 'package:excel/excel.dart' hide Border; // untuk CellValue, TextCellValue, IntCellValue
import '../../utils/export_excel.dart'; // helper export terpisah

/// Detail semua quiz yang sudah dikerjakan oleh satu siswa tertentu.
///
/// Bisa dipakai dengan 2 cara:
/// 1. Dari NilaiSiswaScreen -> kirim `quizList` (+ opsional `kelas`)
///    langsung (data sudah ada di memori, tidak perlu fetch ulang).
/// 2. Dari SiswaSayaScreen  -> `quizList` tidak dikirim (null), jadi
///    halaman ini yang fetch sendiri data nilai siswa tsb via
///    GuruService, lalu filter berdasarkan nama.
class NilaiSiswaDetailScreen extends StatefulWidget {
  final String namaSiswa;
  final String? emailSiswa;
  final String? kelas;
  final List<Map<String, dynamic>>? quizList;

  const NilaiSiswaDetailScreen({
    Key? key,
    required this.namaSiswa,
    this.emailSiswa,
    this.kelas,
    this.quizList,
  }) : super(key: key);

  @override
  State<NilaiSiswaDetailScreen> createState() =>
      _NilaiSiswaDetailScreenState();
}

class _NilaiSiswaDetailScreenState extends State<NilaiSiswaDetailScreen> {
  static const Color _primaryColor = Color(0xFF1B3F9E);
  static const Color _hijau = Color(0xFF16A34A); // performa bagus (>=80%)
  static const Color _kuning = Color(0xFFCA8A04); // performa sedang (60-79%)
  static const Color _merah = Color(0xFFDC2626); // performa kurang (<60%)

  final GuruService _guruService = GuruService();

  late Future<List<Map<String, dynamic>>> _future;
  bool _isExporting = false; // status loading tombol export

  @override
  void initState() {
    super.initState();
    if (widget.quizList != null) {
      // Data sudah dikirim dari halaman sebelumnya, tidak perlu fetch.
      _future = Future.value(widget.quizList!);
    } else {
      // Belum ada data -> fetch semua nilai lalu filter untuk siswa ini.
      _future = _fetchQuizUntukSiswaIni();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchQuizUntukSiswaIni() async {
    final semuaNilai = await _guruService.getNilaiSiswaSaya();
    return semuaNilai
        .where((n) => (n['nama_siswa'] ?? '') == widget.namaSiswa)
        .toList();
  }

  Future<void> _refresh() async {
    if (widget.quizList != null) return; // data statis, tidak perlu refresh
    setState(() => _future = _fetchQuizUntukSiswaIni());
  }

  Color _colorForPersen(int persen) {
    if (persen >= 80) return _hijau;
    if (persen >= 60) return _kuning;
    return _merah;
  }

  String _formatTanggal(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    final local = dt.toLocal();
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${bulan[local.month - 1]} ${local.year}, $hh:$mm';
  }

  /// Siapkan data untuk ditampilkan:
  /// - Urutkan dari yang PALING BARU dikerjakan.
  /// - Kalau siswa mengerjakan kategori quiz yang sama lebih dari
  ///   sekali, tandai tiap baris dengan nomor percobaan (mis.
  ///   "Percobaan 1/2", "Percobaan 2/2") supaya progres pengulangan
  ///   kelihatan, bukan cuma daftar datar.
  /// Bekerja di atas SALINAN map (bukan referensi asli) supaya tidak
  /// mengubah data yang mungkin masih dipakai halaman sebelumnya.
  List<Map<String, dynamic>> _prepareQuizList(
      List<Map<String, dynamic>> raw) {
    final list = raw.map((e) => Map<String, dynamic>.from(e)).toList();

    list.sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da); // terbaru dulu
    });

    // Total percobaan per kategori.
    final totalPerKategori = <String, int>{};
    for (final q in list) {
      final kat = (q['judul_kategori'] ?? '-').toString();
      totalPerKategori[kat] = (totalPerKategori[kat] ?? 0) + 1;
    }

    // Nomor percobaan dihitung dari yang PALING LAMA (percobaan 1),
    // jadi iterasi dari belakang (list saat ini terurut terbaru dulu).
    final counterPerKategori = <String, int>{};
    for (final q in list.reversed) {
      final kat = (q['judul_kategori'] ?? '-').toString();
      counterPerKategori[kat] = (counterPerKategori[kat] ?? 0) + 1;
      q['_attempt_number'] = counterPerKategori[kat];
      q['_attempt_total'] = totalPerKategori[kat];
    }

    return list;
  }

  // ── Export nilai siswa ini ke Excel ──
  Future<void> _exportKeExcel() async {
    final rawData = await _future;
    final data = _prepareQuizList(rawData);

    if (data.isEmpty) {
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
      for (var i = 0; i < data.length; i++) {
        final n = data[i];
        final skor = (n['skor'] as num?)?.toInt() ?? 0;
        final total = (n['total_soal'] as num?)?.toInt() ?? 0;
        final attemptNumber = n['_attempt_number'] as int? ?? 1;
        final attemptTotal = n['_attempt_total'] as int? ?? 1;

        rows.add([
          IntCellValue(i + 1),
          TextCellValue(n['judul_kategori']?.toString() ?? '-'),
          IntCellValue(skor),
          IntCellValue(total),
          TextCellValue('$attemptNumber/$attemptTotal'),
          TextCellValue(_formatTanggal(n['created_at']?.toString())),
        ]);
      }

      await ExportExcelHelper.exportToExcel(
        sheetName: 'Nilai',
        headers: const [
          'No',
          'Kategori/Judul',
          'Skor',
          'Total Soal',
          'Percobaan Ke',
          'Tanggal Dikerjakan'
        ],
        rows: rows,
        fileNamePrefix: 'Nilai_${widget.namaSiswa}',
        shareText: 'Nilai quiz ${widget.namaSiswa}',
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

  /// Kartu ringkasan di atas daftar: rata-rata keseluruhan + jumlah
  /// quiz yang sudah dikerjakan siswa ini + berapa kali siswa
  /// mengulang pengerjaan quiz (kategori yang dikerjakan >1x),
  /// supaya guru langsung tahu gambaran besar tanpa harus scroll &
  /// hitung manual.
  Widget _buildSummaryHeader(List<Map<String, dynamic>> quizList) {
    final totalSkor = quizList.fold<int>(
      0,
          (s, q) => s + ((q['skor'] as num?)?.toInt() ?? 0),
    );
    final totalSoal = quizList.fold<int>(
      0,
          (s, q) => s + ((q['total_soal'] as num?)?.toInt() ?? 0),
    );
    final rataRata = totalSoal > 0 ? (totalSkor / totalSoal * 100).round() : 0;

    // Jumlah kategori quiz yang berbeda yang pernah dikerjakan.
    final kategoriUnik = quizList
        .map((q) => (q['judul_kategori'] ?? '-').toString())
        .toSet();

    // Jumlah kategori yang diulang (dikerjakan lebih dari 1x).
    final kategoriDiulang = kategoriUnik.where((kat) {
      final jumlah =
          quizList.where((q) => (q['judul_kategori'] ?? '-') == kat).length;
      return jumlah > 1;
    }).length;

    // Total pengulangan = total quiz dikerjakan - jumlah kategori unik.
    // (mis. Matematika 3x + IPA 1x = 4 quiz, 2 kategori unik -> 2 kali ulang)
    final totalPengulangan = quizList.length - kategoriUnik.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rataRata%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.kelas != null && widget.kelas!.isNotEmpty) ...[
                  Text(
                    'Kelas ${widget.kelas}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  '${quizList.length} quiz dikerjakan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rata-rata keseluruhan $rataRata%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Baris baru: ringkasan jumlah pengulangan quiz.
                if (totalPengulangan > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.replay_rounded,
                          size: 12, color: Colors.white.withOpacity(0.85)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Mengulang $totalPengulangan kali di $kategoriDiulang kategori',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCard(Map<String, dynamic> n) {
    final skor = (n['skor'] as num?)?.toInt() ?? 0;
    final total = (n['total_soal'] as num?)?.toInt() ?? 0;
    final persen = total > 0 ? (skor / total * 100).round() : 0;
    final warna = _colorForPersen(persen);
    final tanggal = _formatTanggal(n['created_at']?.toString());
    final attemptNumber = n['_attempt_number'] as int? ?? 1;
    final attemptTotal = n['_attempt_total'] as int? ?? 1;

    return Card(
      elevation: 0,
      color: const Color(0xFFE7ECFB).withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge persentase berwarna sesuai performa: hijau (>=80%),
            // kuning (60-79%), merah (<60%) — supaya guru bisa scan
            // cepat siapa yang perlu perhatian.
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
              child: Text(
                '$persen%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n['judul_kategori']?.toString() ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      // Kalau kategori ini dikerjakan lebih dari 1x,
                      // tandai sebagai percobaan ke berapa dari berapa.
                      if (attemptTotal > 1)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Percobaan $attemptNumber/$attemptTotal',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Skor $skor dari $total soal',
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.black.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 12, color: Colors.black.withOpacity(0.35)),
                      const SizedBox(width: 4),
                      Text(
                        tanggal,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.black.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white, // pastikan icon & title default putih
        title: Text(
          widget.namaSiswa,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          _isExporting
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            ),
          )
              : IconButton(
            tooltip: "Export ke Excel",
            onPressed: _exportKeExcel,
            icon: const Icon(Icons.file_download_outlined,
                color: Colors.white),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7F6),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                  child: Text('Gagal memuat nilai: ${snapshot.error}'));
            }

            final quizList = _prepareQuizList(snapshot.data ?? []);

            if (quizList.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 90),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.quiz_outlined,
                            size: 44, color: Colors.black.withOpacity(0.2)),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada quiz yang dikerjakan',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _buildSummaryHeader(quizList),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    children: [
                      for (final n in quizList) ...[
                        _buildQuizCard(n),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}