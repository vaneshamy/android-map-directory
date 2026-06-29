class ReviewModel {
  final String id;
  final String placeId;
  final String userId;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatarUrl;
  final String? placeName;
  final String? placePhotoUrl;

  ReviewModel({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.userName,
    this.userAvatarUrl,
    this.placeName,
    this.placePhotoUrl,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      placeId: json['place_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      // DIPERBAIKI: Membaca kolom 'user_name' yang dikirim dari database
      // Jika null (seperti ulasan manual Anda sebelumnya), baru pakai 'Pengunjung'
      userName: json['user_name']?.toString() ?? 'Pengunjung', 
      userAvatarUrl: null,
      placeName: json['places']?['name']?.toString() ?? json['place']?['name']?.toString(),
      placePhotoUrl: json['places']?['photo_url']?.toString() ?? json['place']?['photo_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'place_id': placeId,
      'user_id': userId,
      'rating': rating,
      'comment': comment,
      'user_name': userName, // Ditambahkan agar sinkron dengan database
    };
  }

  ReviewModel copyWith({
    String? id,
    String? placeId,
    String? userId,
    int? rating,
    String? comment,
    DateTime? createdAt,
    String? userName,
    String? userAvatarUrl,
    String? placeName,
    String? placePhotoUrl,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      placeName: placeName ?? this.placeName,
      placePhotoUrl: placePhotoUrl ?? this.placePhotoUrl,
    );
  }
}