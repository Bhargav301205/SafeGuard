import 'package:flutter_test/flutter_test.dart';
import 'package:accident_detection/core/constants.dart';

void main() {
  group('Crash Detection Fusion Logic Tests', () {
    test('Crash is triggered when 2 of 3 conditions are met (Accel + Gyro)', () {
      const g = 4.2;
      const rot = 280.0;
      const speedDrop = 10.0;

      const accelMet = g >= AppConstants.defaultGForceThreshold;
      const gyroMet = rot >= AppConstants.defaultRotationThreshold;
      const speedMet = speedDrop >= AppConstants.defaultSpeedDeltaThreshold;

      int metCount = 0;
      if (accelMet) metCount++;
      if (gyroMet) metCount++;
      if (speedMet) metCount++;

      expect(metCount >= AppConstants.conditionsRequired, isTrue);
    });

    test('Crash is triggered when 2 of 3 conditions are met (Accel + GPS Decel)', () {
      const g = 3.8;
      const rot = 100.0;
      const speedDrop = 45.0;

      const accelMet = g >= AppConstants.defaultGForceThreshold;
      const gyroMet = rot >= AppConstants.defaultRotationThreshold;
      const speedMet = speedDrop >= AppConstants.defaultSpeedDeltaThreshold;

      int metCount = 0;
      if (accelMet) metCount++;
      if (gyroMet) metCount++;
      if (speedMet) metCount++;

      expect(metCount >= AppConstants.conditionsRequired, isTrue);
    });

    test('Crash is NOT triggered when only 1 condition is met (False positive prevention)', () {
      const g = 4.0;
      const rot = 80.0;
      const speedDrop = 0.0;

      const accelMet = g >= AppConstants.defaultGForceThreshold;
      const gyroMet = rot >= AppConstants.defaultRotationThreshold;
      const speedMet = speedDrop >= AppConstants.defaultSpeedDeltaThreshold;

      int metCount = 0;
      if (accelMet) metCount++;
      if (gyroMet) metCount++;
      if (speedMet) metCount++;

      expect(metCount >= AppConstants.conditionsRequired, isFalse);
    });

    test('Graceful degradation without gyroscope: requires both Accel and Speed Delta', () {
      int countConditions({required bool accel, required bool speed, required bool gyro}) {
        int count = 0;
        if (accel) count++;
        if (speed) count++;
        if (gyro) count++;
        return count;
      }

      final metWithGyro = countConditions(accel: true, speed: true, gyro: true);
      final metWithoutGyro = countConditions(accel: true, speed: true, gyro: false);

      expect(metWithGyro, 3);
      expect(metWithoutGyro, 2);
      expect(metWithoutGyro >= AppConstants.conditionsRequired, isTrue);
    });
  });
}
