import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../maps/maps_service.dart';
import '../emergency/nearest_services.dart';

/// Displays the user's current location on a Google Map.
/// Also shows nearest police stations and hospitals when triggered
/// post-crash, complete with distance indicators and quick navigation actions.
class LiveLocationScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? address;

  const LiveLocationScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.address,
  });

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  bool _loading = true;

  List<NearbyPlace> _policePlaces = [];
  List<NearbyPlace> _hospitalPlaces = [];
  bool _servicesLoading = false;
  NearbyPlace? _selectedPlace;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _currentPosition = LatLng(widget.initialLat!, widget.initialLng!);
      _loading = false;
      _addMarkers();
    } else {
      _loadCurrentPosition();
    }
  }

  Future<void> _loadCurrentPosition() async {
    final pos = await MapsService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _loading = false;
      });
      _addMarkers();
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _addMarkers() {
    if (_currentPosition == null) return;
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: _currentPosition!,
          infoWindow: InfoWindow(
            title: 'Your Location',
            snippet: widget.address ?? 'Current position',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    });
    _loadNearestServices();
  }

  Future<void> _loadNearestServices() async {
    if (_currentPosition == null) return;
    setState(() => _servicesLoading = true);

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    try {
      final results = await Future.wait([
        NearestServicesClient.instance.getNearest(
          lat: lat,
          lng: lng,
          type: NearbyServiceType.police,
          limit: 3,
        ),
        NearestServicesClient.instance.getNearest(
          lat: lat,
          lng: lng,
          type: NearbyServiceType.hospital,
          limit: 3,
        ),
      ]);

      if (!mounted) return;

      final police = results[0];
      final hospitals = results[1];

      setState(() {
        _policePlaces = police;
        _hospitalPlaces = hospitals;
        _servicesLoading = false;

        // Add police markers (Blue)
        for (final p in police) {
          _markers.add(Marker(
            markerId: MarkerId('police_${p.name}'),
            position: LatLng(p.lat, p.lng),
            infoWindow: InfoWindow(
              title: '👮 ${p.name}',
              snippet: '${p.distanceKm.toStringAsFixed(1)} km away • ${p.address}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            onTap: () => _selectPlace(p),
          ));
        }

        // Add hospital markers (Rose/Red)
        for (final h in hospitals) {
          _markers.add(Marker(
            markerId: MarkerId('hospital_${h.name}'),
            position: LatLng(h.lat, h.lng),
            infoWindow: InfoWindow(
              title: '🏥 ${h.name}',
              snippet: '${h.distanceKm.toStringAsFixed(1)} km away • ${h.address}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
            onTap: () => _selectPlace(h),
          ));
        }
      });
    } catch (e) {
      if (mounted) setState(() => _servicesLoading = false);
    }
  }

  void _selectPlace(NearbyPlace place) {
    setState(() => _selectedPlace = place);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(place.lat, place.lng), 15.5),
    );
  }

  void _openDirections(NearbyPlace place) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${place.lat},${place.lng}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          'Live Location & Services',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              _loadNearestServices();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0A84FF)))
          : _currentPosition == null
              ? const Center(
                  child: Text(
                    'Unable to fetch location.\nCheck GPS permissions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white54, fontFamily: 'Inter'),
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentPosition!,
                        zoom: 14.5,
                      ),
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      mapType: MapType.normal,
                      onMapCreated: (ctrl) {
                        _mapController = ctrl;
                        ctrl.setMapStyle(_darkMapStyle);
                      },
                    ),

                    // Top summary overlay: Address & status
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFFF3B30), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.address ??
                                    '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Emergency Services Carousel
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 125,
                        child: _servicesLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0A84FF),
                                ),
                              )
                            : ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                  ..._hospitalPlaces.map((h) => _buildPlaceCard(h, isHospital: true)),
                                  ..._policePlaces.map((p) => _buildPlaceCard(p, isHospital: false)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPlaceCard(NearbyPlace place, {required bool isHospital}) {
    final color = isHospital ? const Color(0xFFFF453A) : const Color(0xFF0A84FF);
    final icon = isHospital ? Icons.local_hospital : Icons.local_police;
    final isSelected = _selectedPlace?.name == place.name;

    return GestureDetector(
      onTap: () => _selectPlace(place),
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E).withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: isSelected ? 2 : 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    place.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              '${place.distanceKm.toStringAsFixed(1)} km away • ${place.address}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontFamily: 'Inter',
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(
              height: 28,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.navigation, size: 12),
                label: const Text('Navigate', style: TextStyle(fontSize: 11, fontFamily: 'Inter')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openDirections(place),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

// Dark map style JSON
const _darkMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]}
]''';
