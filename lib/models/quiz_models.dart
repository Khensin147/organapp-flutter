class QuizKategoriModel {
  final String id;
  final String judul;
  final String deskripsi;
  int jumlahSoal; // diisi manual setelah fetch

  QuizKategoriModel({
    required this.id,
    required this.judul,
    required this.deskripsi,
    this.jumlahSoal = 0,
  });

  factory QuizKategoriModel.fromJson(Map<String, dynamic> json) =>
      QuizKategoriModel(
        id: json['id'],
        judul: json['judul'] ?? '',
        deskripsi: json['deskripsi'] ?? '',
      );
}

class QuizSoalModel {
  final String id;
  final String kategoriId;
  final String pertanyaan;
  final String pilihanA;
  final String pilihanB;
  final String pilihanC;
  final String pilihanD;
  final String jawabanBenar; // 'A','B','C','D'

  QuizSoalModel({
    required this.id,
    required this.kategoriId,
    required this.pertanyaan,
    required this.pilihanA,
    required this.pilihanB,
    required this.pilihanC,
    required this.pilihanD,
    required this.jawabanBenar,
  });

  factory QuizSoalModel.fromJson(Map<String, dynamic> json) => QuizSoalModel(
    id: json['id'],
    kategoriId: json['kategori_id'],
    pertanyaan: json['pertanyaan'] ?? '',
    pilihanA: json['pilihan_a'] ?? '',
    pilihanB: json['pilihan_b'] ?? '',
    pilihanC: json['pilihan_c'] ?? '',
    pilihanD: json['pilihan_d'] ?? '',
    jawabanBenar: json['jawaban_benar'] ?? 'A',
  );

  // Ambil list pilihan
  List<String> get pilihan => [pilihanA, pilihanB, pilihanC, pilihanD];

  // Index jawaban benar (0=A, 1=B, 2=C, 3=D)
  int get indexJawabanBenar =>
      ['A', 'B', 'C', 'D'].indexOf(jawabanBenar.toUpperCase());
}