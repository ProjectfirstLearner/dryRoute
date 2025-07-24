import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'widgets/map_widget.dart';
import 'widgets/address_input_widget.dart';
import 'routing_service.dart';
import 'models/route_data.dart';
import 'radar_provider.dart';
import 'package:geolocator/geolocator.dart';

import 'shelter_finder.dart';

class MapScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenSettings;

  const MapScreen({super.key, this.onOpenSettings});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _startAddressController = TextEditingController();
  final _endAddressController = TextEditingController();

  RouteData _routeData = const RouteData();
  bool _setStartMode = false;
  bool _setEndMode = false;
  String _profile = 'foot-walking';
  bool _showRadar = true;

  void _updateRouteData(RouteData Function(RouteData) updater) {
    setState(() => _routeData = updater(_routeData));
  }

  void _setStartLocation(String coords) {
    final parts = coords.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0]);
      final lon = double.tryParse(parts[1]);
      if (lat != null && lon != null) {
        _updateRouteData((data) => data.copyWith(start: LatLng(lat, lon)));
        _startController.text = coords;
      }
    }
  }

  void _setEndLocation(String coords) {
    final parts = coords.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0]);
      final lon = double.tryParse(parts[1]);
      if (lat != null && lon != null) {
        _updateRouteData((data) => data.copyWith(end: LatLng(lat, lon)));
        _endController.text = coords;
      }
    }
  }

  void _onMapTap(LatLng latlng) {
    if (_setStartMode) {
      _setStartLocation('${latlng.latitude},${latlng.longitude}');
      _startAddressController.text = '${latlng.latitude},${latlng.longitude}';
      setState(() {
        _setStartMode = false;
        _setEndMode = true;
      });
    } else if (_setEndMode) {
      _setEndLocation('${latlng.latitude},${latlng.longitude}');
      _endAddressController.text = '${latlng.latitude},${latlng.longitude}';
      setState(() => _setEndMode = false);
    }
  }

  Future<void> _planRoute() async {
    if (_routeData.start == null || _routeData.end == null) {
      _updateRouteData((data) => data.copyWith(
        error: 'Bitte Start und Ziel setzen',
        isLoading: false,
      ));
      return;
    }

    _updateRouteData((data) => data.copyWith(
      isLoading: true,
      error: null,
    ));

    try {
      final routeResult = await RoutingService.getRoute(
        start: _routeData.start!,
        end: _routeData.end!,
        profile: _profile,
      );
      final shelters = await ShelterFinder.findSheltersNear(_routeData.end!);

      _updateRouteData((data) => data.copyWith(
        route: routeResult.coordinates,
        shelters: shelters,
        distanceInMeters: routeResult.distanceInMeters,
        durationInSeconds: routeResult.durationInSeconds,
        isLoading: false,
      ));
    } catch (e) {
      _updateRouteData((data) => data.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  Future<void> _setCurrentLocationAsStart() async {
    _updateRouteData((data) => data.copyWith(isLoading: true));

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Standortberechtigung verweigert.');
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latlng = LatLng(pos.latitude, pos.longitude);

      _updateRouteData((data) => data.copyWith(
        start: latlng,
        isLoading: false,
      ));
      _startController.text = '${latlng.latitude},${latlng.longitude}';
      _startAddressController.text = 'Mein Standort';
    } catch (e) {
      _updateRouteData((data) => data.copyWith(
        error: e.toString(),
        isLoading: false,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = _routeData.route.isNotEmpty 
        ? _routeData.route.first 
        : const LatLng(52.5200, 13.4050);
    final radarVisible = ref.watch(radarOverlayProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'DryRoute',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const Spacer(),
                          // Transport Mode Toggle
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildModeButton(
                                  Icons.directions_walk,
                                  'foot-walking',
                                  'Zu Fuß',
                                ),
                                _buildModeButton(
                                  Icons.directions_bike,
                                  'cycling-regular',
                                  'Rad',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Address Inputs
                      AddressInputWidget(
                        label: 'Von',
                        controller: _startAddressController,
                        onAddressSelected: _setStartLocation,
                        onSetLocationMode: () => setState(() {
                          _setStartMode = true;
                          _setEndMode = false;
                        }),
                        hasLocation: _routeData.start != null,
                        onCurrentLocation: _setCurrentLocationAsStart,
                      ),
                      const SizedBox(height: 16),
                      AddressInputWidget(
                        label: 'Nach',
                        controller: _endAddressController,
                        onAddressSelected: _setEndLocation,
                        onSetLocationMode: () => setState(() {
                          _setEndMode = true;
                          _setStartMode = false;
                        }),
                        hasLocation: _routeData.end != null,
                      ),
                      const SizedBox(height: 24),

                      // Route Button & Radar Toggle
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _routeData.isLoading ? null : _planRoute,
                              child: _routeData.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Route planen'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          _buildRadarToggle(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Error Display
            if (_routeData.error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _routeData.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Map
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MapWidget(
                    center: mapCenter,
                    route: _routeData.route,
                    shelters: _routeData.shelters,
                    start: _routeData.start,
                    end: _routeData.end,
                    onTap: _onMapTap,
                    showRadar: _showRadar,
                  ),
                ),
              ),
            ),

            // Bottom Info Card
            if (_routeData.route.isNotEmpty || _routeData.isLoading)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _routeData.isLoading
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Route wird berechnet...',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${((_routeData.distanceInMeters ?? 0) / 1000).toStringAsFixed(1)} km',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _routeData.shelters.isNotEmpty 
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.house,
                                          size: 16,
                                          color: _routeData.shelters.isNotEmpty 
                                              ? Colors.green 
                                              : Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_routeData.shelters.length} Unterstände',
                                          style: TextStyle(
                                            color: _routeData.shelters.isNotEmpty 
                                                ? Colors.green 
                                                : Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Geschätzte Dauer: ${((_routeData.durationInSeconds ?? 0) / 60).round()} Min',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    appBar: AppBar(
        title: const Text('DryRoute'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(radarVisible ? Icons.radar : Icons.radar_outlined),
            onPressed: () {
              ref.read(radarOverlayProvider.notifier).state = !radarVisible;
            },
            tooltip: radarVisible ? 'Radar ausblenden' : 'Radar einblenden',
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(IconData icon, String mode, String label) {
    final isSelected = _profile == mode;
    return GestureDetector(
      onTap: () => setState(() => _profile = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected 
                  ? Colors.white 
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected 
                    ? Colors.white 
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showRadar = !_showRadar),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _showRadar 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Icon(
          Icons.radar,
          color: _showRadar 
              ? Colors.white 
              : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _startAddressController.dispose();
    _endAddressController.dispose();
    super.dispose();
  }
}