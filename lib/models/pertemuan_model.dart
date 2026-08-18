class PertemuanModel {
  final int id;
  final String namaPertemuan;
  final String judul;
  final String deskripsi;
  final int minggu;
  final bool status;

  PertemuanModel({
    required this.id,
    required this.namaPertemuan,
    required this.judul,
    required this.deskripsi,
    required this.minggu,
    required this.status,
  });

  factory PertemuanModel.fromJson(Map<String, dynamic> json) {
    return PertemuanModel(
      id: json["id"],
      namaPertemuan: json["nama_pertemuan"],
      judul: json["judul"],
      deskripsi: json["deskripsi"] ?? "",
      minggu: json["minggu"],
      status: json["status"],
    );
  }
}