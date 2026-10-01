import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

/// Streams the peak angular velocity (°/sec) over the rolling detection window.
/// Returns null from [gyroStream] if the device has no gyroscope.
class GyroscopeService {
  GyroscopeService._();
  static final GyroscopeService instance = GyroscopeService._();

  StreamSubscription<GyroscopeEvent>? _sub;
  final _controller = StreamController<double>.broadcast();

  bool _available = true;
  final List<_TimedSample> _window = [];
  double _peakDps = 0;

  /// True if the device reported a gyroscope. Updated on first [start] call.
  bool get isAvailable => _available;

  /// Emits peak angular velocity in °/sec. Empty if no gyroscope.
  Stream<double> get gyroStream => _available ? _controller.stream : const Stream.empty();

  double get currentPeakDps => _peakDps;

  Future<void> start() async {
    if (_sub != null) return;
    try {
      _sub = gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: AppConstants.sensorSampleIntervalMs),
      ).listen(
        _onEvent,
        onError: (e) {
          debugPrint('[Gyro] error / unavailable: $e');
          _available = false;
        },
      );
    } catch (e) {
      debugPrint('[Gyro] not available on this device: $e');
      _available = false;
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _window.clear();
    _peakDps = 0;
  }

  void _onEvent(GyroscopeEvent event) {
    final now = DateTime.now();
    // Resultant angular velocity: rad/s → °/s
    final radPerSec = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final degPerSec = radPerSec * (180.0 / pi);

    _window.add(_TimedSample(degPerSec, now));

    final cutoff = now.subtract(
      const Duration(milliseconds: AppConstants.detectionWindowMs),
    );
    _window.removeWhere((s) => s.time.isBefore(cutoff));

    _peakDps = _window.fold(0.0, (max, s) => s.value > max ? s.value : max);
    _controller.add(_peakDps);
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
