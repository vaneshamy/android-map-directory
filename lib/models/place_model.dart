class PlaceModel {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? photoUrl;

  PlaceModel({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.photoUrl,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      photoUrl: json['photo_url'] as String?,
    );
  }
}