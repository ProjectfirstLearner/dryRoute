
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

    // Koordinaten im richtigen Format [lon, lat] für ORS
    final coordinates = [
      [start.longitude, start.latitude],
      [end.longitude, end.latitude]
    ];

    final uri = Uri.parse('$_baseUrl/$profile');
    final body = jsonEncode({
      'coordinates': coordinates,
      'instructions': false,
      'geometry': true,
    });

    print('ORS Request URL: $uri');
    print('ORS Request Body: $body');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _apiKey,
          'Accept': 'application/json',
        },
        body: body,
      );

      print('ORS Response Status: ${response.statusCode}');
      print('ORS Response Body: ${response.body}');

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unbekannter Fehler';
        throw Exception('ORS-Fehler (${response.statusCode}): $errorMessage');
      }

      final data = jsonDecode(response.body);
      
      if (data['features'] == null || (data['features'] as List).isEmpty) {
        throw Exception('Keine Route gefunden zwischen den angegebenen Punkten');
      }

      final feature = data['features'][0];
      if (feature['geometry'] == null || feature['geometry']['coordinates'] == null) {
        throw Exception('Ungültige Routengeometrie erhalten');
      }

      final coords = feature['geometry']['coordinates'] as List<dynamic>;
      
      // Konvertiere [lon, lat] zu LatLng(lat, lon)
      return coords
          .map<LatLng>((c) => LatLng(c[1] as double, c[0] as double))
          .toList();

    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Netzwerkfehler: $e');
    }
  }
}
