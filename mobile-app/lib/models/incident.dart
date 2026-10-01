import 'package:uuid/uuid.dart';
import 'sensor_reading.dart';

enum IncidentStatus { pending, confirmed, cancelled }

/// Represents a single crash detection event.
class Incident {
  final String id;
  final DateTime timestamp;
  final double lat;
  final double lng;
  final String address;
  final IncidentStatus status;
  final SensorReading sensorSnapshot;
  final List<String> contactsNotified;
  final bool emergencyCallPlaced;

  const Incident({
    required this.id,
    required this.timestamp,
    required this.lat,
    required this.lng,
    required this.address,
    required this.status,
    required this.sensorSnapshot,
    required this.contactsNotified,
    required this.emergencyCallPlaced,
  });

  factory Incident.create({
    required double lat,
    required double lng,
    required String address,
    required SensorReading sensorSnapshot,
  }) {
    return Incident(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      lat: lat,
      lng: lng,
      address: address,
      status: IncidentStatus.pending,
      sensorSnapshot: sensorSnapshot,
      contactsNotified: [],
      emergencyCallPlaced: false,
    );
  }

  Incident copyWith({
    IncidentStatus? status,
    List<String>? contactsNotified,
    bool? emergencyCallPlaced,
  }) {
    return Incident(
      id: id,
      timestamp: timestamp,
      lat: lat,
      lng: lng,
      address: address,
      status: status ?? this.status,
      sensorSnapshot: sensorSnapshot,
      contactsNotified: contactsNotified ?? this.contactsNotified,
      emergencyCallPlaced: emergencyCallPlaced ?? this.emergencyCallPlaced,
    );
  }

  factory Incident.fromMap(Map<String, dynamic> map) {
    return Incident(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      address: map['address'] as String,
      status: IncidentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => IncidentStatus.pending,
      ),
      sensorSnapshot: SensorReading.fromMap(
        Map<String, dynamic>.from(map['sensorSnapshot'] as Map),
      ),
      contactsNotified: List<String>.from(map['contactsNotified'] as List),
      emergencyCallPlaced: map['emergencyCallPlaced'] == 1 || map['emergencyCallPlaced'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'address': address,
        'status': status.name,
        'sensorSnapshot': sensorSnapshot.toMap(),
        'contactsNotified': contactsNotified,
        'emergencyCallPlaced': emergencyCallPlaced ? 1 : 0,
      };

  String get mapsUrl => 'https://maps.google.com/?q=$lat,$lng';
}
