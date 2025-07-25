
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import 'radar_provider.dart';

class CachedRadarTileProvider extends TileProvider {
  final RadarSource source;
  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<Uint8List?>> _pendingRequests = {};
  static const int _maxCacheSize = 100;

  CachedRadarTileProvider({required this.source});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return RadarTileImageProvider(
      coordinates: coordinates,
      options: options,
      provider: this,
    );
  }

  Future<Uint8List?> getTileData(TileCoordinates coordinates) async {
    final cacheKey = '${source.name}_${coordinates.z}_${coordinates.x}_${coordinates.y}';
    
    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // Check if request is already pending
    if (_pendingRequests.containsKey(cacheKey)) {
      return await _pendingRequests[cacheKey];
    }

    // Start new request
    final future = _fetchTileData(coordinates);
    _pendingRequests[cacheKey] = future;

    try {
      final data = await future;
      _pendingRequests.remove(cacheKey);
      
      if (data != null) {
        // Manage cache size
        if (_cache.length >= _maxCacheSize) {
          final oldestKey = _cache.keys.first;
          _cache.remove(oldestKey);
        }
        _cache[cacheKey] = data;
      }
      
      return data;
    } catch (e) {
      _pendingRequests.remove(cacheKey);
      if (kDebugMode) {
        print('Error fetching radar tile: $e');
      }
      return null;
    }
  }

  Future<Uint8List?> _fetchTileData(TileCoordinates coordinates) async {
    try {
      final url = RadarUrlHelper.getRadarUrl(
        source,
        coordinates.x,
        coordinates.y,
        coordinates.z,
      );

      if (url.isEmpty) return null;

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'DryRoute/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        if (kDebugMode) {
          print('Radar tile request failed: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Radar tile fetch error: $e');
      }
      return null;
    }
  }

  void clearCache() {
    _cache.clear();
    _pendingRequests.clear();
  }
}

class RadarTileImageProvider extends ImageProvider<RadarTileImageProvider> {
  final TileCoordinates coordinates;
  final TileLayer options;
  final CachedRadarTileProvider provider;

  const RadarTileImageProvider({
    required this.coordinates,
    required this.options,
    required this.provider,
  });

  @override
  Future<RadarTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<RadarTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(RadarTileImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'RadarTile(${coordinates.x}, ${coordinates.y}, ${coordinates.z})',
    );
  }

  Future<ui.Codec> _loadAsync(RadarTileImageProvider key, ImageDecoderCallback decode) async {
    try {
      final data = await provider.getTileData(coordinates);
      if (data == null) {
        // Return a transparent 1x1 pixel if tile fails to load
        return await decode(await _createTransparentTile());
      }
      return await decode(await ui.ImmutableBuffer.fromUint8List(data));
    } catch (e) {
      if (kDebugMode) {
        print('Error loading radar tile: $e');
      }
      return await decode(await _createTransparentTile());
    }
  }

  Future<ui.ImmutableBuffer> _createTransparentTile() async {
    // Create a 1x1 transparent PNG
    final transparentPixel = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 dimensions
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, // bit depth, color type, etc.
      0x89, 0x00, 0x00, 0x00, 0x0B, 0x49, 0x44, 0x41, // IDAT chunk
      0x54, 0x78, 0x9C, 0x62, 0x00, 0x02, 0x00, 0x00, // compressed data
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, // more compressed data
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
      0x42, 0x60, 0x82
    ]);
    return ui.ImmutableBuffer.fromUint8List(transparentPixel);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RadarTileImageProvider &&
        other.coordinates == coordinates &&
        other.provider.source == provider.source;
  }

  @override
  int get hashCode => Object.hash(coordinates, provider.source);
}
