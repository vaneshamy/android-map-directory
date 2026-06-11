import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  final dynamic place;
  final LatLng userLocation;

  const MapScreen({
    super.key,
    required this.place,
    required this.userLocation,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Set<Polyline> _polylines = {};
  List<LatLng> polylineCoordinates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getRoutePolyline();
  }

  Future<void> _getRoutePolyline() async {
    final double userLat = widget.userLocation.latitude;
    final double userLng = widget.userLocation.longitude;
    
    // Ambil lat & lng museum secara aman dari objek model
    final double museumLat = double.tryParse(widget.place.lat.toString()) ?? 0.0;
    final double museumLng = double.tryParse(widget.place.lng.toString()) ?? 0.0;

    // Menggunakan OSRM Router API Gratisan untuk menggambar garis rute jalan
    final String url = 'https://router.project-osrm.org/route/v1/driving/$userLng,$userLat;$museumLng,$museumLat?geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];

        setState(() {
          polylineCoordinates.clear();
          for (var coord in coordinates) {
            polylineCoordinates.add(LatLng(coord[1], coord[0]));
          }
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route_to_museum'),
              points: polylineCoordinates,
              color: Colors.blueAccent,
              width: 6,
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal memuat polylines rute OSRM: $e");
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
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.userLocation,
              zoom: 13,
            ),
            polylines: _polylines,
            markers: {
              // Marker posisi HP User (Biru)
              Marker(
                markerId: const MarkerId('user_position'),
                position: widget.userLocation,
                infoWindow: const InfoWindow(title: 'Lokasi Saya'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              ),
              // Marker posisi lokasi Museum (Merah)
              Marker(
                markerId: const MarkerId('museum_position'),
                position: museumLocation,
                infoWindow: InfoWindow(title: widget.place.name ?? 'Museum'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            },
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