import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../contacts/contacts_repository.dart';
import '../sensors/crash_detector.dart';
import '../sensors/accelerometer_service.dart';
import '../sensors/gps_service.dart';
import '../core/constants.dart';
import '../core/background_service.dart';
import '../emergency/countdown_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  CrashDetector? _detector;
  StreamSubscription<CrashEvent>? _crashSub;
  StreamSubscription<double>? _gSub;
  StreamSubscription<double>? _gpsSub;

  bool _monitoring = false;
  double _currentG = 0;
  double _currentSpeed = 0;
  bool _navigatingToCountdown = false;

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadMonitoringState();
  }

  Future<void> _loadMonitoringState() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(AppConstants.prefKeyMonitoringEnabled) ?? false;
    if (enabled) _startMonitoring();
  }

  Future<void> _startMonitoring() async {
    if (_monitoring) return;
    setState(() => _monitoring = true);
    _radarController.repeat();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefKeyMonitoringEnabled, true);

    _detector = CrashDetector();
    await _detector!.start();

    _crashSub = _detector!.crashEvents.listen(_onCrashDetected);

    _gSub = AccelerometerService.instance.gForceStream.listen((g) {
      if (mounted) setState(() => _currentG = g);
    });

    // Use the dedicated km/h stream — no manual conversion needed
    _gpsSub = GpsService.instance.speedKmhStream.listen((speedKmh) {
      if (mounted) setState(() => _currentSpeed = speedKmh);
    });

    await BackgroundServiceManager.start();
  }

  Future<void> _stopMonitoring() async {
    if (!_monitoring) return;
    setState(() => _monitoring = false);
    _radarController.stop();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefKeyMonitoringEnabled, false);

    _crashSub?.cancel();
    _gSub?.cancel();
    _gpsSub?.cancel();
    _detector?.stop();
    _detector = null;

    setState(() {
      _currentG = 0;
      _currentSpeed = 0;
    });

    await BackgroundServiceManager.stop();
  }

  void _onCrashDetected(CrashEvent event) {
    if (_navigatingToCountdown || !mounted) return;
    _navigatingToCountdown = true;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CountdownScreen(
          sensorSnapshot: event.toSensorReading(),
        ),
      ),
    ).then((_) => _navigatingToCountdown = false);
  }

  void _simulateCrash() {
    // For demo/testing — only triggers when monitoring is active.
    if (!_monitoring) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start monitoring first to simulate a crash.',
              style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: Color(0xFFFF9F0A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _onCrashDetected(CrashEvent(
      timestamp: DateTime.now(),
      gForce: 4.2,
      rotationRate: 310,
      speedDelta: 45,
    ));
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _crashSub?.cancel();
    _gSub?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<ContactsRepository>().contacts;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFF0D0D0D),
              floating: true,
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield,
                        color: Color(0xFFFF3B30), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'SafeGuard',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white54),
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ── Radar / Monitor Toggle ──────────────────────────
                    GestureDetector(
                      onTap: _monitoring ? _stopMonitoring : _startMonitoring,
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, child) => Transform.scale(
                          scale: _monitoring ? _pulseAnim.value : 1.0,
                          child: child,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _monitoring
                                  ? [
                                      const Color(0xFFFF3B30).withOpacity(0.15),
                                      const Color(0xFFFF6B35).withOpacity(0.08),
                                    ]
                                  : [
                                      const Color(0xFF1C1C1E),
                                      const Color(0xFF2C2C2E),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: _monitoring
                                  ? const Color(0xFFFF3B30).withOpacity(0.4)
                                  : Colors.white.withOpacity(0.08),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              _RadarAnimation(
                                  controller: _radarController,
                                  active: _monitoring),
                              const SizedBox(height: 20),
                              Text(
                                _monitoring
                                    ? 'MONITORING ACTIVE'
                                    : 'TAP TO START MONITORING',
                                style: TextStyle(
                                  color: _monitoring
                                      ? const Color(0xFFFF3B30)
                                      : Colors.white.withOpacity(0.5),
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _monitoring
                                    ? 'Tap to stop'
                                    : 'Crash detection is paused',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Live Sensor Readouts ────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _SensorCard(
                            label: 'G-Force',
                            value: _monitoring
                                ? '${_currentG.toStringAsFixed(2)}G'
                                : '—',
                            icon: Icons.speed,
                            color: _currentG >= 2.5
                                ? const Color(0xFFFF3B30)
                                : const Color(0xFF0A84FF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SensorCard(
                            label: 'Speed',
                            value: _monitoring
                                ? '${_currentSpeed.toStringAsFixed(0)} km/h'
                                : '—',
                            icon: Icons.directions_car_outlined,
                            color: const Color(0xFF30D158),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Quick Actions ───────────────────────────────────
                    _QuickActionCard(
                      icon: Icons.mark_email_read_outlined,
                      title: 'Emergency Contacts',
                      subtitle: contacts.length < 2
                          ? '${contacts.length}/2 required contacts set — tap to complete'
                          : '${contacts.length} email contact${contacts.length == 1 ? '' : 's'} ready (Active)',
                      onTap: () => Navigator.pushNamed(context, '/contacts'),
                      trailing: contacts.length < 2
                          ? const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFFF9F0A), size: 18)
                          : const Icon(Icons.check_circle,
                              color: Color(0xFF30D158), size: 18),
                    ),

                    const SizedBox(height: 12),

                    _QuickActionCard(
                      icon: Icons.history_outlined,
                      title: 'Incident History',
                      subtitle: 'View past detections and alerts',
                      onTap: () => Navigator.pushNamed(context, '/history'),
                    ),

                    const SizedBox(height: 12),

                    _QuickActionCard(
                      icon: Icons.map_outlined,
                      title: 'Live Location',
                      subtitle: 'View current location on map',
                      onTap: () => Navigator.pushNamed(context, '/map'),
                    ),

                    const SizedBox(height: 24),

                    // ── Test / Demo button ─────────────────────────────
                    OutlinedButton.icon(
                      icon: const Icon(Icons.science_outlined,
                          color: Color(0xFFFF9F0A), size: 18),
                      label: const Text(
                        'Simulate Crash (Demo)',
                        style: TextStyle(
                          color: Color(0xFFFF9F0A),
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _simulateCrash,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: const Color(0xFFFF9F0A).withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _RadarAnimation extends StatelessWidget {
  final AnimationController controller;
  final bool active;

  const _RadarAnimation({required this.controller, required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing rings
          if (active)
            ...List.generate(3, (i) {
              return AnimatedBuilder(
                animation: controller,
                builder: (_, __) {
                  final t = (controller.value + i / 3) % 1.0;
                  return Opacity(
                    opacity: (1 - t).clamp(0.0, 0.5),
                    child: Container(
                      width: 40 + t * 80,
                      height: 40 + t * 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF3B30),
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          // Center icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFFF3B30).withOpacity(0.2)
                  : const Color(0xFF2C2C2E),
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.sensors : Icons.sensors_off_outlined,
              color: active ? const Color(0xFFFF3B30) : Colors.white30,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SensorCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontFamily: 'Inter',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0A84FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF0A84FF), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontFamily: 'Inter',
                        fontSize: 12,
                      )),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right,
                    color: Colors.white.withOpacity(0.2), size: 20),
          ],
        ),
      ),
    );
  }
}
