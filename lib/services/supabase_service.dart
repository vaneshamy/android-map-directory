import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_model.dart';
import '../models/place_model.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  // =========================
  // FETCH CATEGORIES
  // =========================
  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final response = await client
          .from('categories')
          .select()
          .order('name');

      debugPrint('CATEGORIES RESPONSE: $response');

      return (response as List)
          .map((json) => CategoryModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('ERROR FETCH CATEGORIES: $e');
      return [];
    }
  }

  // =========================
  // FETCH PLACES
  // =========================
  Future<List<PlaceModel>> fetchPlaces({
    String? categoryId,
    String? search,
  }) async {
    try {
      dynamic query = client.from('places').select();

      // filter category
      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category_id', categoryId);
      }

      // search
      if (search != null && search.isNotEmpty) {
        query = query.ilike('name', '%$search%');
      }

      final response = await query.order('name');

      debugPrint('PLACES RESPONSE: $response');

      return (response as List)
          .map((json) => PlaceModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('ERROR FETCH PLACES: $e');
      return [];
    }
  }

  // =========================
  // FETCH DETAIL
  // =========================
  Future<PlaceModel?> fetchPlaceById(String id) async {
    try {
      final response = await client
          .from('places')
          .select()
          .eq('id', id)
          .single();

      return PlaceModel.fromJson(response);
    } catch (e) {
      debugPrint('ERROR FETCH DETAIL: $e');
      return null;
    }
  }
}