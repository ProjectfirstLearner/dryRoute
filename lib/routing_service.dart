import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  static final String _apiKey = dotenv.env['ORS_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.openrouteservice.org/v2/directions';

  static Future<List<LatLng>> getRoute({
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

    print('Start: ${start.latitude}, ${start.longitude}');
    print('End: ${end.latitude}, ${end.longitude}');

    final uri = Uri.parse('$_baseUrl/$profile');
    final body = jsonEncode({
      'coordinates': coordinates,
      'instructions': false,
      'geometry': true,
    });

    try {
      // ORS verwendet API-Key als Query-Parameter, nicht als Header
      final uriWithApiKey = Uri.parse('$_baseUrl/$profile?api_key=$_apiKey');
      
      print('ORS Request URL: $uriWithApiKey');
      print('ORS Request Body: $body');
      
      final response = await http.post(
        uriWithApiKey,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      );

      print('ORS Response Status: ${response.statusCode}');
      print('ORS Response Body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unbekannter Fehler';
        
        // Falls foot-walking fehlschlägt, versuche driving-car als Fallback
        if (profile == 'foot-walking' && response.statusCode == 404) {
          print('Foot-walking fehlgeschlagen, versuche driving-car...');
          return getRoute(start: start, end: end, profile: 'driving-car');
        }
        
        throw Exception('ORS-Fehler (${response.statusCode}): $errorMessage');
      }

      final data = jsonDecode(response.body);
      print('Parsed JSON data: $data');
      
      // ORS gibt routes zurück, nicht features
      if (data['routes'] == null || (data['routes'] as List).isEmpty) {
        throw Exception('Keine Route gefunden zwischen den angegebenen Punkten');
      }

      final route = data['routes'][0];
      if (route['geometry'] == null) {
        throw Exception('Ungültige Routengeometrie erhalten');
      }

      final geometryString = route['geometry'] as String;
      print('Geometry string: $geometryString');
      
      // Dekodiere die Polyline-Geometrie
      final coords = _decodePolyline(geometryString);
      print('Decoded ${coords.length} coordinates');
      
      return coords;

    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Netzwerkfehler: $e');
    }
  }

  // Dekodiert eine Polyline-Geometrie String zu LatLng-Koordinaten
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}