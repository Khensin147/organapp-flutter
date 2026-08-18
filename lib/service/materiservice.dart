import 'package:organappfr/models/organ_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MateriService {

  final supabase=Supabase.instance.client;

  Future<List<OrganModel>> getMateri(
      String sistem) async {

    final response=await supabase

        .from("materi")

        .select()

        .eq("sistem",sistem);

    return response
        .map<OrganModel>(
          (item)=>OrganModel.fromJson(item),
    ).toList();
  }

}