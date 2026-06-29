import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; 
import '../models/favorite_model.dart';

class FavoriteService {
  final _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  // Ambil semua favorit user beserta data place-nya (join)
 Future<List<FavoriteModel>> getMyFavorites() async {
  try {
    if (_userId == null) return [];

    final res = await _client
        .from('favorites')
        .select('''
          id,
          place_id,
          user_id,
          created_at,
          places (
            id,
            name,
            address,
            photo_url,
            rating,
            open_hours,
            lat,
            lng,
            description
          )
        ''')
        .eq('user_id', _userId!)
        .order('created_at', ascending: false);

    debugPrint(res.toString());

    return (res as List)
        .map((e) => FavoriteModel.fromJson(e))
        .toList();
  } catch (e) {
    debugPrint("ERROR FAVORITE: $e");
    return [];
  }
}
  // Cek apakah place sudah difavoritkan
  Future<bool> isFavorited(String placeId) async {
    try {
      if (_userId == null) return false;

      final res = await _client
          .from('favorites')
          .select('id')
          .eq('user_id', _userId!)
          .eq('place_id', placeId)
          .maybeSingle();

      return res != null;
    } catch (e) {
      return false;
    }
  }

  // Toggle: tambah atau hapus favorit
  Future<bool> toggleFavorite(String placeId) async {
    try {
      if (_userId == null) return false;

      final existing = await _client
          .from('favorites')
          .select('id')
          .eq('user_id', _userId!)
          .eq('place_id', placeId)
          .maybeSingle();

      if (existing != null) {
        await _client
            .from('favorites')
            .delete()
            .eq('id', existing['id']);
        return false; // sudah dihapus
      } else {
        await _client.from('favorites').insert({
          'user_id': _userId!,
          'place_id': placeId,
        });
        return true; // baru ditambahkan
      }
    } catch (e) {
      debugPrint('toggleFavorite error: $e');
      return false;
    }
  }

  // Hapus favorit berdasarkan favorite ID
  Future<void> removeFavorite(String favoriteId) async {
    try {
      await _client.from('favorites').delete().eq('id', favoriteId);
    } catch (e) {
      debugPrint('removeFavorite error: $e');
    }
  }
}