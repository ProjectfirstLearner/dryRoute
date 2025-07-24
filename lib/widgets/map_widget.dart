
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../radar_provider.dart';

class MapWidget extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final radarTileUrl = ref.watch(radarTileProviderProvider);

    final markers = <Marker>[
      if (start != null)
        Marker(
          point: start!,
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
      if (end != null)
        Marker(
          point: end!,
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
      ...shelters.map((shelter) => Marker(
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
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.0,
        onTap: (tapPos, latlng) => onTap(latlng),
        onLongPress: (tapPos, latlng) => onTap(latlng),
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
        if (markers.isNotEmpty)
          MarkerLayer(markers: markers),
        if (route.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route,
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 4,
              )
            ],
          ),
      ],
    );
  }
}
