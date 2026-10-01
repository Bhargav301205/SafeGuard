import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

/// Streams the peak resultant G-force within a rolling detection window.
///
/// Gravity (≈1G at rest) is NOT subtracted here — the crash spike will be
/// >> 3G regardless. The caller (CrashDetector) handles threshold comparison.
class AccelerometerService {
  AccelerometerService._();
  static final AccelerometerService instance = AccelerometerService._();

  StreamSubscription<AccelerometerEvent>? _sub;
  final _controller = StreamController<double>.broadcast();

  /// Rolling buffer of magnitude samples within [AppConstants.detectionWindowMs].
  final List<_TimedSample> _window = [];

  /// The most recent peak G-force in the rolling window.
  double _peakG = 0;

  /// Emits the peak G-force (in G units) whenever a new sample is processed.
  Stream<double> get gForceStream => _controller.stream;

  double get currentPeakG => _peakG;

  void start() {
    if (_sub != null) return;
    _sub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: AppConstants.sensorSampleIntervalMs),
    ).listen(_onEvent, onError: (e) => debugPrint('[Accel] error: $e'));
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _window.clear();
    _peakG = 0;
  }

  void _onEvent(AccelerometerEvent event) {
    final now = DateTime.now();
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    // Convert m/s² → G
    final gForce = magnitude / 9.81;

    _window.add(_TimedSample(gForce, now));

    // Evict samples outside the rolling window.
    final cutoff = now.subtract(
      const Duration(milliseconds: AppConstants.detectionWindowMs),
    );
    _window.removeWhere((s) => s.time.isBefore(cutoff));

    _peakG = _window.fold(0.0, (max, s) => s.value > max ? s.value : max);
    _controller.add(_peakG);
  }

  void dispose() {
    stop();
    _controller.close();
  }
}

class _TimedSample {
  final double value;
  final DateTime time;
  _TimedSample(this.value, this.time);
}
