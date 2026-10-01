import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/constants.dart';

enum NearbyServiceType { police, hospital, fire }

class NearbyPlace {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double distanceKm;

  const NearbyPlace({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceKm,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    return NearbyPlace(
      name: json['name'] as String,
      address: json['address'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num? ?? 0).toDouble(),
    );
  }
}

/// Queries the backend for nearest emergency services (police/hospital/fire).
class NearestServicesClient {
  NearestServicesClient._();
  static final NearestServicesClient instance = NearestServicesClient._();

  Future<List<NearbyPlace>> getNearest({
    required double lat,
    required double lng,
    required NearbyServiceType type,
    int limit = 3,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.prefKeyBackendUrl);
    final baseUrl = (saved != null && saved.isNotEmpty)
        ? saved
        : AppConstants.resolveBackendUrl();

    final typeStr = type.name; // 'police', 'hospital', 'fire'
    final uri = Uri.parse(
      '$baseUrl/services/nearest?lat=$lat&lng=$lng&type=$typeStr&limit=$limit',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List;
        return data
            .map((e) => NearbyPlace.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('[NearestServices] HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[NearestServices] Error: $e');
      return [];
    }
  }
}
