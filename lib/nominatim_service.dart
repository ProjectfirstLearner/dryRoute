import 'dart:convert';
import 'package:http/http.dart' as http;

class NominatimSuggestion {
  final String displayName;
  final double lat;
  final double lon;

  NominatimSuggestion({required this.displayName, required this.lat, required this.lon});

  factory NominatimSuggestion.fromJson(Map<String, dynamic> json) {
    return NominatimSuggestion(
      displayName: json['display_name'],
      lat: double.parse(json['lat']),
      lon: double.parse(json['lon']),
    );
  }
}

class NominatimService {
  static Future<List<NominatimSuggestion>> search(String query) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5',
    );
    final response = await http.get(url, headers: {
      'User-Agent': 'DryRouteApp/1.0 (your@email.com)',
    });
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((e) => NominatimSuggestion.fromJson(e)).toList();
    } else {
      throw Exception('Nominatim-Fehler: ${response.statusCode}');
    }
  }
}
