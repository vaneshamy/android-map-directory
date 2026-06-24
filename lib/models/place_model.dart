class PlaceModel {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? photoUrl;
  final String? categoryId;
  final double? rating;
  final String? description;
  final String? openHours;
  final String? ticketPrice;
  final String? city;
  double? distanceKm;

  PlaceModel({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.photoUrl,
    this.categoryId,
    this.rating,
    this.description,
    this.openHours,
    this.ticketPrice,
    this.city,
    this.distanceKm,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      photoUrl: json['photo_url'] as String?,
      categoryId: json['category_id']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      description: json['description'] as String?,
      openHours: json['open_hours'] as String?,
      ticketPrice: json['ticket_price'] as String?,
      city: json['city'] as String?,
    );
  }

  // DIUBAH: Tidak lagi hardcode '4.5'. Menampilkan rata-rata asli atau '-' jika belum ada ulasan.
  String get ratingText => (rating != null && rating! > 0) ? rating!.toStringAsFixed(1) : '-';

  String get distanceText {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()} m';
    return '${distanceKm!.toStringAsFixed(1)} km';
  }
}