import 'package:supabase_flutter/supabase_flutter.dart';

class SiswaServices {
  final supabase = Supabase.instance.client;

  // ── NORMALISASI KELAS ──────────────────────────────────────────────────
  // Kolom 'kelas' bisa berisi SATU kelas (untuk siswa, mis. "8A") atau
  // BEBERAPA kelas dipisah koma (untuk guru yang mengampu lebih dari
  // satu kelas, mis. "8A,8B,8C").
  //
  // Fungsi ini menormalisasi tiap bagian: trim -> uppercase -> hapus
  // spasi, lalu membuang duplikat dan mengurutkannya, supaya "8a, 8A,
  // 8b" selalu tersimpan sebagai "8A,8B" — konsisten siapa pun yang
  // input dan dalam urutan apa pun.
  //
  // Dipakai di SEMUA tempat yang menyimpan kolom 'kelas' (tambahSiswa,
  // tambahGuru, editSiswa) supaya data yang masuk selalu konsisten,
  // dan filter guru (GuruService.getSiswaSaya()) bisa match dengan benar.
  static String normalizeKelas(String raw) {
    final bagian = raw
        .split(',')
        .map((k) => k.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ''))
        .where((k) => k.isNotEmpty)
        .toSet() // buang duplikat, mis. "8A,8A" -> {"8A"}
        .toList()
      ..sort();
    return bagian.join(',');
  }

  Future<List> getSiswa() async {
    final data = await supabase
        .from("siswa")
        .select()
        .eq("role", "siswa") // ← fix: supaya guru/admin tidak ikut muncul di daftar siswa
        .order("created_at");
    return data;
  }

  Future<void> tambahSiswa({
    required String nama,
    required String email,
    required String password,
    required String kelas,
    required String username,
  }) async {
    final response = await supabase.functions.invoke(
      'create-user',
      body: {
        'nama': nama,
        'email': email,
        'password': password,
        'kelas': normalizeKelas(kelas), // ← dinormalisasi sebelum dikirim
        'username': username,
        'role': 'siswa', // ← eksplisit, walau default di Edge Function juga 'siswa'
      },
    );

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Gagal menambah siswa';
      throw Exception(error);
    }
  }

  // ── TAMBAH GURU ──────────────────────────────────
  // Sama persis alurnya dengan tambahSiswa(), cuma beda role yang
  // dikirim ke Edge Function 'create-user'. Kolom 'kelas' di sini
  // berarti "kelas yang diampu guru ini" dan BOLEH lebih dari satu,
  // dikirim sebagai string comma-separated (mis. "8A,8B"), dipakai
  // nanti untuk filter siswa & nilai yang boleh dilihat guru tsb.
  Future<void> tambahGuru({
    required String nama,
    required String email,
    required String password,
    required String kelas,
    required String username,
  }) async {
    final response = await supabase.functions.invoke(
      'create-user',
      body: {
        'nama': nama,
        'email': email,
        'password': password,
        'kelas': normalizeKelas(kelas), // ← dinormalisasi sebelum dikirim
        'username': username,
        'role': 'guru',
      },
    );

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Gagal menambah guru';
      throw Exception(error);
    }
  }

  // ── DAFTAR GURU (untuk admin) ────────────────────
  Future<List> getGuru() async {
    final data = await supabase
        .from("siswa")
        .select()
        .eq("role", "guru")
        .order("created_at");
    return data;
  }

  // ── EDIT SISWA / GURU ────────────────────────────
  // FIX: sekarang lewat Edge Function 'update-user' (bukan langsung
  // .update() ke tabel) karena kita menambahkan opsi ganti PASSWORD,
  // dan mengubah password user lain WAJIB pakai service_role key di
  // server — tidak bisa dilakukan langsung dari client.
  //
  // Parameter 'password' OPSIONAL: kirim null / kosongkan kalau admin
  // tidak ingin mengubah password (nama/username/kelas tetap bisa
  // diedit seperti biasa tanpa menyentuh password).
  Future<void> editSiswa({
    required String id,
    required String nama,
    required String kelas,
    required String username,
    String? password,
  }) async {
    final body = <String, dynamic>{
      'id': id,
      'nama': nama,
      'kelas': normalizeKelas(kelas),
      'username': username,
    };

    // Hanya sertakan password kalau memang diisi, supaya Edge Function
    // tahu ini bukan permintaan ganti password.
    if (password != null && password.trim().isNotEmpty) {
      body['password'] = password.trim();
    }

    final response = await supabase.functions.invoke(
      'update-user',
      body: body,
    );

    if (response.status != 200) {
      final error = response.data['error'] ?? 'Gagal mengupdate data';
      throw Exception(error);
    }
  }

  // FIX: sebelumnya cuma hapus row di tabel siswa, sehingga data terkait
  // (hasil_quiz, organ_progress) jadi "yatim" dan tetap muncul di
  // Leaderboard / Progress meskipun siswanya sudah dihapus.
  // Sekarang data terkait dihapus dulu sebelum hapus siswanya.
  //
  // CATATAN: method ini juga aman dipakai untuk hapus akun guru,
  // karena guru & siswa sama-sama row di tabel 'siswa'.
  Future<void> hapusSiswa(String id) async {
    // Ambil dulu email siswa yang mau dihapus, karena hasil_quiz
    // disimpan berdasarkan siswa_email (bukan siswa_id).
    final siswa = await supabase
        .from('siswa')
        .select('email')
        .eq('id', id)
        .maybeSingle();

    // Hapus riwayat quiz siswa ini (berdasarkan email)
    if (siswa != null && siswa['email'] != null) {
      await supabase
          .from('hasil_quiz')
          .delete()
          .eq('siswa_email', siswa['email']);
    }

    // Hapus progress organ siswa ini (berdasarkan siswa_id)
    // Aman dipanggil walau tabel/kolomnya kosong untuk siswa ini.
    await supabase.from('organ_progress').delete().eq('siswa_id', id);

    // Terakhir, hapus row siswanya sendiri
    await supabase.from("siswa").delete().eq("id", id);

    // CATATAN: baris di atas hanya menghapus data di tabel "siswa".
    // Akun LOGIN siswa ini (di Supabase Auth / auth.users) TIDAK ikut
    // terhapus, karena menghapus user Auth butuh service_role key yang
    // tidak aman dipakai langsung dari sisi aplikasi (client).
    //
    // Kalau mau akun login-nya beneran terhapus juga, cara paling aman
    // adalah bikin Edge Function baru (mirip 'create-user' yang sudah
    // ada), misalnya 'delete-user', lalu panggil di sini seperti:
    //
    // await supabase.functions.invoke('delete-user', body: {'id': id});
    //
    // Edge Function itu yang nanti memanggil
    // supabase.auth.admin.deleteUser(id) di sisi server menggunakan
    // service_role key. Kalau kamu mau, kasih tau aku dan aku bantu
    // buatkan Edge Function-nya.
  }
}