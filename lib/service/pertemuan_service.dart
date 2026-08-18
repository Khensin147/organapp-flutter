import 'package:supabase_flutter/supabase_flutter.dart';

class PertemuanService {

  final supabase = Supabase.instance.client;

  Future<List> getPertemuan() async {

    final data = await supabase
        .from("pertemuan")
        .select()
        .order("minggu");

    return data;
  }

  Future insertPertemuan({

    required String namaPertemuan,
    required String judul,
    required String deskripsi,
    required int minggu,

  }) async {

    await supabase.from("pertemuan").insert({

      "nama_pertemuan": namaPertemuan,
      "judul": judul,
      "deskripsi": deskripsi,
      "minggu": minggu,
      "status": false,

    });

  }

  // ── Method baru: update pertemuan yang sudah ada ──
  Future updatePertemuan({

    required int id,
    required String namaPertemuan,
    required String judul,
    required String deskripsi,
    required int minggu,

  }) async {

    await supabase
        .from("pertemuan")
        .update({

      "nama_pertemuan": namaPertemuan,
      "judul": judul,
      "deskripsi": deskripsi,
      "minggu": minggu,

    })
        .eq("id", id);

  }

  Future deletePertemuan(int id) async {

    await supabase
        .from("pertemuan")
        .delete()
        .eq("id", id);

  }

}