class FavoriteModel {
  final String id;
  final String placeId;
  final String userId;
  final String? placeName;
  final String? placeAddress;
  final String? placeCity;
  final String? placePhotoUrl;
  final double? placeRating;
  final String? placeOpenHours;
  final double? placeLat;
  final double? placeLng;
  final String? placeDescription;
  final String? placeOpenHoursText;
  final DateTime? createdAt;

  FavoriteModel({
    required this.id,
    required this.placeId,
    required this.userId,
    this.placeName,
    this.placeAddress,
    this.placeCity,
    this.placePhotoUrl,
    this.placeRating,
    this.placeOpenHours,
    this.placeLat,
    this.placeLng,
    this.placeDescription,
    this.placeOpenHoursText,
    this.createdAt,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    final place = json['places'] as Map<String, dynamic>?;
    return FavoriteModel(
      id: json['id'].toString(),
      placeId: json['place_id'].toString(),
      userId: json['user_id'].toString(),
      placeName: place?['name'] as String?,
      placeAddress: place?['address'] as String?,
      placeCity: place?['city'] as String?,
      placePhotoUrl: place?['photo_url'] as String?,
      placeRating: (place?['rating'] as num?)?.toDouble(),
      placeOpenHours: place?['open_hours'] as String?,
      placeLat: (place?['lat'] as num?)?.toDouble(),
      placeLng: (place?['lng'] as num?)?.toDouble(),
      placeDescription: place?['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  String get ratingText =>
      placeRating != null ? placeRating!.toStringAsFixed(1) : '—';
}