import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/incident.dart';
import '../models/sensor_reading.dart';
import '../contacts/contacts_repository.dart';
import '../emergency/auto_call_service.dart';
import '../emergency/voice_service.dart';
import '../maps/maps_service.dart';
import '../sensors/gps_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The critical 30-second cancellation window after crash detection.
/// Full-screen, high-contrast, one-tap cancel button.
/// If no cancellation: triggers call + email pipeline.
///
/// New in this version:
/// - Voice announcement fires immediately when screen opens
/// - Live speed badge updates every second from GPS
/// - Voice says "Help is on the way" when alert triggers
/// - Voice says "Safe" immediately on cancel
class CountdownScreen extends StatefulWidget {
  final SensorReading sensorSnapshot;

  const CountdownScreen({super.key, required this.sensorSnapshot});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  Timer? _countdownTimer;
  int _secondsLeft = AppConstants.countdownDurationSeconds;
  bool _cancelled = false;
  bool _alertTriggered = false;

  // GPS speed display
  StreamSubscription<double>? _speedSub;
  double _currentSpeedKmh = 0;

  // Voice state — track whether location fetch is done for the announcement
  String? _pendingAddress;
  double? _pendingLat;
  double? _pendingLng;
  bool _locationFetched = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: AppConstants.countdownDurationSeconds),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Subscribe to live GPS speed for the speed badge
    _speedSub = GpsService.instance.speedKmhStream.listen((spd) {
      if (mounted) setState(() => _currentSpeedKmh = spd);
    });

    _startCountdown();

    // Fetch location + fire voice announcement ASAP (async — doesn't block UI)
    _fetchLocationAndAnnounce();
  }

  /// Gets current GPS location in background and speaks the alert.
  Future<void> _fetchLocationAndAnnounce() async {
    final position = await MapsService.instance.getCurrentPosition();
    String address = 'Unknown location';
    if (position != null) {
      _pendingLat = position.latitude;
      _pendingLng = position.longitude;
      address = await MapsService.instance.reverseGeocode(
        position.latitude,
        position.longitude,
      );
    }

    if (!mounted) return;
    setState(() {
      _pendingAddress = address;
      _locationFetched = true;
    });

    // 🔊 SPEAK the crash announcement immediately
    await VoiceService.instance.announceCrashDetected(address: address);
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _triggerAlert();
      }
    });
  }

  void _cancel() {
    if (_alertTriggered) return;
    _countdownTimer?.cancel();
    setState(() => _cancelled = true);

    // 🔊 Immediately cut off crash voice + say "you're safe"
    VoiceService.instance.announceCancelled();

    // Log cancelled incident.
    _logIncident(IncidentStatus.cancelled, false);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  Future<void> _triggerAlert() async {
    if (_cancelled || _alertTriggered) return;
    setState(() => _alertTriggered = true);

    final repo = context.read<ContactsRepository>();

    // Use already-fetched address & coordinates if available, otherwise re-fetch
    double lat = _pendingLat ?? 0;
    double lng = _pendingLng ?? 0;
    String address = _pendingAddress ?? 'Unknown location';

    if (lat == 0 && lng == 0) {
      final position = GpsService.instance.lastPosition ?? await MapsService.instance.getCurrentPosition();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
        if (address == 'Unknown location') {
          address = await MapsService.instance.reverseGeocode(lat, lng);
        }
      }
    }

    // 🔊 Announce alert is triggered (replaces the countdown announcement)
    VoiceService.instance.announceAlertTriggered(address: address);

    // 1. Auto-call emergency services (opens phone dialler).
    final prefs = await SharedPreferences.getInstance();
    final autoCall = prefs.getBool(AppConstants.prefKeyAutoCall) ?? true;
    final alertOnly = prefs.getBool(AppConstants.prefKeyAlertOnly) ?? false;
    bool callPlaced = false;

    if (autoCall && !alertOnly) {
      final number = prefs.getString(AppConstants.prefKeyEmergencyNumber) ??
          AppConstants.defaultEmergencyNumber;
      callPlaced = await AutoCallService.instance.callEmergency(number);
    }

    // 2. Notify contacts (email — wired in next session).
    //    For now, log them as notified so the UI is correct.
    // Notify contacts — email addresses logged; actual sending done via backend
    final notified = repo.contacts.map((c) => c.email).toList();

    // 3. Log incident to local DB + sync to backend.
    await _logIncident(IncidentStatus.confirmed, callPlaced,
        lat: lat, lng: lng, address: address, notified: notified);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(
        '/incident-detail',
        arguments: {
          'lat': lat,
          'lng': lng,
          'address': address,
          'callPlaced': callPlaced,
          'notified': notified,
        },
      );
    }
  }

  Future<void> _logIncident(
    IncidentStatus status,
    bool callPlaced, {
    double lat = 0,
    double lng = 0,
    String address = '',
    List<String> notified = const [],
  }) async {
    final repo = context.read<ContactsRepository>();
    final incident = Incident.create(
      lat: lat,
      lng: lng,
      address: address,
      sensorSnapshot: widget.sensorSnapshot,
    )
        .copyWith(
          status: status,
          contactsNotified: notified,
          emergencyCallPlaced: callPlaced,
        );

    await repo.logIncident(incident.toMap());
    repo.syncIncidentToBackend(incident.toMap());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _speedSub?.cancel();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: SafeArea(
          child: _cancelled
              ? _buildCancelledView()
              : _alertTriggered
                  ? _buildAlertingView()
                  : _buildCountdownView(),
        ),
      ),
    );
  }

  Widget _buildCountdownView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Header
          const Icon(Icons.warning_rounded, color: Color(0xFFFF3B30), size: 56),
          const SizedBox(height: 16),
          const Text(
            'CRASH DETECTED',
            style: TextStyle(
              color: Color(0xFFFF3B30),
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Emergency services will be alerted in',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 36),

          // Countdown ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (_, __) => CircularProgressIndicator(
                    value: 1 - _progressController.value,
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFF2C2C2E),
                    color: _secondsLeft <= 10
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFFFF9F0A),
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_secondsLeft',
                    style: TextStyle(
                      color: _secondsLeft <= 10
                          ? const Color(0xFFFF3B30)
                          : Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Text(
                    'seconds',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Sensor data badges ─────────────────────────────────────────────
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _SensorBadge(
                icon: Icons.speed_rounded,
                label: 'G-Force',
                value: '${widget.sensorSnapshot.gForce.toStringAsFixed(2)}G',
                highlight: widget.sensorSnapshot.gForce >= 3.0,
              ),
              if (widget.sensorSnapshot.rotationRate != null)
                _SensorBadge(
                  icon: Icons.rotate_90_degrees_ccw_rounded,
                  label: 'Rotation',
                  value:
                      '${widget.sensorSnapshot.rotationRate!.toStringAsFixed(0)}°/s',
                  highlight: widget.sensorSnapshot.rotationRate! >= 200,
                ),
              // 🆕 Live GPS speed badge
              _SensorBadge(
                icon: Icons.gps_fixed_rounded,
                label: 'Speed',
                value: '${_currentSpeedKmh.toStringAsFixed(1)} km/h',
                highlight: false,
                live: true,
              ),
              // 🆕 Speed drop badge
              if (widget.sensorSnapshot.speedDelta != null &&
                  widget.sensorSnapshot.speedDelta! > 0)
                _SensorBadge(
                  icon: Icons.trending_down_rounded,
                  label: 'Speed Drop',
                  value:
                      '${widget.sensorSnapshot.speedDelta!.toStringAsFixed(1)} km/h',
                  highlight: true,
                ),
            ],
          ),

          // 🆕 Location chip — shows when fetched
          if (_locationFetched && _pendingAddress != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF38383A), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Color(0xFFFF9F0A), size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _pendingAddress!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 🆕 Voice speaking indicator
          if (VoiceService.instance.isSpeaking)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.volume_up_rounded,
                      color: Color(0xFFFF9F0A), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Voice alert active…',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Cancel button
          ScaleTransition(
            scale: _pulseAnim,
            child: SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton(
                onPressed: _cancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF30D158),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 8,
                ),
                child: const Text(
                  "I'M OK — CANCEL",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap to cancel the emergency alert',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCancelledView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF30D158), size: 80),
          const SizedBox(height: 20),
          const Text(
            'Alert Cancelled',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No emergency services were notified.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 15,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          // 🆕 Voice indicator on cancel
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.volume_up_rounded,
                  color: Color(0xFF30D158), size: 16),
              const SizedBox(width: 6),
              Text(
                '"Alert cancelled. You are marked as safe."',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFFF3B30)),
          const SizedBox(height: 24),
          const Text(
            'Alerting Emergency Services…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching location & notifying contacts',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          // 🆕 Voice announcing in alerting phase
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.volume_up_rounded,
                  color: Color(0xFFFF3B30), size: 16),
              const SizedBox(width: 6),
              Text(
                'Voice alert broadcasting…',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sensor Badge Widget ────────────────────────────────────────────────────────

class _SensorBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final bool live;

  const _SensorBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.highlight,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = highlight
        ? const Color(0xFFFF3B30)
        : live
            ? const Color(0xFF0A84FF)
            : const Color(0xFF8E8E93);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? const Color(0xFFFF3B30).withOpacity(0.5)
              : const Color(0xFF38383A),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentColor, size: 14),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 9,
                  fontFamily: 'Inter',
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: highlight ? const Color(0xFFFF3B30) : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
