import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/notificationservice.dart';

class _NotifColors {
  static const Color primary = Color(0xFF1B3F9E);
  static const Color primaryDark = Color(0xFF122C6F);
  static const Color primarySoft = Color(0xFFE7ECFA);
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF16181D);
  static const Color textGray = Color(0xFF6B7280);
  static const Color textFaint = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFEDEDF2);
}

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  static const _prefsKeyHour = 'reminder_hour';
  static const _prefsKeyMinute = 'reminder_minute';
  static const _prefsKeyActive = 'reminder_active';

  // Default awal diset ke jam 10:00
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  bool _reminderActive = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Jika tidak ada data, gunakan default jam 10:00
    final hour = prefs.getInt(_prefsKeyHour) ?? 10;
    final minute = prefs.getInt(_prefsKeyMinute) ?? 0;
    final active = prefs.getBool(_prefsKeyActive) ?? true;

    if (!mounted) return;
    setState(() {
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
      _reminderActive = active;
      _isLoading = false;
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _NotifColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;

    setState(() => _selectedTime = picked);

    // Kalau pengingat sedang aktif, langsung jadwal ulang ke jam baru.
    if (_reminderActive) {
      await _applyReminder();
    } else {
      // Meski reminder tidak aktif, tetap simpan jam pilihan user
      // supaya tidak "hilang" saat app dibuka lagi.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyHour, _selectedTime.hour);
      await prefs.setInt(_prefsKeyMinute, _selectedTime.minute);
    }
  }

  Future<void> _onToggleActive(bool value) async {
    setState(() => _reminderActive = value);

    if (value) {
      // MINTA IZIN NOTIFIKASI BIASA
      await NotificationService.instance.requestPermissions();

      // CEK & MINTA IZIN EXACT ALARM (Android 12+)
      final canExact =
      await NotificationService.instance.canScheduleExactAlarms();
      if (!canExact && mounted) {
        final goToSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Izin tambahan diperlukan'),
            content: const Text(
              'Agar pengingat muncul tepat waktu, aktifkan izin "Alarms & reminders" '
                  'untuk aplikasi ini di pengaturan sistem.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Nanti saja'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Buka Pengaturan'),
              ),
            ],
          ),
        );
        if (goToSettings == true) {
          await NotificationService.instance.requestExactAlarmPermission();
        }
      }

      await _applyReminder();
    } else {
      await NotificationService.instance.cancelStudyReminder();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyActive, value);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Pengingat diaktifkan setiap hari jam ${_selectedTime.format(context)}'
              : 'Pengingat dimatikan',
        ),
        backgroundColor: _NotifColors.primary,
      ),
    );
  }

  Future<void> _applyReminder() async {
    setState(() => _isSaving = true);
    try {
      // Simpan preferensi DULUAN, sebelum memanggil scheduling.
      // Ini penting: kalau scheduling gagal/throw, pilihan jam user
      // tetap tersimpan dan tidak "balik" ke default saat app dibuka lagi.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyHour, _selectedTime.hour);
      await prefs.setInt(_prefsKeyMinute, _selectedTime.minute);

      await NotificationService.instance.scheduleDailyStudyReminder(
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        title: 'Waktunya Lanjut Belajar! 📚',
        body:
        'Yuk, buka aplikasinya dan lanjutkan progres belajarmu hari ini.',
      );
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menjadwalkan pengingat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _NotifColors.background,
      appBar: AppBar(
        backgroundColor: _NotifColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: _NotifColors.textDark),
        title: const Text(
          'Pengingat Belajar',
          style: TextStyle(
            color: _NotifColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: _NotifColors.primary),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 18),
            _buildTimeCard(),
            const SizedBox(height: 18),
            const Text(
              'Pengingat akan muncul setiap hari di jam yang kamu pilih, '
                  'meski aplikasi sedang tidak dibuka.',
              style: TextStyle(
                fontSize: 12,
                color: _NotifColors.textFaint,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _NotifColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _NotifColors.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _reminderActive
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_outlined,
              color: _NotifColors.primary,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reminderActive ? 'Pengingat aktif' : 'Pengingat nonaktif',
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: _NotifColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _reminderActive
                      ? 'Setiap hari jam ${_selectedTime.format(context)}'
                      : 'Nyalakan untuk mulai diingatkan belajar',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _NotifColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _isSaving
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _NotifColors.primary,
            ),
          )
              : Switch(
            value: _reminderActive,
            activeColor: _NotifColors.primary,
            onChanged: _onToggleActive,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _NotifColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _NotifColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded,
                color: _NotifColors.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jam pengingat',
                    style: TextStyle(
                      fontSize: 12,
                      color: _NotifColors.textFaint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _selectedTime.format(context),
                    style: const TextStyle(
                      fontSize: 16,
                      color: _NotifColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _NotifColors.textFaint),
          ],
        ),
      ),
    );
  }
}