import 'package:flutter_test/flutter_test.dart';
import 'package:accident_detection/models/contact.dart';
import 'package:accident_detection/models/incident.dart';
import 'package:accident_detection/models/sensor_reading.dart';
import 'package:accident_detection/core/constants.dart';
import 'package:accident_detection/maps/maps_service.dart';
import 'package:accident_detection/sensors/crash_detector.dart';
import 'package:accident_detection/sensors/ml_crash_classifier.dart';
import 'package:accident_detection/emergency/nearest_services.dart';

void main() {
  group('Contact Model Tests', () {
    test('creates contact and converts to/from Map correctly', () {
      const contact = Contact(
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Rahul Sharma',
        email: 'rahul.sharma@example.com',
        phone: '+919876543210',
        relation: 'Brother',
      );

      expect(contact.id, '123e4567-e89b-12d3-a456-426614174000');
      expect(contact.name, 'Rahul Sharma');
      expect(contact.email, 'rahul.sharma@example.com');
      expect(contact.phone, '+919876543210');
      expect(contact.relation, 'Brother');

      final map = contact.toMap();
      expect(map['id'], '123e4567-e89b-12d3-a456-426614174000');
      expect(map['name'], 'Rahul Sharma');
      expect(map['email'], 'rahul.sharma@example.com');
      expect(map['phone'], '+919876543210');
      expect(map['relation'], 'Brother');

      final fromMap = Contact.fromMap(map);
      expect(fromMap.id, contact.id);
      expect(fromMap.name, contact.name);
      expect(fromMap.email, contact.email);
      expect(fromMap.phone, contact.phone);
      expect(fromMap.relation, contact.relation);
    });

    test('Contact.fromMap handles legacy phone field fallback', () {
      final legacyMap = {
        'id': 'legacy-id',
        'name': 'Priya Patel',
        'phone': 'priya@example.com',
        'relation': 'Sister',
      };
      final contact = Contact.fromMap(legacyMap);
      expect(contact.id, 'legacy-id');
      expect(contact.name, 'Priya Patel');
      expect(contact.email, 'priya@example.com');
      expect(contact.relation, 'Sister');
    });

    test('Contact copyWith updates fields properly', () {
      const contact = Contact(
        id: 'test-id',
        name: 'Initial Name',
        email: 'initial@example.com',
        relation: 'Friend',
      );

      final updated = contact.copyWith(name: 'Updated Name', email: 'updated@example.com');
      expect(updated.name, 'Updated Name');
      expect(updated.id, 'test-id');
      expect(updated.email, 'updated@example.com');
      expect(updated.relation, 'Friend');
    });
  });

  group('SensorReading Model Tests', () {
    test('Stores and formats sensor snapshot correctly', () {
      final now = DateTime.now();
      final reading = SensorReading(
        gForce: 4.2,
        rotationRate: 280.0,
        speedDelta: 45.0,
        timestamp: now,
      );

      expect(reading.gForce, 4.2);
      expect(reading.rotationRate, 280.0);
      expect(reading.speedDelta, 45.0);

      final map = reading.toMap();
      final restored = SensorReading.fromMap(map);
      expect(restored.gForce, 4.2);
      expect(restored.rotationRate, 280.0);
      expect(restored.speedDelta, 45.0);
    });
  });

  group('Incident Model Tests', () {
    test('serializes and deserializes incident with sensor snapshot', () {
      final now = DateTime.now();
      final sensorSnapshot = SensorReading(
        gForce: 4.2,
        rotationRate: 310.5,
        speedDelta: 45.0,
        timestamp: now,
      );

      final incident = Incident(
        id: 'inc-001',
        timestamp: now,
        lat: 17.385044,
        lng: 78.486671,
        address: 'MG Road, Hyderabad',
        status: IncidentStatus.confirmed,
        sensorSnapshot: sensorSnapshot,
        contactsNotified: ['+919876543210'],
        emergencyCallPlaced: true,
      );

      final map = incident.toMap();
      expect(map['id'], 'inc-001');
      expect(map['status'], 'confirmed');
      expect(map['emergencyCallPlaced'], 1);

      final recovered = Incident.fromMap(map);
      expect(recovered.id, 'inc-001');
      expect(recovered.status, IncidentStatus.confirmed);
      expect(recovered.emergencyCallPlaced, true);
      expect(recovered.sensorSnapshot.gForce, 4.2);
      expect(recovered.contactsNotified, contains('+919876543210'));
    });
  });

  group('MapsService & AppConstants Tests', () {
    test('mapsUrl generates correct Google Maps link', () {
      final url = MapsService.instance.mapsUrl(17.385044, 78.486671);
      expect(url, 'https://maps.google.com/?q=17.385044,78.486671');
    });

    test('default constants match specification', () {
      expect(AppConstants.defaultGForceThreshold, 3.5);
      expect(AppConstants.defaultRotationThreshold, 250.0);
      expect(AppConstants.defaultSpeedDeltaThreshold, 40.0);
      expect(AppConstants.countdownDurationSeconds, 30);
      expect(AppConstants.conditionsRequired, 2);
    });
  });

  group('ML Classifier & CrashEvent Tests', () {
    test('MlCrashClassifier correctly identifies high-speed vehicle crash', () {
      // High G, high angular spin, severe speed drop, victim stationary
      final prob = MlCrashClassifier.instance.predictCrashProbability(
        peakG: 4.8,
        angularVelocityDps: 310.0,
        speedDropKmh: 52.0,
        postImpactVariance: 0.02,
      );
      expect(prob, greaterThan(0.9));
      expect(
        MlCrashClassifier.instance.isGenuineCrash(
          peakG: 4.8,
          angularVelocityDps: 310.0,
          speedDropKmh: 52.0,
          postImpactVariance: 0.02,
        ),
        isTrue,
      );
    });

    test('MlCrashClassifier suppresses false positives like dropping phone or running', () {
      // Minor G, low rotation, 0 speed drop, high ongoing motion
      final dropProb = MlCrashClassifier.instance.predictCrashProbability(
        peakG: 1.8,
        angularVelocityDps: 45.0,
        speedDropKmh: 0.0,
        postImpactVariance: 0.85,
      );
      expect(dropProb, lessThan(0.3));
      expect(
        MlCrashClassifier.instance.isGenuineCrash(
          peakG: 1.8,
          angularVelocityDps: 45.0,
          speedDropKmh: 0.0,
          postImpactVariance: 0.85,
        ),
        isFalse,
      );
    });

    test('CrashEvent accurately converts to SensorReading snapshot', () {
      final now = DateTime.now();
      final event = CrashEvent(
        timestamp: now,
        gForce: 4.5,
        rotationRate: 290.0,
        speedDelta: 48.0,
      );
      final snapshot = event.toSensorReading();
      expect(snapshot.gForce, 4.5);
      expect(snapshot.rotationRate, 290.0);
      expect(snapshot.speedDelta, 48.0);
      expect(snapshot.timestamp, now);
    });
  });

  group('NearbyPlace Model Tests', () {
    test('NearbyPlace parses from JSON correctly', () {
      final json = {
        'name': 'City General Hospital',
        'address': 'MG Road, Sec 4',
        'lat': 17.3940,
        'lng': 78.4754,
        'distance_km': 1.25,
      };

      final place = NearbyPlace.fromJson(json);
      expect(place.name, 'City General Hospital');
      expect(place.address, 'MG Road, Sec 4');
      expect(place.lat, 17.3940);
      expect(place.lng, 78.4754);
      expect(place.distanceKm, 1.25);
    });
  });
}
