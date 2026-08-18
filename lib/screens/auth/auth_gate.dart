import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:organappfr/screens/auth/login_screen.dart';
import 'package:organappfr/screens/navbar.dart';
import 'package:organappfr/screens/Admin/admin_screen.dart';
import 'package:organappfr/screens/Guru/guru_screen.dart'; // sesuaikan path GuruScreen kamu

/// AuthGate — widget "pintu masuk" pertama yang dipanggil dari main.dart
/// (menggantikan LoginScreen langsung sebagai `home`).
///
/// Alur kerja:
/// 1. Cek apakah ada session Supabase yang tersimpan.
///    - Tidak ada  -> tampilkan LoginScreen.
/// 2. Kalau ada session, cek kapan terakhir kali app ditinggal
///    (paused/detached), disimpan di SharedPreferences.
///    - Jika sudah lebih dari SESSION_TIMEOUT -> signOut() paksa,
///      tampilkan LoginScreen lagi.
///    - Jika belum -> langsung arahkan ke MainScreen/GuruScreen/AdminScreen
///      sesuai kolom `role` di tabel `siswa`, tanpa perlu login ulang.
/// 3. AuthGate juga mendengarkan siklus hidup app (WidgetsBindingObserver)
///    supaya setiap kali app di-minimize/ditutup, waktu "terakhir aktif"
///    selalu ter-update.
class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  // Key penyimpanan timestamp terakhir kali app aktif/ditinggal.
  static const _kLastActiveKey = 'last_active_timestamp';

  // Batas waktu sesi dianggap kedaluwarsa jika app ditinggal lebih lama
  // dari durasi ini. Ubah sesuai kebutuhan (misalnya Duration(minutes: 30)).
  static const Duration _sessionTimeout = Duration(minutes: 2);

  bool _checking = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resolveDestination();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Dipanggil otomatis oleh Flutter setiap kali status app berubah:
  /// resumed (dibuka lagi), inactive (transisi), paused (di-minimize),
  /// detached (ditutup total).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveLastActiveTime();
    }
  }

  Future<void> _saveLastActiveTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kLastActiveKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _resolveDestination() async {
    final supabase = Supabase.instance.client;

    // PENTING: jangan langsung baca supabase.auth.currentSession di sini.
    // Saat app baru dibuka, Supabase butuh sedikit waktu untuk me-restore
    // session yang tersimpan di local storage. Kalau kita cek terlalu
    // cepat, currentSession bisa masih null padahal user sebenarnya
    // sudah pernah login -> makanya selalu disuruh login ulang.
    //
    // Solusi: tunggu event pertama dari onAuthStateChange, yang baru
    // terpicu SETELAH Supabase selesai memulihkan session (event
    // AuthChangeEvent.initialSession).
    final authState = await supabase.auth.onAuthStateChange.first.timeout(
      const Duration(seconds: 5),
      onTimeout: () => AuthState(AuthChangeEvent.signedOut, null),
    );
    final session = authState.session ?? supabase.auth.currentSession;

    // 1. Belum pernah login sama sekali, atau token Supabase sudah
    //    tidak valid -> wajib login.
    if (session == null) {
      _setDestination(const LoginScreen());
      return;
    }

    // 2. Cek kapan terakhir kali app ditinggal.
    final prefs = await SharedPreferences.getInstance();
    final lastActiveMillis = prefs.getInt(_kLastActiveKey);

    if (lastActiveMillis != null) {
      final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveMillis);
      final elapsed = DateTime.now().difference(lastActive);

      if (elapsed > _sessionTimeout) {
        // Sudah lebih dari batas waktu -> paksa logout, minta login lagi.
        await supabase.auth.signOut();
        _setDestination(const LoginScreen());
        return;
      }
    }

    // 3. Masih dalam batas waktu -> langsung arahkan sesuai role,
    //    tanpa perlu login ulang.
    try {
      final data = await supabase
          .from('siswa')
          .select('role')
          .eq('email', session.user.email as Object)
          .maybeSingle();

      // Normalisasi role supaya tidak sensitif huruf besar/kecil
      // (misal 'Guru', 'GURU', 'guru' semua dianggap sama).
      final role = ((data?['role'] as String?) ?? 'siswa').toLowerCase().trim();

      if (role == 'admin') {
        _setDestination(const AdminScreen());
      } else if (role == 'guru') {
        _setDestination(const GuruScreen());
      } else {
        _setDestination(const MainScreen());
      }
    } catch (e) {
      // Kalau gagal ambil data role (misal koneksi bermasalah, nama
      // kolom tidak cocok, atau RLS memblokir), kita cetak error-nya
      // supaya gampang di-debug lewat `flutter run` -> lihat console.
      debugPrint('AuthGate: gagal ambil role, fallback ke LoginScreen. Error: $e');
      _setDestination(const LoginScreen());
    }
  }

  void _setDestination(Widget dest) {
    if (!mounted) return;
    setState(() {
      _destination = dest;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _destination!;
  }
}