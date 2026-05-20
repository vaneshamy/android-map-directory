import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_model.dart';
import '../models/place_model.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final response = await _client.from('categories').select();
      return (response as List).map((e) => CategoryModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Gagal memuat kategori: $e');
    }
  }

  Future<List<PlaceModel>> fetchPlaces() async {
    try {
      final response = await _client.from('places').select();
      return (response as List).map((e) => PlaceModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Gagal memuat tempat: $e');
    }
  }
}