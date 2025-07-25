import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/route_data.dart';

class RouteResult {
  final List<LatLng> coordinates;
  final double distanceInMeters;
  final double durationInSeconds;

  RouteResult({
    required this.coordinates,
    required this.distanceInMeters,
    required this.durationInSeconds,
  });
}

class RoutingService {
  static final String _apiKey = dotenv.env['ORS_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.openrouteservice.org/v2/directions';
  static const String _osrmUrl = 'https://router.project-osrm.org/route/v1/driving';
  
  String get _mapboxToken => dotenv.env['MAPBOX_TOKEN'] ?? '';

  static Future<RouteResult> getRoute({
    required LatLng start,
    required LatLng end,
    String profile = 'foot-walking',
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('ORS API Key nicht gefunden. Bitte .env Datei prüfen.');
    }

    // Validiere Koordinaten
    if (start.latitude.abs() > 90 || start.longitude.abs() > 180 ||
        end.latitude.abs() > 90 || end.longitude.abs() > 180) {
      throw Exception('Ungültige Koordinaten');
    }

    // Koordinaten im richtigen Format [lon, lat] für ORS
    final coordinates = [
      [start.longitude, start.latitude],
      [end.longitude, end.latitude]
    ];

    final body = jsonEncode({
      'coordinates': coordinates,
      'instructions': false,
      'geometry': true,
    });

    try {
      // ORS verwendet API-Key als Query-Parameter, nicht als Header
      final uriWithApiKey = Uri.parse('$_baseUrl/$profile?api_key=$_apiKey');

      final response = await http.post(
        uriWithApiKey,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unbekannter Fehler';

        // Falls foot-walking fehlschlägt, versuche driving-car als Fallback
        if (profile == 'foot-walking' && response.statusCode == 404) {
          return getRoute(start: start, end: end, profile: 'driving-car');
        }

        throw Exception('ORS-Fehler (${response.statusCode}): $errorMessage');
      }

      final data = jsonDecode(response.body);

      // ORS gibt routes zurück, nicht features
      if (data['routes'] == null || (data['routes'] as List).isEmpty) {
        throw Exception('Keine Route gefunden zwischen den angegebenen Punkten');
      }

      final route = data['routes'][0];
      if (route['geometry'] == null) {
        throw Exception('Ungültige Routengeometrie erhalten');
      }

      final geometryString = route['geometry'] as String;

      // Dekodiere die Polyline-Geometrie
      final coords = _decodePolyline(geometryString);

      // Extrahiere die echte Distanz aus der API-Response
      final summary = route['summary'];
      final distance = (summary?['distance'] as num?)?.toDouble() ?? 0.0;
      final duration = (summary?['duration'] as num?)?.toDouble() ?? 0.0;

      return RouteResult(
        coordinates: coords,
        distanceInMeters: distance,
        durationInSeconds: duration,
      );

    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Netzwerkfehler: $e');
    }
  }

  /// Berechnet Route zwischen zwei Punkten
  Future<RouteData?> calculateRoute(
    LatLng start, 
    LatLng end, 
    {String startAddress = '', String endAddress = ''}
  ) async {
    try {
      // Versuche zuerst OSRM (kostenlos)
      final osrmRoute = await _calculateOSRMRoute(start, end, startAddress, endAddress);
      if (osrmRoute != null) return osrmRoute;

      // Fallback zu Mapbox falls verfügbar
      if (_mapboxToken.isNotEmpty) {
        return await _calculateMapboxRoute(start, end, startAddress, endAddress);
      }

      return null;
    } catch (e) {
      print('Fehler bei Routenberechnung: $e');
      return null;
    }
  }

  /// OSRM Routing (Open Source)
  Future<RouteData?> _calculateOSRMRoute(
    LatLng start, 
    LatLng end, 
    String startAddress, 
    String endAddress
  ) async {
    try {
      final url = Uri.parse(
        '$_osrmUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson&steps=true'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;
          
          final polylinePoints = geometry
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();

          final distance = (route['distance'] as num).toDouble();
          final duration = Duration(seconds: (route['duration'] as num).round());

          return RouteData(
            polylinePoints: polylinePoints,
            totalDistance: distance,
            estimatedDuration: duration,
            startAddress: startAddress.isEmpty ? 'Start' : startAddress,
            endAddress: endAddress.isEmpty ? 'Ziel' : endAddress,
            startPoint: start,
            endPoint: end,
            createdAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      print('OSRM Fehler: $e');
    }
    return null;
  }

  /// Mapbox Routing (benötigt API Key)
  Future<RouteData?> _calculateMapboxRoute(
    LatLng start, 
    LatLng end, 
    String startAddress, 
    String endAddress
  ) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/cycling/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?geometries=geojson&access_token=$_mapboxToken'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;
          
          final polylinePoints = geometry
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();

          final distance = (route['distance'] as num).toDouble();
          final duration = Duration(seconds: (route['duration'] as num).round());

          return RouteData(
            polylinePoints: polylinePoints,
            totalDistance: distance,
            estimatedDuration: duration,
            startAddress: startAddress.isEmpty ? 'Start' : startAddress,
            endAddress: endAddress.isEmpty ? 'Ziel' : endAddress,
            startPoint: start,
            endPoint: end,
            createdAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      print('Mapbox Fehler: $e');
    }
    return null;
  }

  /// Erstellt eine einfache Luftlinie-Route als Fallback
  RouteData createStraightLineRoute(
    LatLng start, 
    LatLng end, 
    String startAddress, 
    String endAddress
  ) {
    const Distance distance = Distance();
    final distanceMeters = distance.as(LengthUnit.Meter, start, end);
    
    // Geschätzte Dauer bei 15 km/h (Fahrrad)
    final estimatedMinutes = (distanceMeters / 1000 * 4).round(); // 15 km/h = 4 min/km
    
    return RouteData(
      polylinePoints: [start, end],
      totalDistance: distanceMeters,
      estimatedDuration: Duration(minutes: estimatedMinutes),
      startAddress: startAddress.isEmpty ? 'Start' : startAddress,
      endAddress: endAddress.isEmpty ? 'Ziel' : endAddress,
      startPoint: start,
      endPoint: end,
      createdAt: DateTime.now(),
    );
  }

  /// Berechnet Zwischenpunkte für lange Strecken
  List<LatLng> interpolateRoute(LatLng start, LatLng end, {int points = 10}) {
    final List<LatLng> interpolated = [start];
    
    for (int i = 1; i < points; i++) {
      final ratio = i / points;
      final lat = start.latitude + (end.latitude - start.latitude) * ratio;
      final lng = start.longitude + (end.longitude - start.longitude) * ratio;
      interpolated.add(LatLng(lat, lng));
    }
    
    interpolated.add(end);
    return interpolated;
  }

  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}
