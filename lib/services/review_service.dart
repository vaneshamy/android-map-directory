import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review_model.dart';

class ReviewService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<ReviewModel>> getReviewsByPlace(String placeId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select() 
          .eq('place_id', placeId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReviewModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('🚨 Error GET Reviews: $e');
      return [];
    }
  }

  Future<ReviewModel?> getMyReview(String placeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('reviews')
          .select()
          .eq('place_id', placeId)
          .eq('user_id', userId)
          .order('created_at', ascending: false) 
          .limit(1) 
          .maybeSingle();

      if (response == null) return null;
      return ReviewModel.fromJson(response);
    } catch (e) {
      debugPrint('🚨 Error GET My Review: $e');
      return null;
    }
  }

  Future<List<ReviewModel>> getMyAllReviews() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('reviews')
          .select('*, places(name, photo_url)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReviewModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('🚨 Error GET My All Reviews: $e');
      return [];
    }
  }


  Future<void> createReview({
    required String placeId,
    required int rating,
    required String comment,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      // Mengambil email user
      final String userEmail = user.email ?? 'Pengunjung';
      
      // Mengambil nama depan sebelum karakter '@'
      final String emailName = userEmail.contains('@') 
          ? userEmail.split('@')[0] 
          : userEmail;

      await _supabase.from('reviews').insert({
        'place_id': placeId,
        'user_id': user.id,
        'rating': rating,
        'comment': comment.trim(),
        'user_name': emailName, // Menyimpan potongan nama email ke database
      });
    } catch (e) {
      debugPrint('🚨 Error Create Review: $e');
      rethrow;
    }
  }

  Future<void> updateReview({
    required String reviewId,
    required int rating,
    required String comment,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User belum login');

      await _supabase
          .from('reviews')
          .update({'rating': rating, 'comment': comment.trim()})
          .eq('id', reviewId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('🚨 Error Update Review: $e');
      rethrow;
    }
  }

  Future<void> deleteReview(String reviewId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User belum login');

      await _supabase
          .from('reviews')
          .delete()
          .eq('id', reviewId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('🚨 Error Delete Review: $e');
      rethrow;
    }
  }

  Future<double> getAverageRating(String placeId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('rating')
          .eq('place_id', placeId);

      if (response == null || (response as List).isEmpty) return 0.0;

      final List<int> ratings = (response as List).map<int>((r) => (r['rating'] as num).toInt()).toList();
      
      final avg = ratings.reduce((a, b) => a + b) / ratings.length;
      return double.parse(avg.toStringAsFixed(1));
    } catch (e) {
      debugPrint('🚨 Error GET Average Rating: $e');
      return 0.0;
    }
  }
}