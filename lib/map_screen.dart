
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';

import 'widgets/map_widget.dart';
import 'widgets/address_input_widget.dart';
import 'radar_provider.dart';
import 'routing_service.dart';
import 'navigation_service.dart';
import 'nominatim_service.dart';
import 'shelter_finder.dart';
import 'models/route_data.dart';
import 'settings_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  LatLng _currentCenter = const LatLng(51.1657, 10.4515); // Deutschland Zentrum
  final double _currentZoom = 6.0;
  
  String _startAddress = '';
  String _endAddress = '';
  LatLng? _startPoint;
  LatLng? _endPoint;
  LatLng? _currentLocation;
  RouteData? _currentRoute;
  List<Shelter> _shelters = [];
  
  bool _isSelectingMapPoint = false;
  bool _isSelectingStart = false;
  bool _isLoadingRoute = false;
  bool _showShelters = false;

  final RoutingService _routingService = RoutingService();
  final NavigationService _navigationService = NavigationService();
  final NominatimService _nominatimService = NominatimService();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentCenter = _currentLocation!;
      });
    } catch (e) {
      print('Standort konnte nicht ermittelt werden: $e');
    }
  }

  void _onMapTap(LatLng point) {
    if (_isSelectingMapPoint) {
      setState(() {
        if (_isSelectingStart) {
          _startPoint = point;
          _startAddress = 'Ausgewählter Punkt';
        } else {
          _endPoint = point;
          _endAddress = 'Ausgewählter Punkt';
        }
        _isSelectingMapPoint = false;
      });
    }
  }

  void _onAddressChanged(String address, LatLng? location, bool isStart) {
    if (address == 'Punkt auf Karte wählen') {
      setState(() {
        _isSelectingMapPoint = true;
        _isSelectingStart = isStart;
      });
      return;
    }

    setState(() {
      if (isStart) {
        _startAddress = address;
        _startPoint = location;
      } else {
        _endAddress = address;
        _endPoint = location;
      }
    });

    // Geocoding falls keine Koordinaten vorhanden
    if (location == null && address.isNotEmpty && address != 'Aktueller Standort') {
      _geocodeAddress(address, isStart);
    }
  }

  Future<void> _geocodeAddress(String address, bool isStart) async {
    try {
      final results = await _nominatimService.searchAddresses(address);
      if (results.isNotEmpty) {
        final result = results.first;
        setState(() {
          if (isStart) {
            _startPoint = result.location;
            _startAddress = result.shortName;
          } else {
            _endPoint = result.location;
            _endAddress = result.shortName;
          }
        });
      }
    } catch (e) {
      print('Geocoding Fehler: $e');
    }
  }

  Future<void> _calculateRoute() async {
    if (_startPoint == null || _endPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Start- und Endpunkt auswählen')),
      );
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final route = await _routingService.calculateRoute(
        _startPoint!,
        _endPoint!,
        startAddress: _startAddress,
        endAddress: _endAddress,
      );

      if (route != null) {
        setState(() {
          _currentRoute = route;
        });
      } else {
        // Fallback: Luftlinie
        final fallbackRoute = _routingService.createStraightLineRoute(
          _startPoint!,
          _endPoint!,
          _startAddress,
          _endAddress,
        );
        setState(() {
          _currentRoute = fallbackRoute;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route als Luftlinie berechnet (kein Routing Service verfügbar)')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler bei Routenberechnung: $e')),
      );
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  Future<void> _startNavigation() async {
    if (_currentRoute == null) return;

    await _navigationService.startNavigation(_currentRoute!);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigation gestartet - Sie erhalten Benachrichtigungen bei Regen'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _stopNavigation() {
    _navigationService.stopNavigation();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation beendet')),
    );
  }

  Future<void> _findShelters() async {
    if (_currentLocation == null) return;

    try {
      final shelters = await ShelterFinder.findNearbyShelters(_currentLocation!);
      setState(() {
        _shelters = shelters;
        _showShelters = true;
      });
    } catch (e) {
      print('Fehler beim Laden der Unterstände: $e');
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Start Marker
    if (_startPoint != null) {
      markers.add(
        Marker(
          point: _startPoint!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.play_arrow,
            color: Colors.green,
            size: 40,
          ),
        ),
      );
    }

    // End Marker
    if (_endPoint != null) {
      markers.add(
        Marker(
          point: _endPoint!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.stop,
            color: Colors.red,
            size: 40,
          ),
        ),
      );
    }

    // Shelter Markers
    if (_showShelters) {
      for (final shelter in _shelters) {
        markers.add(
          Marker(
            point: shelter.location,
            width: 30,
            height: 30,
            child: Tooltip(
              message: shelter.displayName,
              child: const Icon(
                Icons.umbrella,
                color: Colors.orange,
                size: 30,
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    if (_currentRoute == null) return [];

    return [
      Polyline(
        points: _currentRoute!.polylinePoints,
        color: Colors.blue,
        strokeWidth: 4.0,
      ),
    ];
  }

  Widget _buildRadarControls() {
    final radarState = ref.watch(radarProvider);

    return Positioned(
      top: 100,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: PopupMenuButton<String>(
          icon: Icon(
            Icons.layers,
            color: radarState.isVisible ? Colors.blue : Colors.grey,
          ),
          tooltip: 'Radar Optionen',
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(radarState.isVisible ? Icons.visibility_off : Icons.visibility),
                  const SizedBox(width: 8),
                  Text(radarState.isVisible ? 'Radar ausblenden' : 'Radar anzeigen'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'rainviewer',
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: radarState.source == RadarSource.rainviewer ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text('RainViewer'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'dwd',
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: radarState.source == RadarSource.dwd ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text('DWD'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'openweathermap',
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: radarState.source == RadarSource.openweathermap ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text('OpenWeatherMap'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'shelters',
              child: Row(
                children: [
                  Icon(_showShelters ? Icons.umbrella : Icons.umbrella_outlined),
                  const SizedBox(width: 8),
                  Text(_showShelters ? 'Unterstände ausblenden' : 'Unterstände anzeigen'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'toggle':
                ref.read(radarProvider.notifier).toggleVisibility();
                break;
              case 'rainviewer':
                ref.read(radarProvider.notifier).setSource(RadarSource.rainviewer);
                if (!radarState.isVisible) {
                  ref.read(radarProvider.notifier).show();
                }
                break;
              case 'dwd':
                ref.read(radarProvider.notifier).setSource(RadarSource.dwd);
                if (!radarState.isVisible) {
                  ref.read(radarProvider.notifier).show();
                }
                break;
              case 'openweathermap':
                ref.read(radarProvider.notifier).setSource(RadarSource.openweathermap);
                if (!radarState.isVisible) {
                  ref.read(radarProvider.notifier).show();
                }
                break;
              case 'shelters':
                if (_showShelters) {
                  setState(() {
                    _showShelters = false;
                    _shelters.clear();
                  });
                } else {
                  _findShelters();
                }
                break;
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNavigating = _navigationService.isNavigating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DryRoute'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            center: _currentCenter,
            zoom: _currentZoom,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            onTap: _onMapTap,
            showCurrentLocation: true,
            currentLocation: _currentLocation,
            isNavigationMode: isNavigating,
          ),
          _buildRadarControls(),
          if (_isSelectingMapPoint)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isSelectingStart 
                      ? 'Startpunkt auf der Karte auswählen'
                      : 'Zielpunkt auf der Karte auswählen',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isNavigating) ...[
              AddressInputWidget(
                label: 'Start',
                value: _startAddress,
                onChanged: (address, location) => _onAddressChanged(address, location, true),
                isStart: true,
              ),
              const SizedBox(height: 16),
              AddressInputWidget(
                label: 'Ziel',
                value: _endAddress,
                onChanged: (address, location) => _onAddressChanged(address, location, false),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoadingRoute ? null : _calculateRoute,
                      child: _isLoadingRoute
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Route berechnen'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _currentRoute == null ? null : _startNavigation,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Navigation starten'),
                  ),
                ],
              ),
              if (_currentRoute != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${_currentRoute!.formattedDistance} • ${_currentRoute!.formattedDuration}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ] else ...[
              Text(
                'Navigation aktiv',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_currentRoute != null)
                Text(
                  '${_currentRoute!.formattedDistance} • ${_currentRoute!.formattedDuration}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _stopNavigation,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Navigation beenden'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
