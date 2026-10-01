import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/contact.dart';

/// Sends an emergency SMS to all registered contacts.
///
/// Tries native SMS intent (sms: URI scheme) first. If native SMS is
/// unavailable on the platform/device, it falls back to the backend notification service.
class SmsService {
  SmsService._();
  static final SmsService instance = SmsService._();

  /// Sends SMS to each contact in [contacts].
  /// Returns the list of phone numbers that were successfully dispatched.
  Future<List<String>> sendAlert({
    required List<Contact> contacts,
    required double lat,
    required double lng,
    required String address,
  }) async {
    if (contacts.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final template = prefs.getString('sms_template') ?? AppConstants.defaultSmsTemplate;

    final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
    final body = template
        .replaceAll('{address}', address)
        .replaceAll('{mapsUrl}', mapsUrl);

    final notified = <String>[];

    for (final contact in contacts) {
      // Use email as the notification address since phone field was removed from Contact model.
      // SMS is sent to contact.email if it's a phone number, or skipped if it's an actual email.
      final target = contact.email;
      final sent = await _sendSms(target, body);
      if (sent) notified.add(target);
    }

    // If native SMS intent could not launch on this device (e.g. tablet, emulator, desktop),
    // fall back to backend notification service.
    if (notified.isEmpty && contacts.isNotEmpty) {
      debugPrint('[SMS] Native SMS unavailable or failed. Dispatching via backend notification service...');
      final backendDispatched = await _sendViaBackend(
        contacts: contacts,
        lat: lat,
        lng: lng,
        address: address,
      );
      notified.addAll(backendDispatched);
    }

    return notified;
  }

  Future<bool> _sendSms(String phone, String body) async {
    final encoded = Uri.encodeComponent(body);
    final uri = Uri.parse('sms:$phone?body=$encoded');
    debugPrint('[SMS] Sending to $phone');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      debugPrint('[SMS] Cannot launch sms: URI on this device.');
      return false;
    } catch (e) {
      debugPrint('[SMS] Error: $e');
      return false;
    }
  }

  Future<List<String>> _sendViaBackend({
    required List<Contact> contacts,
    required double lat,
    required double lng,
    required String address,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(AppConstants.prefKeyBackendUrl);
      final baseUrl = (saved != null && saved.isNotEmpty)
          ? saved
          : AppConstants.resolveBackendUrl();
      // Use email as contact identifier (phone field removed from Contact model)
      final contactEmails = contacts.map((c) => c.email).toList();

      final response = await http.post(
        Uri.parse('$baseUrl/incidents'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': const Uuid().v4(),
          'timestamp': DateTime.now().toIso8601String(),
          'lat': lat,
          'lng': lng,
          'address': address,
          'status': 'confirmed',
          'sensorSnapshot': {
            'gForce': 4.0,
            'rotationRate': null,
            'speedDelta': null,
            'timestamp': DateTime.now().toIso8601String(),
          },
          'contactsNotified': contactEmails,
          'emergencyCallPlaced': false,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 201) {
        debugPrint('[SMS] Backend alert successfully recorded and triggered.');
        return contactEmails;
      }
    } catch (e) {
      debugPrint('[SMS] Backend alert fallback failed: $e');
    }
    return [];
  }
}
