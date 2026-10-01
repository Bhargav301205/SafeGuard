import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../contacts/contacts_repository.dart';
import '../models/incident.dart';
import '../models/sensor_reading.dart';
import '../maps/live_location_screen.dart';
import 'package:provider/provider.dart';

class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({super.key});

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  List<Map<String, dynamic>> _incidents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    final repo = context.read<ContactsRepository>();
    final data = await repo.getIncidents();
    setState(() {
      _incidents = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('Incident History',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: () {
              setState(() => _loading = true);
              _loadIncidents();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0A84FF)))
          : _incidents.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off,
              size: 64, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text('No incidents recorded',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontFamily: 'Inter',
                  fontSize: 16)),
          const SizedBox(height: 6),
          Text('Triggered and cancelled events will appear here',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontFamily: 'Inter',
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _incidents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final raw = _incidents[i];
        final status = IncidentStatus.values.firstWhere(
          (e) => e.name == raw['status'],
          orElse: () => IncidentStatus.pending,
        );
        final ts = DateTime.parse(raw['timestamp'] as String);
        final lat = (raw['lat'] as num).toDouble();
        final lng = (raw['lng'] as num).toDouble();
        final address = raw['address'] as String? ?? 'Unknown';

        return GestureDetector(
          onTap: () => _showDetail(raw),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _statusColor(status).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_statusIcon(status),
                      color: _statusColor(status), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatusBadge(status),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('MMM d, y — HH:mm').format(ts.toLocal()),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontFamily: 'Inter',
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.isNotEmpty ? address : '$lat, $lng',
                        style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Colors.white24, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetail(Map<String, dynamic> raw) {
    final sensorRaw = raw['sensorSnapshot'] as Map<String, dynamic>;
    final sensor = SensorReading.fromMap(sensorRaw);
    final status = IncidentStatus.values.firstWhere(
      (e) => e.name == raw['status'],
      orElse: () => IncidentStatus.pending,
    );
    final lat = (raw['lat'] as num).toDouble();
    final lng = (raw['lng'] as num).toDouble();
    final address = raw['address'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _StatusBadge(status),
                const Spacer(),
                Text(
                  DateFormat('MMM d, y HH:mm').format(
                      DateTime.parse(raw['timestamp'] as String).toLocal()),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontFamily: 'Inter',
                      fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow('📍 Location', address.isEmpty ? '$lat, $lng' : address),
            _detailRow('⚡ G-Force', '${sensor.gForce.toStringAsFixed(2)}G'),
            if (sensor.rotationRate != null)
              _detailRow('🔄 Rotation', '${sensor.rotationRate!.toStringAsFixed(0)}°/s'),
            if (sensor.speedDelta != null)
              _detailRow('🚗 Speed Drop', '${sensor.speedDelta!.toStringAsFixed(0)} km/h'),
            _detailRow(
              '📞 Emergency Call',
              (raw['emergency_call_placed'] == 1 || raw['emergency_call_placed'] == true)
                  ? 'Placed'
                  : 'Not placed',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('View on Map',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A84FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveLocationScreen(
                        initialLat: lat,
                        initialLng: lng,
                        address: address,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontFamily: 'Inter',
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(IncidentStatus s) {
    return switch (s) {
      IncidentStatus.confirmed => const Color(0xFFFF3B30),
      IncidentStatus.cancelled => const Color(0xFF30D158),
      IncidentStatus.pending => const Color(0xFFFF9F0A),
    };
  }

  IconData _statusIcon(IncidentStatus s) {
    return switch (s) {
      IncidentStatus.confirmed => Icons.warning_rounded,
      IncidentStatus.cancelled => Icons.check_circle_outline,
      IncidentStatus.pending => Icons.hourglass_empty,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  final IncidentStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      IncidentStatus.confirmed => const Color(0xFFFF3B30),
      IncidentStatus.cancelled => const Color(0xFF30D158),
      IncidentStatus.pending => const Color(0xFFFF9F0A),
    };
    final label = switch (status) {
      IncidentStatus.confirmed => 'CONFIRMED',
      IncidentStatus.cancelled => 'CANCELLED',
      IncidentStatus.pending => 'PENDING',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.8)),
    );
  }
}
