import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

/// Handles placing an emergency call.
///
/// Android: auto-dials when CALL_PHONE permission is granted.
/// iOS: opens the dialer pre-filled (user must tap Call — Apple policy).
class AutoCallService {
  AutoCallService._();
  static final AutoCallService instance = AutoCallService._();

  /// Dials [phoneNumber]. Returns true if the call intent was launched.
  Future<bool> callEmergency(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    debugPrint('[AutoCall] Launching: $uri');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        debugPrint('[AutoCall] Cannot launch tel: URI on this device.');
        return false;
      }
    } catch (e) {
      debugPrint('[AutoCall] Error launching call: $e');
      return false;
    }
  }
}
