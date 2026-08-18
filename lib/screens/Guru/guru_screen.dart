import 'package:flutter/material.dart';
import 'package:organappfr/screens/Guru/siswasaya.dart';
// sesuaikan path LoginScreen kamu
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../service/guru_service.dart';
import '../Admin/organ_adminscreen.dart';
import '../Admin/quiz_admin.dart'; // sesuaikan path QuizAdminScreen kamu
import '../auth/login_screen.dart';
import 'nilaisiswaguru.dart';
import '../Admin/pertemuan_screen.dart';   // sesuaikan path PertemuanScreen


/// Halaman utama (dashboard) untuk role GURU.
///
/// Berisi 3 tab lewat BottomNavigationBar:
/// 1. Materi      -> berisi 3 sub-tab: Pertemuan, Materi Organ & Quiz
///                   (reuse PertemuanScreen + OrganAdminScreen + QuizAdminScreen).
/// 2. Siswa Saya  -> daftar siswa di kelas yang diampu guru ini.
/// 3. Nilai Siswa -> daftar nilai quiz dari siswa-siswa tsb.
class GuruScreen extends StatefulWidget {
  const GuruScreen({Key? key}) : super(key: key);

  @override
  State<GuruScreen> createState() => _GuruScreenState();
}

class _GuruScreenState extends State<GuruScreen> {
  static const Color _primaryColor = Color(0xFF1B3F9E);

  final GuruService _guruService = GuruService();
  int _currentIndex = 0;
  Map<String, dynamic>? _guru;

  @override
  void initState() {
    super.initState();
    _loadGuru();
  }

  Future<void> _loadGuru() async {
    final guru = await _guruService.getGuruSaya();
    if (mounted) setState(() => _guru = guru);
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final namaGuru = _guru?['nama'] ?? '';
    final kelasGuru = _guru?['kelas'] ?? '-';

    final titles = ['Materi', 'Siswa Saya', 'Nilai Siswa'];

    final tabs = const [
      _MateriTabContent(),
      SiswaSayaScreen(),
      NilaiSiswaScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        foregroundColor: Colors.white, // pastikan icon & title default putih
        title: Text(
          _currentIndex == 0 && namaGuru.isNotEmpty
              ? 'Halo, $namaGuru (Kelas $kelasGuru)'
              : titles[_currentIndex],
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white, // kontras eksplisit di atas AppBar navy
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Keluar',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Materi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            label: 'Siswa Saya',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard_outlined),
            label: 'Nilai Siswa',
          ),
        ],
      ),
    );
  }
}

/// Konten tab "Materi": berisi sub-tab Pertemuan, Materi Organ & Quiz,
/// reuse `PertemuanScreen`, `OrganAdminScreen`, dan `QuizAdminScreen` yang sudah ada.
///
/// Pakai DefaultTabController + TabBar terpisah (bukan BottomNavigationBar)
/// supaya tidak nabrak dengan navbar utama GuruScreen.
class _MateriTabContent extends StatelessWidget {
  const _MateriTabContent();

  static const Color _primaryColor = Color(0xFF1B3F9E);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: _primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _primaryColor,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.event_note_outlined), text: 'Pertemuan'),
                Tab(icon: Icon(Icons.view_in_ar_outlined), text: 'Materi Organ'),
                Tab(icon: Icon(Icons.quiz_outlined), text: 'Quiz'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                PertemuanScreen(),
                OrganAdminScreen(),
                QuizAdminScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}