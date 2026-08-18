import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Service tunggal (singleton) untuk mengurus semua urusan notifikasi:
/// inisialisasi, minta izin, jadwalkan, dan batalkan.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const int studyReminderId = 1;
  static const String _channelId = 'study_reminder_channel';
  static const String _channelName = 'Pengingat Belajar';
  static const String _channelDesc =
      'Notifikasi pengingat waktu belajar harian';

  bool _initialized = false;

  /// Panggil sekali di awal aplikasi (sebelum runApp).
  Future<void> init() async {
    if (_initialized) return;

    // Siapkan data timezone dan set lokasi ke WIB.
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notifikasi di-tap, payload: ${response.payload}');
      },
    );

    // Buat notification channel eksplisit untuk Android 8+.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Minta izin notifikasi biasa (wajib di Android 13+ dan iOS).
  /// PENTING: ini TIDAK mengurus izin exact alarm. Untuk itu pakai
  /// [requestExactAlarmPermission] terpisah, karena di banyak versi
  /// Android user harus di-arahkan ke halaman Settings secara manual.
  Future<bool> requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final bool? androidGranted =
    await androidImpl?.requestNotificationsPermission();

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    final bool? iosGranted = await iosImpl?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  /// Cek apakah app sudah boleh menjadwalkan exact alarm (Android 12+).
  Future<bool> canScheduleExactAlarms() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidImpl?.canScheduleExactNotifications() ?? true;
  }

  /// Buka halaman Settings sistem supaya user bisa mengaktifkan
  /// "Alarms & reminders" / exact alarm secara manual.
  /// Ini WAJIB dipanggil dan ditunggu user toggle manual —
  /// izinnya tidak langsung aktif hanya karena fungsi ini dipanggil.
  Future<void> requestExactAlarmPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestExactAlarmsPermission();
  }

  /// Jadwalkan notifikasi pengingat belajar setiap hari pada jam:menit tertentu.
  /// Otomatis fallback ke mode "inexact" kalau exact alarm belum diizinkan,
  /// supaya scheduling tidak silently gagal / throw.
  Future<void> scheduleDailyStudyReminder({
    required int hour,
    required int minute,
    String title = 'Waktunya Belajar! 📚',
    String body = 'Jangan lupa review materi hari ini.',
  }) async {
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final bool canExact = await canScheduleExactAlarms();

    await _plugin.zonedSchedule(
      id: studyReminderId,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: details,
      androidScheduleMode: canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // ulangi tiap hari
    );

    // Debug: pastikan job benar-benar terdaftar di sistem.
    final pending = await pendingNotifications();
    debugPrint(
      'Reminder dijadwalkan (exact: $canExact). Pending notifications: ${pending.length}',
    );
  }

  Future<void> cancelStudyReminder() async {
    await _plugin.cancel(id: studyReminderId);
  }

  Future<List<PendingNotificationRequest>> pendingNotifications() {
    return _plugin.pendingNotificationRequests();
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}