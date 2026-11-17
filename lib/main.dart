import 'package:flutter/material.dart';
import 'package:organappfr/screens/onboarding/onboarding_screen.dart';
import 'package:organappfr/service/notificationservice.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notifikasi/notifikasiscreen.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: '',
    anonKey: '',
  );

  // Inisialisasi notifikasi lokal (TANPA minta izin di awal)
  await NotificationService.instance.init();

  final prefs = await SharedPreferences.getInstance();
  final isReminderSet = prefs.getBool('reminder_active');

  if (isReminderSet == null) {
    // Baru pertama kali install / belum ada data -> set default jam 10:00
    await prefs.setBool('reminder_active', true);
    await prefs.setInt('reminder_hour', 10);
    await prefs.setInt('reminder_minute', 0);
  }

  // PENJADWALAN ULANG SETIAP APP DIBUKA.
  // Ini WAJIB dilakukan setiap start, bukan cuma sekali saat install,
  // karena scheduling internal flutter_local_notifications bisa hilang
  // (mis. setelah app di-update, reboot tanpa boot receiver, dsb).
  // Kita baca jam/menit TERBARU dari prefs (bukan hardcode 10:00),
  // supaya jam yang sudah diubah user tidak ketimpa balik.
  final reminderActive = prefs.getBool('reminder_active') ?? true;
  if (reminderActive) {
    final hour = prefs.getInt('reminder_hour') ?? 10;
    final minute = prefs.getInt('reminder_minute') ?? 0;

    try {
      await NotificationService.instance.scheduleDailyStudyReminder(
        hour: hour,
        minute: minute,
        title: 'Waktunya Lanjut Belajar! 📚',
        body: 'Yuk, buka aplikasinya dan lanjutkan progres belajarmu hari ini.',
      );
      debugPrint('Reminder di-refresh untuk jam $hour:$minute');
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi saat start app: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Organ Tubuh App',
      home: const SplashScreen(),
      builder: (context, child) {
        return ShowCaseWidget(
          builder: (context) => child!,
        );
      },
    );
  }
}
