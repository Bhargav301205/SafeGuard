import 'package:flutter/foundation.dart' show kIsWeb;

/// Core constants for the Accident Detection System.
/// All detection thresholds are tunable from the Settings screen at runtime;
/// these are the factory defaults.

class AppConstants {
  AppConstants._();

  // ── Detection Thresholds ────────────────────────────────────────────────
  /// Resultant G-force magnitude (√x²+y²+z²) that triggers the accelerometer
  /// condition. Range: 2.0–6.0G. Default: 3.5G.
  static const double defaultGForceThreshold = 3.5;

  /// Gyroscope angular velocity (°/sec) that triggers the rotation condition.
  /// Range: 100–500°/s. Default: 250°/s.
  static const double defaultRotationThreshold = 250.0;

  /// GPS speed drop (km/h) within the detection window that triggers the
  /// speed-delta condition. Range: 20–60 km/h. Default: 40 km/h.
  static const double defaultSpeedDeltaThreshold = 40.0;

  /// How many of the 3 conditions must fire within the detection window.
  /// Set to 2 for 2-of-3 logic; auto-reduced to 2-of-2 when no gyroscope.
  static const int conditionsRequired = 2;

  // ── Timing ──────────────────────────────────────────────────────────────
  /// Sensor sampling interval in milliseconds (20Hz = 50ms).
  static const int sensorSampleIntervalMs = 50;

  /// Rolling window (ms) within which all sensor conditions must be met.
  static const int detectionWindowMs = 1000;

  /// After a crash is detected, ignore further detections for this duration
  /// to prevent duplicate alerts.
  static const int postDetectionCooldownMs = 60000;

  /// Duration of the cancellation countdown in seconds.
  static const int countdownDurationSeconds = 30;

  // ── Emergency ────────────────────────────────────────────────────────────
  /// Default emergency phone number dialled. Users can override in settings.
  static const String defaultEmergencyNumber = '112';

  /// Default SMS message template. {address} and {mapsUrl} are substituted.
  static const String defaultSmsTemplate =
      '🚨 EMERGENCY ALERT: I may have been in an accident.\n'
      'Location: {address}\n'
      'Live map: {mapsUrl}\n'
      'This message was sent automatically.';

  // ── Backend ───────────────────────────────────────────────────────────────
  static const String defaultBackendUrl = 'http://192.168.0.101:8000'; // Default LAN IP

  /// Resolves the backend URL dynamically.
  /// On Web: automatically extracts the current hostname (e.g. 192.168.0.101 or localhost)
  /// and points to port 8000, ensuring LAN and localhost both work without manual reconfiguration.
  /// On Mobile/Native: defaults to the configured LAN IP.
  static String resolveBackendUrl() {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty) {
        return 'http://$host:8000';
      }
    }
    return defaultBackendUrl;
  }

  // ── Storage Keys ──────────────────────────────────────────────────────────
  static const String prefKeyGForceThreshold = 'gforce_threshold';
  static const String prefKeyRotationThreshold = 'rotation_threshold';
  static const String prefKeySpeedDeltaThreshold = 'speed_delta_threshold';
  static const String prefKeyEmergencyNumber = 'emergency_number';
  static const String prefKeyAutoCall = 'auto_call_enabled';
  static const String prefKeyAlertOnly = 'alert_only_mode';
  static const String prefKeyBackendUrl = 'backend_url';
  static const String prefKeyMonitoringEnabled = 'monitoring_enabled';

  // ── DB ────────────────────────────────────────────────────────────────────
  static const String dbName = 'accident_detection.db';
  static const int dbVersion = 3; // bumped: added phone column for AI voice calls
}
