import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Radar-Provider-Auswahl (Rainviewer/DWD) via Riverpod
final radarProviderSetting = StateProvider<String>((ref) => 'dwd');
final radarOverlayProvider = StateProvider<bool>((ref) => true);

/// Gibt das passende Radar-Tile-URL-Template zurück, abhängig vom Provider
final radarTileProviderProvider = Provider<String>((ref) {
  // Nur DWD verwenden
  return 'https://maps.dwd.de/geoserver/radar/wmts?layer=RADOLAN-OS&style=default&tilematrixset=EPSG:3857&Service=WMTS&Request=GetTile&Version=1.0.0&Format=image/png&TileMatrix={z}&TileCol={x}&TileRow={y}';
});
