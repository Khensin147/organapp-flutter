import 'package:supabase_flutter/supabase_flutter.dart';

class QuizService {
  final SupabaseClient _client = Supabase.instance.client;

  // ── KATEGORI ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getKategori() async {
    final data = await _client
        .from('quiz_kategori')
        .select()
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<int> countSoal(String kategoriId) async {
    final data = await _client
        .from('quiz_soal')
        .select('id')
        .eq('kategori_id', kategoriId);
    return List.from(data).length;
  }

  Future<void> tambahKategori({
    required String judul,
    required String deskripsi,
  }) async {
    await _client.from('quiz_kategori').insert({
      'judul': judul,
      'deskripsi': deskripsi,
    });
  }

  Future<void> editKategori({
    required String id,
    required String judul,
    required String deskripsi,
  }) async {
    await _client.from('quiz_kategori').update({
      'judul': judul,
      'deskripsi': deskripsi,
    }).eq('id', id);
  }

  Future<void> hapusKategori(String id) async {
    await _client.from('quiz_kategori').delete().eq('id', id);
  }

  // ── CARI KATEGORI BERDASARKAN SISTEM ORGAN / JUDUL PERTEMUAN ──
  // BARU: dipakai oleh OrganListScreen (_mulaiQuiz) untuk mencari
  // kategori quiz yang judulnya cocok dengan judul pertemuan / sistem
  // organ yang sedang dibuka siswa.
  //
  // Strategi pencarian:
  // 1. Coba exact match dulu (case-insensitive) pakai ilike tanpa '%'.
  // 2. Kalau tidak ketemu, fallback ke partial match (mengandung kata
  //    kunci), supaya tetap toleran terhadap sedikit perbedaan
  //    penulisan judul (misal "Sistem Pernapasan" vs "Pernapasan").
  //
  // Return null kalau memang tidak ada kategori yang cocok sama
  // sekali, supaya UI bisa menampilkan pesan "quiz belum tersedia".
  Future<Map<String, dynamic>?> getKategoriBySistemOrgan(
      String sistemOrgan) async {
    // 1) Exact match (case-insensitive)
    final exact = await _client
        .from('quiz_kategori')
        .select()
        .ilike('judul', sistemOrgan)
        .maybeSingle();

    if (exact != null) return exact;

    // 2) Fallback: partial match (judul kategori mengandung kata kunci)
    final fallback = await _client
        .from('quiz_kategori')
        .select()
        .ilike('judul', '%$sistemOrgan%')
        .limit(1)
        .maybeSingle();

    if (fallback != null) return fallback;

    // 3) Fallback terakhir: kata kunci mengandung judul kategori
    // (menangani kasus judul pertemuan lebih panjang/spesifik,
    // misal pertemuan "Sistem Pernapasan Manusia" vs kategori
    // "Pernapasan").
    final semuaKategori = await getKategori();
    for (final kategori in semuaKategori) {
      final judulKategori = (kategori['judul'] as String?)?.toLowerCase() ?? '';
      if (judulKategori.isNotEmpty &&
          sistemOrgan.toLowerCase().contains(judulKategori)) {
        return kategori;
      }
    }

    return null;
  }

  // ── SOAL ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSoalByKategori(
      String kategoriId) async {
    final data = await _client
        .from('quiz_soal')
        .select()
        .eq('kategori_id', kategoriId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> tambahSoal({
    required String kategoriId,
    required String pertanyaan,
    required String pilihanA,
    required String pilihanB,
    required String pilihanC,
    required String pilihanD,
    required String jawabanBenar,
  }) async {
    await _client.from('quiz_soal').insert({
      'kategori_id': kategoriId,
      'pertanyaan': pertanyaan,
      'pilihan_a': pilihanA,
      'pilihan_b': pilihanB,
      'pilihan_c': pilihanC,
      'pilihan_d': pilihanD,
      'jawaban_benar': jawabanBenar,
    });
  }

  Future<void> editSoal({
    required String id,
    required String pertanyaan,
    required String pilihanA,
    required String pilihanB,
    required String pilihanC,
    required String pilihanD,
    required String jawabanBenar,
  }) async {
    await _client.from('quiz_soal').update({
      'pertanyaan': pertanyaan,
      'pilihan_a': pilihanA,
      'pilihan_b': pilihanB,
      'pilihan_c': pilihanC,
      'pilihan_d': pilihanD,
      'jawaban_benar': jawabanBenar,
    }).eq('id', id);
  }

  Future<void> hapusSoal(String id) async {
    await _client.from('quiz_soal').delete().eq('id', id);
  }

  // ── HASIL QUIZ (NILAI) ────────────────────────────────

  // FIX: sebelumnya pakai .insert(), sehingga setiap kali siswa
  // mengerjakan ulang quiz yang sama, tersimpan baris BARU dan
  // data lama tetap menumpuk (1 siswa bisa punya banyak baris untuk
  // kategori yang sama).
  //
  // Sekarang pakai .upsert() dengan onConflict: 'siswa_email,kategori_id'.
  // Artinya: kalau siswa ini SUDAH PERNAH mengerjakan kategori quiz ini
  // sebelumnya, baris lamanya akan DI-UPDATE (nilai terbaru menggantikan
  // nilai lama) alih-alih menambah baris baru. Kalau ini percobaan
  // pertama untuk kategori tsb, baris baru tetap dibuat seperti biasa.
  //
  // PENTING: supaya ini berfungsi, tabel hasil_quiz di Supabase WAJIB
  // punya UNIQUE CONSTRAINT pada kombinasi (siswa_email, kategori_id).
  // Jalankan SQL berikut sekali di Supabase SQL Editor kalau belum ada:
  //
  //   ALTER TABLE hasil_quiz
  //   ADD CONSTRAINT hasil_quiz_siswa_kategori_unique
  //   UNIQUE (siswa_email, kategori_id);
  //
  Future<void> simpanHasilQuiz({
    required String kategoriId,
    required String judulKategori,
    required int skor,
    required int totalSoal,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception("User belum login");
    }

    final siswaData = await _client
        .from('siswa')
        .select('nama')
        .eq('email', user.email!)
        .maybeSingle();

    final namaSiswa = siswaData?['nama'] ?? user.email!;

    await _client.from('hasil_quiz').upsert(
      {
        'siswa_email': user.email,
        'nama_siswa': namaSiswa,
        'kategori_id': kategoriId,
        'judul_kategori': judulKategori,
        'skor': skor,
        'total_soal': totalSoal,
      },
      onConflict: 'siswa_email,kategori_id',
    );
  }

  Future<List<Map<String, dynamic>>> getHasilQuiz() async {
    final data = await _client
        .from('hasil_quiz')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── HASIL QUIZ MILIK SISWA YANG SEDANG LOGIN ──────────────
  // TAMBAHAN: dipakai oleh LeaderboardScreen (sekarang menjadi halaman
  // "Nilai Saya") untuk menampilkan daftar quiz yang sudah dikerjakan
  // oleh siswa yang sedang login saja, bukan semua siswa.
  Future<List<Map<String, dynamic>>> getHasilQuizSaya() async {
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) return [];

    final data = await _client
        .from('hasil_quiz')
        .select()
        .eq('siswa_email', user.email!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── LEADERBOARD ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final res = await _client
        .from('hasil_quiz')
        .select('nama_siswa, skor, kategori_id');

    final Map<String, Map<String, dynamic>> grouped = {};

    for (final item in res as List) {
      final nama = (item['nama_siswa'] as String?) ?? 'Siswa';
      // ← fix: handle null dan tipe num
      final skor = (item['skor'] as num?)?.toInt() ?? 0;

      if (!grouped.containsKey(nama)) {
        grouped[nama] = {
          'nama_siswa': nama,
          'total_skor': 0,
          'quiz_selesai': 0,
        };
      }
      grouped[nama]!['total_skor'] += skor;
      grouped[nama]!['quiz_selesai'] += 1;
    }

    final result = grouped.values.toList();
    result.sort((a, b) =>
        (b['total_skor'] as int).compareTo(a['total_skor'] as int));

    return result;
  }

  Future<Map<String, dynamic>?> getMyLeaderboard() async {
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) return null;

    final siswaData = await _client
        .from('siswa')
        .select('nama')
        .eq('email', user.email!)
        .maybeSingle();

    if (siswaData == null) return null;
    final nama = siswaData['nama'] as String;

    final hasilRes = await _client
        .from('hasil_quiz')
        .select('skor')
        .eq('nama_siswa', nama);

    final list = hasilRes as List;
    // ← fix: handle null dan tipe num
    final totalSkor = list.fold<int>(
      0,
          (sum, e) => sum + ((e['skor'] as num?)?.toInt() ?? 0),
    );

    return {
      'nama_siswa': nama,
      'total_skor': totalSkor,
      'quiz_selesai': list.length,
    };
  }

  // ── NILAI (untuk admin NilaiScreen) ───────────────────

  Future<List<Map<String, dynamic>>> getAllNilai() async {
    final data = await _client
        .from('hasil_quiz')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }
}