import 'package:flutter/material.dart';
import 'package:organappfr/screens/Admin/tambah_guru.dart';
import 'package:organappfr/service/siswa_services.dart';
import '../../models/siswa_models.dart';


class SiswaScreen extends StatefulWidget {
  const SiswaScreen({super.key});

  @override
  State<SiswaScreen> createState() => _SiswaScreenState();
}

class _SiswaScreenState extends State<SiswaScreen> {
  final SiswaServices _service = SiswaServices();
  final TextEditingController _searchController = TextEditingController();

  List<SiswaModel> _siswaList = [];
  bool _isLoading = false;
  String _query = '';

  // Controllers tambah
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _kelasController = TextEditingController();
  final _usernameController = TextEditingController();

  // Controllers edit
  final _editNamaController = TextEditingController();
  final _editKelasController = TextEditingController();
  final _editUsernameController = TextEditingController();
  // Password baru (opsional) saat edit — dikosongkan berarti tidak diubah.
  final _editPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureEditPassword = true;

  // Warna tema (konsisten dengan layar Pertemuan & Nilai)
  static const Color _primaryColor = Color(0xFF0E6E3B);
  static const Color _bgColor = Color(0xFFF5F7F6);
  static const Color _darkText = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _loadSiswa();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _kelasController.dispose();
    _usernameController.dispose();
    _editNamaController.dispose();
    _editKelasController.dispose();
    _editUsernameController.dispose();
    _editPasswordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSiswa() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getSiswa();
      setState(() {
        _siswaList = data.map((e) => SiswaModel.fromJson(e)).toList();
      });
    } catch (e) {
      _showSnackbar("Gagal memuat data: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<SiswaModel> get _filteredList {
    if (_query.isEmpty) return _siswaList;
    return _siswaList.where((s) {
      return s.nama.toLowerCase().contains(_query) ||
          s.username.toLowerCase().contains(_query) ||
          s.kelas.toLowerCase().contains(_query);
    }).toList();
  }

  int get _jumlahKelas => _siswaList.map((s) => s.kelas).toSet().length;

  // ═══════════════════════ FORM TAMBAH ═══════════════════════
  void _showTambahDialog() {
    _namaController.clear();
    _emailController.clear();
    _passwordController.clear();
    _kelasController.clear();
    _usernameController.clear();
    _obscurePassword = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                    icon: Icons.person_add_alt_1_rounded,
                    title: "Tambah Siswa",
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Nama Lengkap"),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _namaController,
                    hint: "Nama siswa",
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel("Username (untuk login)"),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _usernameController,
                    hint: "Contoh: andi123",
                    icon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel("Email"),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _emailController,
                    hint: "nama@email.com",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel("Password"),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _passwordController,
                    hint: "Minimal 6 karakter",
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    suffixIcon: InkWell(
                      onTap: () => setSheetState(
                              () => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.black.withOpacity(0.35),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildLabel("Kelas"),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _kelasController,
                    hint: "Contoh: 8A",
                    icon: Icons.school_outlined,
                  ),
                  const SizedBox(height: 24),

                  _buildSubmitButton(
                    label: "Simpan",
                    onPressed: _submitTambah,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitTambah() async {
    final nama = _namaController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final kelas = _kelasController.text.trim();

    if (nama.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        kelas.isEmpty) {
      _showSnackbar("Semua field wajib diisi!", isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackbar("Password minimal 6 karakter!", isError: true);
      return;
    }

    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      await _service.tambahSiswa(
        nama: nama,
        email: email,
        password: password,
        kelas: kelas,
        username: username,
      );
      _showSnackbar("Siswa berhasil ditambahkan!");
      _loadSiswa();
    } catch (e) {
      _showSnackbar("Gagal: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════ FORM EDIT ═══════════════════════
  void _showEditDialog(SiswaModel siswa) {
    _editNamaController.text = siswa.nama;
    _editKelasController.text = siswa.kelas;
    _editUsernameController.text = siswa.username;
    _editPasswordController.clear(); // ← selalu kosong, opsional
    _obscureEditPassword = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                    icon: Icons.edit_note_rounded,
                    title: "Edit Siswa",
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Nama Lengkap"),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _editNamaController,
                    hint: "Nama siswa",
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel("Username"),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _editUsernameController,
                    hint: "Contoh: andi123",
                    icon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel("Email"),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.black.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email_outlined,
                            color: Colors.black.withOpacity(0.35), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            siswa.email,
                            style: TextStyle(
                                color: Colors.black.withOpacity(0.5)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("Email tidak dapat diubah",
                      style: TextStyle(
                          fontSize: 11, color: Colors.black.withOpacity(0.35))),
                  const SizedBox(height: 14),

                  _buildLabel("Kelas"),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _editKelasController,
                    hint: "Contoh: 8A",
                    icon: Icons.school_outlined,
                  ),
                  const SizedBox(height: 14),

                  // ── FIELD BARU: Password baru (opsional) ──
                  _buildLabel("Password Baru"),
                  const SizedBox(height: 2),
                  Text(
                    "Kosongkan jika tidak ingin mengubah password",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.black.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _editPasswordController,
                    hint: "Minimal 6 karakter",
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureEditPassword,
                    suffixIcon: InkWell(
                      onTap: () => setSheetState(() =>
                      _obscureEditPassword = !_obscureEditPassword),
                      child: Icon(
                        _obscureEditPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.black.withOpacity(0.35),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSubmitButton(
                    label: "Simpan Perubahan",
                    onPressed: () => _submitEdit(siswa.id),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitEdit(String id) async {
    final nama = _editNamaController.text.trim();
    final kelas = _editKelasController.text.trim();
    final username = _editUsernameController.text.trim().toLowerCase();
    final password = _editPasswordController.text.trim();

    if (nama.isEmpty || kelas.isEmpty || username.isEmpty) {
      _showSnackbar("Semua field wajib diisi!", isError: true);
      return;
    }

    // Validasi password HANYA kalau diisi (karena opsional).
    if (password.isNotEmpty && password.length < 6) {
      _showSnackbar("Password baru minimal 6 karakter!", isError: true);
      return;
    }

    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      await _service.editSiswa(
        id: id,
        nama: nama,
        kelas: kelas,
        username: username,
        // null kalau kosong -> password lama tidak berubah
        password: password.isEmpty ? null : password,
      );
      _showSnackbar(
        password.isEmpty
            ? "Data siswa berhasil diupdate!"
            : "Data & password siswa berhasil diupdate!",
      );
      _loadSiswa();
    } catch (e) {
      _showSnackbar("Gagal update: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _hapusSiswa(SiswaModel siswa) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Siswa"),
        content: Text("Yakin ingin menghapus ${siswa.nama}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Batal",
                style: TextStyle(color: Colors.black.withOpacity(0.6))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _service.hapusSiswa(siswa.id);
        _showSnackbar("Siswa berhasil dihapus!");
        _loadSiswa();
      } catch (e) {
        _showSnackbar("Gagal menghapus: $e", isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
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

  // ═══════════════════════ HELPER WIDGETS ═══════════════════════
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
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: obscureText ? 1 : maxLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: _darkText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        TextStyle(color: Colors.black.withOpacity(0.35), fontSize: 14),
        prefixIcon: Icon(icon, color: _primaryColor.withOpacity(0.7), size: 20),
        suffixIcon: suffixIcon,
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

  Widget _buildSubmitButton(
      {required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
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
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _darkText,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════ BUILD ═══════════════════════
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
              "Kelola Siswa",
              style: TextStyle(
                color: _darkText,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              "${_siswaList.length} siswa terdaftar",
              style: TextStyle(
                color: Colors.black.withOpacity(0.45),
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ],
        ),
        // ← BARU: tombol pindah ke halaman Kelola Guru
        actions: [
          IconButton(
            tooltip: "Kelola Guru",
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_rounded,
                  color: _primaryColor, size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KelolaGuruScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // FIX: FAB dibungkus Padding supaya naik ke atas dan tidak
      // ketutupan navbar bawah. Nilai `bottom: 70` disamakan dengan
      // screen admin lain supaya posisinya konsisten.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          onPressed: _showTambahDialog,
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
          : _siswaList.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 56, color: Colors.black.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text(
              "Belum ada siswa.\nTambah dengan tombol +",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black.withOpacity(0.4)),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // ── Ringkasan statistik ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.groups_rounded,
                    label: "Total Siswa",
                    value: "${_siswaList.length}",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.class_outlined,
                    label: "Jumlah Kelas",
                    value: "$_jumlahKelas",
                  ),
                ),
              ],
            ),
          ),

          // ── Kolom pencarian ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14, color: _darkText),
              decoration: InputDecoration(
                hintText: "Cari nama, username, atau kelas...",
                hintStyle: TextStyle(
                    color: Colors.black.withOpacity(0.35),
                    fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: _primaryColor.withOpacity(0.7), size: 20),
                suffixIcon: _query.isNotEmpty
                    ? InkWell(
                  onTap: () => _searchController.clear(),
                  child: Icon(Icons.close_rounded,
                      color: Colors.black.withOpacity(0.4),
                      size: 18),
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: _primaryColor.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: _primaryColor.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: _primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ── Daftar siswa ──
          Expanded(
            child: _filteredList.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 48,
                      color: Colors.black.withOpacity(0.2)),
                  const SizedBox(height: 10),
                  Text(
                    "Tidak ada hasil untuk \"$_query\"",
                    style: TextStyle(
                        color: Colors.black.withOpacity(0.4)),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              color: _primaryColor,
              onRefresh: _loadSiswa,
              child: ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(16, 0, 16, 96),
                itemCount: _filteredList.length,
                itemBuilder: (context, index) {
                  final siswa = _filteredList[index];
                  return _buildSiswaCard(siswa);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiswaCard(SiswaModel siswa) {
    final initial = siswa.nama.isNotEmpty ? siswa.nama[0].toUpperCase() : '?';

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar inisial ──
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

          // ── Konten ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  siswa.nama,
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
                    Icon(Icons.alternate_email_rounded,
                        size: 13, color: Colors.black.withOpacity(0.35)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        siswa.username,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  siswa.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.45),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Kelas ${siswa.kelas}",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tombol aksi ──
          Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showEditDialog(siswa),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      color: _primaryColor, size: 20),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _hapusSiswa(siswa),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}