class OrganModel {
  final String id;
  final int pertemuanId;
  final String nama;
  final String sistemOrgan;
  final String fungsi;
  final String deskripsi;
  final String faktaMenarik;
  final String? modelUrl;

  OrganModel({
    required this.id,
    required this.pertemuanId,
    required this.nama,
    required this.sistemOrgan,
    required this.fungsi,
    required this.deskripsi,
    required this.faktaMenarik,
    this.modelUrl,
  });

  factory OrganModel.fromJson(Map<String, dynamic> json) => OrganModel(
    id: json['id'],
    pertemuanId: json['pertemuan_id'],
    nama: json['nama'] ?? '',
    sistemOrgan: json['sistem_organ'] ?? '',
    fungsi: json['fungsi'] ?? '',
    deskripsi: json['deskripsi'] ?? '',
    faktaMenarik: json['fakta_menarik'] ?? '',
    modelUrl: json['model_url'],
  );

  Map<String, dynamic> toJson() => {
    'pertemuan_id': pertemuanId,
    'nama': nama,
    'sistem_organ': sistemOrgan,
    'fungsi': fungsi,
    'deskripsi': deskripsi,
    'fakta_menarik': faktaMenarik,
    'model_url': modelUrl,
  };
}