import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:organappfr/screens/auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  String _nama = '';
  String _username = '';
  String _kelas = '';
  String _email = '';
  String? _avatarUrl;

  // Animasi "kedatangan halaman": fade + slide + scale halus yang main
  // begitu halaman ini terlihat (baik lewat Navigator.push maupun saat
  // tab Profil dipilih di IndexedStack lewat reload()). Dipisah dari
  // _entranceController supaya tidak menunggu proses fetch data selesai.
  late final AnimationController _pageTransitionController;
  late final Animation<double> _pageFade;
  late final Animation<Offset> _pageSlide;
  late final Animation<double> _pageScale;

  // Animasi kemunculan konten (fade + slide, bertahap antar section)
  late final AnimationController _entranceController;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _listFade;
  late final Animation<Offset> _listSlide;

  // Animasi "pop-in" untuk avatar saat pertama kali muncul
  late final Animation<double> _avatarPop;

  // Animasi staggered untuk tiap item pada daftar aksi akun
  late final List<Animation<double>> _tileFades;
  late final List<Animation<Offset>> _tileSlides;

  // Animasi feedback saat avatar ditekan
  bool _avatarPressed = false;

  // Controllers form edit profil
  final _editNamaC = TextEditingController();
  final _editKelasC = TextEditingController();

  // Controllers ganti password
  final _passwordBaruC = TextEditingController();
  final _passwordKonfirmasiC = TextEditingController();
  bool _obscurePassword = true;

  static const Color _bgColor = Color(0xFFF2F2F2);
  static const Color _darkText = Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cardFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_cardFade);

    // Avatar "pop" dengan sedikit efek overshoot supaya terasa hidup
    _avatarPop = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _listFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _listSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_listFade);

    // Setiap item di daftar "Akun" muncul satu per satu (staggered)
    _tileFades = List.generate(3, (i) {
      final start = (0.35 + i * 0.15).clamp(0.0, 1.0);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });
    _tileSlides = _tileFades
        .map((fade) => Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(fade))
        .toList();

    _loadProfil();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _editNamaC.dispose();
    _editKelasC.dispose();
    _passwordBaruC.dispose();
    _passwordKonfirmasiC.dispose();
    super.dispose();
  }

  // Method publik supaya bisa dipanggil dari luar (misalnya dari navbar.dart
  // lewat GlobalKey) untuk memuat ulang data profil, misalnya saat tab
  // Profil dipilih di IndexedStack.
  Future<void> reload() => _loadProfil();

  Future<void> _loadProfil() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _email = user.email ?? '';
        final data = await _supabase
            .from('siswa')
            .select('nama, username, kelas, avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        if (data != null) {
          _nama = data['nama'] ?? '';
          _username = data['username'] ?? '';
          _kelas = data['kelas'] ?? '';
          _avatarUrl = data['avatar_url'];
        }
      }
    } catch (e) {
      _showSnackbar("Gagal memuat profil: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _entranceController
          ..reset()
          ..forward();
      }
    }
  }

  // ═══════════════════════ GANTI FOTO PROFIL ═══════════════════════
  Future<void> _pilihDanUploadFoto() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final file = File(picked.path);
      final ext = picked.path.split('.').last;
      final path = '${user.id}/avatar.$ext';

      // Upload ke bucket 'avatars' (pastikan bucket ini sudah dibuat
      // di Supabase Storage dan diset public / punya policy yang sesuai)
      await _supabase.storage.from('avatars').upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      // Tambahkan query param waktu supaya gambar baru tidak kena cache lama
      final urlDenganCacheBuster =
          '$publicUrl?updated=${DateTime.now().millisecondsSinceEpoch}';

      await _supabase
          .from('siswa')
          .update({'avatar_url': urlDenganCacheBuster}).eq('id', user.id);

      setState(() => _avatarUrl = urlDenganCacheBuster);
      _showSnackbar("Foto profil berhasil diperbarui!");
    } catch (e) {
      _showSnackbar("Gagal mengupload foto: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showEditProfilSheet() {
    _editNamaC.text = _nama;
    _editKelasC.text = _kelas;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
              _buildDragHandle(),
              _buildSheetHeader("Edit Profil"),
              const SizedBox(height: 20),
              _buildLabel("Nama Lengkap"),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _editNamaC,
                hint: "Nama kamu",
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 14),
              _buildLabel("Kelas"),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _editKelasC,
                hint: "Contoh: 8A",
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: 24),
              _buildSubmitButton(
                label: "Simpan Perubahan",
                onPressed: _submitEditProfil,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitEditProfil() async {
    final nama = _editNamaC.text.trim();
    final kelas = _editKelasC.text.trim();

    if (nama.isEmpty || kelas.isEmpty) {
      _showSnackbar("Nama dan kelas wajib diisi!", isError: true);
      return;
    }

    Navigator.pop(context);
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('siswa')
            .update({'nama': nama, 'kelas': kelas}).eq('id', user.id);
        _showSnackbar("Profil berhasil diperbarui!");
        _loadProfil();
      }
    } catch (e) {
      _showSnackbar("Gagal menyimpan: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════ GANTI PASSWORD ═══════════════════════
  void _showGantiPasswordSheet() {
    _passwordBaruC.clear();
    _passwordKonfirmasiC.clear();
    _obscurePassword = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                _buildDragHandle(),
                _buildSheetHeader("Ganti Password"),
                const SizedBox(height: 20),
                _buildLabel("Password Baru"),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _passwordBaruC,
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
                _buildLabel("Konfirmasi Password"),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _passwordKonfirmasiC,
                  hint: "Ulangi password baru",
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                ),
                const SizedBox(height: 24),
                _buildSubmitButton(
                  label: "Simpan Password",
                  onPressed: _submitGantiPassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitGantiPassword() async {
    final baru = _passwordBaruC.text.trim();
    final konfirmasi = _passwordKonfirmasiC.text.trim();

    if (baru.isEmpty || konfirmasi.isEmpty) {
      _showSnackbar("Semua field wajib diisi!", isError: true);
      return;
    }
    if (baru.length < 6) {
      _showSnackbar("Password minimal 6 karakter!", isError: true);
      return;
    }
    if (baru != konfirmasi) {
      _showSnackbar("Konfirmasi password tidak cocok!", isError: true);
      return;
    }

    Navigator.pop(context);
    try {
      await _supabase.auth.updateUser(UserAttributes(password: baru));
      _showSnackbar("Password berhasil diubah!");
    } catch (e) {
      _showSnackbar("Gagal mengubah password: $e", isError: true);
    }
  }

  // ═══════════════════════ LOGOUT ═══════════════════════
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Keluar Akun"),
        content: const Text("Yakin ingin keluar?"),
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Keluar"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(msg),
        backgroundColor: isError ? Colors.red : _darkText,
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
        title: const Text(
          "Profil",
          style: TextStyle(
              color: _darkText, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isLoading
            ? const Center(
          key: ValueKey('loading'),
          child: CircularProgressIndicator(color: _darkText),
        )
            : SingleChildScrollView(
          key: const ValueKey('content'),
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: _cardFade,
                child: SlideTransition(
                  position: _cardSlide,
                  child: _buildInfoCard(),
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _listFade,
                child: SlideTransition(
                  position: _listSlide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Akun"),
                      const SizedBox(height: 10),
                      _buildAksiList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. INFO DASAR ──────────────────────────────────────────────
  Widget _buildInfoCard() {
    final initial = _nama.isNotEmpty ? _nama[0].toUpperCase() : '?';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploadingPhoto ? null : _pilihDanUploadFoto,
            onTapDown: _isUploadingPhoto
                ? null
                : (_) => setState(() => _avatarPressed = true),
            onTapUp: _isUploadingPhoto
                ? null
                : (_) => setState(() => _avatarPressed = false),
            onTapCancel: _isUploadingPhoto
                ? null
                : () => setState(() => _avatarPressed = false),
            // Efek "pop" halus saat avatar pertama kali muncul di layar
            child: ScaleTransition(
              scale: _avatarPop,
              child: AnimatedScale(
                scale: _avatarPressed ? 0.92 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: anim, child: child),
                      ),
                      child: Container(
                        key: ValueKey(_isUploadingPhoto
                            ? 'uploading'
                            : (_avatarUrl ?? 'kosong')),
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _darkText,
                          shape: BoxShape.circle,
                          image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              ? DecorationImage(
                            image: NetworkImage(_avatarUrl!),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: _isUploadingPhoto
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                            : (_avatarUrl == null || _avatarUrl!.isEmpty)
                            ? Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 12, color: _darkText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _nama.isNotEmpty ? _nama : '-',
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: _darkText),
          ),
          const SizedBox(height: 4),
          Text(
            _email,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[200], height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.alternate_email_rounded,
                  label: "Username",
                  value: _username.isNotEmpty ? _username : '-',
                ),
              ),
              Container(width: 1, height: 32, color: Colors.grey[200]),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.school_outlined,
                  label: "Kelas",
                  value: _kelas.isNotEmpty ? _kelas : '-',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
      {required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: _darkText)),
      ],
    );
  }

  // ── 3. AKSI AKUN ────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.bold, color: _darkText),
  );

  Widget _buildAksiList() {
    // Daftar item dibuat lebih dulu supaya bisa dibungkus animasi
    // fade + slide bertahap (staggered) satu per satu saat muncul.
    final items = <Widget>[
      _buildAksiTile(
        icon: Icons.edit_outlined,
        label: "Edit Profil",
        onTap: _showEditProfilSheet,
      ),
      _buildAksiTile(
        icon: Icons.lock_reset_rounded,
        label: "Ganti Password",
        onTap: _showGantiPasswordSheet,
      ),
      _buildAksiTile(
        icon: Icons.logout_rounded,
        label: "Keluar",
        isDestructive: true,
        onTap: _logout,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            FadeTransition(
              opacity: _tileFades[i],
              child: SlideTransition(
                position: _tileSlides[i],
                child: items[i],
              ),
            ),
            if (i != items.length - 1)
              Divider(height: 1, indent: 56, color: Colors.grey[200]),
          ],
        ],
      ),
    );
  }

  Widget _buildAksiTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : _darkText;
    return InkWell(
      onTap: onTap,
      splashColor: color.withOpacity(0.06),
      highlightColor: color.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: color),
              ),
            ),
            if (!isDestructive)
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  // ── HELPER FORM ─────────────────────────────────────────────────
  Widget _buildDragHandle() => Center(
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

  Widget _buildSheetHeader(String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: _darkText),
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
        fontSize: 13, fontWeight: FontWeight.w600, color: _darkText),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 14, color: _darkText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        TextStyle(color: Colors.black.withOpacity(0.35), fontSize: 14),
        prefixIcon: Icon(icon, color: _darkText.withOpacity(0.6), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.black.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkText, width: 1.5),
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
          backgroundColor: _darkText,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}