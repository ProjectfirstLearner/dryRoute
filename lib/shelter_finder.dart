import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ShelterFinder {
  static Future<List<LatLng>> findSheltersNear(LatLng point, {double radius = 300}) async {
    // Overpass-API: Suche nach shelter in der Nähe
    final query = '''
      [out:json];
      node["amenity"="shelter"](around:$radius,${point.latitude},${point.longitude});
      out;
    ''';
    final url = Uri.parse('https://overpass-api.de/api/interpreter');
    final response = await http.post(url, body: {'data': query});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final elements = data['elements'] as List?;
      if (elements == null || elements.isEmpty) {
        // Keine Shelter gefunden, aber kein harter Fehler
        return [];
      }
      return elements
          .map((e) => LatLng((e['lat'] as num).toDouble(), (e['lon'] as num).toDouble()))
          .toList();
    } else {
      throw Exception('Fehler bei Overpass: ${response.body}');
    }
  }
}
