class ActivityLogModel {
  final String id;
  final String userId;
  final String placeId;
  final DateTime createdAt;
  
  final String? placeName;
  final String? placeImageUrl;

  ActivityLogModel({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.createdAt,
    this.placeName,
    this.placeImageUrl,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    final placeData = json['places']; 

    return ActivityLogModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      placeId: json['place_id']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
          
      // PERBAIKAN DI SINI: Menggunakan 'photo_url' sesuai gambar database Anda
      placeName: placeData != null ? placeData['name']?.toString() : 'Tempat Tidak Diketahui',
      placeImageUrl: placeData != null ? placeData['photo_url']?.toString() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'place_id': placeId,
    };
  }
}