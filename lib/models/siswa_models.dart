class SiswaModel {
  final String id;
  final String nama;
  final String email;
  final String kelas; // ← bisa berisi beberapa kelas, dipisah koma: "8A,8B,8C"
  final String username;
  final String createdAt;

  SiswaModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.kelas,
    required this.username,
    required this.createdAt,
  });

  factory SiswaModel.fromJson(Map<String, dynamic> json) {
    return SiswaModel(
      id: json["id"],
      nama: json["nama"],
      email: json["email"],
      kelas: json["kelas"] ?? "",
      username: json["username"] ?? "",
      createdAt: json["created_at"] ?? "",
    );
  }

  /// Pecah kolom `kelas` (comma-separated) jadi List<String> yang bersih
  /// (sudah di-trim, kosong dibuang). Dipakai terutama untuk guru yang
  /// bisa mengampu lebih dari satu kelas, mis. kelas = "8A,8B" ->
  /// ["8A", "8B"]. Untuk siswa (yang cuma punya 1 kelas), ini tetap
  /// aman dan hanya menghasilkan list berisi 1 elemen.
  List<String> get kelasList => kelas
      .split(',')
      .map((k) => k.trim())
      .where((k) => k.isNotEmpty)
      .toList();

  /// Versi tampilan yang enak dibaca, mis. "8A, 8B, 8C".
  String get kelasDisplay => kelasList.join(', ');
}