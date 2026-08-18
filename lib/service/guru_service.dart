import 'package:supabase_flutter/supabase_flutter.dart';

/// Service khusus untuk halaman Guru.
/// Semua query di sini otomatis difilter berdasarkan `kelas` milik guru
/// yang sedang login, supaya guru hanya bisa melihat siswa & nilai
/// dari kelas yang dia ampu — bukan semua siswa di sekolah.
///
/// Kolom `kelas` pada baris guru boleh berisi LEBIH DARI SATU kelas,
/// disimpan comma-separated (mis. "8A,8B,8C") — lihat
/// SiswaServices.normalizeKelas() untuk gimana formatnya dijaga tetap
/// konsisten saat disimpan.
///
/// CATATAN KEAMANAN: filter di bawah ini terjadi di sisi client (app).
/// Ini cukup untuk UX, tapi supaya benar-benar aman (guru tidak bisa
/// akses data siswa lain lewat cara lain), tambahkan juga RLS Policy
/// di Supabase pada tabel `siswa` dan `hasil_quiz`, contoh idenya:
///   - siswa: guru boleh SELECT baris dengan kelas ada di antara
///     kelas-kelas milik guru tsb (butuh function security definer,
///     mis. kelas_guru_saya() yang return set of text).
///   - hasil_quiz: guru boleh SELECT baris yang siswa_email-nya ada
///     di antara siswa sekelasnya.
class GuruService {
  final _supabase = Supabase.instance.client;

  /// Ambil data guru yang sedang login (termasuk kolom `kelas`nya)
  /// dari tabel `siswa` (guru & siswa disimpan di tabel yang sama).
  ///
  /// Pakai `ilike` (bukan `eq`) supaya perbandingan email tidak
  /// case-sensitive — menghindari bug "guru tidak ketemu" akibat beda
  /// huruf besar/kecil antara auth.email() dan kolom email di database.
  Future<Map<String, dynamic>?> getGuruSaya() async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.email == null) return null;

    final data = await _supabase
        .from('siswa')
        .select()
        .ilike('email', user.email!) // ← case-insensitive match
        .eq('role', 'guru')
        .maybeSingle();

    return data;
  }

  /// Ambil daftar siswa yang berada di SALAH SATU kelas yang diampu
  /// guru ini (guru bisa mengampu lebih dari 1 kelas).
  Future<List<Map<String, dynamic>>> getSiswaSaya() async {
    final guru = await getGuruSaya();
    if (guru == null) return [];

    // Pecah "8A,8B,8C" jadi {"8a", "8b", "8c"} (lowercase, untuk
    // dibandingkan case-insensitive).
    final kelasGuruRaw = (guru['kelas'] as String?) ?? '';
    final kelasGuruSet = kelasGuruRaw
        .split(',')
        .map((k) => k.trim().toLowerCase())
        .where((k) => k.isNotEmpty)
        .toSet();

    if (kelasGuruSet.isEmpty) return [];

    // Ambil semua siswa, lalu cocokkan kelas secara case-insensitive
    // di sisi Dart. Ini sengaja TIDAK pakai `.ilike('kelas', ...)`
    // karena ilike memperlakukan karakter '_' dan '%' sebagai wildcard
    // pattern-matching, bukan exact match — kalau nama kelas mengandung
    // karakter tsb (mis. "8_C"), ilike bisa salah menangkap kelas lain.
    final data = await _supabase
        .from('siswa')
        .select()
        .eq('role', 'siswa')
        .order('nama');

    final semuaSiswa = List<Map<String, dynamic>>.from(data);

    return semuaSiswa.where((s) {
      final kelasSiswa = (s['kelas'] as String?)?.trim().toLowerCase();
      if (kelasSiswa == null || kelasSiswa.isEmpty) return false;
      return kelasGuruSet.contains(kelasSiswa);
    }).toList();
  }

  /// Ambil nilai quiz seluruh siswa di kelas-kelas yang diampu guru ini.
  /// Caranya: ambil dulu daftar siswa di kelas-kelas tsb (utk dapat
  /// email mereka), lalu ambil hasil_quiz yang siswa_email-nya ada di
  /// daftar itu.
  Future<List<Map<String, dynamic>>> getNilaiSiswaSaya() async {
    final siswaSaya = await getSiswaSaya();
    if (siswaSaya.isEmpty) return [];

    final emailList = siswaSaya
        .map((s) => s['email'] as String?)
        .whereType<String>()
        .toList();

    if (emailList.isEmpty) return [];

    final data = await _supabase
        .from('hasil_quiz')
        .select()
        .inFilter('siswa_email', emailList)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Nilai quiz milik satu siswa tertentu (dipakai dari halaman Siswa
  /// Saya -> tap siswa -> lihat detail nilainya).
  Future<List<Map<String, dynamic>>> getNilaiBySiswaEmail(String email) async {
    final data = await _supabase
        .from('hasil_quiz')
        .select()
        .ilike('siswa_email', email) // ← case-insensitive juga di sini
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }
}