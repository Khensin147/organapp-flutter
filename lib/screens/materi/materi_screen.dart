import 'package:flutter/material.dart';
import 'package:organappfr/screens/materi/organ_list_screen.dart'; // ← ganti import
import 'package:organappfr/service/pertemuan_service.dart';
import '../../models/pertemuan_model.dart';

class MateriScreen extends StatefulWidget {
  const MateriScreen({super.key});

  @override
  State<MateriScreen> createState() => _MateriScreenState();
}

class _MateriScreenState extends State<MateriScreen> {
  final PertemuanService _service = PertemuanService();
  List<PertemuanModel> _pertemuanList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPertemuan();
  }

  Future<void> _loadPertemuan() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getPertemuan();
      final list = data.map((e) => PertemuanModel.fromJson(e)).toList();

      // Urutkan berdasarkan angka yang ada di namaPertemuan
      // (misal: "Pertemuan 1", "pertemuan 2", "tugas 1" tetap terurut walau penamaan tidak konsisten)
      list.sort((a, b) {
        final numA = _extractNumber(a.namaPertemuan);
        final numB = _extractNumber(b.namaPertemuan);
        return numA.compareTo(numB);
      });

      setState(() {
        _pertemuanList = list;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal memuat data: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Mengambil angka pertama dari sebuah teks, contoh "Pertemuan 3" -> 3
  // Jika tidak ada angka, dianggap paling besar (ditaruh di akhir daftar)
  int _extractNumber(String text) {
    final match = RegExp(r'\d+').firstMatch(text);
    return match != null ? int.parse(match.group(0)!) : 9999;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Daftar Pertemuan",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pertemuanList.isEmpty
          ? const Center(
        child: Text(
          "Belum ada pertemuan tersedia.",
          style: TextStyle(color: Colors.grey),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadPertemuan,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: GridView.builder(
            itemCount: _pertemuanList.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (context, index) {
              final item = _pertemuanList[index];

              return _AnimatedPertemuanCard(
                onTap: () {
                  // ← langsung masuk, tidak ada kunci
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrganListScreen(
                        pertemuanId: item.id,
                        judulPertemuan: item.judul,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Icon buku (tidak ada gembok)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.namaPertemuan,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.judul,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),

                      // Panah kanan
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.black,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Wrapper animasi untuk kartu pertemuan/tugas.
///
/// Memberi efek "mengecil" (scale down) singkat saat kartu ditekan,
/// lalu kembali membesar ke ukuran normal saat jari dilepas/dibatalkan,
/// supaya ada feedback visual bahwa tap-nya kedetect (mirip efek tombol
/// ditekan pada umumnya).
class _AnimatedPertemuanCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedPertemuanCard({
    required this.child,
    required this.onTap,
  });

  @override
  State<_AnimatedPertemuanCard> createState() =>
      _AnimatedPertemuanCardState();
}

class _AnimatedPertemuanCardState extends State<_AnimatedPertemuanCard> {
  static const Duration _animDuration = Duration(milliseconds: 120);

  bool _isPressed = false;
  bool _isNavigating = false; // cegah double-tap saat animasi berjalan

  void _setPressed(bool pressed) {
    if (_isPressed != pressed) {
      setState(() => _isPressed = pressed);
    }
  }

  // Urutan: tekan (scale mengecil) -> tunggu animasi kelihatan dulu ->
  // lepas (scale membesar lagi) -> baru pindah halaman.
  // Kalau Navigator.push langsung dipanggil begitu jari diangkat,
  // halaman baru keburu menutupi kartu sebelum animasinya sempat
  // dirender, jadi animasinya terasa "tidak ada".
  Future<void> _handleTap() async {
    if (_isNavigating) return;
    _isNavigating = true;

    _setPressed(true);
    await Future.delayed(_animDuration);
    if (!mounted) return;
    _setPressed(false);
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    widget.onTap();
    _isNavigating = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: _animDuration,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _isPressed ? 0.85 : 1.0,
          duration: _animDuration,
          child: widget.child,
        ),
      ),
    );
  }
}