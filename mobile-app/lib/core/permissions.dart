import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

/// Centralises all runtime permission requests for the app.
/// Call [requestAll] on app start after showing rationale to the user.
class AppPermissions {
  AppPermissions._();

  /// Requests every permission the app needs. Returns a map of results.
  static Future<Map<Permission, PermissionStatus>> requestAll() async {
    final permissions = <Permission>[
      Permission.location,
      Permission.locationAlways,
      Permission.phone,
      Permission.sms,
      Permission.notification,
    ];

    final statuses = await permissions.request();
    for (final entry in statuses.entries) {
      debugPrint('[Permissions] ${entry.key}: ${entry.value}');
    }
    return statuses;
  }

  /// True when the minimum required permissions are granted (location + phone).
  static Future<bool> hasMinimumRequired() async {
    final location = await Permission.location.isGranted;
    final phone = await Permission.phone.isGranted;
    return location && phone;
  }

  /// True when background location is granted (needed for background monitoring).
  static Future<bool> hasBackgroundLocation() async {
    return Permission.locationAlways.isGranted;
  }

  /// Opens the OS settings page so the user can grant permissions manually.
  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Checks if the HIGH_SAMPLING_RATE_SENSORS permission is needed (Android 12+).
  /// This is declared in the manifest — no runtime grant needed, but we
  /// verify the device reported it.
  static bool get needsHighSamplingRate => defaultTargetPlatform == TargetPlatform.android;
}
