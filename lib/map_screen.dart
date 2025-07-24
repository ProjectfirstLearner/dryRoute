import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';


import 'radar_provider.dart';
import 'routing_service.dart';
import 'shelter_finder.dart';
import 'nominatim_service.dart';


typedef VoidCallback = void Function();

class MapScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenSettings;
  MapScreen({super.key, this.onOpenSettings});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  _MapScreenState();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final TextEditingController _startAddressController = TextEditingController();
  final TextEditingController _endAddressController = TextEditingController();
  // Debounce Timer für Suggestions
  Duration _debounceDuration = const Duration(milliseconds: 350);
  DateTime? _lastStartSuggest;
  DateTime? _lastEndSuggest;

  List<LatLng> _route = [];
  List<LatLng> _shelters = [];
  bool _loading = false;
  String? _error;
  LatLng? _start;
  LatLng? _end;
  bool _setStartMode = false;
  bool _setEndMode = false;
  List<NominatimSuggestion> _startSuggestions = const [];
  List<NominatimSuggestion> _endSuggestions = const [];
  bool _startAddressSelected = false;
  bool _endAddressSelected = false;
  bool _showCoords = false;
  String _profile = 'foot-walking';

  // --- Widget-Optimierungen ---
  Widget _buildStartAddressInput() {
    return Stack(
      children: [
        TextField(
          controller: _startAddressController,
          decoration: InputDecoration(
            labelText: 'Start-Adresse',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.my_location, color: Colors.blue),
                  tooltip: 'Aktuellen Standort verwenden',
                  onPressed: _loading ? null : _setCurrentLocationAsStart,
                ),
                if (_startAddressSelected)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
          ),
          onChanged: (value) {
            _debouncedStartSuggest(value);
          },
        ),
        if (_startSuggestions.isNotEmpty || true)
          Positioned(
            left: 0,
            right: 0,
            top: 56,
            child: Material(
              elevation: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_startSuggestions.isNotEmpty)
                    ...List.generate(_startSuggestions.length, (idx) {
                      final s = _startSuggestions[idx];
                      return ListTile(
                        title: Text(s.displayName),
                        onTap: () {
                          setState(() {
                            _start = LatLng(s.lat, s.lon);
                            _startController.text = '${s.lat},${s.lon}';
                            _startAddressController.text = s.displayName;
                            _startSuggestions = const [];
                            _startAddressSelected = true;
                          });
                        },
                      );
                    }),
                  ListTile(
                    leading: const Icon(Icons.touch_app),
                    title: const Text('Punkt auf Karte wählen'),
                    onTap: () {
                      setState(() {
                        _setStartMode = true;
                        _setEndMode = false;
                        _startSuggestions = const [];
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEndAddressInput() {
    return Stack(
      children: [
        TextField(
          controller: _endAddressController,
          decoration: InputDecoration(
            labelText: 'Ziel-Adresse',
            suffixIcon: _endAddressSelected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.location_searching, color: Colors.grey),
          ),
          onChanged: (value) {
            _debouncedEndSuggest(value);
          },
        ),
        if (_endSuggestions.isNotEmpty || true)
          Positioned(
            left: 0,
            right: 0,
            top: 56,
            child: Material(
              elevation: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_endSuggestions.isNotEmpty)
                    ...List.generate(_endSuggestions.length, (idx) {
                      final s = _endSuggestions[idx];
                      return ListTile(
                        title: Text(s.displayName),
                        onTap: () {
                          setState(() {
                            _end = LatLng(s.lat, s.lon);
                            _endController.text = '${s.lat},${s.lon}';
                            _endAddressController.text = s.displayName;
                            _endSuggestions = const [];
                            _endAddressSelected = true;
                          });
                        },
                      );
                    }),
                  ListTile(
                    leading: const Icon(Icons.touch_app),
                    title: const Text('Punkt auf Karte wählen'),
                    onTap: () {
                      setState(() {
                        _setEndMode = true;
                        _setStartMode = false;
                        _endSuggestions = const [];
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRouteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _planRoute,
        child: _loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Route planen'),
      ),
    );
  }

  Widget _buildMarkerButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _setStartMode ? null : () {
            setState(() { _setStartMode = true; _setEndMode = false; });
          },
          child: const Text('Startpunkt auf Karte setzen'),
        ),
        ElevatedButton(
          onPressed: _setEndMode ? null : () {
            setState(() { _setEndMode = true; _setStartMode = false; });
          },
          child: const Text('Zielpunkt auf Karte setzen'),
        ),
        TextButton.icon(
          icon: const Icon(Icons.pin_drop, size: 18),
          label: Text(_showCoords ? 'Koordinaten ausblenden' : 'Koordinaten eingeben'),
          onPressed: () {
            setState(() { _showCoords = !_showCoords; });
          },
        ),
      ],
    );
  }

  Widget _buildCoordInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Flexible(
            child: SizedBox(
              width: 120,
              child: TextField(
                controller: _startController,
                decoration: const InputDecoration(labelText: 'Start (lat,lon)', isDense: true),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: SizedBox(
              width: 120,
              child: TextField(
                controller: _endController,
                decoration: const InputDecoration(labelText: 'Ziel (lat,lon)', isDense: true),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(LatLng mapCenter) {
    final List<Marker> startMarkers = _start != null
        ? [Marker(point: _start!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.blue, size: 36))]
        : const [];
    final List<Marker> endMarkers = _end != null
        ? [Marker(point: _end!, width: 40, height: 40, child: const Icon(Icons.flag, color: Colors.red, size: 36))]
        : const [];
    final List<Marker> shelterMarkers = _shelters.isNotEmpty 
        ? _shelters.map((shelter) => Marker(
            point: shelter,
            width: 30,
            height: 30,
            child: const Icon(Icons.house, color: Colors.green, size: 24),
          )).toList()
        : const [];
    // Riverpod: Radar-Provider und Overlay-Toggle
    final radarTileUrl = ref.watch(radarTileProviderProvider);
    final showRadar = ref.watch(radarOverlayProvider);
    return FlutterMap(
      options: MapOptions(
        initialCenter: mapCenter,
        initialZoom: 13.0,
        onTap: (tapPos, latlng) {
          if (_setStartMode) {
            setState(() {
              _start = latlng;
              _startController.text = '${latlng.latitude},${latlng.longitude}';
              _startAddressController.text = '${latlng.latitude},${latlng.longitude}';
              _setStartMode = false;
              _setEndMode = true;
            });
          } else if (_setEndMode) {
            setState(() {
              _end = latlng;
              _endController.text = '${latlng.latitude},${latlng.longitude}';
              _endAddressController.text = '${latlng.latitude},${latlng.longitude}';
              _setEndMode = false;
            });
          }
        },
        onLongPress: (tapPos, latlng) {
          if (_setStartMode) {
            setState(() {
              _start = latlng;
              _startController.text = '${latlng.latitude},${latlng.longitude}';
              _startAddressController.text = '${latlng.latitude},${latlng.longitude}';
              _setStartMode = false;
              _setEndMode = true;
            });
          } else if (_setEndMode) {
            setState(() {
              _end = latlng;
              _endController.text = '${latlng.latitude},${latlng.longitude}';
              _endAddressController.text = '${latlng.latitude},${latlng.longitude}';
              _setEndMode = false;
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'de.dryroute.app',
        ),
        if (showRadar)
          TileLayer(
            urlTemplate: radarTileUrl,
          ),
        if (startMarkers.isNotEmpty)
          MarkerLayer(markers: startMarkers),
        if (endMarkers.isNotEmpty)
          MarkerLayer(markers: endMarkers),
        if (_route.isNotEmpty)
          PolylineLayer(
            polylines: [Polyline(points: _route, color: Colors.blue, strokeWidth: 5)],
          ),
        if (shelterMarkers.isNotEmpty)
          MarkerLayer(markers: shelterMarkers),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: _loading
          ? const Text('Lade Route und Shelter...')
          : (_route.isNotEmpty
              ? Text('Route-Länge: ~${_route.length * 100} m, Shelter: ${_shelters.length}')
              : const Text('Regenvorhersage & Shelter-Vorschläge erscheinen hier.')),
    );
  }

  Widget _buildProfileButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        setState(() {
          _profile = _profile == 'foot-walking' ? 'cycling-regular' : 'foot-walking';
        });
      },
      icon: Icon(_profile == 'foot-walking' ? Icons.directions_walk : Icons.directions_bike),
      label: Text(_profile == 'foot-walking' ? 'Zu Rad' : 'Zu Fuß'),
      tooltip: 'Profil wechseln',
    );
  }

  // --- Debounce-Optimierung für Suggestions ---
  void _debouncedStartSuggest(String value) async {
    _lastStartSuggest = DateTime.now();
    final captured = _lastStartSuggest;
    if (value.isEmpty) {
      setState(() { _startSuggestions = const []; _startAddressSelected = false; });
      return;
    }
    await Future.delayed(_debounceDuration);
    if (_lastStartSuggest != captured) return;
    final suggestions = await NominatimService.search(value);
    if (_lastStartSuggest == captured) {
      setState(() {
        _startSuggestions = suggestions;
        _startAddressSelected = false;
      });
    }
  }

  void _debouncedEndSuggest(String value) async {
    _lastEndSuggest = DateTime.now();
    final captured = _lastEndSuggest;
    if (value.isEmpty) {
      setState(() { _endSuggestions = const []; _endAddressSelected = false; });
      return;
    }
    await Future.delayed(_debounceDuration);
    if (_lastEndSuggest != captured) return;
    final suggestions = await NominatimService.search(value);
    if (_lastEndSuggest == captured) {
      setState(() {
        _endSuggestions = suggestions;
        _endAddressSelected = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('MapScreen build() gestartet');
    final mapCenter = _route.isNotEmpty ? _route.first : const LatLng(52.5200, 13.4050);
    return Scaffold(
      appBar: AppBar(
        title: const Text('DryRoute'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Einstellungen',
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Start-Adresseingabe
                _buildStartAddressInput(),
                const SizedBox(height: 8),
                // Ziel-Adresseingabe
                _buildEndAddressInput(),
                const SizedBox(height: 8),
                // Route planen Button
                _buildRouteButton(),
                const SizedBox(height: 8),
                // Buttons für Marker setzen, Koordinaten anzeigen etc.
                const SizedBox(height: 8),
                _buildMarkerButtons(),
                if (_showCoords) _buildCoordInput(),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(child: _buildMap(mapCenter)),
          _buildInfoCard(),
        ],
      ),
      floatingActionButton: _buildProfileButton(),
    );
  }

  Future<void> _planRoute() async {
    setState(() {
      _loading = true;
      _error = null;
      _route = [];
      _shelters = [];
    });
    try {
      // Priorität: Marker, dann Textfeld
      LatLng? start = _start;
      LatLng? end = _end;
      if (start == null && _startController.text.isNotEmpty) {
        final startParts = _startController.text.split(',');
        if (startParts.length == 2) {
          start = LatLng(double.parse(startParts[0]), double.parse(startParts[1]));
        }
      }
      if (end == null && _endController.text.isNotEmpty) {
        final endParts = _endController.text.split(',');
        if (endParts.length == 2) {
          end = LatLng(double.parse(endParts[0]), double.parse(endParts[1]));
        }
      }
      if (start == null || end == null) {
        throw Exception('Bitte Start und Ziel per Marker, Koordinate oder Adresse setzen.');
      }
      // Snap to road
      start = await _snapToRoad(start);
      end = await _snapToRoad(end);
      final route = await RoutingService.getRoute(start: start, end: end, profile: _profile);
      final shelters = await ShelterFinder.findSheltersNear(end);
      setState(() {
        _route = route;
        _shelters = shelters;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }



  Future<LatLng> _snapToRoad(LatLng point) async {
    // Nutzt ORS-Nearest, um den Punkt auf die nächste Straße zu snappen
    final apiKey = dotenv.env['ORS_API_KEY']?.replaceAll("'", "");
    final url = Uri.parse(
      'https://api.openrouteservice.org/nearest?api_key=$apiKey',
    );
    final body = jsonEncode({
      'coordinates': [[point.longitude, point.latitude]],
    });
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final snapped = data['features']?[0]?['geometry']?['coordinates'];
      if (snapped != null && snapped.length == 2) {
        return LatLng((snapped[1] as num).toDouble(), (snapped[0] as num).toDouble());
      }
    }
    // Fallback: original Punkt
    return point;
  }

  Future<void> _setCurrentLocationAsStart() async {
    setState(() { _loading = true; _error = null; });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Standortberechtigung verweigert.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Standortberechtigung dauerhaft verweigert. Bitte in den Einstellungen aktivieren.');
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _start = latlng;
        _startController.text = '${latlng.latitude},${latlng.longitude}';
        _startAddressController.text = 'Mein Standort';
        _startAddressSelected = true;
        _loading = false;
        // KEIN _planRoute() Aufruf hier!
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    // dotenv.load();
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
