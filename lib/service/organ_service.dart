import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganService {
  final _supabase = Supabase.instance.client;

  // ── ORGAN ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getOrganByPertemuan(int pertemuanId) async {
    final res = await _supabase
        .from('organ')
        .select()
        .eq('pertemuan_id', pertemuanId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getAllOrgan() async {
    final res = await _supabase
        .from('organ')
        .select()
        .order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> tambahOrgan(Map<String, dynamic> data) async {
    await _supabase.from('organ').insert(data);
  }

  Future<void> editOrgan(String id, Map<String, dynamic> data) async {
    await _supabase.from('organ').update(data).eq('id', id);
  }

  Future<void> hapusOrgan(String id) async {
    await _supabase.from('organ').delete().eq('id', id);
  }

  // ── STORAGE 3D ────────────────────────────────────────

  Future<String> uploadModel3D(String filePath, String namaOrgan) async {
    final file = File(filePath);
    final fileName =
        '${namaOrgan.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.glb';

    await _supabase.storage
        .from('organ-models')
        .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

    return _supabase.storage.from('organ-models').getPublicUrl(fileName);
  }

  Future<void> deleteModel3D(String modelUrl) async {
    try {
      final fileName = modelUrl.split('/').last;
      await _supabase.storage.from('organ-models').remove([fileName]);
    } catch (_) {}
  }

  // ── PROGRESS ──────────────────────────────────────────

  // Tandai organ sudah dilihat siswa
  Future<void> tandaiSudahDilihat(String organId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('organ_progress').upsert({
      'siswa_id': user.id,
      'organ_id': organId,
    }, onConflict: 'siswa_id,organ_id');
  }

  // Ambil progress: berapa organ sudah dilihat vs total
  Future<Map<String, dynamic>> getProgress() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'sudah': 0, 'total': 0};

    final totalRes = await _supabase.from('organ').select();
    final total = (totalRes as List).length;

    final sudahRes = await _supabase
        .from('organ_progress')
        .select()
        .eq('siswa_id', user.id);
    final sudah = (sudahRes as List).length;

    return {'sudah': sudah, 'total': total};
  }

  // Ambil list organ_id yang sudah dilihat siswa ini
  Future<List<String>> getOrganSudahDilihat() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final res = await _supabase
        .from('organ_progress')
        .select('organ_id')
        .eq('siswa_id', user.id);

    return (res as List).map((e) => e['organ_id'] as String).toList();
  }
}