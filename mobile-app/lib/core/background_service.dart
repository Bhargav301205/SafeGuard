import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../sensors/crash_detector.dart';

/// Bootstraps the Flutter background service for continuous sensor monitoring.
///
/// Android: runs as a foreground service with a persistent notification.
/// iOS: uses BGProcessingTask / BGAppRefreshTask (limited by OS).
class BackgroundServiceManager {
  BackgroundServiceManager._();

  static const _notificationChannelId = 'accident_monitor';
  static const _notificationId = 888;

  /// Initialise and start the background service.
  static Future<void> init() async {
    final service = FlutterBackgroundService();

    final androidConfig = AndroidConfiguration(
      onStart: _onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: _notificationChannelId,
      initialNotificationTitle: 'Accident Monitor Active',
      initialNotificationContent: 'Monitoring sensors for crash detection…',
      foregroundServiceNotificationId: _notificationId,
    );

    final iosConfig = IosConfiguration(
      autoStart: true,
      onForeground: _onStart,
      onBackground: _onIosBackground,
    );

    await service.configure(
      androidConfiguration: androidConfig,
      iosConfiguration: iosConfig,
    );
  }

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static Future<bool> isRunning() async {
    return FlutterBackgroundService().isRunning();
  }
}

/// Entry point executed inside the background isolate.
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((_) => service.stopSelf());

  // Initialise crash detector inside the background isolate.
  final detector = CrashDetector();
  await detector.start();

  detector.crashEvents.listen((event) {
    // Send crash event to the UI isolate via IPC.
    service.invoke('crashDetected', {
      'timestamp': event.timestamp.toIso8601String(),
      'gForce': event.gForce,
      'rotationRate': event.rotationRate,
      'speedDelta': event.speedDelta,
    });
  });

  // Heartbeat every 5 seconds so Android doesn't kill the service.
  Timer.periodic(const Duration(seconds: 5), (_) {
    service.invoke('heartbeat', {'ts': DateTime.now().toIso8601String()});
  });
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
