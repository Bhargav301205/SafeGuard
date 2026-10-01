import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

/// Streams GPS position and detects sudden speed drops (crash signature).
///
/// Enhancement over the previous 2-second window:
/// - 5-second rolling speed history (more robust on real roads)
/// - Detects BOTH sudden stop (high drop in short time) and
///   gradual deceleration spike (high rate of change)
/// - Exposes [currentSpeedKmh] for live display on UI
/// - Exposes [peakSpeedDropKmh] — the maximum drop seen in the rolling window
class GpsService {
  GpsService._();
  static final GpsService instance = GpsService._();

  StreamSubscription<Position>? _sub;
  final _positionController = StreamController<Position>.broadcast();
  final _speedDeltaController = StreamController<double>.broadcast();
  final _speedKmhController = StreamController<double>.broadcast();

  Position? _lastPosition;
  final List<_TimedSpeed> _speedHistory = [];

  double _currentSpeedKmh = 0;
  double _peakDropKmh = 0;

  /// Latest GPS position.
  Stream<Position> get positionStream => _positionController.stream;

  /// Speed drop in km/h detected in the rolling window. Emits 0 when no drop.
  Stream<double> get speedDeltaStream => _speedDeltaController.stream;

  /// Live current speed in km/h — use for the speed badge in the UI.
  Stream<double> get speedKmhStream => _speedKmhController.stream;

  Position? get lastPosition => _lastPosition;
  double get currentSpeedKmh => _currentSpeedKmh;
  double get peakSpeedDropKmh => _peakDropKmh;

  Future<bool> start() async {
    if (_sub != null) return true; // Already running

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[GPS] Location services disabled.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (e) => debugPrint('[GPS] error: $e'),
    );
    return true;
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _speedHistory.clear();
    _lastPosition = null;
    _currentSpeedKmh = 0;
    _peakDropKmh = 0;
  }

  void _onPosition(Position position) {
    _lastPosition = position;
    _positionController.add(position);

    // Speed in km/h (geolocator returns m/s, negative = invalid)
    final speedKmh = (position.speed < 0 ? 0.0 : position.speed) * 3.6;
    _currentSpeedKmh = speedKmh;
    _speedKmhController.add(speedKmh);

    final now = DateTime.now();
    _speedHistory.add(_TimedSpeed(speedKmh, now));

    // ── 5-second rolling window (was 2s — catches slower deceleration too) ──
    final cutoff = now.subtract(const Duration(milliseconds: 5000));
    _speedHistory.removeWhere((s) => s.time.isBefore(cutoff));

    double crashSignal = 0.0;

    if (_speedHistory.length >= 2) {
      final oldest = _speedHistory.first.speed;
      final newest = _speedHistory.last.speed;

      // Primary: absolute speed drop over 5s window
      final absoluteDrop = oldest - newest; // positive = dropped

      // Secondary: max speed in window → current speed (catches peaks better)
      final maxSpeed = _speedHistory.fold(0.0, (m, s) => s.speed > m ? s.speed : m);
      final dropFromPeak = maxSpeed - newest;

      // Use the stronger signal of the two
      crashSignal = [absoluteDrop, dropFromPeak].reduce((a, b) => a > b ? a : b);
      if (crashSignal < 0) crashSignal = 0.0;

      _peakDropKmh = crashSignal;
    }

    _speedDeltaController.add(crashSignal);
  }

  void dispose() {
    stop();
    _positionController.close();
    _speedDeltaController.close();
    _speedKmhController.close();
  }
}

class _TimedSpeed {
  final double speed;
  final DateTime time;
  _TimedSpeed(this.speed, this.time);
}
