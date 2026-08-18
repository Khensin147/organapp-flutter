import 'package:flutter/material.dart';
import 'package:organappfr/models/quiz_models.dart';
import 'package:organappfr/service/quiz_service.dart';

class QuizAdminScreen extends StatefulWidget {
  const QuizAdminScreen({super.key});

  @override
  State<QuizAdminScreen> createState() => _QuizAdminScreenState();
}

class _QuizAdminScreenState extends State<QuizAdminScreen> {
  final QuizService _service = QuizService();
  List<QuizKategoriModel> _kategoriList = [];
  Map<String, List<QuizSoalModel>> _soalMap = {}; // kategoriId → list soal
  Set<String> _expandedIds = {}; // kategori yang sedang dibuka
  bool _isLoading = false;

  // Controllers kategori
  final _judulC = TextEditingController();
  final _deskripsiC = TextEditingController();

  // Controllers soal
  final _pertanyaanC = TextEditingController();
  final _aC = TextEditingController();
  final _bC = TextEditingController();
  final _cC = TextEditingController();
  final _dC = TextEditingController();
  String _jawabanBenar = 'A';

  // Warna tema (konsisten dengan layar Siswa)
  static const Color _primaryColor = Color(0xFF0E6E3B);
  static const Color _bgColor = Color(0xFFF5F7F6);
  static const Color _darkText = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _loadKategori();
  }

  @override
  void dispose() {
    _judulC.dispose();
    _deskripsiC.dispose();
    _pertanyaanC.dispose();
    _aC.dispose();
    _bC.dispose();
    _cC.dispose();
    _dC.dispose();
    super.dispose();
  }

  // ── LOAD ──────────────────────────────────────────────

  Future<void> _loadKategori() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getKategori();
      final list = data.map((e) => QuizKategoriModel.fromJson(e)).toList();
      for (final k in list) {
        k.jumlahSoal = await _service.countSoal(k.id);
      }
      setState(() => _kategoriList = list);
    } catch (e) {
      _showSnackbar("Gagal memuat: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSoal(String kategoriId) async {
    try {
      final data = await _service.getSoalByKategori(kategoriId);
      setState(() {
        _soalMap[kategoriId] =
            data.map((e) => QuizSoalModel.fromJson(e)).toList();
      });
    } catch (e) {
      _showSnackbar("Gagal memuat soal: $e", isError: true);
    }
  }

  // ── TOGGLE EXPAND ─────────────────────────────────────

  void _toggleExpand(String kategoriId) {
    setState(() {
      if (_expandedIds.contains(kategoriId)) {
        _expandedIds.remove(kategoriId);
      } else {
        _expandedIds.add(kategoriId);
        // Load soal kalau belum ada
        if (!_soalMap.containsKey(kategoriId)) {
          _loadSoal(kategoriId);
        }
      }
    });
  }

  // ── KATEGORI DIALOG ───────────────────────────────────

  void _showKategoriDialog({QuizKategoriModel? kategori}) {
    final isEdit = kategori != null;
    if (isEdit) {
      _judulC.text = kategori.judul;
      _deskripsiC.text = kategori.deskripsi;
    } else {
      _judulC.clear();
      _deskripsiC.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDragHandle(),
                _buildSheetHeader(
                  icon: Icons.quiz_outlined,
                  title: isEdit ? "Edit Kategori" : "Tambah Kategori",
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _judulC,
                  style: const TextStyle(color: _darkText),
                  decoration: InputDecoration(
                    labelText: "Judul Kategori",
                    prefixIcon: Icon(Icons.quiz_outlined,
                        color: _primaryColor.withOpacity(0.7)),
                    filled: true,
                    fillColor: _primaryColor.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryColor.withOpacity(0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryColor.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deskripsiC,
                  maxLines: 2,
                  style: const TextStyle(color: _darkText),
                  decoration: InputDecoration(
                    labelText: "Deskripsi (opsional)",
                    prefixIcon: Icon(Icons.description_outlined,
                        color: _primaryColor.withOpacity(0.7)),
                    filled: true,
                    fillColor: _primaryColor.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryColor.withOpacity(0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryColor.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _submitKategori(isEdit, kategori),
                  icon: Icon(isEdit ? Icons.save : Icons.add),
                  label: Text(isEdit ? "Simpan" : "Tambah Kategori"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitKategori(
      bool isEdit, QuizKategoriModel? kategori) async {
    if (_judulC.text.trim().isEmpty) {
      _showSnackbar("Judul wajib diisi!", isError: true);
      return;
    }
    Navigator.pop(context);
    setState(() => _isLoading = true);
    try {
      if (isEdit && kategori != null) {
        await _service.editKategori(
          id: kategori.id,
          judul: _judulC.text.trim(),
          deskripsi: _deskripsiC.text.trim(),
        );
        _showSnackbar("Kategori diupdate!");
      } else {
        await _service.tambahKategori(
          judul: _judulC.text.trim(),
          deskripsi: _deskripsiC.text.trim(),
        );
        _showSnackbar("Kategori ditambahkan!");
      }
      _loadKategori();
    } catch (e) {
      _showSnackbar("Gagal: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _hapusKategori(QuizKategoriModel kategori) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Kategori"),
        content: Text(
            "Hapus '${kategori.judul}'? Semua soal di dalamnya ikut terhapus."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Hapus",
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _service.hapusKategori(kategori.id);
        _soalMap.remove(kategori.id);
        _expandedIds.remove(kategori.id);
        _showSnackbar("Kategori dihapus!");
        _loadKategori();
      } catch (e) {
        _showSnackbar("Gagal: $e", isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── SOAL DIALOG ───────────────────────────────────────

  void _showSoalDialog(String kategoriId, {QuizSoalModel? soal}) {
    final isEdit = soal != null;
    if (isEdit) {
      _pertanyaanC.text = soal.pertanyaan;
      _aC.text = soal.pilihanA;
      _bC.text = soal.pilihanB;
      _cC.text = soal.pilihanC;
      _dC.text = soal.pilihanD;
      _jawabanBenar = soal.jawabanBenar;
    } else {
      _pertanyaanC.clear();
      _aC.clear();
      _bC.clear();
      _cC.clear();
      _dC.clear();
      _jawabanBenar = 'A';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    _buildDragHandle(),
                    _buildSheetHeader(
                      icon: Icons.quiz_outlined,
                      title: isEdit ? "Edit Soal" : "Tambah Soal",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.only(
                    left: 16, right: 16, top: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  children: [
                    TextField(
                      controller: _pertanyaanC,
                      maxLines: 3,
                      style: const TextStyle(color: _darkText),
                      decoration: InputDecoration(
                        labelText: "Pertanyaan",
                        prefixIcon: Icon(Icons.help_outline,
                            color: _primaryColor.withOpacity(0.7)),
                        filled: true,
                        fillColor: _primaryColor.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _primaryColor.withOpacity(0.15)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _primaryColor.withOpacity(0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("Pilihan Jawaban",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13, color: _darkText.withOpacity(0.8))),
                    const SizedBox(height: 8),

                    // Pilihan A B C D
                    ...['A', 'B', 'C', 'D'].map((huruf) {
                      final ctrl = huruf == 'A' ? _aC
                          : huruf == 'B' ? _bC
                          : huruf == 'C' ? _cC : _dC;
                      final isSelected = _jawabanBenar == huruf;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: ctrl,
                          style: const TextStyle(color: _darkText),
                          decoration: InputDecoration(
                            labelText: "Pilihan $huruf",
                            filled: true,
                            fillColor: isSelected
                                ? _primaryColor.withOpacity(0.05)
                                : Colors.grey.shade50,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(10),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: isSelected
                                    ? _primaryColor
                                    : Colors.grey.shade300,
                                child: Text(huruf,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black54)),
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isSelected
                                    ? _primaryColor
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isSelected
                                    ? _primaryColor
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Pilih jawaban benar
                    const SizedBox(height: 4),
                    const Text("Jawaban Benar",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: ['A', 'B', 'C', 'D'].map((huruf) {
                        final isSelected = _jawabanBenar == huruf;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(
                                    () => _jawabanBenar = huruf),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _primaryColor
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(huruf,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black54)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _submitSoal(isEdit, kategoriId, soal),
                      icon: Icon(isEdit ? Icons.save : Icons.add),
                      label: Text(
                          isEdit ? "Simpan Perubahan" : "Tambah Soal"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
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

  Future<void> _submitSoal(
      bool isEdit, String kategoriId, QuizSoalModel? soal) async {
    if (_pertanyaanC.text.trim().isEmpty ||
        _aC.text.trim().isEmpty ||
        _bC.text.trim().isEmpty ||
        _cC.text.trim().isEmpty ||
        _dC.text.trim().isEmpty) {
      _showSnackbar("Semua field wajib diisi!", isError: true);
      return;
    }
    Navigator.pop(context);
    try {
      if (isEdit && soal != null) {
        await _service.editSoal(
          id: soal.id,
          pertanyaan: _pertanyaanC.text.trim(),
          pilihanA: _aC.text.trim(),
          pilihanB: _bC.text.trim(),
          pilihanC: _cC.text.trim(),
          pilihanD: _dC.text.trim(),
          jawabanBenar: _jawabanBenar,
        );
        _showSnackbar("Soal diupdate!");
      } else {
        await _service.tambahSoal(
          kategoriId: kategoriId,
          pertanyaan: _pertanyaanC.text.trim(),
          pilihanA: _aC.text.trim(),
          pilihanB: _bC.text.trim(),
          pilihanC: _cC.text.trim(),
          pilihanD: _dC.text.trim(),
          jawabanBenar: _jawabanBenar,
        );
        _showSnackbar("Soal ditambahkan!");
      }
      // Reload soal & update jumlah
      await _loadSoal(kategoriId);
      final idx = _kategoriList.indexWhere((k) => k.id == kategoriId);
      if (idx != -1) {
        _kategoriList[idx].jumlahSoal =
            _soalMap[kategoriId]?.length ?? 0;
        setState(() {});
      }
    } catch (e) {
      _showSnackbar("Gagal: $e", isError: true);
    }
  }

  Future<void> _hapusSoal(String kategoriId, QuizSoalModel soal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Soal"),
        content: const Text("Yakin ingin menghapus soal ini?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Hapus",
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _service.hapusSoal(soal.id);
        _showSnackbar("Soal dihapus!");
        await _loadSoal(kategoriId);
        final idx =
        _kategoriList.indexWhere((k) => k.id == kategoriId);
        if (idx != -1) {
          _kategoriList[idx].jumlahSoal =
              _soalMap[kategoriId]?.length ?? 0;
          setState(() {});
        }
      } catch (e) {
        _showSnackbar("Gagal: $e", isError: true);
      }
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : _primaryColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── HELPER WIDGETS (sheet) ─────────────────────────────

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildSheetHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _darkText,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.close_rounded,
                color: Colors.black.withOpacity(0.5), size: 18),
          ),
        ),
      ],
    );
  }

  // ── BUILD ─────────────────────────────────────────────

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
              "Kelola Quiz",
              style: TextStyle(
                color: _darkText,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              "${_kategoriList.length} kategori",
              style: TextStyle(
                color: Colors.black.withOpacity(0.45),
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      // FIX: FAB dibungkus Padding supaya naik ke atas dan tidak
      // ketutupan navbar bawah. Nilai `bottom: 70` disamakan dengan
      // PertemuanScreen & OrganAdminScreen supaya konsisten di semua tab.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          onPressed: () => _showKategoriDialog(),
          backgroundColor: _primaryColor,
          elevation: 2,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "Tambah Kategori",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : _kategoriList.isEmpty
          ? const Center(
          child: Text("Belum ada kategori quiz.",
              style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
        color: _primaryColor,
        onRefresh: _loadKategori,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: _kategoriList.length,
          itemBuilder: (context, index) {
            final k = _kategoriList[index];
            final nomor =
            (index + 1).toString().padLeft(2, '0');
            final isExpanded = _expandedIds.contains(k.id);
            final soalList = _soalMap[k.id] ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      // ── Header kategori ──
                      InkWell(
                        borderRadius: BorderRadius.vertical(
                          top: const Radius.circular(18),
                          bottom: isExpanded
                              ? Radius.zero
                              : const Radius.circular(18),
                        ),
                        onTap: () => _toggleExpand(k.id),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // Nomor
                              Container(
                                width: 44, height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius:
                                  BorderRadius.circular(14),
                                ),
                                child: Text(nomor,
                                    style: const TextStyle(
                                        color: _primaryColor,
                                        fontSize: 15,
                                        fontWeight:
                                        FontWeight.w800)),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(k.judul,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: _darkText)),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${k.jumlahSoal} soal",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black.withOpacity(0.45)),
                                    ),
                                  ],
                                ),
                              ),
                              // Edit kategori
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () =>
                                    _showKategoriDialog(
                                        kategori: k),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.edit_outlined,
                                      color: _primaryColor, size: 18),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Hapus kategori
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () =>
                                    _hapusKategori(k),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded,
                                      color: Colors.red, size: 18),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Expand icon
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.black.withOpacity(0.35),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Soal list (expand) ──
                      if (isExpanded) ...[
                        const Divider(height: 1),
                        // Tombol tambah soal
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              14, 10, 14, 6),
                          child: Row(
                            children: [
                              Text(
                                "Daftar Soal",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () =>
                                    _showSoalDialog(k.id),
                                icon: const Icon(Icons.add,
                                    size: 16),
                                label:
                                const Text("Tambah Soal"),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                  _primaryColor,
                                  padding: const EdgeInsets
                                      .symmetric(horizontal: 8),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // List soal
                        soalList.isEmpty
                            ? const Padding(
                          padding: EdgeInsets.fromLTRB(
                              14, 0, 14, 14),
                          child: Text(
                            "Belum ada soal. Tambah soal dulu.",
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13),
                          ),
                        )
                            : ListView.separated(
                          shrinkWrap: true,
                          physics:
                          const NeverScrollableScrollPhysics(),
                          padding:
                          const EdgeInsets.fromLTRB(
                              12, 0, 12, 12),
                          itemCount: soalList.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                          itemBuilder: (context, si) {
                            final soal = soalList[si];
                            final nomorSoal = (si + 1)
                                .toString()
                                .padLeft(2, '0');
                            return Container(
                              padding:
                              const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius:
                                BorderRadius.circular(
                                    14),
                                border: Border.all(
                                    color: Colors
                                        .grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  // Nomor soal + aksi
                                  Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration:
                                        BoxDecoration(
                                          color: _primaryColor,
                                          borderRadius:
                                          BorderRadius
                                              .circular(
                                              6),
                                        ),
                                        child: Center(
                                          child: Text(
                                              nomorSoal,
                                              style: const TextStyle(
                                                  color: Colors
                                                      .white,
                                                  fontSize:
                                                  10,
                                                  fontWeight:
                                                  FontWeight
                                                      .bold)),
                                        ),
                                      ),
                                      const SizedBox(
                                          width: 8),
                                      Expanded(
                                        child: Text(
                                          soal.pertanyaan,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                              FontWeight
                                                  .w600),
                                        ),
                                      ),
                                      // Edit soal
                                      IconButton(
                                        onPressed: () =>
                                            _showSoalDialog(
                                                k.id,
                                                soal: soal),
                                        icon: Icon(
                                            Icons.edit_outlined,
                                            color: _primaryColor,
                                            size: 18),
                                        constraints:
                                        const BoxConstraints(),
                                        padding:
                                        const EdgeInsets
                                            .all(4),
                                      ),
                                      // Hapus soal
                                      IconButton(
                                        onPressed: () =>
                                            _hapusSoal(
                                                k.id, soal),
                                        icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                            size: 18),
                                        constraints:
                                        const BoxConstraints(),
                                        padding:
                                        const EdgeInsets
                                            .all(4),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Pilihan A B C D
                                  ...['A','B','C','D']
                                      .asMap()
                                      .entries
                                      .map((e) {
                                    final huruf = e.value;
                                    final pilihan =
                                    soal.pilihan[e.key];
                                    final isBenar =
                                        soal.jawabanBenar ==
                                            huruf;
                                    return Padding(
                                      padding:
                                      const EdgeInsets
                                          .only(
                                          bottom: 3),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration:
                                            BoxDecoration(
                                              color: isBenar
                                                  ? Colors
                                                  .green
                                                  : Colors.grey
                                                  .shade200,
                                              borderRadius:
                                              BorderRadius
                                                  .circular(
                                                  5),
                                            ),
                                            child: Center(
                                              child: Text(
                                                  huruf,
                                                  style: TextStyle(
                                                      fontSize:
                                                      10,
                                                      fontWeight:
                                                      FontWeight
                                                          .bold,
                                                      color: isBenar
                                                          ? Colors
                                                          .white
                                                          : Colors
                                                          .black54)),
                                            ),
                                          ),
                                          const SizedBox(
                                              width: 6),
                                          Expanded(
                                            child: Text(
                                              pilihan,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isBenar
                                                    ? Colors
                                                    .green
                                                    .shade700
                                                    : Colors
                                                    .black87,
                                                fontWeight:
                                                isBenar
                                                    ? FontWeight
                                                    .w600
                                                    : FontWeight
                                                    .normal,
                                              ),
                                            ),
                                          ),
                                          if (isBenar)
                                            const Icon(
                                                Icons
                                                    .check_circle,
                                                color: Colors
                                                    .green,
                                                size: 14),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}