import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app.dart';
import 'core/permissions.dart';
import 'core/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for full dark immersion.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0D0D),
  ));

  // Initialise background service and permissions on supported mobile platforms.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await BackgroundServiceManager.init();
    await AppPermissions.requestAll();
  }

  runApp(const AccidentDetectionApp());
}
