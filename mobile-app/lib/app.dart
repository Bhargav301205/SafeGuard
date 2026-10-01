import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'contacts/contacts_repository.dart';
import 'ui/home_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/incident_history_screen.dart';
import 'contacts/manage_contacts_screen.dart';
import 'maps/live_location_screen.dart';
import 'emergency/countdown_screen.dart';
import 'models/sensor_reading.dart';

class AccidentDetectionApp extends StatelessWidget {
  const AccidentDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ContactsRepository()..init(),
      child: MaterialApp(
        title: 'SafeGuard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D0D0D),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF0A84FF),
            secondary: Color(0xFF30D158),
            error: Color(0xFFFF3B30),
            surface: Color(0xFF1C1C1E),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D0D0D),
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontFamily: 'Inter', color: Colors.white),
          ),
          fontFamily: 'Inter',
          sliderTheme: const SliderThemeData(
            activeTrackColor: Color(0xFF0A84FF),
            inactiveTrackColor: Color(0xFF3A3A3C),
            thumbColor: Color(0xFF0A84FF),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (_) => const HomeScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/contacts': (_) => const ManageContactsScreen(),
          '/history': (_) => const IncidentHistoryScreen(),
          '/map': (_) => const LiveLocationScreen(),
          '/countdown': (_) => CountdownScreen(
                sensorSnapshot: SensorReading(
                  gForce: 4.2,
                  rotationRate: 310,
                  speedDelta: 45,
                  timestamp: DateTime.now(),
                ),
              ),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/incident-detail') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => LiveLocationScreen(
                initialLat: args['lat'] as double?,
                initialLng: args['lng'] as double?,
                address: args['address'] as String?,
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
