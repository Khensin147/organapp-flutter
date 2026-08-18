import 'package:flutter/material.dart';
import 'package:organappfr/service/pertemuan_service.dart';
import '../../models/pertemuan_model.dart';

class PertemuanScreen extends StatefulWidget {
  const PertemuanScreen({super.key});

  @override
  State<PertemuanScreen> createState() => _PertemuanScreenState();
}

class _PertemuanScreenState extends State<PertemuanScreen> {
  final PertemuanService _service = PertemuanService();

  List<PertemuanModel> _pertemuanList = [];
  bool _isLoading = false;
  final Set<int> _expandedIds = {};
  int? _editingId; // null = mode tambah, ada isinya = mode edit

  // Controller untuk form
  final _namaController = TextEditingController();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _mingguController = TextEditingController();

  // Warna tema
  static const Color _primaryColor = Color(0xFF0E6E3B);
  static const Color _bgColor = Color(0xFFF5F7F6);
  static const Color _darkText = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _loadPertemuan();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _judulController.dispose();
    _deskripsiController.dispose();
    _mingguController.dispose();
    super.dispose();
  }

  // Load data dari Supabase
  Future<void> _loadPertemuan() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getPertemuan();
      setState(() {
        _pertemuanList = data.map((e) => PertemuanModel.fromJson(e)).toList();
      });
    } catch (e) {
      _showSnackbar("Gagal memuat data: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Hapus pertemuan
  Future<void> _deletePertemuan(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("Hapus Pertemuan"),
        content: const Text("Yakin ingin menghapus pertemuan ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Batal",
                style: TextStyle(color: Colors.black.withOpacity(0.6))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deletePertemuan(id);
        _showSnackbar("Pertemuan berhasil dihapus");
        _loadPertemuan();
      } catch (e) {
        _showSnackbar("Gagal menghapus: $e", isError: true);
      }
    }
  }

  // Tampilkan bottom sheet form (tambah ATAU edit, tergantung parameter `item`)
  void _showFormDialog({PertemuanModel? item}) {
    final bool isEdit = item != null;
    _editingId = item?.id;

    _namaController.text = item?.namaPertemuan ?? '';
    _judulController.text = item?.judul ?? '';
    _deskripsiController.text = item?.deskripsi ?? '';
    _mingguController.text = item != null ? '${item.minggu}' : '';

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ──
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                        isEdit
                            ? Icons.edit_note_rounded
                            : Icons.event_note_rounded,
                        color: _primaryColor,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? "Edit Pertemuan" : "Tambah Pertemuan",
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
              ),
              const SizedBox(height: 20),

              _buildLabel("Nama Pertemuan"),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _namaController,
                hint: "Contoh: Pertemuan 1",
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 14),

              _buildLabel("Judul"),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _judulController,
                hint: "Judul materi",
                icon: Icons.title_rounded,
              ),
              const SizedBox(height: 14),

              _buildLabel("Deskripsi"),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _deskripsiController,
                hint: "Deskripsi singkat pertemuan",
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 14),

              _buildLabel("Minggu ke-"),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _mingguController,
                hint: "Contoh: 1",
                icon: Icons.calendar_today_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitPertemuan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEdit ? "Simpan Perubahan" : "Simpan",
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => _editingId = null);
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _darkText,
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: _darkText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        TextStyle(color: Colors.black.withOpacity(0.35), fontSize: 14),
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines > 1 ? 40 : 0),
          child: Icon(icon, color: _primaryColor.withOpacity(0.7), size: 20),
        ),
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
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // Submit form: insert kalau _editingId null, update kalau ada isinya
  Future<void> _submitPertemuan() async {
    final nama = _namaController.text.trim();
    final judul = _judulController.text.trim();
    final deskripsi = _deskripsiController.text.trim();
    final minggu = int.tryParse(_mingguController.text.trim());

    if (nama.isEmpty || judul.isEmpty || minggu == null) {
      _showSnackbar("Nama, judul, dan minggu wajib diisi!", isError: true);
      return;
    }

    final editingId = _editingId;
    Navigator.pop(context); // tutup bottom sheet

    try {
      if (editingId != null) {
        // ── MODE EDIT ──
        await _service.updatePertemuan(
          id: editingId,
          namaPertemuan: nama,
          judul: judul,
          deskripsi: deskripsi,
          minggu: minggu,
        );
        _showSnackbar("Pertemuan berhasil diperbarui!");
      } else {
        // ── MODE TAMBAH ──
        await _service.insertPertemuan(
          namaPertemuan: nama,
          judul: judul,
          deskripsi: deskripsi,
          minggu: minggu,
        );
        _showSnackbar("Pertemuan berhasil ditambahkan!");
      }
      _loadPertemuan();
    } catch (e) {
      _showSnackbar("Gagal menyimpan: $e", isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(message),
        backgroundColor: isError ? Colors.red : _primaryColor,
      ),
    );
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
              "Kelola Pertemuan",
              style: TextStyle(
                color: _darkText,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              "${_pertemuanList.length} pertemuan terjadwal",
              style: TextStyle(
                color: Colors.black.withOpacity(0.45),
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),

      // FIX #1: sebelumnya memanggil `_showAddDialog` yang tidak pernah
      // didefinisikan di class ini (compile error). Sekarang memanggil
      // `_showFormDialog()` tanpa parameter `item` -> otomatis mode "Tambah".
      //
      // FIX #2: FAB dibungkus Padding supaya naik ke atas dan tidak
      // ketutupan navbar bawah. Sesuaikan nilai `bottom` dengan tinggi
      // navbar kamu (contoh: 70).
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          onPressed: () => _showFormDialog(),
          backgroundColor: _primaryColor,
          elevation: 2,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "Tambah",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),

      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: _primaryColor))
          : _pertemuanList.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded,
                size: 56, color: Colors.black.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text(
              "Belum ada pertemuan.\nTambah dengan tombol +",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black.withOpacity(0.4)),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        color: _primaryColor,
        onRefresh: _loadPertemuan,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: _pertemuanList.length,
          itemBuilder: (context, index) {
            final item = _pertemuanList[index];
            final isExpanded = _expandedIds.contains(item.id);
            final hasDeskripsi = item.deskripsi.trim().isNotEmpty;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: hasDeskripsi
                        ? () => setState(() {
                      if (isExpanded) {
                        _expandedIds.remove(item.id);
                      } else {
                        _expandedIds.add(item.id);
                      }
                    })
                        : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Badge minggu ──
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Text(
                                "${item.minggu}",
                                style: const TextStyle(
                                  color: _primaryColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  height: 1,
                                ),
                              ),
                              Text(
                                "Mgu",
                                style: TextStyle(
                                  color: _primaryColor
                                      .withOpacity(0.7),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // ── Konten ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.namaPertemuan,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: _darkText,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.judul,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black
                                      .withOpacity(0.55),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (hasDeskripsi)
                          Padding(
                            padding:
                            const EdgeInsets.only(top: 12),
                            child: Icon(
                              isExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: Colors.black.withOpacity(0.3),
                            ),
                          ),

                        const SizedBox(width: 4),

                        // ── Tombol edit ──
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showFormDialog(item: item),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                              _primaryColor.withOpacity(0.08),
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_outlined,
                                color: _primaryColor, size: 20),
                          ),
                        ),

                        // ── Tombol hapus ──
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _deletePertemuan(item.id),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                                size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Deskripsi (muncul saat di-tap) ──
                  if (isExpanded)
                    Padding(
                      padding:
                      const EdgeInsets.only(top: 10, left: 60),
                      child: Text(
                        item.deskripsi,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.6),
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}