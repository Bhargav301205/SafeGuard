/// A timestamped snapshot of sensor readings at the moment of crash detection.
class SensorReading {
  /// Resultant G-force magnitude: √(x²+y²+z²) / 9.81
  final double gForce;

  /// Resultant angular velocity in °/sec. Null if device has no gyroscope.
  final double? rotationRate;

  /// Speed drop in km/h over the detection window. Null if GPS was unavailable.
  final double? speedDelta;

  final DateTime timestamp;

  const SensorReading({
    required this.gForce,
    this.rotationRate,
    this.speedDelta,
    required this.timestamp,
  });

  factory SensorReading.fromMap(Map<String, dynamic> map) {
    return SensorReading(
      gForce: (map['gForce'] as num).toDouble(),
      rotationRate: map['rotationRate'] != null
          ? (map['rotationRate'] as num).toDouble()
          : null,
      speedDelta: map['speedDelta'] != null
          ? (map['speedDelta'] as num).toDouble()
          : null,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'gForce': gForce,
        'rotationRate': rotationRate,
        'speedDelta': speedDelta,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() =>
      'SensorReading(gForce: ${gForce.toStringAsFixed(2)}G, '
      'rotation: ${rotationRate?.toStringAsFixed(1)}°/s, '
      'speedDelta: ${speedDelta?.toStringAsFixed(1)} km/h)';
}
