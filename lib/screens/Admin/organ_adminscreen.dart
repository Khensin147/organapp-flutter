import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:organappfr/models/organ_models.dart';
import 'package:organappfr/models/pertemuan_model.dart';
import 'package:organappfr/service/organ_service.dart';
import 'package:organappfr/service/pertemuan_service.dart';

class OrganAdminScreen extends StatefulWidget {
  const OrganAdminScreen({super.key});

  @override
  State<OrganAdminScreen> createState() => _OrganAdminScreenState();
}

class _OrganAdminScreenState extends State<OrganAdminScreen> {
  final OrganService _organService = OrganService();
  final PertemuanService _pertemuanService = PertemuanService();

  List<OrganModel> _organList = [];
  List<PertemuanModel> _pertemuanList = [];
  bool _isLoading = false;
  PertemuanModel? _selectedFilterPertemuan;

  final _namaC = TextEditingController();
  final _sistemC = TextEditingController();
  final _fungsiC = TextEditingController();
  final _deskripsiC = TextEditingController();
  final _faktaC = TextEditingController();

  PertemuanModel? _selectedPertemuan;
  String? _selectedFilePath;   // path lokal file .glb
  String? _selectedFileName;   // nama file untuk ditampilkan
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _namaC.dispose();
    _sistemC.dispose();
    _fungsiC.dispose();
    _deskripsiC.dispose();
    _faktaC.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final pertemuanData = await _pertemuanService.getPertemuan();
      final organData = await _organService.getAllOrgan();
      setState(() {
        _pertemuanList =
            pertemuanData.map((e) => PertemuanModel.fromJson(e)).toList();
        _organList =
            organData.map((e) => OrganModel.fromJson(e)).toList();
      });
    } catch (e) {
      _showSnackbar("Gagal memuat: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<OrganModel> get _filteredOrgan {
    if (_selectedFilterPertemuan == null) return _organList;
    return _organList
        .where((o) => o.pertemuanId == _selectedFilterPertemuan!.id)
        .toList();
  }

  void _clearForm() {
    _namaC.clear();
    _sistemC.clear();
    _fungsiC.clear();
    _deskripsiC.clear();
    _faktaC.clear();
    _selectedPertemuan = null;
    _selectedFilePath = null;
    _selectedFileName = null;
  }

  Future<void> _pickFile(StateSetter setModalState) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final name = result.files.single.name;
    final ext = name.split('.').last.toLowerCase();

    if (ext != 'glb') {
      _showSnackbar("File harus berformat .glb!", isError: true);
      return;
    }

    setModalState(() {
      _selectedFilePath = path;
      _selectedFileName = name;
    });
  }

  void _showFormDialog({OrganModel? organ}) {
    final isEdit = organ != null;

    if (isEdit) {
      _namaC.text = organ.nama;
      _sistemC.text = organ.sistemOrgan;
      _fungsiC.text = organ.fungsi;
      _deskripsiC.text = organ.deskripsi;
      _faktaC.text = organ.faktaMenarik;
      _selectedPertemuan = _pertemuanList
          .firstWhere((p) => p.id == organ.pertemuanId,
          orElse: () => _pertemuanList.first);
      _selectedFilePath = null;
      _selectedFileName = organ.modelUrl != null
          ? organ.modelUrl!.split('/').last
          : null;
    } else {
      _clearForm();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollCtrl) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      isEdit ? "Edit materi" : "Tambah materi",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  children: [
                    const Text("Tugas",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<PertemuanModel>(
                      value: _selectedPertemuan,
                      isExpanded: true,
                      hint: const Text("Pilih tugas"),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.calendar_month),
                      ),
                      items: _pertemuanList
                          .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text("${p.namaPertemuan} — ${p.judul}",
                            overflow: TextOverflow.ellipsis),
                      ))
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => _selectedPertemuan = val),
                    ),
                    const SizedBox(height: 12),

                    _buildField(_namaC, "Nama Organ", Icons.label_outline),
                    _buildField(_sistemC, "Sistem Organ", Icons.account_tree_outlined),
                    _buildField(_fungsiC, "Fungsi", Icons.task_alt, maxLines: 2),
                    _buildField(_deskripsiC, "Deskripsi", Icons.description_outlined, maxLines: 4),
                    _buildField(_faktaC, "Fakta Menarik", Icons.lightbulb_outline, maxLines: 3),

                    const SizedBox(height: 4),
                    const Text(
                      "Model 3D (.glb)",
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _pickFile(setModalState),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _selectedFileName != null
                              ? Colors.teal.shade50
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedFileName != null
                                ? Colors.teal
                                : Colors.grey.shade300,
                            width: _selectedFileName != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.view_in_ar_rounded,
                              size: 32,
                              color: _selectedFileName != null
                                  ? Colors.teal
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFileName ?? "Pilih file .glb",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _selectedFileName != null
                                          ? Colors.teal.shade700
                                          : Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedFilePath != null
                                        ? "File baru dipilih — akan diupload"
                                        : isEdit && _selectedFileName != null
                                        ? "File sudah ada — tap untuk ganti"
                                        : "Format: .glb | Tap untuk pilih file",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _selectedFilePath != null
                                  ? Icons.check_circle
                                  : Icons.upload_file,
                              color: _selectedFilePath != null
                                  ? Colors.teal
                                  : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_selectedFilePath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 13, color: Colors.teal.shade400),
                            const SizedBox(width: 4),
                            Text(
                              "File akan diupload saat kamu tekan Simpan",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal.shade400),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    StatefulBuilder(
                      builder: (ctx, setBtnState) => ElevatedButton.icon(
                        onPressed: _isUploading
                            ? null
                            : () async {
                          setBtnState(() => _isUploading = true);
                          await _submitForm(isEdit, organ);
                          setBtnState(() => _isUploading = false);
                        },
                        icon: _isUploading
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Icon(isEdit ? Icons.save : Icons.add),
                        label: Text(_isUploading
                            ? "Mengupload..."
                            : isEdit
                            ? "Simpan Perubahan"
                            : "Tambah materi"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String label, IconData icon,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Future<void> _submitForm(bool isEdit, OrganModel? organ) async {
    if (_selectedPertemuan == null) {
      _showSnackbar("Pilih tugas dulu!", isError: true);
      return;
    }
    if (_namaC.text.trim().isEmpty) {
      _showSnackbar("Nama organ wajib diisi!", isError: true);
      return;
    }

    try {
      String? modelUrl = organ?.modelUrl;

      if (_selectedFilePath != null) {
        if (isEdit && organ?.modelUrl != null) {
          await _organService.deleteModel3D(organ!.modelUrl!);
        }
        modelUrl = await _organService.uploadModel3D(
          _selectedFilePath!,
          _namaC.text.trim(),
        );
      }

      final data = {
        'pertemuan_id': _selectedPertemuan!.id,
        'nama': _namaC.text.trim(),
        'sistem_organ': _sistemC.text.trim(),
        'fungsi': _fungsiC.text.trim(),
        'deskripsi': _deskripsiC.text.trim(),
        'fakta_menarik': _faktaC.text.trim(),
        'model_url': modelUrl,
      };

      if (isEdit && organ != null) {
        await _organService.editOrgan(organ.id, data);
        _showSnackbar("Organ berhasil diupdate!");
      } else {
        await _organService.tambahOrgan(data);
        _showSnackbar("Organ berhasil ditambahkan!");
      }

      if (mounted) Navigator.pop(context);
      _loadAll();
    } catch (e) {
      _showSnackbar("Gagal: $e", isError: true);
    }
  }

  Future<void> _hapusOrgan(OrganModel organ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Organ"),
        content: Text("Yakin hapus ${organ.nama}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Hapus",
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        if (organ.modelUrl != null) {
          await _organService.deleteModel3D(organ.modelUrl!);
        }
        await _organService.hapusOrgan(organ.id);
        _showSnackbar("Organ dihapus!");
        _loadAll();
      } catch (e) {
        _showSnackbar("Gagal hapus: $e", isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  String _namaPertemuan(int pertemuanId) {
    try {
      return _pertemuanList
          .firstWhere((p) => p.id == pertemuanId)
          .namaPertemuan;
    } catch (_) {
      return "—";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelola Materi"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          onPressed: _pertemuanList.isEmpty ? null : () => _showFormDialog(),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text("Tambah Materi"),
        ),
      ),
      body: Column(
        children: [
          if (_pertemuanList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: DropdownButtonFormField<PertemuanModel?>(
                value: _selectedFilterPertemuan,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: "Filter Tugas",
                  prefixIcon: const Icon(Icons.filter_list),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text("Semua Tugas")),
                  ..._pertemuanList.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.namaPertemuan,
                        overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (val) =>
                    setState(() => _selectedFilterPertemuan = val),
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrgan.isEmpty
                ? Center(
              child: Text(
                _pertemuanList.isEmpty
                    ? "Tambah tugas dulu\nsebelum menambah organ."
                    : "Belum ada organ.\nTambah dengan tombol +",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(12, 8, 12, 80),
                itemCount: _filteredOrgan.length,
                itemBuilder: (context, index) {
                  final organ = _filteredOrgan[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade50,
                        child: Text(
                          organ.nama[0].toUpperCase(),
                          style: TextStyle(
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(organ.nama,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(
                                top: 4, bottom: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: Text(
                              _namaPertemuan(organ.pertemuanId),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal.shade700,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(organ.sistemOrgan,
                              style:
                              const TextStyle(fontSize: 12)),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_in_ar_rounded,
                            size: 20,
                            color: organ.modelUrl != null
                                ? Colors.teal
                                : Colors.grey.shade300,
                          ),
                          IconButton(
                            onPressed: () =>
                                _showFormDialog(organ: organ),
                            icon: const Icon(Icons.edit,
                                color: Colors.blue),
                          ),
                          IconButton(
                            onPressed: () => _hapusOrgan(organ),
                            icon: const Icon(Icons.delete,
                                color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}