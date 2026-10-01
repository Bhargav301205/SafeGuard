import 'dart:async';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Provides location utilities: current position, reverse geocoding,
/// shareable Google Maps links, and distance calculation.
class MapsService {
  MapsService._();
  static final MapsService instance = MapsService._();

  /// Fetch the current GPS position.
  /// Falls back to network IP geolocation if hardware GPS is blocked by browser policies.
  Future<Position?> getCurrentPosition() async {
    // 1. Try hardware GPS via Geolocator
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        return pos;
      }
    } catch (e) {
      debugPrint('[MapsService] Hardware GPS error: $e');
    }

    // 2. Fallback: Network IP geolocation (works even when browser blocks GPS on HTTP)
    try {
      final res = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          final lat = (data['lat'] as num).toDouble();
          final lon = (data['lon'] as num).toDouble();
          return Position(
            latitude: lat,
            longitude: lon,
            timestamp: DateTime.now(),
            accuracy: 500.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );
        }
      }
    } catch (e) {
      debugPrint('[MapsService] IP fallback geolocation error: $e');
    }

    return null;
  }

  /// Reverse-geocodes [lat]/[lng] to a human-readable address string.
  Future<String> reverseGeocode(double lat, double lng) async {
    if (lat == 0 && lng == 0) return 'Location pending';

    // On Web: use OpenStreetMap Nominatim reverse geocode (free, zero API key)
    if (kIsWeb) {
      try {
        final res = await http.get(
          Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng'),
          headers: {'User-Agent': 'SafeGuard-Emergency-App/1.0'},
        ).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final displayName = data['display_name'];
          if (displayName != null && displayName.toString().isNotEmpty) {
            // Keep it concise: take the first 3 parts of the address
            final parts = displayName.toString().split(', ');
            return parts.take(3).join(', ');
          }
        }
      } catch (e) {
        debugPrint('[MapsService] Web reverse geocode error: $e');
      }
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }

    // On Native mobile: use placemarkFromCoordinates
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return '$lat, $lng';
      final p = placemarks.first;
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
        p.country,
      ].where((s) => s != null && s.isNotEmpty).join(', ');
      return parts.isEmpty ? '$lat, $lng' : parts;
    } catch (e) {
      debugPrint('[MapsService] reverseGeocode error: $e');
      return '$lat, $lng';
    }
  }

  /// Returns a shareable Google Maps URL for the given coordinates.
  String mapsUrl(double lat, double lng) =>
      'https://maps.google.com/?q=$lat,$lng';

  /// Returns a [LatLng] from a [Position].
  LatLng positionToLatLng(Position position) =>
      LatLng(position.latitude, position.longitude);

  /// Returns distance in metres between two coordinates.
  double distanceMetres(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }
}
