import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  
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

  /// Sucht nach Adressen basierend auf Suchanfrage
  Future<List<SearchResult>> searchAddresses(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = Uri.parse('$_baseUrl/search')
          .replace(queryParameters: {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
        'countrycodes': 'de', // Fokus auf Deutschland
      });

      final response = await http.get(
        url,
        headers: {'User-Agent': 'DryRoute/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => SearchResult.fromJson(item))
            .toList();
      }
    } catch (e) {
      print('Nominatim Suchfehler: $e');
    }
    return [];
  }

  /// Reverse Geocoding - Adresse für Koordinaten finden
  Future<String?> reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse('$_baseUrl/reverse')
          .replace(queryParameters: {
        'lat': location.latitude.toString(),
        'lon': location.longitude.toString(),
        'format': 'json',
        'addressdetails': '1',
      });

      final response = await http.get(
        url,
        headers: {'User-Agent': 'DryRoute/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _formatAddress(data);
      }
    } catch (e) {
      print('Reverse Geocoding Fehler: $e');
    }
    return null;
  }

  String _formatAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) return data['display_name'] ?? 'Unbekannte Adresse';

    final parts = <String>[];
    
    // Straße und Hausnummer
    final road = address['road'] as String?;
    final houseNumber = address['house_number'] as String?;
    if (road != null) {
      if (houseNumber != null) {
        parts.add('$road $houseNumber');
      } else {
        parts.add(road);
      }
    }

    // Stadt
    final city = address['city'] ?? 
                address['town'] ?? 
                address['village'] ?? 
                address['municipality'];
    if (city != null) parts.add(city);

    return parts.join(', ');
  }
}

class SearchResult {
  final String displayName;
  final LatLng location;
  final String type;
  final Map<String, dynamic> address;

  SearchResult({
    required this.displayName,
    required this.location,
    required this.type,
    required this.address,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      displayName: json['display_name'] ?? 'Unbekannt',
      location: LatLng(
        double.parse(json['lat']),
        double.parse(json['lon']),
      ),
      type: json['type'] ?? 'unknown',
      address: json['address'] ?? {},
    );
  }

  String get shortName {
    final address = this.address;
    final road = address['road'] as String?;
    final houseNumber = address['house_number'] as String?;
    final city = address['city'] ?? 
                address['town'] ?? 
                address['village'] ?? 
                address['municipality'];

    final parts = <String>[];
    if (road != null) {
      if (houseNumber != null) {
        parts.add('$road $houseNumber');
      } else {
        parts.add(road);
      }
    }
    if (city != null) parts.add(city);

    return parts.join(', ');
  }
}
