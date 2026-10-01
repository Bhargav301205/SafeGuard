import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/sensor_reading.dart';
import 'accelerometer_service.dart';
import 'gyroscope_service.dart';
import 'gps_service.dart';

/// Emitted when the crash detection algorithm decides a crash has occurred.
class CrashEvent {
  final DateTime timestamp;
  final double gForce;
  final double? rotationRate;
  final double? speedDelta;

  const CrashEvent({
    required this.timestamp,
    required this.gForce,
    this.rotationRate,
    this.speedDelta,
  });

  SensorReading toSensorReading() => SensorReading(
        gForce: gForce,
        rotationRate: rotationRate,
        speedDelta: speedDelta,
        timestamp: timestamp,
      );
}

/// Fuses accelerometer, gyroscope, and GPS speed-delta signals using a
/// 2-of-3 rule (or 2-of-2 when gyroscope is unavailable).
///
/// Emits a [CrashEvent] on the [crashEvents] stream when a crash is detected.
/// Auto-debounced — further detections are suppressed for
/// [AppConstants.postDetectionCooldownMs] after a trigger.
class CrashDetector {
  final _crashController = StreamController<CrashEvent>.broadcast();

  Stream<CrashEvent> get crashEvents => _crashController.stream;

  StreamSubscription<double>? _accelSub;
  StreamSubscription<double>? _gyroSub;
  StreamSubscription<double>? _gpsSub;

  bool _inCooldown = false;

  // Live readings within the current detection window.
  double _currentG = 0;
  double _currentDps = 0;
  double _currentSpeedDelta = 0;

  // Thresholds loaded from SharedPreferences.
  late double _gThreshold;
  late double _rotThreshold;
  late double _speedThreshold;

  Future<void> start() async {
    await _loadThresholds();

    final accel = AccelerometerService.instance;
    final gyro = GyroscopeService.instance;
    final gps = GpsService.instance;

    accel.start();
    await gyro.start();
    await gps.start();

    _accelSub = accel.gForceStream.listen((g) {
      _currentG = g;
      _evaluate();
    });

    _gyroSub = gyro.gyroStream.listen((dps) {
      _currentDps = dps;
      _evaluate();
    });

    _gpsSub = gps.speedDeltaStream.listen((delta) {
      _currentSpeedDelta = delta;
      _evaluate();
    });
  }

  void stop() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _gpsSub?.cancel();
    AccelerometerService.instance.stop();
    GyroscopeService.instance.stop();
    GpsService.instance.stop();
  }

  Future<void> _loadThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    _gThreshold = prefs.getDouble(AppConstants.prefKeyGForceThreshold) ??
        AppConstants.defaultGForceThreshold;
    _rotThreshold = prefs.getDouble(AppConstants.prefKeyRotationThreshold) ??
        AppConstants.defaultRotationThreshold;
    _speedThreshold = prefs.getDouble(AppConstants.prefKeySpeedDeltaThreshold) ??
        AppConstants.defaultSpeedDeltaThreshold;
  }

  void _evaluate() {
    if (_inCooldown) return;

    final bool accelTriggered = _currentG >= _gThreshold;
    final bool gyroAvailable = GyroscopeService.instance.isAvailable;
    final bool gyroTriggered = gyroAvailable && _currentDps >= _rotThreshold;
    final bool gpsTriggered = _currentSpeedDelta >= _speedThreshold;

    int conditionsMet = 0;
    if (accelTriggered) conditionsMet++;
    if (gyroAvailable && gyroTriggered) conditionsMet++;
    if (gpsTriggered) conditionsMet++;

    // Required conditions: 2 (of 3, or 2 of 2 if no gyro).
    const required = AppConstants.conditionsRequired;

    if (conditionsMet >= required) {
      _triggerCrash();
    }
  }

  void _triggerCrash() {
    if (_inCooldown) return;
    _inCooldown = true;

    final event = CrashEvent(
      timestamp: DateTime.now(),
      gForce: _currentG,
      rotationRate: GyroscopeService.instance.isAvailable ? _currentDps : null,
      speedDelta: _currentSpeedDelta > 0 ? _currentSpeedDelta : null,
    );

    debugPrint('[CrashDetector] 🚨 CRASH DETECTED: $event');
    _crashController.add(event);

    // Cooldown to prevent duplicate triggers.
    Future.delayed(
      const Duration(milliseconds: AppConstants.postDetectionCooldownMs),
      () => _inCooldown = false,
    );
  }

  void dispose() {
    stop();
    _crashController.close();
  }
}
