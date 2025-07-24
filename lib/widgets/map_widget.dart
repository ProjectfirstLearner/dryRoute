
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../radar_provider.dart';

class MapWidget extends ConsumerStatefulWidget {
  final LatLng center;
  final List<LatLng> route;
  final List<LatLng> shelters;
  final LatLng? start;
  final LatLng? end;
  final Function(LatLng) onTap;
  final bool showRadar;

  const MapWidget({
    super.key,
    required this.center,
    required this.route,
    required this.shelters,
    this.start,
    this.end,
    required this.onTap,
    this.showRadar = true,
  });

  @override
  ConsumerState<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidget> {
  final MapController _mapController = MapController();
  List<LatLng> _previousRoute = [];

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Wenn eine neue Route berechnet wurde, zoome darauf
    if (widget.route.isNotEmpty && 
        widget.route != _previousRoute && 
        widget.route.length > 1) {
      _previousRoute = widget.route;
      // Längeres Delay für stabilere Kamera-Updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _fitBounds();
          }
        });
      });
    }
  }

  void _fitBounds() {
    if (widget.route.isEmpty) return;

    // Berechne die Bounding Box der Route
    double minLat = widget.route.first.latitude;
    double maxLat = widget.route.first.latitude;
    double minLng = widget.route.first.longitude;
    double maxLng = widget.route.first.longitude;

    for (final point in widget.route) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    // Füge etwas Padding hinzu
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    final bounds = LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    // Verwende fitCamera mit forceIntegerZoomLevel: false für smoothere Übergänge
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
          forceIntegerZoomLevel: false,
        ),
      );
    } catch (e) {
      // Fallback: Einfacher Move zur Mitte der Route
      final center = LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );
      _mapController.move(center, 13.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radarTileUrl = ref.watch(radarTileProviderProvider);
    final showRadarOverlay = ref.watch(radarOverlayProvider) && widget.showRadar;

    final markers = <Marker>[
      if (widget.start != null)
        Marker(
          point: widget.start!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
          ),
        ),
      if (widget.end != null)
        Marker(
          point: widget.end!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.flag, color: Colors.white, size: 24),
          ),
        ),
      ...widget.shelters.map((shelter) => Marker(
        point: shelter,
        width: 32,
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.house, color: Colors.white, size: 18),
        ),
      )),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.route.isEmpty ? 5.5 : 13.0, // Zoom 5.5 für ganz Deutschland, 13 für lokale Ansicht
        onTap: (tapPos, latlng) => widget.onTap(latlng),
        onLongPress: (tapPos, latlng) => widget.onTap(latlng),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'de.dryroute.app',
        ),
        if (showRadarOverlay && radarTileUrl.isNotEmpty)
          Opacity(
            opacity: 0.7,
            child: TileLayer(
              urlTemplate: radarTileUrl,
              backgroundColor: Colors.transparent,
              additionalOptions: const {
                'attribution': 'RainViewer',
              },
            ),
          ),
        if (markers.isNotEmpty)
          MarkerLayer(markers: markers),
        if (widget.route.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.route,
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 4,
              )
            ],
          ),
      ],
    );
  }
}
