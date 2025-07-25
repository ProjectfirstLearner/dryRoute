import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../radar_provider.dart';
import '../radar_tile_provider.dart';

class MapWidget extends ConsumerStatefulWidget {
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final Function(LatLng)? onTap;
  final bool showCurrentLocation;
  final LatLng? currentLocation;
  final bool isNavigationMode;

  const MapWidget({
    super.key,
    required this.center,
    this.zoom = 13.0,
    this.markers = const [],
    this.polylines = const [],
    this.onTap,
    this.showCurrentLocation = false,
    this.currentLocation,
    this.isNavigationMode = false,
  });

  @override
  ConsumerState<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidget> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isCompassLocked = false;
  double _currentRotation = 0.0;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _toggleCompassLock() {
    setState(() {
      _isCompassLocked = !_isCompassLocked;
      if (!_isCompassLocked) {
        // Reset rotation to north
        _currentRotation = 0.0;
        _rotationController.forward();
      }
    });
  }

  void _resetRotation() {
    _mapController.rotate(0.0);
    setState(() {
      _currentRotation = 0.0;
    });
  }

  List<Widget> _buildRadarLayers() {
    final radarState = ref.watch(radarProvider);
    
    if (!radarState.isVisible) return [];

    return [
      TileLayer(
        urlTemplate: RadarUrlHelper.getRadarUrl(
          radarState.source,
          0, 0, 0, // Placeholder values, will be replaced by flutter_map
        ).replaceAll('256/0/0/0', '256/{z}/{x}/{y}'),
        tileProvider: CachedRadarTileProvider(source: radarState.source),
        // Optimierungen für bessere Performance
        maxZoom: 18,
        keepBuffer: 2,
        panBuffer: 1,
        tileSize: 256,
        retinaMode: true,
      ),
    ];
  }

  Widget _buildCompassWidget() {
    return Positioned(
      top: widget.isNavigationMode ? 60 : 100,
      right: 16,
      child: Column(
        children: [
          // Kompass-Button
          Container(
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
            child: IconButton(
              onPressed: _toggleCompassLock,
              icon: Icon(
                _isCompassLocked ? Icons.explore : Icons.explore_off,
                color: _isCompassLocked ? Colors.blue : Colors.grey,
              ),
              tooltip: _isCompassLocked ? 'Kompass entsperren' : 'Nach Norden ausrichten',
            ),
          ),
          const SizedBox(height: 8),
          // Reset-Button (nur wenn Rotation vorhanden)
          if (_currentRotation != 0.0)
            Container(
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
              child: IconButton(
                onPressed: _resetRotation,
                icon: const Icon(Icons.navigation, color: Colors.blue),
                tooltip: 'Nach Norden ausrichten',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = List<Marker>.from(widget.markers);
    
    // Aktueller Standort Marker hinzufügen
    if (widget.showCurrentLocation && widget.currentLocation != null) {
      markers.add(
        Marker(
          point: widget.currentLocation!,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        minZoom: 3,
        maxZoom: 18,
        onTap: (tapPosition, point) {
          widget.onTap?.call(point);
        },
        onPositionChanged: (position, hasGesture) {
          // Position change handling could be added here
        },
        // Performance Optimierungen
        interactionOptions: const InteractionOptions(
          enableScrollWheel: true,
          scrollWheelVelocity: 0.005,
        ),
      ),
      children: [
        // Base Map Layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.dryroute',
          maxZoom: 19,
          // Performance Optimierungen
          keepBuffer: 3,
          panBuffer: 2,
          tileSize: 256,
          retinaMode: MediaQuery.of(context).devicePixelRatio > 1.5,
        ),
        
        // Radar Layers
        ..._buildRadarLayers(),
        
        // Polylines (Routen)
        if (widget.polylines.isNotEmpty)
          PolylineLayer(
            polylines: widget.polylines,
          ),
        
        // Markers
        if (markers.isNotEmpty)
          MarkerLayer(
            markers: markers,
          ),
        
        // Compass Widget
        _buildCompassWidget(),
      ],
    );
  }
}