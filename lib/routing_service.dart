import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';


// Liest den ORS-API-Key aus der .env-Datei
String? get orsApiKey => dotenv.env['ORS_API_KEY'];

class RoutingService {
  static Future<List<LatLng>> getRoute({
    required LatLng start,
    required LatLng end,
    String profile = 'foot-walking', // oder 'cycling-regular'
  }) async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/$profile?api_key=$orsApiKey',
    );
    final body = jsonEncode({
      'coordinates': [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ],
    });
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data == null || data['features'] == null || data['features'].isEmpty) {
        // Zeige ggf. ORS-Fehlermeldung, falls vorhanden
        final msg = data['error']?['message'] ?? 'Keine Route gefunden (leere Antwort von ORS).';
        throw Exception(msg);
      }
      final coords = data['features'][0]['geometry']['coordinates'] as List?;
      if (coords == null || coords.isEmpty) {
        throw Exception('Keine Routendaten gefunden.');
      }
      return coords
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } else {
      // Versuche, die Fehlermeldung aus dem JSON zu extrahieren
      String msg = 'Fehler beim Abrufen der Route: ${response.body}';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('error')) {
          msg = data['error']['message'] ?? msg;
        }
      } catch (_) {}
      throw Exception(msg);
    }
  }
}
