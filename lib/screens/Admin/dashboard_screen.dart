import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:organappfr/screens/auth/login_screen.dart'; // ← sesuaikan path

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;

  // Simpan hasil hitung tiap tabel di sini
  Map<String, int> jumlah = {
    "pertemuan": 0,
    "organ": 0,
    "siswa": 0,
    "quiz_soal": 0,
  };

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadJumlah();
  }

  // Hitung jumlah row di 1 tabel tanpa narik semua datanya
  Future<int> hitungTabel(String namaTabel) async {
    final response = await supabase
        .from(namaTabel)
        .select()
        .count(CountOption.exact);
    return response.count;
  }

  Future<void> loadJumlah() async {
    setState(() => loading = true);

    try {
      // Jalankan ke-4 query bareng-bareng biar lebih cepat
      final hasil = await Future.wait([
        hitungTabel("pertemuan"),
        hitungTabel("organ"),
        hitungTabel("siswa"),
        hitungTabel("quiz_soal"),
      ]);

      setState(() {
        jumlah = {
          "pertemuan": hasil[0],
          "organ": hasil[1],
          "siswa": hasil[2],
          "quiz_soal": hasil[3],
        };
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal ambil data: $e")),
        );
      }
    }
  }

  Widget card(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Admin"),
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: "Keluar",
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Keluar"),
                content: const Text("Yakin ingin keluar dari akun admin?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Batal"),
                  ),
                  TextButton(
                    onPressed: () {
                      // Hapus semua halaman dan ke LoginScreen
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                            (route) => false, // hapus semua stack
                      );
                    },
                    child: const Text(
                      "Keluar",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Muat ulang",
            onPressed: loadJumlah,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: loadJumlah,
        child: GridView.count(
          padding: const EdgeInsets.all(15),
          crossAxisCount: 2,
          children: [
            card("Pertemuan", "${jumlah["pertemuan"]}",
                Icons.calendar_month),
            card("Organ", "${jumlah["organ"]}", Icons.favorite),
            card("Siswa", "${jumlah["siswa"]}", Icons.people),
            card("Quiz", "${jumlah["quiz_soal"]}", Icons.quiz),
          ],
        ),
      ),
    );
  }
}