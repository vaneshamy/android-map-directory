import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  final dynamic place;
  final LatLng userLocation; // Menggunakan LatLng dari latlong2

  const MapScreen({
    super.key,
    required this.place,
    required this.userLocation,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<LatLng> routePoints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getRoute();
  }

  Future<void> _getRoute() async {
    final double userLat = widget.userLocation.latitude;
    final double userLng = widget.userLocation.longitude;
    final double museumLat = double.tryParse(widget.place.lat.toString()) ?? 0.0;
    final double museumLng = double.tryParse(widget.place.lng.toString()) ?? 0.0;

    // Mengambil rute dari API OSRM gratis
    final String url = 'https://router.project-osrm.org/route/v1/driving/$userLng,$userLat;$museumLng,$museumLat?geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];

        setState(() {
          routePoints = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal mengambil rute OSRM: $e");
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double museumLat = double.tryParse(widget.place.lat.toString()) ?? 0.0;
    final double museumLng = double.tryParse(widget.place.lng.toString()) ?? 0.0;
    final LatLng museumLocation = LatLng(museumLat, museumLng);

    return Scaffold(
      appBar: AppBar(
        title: Text('Rute ke ${widget.place.name ?? "Museum"}'),
        backgroundColor: const Color(0xFF3E2723),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.userLocation,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.museum.nusantara',
              ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: Colors.blueAccent,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Marker User (Biru)
                  Marker(
                    point: widget.userLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                  ),
                  // Marker Museum (Merah)
                  Marker(
                    point: museumLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 35),
                  ),
                ],
              ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC8A96B)),
              ),
            ),
        ],
      ),
    );
  }
}