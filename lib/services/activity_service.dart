import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_log_model.dart'; 

class ActivityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Fungsi untuk mencatat riwayat saat tombol navigasi ditekan
  Future<void> recordNavigation(String placeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      if (userId == null) {
        print('Kritikal: User belum login, riwayat tidak dicatat.');
        return; 
      }

      await _supabase.from('navigation_logs').insert({
        'user_id': userId,
        'place_id': placeId,
      });
      
      print('Log navigasi berhasil dicatat!');
    } catch (e) {
      print('Error saat mencatat navigasi: $e');
    }
  }

  // 2. Fungsi untuk mengambil data riwayat (ditampilkan di Profile)
  Future<List<ActivityLogModel>> getUserActivityLogs() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // SOLUSI: Kita gunakan .select() biasa tanpa JOIN terlebih dahulu
      // agar aplikasi tidak crash dan data riwayat tetap muncul.
      final response = await _supabase
          .from('navigation_logs')
          .select('*, places(name, photo_url)') 
          .eq('user_id', userId)
          .order('created_at', ascending: false); 

      return (response as List)
          .map((log) => ActivityLogModel.fromJson(log))
          .toList();
    } catch (e) {
      // Jika masih error, pesan ini akan muncul di Terminal VS Code Anda
      print('Error mengambil riwayat navigasi: $e');
      return [];
    }
  }
}