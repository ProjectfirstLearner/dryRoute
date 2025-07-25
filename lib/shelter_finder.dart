import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class Shelter {
  final LatLng location;
  final String type;
  final String? name;
  final double distanceFromPoint;

  Shelter({
    required this.location,
    required this.type,
    this.name,
    required this.distanceFromPoint,
  });

  factory Shelter.fromOverpassElement(Map<String, dynamic> element, LatLng referencePoint) {
    final lat = (element['lat'] as num).toDouble();
    final lon = (element['lon'] as num).toDouble();
    final location = LatLng(lat, lon);
    
    // Berechne Distanz zum Referenzpunkt
    const Distance distance = Distance();
    final distanceInMeters = distance.as(LengthUnit.Meter, referencePoint, location);
    
    // Bestimme Unterstand-Typ
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    String type = 'Unterstand';
    
    if (tags.containsKey('amenity')) {
      switch (tags['amenity']) {
        case 'shelter':
          type = 'Schutzhütte';
          break;
        case 'bus_station':
          type = 'Busbahnhof';
          break;
      }
    } else if (tags.containsKey('building')) {
      switch (tags['building']) {
        case 'roof':
          type = 'Überdachung';
          break;
        case 'train_station':
          type = 'Bahnhof';
          break;
      }
    } else if (tags.containsKey('highway')) {
      if (tags['highway'] == 'bus_stop') {
        type = 'Bushaltestelle';
      }
    } else if (tags.containsKey('public_transport')) {
      switch (tags['public_transport']) {
        case 'platform':
          type = 'Bahnsteig';
          break;
        case 'station':
          type = 'Haltestelle';
          break;
      }
    }
    
    return Shelter(
      location: location,
      type: type,
      name: tags['name'] as String?,
      distanceFromPoint: distanceInMeters,
    );
  }

  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return '$name ($type)';
    }
    return type;
  }

  String get distanceText {
    if (distanceFromPoint < 1000) {
      return '${distanceFromPoint.round()} m';
    } else {
      return '${(distanceFromPoint / 1000).toStringAsFixed(1)} km';
    }
  }
}

class ShelterFinder {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const int _maxResults = 10;

  static Future<List<LatLng>> findSheltersNear(LatLng point, {double radius = 300}) async {
    final shelters = await findNearbyShelters(point, radius: radius);
    return shelters.map((shelter) => shelter.location).toList();
  }

  /// Findet Unterstände in einem Umkreis um den gegebenen Punkt
  static Future<List<Shelter>> findNearbyShelters(LatLng center, {double radius = 500}) async {
    try {
      // Overpass QL Query erstellen
      final String query = _buildOverpassQuery(center, radius);
      
      // HTTP POST Request an Overpass API
      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=$query',
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Overpass API Fehler: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final elements = data['elements'] as List<dynamic>? ?? [];

      // Konvertiere zu Shelter Objekten und sortiere nach Distanz
      final shelters = elements
          .map((element) => Shelter.fromOverpassElement(element, center))
          .toList();

      shelters.sort((a, b) => a.distanceFromPoint.compareTo(b.distanceFromPoint));

      // Limitiere Ergebnisse
      return shelters.take(_maxResults).toList();

    } catch (e) {
      print('Fehler beim Suchen von Unterständen: $e');
      return [];
    }
  }

  /// Erstellt Overpass QL Query für verschiedene Arten von Unterständen
  static String _buildOverpassQuery(LatLng center, double radius) {
    return '''
[out:json][timeout:10];
(
  // Explizite Unterstände
  node["amenity"="shelter"](around:$radius,${center.latitude},${center.longitude});
  way["amenity"="shelter"](around:$radius,${center.latitude},${center.longitude});
  
  // Bushaltestellen (oft überdacht)
  node["highway"="bus_stop"]["shelter"="yes"](around:$radius,${center.latitude},${center.longitude});
  node["highway"="bus_stop"]["covered"="yes"](around:$radius,${center.latitude},${center.longitude});
  
  // Bahnsteige und Haltestellen
  node["public_transport"="platform"]["covered"="yes"](around:$radius,${center.latitude},${center.longitude});
  way["public_transport"="platform"]["covered"="yes"](around:$radius,${center.latitude},${center.longitude});
  
  // Busbahnhöfe
  node["amenity"="bus_station"](around:$radius,${center.latitude},${center.longitude});
  way["amenity"="bus_station"](around:$radius,${center.latitude},${center.longitude});
  
  // Überdachungen
  way["building"="roof"](around:$radius,${center.latitude},${center.longitude});
  
  // Gebäude mit expliziter Schutz-Funktion
  node["shelter"="yes"](around:$radius,${center.latitude},${center.longitude});
  way["shelter"="yes"](around:$radius,${center.latitude},${center.longitude});
);
out center;
''';
  }

  /// Findet den nächstgelegenen Unterstand
  static Future<Shelter?> findNearestShelter(LatLng point) async {
    final shelters = await findNearbyShelters(point);
    return shelters.isNotEmpty ? shelters.first : null;
  }

  /// Prüft ob es Unterstände in der Nähe gibt
  static Future<bool> hasSheltersNearby(LatLng point, {double radius = 300}) async {
    final shelters = await findNearbyShelters(point, radius: radius);
    return shelters.isNotEmpty;
  }
}
