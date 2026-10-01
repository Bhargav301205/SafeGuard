import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _gForce = AppConstants.defaultGForceThreshold;
  double _rotation = AppConstants.defaultRotationThreshold;
  double _speedDelta = AppConstants.defaultSpeedDeltaThreshold;
  bool _autoCall = true;
  bool _alertOnly = false;
  String _emergencyNumber = AppConstants.defaultEmergencyNumber;
  String _backendUrl = AppConstants.resolveBackendUrl();

  final _numberCtrl = TextEditingController();
  final _backendCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _gForce = p.getDouble(AppConstants.prefKeyGForceThreshold) ?? AppConstants.defaultGForceThreshold;
      _rotation = p.getDouble(AppConstants.prefKeyRotationThreshold) ?? AppConstants.defaultRotationThreshold;
      _speedDelta = p.getDouble(AppConstants.prefKeySpeedDeltaThreshold) ?? AppConstants.defaultSpeedDeltaThreshold;
      _autoCall = p.getBool(AppConstants.prefKeyAutoCall) ?? true;
      _alertOnly = p.getBool(AppConstants.prefKeyAlertOnly) ?? false;
      _emergencyNumber = p.getString(AppConstants.prefKeyEmergencyNumber) ?? AppConstants.defaultEmergencyNumber;
      _backendUrl = p.getString(AppConstants.prefKeyBackendUrl) ?? AppConstants.resolveBackendUrl();
    });
    _numberCtrl.text = _emergencyNumber;
    _backendCtrl.text = _backendUrl;
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(AppConstants.prefKeyGForceThreshold, _gForce);
    await p.setDouble(AppConstants.prefKeyRotationThreshold, _rotation);
    await p.setDouble(AppConstants.prefKeySpeedDeltaThreshold, _speedDelta);
    await p.setBool(AppConstants.prefKeyAutoCall, _autoCall);
    await p.setBool(AppConstants.prefKeyAlertOnly, _alertOnly);
    await p.setString(AppConstants.prefKeyEmergencyNumber, _numberCtrl.text.trim());
    await p.setString(AppConstants.prefKeyBackendUrl, _backendCtrl.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: Color(0xFF30D158),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _backendCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('Settings',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: Color(0xFF0A84FF),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('Detection Thresholds'),
          _sliderTile(
            label: 'G-Force Threshold',
            value: _gForce,
            min: 2.0,
            max: 6.0,
            divisions: 16,
            format: (v) => '${v.toStringAsFixed(1)}G',
            description: 'Impact magnitude to trigger detection (default 3.5G)',
            onChanged: (v) => setState(() => _gForce = v),
          ),
          _sliderTile(
            label: 'Rotation Threshold',
            value: _rotation,
            min: 100,
            max: 500,
            divisions: 40,
            format: (v) => '${v.toStringAsFixed(0)}°/s',
            description: 'Angular velocity to trigger detection (default 250°/s)',
            onChanged: (v) => setState(() => _rotation = v),
          ),
          _sliderTile(
            label: 'Speed Drop Threshold',
            value: _speedDelta,
            min: 20,
            max: 80,
            divisions: 60,
            format: (v) => '${v.toStringAsFixed(0)} km/h',
            description: 'Speed drop within 2s to trigger detection (default 40)',
            onChanged: (v) => setState(() => _speedDelta = v),
          ),

          const SizedBox(height: 8),
          _section('Emergency Response'),
          _switchTile(
            label: 'Auto-Call Emergency Services',
            subtitle: 'Automatically dial the emergency number on confirmed crash',
            value: _autoCall,
            onChanged: (v) => setState(() {
              _autoCall = v;
              if (v) _alertOnly = false;
            }),
          ),
          _switchTile(
            label: 'Alert-Only Mode',
            subtitle: 'Only send email alerts — no phone call will be placed',
            value: _alertOnly,
            onChanged: (v) => setState(() {
              _alertOnly = v;
              if (v) _autoCall = false;
            }),
          ),
          _textFieldTile(
            label: 'Emergency Phone Number',
            controller: _numberCtrl,
            keyboardType: TextInputType.phone,
            hint: '112',
          ),

          const SizedBox(height: 8),
          _section('Backend'),
          _textFieldTile(
            label: 'Backend URL',
            controller: _backendCtrl,
            keyboardType: TextInputType.url,
            hint: AppConstants.resolveBackendUrl(),
          ),

          const SizedBox(height: 32),
          OutlinedButton.icon(
            icon: const Icon(Icons.restore, color: Colors.white38),
            label: const Text('Reset to Defaults',
                style: TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Inter')),
            onPressed: () async {
              setState(() {
                _gForce = AppConstants.defaultGForceThreshold;
                _rotation = AppConstants.defaultRotationThreshold;
                _speedDelta = AppConstants.defaultSpeedDeltaThreshold;
                _autoCall = true;
                _alertOnly = false;
              });
              _numberCtrl.text = AppConstants.defaultEmergencyNumber;
              _backendCtrl.text = AppConstants.resolveBackendUrl();
              await _save();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Text(title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 1.2,
            )),
      );

  Widget _sliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required String description,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(format(value),
                    style: const TextStyle(
                        color: Color(0xFF0A84FF),
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            activeColor: const Color(0xFF0A84FF),
            inactiveColor: const Color(0xFF3A3A3C),
          ),
          Text(description,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontFamily: 'Inter',
                  fontSize: 11)),
        ],
      ),
    );
  }

  Widget _switchTile({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontFamily: 'Inter',
                        fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF30D158),
          ),
        ],
      ),
    );
  }

  Widget _textFieldTile({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required String hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
                color: Colors.white, fontFamily: 'Inter', fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontFamily: 'Inter'),
              filled: true,
              fillColor: const Color(0xFF2C2C2E),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
